//
//  CommandExecutor.swift
//  RunProcess
//
//  Created by Haoran on 2026/8/19.
//

import Foundation

class CommandExecutor {
    static let shared = CommandExecutor()
    
    // 当前正在运行的任务（用于取消）
    private var currentTask: Process?
    private var currentTimeoutWork: DispatchWorkItem?
    private let taskQueue = DispatchQueue(label: "com.runprocess.executor")
    
    private init() {}
    
    /// 执行命令（带超时）
    func execute(_ input: String, timeout: TimeInterval = 10.0, completion: @escaping (Result<String, Error>) -> Void) {
        // 取消之前的任务
        cancelCurrentTask()
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let task = Process()
            let pipe = Pipe()
            
            let homeDirectory = FileManager.default.homeDirectoryForCurrentUser.path
            task.currentDirectoryURL = URL(fileURLWithPath: homeDirectory)
            
            task.launchPath = "/bin/zsh"
            task.arguments = ["-l", "-c", input]
            task.standardOutput = pipe
            task.standardError = pipe
            
            // 保存当前任务
            self.taskQueue.sync {
                self.currentTask = task
            }
            
            do {
                try task.run()
                
                let timeoutWork = DispatchWorkItem { [weak self] in
                    guard let self = self else { return }
                    if task.isRunning {
                        task.terminate()
                        pipe.fileHandleForReading.closeFile()
                        pipe.fileHandleForWriting.closeFile()
                    }
                    self.taskQueue.sync {
                        self.currentTask = nil
                        self.currentTimeoutWork = nil
                    }
                }
                
                self.taskQueue.sync {
                    self.currentTimeoutWork = timeoutWork
                }
                
                DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: timeoutWork)
                
                task.waitUntilExit()
                timeoutWork.cancel()
                
                // 读取输出
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                let trimmed = output.trimmingCharacters(in: .newlines)
                
                // 关闭 pipe
                pipe.fileHandleForReading.closeFile()
                pipe.fileHandleForWriting.closeFile()
                
                DispatchQueue.main.async {
                    self.taskQueue.sync {
                        self.currentTask = nil
                        self.currentTimeoutWork = nil
                    }
                    
                    if task.terminationStatus == 0 {
                        completion(.success(trimmed))
                    } else if task.terminationStatus == 15 {
                        completion(.failure(NSError(domain: "RunProcess", code: Int(task.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "⏰ 命令执行超时（超过 \(timeout) 秒）\n💡 如需执行耗时命令，请直接在终端中运行"])))
                    } else {
                        let errorMsg = trimmed.isEmpty ? "命令执行失败（退出码: \(task.terminationStatus)）" : trimmed
                        completion(.failure(NSError(domain: "RunProcess", code: Int(task.terminationStatus), userInfo: [NSLocalizedDescriptionKey: errorMsg])))
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.taskQueue.sync {
                        self.currentTask = nil
                        self.currentTimeoutWork = nil
                    }
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// 🔒 安全执行 sudo 命令（通过 standardInput 传递密码）
    func executeWithSudo(_ command: String, password: String, timeout: TimeInterval = 10.0, completion: @escaping (Result<String, Error>) -> Void) {
        // 取消之前的任务
        cancelCurrentTask()
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let task = Process()
            let outputPipe = Pipe()
            let inputPipe = Pipe()
            
            let homeDirectory = FileManager.default.homeDirectoryForCurrentUser.path
            task.currentDirectoryURL = URL(fileURLWithPath: homeDirectory)
            
            // 🛡️ 使用 sudo -S 从标准输入读取密码
            task.launchPath = "/usr/bin/sudo"
            let commandArgs = command.split(separator: " ").map(String.init)
            task.arguments = ["-S", "-k"] + commandArgs  // -k 忽略缓存，强制要求密码
            
            task.standardOutput = outputPipe
            task.standardError = outputPipe
            task.standardInput = inputPipe
            
            // 保存当前任务
            self.taskQueue.sync {
                self.currentTask = task
            }
            
            do {
                try task.run()
                
                // 🔐 通过标准输入传递密码，不会出现在进程列表中
                let passwordData = "\(password)\n".data(using: .utf8)!
                inputPipe.fileHandleForWriting.write(passwordData)
                inputPipe.fileHandleForWriting.closeFile()
                
                let timeoutWork = DispatchWorkItem { [weak self] in
                    guard let self = self else { return }
                    if task.isRunning {
                        task.terminate()
                        outputPipe.fileHandleForReading.closeFile()
                        outputPipe.fileHandleForWriting.closeFile()
                    }
                    self.taskQueue.sync {
                        self.currentTask = nil
                        self.currentTimeoutWork = nil
                    }
                }
                
                self.taskQueue.sync {
                    self.currentTimeoutWork = timeoutWork
                }
                
                DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: timeoutWork)
                
                task.waitUntilExit()
                timeoutWork.cancel()
                
                let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                let trimmed = output.trimmingCharacters(in: .newlines)
                
                // 关闭 pipe
                outputPipe.fileHandleForReading.closeFile()
                outputPipe.fileHandleForWriting.closeFile()
                
                DispatchQueue.main.async {
                    self.taskQueue.sync {
                        self.currentTask = nil
                        self.currentTimeoutWork = nil
                    }
                    
                    if task.terminationStatus == 0 {
                        completion(.success(trimmed))
                    } else if task.terminationStatus == 15 {
                        completion(.failure(NSError(domain: "RunProcess", code: Int(task.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "⏰ 命令执行超时（超过 \(timeout) 秒）"])))
                    } else {
                        // 检测密码错误
                        if trimmed.lowercased().contains("password") || trimmed.contains("Sorry") {
                            completion(.failure(NSError(domain: "RunProcess", code: Int(task.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "❌ 密码错误\n💡 请检查密码后重试"])))
                        } else {
                            let errorMsg = trimmed.isEmpty ? "命令执行失败（退出码: \(task.terminationStatus)）" : trimmed
                            completion(.failure(NSError(domain: "RunProcess", code: Int(task.terminationStatus), userInfo: [NSLocalizedDescriptionKey: errorMsg])))
                        }
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.taskQueue.sync {
                        self.currentTask = nil
                        self.currentTimeoutWork = nil
                    }
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// 取消当前正在执行的任务
    func cancelCurrentTask() {
        taskQueue.sync {
            currentTimeoutWork?.cancel()
            if let task = currentTask, task.isRunning {
                task.terminate()
            }
            currentTask = nil
            currentTimeoutWork = nil
        }
    }
}
