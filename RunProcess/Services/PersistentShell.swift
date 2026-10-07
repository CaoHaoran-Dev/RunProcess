//
//  PersistentShell.swift
//  RunProcess
//
//  Created by Haoran on 2026/9/13.
//

import Foundation

final class PersistentShell {

    struct ShellResult {
        let output: String
        let exitCode: Int32
        let cwd: String
    }

    // MARK: - State

    private var process: Process?
    private var stdinPipe: Pipe?
    private var stdoutPipe: Pipe?
    private var stderrPipe: Pipe?

    private var outputBuffer = Data()
    private var errorBuffer = Data()

    private var pendingMarker: String?
    private var pendingCompletion: ((Result<ShellResult, Error>) -> Void)?
    private var pendingTimeoutWork: DispatchWorkItem?

    private var suppressCrashCallback = false

    private(set) var currentWorkingDirectory: String
    private(set) var isAlive: Bool = false

    private let queue = DispatchQueue(label: "com.runprocess.persistent-shell", qos: .userInitiated)
    private let maxOutputSize = 10 * 1024 * 1024

    var onCrash: (() -> Void)?
    var onCWDChange: ((String) -> Void)?

    init(initialCWD: String) {
        self.currentWorkingDirectory = initialCWD
    }

    deinit {
        stdoutPipe?.fileHandleForReading.readabilityHandler = nil
        stderrPipe?.fileHandleForReading.readabilityHandler = nil
        if let p = process, p.isRunning { p.terminate() }
    }

    // MARK: - Start / Stop

    func start() throws {
        var thrown: Error?
        let sem = DispatchSemaphore(value: 0)
        queue.async { [weak self] in
            guard let self = self else { sem.signal(); return }
            do {
                try self.startLocked()
            } catch {
                thrown = error
            }
            sem.signal()
        }
        sem.wait()
        if let e = thrown { throw e }
    }

    private func startLocked() throws {
        guard !isAlive else { return }

        let task = Process()
        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        task.currentDirectoryURL = URL(fileURLWithPath: currentWorkingDirectory)
        task.launchPath = "/bin/zsh"

        // ✅ 只把用户自定义路径替换进脚本，让 zsh 自己加载 .zshrc 的 PATH，
        //    bootstrap 只追加用户路径，不覆盖。
        let customPath = PathStore.shared.customPathString()
        let script = Self.bootstrapScript.replacingOccurrences(
            of: "__RP_CUSTOM_PATH__",
            with: customPath
        )
        task.arguments = ["-l", "-c", script]

        task.standardInput = stdinPipe
        task.standardOutput = stdoutPipe
        task.standardError = stderrPipe

        // ✅ 不再设置 task.environment["PATH"]，让 zsh 自己从 shell 配置里加载 PATH。
        //    否则会覆盖掉用户 .zshrc / .zprofile 里的 PATH。

        self.process = task
        self.stdinPipe = stdinPipe
        self.stdoutPipe = stdoutPipe
        self.stderrPipe = stderrPipe

        stdoutPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            guard let self = self else { return }
            let data = handle.availableData
            guard !data.isEmpty else { return }
            self.queue.async {
                if self.outputBuffer.count + data.count <= self.maxOutputSize {
                    self.outputBuffer.append(data)
                }
                self.tryExtractResultLocked()
            }
        }

        stderrPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            guard let self = self else { return }
            let data = handle.availableData
            guard !data.isEmpty else { return }
            self.queue.async {
                if self.errorBuffer.count + data.count <= self.maxOutputSize {
                    self.errorBuffer.append(data)
                }
            }
        }

        task.terminationHandler = { [weak self] _ in
            guard let self = self else { return }
            self.queue.async {
                self.isAlive = false
                let completion = self.pendingCompletion
                self.pendingCompletion = nil
                self.pendingMarker = nil
                self.pendingTimeoutWork?.cancel()
                self.pendingTimeoutWork = nil

                let shouldNotify = !self.suppressCrashCallback
                self.suppressCrashCallback = false

                if let completion = completion {
                    DispatchQueue.main.async {
                        completion(.failure(NSError(
                            domain: "RunProcess", code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "会话已结束"])))
                    }
                }
                if shouldNotify {
                    DispatchQueue.main.async { self.onCrash?() }
                }
            }
        }

        try task.run()
        let pid = task.processIdentifier
        if pid > 0 { _ = setpgid(pid, pid) }

        isAlive = true
    }

    func teardown() {
        let sem = DispatchSemaphore(value: 0)
        queue.async { [weak self] in
            guard let self = self else { sem.signal(); return }
            self.teardownLocked()
            sem.signal()
        }
        sem.wait()
    }

    private func teardownLocked() {
        self.suppressCrashCallback = true
        self.stdoutPipe?.fileHandleForReading.readabilityHandler = nil
        self.stderrPipe?.fileHandleForReading.readabilityHandler = nil

        if let process = self.process, process.isRunning {
            let pid = process.processIdentifier
            if pid > 0 {
                kill(-pid, SIGTERM)
                let deadline = Date().addingTimeInterval(0.2)
                while process.isRunning && Date() < deadline {
                    Thread.sleep(forTimeInterval: 0.02)
                }
                if process.isRunning { kill(-pid, SIGKILL) }
            } else {
                process.terminate()
            }
        }

        self.process = nil
        self.stdinPipe = nil
        self.stdoutPipe = nil
        self.stderrPipe = nil

        self.outputBuffer.removeAll()
        self.errorBuffer.removeAll()
        self.pendingMarker = nil
        self.pendingCompletion = nil
        self.pendingTimeoutWork?.cancel()
        self.pendingTimeoutWork = nil

        self.isAlive = false
    }

    func restart() throws {
        teardown()
        try start()
    }

    // MARK: - Execute

    func execute(_ command: String, timeout: TimeInterval,
                 completion: @escaping (Result<ShellResult, Error>) -> Void) {
        queue.async { [weak self] in
            guard let self = self else { return }

            guard self.isAlive, let stdin = self.stdinPipe?.fileHandleForWriting else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(
                        domain: "RunProcess", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "会话未启动"])))
                }
                return
            }

            guard self.pendingCompletion == nil else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(
                        domain: "RunProcess", code: -2,
                        userInfo: [NSLocalizedDescriptionKey: "会话正忙"])))
                }
                return
            }

            let marker = "__RUNPROCESS_DONE_\(UUID().uuidString)__"
            self.pendingMarker = marker
            self.pendingCompletion = completion

            self.outputBuffer.removeAll()
            self.errorBuffer.removeAll()

            let wrapped = """
            \(command)
            __rp_exit=$?
            printf '\\n\(marker):%d:%s\\n' "$__rp_exit" "$(pwd)"
            """

            guard let data = (wrapped + "\n").data(using: .utf8) else {
                self.pendingCompletion = nil
                self.pendingMarker = nil
                DispatchQueue.main.async {
                    completion(.failure(NSError(
                        domain: "RunProcess", code: -3,
                        userInfo: [NSLocalizedDescriptionKey: "命令编码失败"])))
                }
                return
            }

            do {
                try stdin.write(contentsOf: data)
            } catch {
                self.pendingCompletion = nil
                self.pendingMarker = nil
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }

            let timeoutWork = DispatchWorkItem { [weak self] in
                self?.handleTimeout(timeout: timeout)
            }
            self.pendingTimeoutWork = timeoutWork
            self.queue.asyncAfter(deadline: .now() + timeout, execute: timeoutWork)
        }
    }

    // MARK: - Result extraction

    private func tryExtractResultLocked() {
        guard let marker = pendingMarker else { return }

        let markerBytes = Data((marker + ":").utf8)
        guard let range = outputBuffer.range(of: markerBytes) else { return }

        let afterMarker = range.upperBound
        guard let lineEndOffset = outputBuffer[afterMarker...].firstIndex(of: 0x0A) else { return }
        let payload = outputBuffer[afterMarker..<lineEndOffset]
        let payloadStr = String(data: payload, encoding: .utf8) ?? ""

        let parts = payloadStr.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2, let exitCode = Int32(parts[0]) else { return }
        let cwd = String(parts[1])

        var output = String(data: outputBuffer[..<range.lowerBound], encoding: .utf8) ?? ""
        while output.hasSuffix("\n") { output.removeLast() }

        let errText = String(data: errorBuffer, encoding: .utf8) ?? ""
        if !errText.isEmpty {
            output += (output.isEmpty ? "" : "\n") + errText.trimmingCharacters(in: .newlines)
        }

        pendingMarker = nil
        let completion = pendingCompletion
        pendingCompletion = nil
        pendingTimeoutWork?.cancel()
        pendingTimeoutWork = nil

        currentWorkingDirectory = cwd
        DispatchQueue.main.async { self.onCWDChange?(cwd) }

        let result = ShellResult(output: output, exitCode: exitCode, cwd: cwd)

        DispatchQueue.main.async {
            if exitCode == 0 {
                completion?(.success(result))
            } else {
                let message = output.isEmpty ? "退出码: \(exitCode)" : output
                completion?(.failure(NSError(
                    domain: "RunProcess", code: Int(exitCode),
                    userInfo: [NSLocalizedDescriptionKey: message])))
            }
        }
    }

    // MARK: - Timeout

    private func handleTimeout(timeout: TimeInterval) {
        guard pendingCompletion != nil else { return }

        if let stdin = stdinPipe?.fileHandleForWriting {
            try? stdin.write(contentsOf: Data([0x03]))
        }

        queue.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self else { return }
            guard self.pendingCompletion != nil else { return }

            self.pendingMarker = nil
            let completion = self.pendingCompletion
            self.pendingCompletion = nil
            self.pendingTimeoutWork?.cancel()
            self.pendingTimeoutWork = nil

            let error = NSError(
                domain: "RunProcess", code: 15,
                userInfo: [NSLocalizedDescriptionKey:
                    "命令执行超时（超过 \(Int(timeout)) 秒）"])

            self.suppressCrashCallback = true
            self.teardownLocked()
            do { try self.startLocked() } catch { /* ignore */ }

            DispatchQueue.main.async { completion?(.failure(error)) }
        }
    }

    // MARK: - Bootstrap

    private static let bootstrapScript = """
    if [ -f ~/.zshrc ]; then
        source ~/.zshrc
    fi
    # ✅ 追加用户自定义路径，不覆盖 .zshrc / .zprofile 里已经设好的 PATH
    if [ -n "__RP_CUSTOM_PATH__" ]; then
        export PATH="$PATH:__RP_CUSTOM_PATH__"
    fi
    unsetopt PROMPT_SP 2>/dev/null
    unsetopt PROMPT_CR 2>/dev/null
    PROMPT=''
    RPROMPT=''
    PS1=''
    unsetopt INC_APPEND_HISTORY 2>/dev/null
    unsetopt SHARE_HISTORY 2>/dev/null
    setopt NO_HIST_VERIFY 2>/dev/null
    while IFS= read -r __rp_line; do
        eval "$__rp_line"
    done
    """
}
