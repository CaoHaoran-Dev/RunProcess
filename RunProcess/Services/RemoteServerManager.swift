//
//  RemoteServerManager.swift
//  RunProcess
//
//  Created by Haoran on 2026/11/7.
//

#if BETA

import Foundation
import Network
import RemoteLinkKit
import RemoteProcessProtocol
internal import AppKit

nonisolated final class RemoteServerManager: @unchecked Sendable {
    static let shared = RemoteServerManager()

    private var activeChannels: [SecureChannel] = []
    private let lock = NSLock()

    private var wsListener: NWListener?
    private var pairingServer: HTTPPairingServer?
    private var advertiser: BonjourAdvertiser?

    private var currentPairingCode: PairingCode?

    private struct PendingSession {
        let cipher: AESGCMCipher
        let createdAt: Date
    }
    private var pendingSessions: [String: PendingSession] = [:]
    private let pendingLock = NSLock()
    private static let pendingSessionTTL: TimeInterval = 3600

    private init() {}

    nonisolated private func withPendingLock<T>(_ body: () -> T) -> T {
        pendingLock.lock()
        defer { pendingLock.unlock() }
        return body()
    }

    // MARK: - Lifecycle

    func start() {
        guard wsListener == nil else { return }
        print("🌐 Starting Remote Server...")

        let name = Host.current().localizedName ?? "RunProcess Mac"
        advertiser = BonjourAdvertiser(serviceName: name, port: 52731)
        advertiser?.start()

        startPairingServer()
        startWebSocketServer()
    }

    func stop() {
        print("🛑 Stopping Remote Server...")
        wsListener?.cancel()
        wsListener = nil
        pairingServer?.stop()
        pairingServer = nil
        advertiser?.stop()
        advertiser = nil
        lock.withLock { activeChannels.removeAll() }
        withPendingLock { pendingSessions.removeAll() }
    }

    // MARK: - HTTP Pairing Server

    private func startPairingServer() {
        pairingServer = HTTPPairingServer { [weak self] request in
            guard let self = self else { return HTTPPairingServer.Response(status: 500) }
            return self.handlePairingRequest(request)
        }
        do {
            try pairingServer?.start(port: 52732)
            print("✅ Pairing server started on 52732")
        } catch {
            print("⚠️ Failed to start pairing server: \(error)")
        }
    }

    private nonisolated func handlePairingRequest(_ request: HTTPPairingServer.Request) -> HTTPPairingServer.Response {
        let path = request.path
        let decoder = JSONDecoder()
        let encoder = JSONEncoder()

        if path == "/pair/hello" {
            let code = PairingCode()
            lock.withLock { self.currentPairingCode = code }

            Task { @MainActor in
                NotificationCenter.default.post(
                    name: NSNotification.Name("ShowRemotePairingCode"),
                    object: code.code
                )
                let delivered = await RemotePairingNotifier.notifyPairingCode(code.code)
                if !delivered {
                    print("⚠️ [Server] pairing notification not delivered, rely on in-app alert")
                }
            }
            
            let serverId = "runprocess-host-\(Host.current().localizedName ?? "Mac")"
            let nonce = KeyDerivation.randomBytes(32)
            let hello = PairingHandshake.HelloResponse(
                serverId: serverId,
                nonce: nonce.map { String(format: "%02x", $0) }.joined(),
                supportedCiphers: [AESGCMCipher.cipherId],
                serverName: Host.current().localizedName
            )
            if let data = try? encoder.encode(hello) {
                return HTTPPairingServer.Response(status: 200, body: data)
            }

        } else if path == "/pair/verify" {
            let hasCode = lock.withLock { self.currentPairingCode != nil }
            guard hasCode else { return HTTPPairingServer.Response(status: 400) }
            guard let verifyReq = try? decoder.decode(PairingHandshake.VerifyRequest.self, from: request.body) else {
                return HTTPPairingServer.Response(status: 400)
            }

            let token = PairingToken.generate(deviceName: verifyReq.deviceName)
            let tokenHash = token.hash()
            let clientName = verifyReq.deviceName ?? "Unknown Device"
            let clientRecord = PairedClient(deviceName: clientName, tokenHash: tokenHash)

            Task { @MainActor in
                PairedClientStore.shared.add(clientRecord)
            }

            let resp = PairingHandshake.VerifyResponse(
                token: token.rawValue,
                deviceId: token.rawValue
            )
            if let data = try? encoder.encode(resp) {
                return HTTPPairingServer.Response(status: 200, body: data)
            }
        }

        return HTTPPairingServer.Response(status: 404)
    }

    // MARK: - WebSocket Server

    private func startWebSocketServer() {
        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true
        params.includePeerToPeer = false
        if let ipOptions = params.defaultProtocolStack.internetProtocol as? NWProtocolIP.Options {
            ipOptions.version = .any
        }
        let wsOptions = NWProtocolWebSocket.Options()
        wsOptions.autoReplyPing = true
        params.defaultProtocolStack.applicationProtocols.insert(wsOptions, at: 0)

        do {
            let listener = try NWListener(using: params, on: 52731)
            listener.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    print("✅ WebSocket listener ready on port \(listener.port?.rawValue ?? 0)")
                case .waiting(let error):
                    print("⏳ WebSocket listener waiting: \(error)")
                case .failed(let error):
                    print("❌ WebSocket listener failed: \(error)")
                case .cancelled:
                    print("🛑 WebSocket listener cancelled")
                default:
                    break
                }
            }
            listener.newConnectionHandler = { [weak self] connection in
                self?.handleNewConnection(connection)
            }
            listener.start(queue: .global())
            self.wsListener = listener
        } catch {
            print("⚠️ Failed to start WebSocket server: \(error)")
        }
    }

    // MARK: - 新连接处理

    private nonisolated func handleNewConnection(_ connection: NWConnection) {
        print("🔌 [Server] new connection from \(connection.endpoint)")
        let transport = NWTransport(connection: connection)
        let serverNonce = KeyDerivation.randomBytes(32)

        final class BindBox: @unchecked Sendable {
            var bound = false
            let lock = NSLock()
        }
        let bindBox = BindBox()

        transport.onReceive = { [weak self] data in
            guard let self = self else { return }

            bindBox.lock.lock()
            let alreadyBound = bindBox.bound
            bindBox.lock.unlock()
            if alreadyBound { return }

            if let matched = self.tryBindPendingSecure(data, transport: transport) {
                bindBox.lock.lock(); bindBox.bound = true; bindBox.lock.unlock()
                print("✅ [Server] secure connection bound (tokenHash \(matched.prefix(8))…)")
                return
            }

            do {
                let msg = try MessageCodec.decodeClient(data)
                guard case .custom(let type, let payload) = msg, type == "client-auth" else {
                    print("⚠️ [Server] first packet is not client-auth, ignoring")
                    return
                }

                struct AuthPayload: Codable {
                    let clientNonce: String
                    let tokenHash: String
                }
                let auth = try JSONDecoder().decode(AuthPayload.self, from: payload)
                let clientNonce = Data(hexString: auth.clientNonce)

                let sessionKey = KeyDerivation.deriveKey(
                    sharedSecret: Data(auth.tokenHash.utf8),
                    salt: clientNonce + serverNonce,
                    info: Data("RunProcess-Session-v1".utf8)
                )
                let cipher = try AESGCMCipher(key: sessionKey)

                Task {
                    // 只在主 actor 上做验证和写缓存
                    let authorized: Bool = await MainActor.run {
                        guard PairedClientStore.shared.verify(tokenHash: auth.tokenHash) != nil else {
                            return false
                        }
                        self.withPendingLock {
                            self.pendingSessions[auth.tokenHash] = PendingSession(cipher: cipher, createdAt: Date())
                        }
                        return true
                    }

                    guard authorized else {
                        print("⚠️ [Server] unauthorized tokenHash: \(auth.tokenHash.prefix(8))…")
                        connection.cancel()
                        return
                    }

                    print("✅ [Server] auth ok; closing plain connection, awaiting secure connection")
                    // 普通 Task 上下文，同步调用 close()，不会被误判为 async
                    transport.close()
                }
            } catch {
                print("❌ [Server] first packet rejected: \(error)")
                connection.cancel()
            }
        }

        Task {
            try? await transport.connect()
            let challenge: [String: Any] = [
                "serverNonce": serverNonce.map { String(format: "%02x", $0) }.joined(),
                "cipherId": AESGCMCipher.cipherId
            ]
            if let data = try? JSONSerialization.data(withJSONObject: challenge) {
                let msg = ClientMessage.custom(type: "server-challenge", payload: data)
                if let encoded = try? MessageCodec.encode(msg) {
                    try? await transport.send(encoded)
                }
            }
        }
    }

    private nonisolated func tryBindPendingSecure(_ data: Data, transport: NWTransport) -> String? {
        let snapshot: [String: PendingSession] = withPendingLock {
            let now = Date()
            for (k, v) in pendingSessions where now.timeIntervalSince(v.createdAt) > Self.pendingSessionTTL {
                pendingSessions.removeValue(forKey: k)
            }
            return pendingSessions
        }

        guard !snapshot.isEmpty, data.count >= 12 else { return nil }
        let bytes = [UInt8](data.prefix(12))
        let seq = UInt32(bytes[4]) << 24 | UInt32(bytes[5]) << 16 | UInt32(bytes[6]) << 8 | UInt32(bytes[7])
        let length = UInt32(bytes[8]) << 24 | UInt32(bytes[9]) << 16 | UInt32(bytes[10]) << 8 | UInt32(bytes[11])

        guard length <= UInt32(Frame.maxPayloadSize), data.count >= 12 + Int(length) else { return nil }

        let payloadStart = data.index(data.startIndex, offsetBy: 12)
        let payloadEnd = data.index(payloadStart, offsetBy: Int(length))
        let payload = data[payloadStart..<payloadEnd]
        // headerAAD 只含 version + type + cipherId + seq（8 字节），不含 length
        let headerData = data.prefix(8)
        let nonce = KeyDerivation.nonce(from: seq)

        for (tokenHash, session) in snapshot {
            if (try? session.cipher.open(Data(payload), nonce: nonce, aad: headerData)) != nil {
                let secureChannel = SecureChannel(
                    transport: transport,
                    cipher: session.cipher,
                    cipherId: AESGCMCipher.cipherId,
                    isClient: false
                )
                self.setupChannel(secureChannel)
                Task { await secureChannel.start() }
                return tokenHash
            }
        }
        return nil
    }

    // MARK: - Channel 绑定

    private nonisolated func setupChannel(_ channel: SecureChannel) {
        lock.withLock { activeChannels.append(channel) }

        Task {
            await channel.setOnClientMessage { [weak self] msg in
                guard let self = self else { return }
                switch msg {
                case .exec(let id, let cmd, _):
                    if let reason = RemoteAccessPolicyStore.shared.validate(command: cmd, capability: .execCommand) {
                        Task { try? await channel.send(.error(id: id, message: reason)) }
                        return
                    }
                    self.executeLocalCommand(cmd, id: id, channel: channel)

                case .custom(let type, let payload) where type == "exec-v2":
                    guard let req = try? JSONDecoder().decode(RemoteExecPayload.self, from: payload) else {
                        Task { try? await channel.send(.error(id: nil, message: "invalid exec-v2 payload")) }
                        return
                    }
                    let capability = Self.capability(for: req.execKind)
                    if let reason = RemoteAccessPolicyStore.shared.validate(command: req.cmd, capability: capability) {
                        Task { try? await channel.send(.error(id: req.id, message: reason)) }
                        return
                    }
                    self.dispatch(req, channel: channel)

                case .cancel(let id):
                    print("Received cancel for \(id)")
                default:
                    break
                }
            }

            await channel.setOnError { [weak self] error in
                guard let self = self else { return }
                print("❌ [Server] channel error: \(error)")
                self.lock.withLock {
                    self.activeChannels.removeAll { $0 === channel }
                }
            }
        }
    }

    // MARK: - exec-v2 分发

    private nonisolated static func capability(for kind: RemoteExecPayload.Kind) -> RemoteCapability {
        switch kind {
        case .command:  return .execCommand
        case .sudo:     return .sudoCommand
        case .workflow: return .runWorkflow
        case .alias:    return .modifyAliases
        case .history:  return .modifyHistory
        case .file:     return .fileAccess
        }
    }

    private nonisolated func dispatch(_ req: RemoteExecPayload, channel: SecureChannel) {
        switch req.execKind {
        case .command, .workflow:
            executeLocalCommand(req.cmd, id: req.id, channel: channel)
        case .sudo:
            executeSudoCommand(req.cmd, id: req.id, channel: channel)
        case .alias:
            handleAliasCommand(req.cmd, id: req.id, channel: channel)
        case .history:
            handleHistoryCommand(req.cmd, id: req.id, channel: channel)
        case .file:
            handleFileCommand(req.cmd, id: req.id, channel: channel)
        }
    }

    // MARK: - sudo

    private nonisolated func executeSudoCommand(_ cmd: String, id: String, channel: SecureChannel) {
        DispatchQueue.global().async {
            let escaped = cmd.replacingOccurrences(of: "\"", with: "\\\"")
            let script = "do shell script \"\(escaped)\" with administrator privileges"

            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            task.arguments = ["-e", script]

            let outPipe = Pipe()
            let errPipe = Pipe()
            task.standardOutput = outPipe
            task.standardError = errPipe

            outPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty { Task { try? await channel.send(.output(id: id, stream: .stdout, data: data)) } }
            }
            errPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty { Task { try? await channel.send(.output(id: id, stream: .stderr, data: data)) } }
            }

            do {
                try task.run()
                task.waitUntilExit()
                Task { try? await channel.send(.done(id: id, exit: task.terminationStatus, cwd: "/")) }
            } catch {
                Task { try? await channel.send(.error(id: id, message: error.localizedDescription)) }
            }
        }
    }

    // MARK: - alias

    private nonisolated func handleAliasCommand(_ cmd: String, id: String, channel: SecureChannel) {
        DispatchQueue.global().async {
            let parts = cmd.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true).map(String.init)
            guard let sub = parts.first else {
                Task { try? await channel.send(.error(id: id, message: "alias: missing subcommand")) }
                return
            }

            let reply: String
            switch sub.lowercased() {
            case "list":
                reply = AliasStore.shared.aliases.map { "\($0.name)\t\($0.expansion)" }.joined(separator: "\n")
            case "add":
                guard parts.count == 2 else {
                    Task { try? await channel.send(.error(id: id, message: "alias add <name> <expansion>")) }
                    return
                }
                let rest = parts[1]
                let name = rest.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true).first.map(String.init) ?? ""
                let expansion = rest.dropFirst(name.count).trimmingCharacters(in: .whitespaces)
                guard !name.isEmpty, !expansion.isEmpty, !name.contains(" ") else {
                    Task { try? await channel.send(.error(id: id, message: "alias add <name> <expansion>")) }
                    return
                }
                AliasStore.shared.add(CommandAlias(name: name, expansion: expansion))
                reply = "ok"
            case "remove":
                guard parts.count == 2 else {
                    Task { try? await channel.send(.error(id: id, message: "alias remove <name>")) }
                    return
                }
                AliasStore.shared.remove(name: parts[1].trimmingCharacters(in: .whitespaces))
                reply = "ok"
            default:
                Task { try? await channel.send(.error(id: id, message: "unknown alias subcommand: \(sub)")) }
                return
            }

            let data = Data((reply + "\n").utf8)
            Task {
                try? await channel.send(.output(id: id, stream: .stdout, data: data))
                try? await channel.send(.done(id: id, exit: 0, cwd: "/"))
            }
        }
    }

    // MARK: - history

    private nonisolated func handleHistoryCommand(_ cmd: String, id: String, channel: SecureChannel) {
        DispatchQueue.global().async {
            let parts = cmd.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
            guard let sub = parts.first else {
                Task { try? await channel.send(.error(id: id, message: "history: missing subcommand")) }
                return
            }

            let reply: String
            switch sub.lowercased() {
            case "list":
                let limit = parts.count > 1 ? (Int(parts[1]) ?? 50) : 50
                reply = CommandHistory.shared.getAll()
                    .sorted { $0.lastUsed > $1.lastUsed }
                    .prefix(max(0, min(limit, 500)))
                    .map { "\($0.count)\t\($0.command)" }.joined(separator: "\n")
            case "search":
                guard parts.count > 1 else {
                    Task { try? await channel.send(.error(id: id, message: "history search <query> [limit]")) }
                    return
                }
                let query = parts[1]
                let limit = parts.count > 2 ? (Int(parts[2]) ?? 20) : 20
                reply = CommandHistory.shared.search(query).prefix(max(0, min(limit, 200)))
                    .map { "\($0.count)\t\($0.command)" }.joined(separator: "\n")
            case "clear":
                CommandHistory.shared.clearAll()
                reply = "ok"
            default:
                Task { try? await channel.send(.error(id: id, message: "unknown history subcommand: \(sub)")) }
                return
            }

            let data = Data((reply + "\n").utf8)
            Task {
                try? await channel.send(.output(id: id, stream: .stdout, data: data))
                try? await channel.send(.done(id: id, exit: 0, cwd: "/"))
            }
        }
    }

    // MARK: - file

    private nonisolated func handleFileCommand(_ cmd: String, id: String, channel: SecureChannel) {
        DispatchQueue.global().async {
            let parts = cmd.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true).map(String.init)
            guard let sub = parts.first else {
                Task { try? await channel.send(.error(id: id, message: "file: missing subcommand")) }
                return
            }

            switch sub.lowercased() {
            case "read":
                guard parts.count == 2 else {
                    Task { try? await channel.send(.error(id: id, message: "file read <path>")) }
                    return
                }
                let path = (parts[1] as NSString).expandingTildeInPath
                do {
                    let data = try Data(contentsOf: URL(fileURLWithPath: path))
                    Task {
                        try? await channel.send(.output(id: id, stream: .stdout, data: data))
                        try? await channel.send(.done(id: id, exit: 0, cwd: "/"))
                    }
                } catch {
                    Task { try? await channel.send(.error(id: id, message: error.localizedDescription)) }
                }

            case "write":
                guard parts.count == 2 else {
                    Task { try? await channel.send(.error(id: id, message: "file write <path>\\n<content>")) }
                    return
                }
                let rest = parts[1]
                guard let newline = rest.firstIndex(of: "\n") else {
                    Task { try? await channel.send(.error(id: id, message: "file write <path>\\n<content>")) }
                    return
                }
                let path = (String(rest[..<newline]) as NSString).expandingTildeInPath
                let content = String(rest[rest.index(after: newline)...])
                do {
                    try Data(content.utf8).write(to: URL(fileURLWithPath: path), options: .atomic)
                    Task {
                        try? await channel.send(.output(id: id, stream: .stdout, data: Data("ok\n".utf8)))
                        try? await channel.send(.done(id: id, exit: 0, cwd: "/"))
                    }
                } catch {
                    Task { try? await channel.send(.error(id: id, message: error.localizedDescription)) }
                }

            case "list":
                guard parts.count == 2 else {
                    Task { try? await channel.send(.error(id: id, message: "file list <path>")) }
                    return
                }
                let path = (parts[1] as NSString).expandingTildeInPath
                do {
                    let entries = try FileManager.default.contentsOfDirectory(atPath: path).sorted()
                    Task {
                        try? await channel.send(.output(id: id, stream: .stdout, data: Data((entries.joined(separator: "\n") + "\n").utf8)))
                        try? await channel.send(.done(id: id, exit: 0, cwd: "/"))
                    }
                } catch {
                    Task { try? await channel.send(.error(id: id, message: error.localizedDescription)) }
                }

            default:
                Task { try? await channel.send(.error(id: id, message: "unknown file subcommand: \(sub)")) }
            }
        }
    }

    // MARK: - 本地执行

    private nonisolated func executeLocalCommand(_ command: String, id: String, channel: SecureChannel) {
        DispatchQueue.global().async {
            let task = Process()
            let outPipe = Pipe()
            let errPipe = Pipe()
            task.executableURL = URL(fileURLWithPath: "/bin/zsh")
            task.arguments = ["-l", "-c", command]
            task.standardOutput = outPipe
            task.standardError = errPipe

            outPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty { Task { try? await channel.send(.output(id: id, stream: .stdout, data: data)) } }
            }
            errPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty { Task { try? await channel.send(.output(id: id, stream: .stderr, data: data)) } }
            }

            do {
                try task.run()
                task.waitUntilExit()
                Task { try? await channel.send(.done(id: id, exit: task.terminationStatus, cwd: "/")) }
            } catch {
                Task { try? await channel.send(.error(id: id, message: error.localizedDescription)) }
            }
        }
    }
}

#endif
