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
        
        let config = ConnectionConfig(host: host.host, port: host.port)
        let plainTransport = URLSessionTransport(config: config, transform: PassthroughTransform())
        try await plainTransport.connect()
        
        let sessionKeyData = try await negotiateKey(transport: plainTransport, token: token)
        plainTransport.close()
        
        let cipher = try AESGCMCipher(key: sessionKeyData)
        let secureTransport = URLSessionTransport(config: config)
        try await secureTransport.connect()
        
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
                    
                    // 💡 关键点：客户端利用 tokenHash 派生 SessionKey
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
                        try await transport.send(encoded)
                        continuation.resume(returning: sessionKey)
                    }
                } catch {
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
