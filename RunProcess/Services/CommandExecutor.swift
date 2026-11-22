//
//  CommandExecutor.swift
//  RunProcess
//
//  Created by Haoran on 2026/8/19.
//

import Foundation

class CommandExecutor {
    static let shared = CommandExecutor()

    /// 单次执行的句柄。调用方拿它来精确取消自己的那一次执行，
    /// 不会误伤同一时刻其它窗口 / 快捷指令发起的执行。
    final class Execution {
        fileprivate let token = UUID()
    }

    /// 每次执行各自一份状态，按 token 索引。
    private struct State {
        var task: Process?
        var timeoutWork: DispatchWorkItem?
        var cancelled = false
    }

    private var executions: [UUID: State] = [:]
    private let stateQueue = DispatchQueue(label: "com.runprocess.executor.state", qos: .userInitiated)
    private let maxOutputSize = 10 * 1024 * 1024 // 10MB

    private init() {}

    // MARK: - Public

    @discardableResult
    func execute(_ input: String, timeout: TimeInterval = 10.0,
                 completion: @escaping (Result<String, Error>) -> Void) -> Execution {
        let execution = Execution()
        let token = execution.token

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
            self.executions[token] = State(task: task)
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
            return execution
        }

        collectOutput(token: token, task: task,
                      outputPipe: outputPipe, errorPipe: errorPipe,
                      timeout: timeout, isSudo: false, completion: completion)
        return execution
    }

    @discardableResult
    func executeWithSudo(_ command: String, password: String, timeout: TimeInterval = 10.0,
                         completion: @escaping (Result<String, Error>) -> Void) -> Execution {
        let execution = Execution()
        let token = execution.token

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
            self.executions[token] = State(task: task)
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
            return execution
        }

        let passwordData = "\(password)\n".data(using: .utf8)!
        inputPipe.fileHandleForWriting.write(passwordData)
        inputPipe.fileHandleForWriting.closeFile()

        collectOutput(token: token, task: task,
                      outputPipe: outputPipe, errorPipe: errorPipe,
                      timeout: timeout, isSudo: true, completion: completion)
        return execution
    }

    // MARK: - PATH 拼接

    /// 用单引号包裹自定义路径，避免含空格时被拆成多个 PATH 段。
    /// 例：`/Users/a b/bin` → `export PATH="$PATH:'/Users/a b/bin'"; ...`
    ///
    /// 与 `Session` / `PersistentShell` 保持一致：用户关闭注入、或当前 shell 不是 zsh 时，
    /// `AppSettings.customPathEnabled` 返回 false，此时不追加自定义 PATH。
    private static func wrapWithCustomPath(_ command: String) -> String {
        guard AppSettings.customPathEnabled else { return command }

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
                } else {
                    // Data 没有 hasSuffix，转成 String 检查尾部
                    let warningStr = "\n[⚠️ 输出过长，已截断]"
                    let tailStr = String(decoding: outputData.suffix(100), as: UTF8.self)
                    if !tailStr.contains(warningStr) {
                        outputData.append(Data(warningStr.utf8))
                    }
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
                } else {
                    // Data 没有 hasSuffix，转成 String 检查尾部
                    let warningStr = "\n[⚠️ 输出过长，已截断]"
                    let tailStr = String(decoding: errorData.suffix(100), as: UTF8.self)
                    if !tailStr.contains(warningStr) {
                        errorData.append(Data(warningStr.utf8))
                    }
                }
                dataLock.unlock()
            }
        }

        let timeoutWork = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            // 只有仍是本次执行的进程才允许超时处理，
            // 防止旧执行的超时任务误杀新进程。
            let isCurrent: Bool = self.stateQueue.sync {
                self.executions[token]?.task === task
            }
            guard isCurrent else { return }

            timedOut.set()
            self.killProcessGroup(task)

            outputPipe.fileHandleForReading.readabilityHandler = nil
            errorPipe.fileHandleForReading.readabilityHandler = nil

            outputLeave.leave(group)
            errorLeave.leave(group)

            self.stateQueue.sync {
                if self.executions[token]?.task === task {
                    self.executions[token]?.timeoutWork = nil
                    self.executions[token]?.task = nil
                }
            }
        }

        stateQueue.sync {
            if self.executions[token]?.task === task {
                self.executions[token]?.timeoutWork = timeoutWork
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

            // 移出登记表并取回取消标记：只有本次执行的 notify 会走到这里，
            // 所以无论是否被取消，这次执行的结果都必须回调给调用方。
            let wasCancelled: Bool = self.stateQueue.sync {
                let state = self.executions.removeValue(forKey: token)
                return state?.cancelled ?? false
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
                let message = String(format: format, Int(timeout))
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
                        ? String(format: format, Int(status))
                        : trimmed
                    result = .failure(NSError(
                        domain: "RunProcess", code: Int(status),
                        userInfo: [NSLocalizedDescriptionKey: message]))
                }
            }

            DispatchQueue.main.async { completion(result) }
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
            _ = self.executions.removeValue(forKey: token)
        }
    }

    /// 取消指定的一次执行。若该执行已结束，调用无副作用。
    func cancel(_ execution: Execution) {
        stateQueue.sync {
            guard var state = self.executions[execution.token] else { return }
            state.cancelled = true
            state.timeoutWork?.cancel()
            state.timeoutWork = nil
            if let task = state.task, task.isRunning {
                self.killProcessGroup(task)
            }
            state.task = nil
            self.executions[execution.token] = state
        }
    }

    /// 取消所有正在进行的执行（退出 App 等场景使用）。
    func cancelAll() {
        stateQueue.sync {
            for (token, var state) in self.executions {
                state.cancelled = true
                state.timeoutWork?.cancel()
                state.timeoutWork = nil
                if let task = state.task, task.isRunning {
                    self.killProcessGroup(task)
                }
                state.task = nil
                self.executions[token] = state
            }
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
