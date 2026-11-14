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
    private let lock = NSLock()

    private init() {}

    // MARK: - 建立独立 channel

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

        let channel = SecureChannel(
            transport: transport,
            cipher: session.cipher,
            cipherId: AESGCMCipher.cipherId,
            isClient: true
        )
        await channel.start()

        lock.withLock {
            activeTransports[ObjectIdentifier(channel)] = transport
        }
        return channel
    }

    // MARK: - 移除独立 channel

    func removeChannel(for hostId: String, channel: SecureChannel) async {
        let transport: URLSessionTransport? = lock.withLock {
            activeTransports.removeValue(forKey: ObjectIdentifier(channel))
        }
        transport?.close()
        print("🧹 [Remote] channel removed for \(hostId)")
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

    // MARK: - 明文协商（只做一次）

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

        try? await Task.sleep(nanoseconds: 150_000_000)

        let cipher = try AESGCMCipher(key: sessionKeyData)
        let cached = CachedSession(sessionKey: sessionKeyData, cipher: cipher, createdAt: Date())

        lock.withLock {
            sessions[host.id] = cached
        }
        return cached
    }

    // MARK: - 明文握手

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
