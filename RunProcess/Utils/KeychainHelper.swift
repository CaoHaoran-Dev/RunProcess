//
//  KeychainHelper.swift
//  RunProcess
//
//  Created by Haoran on 2026/11/7.
//

import Foundation
import Security

final class KeychainHelper {
    static let shared = KeychainHelper()
    private let service = "com.runprocess.remote"
    
    private init() {}
    
    /// 保存远程主机的 Token
    func saveToken(_ token: String, for hostId: String) {
        guard let data = token.data(using: .utf8) else { return }
        
        // 先删除旧的
        deleteToken(for: hostId)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: hostId,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        SecItemAdd(query as CFDictionary, nil)
    }
    
    /// 读取 Token
    func getToken(for hostId: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: hostId,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess, let data = dataTypeRef as? Data {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
    
    /// 删除 Token
    func deleteToken(for hostId: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: hostId
        ]
        SecItemDelete(query as CFDictionary)
    }
}
