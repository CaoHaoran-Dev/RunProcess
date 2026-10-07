//
//  CommandExecutor.swift
//  RunProcess
//
//  Created by Haoran on 2026/8/19.
//

import Foundation

class CommandExecutor {
    static let shared = CommandExecutor()

    private struct State {
        var task: Process?
        var timeoutWork: DispatchWorkItem?
        var cancelled = false
    }

    private var state = State()
    private let stateQueue = DispatchQueue(label: "com.runprocess.executor.state", qos: .userInitiated)
    private let maxOutputSize = 10 * 1024 * 1024 // 10MB

    private init() {}

    // MARK: - Public

    func execute(_ input: String, timeout: TimeInterval = 10.0,
                 completion: @escaping (Result<String, Error>) -> Void) {
        cancelCurrentTask()

        let task = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        task.currentDirectoryURL = URL(fileURLWithPath: AppSettings.resolvedWorkingDirectory)
        task.launchPath = "/bin/zsh"

        // ✅ 追加用户自定义路径，不覆盖 .zshrc / .zprofile 里已经设好的 PATH
        let customPath = PathStore.shared.customPathString()
        let wrappedCommand: String
        if customPath.isEmpty {
            wrappedCommand = input
        } else {
            wrappedCommand = "export PATH=\"$PATH:\(ShellQuoting.quote(customPath))\"; \(input)"
        }
        task.arguments = ["-l", "-c", wrappedCommand]

        task.standardOutput = outputPipe
        task.standardError = errorPipe

        // ✅ 不再设置 task.environment["PATH"]
        //    让 zsh 自己加载用户的 PATH，bootstrap 里再追加用户路径

        stateQueue.sync {
            self.state.task = task
            self.state.cancelled = false
        }

        do {
            try task.run()
            let pid = task.processIdentifier
            if pid > 0 {
                _ = setpgid(pid, pid)
            }
        } catch {
            cleanup()
            DispatchQueue.main.async { completion(.failure(error)) }
            return
        }

        collectOutput(task: task, outputPipe: outputPipe, errorPipe: errorPipe,
                      timeout: timeout, isSudo: false, completion: completion)
    }

    func executeWithSudo(_ command: String, password: String, timeout: TimeInterval = 10.0,
                         completion: @escaping (Result<String, Error>) -> Void) {
        cancelCurrentTask()

        let task = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        let inputPipe = Pipe()

        task.currentDirectoryURL = URL(fileURLWithPath: AppSettings.resolvedWorkingDirectory)
        task.launchPath = "/usr/bin/sudo"

        // ✅ 追加用户自定义路径
        let customPath = PathStore.shared.customPathString()
        let wrappedCommand: String
        if customPath.isEmpty {
            wrappedCommand = command
        } else {
            wrappedCommand = "export PATH=\"$PATH:\(ShellQuoting.quote(customPath))\"; \(command)"
        }
        task.arguments = ["-S", "-k", "/bin/zsh", "-l", "-c", wrappedCommand]

        task.standardOutput = outputPipe
        task.standardError = errorPipe
        task.standardInput = inputPipe

        stateQueue.sync {
            self.state.task = task
            self.state.cancelled = false
        }

        do {
            try task.run()
            let pid = task.processIdentifier
            if pid > 0 {
                _ = setpgid(pid, pid)
            }
        } catch {
            cleanup()
            DispatchQueue.main.async { completion(.failure(error)) }
            return
        }

        let passwordData = "\(password)\n".data(using: .utf8)!
        inputPipe.fileHandleForWriting.write(passwordData)
        inputPipe.fileHandleForWriting.closeFile()

        collectOutput(task: task, outputPipe: outputPipe, errorPipe: errorPipe,
                      timeout: timeout, isSudo: true, completion: completion)
    }

    // MARK: - Private

    private func collectOutput(task: Process,
                               outputPipe: Pipe, errorPipe: Pipe,
                               timeout: TimeInterval,
                               isSudo: Bool,
                               completion: @escaping (Result<String, Error>) -> Void) {
        var outputData = Data()
        var errorData = Data()
        let lock = NSLock()

        let group = DispatchGroup()
        group.enter()
        group.enter()

        var outputDone = false
        var errorDone = false

        let callbackQueue = DispatchQueue(label: "com.runprocess.executor.callback", qos: .userInitiated)

        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            callbackQueue.async {
                guard let self = self else { return }
                let data = handle.availableData
                if data.isEmpty {
                    if !outputDone { outputDone = true; group.leave() }
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
                    if !errorDone { errorDone = true; group.leave() }
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
            self.killProcessGroup(task)
            outputPipe.fileHandleForReading.readabilityHandler = nil
            errorPipe.fileHandleForReading.readabilityHandler = nil
            if !outputDone { outputDone = true; group.leave() }
            if !errorDone { errorDone = true; group.leave() }
            self.stateQueue.sync {
                self.state.timeoutWork = nil
                self.state.task = nil
            }
        }

        stateQueue.sync {
            self.state.timeoutWork = timeoutWork
        }
        DispatchQueue.global(qos: .userInitiated)
            .asyncAfter(deadline: .now() + timeout, execute: timeoutWork)

        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            timeoutWork.cancel()
            outputPipe.fileHandleForReading.readabilityHandler = nil
            errorPipe.fileHandleForReading.readabilityHandler = nil

            self.waitUntilExit(task, timeout: 3.0)

            let wasCancelled: Bool = self.stateQueue.sync {
                let c = self.state.cancelled
                self.state.task = nil
                self.state.timeoutWork = nil
                self.state.cancelled = false
                return c
            }

            let output = String(data: outputData, encoding: .utf8) ?? ""
            let error = String(data: errorData, encoding: .utf8) ?? ""
            let combined = output + (error.isEmpty ? "" : "\n" + error)
            let trimmed = combined.trimmingCharacters(in: .newlines)

            if wasCancelled {
                completion(.failure(NSError(
                    domain: "RunProcess", code: -2,
                    userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("output.cancelled", comment: "")])))
                return
            }

            let status = task.terminationStatus
            if status == 9 || status == 15 {
                let format = isSudo
                    ? NSLocalizedString("error.timeout.short", comment: "")
                    : NSLocalizedString("error.timeout", comment: "")
                let message = String(format: format, timeout)
                completion(.failure(NSError(domain: "RunProcess", code: 15,
                                            userInfo: [NSLocalizedDescriptionKey: message])))
                return
            }

            if status == 0 {
                completion(.success(trimmed))
                return
            }

            if isSudo {
                let lower = trimmed.lowercased()
                let isPasswordError = lower.contains("sorry") ||
                    lower.contains("incorrect password") ||
                    (lower.contains("password") && lower.contains("try again"))
                if isPasswordError {
                    completion(.failure(NSError(
                        domain: "RunProcess", code: Int(status),
                        userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("error.sudo.wrong.password", comment: "")])))
                    return
                }
            }

            let format = NSLocalizedString("error.exit.code", comment: "")
            let message = trimmed.isEmpty ? String(format: format, status) : trimmed
            completion(.failure(NSError(domain: "RunProcess", code: Int(status),
                                        userInfo: [NSLocalizedDescriptionKey: message])))
        }
    }

    private func killProcessGroup(_ task: Process) {
        let pid = task.processIdentifier
        if pid > 0 {
            kill(-pid, SIGTERM)
            let killPid = pid
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
                kill(-killPid, SIGKILL)
            }
        } else if task.isRunning {
            task.terminate()
        }
    }

    private func waitUntilExit(_ task: Process, timeout: TimeInterval) {
        let deadline = Date().addingTimeInterval(timeout)
        while task.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.02)
        }
        if task.isRunning {
            killProcessGroup(task)
        }
    }

    private func cleanup() {
        stateQueue.sync {
            self.state.task = nil
            self.state.timeoutWork = nil
            self.state.cancelled = false
        }
    }

    func cancelCurrentTask() {
        stateQueue.sync {
            self.state.cancelled = true
            self.state.timeoutWork?.cancel()
            self.state.timeoutWork = nil
            if let task = self.state.task, task.isRunning {
                self.killProcessGroup(task)
            }
            self.state.task = nil
        }
    }
}
