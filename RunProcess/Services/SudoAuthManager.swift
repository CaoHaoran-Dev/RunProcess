//
//  SudoAuthManager.swift
//  RunProcess
//
//  Created by Haoran on 2026/9/13.
//

import Foundation

/// 单个窗口的 sudo 授权状态
///
/// 设计：每次执行 sudo 命令都需要重新输入密码。密码只在当次执行期间临时存在，
/// 执行完立即清除。
final class SudoAuthManager {
    
    /// 临时密码，仅在 executeSudo 执行期间存在
    private var temporaryPassword: String?
    
    /// 是否已授权（当次命令执行中）
    var isAuthorized: Bool {
        return temporaryPassword != nil
    }
    
    /// 撤销授权（清除临时密码）
    func revoke() {
        temporaryPassword = nil
    }
    
    /// 用密码执行一次 sudo 命令，执行完立即清除
    /// - Parameters:
    ///   - command: 要执行的命令（不含 sudo 前缀）
    ///   - password: 用户输入的密码
    ///   - timeout: 超时
    ///   - completion: 结果回调
    func executeSudo(
        _ command: String,
        password: String,
        timeout: TimeInterval,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        temporaryPassword = password
        
        CommandExecutor.shared.executeWithSudo(
            command,
            password: password,
            timeout: timeout
        ) { [weak self] result in
            // ✅ 无论成功失败，都清除临时密码
            self?.temporaryPassword = nil
            completion(result)
        }
    }
}
