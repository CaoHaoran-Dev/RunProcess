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

    /// 共享缓存：同一主机复用一个 channel（旧行为，供其他调用方使用）。
    private var channels: [String: (channel: SecureChannel, transport: URLSessionTransport)] = [:]

    /// 独立 channel 的 transport，按 channel 身份登记，用于执行完后关闭。
    private var standaloneTransports: [ObjectIdentifier: URLSessionTransport] = [:]

    private let lock = NSLock()

    private init() {}

    // MARK: - 复用（保留原行为）

    func getChannel(for host: RemoteHost) async throws -> SecureChannel {
        if let existing = lock.withLock({ channels[host.id] }) {
            return existing.channel
        }

        let pair = try await buildChannel(for: host)
        lock.withLock { channels[host.id] = pair }
        return pair.channel
    }

    // MARK: - 独立 channel（每次执行新建，用完即关）

    /// 每次调用都新建一个 SecureChannel，不进入共享缓存。
    /// 调用方负责在用完后调用 `removeChannel(for:channel:)` 关闭。
    func makeChannel(for host: RemoteHost) async throws -> SecureChannel {
        let pair = try await buildChannel(for: host)
        lock.withLock {
            standaloneTransports[ObjectIdentifier(pair.channel)] = pair.transport
        }
        return pair.channel
    }

    /// 关闭并移除一个 channel。
    /// - 若该 channel 在共享缓存中，清缓存并关闭；
    /// - 否则按独立 channel 处理，只关闭 transport。
    func removeChannel(for hostId: String, channel: SecureChannel) async {
        // 1. 共享缓存
        let shared = lock.withLock { channels[hostId] }
        if let shared, shared.channel === channel {
            _ = lock.withLock { channels.removeValue(forKey: hostId) }
            shared.transport.close()
            return
        }

        // 2. 独立 channel
        let transport = lock.withLock {
            standaloneTransports.removeValue(forKey: ObjectIdentifier(channel))
        }
        transport?.close()
    }

    // MARK: - 内部构建

    private func buildChannel(for host: RemoteHost) async throws
        -> (channel: SecureChannel, transport: URLSessionTransport) {

        guard let token = KeychainHelper.shared.getToken(for: host.id) else {
            throw NSError(
                domain: "RunProcess.Remote",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey:
                    NSLocalizedString("error.remote.missing.token", comment: "")])
        }

        let endpointHost = HostAddress.formattedForURL(host.host)
        let config = ConnectionConfig(
            host: endpointHost,
            port: host.port,
            pairingPort: 52732,
            scheme: .ws,
            connectTimeout: 10
        )

        // 1. 明文连接，协商会话密钥
        print("🔌 [Remote] plain connect ws://\(endpointHost):\(host.port)")
        let plainTransport = URLSessionTransport(
            config: config,
            transform: PassthroughTransform(),
            reconnectPolicy: ReconnectPolicy()
        )
        plainTransport.onStateChange = { state in
            print("🔌 [Remote] plain state: \(state)")
        }

        let sessionKeyData: Data
        do {
            try await plainTransport.connect()
            print("✅ [Remote] plain connected")
            sessionKeyData = try await negotiateKey(transport: plainTransport, token: token)
            print("✅ [Remote] key negotiated")
        } catch {
            plainTransport.close()
            throw error
        }
        plainTransport.close()

        // 2. 加密连接
        let cipher = try AESGCMCipher(key: sessionKeyData)
        let secureTransport = URLSessionTransport(
            config: config,
            reconnectPolicy: ReconnectPolicy()
        )
        secureTransport.onStateChange = { state in
            print("🔐 [Remote] secure state: \(state)")
        }

        do {
            print("🔐 [Remote] secure connect ws://\(endpointHost):\(host.port)")
            try await secureTransport.connect()
            print("✅ [Remote] secure connected")
        } catch {
            secureTransport.close()
            throw error
        }

        let channel = SecureChannel(
            transport: secureTransport,
            cipher: cipher,
            cipherId: AESGCMCipher.cipherId,
            isClient: true
        )
        await channel.start()

        return (channel, secureTransport)
    }

    // MARK: - 密钥协商

    private func negotiateKey(transport: URLSessionTransport, token: String) async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            transport.onReceive = { data in
                print("📨 [Remote] plain received \(data.count) bytes")
                do {
                    let msg = try MessageCodec.decodeServer(data)
                    guard case .custom(let type, let payload) = msg, type == "server-challenge" else {
                        throw NSError(domain: "RunProcess", code: -1,
                                      userInfo: [NSLocalizedDescriptionKey: "收到未知的握手包"])
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

#endif
