//
//  CommandExecutor.swift
//  RunProcess
//
//  Created by Haoran on 2026/8/19.
//

import Foundation

class CommandExecutor {
    static let shared = CommandExecutor()
    
    private init() {}
    
    /// 执行命令（带超时）
    func execute(_ input: String, timeout: TimeInterval = 10.0, completion: @escaping (Result<String, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let task = Process()
            let pipe = Pipe()
            
            // 设置工作目录为用户主目录
            let homeDirectory = FileManager.default.homeDirectoryForCurrentUser.path
            task.currentDirectoryURL = URL(fileURLWithPath: homeDirectory)
            
            task.launchPath = "/bin/zsh"
            task.arguments = ["-l", "-c", input]
            task.standardOutput = pipe
            task.standardError = pipe
            
            do {
                try task.run()
                
                // 超时控制
                let timeoutWork = DispatchWorkItem {
                    if task.isRunning {
                        task.terminate()
                    }
                }
                
                DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: timeoutWork)
                
                task.waitUntilExit()
                timeoutWork.cancel()
                
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                let trimmed = output.trimmingCharacters(in: .newlines)
                
                DispatchQueue.main.async {
                    if task.terminationStatus == 0 {
                        completion(.success(trimmed))
                    } else if task.terminationStatus == 15 { // SIGTERM（被终止）
                        completion(.failure(NSError(domain: "RunProcess", code: Int(task.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "⏰ 命令执行超时（超过 \(timeout) 秒）\n💡 如需执行耗时命令，请直接在终端中运行"])))
                    } else {
                        let errorMsg = trimmed.isEmpty ? "命令执行失败（退出码: \(task.terminationStatus)）" : trimmed
                        completion(.failure(NSError(domain: "RunProcess", code: Int(task.terminationStatus), userInfo: [NSLocalizedDescriptionKey: errorMsg])))
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
}
