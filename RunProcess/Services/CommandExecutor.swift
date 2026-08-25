//
//  CommandExecutor.swift
//  RunProcess
//
//  Created by Haoran on 2026/8/19.
//

import Foundation

class CommandExecutor {
    static let shared = CommandExecutor()
    
    private var currentTask: Process?
    private var currentTimeoutWork: DispatchWorkItem?
    private let taskQueue = DispatchQueue(label: "com.runprocess.executor", qos: .default)
    private let maxOutputSize = 10 * 1024 * 1024 // 10MB
    private let outputQueue = DispatchQueue(label: "com.runprocess.output", qos: .userInitiated)
    
    private init() {}
    
    func execute(_ input: String, timeout: TimeInterval = 10.0, completion: @escaping (Result<String, Error>) -> Void) {
        cancelCurrentTask()
        
        // ✅ 修复：所有操作在同一个 QoS 队列中执行
        outputQueue.async { [weak self] in
            guard let self = self else { return }
            
            let task = Process()
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            
            let homeDirectory = FileManager.default.homeDirectoryForCurrentUser.path
            task.currentDirectoryURL = URL(fileURLWithPath: homeDirectory)
            
            task.launchPath = "/bin/zsh"
            task.arguments = ["-l", "-c", input]
            task.standardOutput = outputPipe
            task.standardError = errorPipe
            
            self.taskQueue.sync {
                self.currentTask = task
            }
            
            do {
                try task.run()
                
                // ✅ 修复：使用 DispatchGroup 但确保在同一个队列中处理
                let group = DispatchGroup()
                var outputData = Data()
                var errorData = Data()
                let lock = NSLock()
                var outputFinished = false
                var errorFinished = false
                
                // 读取 stdout
                group.enter()
                outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                    guard let self = self else { return }
                    let data = handle.availableData
                    if data.isEmpty {
                        if !outputFinished {
                            outputFinished = true
                            group.leave()
                        }
                        return
                    }
                    lock.lock()
                    if outputData.count + data.count <= self.maxOutputSize {
                        outputData.append(data)
                    }
                    lock.unlock()
                }
                
                // 读取 stderr
                group.enter()
                errorPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                    guard let self = self else { return }
                    let data = handle.availableData
                    if data.isEmpty {
                        if !errorFinished {
                            errorFinished = true
                            group.leave()
                        }
                        return
                    }
                    lock.lock()
                    if errorData.count + data.count <= self.maxOutputSize {
                        errorData.append(data)
                    }
                    lock.unlock()
                }
                
                // ✅ 修复：超时处理使用相同的 QoS
                let timeoutWork = DispatchWorkItem(qos: .userInitiated) { [weak self] in
                    guard let self = self else { return }
                    if task.isRunning {
                        task.terminate()
                    }
                    // 清理 handlers
                    outputPipe.fileHandleForReading.readabilityHandler = nil
                    errorPipe.fileHandleForReading.readabilityHandler = nil
                    // 确保 group 被释放
                    if !outputFinished {
                        outputFinished = true
                        group.leave()
                    }
                    if !errorFinished {
                        errorFinished = true
                        group.leave()
                    }
                    self.taskQueue.sync {
                        self.currentTask = nil
                        self.currentTimeoutWork = nil
                    }
                }
                
                self.taskQueue.sync {
                    self.currentTimeoutWork = timeoutWork
                }
                
                // ✅ 修复：在同一个队列中调度超时
                self.outputQueue.asyncAfter(deadline: .now() + timeout, execute: timeoutWork)
                
                // ✅ 修复：等待 group 完成（不阻塞高优先级队列）
                let result = group.wait(timeout: .now() + timeout + 1)
                
                // 取消超时任务（如果还没触发）
                timeoutWork.cancel()
                
                // 清理 handlers
                outputPipe.fileHandleForReading.readabilityHandler = nil
                errorPipe.fileHandleForReading.readabilityHandler = nil
                
                // 等待进程结束
                task.waitUntilExit()
                
                let output = String(data: outputData, encoding: .utf8) ?? ""
                let error = String(data: errorData, encoding: .utf8) ?? ""
                let combined = output + (error.isEmpty ? "" : "\n" + error)
                let trimmed = combined.trimmingCharacters(in: .newlines)
                
                let wasTerminated = task.terminationStatus == 15 || result == .timedOut
                
                DispatchQueue.main.async {
                    self.taskQueue.sync {
                        self.currentTask = nil
                        self.currentTimeoutWork = nil
                    }
                    
                    if wasTerminated {
                        completion(.failure(NSError(domain: "RunProcess", code: 15, userInfo: [NSLocalizedDescriptionKey: "⏰ 命令执行超时（超过 \(timeout) 秒）\n💡 如需执行耗时命令，请直接在终端中运行"])))
                    } else if task.terminationStatus == 0 {
                        completion(.success(trimmed))
                    } else {
                        let errorMsg = trimmed.isEmpty ? "命令执行失败（退出码: \(task.terminationStatus)）" : trimmed
                        completion(.failure(NSError(domain: "RunProcess", code: Int(task.terminationStatus), userInfo: [NSLocalizedDescriptionKey: errorMsg])))
                    }
                }
            } catch {
                outputPipe.fileHandleForReading.readabilityHandler = nil
                errorPipe.fileHandleForReading.readabilityHandler = nil
                
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
    
    func executeWithSudo(_ command: String, password: String, timeout: TimeInterval = 10.0, completion: @escaping (Result<String, Error>) -> Void) {
        cancelCurrentTask()
        
        outputQueue.async { [weak self] in
            guard let self = self else { return }
            
            let task = Process()
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            let inputPipe = Pipe()
            
            let homeDirectory = FileManager.default.homeDirectoryForCurrentUser.path
            task.currentDirectoryURL = URL(fileURLWithPath: homeDirectory)
            
            task.launchPath = "/usr/bin/sudo"
            let commandArgs = command.split(separator: " ").map(String.init)
            task.arguments = ["-S", "-k"] + commandArgs
            
            task.standardOutput = outputPipe
            task.standardError = errorPipe
            task.standardInput = inputPipe
            
            self.taskQueue.sync {
                self.currentTask = task
            }
            
            do {
                try task.run()
                
                let passwordData = "\(password)\n".data(using: .utf8)!
                inputPipe.fileHandleForWriting.write(passwordData)
                inputPipe.fileHandleForWriting.closeFile()
                
                let group = DispatchGroup()
                var outputData = Data()
                var errorData = Data()
                let lock = NSLock()
                var outputFinished = false
                var errorFinished = false
                
                group.enter()
                outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                    guard let self = self else { return }
                    let data = handle.availableData
                    if data.isEmpty {
                        if !outputFinished {
                            outputFinished = true
                            group.leave()
                        }
                        return
                    }
                    lock.lock()
                    if outputData.count + data.count <= self.maxOutputSize {
                        outputData.append(data)
                    }
                    lock.unlock()
                }
                
                group.enter()
                errorPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                    guard let self = self else { return }
                    let data = handle.availableData
                    if data.isEmpty {
                        if !errorFinished {
                            errorFinished = true
                            group.leave()
                        }
                        return
                    }
                    lock.lock()
                    if errorData.count + data.count <= self.maxOutputSize {
                        errorData.append(data)
                    }
                    lock.unlock()
                }
                
                let timeoutWork = DispatchWorkItem(qos: .userInitiated) { [weak self] in
                    guard let self = self else { return }
                    if task.isRunning {
                        task.terminate()
                    }
                    outputPipe.fileHandleForReading.readabilityHandler = nil
                    errorPipe.fileHandleForReading.readabilityHandler = nil
                    if !outputFinished {
                        outputFinished = true
                        group.leave()
                    }
                    if !errorFinished {
                        errorFinished = true
                        group.leave()
                    }
                    self.taskQueue.sync {
                        self.currentTask = nil
                        self.currentTimeoutWork = nil
                    }
                }
                
                self.taskQueue.sync {
                    self.currentTimeoutWork = timeoutWork
                }
                
                self.outputQueue.asyncAfter(deadline: .now() + timeout, execute: timeoutWork)
                
                let result = group.wait(timeout: .now() + timeout + 1)
                
                timeoutWork.cancel()
                
                outputPipe.fileHandleForReading.readabilityHandler = nil
                errorPipe.fileHandleForReading.readabilityHandler = nil
                
                task.waitUntilExit()
                
                let output = String(data: outputData, encoding: .utf8) ?? ""
                let error = String(data: errorData, encoding: .utf8) ?? ""
                let combined = output + (error.isEmpty ? "" : "\n" + error)
                let trimmed = combined.trimmingCharacters(in: .newlines)
                
                let wasTerminated = task.terminationStatus == 15 || result == .timedOut
                
                DispatchQueue.main.async {
                    self.taskQueue.sync {
                        self.currentTask = nil
                        self.currentTimeoutWork = nil
                    }
                    
                    if wasTerminated {
                        completion(.failure(NSError(domain: "RunProcess", code: 15, userInfo: [NSLocalizedDescriptionKey: "⏰ 命令执行超时（超过 \(timeout) 秒）"])))
                    } else if task.terminationStatus == 0 {
                        completion(.success(trimmed))
                    } else {
                        let lowercased = trimmed.lowercased()
                        let isPasswordError = lowercased.contains("sorry") ||
                                              lowercased.contains("incorrect password") ||
                                              (lowercased.contains("password") && lowercased.contains("try again"))
                        
                        if isPasswordError {
                            completion(.failure(NSError(domain: "RunProcess", code: Int(task.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "❌ 密码错误\n💡 请检查密码后重试"])))
                        } else {
                            let errorMsg = trimmed.isEmpty ? "命令执行失败（退出码: \(task.terminationStatus)）" : trimmed
                            completion(.failure(NSError(domain: "RunProcess", code: Int(task.terminationStatus), userInfo: [NSLocalizedDescriptionKey: errorMsg])))
                        }
                    }
                }
            } catch {
                outputPipe.fileHandleForReading.readabilityHandler = nil
                errorPipe.fileHandleForReading.readabilityHandler = nil
                
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
