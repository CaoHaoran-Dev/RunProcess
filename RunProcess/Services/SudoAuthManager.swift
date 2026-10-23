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
            command, password: password, timeout: timeout) { result in
                switch result {
                case .success:
                    completion(result)
                case .failure(let error):
                    // 👇 密码错误判定放宽：覆盖 sudo 的多种措辞
                    let lower = error.localizedDescription.lowercased()
                    if lower.contains("incorrect password")
                        || lower.contains("sorry, try again")
                        || lower.contains("wrong password")
                        || lower.contains("authentication failure")
                        || lower.contains("no password was provided")
                        || lower.contains("a password is required")
                    {
                        let mapped = NSError(
                            domain: "RunProcess",
                            code: -2,
                            userInfo: [NSLocalizedDescriptionKey:
                                NSLocalizedString("error.sudo.wrong.password", comment: "")]
                        )
                        completion(.failure(mapped))
                    } else {
                        completion(result)
                    }
                }
            }
    }
}
