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
    
    private init() {}
    
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
    }
    
    // MARK: - HTTP Pairing Server
    
    private func startPairingServer() {
        pairingServer = HTTPPairingServer { [weak self] request in
            guard let self = self else { return HTTPPairingServer.Response(status: 500) }
            return self.handlePairingRequest(request)
        }
        
        do {
            try pairingServer?.start(port: 52732)
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
                NotificationCenter.default.post(name: NSNotification.Name("ShowRemotePairingCode"), object: code.code)
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
            guard hasCode else {
                return HTTPPairingServer.Response(status: 400)
            }
            
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
        let wsOptions = NWProtocolWebSocket.Options()
        wsOptions.autoReplyPing = true
        params.defaultProtocolStack.applicationProtocols.insert(wsOptions, at: 0)
        
        do {
            let listener = try NWListener(using: params, on: 52731)
            listener.newConnectionHandler = { [weak self] connection in
                self?.handleNewConnection(connection)
            }
            listener.start(queue: .global())
            self.wsListener = listener
        } catch {
            print("⚠️ Failed to start WebSocket server: \(error)")
        }
    }
    
    private nonisolated func handleNewConnection(_ connection: NWConnection) {
        let transport = NWTransport(connection: connection)
        let serverNonce = KeyDerivation.randomBytes(32)
        
        transport.onReceive = { [weak self] data in
            guard let self = self else { return }
            do {
                let msg = try MessageCodec.decodeClient(data)
                guard case .custom(let type, let payload) = msg, type == "client-auth" else { return }
                
                struct AuthPayload: Codable {
                    let clientNonce: String
                    let tokenHash: String
                }
                
                let auth = try JSONDecoder().decode(AuthPayload.self, from: payload)
                let clientNonce = Data(hexString: auth.clientNonce)
                
                Task { @MainActor in
                    // 验证客户端发来的 Token Hash 是否在服务端的 PairedClientStore 里
                    guard PairedClientStore.shared.verify(tokenHash: auth.tokenHash) != nil else {
                        print("⚠️ Unauthorized client attempt: \(auth.tokenHash)")
                        connection.cancel()
                        return
                    }
                    
                    let sessionKey = KeyDerivation.deriveKey(
                        sharedSecret: Data(auth.tokenHash.utf8),
                        salt: clientNonce + serverNonce,
                        info: Data("RunProcess-Session-v1".utf8)
                    )
                    
                    let cipher = try AESGCMCipher(key: sessionKey)
                    
                    let secureChannel = SecureChannel(
                        transport: transport,
                        cipher: cipher,
                        cipherId: AESGCMCipher.cipherId,
                        isClient: false
                    )
                    
                    self.setupChannel(secureChannel)
                    Task { await secureChannel.start() }
                }
                
            } catch {
                connection.cancel()
            }
        }
        
        Task {
            try? await transport.connect()
            
            // 修复点：结构体中必须包含客户端期望解析的 cipherId 字段
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
    
    private nonisolated func setupChannel(_ channel: SecureChannel) {
        lock.withLock { activeChannels.append(channel) }
        
        Task {
            await channel.setOnClientMessage { [weak self] msg in
                guard let self = self else { return }
                switch msg {
                case .exec(let id, let cmd, _):
                    self.executeLocalCommand(cmd, id: id, channel: channel)
                case .cancel(let id):
                    print("Received cancel for \(id)")
                default:
                    break
                }
            }
            
            await channel.setOnError { [weak self] _ in
                guard let self = self else { return }
                self.lock.withLock {
                    self.activeChannels.removeAll { $0 === channel }
                }
            }
        }
    }
    
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
                if !data.isEmpty {
                    Task { try? await channel.send(.output(id: id, stream: .stdout, data: data)) }
                }
            }
            
            errPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty {
                    Task { try? await channel.send(.output(id: id, stream: .stderr, data: data)) }
                }
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
