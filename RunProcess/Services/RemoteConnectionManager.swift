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
    
    private var channels: [String: (channel: SecureChannel, transport: URLSessionTransport)] = [:]
    private let lock = NSLock()
    
    private init() {}
    
    func getChannel(for host: RemoteHost) async throws -> SecureChannel {
        if let existing = lock.withLock({ channels[host.id] }) {
            return existing.channel
        }
        
        guard let token = KeychainHelper.shared.getToken(for: host.id) else {
            throw NSError(domain: "RunProcess.Remote", code: 401, userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("error.remote.missing.token", comment: "")])
        }
        
        let endpointHost = HostAddress.formattedForURL(host.host)
        let config = ConnectionConfig(
            host: endpointHost,
            port: host.port,
            pairingPort: 52732,
            scheme: .ws,
            connectTimeout: 10
        )
        
        print("🔌 [Remote] plain connect ws://\(endpointHost):\(host.port)")
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
        
        let sessionKeyData = try await negotiateKey(transport: plainTransport, token: token)
        print("✅ [Remote] key negotiated")
        plainTransport.close()
        
        let cipher = try AESGCMCipher(key: sessionKeyData)
        let secureTransport = URLSessionTransport(
            config: config,
            reconnectPolicy: ReconnectPolicy()
        )
        secureTransport.onStateChange = { state in
            print("🔐 [Remote] secure state: \(state)")
        }
        print("🔐 [Remote] secure connect ws://\(endpointHost):\(host.port)")
        try await secureTransport.connect()
        print("✅ [Remote] secure connected")
        
        let channel = SecureChannel(
            transport: secureTransport,
            cipher: cipher,
            cipherId: AESGCMCipher.cipherId,
            isClient: true
        )
        await channel.start()
        
        lock.withLock { channels[host.id] = (channel, secureTransport) }
        return channel
    }
    
    private func negotiateKey(transport: URLSessionTransport, token: String) async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            transport.onReceive = { data in
                print("📨 [Remote] plain received \(data.count) bytes")
                do {
                    let msg = try MessageCodec.decodeServer(data)
                    guard case .custom(let type, let payload) = msg, type == "server-challenge" else {
                        throw NSError(domain: "RunProcess", code: -1, userInfo: [NSLocalizedDescriptionKey: "收到未知的握手包"])
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
    
    func removeChannel(for hostId: String) {
        let connection = lock.withLock { channels.removeValue(forKey: hostId) }
        connection?.transport.close()
    }
}

#endif
