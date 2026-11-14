//
//  RemoteConnectionManager.swift
//  RunProcess
//
//  Created by Haoran on 2026/11/7.
//

#if BETA

import Foundation
import RemoteLinkKit
import RemoteProcessProtocol

final class RemoteConnectionManager {
    static let shared = RemoteConnectionManager()

    private struct CachedSession {
        let sessionKey: Data
        let cipher: AESGCMCipher
        let createdAt: Date
    }

    private var sessions: [String: CachedSession] = [:]
    private var activeTransports: [ObjectIdentifier: URLSessionTransport] = [:]
    private var hostTransports: [String: URLSessionTransport] = [:]
    
    private let lock = NSLock()

    private init() {}

    func makeChannel(for host: RemoteHost) async throws -> SecureChannel {
        let session = try await ensureSession(for: host)

        let endpointHost = HostAddress.formattedForURL(host.host)
        let config = ConnectionConfig(
            host: endpointHost,
            port: host.port,
            pairingPort: 52732,
            scheme: .ws,
            connectTimeout: 10
        )

        print("🔐 [Remote] makeChannel connect ws://\(endpointHost):\(host.port)")
        let transport = URLSessionTransport(
            config: config,
            transform: PassthroughTransform(),
            reconnectPolicy: ReconnectPolicy()
        )
        transport.onStateChange = { state in
            print("🔐 [Remote] channel state: \(state)")
        }
        
        try await transport.connect()
        print("✅ [Remote] channel connected")

        // 👇 核心修复：在交给 SecureChannel 之前，给它一点时间让底层握手彻底完成
        // 避免把 HTTP 101 之后的零星字节当成 Frame
        try? await Task.sleep(nanoseconds: 200_000_000)

        let channel = SecureChannel(
            transport: transport,
            cipher: session.cipher,
            cipherId: AESGCMCipher.cipherId,
            isClient: true
        )
        
        // 拦截第一次错误，如果是脏数据导致的解析错误，自动抛出，外层重试
        await channel.setOnError { error in
            print("⚠️ [Remote] Channel error intercepted: \(error)")
        }
        
        await channel.start()

        lock.withLock {
            activeTransports[ObjectIdentifier(channel)] = transport
            hostTransports[host.id] = transport
        }
        return channel
    }

    func removeChannel(for hostId: String, channel: SecureChannel) async {
        let transport: URLSessionTransport? = lock.withLock {
            activeTransports.removeValue(forKey: ObjectIdentifier(channel))
        }
        transport?.close()
        print("🧹 [Remote] channel removed for \(hostId)")
    }

    func removeChannel(for hostId: String) async {
        let transport: URLSessionTransport? = lock.withLock {
            hostTransports.removeValue(forKey: hostId)
        }
        if let t = transport {
            t.close()
            print("🧹 [Remote] stale transport cleaned for \(hostId)")
        }
    }

    func removeChannel(_ channel: SecureChannel) async {
        let transport: URLSessionTransport? = lock.withLock {
            activeTransports.removeValue(forKey: ObjectIdentifier(channel))
        }
        transport?.close()
    }

    func invalidateSession(for hostId: String) {
        _ = lock.withLock { sessions.removeValue(forKey: hostId) }
    }

    private func ensureSession(for host: RemoteHost) async throws -> CachedSession {
        if let cached = lock.withLock({ sessions[host.id] }) {
            return cached
        }

        guard let token = KeychainHelper.shared.getToken(for: host.id) else {
            throw NSError(
                domain: "RunProcess.Remote",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("error.remote.missing.token", comment: "")]
            )
        }

        let endpointHost = HostAddress.formattedForURL(host.host)
        let config = ConnectionConfig(
            host: endpointHost,
            port: host.port,
            pairingPort: 52732,
            scheme: .ws,
            connectTimeout: 10
        )

        print("🔌 [Remote] negotiate plain connect ws://\(endpointHost):\(host.port)")
        let plainTransport = URLSessionTransport(
            config: config,
            transform: PassthroughTransform(),
            reconnectPolicy: ReconnectPolicy()
        )
        plainTransport.onStateChange = { state in
            print("🔌 [Remote] plain state: \(state)")
        }
        try await plainTransport.connect()
        print("✅ [Remote] plain connected")

        let sessionKeyData: Data
        do {
            sessionKeyData = try await negotiateKey(transport: plainTransport, token: token)
        } catch {
            plainTransport.close()
            throw error
        }
        print("✅ [Remote] key negotiated")

        plainTransport.onReceive = nil
        plainTransport.close()

        try? await Task.sleep(nanoseconds: 200_000_000)

        let cipher = try AESGCMCipher(key: sessionKeyData)
        let cached = CachedSession(sessionKey: sessionKeyData, cipher: cipher, createdAt: Date())

        lock.withLock {
            sessions[host.id] = cached
        }
        return cached
    }

    private func negotiateKey(transport: URLSessionTransport, token: String) async throws -> Data {
        let resumed = ResumedFlag()

        return try await withCheckedThrowingContinuation { continuation in
            transport.onReceive = { data in
                guard resumed.trySet() else { return }
                print("📨 [Remote] plain received \(data.count) bytes")
                do {
                    let msg = try MessageCodec.decodeServer(data)
                    guard case .custom(let type, let payload) = msg, type == "server-challenge" else {
                        throw NSError(
                            domain: "RunProcess",
                            code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "收到未知的握手包"]
                        )
                    }

                    struct ChallengePayload: Codable {
                        let serverNonce: String
                        let cipherId: UInt16
                    }

                    let challenge = try JSONDecoder().decode(ChallengePayload.self, from: payload)
                    let serverNonce = Data(hexString: challenge.serverNonce)
                    let clientNonce = KeyDerivation.randomBytes(32)
                    let tokenHash = PairingToken(rawValue: token).hash()

                    let sessionKey = KeyDerivation.deriveKey(
                        sharedSecret: Data(tokenHash.utf8),
                        salt: clientNonce + serverNonce,
                        info: Data("RunProcess-Session-v1".utf8)
                    )

                    struct AuthPayload: Codable {
                        let clientNonce: String
                        let tokenHash: String
                    }

                    let hexClientNonce = clientNonce.map { String(format: "%02x", $0) }.joined()
                    let authPayload = try JSONEncoder().encode(AuthPayload(
                        clientNonce: hexClientNonce,
                        tokenHash: tokenHash
                    ))
                    let authMsg = ClientMessage.custom(type: "client-auth", payload: authPayload)
                    let encoded = try MessageCodec.encode(authMsg)

                    Task {
                        do {
                            try await transport.send(encoded)
                            print("✅ [Remote] client-auth sent")
                            continuation.resume(returning: sessionKey)
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                } catch {
                    print("❌ [Remote] negotiate failed: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

private nonisolated final class ResumedFlag: @unchecked Sendable {
    private var value = false
    private let lock = NSLock()

    func trySet() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if value { return false }
        value = true
        return true
    }
}

#endif
