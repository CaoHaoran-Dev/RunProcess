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
    private let taskQueue = DispatchQueue(label: "com.runprocess.executor", qos: .userInitiated)
    private let maxOutputSize = 10 * 1024 * 1024 // 10MB
    
    private init() {}
    
    // MARK: - Execute Command
    
    func execute(_ input: String, timeout: TimeInterval = 10.0, completion: @escaping (Result<String, Error>) -> Void) {
        cancelCurrentTask()
        
        // ✅ 所有工作在同一 QoS 队列
        taskQueue.async { [weak self] in
            guard let self = self else { return }
            
            let task = Process()
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            
            task.currentDirectoryURL = FileManager.default.homeDirectoryForCurrentUser
            task.launchPath = "/bin/zsh"
            task.arguments = ["-l", "-c", input]
            task.standardOutput = outputPipe
            task.standardError = errorPipe
            
            self.taskQueue.sync {
                self.currentTask = task
            }
            
            do {
                try task.run()
                
                var outputData = Data()
                var errorData = Data()
                let lock = NSLock()
                
                // ✅ 使用调度组
                let group = DispatchGroup()
                group.enter()
                group.enter()
                
                var outputEOF = false
                var errorEOF = false
                
                // ✅ 显式指定回调队列为 userInitiated
                let callbackQueue = DispatchQueue(label: "com.runprocess.callback", qos: .userInitiated)
                
                outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                    callbackQueue.async {
                        guard let self = self else { return }
                        let data = handle.availableData
                        if data.isEmpty {
                            if !outputEOF {
                                outputEOF = true
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
                }
                
                errorPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                    callbackQueue.async {
                        guard let self = self else { return }
                        let data = handle.availableData
                        if data.isEmpty {
                            if !errorEOF {
                                errorEOF = true
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
                }
                
                // ✅ 超时处理
                let timeoutWork = DispatchWorkItem { [weak self] in
                    guard let self = self else { return }
                    if task.isRunning {
                        task.terminate()
                    }
                    outputPipe.fileHandleForReading.readabilityHandler = nil
                    errorPipe.fileHandleForReading.readabilityHandler = nil
                    if !outputEOF {
                        outputEOF = true
                        group.leave()
                    }
                    if !errorEOF {
                        errorEOF = true
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
                
                // ✅ 在同一个队列调度超时
                self.taskQueue.asyncAfter(deadline: .now() + timeout, execute: timeoutWork)
                
                // ✅ 关键修复：不使用 wait() 阻塞，改用通知回调
                // 在 group 完成后处理结果
                group.notify(queue: .main) { [weak self] in
                    guard let self = self else { return }
                    
                    timeoutWork.cancel()
                    
                    outputPipe.fileHandleForReading.readabilityHandler = nil
                    errorPipe.fileHandleForReading.readabilityHandler = nil
                    
                    task.waitUntilExit()
                    
                    let output = String(data: outputData, encoding: .utf8) ?? ""
                    let error = String(data: errorData, encoding: .utf8) ?? ""
                    let combined = output + (error.isEmpty ? "" : "\n" + error)
                    let trimmed = combined.trimmingCharacters(in: .newlines)
                    
                    let wasTerminated = task.terminationStatus == 15
                    
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
    
    // MARK: - Execute with Sudo
    
    func executeWithSudo(_ command: String, password: String, timeout: TimeInterval = 10.0, completion: @escaping (Result<String, Error>) -> Void) {
        cancelCurrentTask()
        
        taskQueue.async { [weak self] in
            guard let self = self else { return }
            
            let task = Process()
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            let inputPipe = Pipe()
            
            task.currentDirectoryURL = FileManager.default.homeDirectoryForCurrentUser
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
                
                var outputData = Data()
                var errorData = Data()
                let lock = NSLock()
                
                let group = DispatchGroup()
                group.enter()
                group.enter()
                
                var outputEOF = false
                var errorEOF = false
                
                let callbackQueue = DispatchQueue(label: "com.runprocess.sudo.callback", qos: .userInitiated)
                
                outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                    callbackQueue.async {
                        guard let self = self else { return }
                        let data = handle.availableData
                        if data.isEmpty {
                            if !outputEOF {
                                outputEOF = true
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
                }
                
                errorPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                    callbackQueue.async {
                        guard let self = self else { return }
                        let data = handle.availableData
                        if data.isEmpty {
                            if !errorEOF {
                                errorEOF = true
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
                }
                
                let timeoutWork = DispatchWorkItem { [weak self] in
                    guard let self = self else { return }
                    if task.isRunning {
                        task.terminate()
                    }
                    outputPipe.fileHandleForReading.readabilityHandler = nil
                    errorPipe.fileHandleForReading.readabilityHandler = nil
                    if !outputEOF {
                        outputEOF = true
                        group.leave()
                    }
                    if !errorEOF {
                        errorEOF = true
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
                
                self.taskQueue.asyncAfter(deadline: .now() + timeout, execute: timeoutWork)
                
                group.notify(queue: .main) { [weak self] in
                    guard let self = self else { return }
                    
                    timeoutWork.cancel()
                    
                    outputPipe.fileHandleForReading.readabilityHandler = nil
                    errorPipe.fileHandleForReading.readabilityHandler = nil
                    
                    task.waitUntilExit()
                    
                    let output = String(data: outputData, encoding: .utf8) ?? ""
                    let error = String(data: errorData, encoding: .utf8) ?? ""
                    let combined = output + (error.isEmpty ? "" : "\n" + error)
                    let trimmed = combined.trimmingCharacters(in: .newlines)
                    
                    let wasTerminated = task.terminationStatus == 15
                    
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
    
    // MARK: - Cancel
    
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
