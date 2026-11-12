//
//  CommandExecutor.swift
//  RunProcess
//
//  Created by Haoran on 2026/8/19.
//

import Foundation

class CommandExecutor {
    static let shared = CommandExecutor()

    /// 每次执行的令牌。cancel 只杀匹配 token 的进程，避免
    /// 并发 execute 时「先杀后建」把新任务误杀或把旧任务变孤儿。
    private struct State {
        var token: UUID?
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

        let token = UUID()
        let task = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        task.currentDirectoryURL = URL(fileURLWithPath: AppSettings.resolvedWorkingDirectory)
        task.launchPath = "/bin/zsh"

        // 追加用户自定义路径，不覆盖 .zshrc / .zprofile 里已设好的 PATH。
        let wrappedCommand = Self.wrapWithCustomPath(input)

        task.arguments = ["-l", "-c", wrappedCommand]
        task.standardOutput = outputPipe
        task.standardError = errorPipe

        stateQueue.sync {
            self.state.token = token
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
            finish(token: token)
            DispatchQueue.main.async { completion(.failure(error)) }
            return
        }

        collectOutput(token: token, task: task,
                      outputPipe: outputPipe, errorPipe: errorPipe,
                      timeout: timeout, isSudo: false, completion: completion)
    }

    func executeWithSudo(_ command: String, password: String, timeout: TimeInterval = 10.0,
                         completion: @escaping (Result<String, Error>) -> Void) {
        cancelCurrentTask()

        let token = UUID()
        let task = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        let inputPipe = Pipe()

        task.currentDirectoryURL = URL(fileURLWithPath: AppSettings.resolvedWorkingDirectory)
        task.launchPath = "/usr/bin/sudo"

        let wrappedCommand = Self.wrapWithCustomPath(command)
        task.arguments = ["-S", "-k", "/bin/zsh", "-l", "-c", wrappedCommand]

        task.standardOutput = outputPipe
        task.standardError = errorPipe
        task.standardInput = inputPipe

        stateQueue.sync {
            self.state.token = token
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
            finish(token: token)
            DispatchQueue.main.async { completion(.failure(error)) }
            return
        }

        let passwordData = "\(password)\n".data(using: .utf8)!
        inputPipe.fileHandleForWriting.write(passwordData)
        inputPipe.fileHandleForWriting.closeFile()

        collectOutput(token: token, task: task,
                      outputPipe: outputPipe, errorPipe: errorPipe,
                      timeout: timeout, isSudo: true, completion: completion)
    }

    // MARK: - PATH 拼接

    /// 用单引号包裹自定义路径，避免含空格时被拆成多个 PATH 段。
    /// 例：`/Users/a b/bin` → `export PATH="$PATH:'/Users/a b/bin'"; ...`
    private static func wrapWithCustomPath(_ command: String) -> String {
        let customPath = PathStore.shared.customPathString()
        guard !customPath.isEmpty else { return command }

        let escaped = customPath.replacingOccurrences(of: "'", with: "'\\''")
        return "export PATH=\"$PATH:'\(escaped)'\"; \(command)"
    }

    // MARK: - 输出收集

    private func collectOutput(token: UUID,
                               task: Process,
                               outputPipe: Pipe, errorPipe: Pipe,
                               timeout: TimeInterval,
                               isSudo: Bool,
                               completion: @escaping (Result<String, Error>) -> Void) {
        var outputData = Data()
        var errorData = Data()
        let dataLock = NSLock()

        let group = DispatchGroup()
        group.enter()
        group.enter()

        // 每个 pipe 各一个「只 leave 一次」的守卫，
        // 避免超时任务与 EOF 读同时 leave 造成 unbalanced crash。
        let outputLeave = LeaveOnce()
        let errorLeave = LeaveOnce()

        // 超时标志。超时任务置位，notify 里优先按它判定，
        // 不再靠 terminationStatus 反推（kill 与自然退出可能竞争）。
        let timedOut = Flag()

        let callbackQueue = DispatchQueue(label: "com.runprocess.executor.callback", qos: .userInitiated)

        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            callbackQueue.async {
                guard let self = self else { return }
                let data = handle.availableData
                if data.isEmpty {
                    outputLeave.leave(group)
                    return
                }
                dataLock.lock()
                if outputData.count + data.count <= self.maxOutputSize {
                    outputData.append(data)
                }
                dataLock.unlock()
            }
        }

        errorPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            callbackQueue.async {
                guard let self = self else { return }
                let data = handle.availableData
                if data.isEmpty {
                    errorLeave.leave(group)
                    return
                }
                dataLock.lock()
                if errorData.count + data.count <= self.maxOutputSize {
                    errorData.append(data)
                }
                dataLock.unlock()
            }
        }

        let timeoutWork = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            // 只有仍是当前令牌的执行才允许超时处理，
            // 防止旧执行的超时任务误杀新进程。
            let isCurrent: Bool = self.stateQueue.sync {
                self.state.token == token
            }
            guard isCurrent else { return }

            timedOut.set()
            self.killProcessGroup(task)

            outputPipe.fileHandleForReading.readabilityHandler = nil
            errorPipe.fileHandleForReading.readabilityHandler = nil

            outputLeave.leave(group)
            errorLeave.leave(group)

            self.stateQueue.sync {
                if self.state.token == token {
                    self.state.timeoutWork = nil
                    self.state.task = nil
                }
            }
        }

        stateQueue.sync {
            if self.state.token == token {
                self.state.timeoutWork = timeoutWork
            }
        }
        DispatchQueue.global(qos: .userInitiated)
            .asyncAfter(deadline: .now() + timeout, execute: timeoutWork)

        // 后台队列收尾，避免主线程被 waitUntilExit 阻塞。
        group.notify(queue: .global(qos: .userInitiated)) { [weak self] in
            guard let self = self else { return }
            timeoutWork.cancel()
            outputPipe.fileHandleForReading.readabilityHandler = nil
            errorPipe.fileHandleForReading.readabilityHandler = nil

            self.waitUntilExit(task, timeout: 3.0)

            let (wasCancelled, stillCurrent): (Bool, Bool) = self.stateQueue.sync {
                let c = self.state.cancelled
                let current = self.state.token == token
                if current {
                    self.state.task = nil
                    self.state.timeoutWork = nil
                    self.state.cancelled = false
                }
                return (c, current)
            }

            dataLock.lock()
            let outputStr = String(data: outputData, encoding: .utf8) ?? ""
            let errorStr = String(data: errorData, encoding: .utf8) ?? ""
            dataLock.unlock()

            let combined = outputStr + (errorStr.isEmpty ? "" : "\n" + errorStr)
            let trimmed = combined.trimmingCharacters(in: .newlines)

            let result: Result<String, Error>

            if timedOut.isSet {
                let format = isSudo
                    ? NSLocalizedString("error.timeout.short", comment: "")
                    : NSLocalizedString("error.timeout", comment: "")
                let message = String(format: format, timeout)
                result = .failure(NSError(
                    domain: "RunProcess", code: 15,
                    userInfo: [NSLocalizedDescriptionKey: message]))
            } else if wasCancelled {
                result = .failure(NSError(
                    domain: "RunProcess", code: -2,
                    userInfo: [NSLocalizedDescriptionKey:
                        NSLocalizedString("output.cancelled", comment: "")]))
            } else {
                let status = task.terminationStatus
                if status == 0 {
                    result = .success(trimmed)
                } else if isSudo, Self.isSudoPasswordError(trimmed) {
                    result = .failure(NSError(
                        domain: "RunProcess", code: Int(status),
                        userInfo: [NSLocalizedDescriptionKey:
                            NSLocalizedString("error.sudo.wrong.password", comment: "")]))
                } else {
                    let format = NSLocalizedString("error.exit.code", comment: "")
                    let message = trimmed.isEmpty
                        ? String(format: format, status)
                        : trimmed
                    result = .failure(NSError(
                        domain: "RunProcess", code: Int(status),
                        userInfo: [NSLocalizedDescriptionKey: message]))
                }
            }

            // 只有当前令牌的执行才回写 completion，
            // 旧执行的迟到回调直接丢弃。
            guard stillCurrent || self.isCompletionStillRelevant(token: token) else { return }
            DispatchQueue.main.async { completion(result) }
        }
    }

    private func isCompletionStillRelevant(token: UUID) -> Bool {
        // 执行已结束（state.token 被清理成 nil）时仍应回调，
        // 因为 notify 是本执行的唯一结果出口。
        // 只有「state.token 已被别的执行占用」才丢弃。
        stateQueue.sync {
            self.state.token == nil || self.state.token == token
        }
    }

    private static func isSudoPasswordError(_ text: String) -> Bool {
        let lower = text.lowercased()
        return lower.contains("sorry")
            || lower.contains("incorrect password")
            || (lower.contains("password") && lower.contains("try again"))
    }

    // MARK: - 进程控制

    private func killProcessGroup(_ task: Process) {
        let pid = task.processIdentifier
        if pid > 0 {
            kill(-pid, SIGTERM)
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
                kill(-pid, SIGKILL)
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

    private func finish(token: UUID) {
        stateQueue.sync {
            if self.state.token == token {
                self.state.task = nil
                self.state.timeoutWork = nil
                self.state.cancelled = false
                self.state.token = nil
            }
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
            self.state.token = nil
        }
    }
}

// MARK: - 辅助类型

/// 只允许 leave 一次，防止 DispatchGroup unbalanced crash。
private final class LeaveOnce: @unchecked Sendable {
    private let lock = NSLock()
    private var left = false

    func leave(_ group: DispatchGroup) {
        let should: Bool = lock.withLock {
            guard !left else { return false }
            left = true
            return true
        }
        if should { group.leave() }
    }
}

/// 线程安全的布尔标志。
private final class Flag: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false

    func set() {
        lock.withLock { value = true }
    }

    var isSet: Bool {
        lock.withLock { value }
    }
}
