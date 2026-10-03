//
//  SudoAuthManager.swift
//  RunProcess
//
//  Created by Haoran on 2026/9/13.
//

import Foundation

final class SudoAuthManager {

    func revoke() { /* 无缓存凭据，无需操作 */ }

    func executeSudo(_ command: String, password: String, timeout: TimeInterval,
                     completion: @escaping (Result<String, Error>) -> Void) {
        CommandExecutor.shared.executeWithSudo(
            command, password: password, timeout: timeout, completion: completion)
    }
}
