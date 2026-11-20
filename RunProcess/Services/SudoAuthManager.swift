//
//  SudoAuthManager.swift
//  RunProcess
//
//  Created by Haoran on 2026/9/13.
//

import Foundation

final class SudoAuthManager {

    /// 当前窗口正在进行的 sudo 执行。每个 Session 一份，
    /// 取消时只影响自己，不会打断其它窗口的 sudo。
    private var activeExecution: CommandExecutor.Execution?
    private let lock = NSLock()

    func revoke() { cancel() }

    /// 取消当前窗口正在进行的 sudo 执行（若有）。
    func cancel() {
        lock.lock()
        let execution = activeExecution
        activeExecution = nil
        lock.unlock()

        if let execution {
            CommandExecutor.shared.cancel(execution)
        }
    }

    func executeSudo(_ command: String, password: String, timeout: TimeInterval,
                     completion: @escaping (Result<String, Error>) -> Void) {
        // 同一窗口内新的 sudo 取代旧的。
        cancel()

        let execution = CommandExecutor.shared.executeWithSudo(
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
                                NSLocalizedString("error.sudo.wrong.password", comment: "")])
                        completion(.failure(mapped))
                    } else {
                        completion(result)
                    }
                }
            }

        lock.lock()
        activeExecution = execution
        lock.unlock()
    }
}
