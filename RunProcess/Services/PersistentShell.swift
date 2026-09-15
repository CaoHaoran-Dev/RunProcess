//
//  PersistentShell.swift
//  RunProcess
//
//  Created by Haoran on 2026/9/13.
//

import Foundation

/// 持久 zsh 会话
///
/// 保持一个长驻的 zsh 进程，命令通过 stdin 喂入，输出从 stdout 读回。
/// 用 UUID 标记判断命令结束，同时同步 cwd。
final class PersistentShell {
    
    // MARK: - 状态
    
    private var process: Process?
    private var stdinPipe: Pipe?
    private var stdoutPipe: Pipe?
    private var stderrPipe: Pipe?
    
    private var outputBuffer = Data()
    private var errorBuffer = Data()
    private let bufferLock = NSLock()
    
    /// 当前正在等待的命令标记
    private var pendingMarker: String?
    private var pendingCompletion: ((Result<ShellResult, Error>) -> Void)?
    private var pendingTimeoutWork: DispatchWorkItem?
    
    /// 当前 cwd（由 shell 每次命令后同步）
    private(set) var currentWorkingDirectory: String
    
    /// 会话是否存活
    private(set) var isAlive: Bool = false
    
    /// 命令执行串行队列
    private let queue = DispatchQueue(label: "com.linran.RunProcess.persistent-shell", qos: .userInitiated)
    
    /// 会话崩溃回调
    var onCrash: (() -> Void)?
    
    /// cwd 变化回调
    var onCWDChange: ((String) -> Void)?
    
    /// 输出上限
    private let maxOutputSize = 10 * 1024 * 1024
    
    // MARK: - 结果类型
    
    struct ShellResult {
        let output: String
        let exitCode: Int32
        let cwd: String
    }
    
    // MARK: - Init
    
    init(initialCWD: String) {
        self.currentWorkingDirectory = initialCWD
    }
    
    deinit {
        teardown()
    }
    
    // MARK: - 启动 / 停止
    
    /// 启动持久 shell。如果已启动则不重复启动。
    func start() throws {
        guard !isAlive else { return }
        
        let task = Process()
        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        
        task.currentDirectoryURL = URL(fileURLWithPath: currentWorkingDirectory)
        task.launchPath = "/bin/zsh"
        // -l: 加载 ~/.zprofile；-f: 跳过 ~/.zshenv
        // 然后手动 source ~/.zshrc，并关闭 prompt / 回显
        task.arguments = ["-l", "-c", Self.bootstrapScript]
        
        task.standardInput = stdinPipe
        task.standardOutput = stdoutPipe
        task.standardError = stderrPipe
        
        self.process = task
        self.stdinPipe = stdinPipe
        self.stdoutPipe = stdoutPipe
        self.stderrPipe = stderrPipe
        
        // stdout 累积
        stdoutPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            guard let self = self else { return }
            let data = handle.availableData
            guard !data.isEmpty else { return }
            self.bufferLock.lock()
            if self.outputBuffer.count + data.count <= self.maxOutputSize {
                self.outputBuffer.append(data)
            }
            self.bufferLock.unlock()
            self.tryExtractResult()
        }
        
        // stderr 累积
        stderrPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            guard let self = self else { return }
            let data = handle.availableData
            guard !data.isEmpty else { return }
            self.bufferLock.lock()
            if self.errorBuffer.count + data.count <= self.maxOutputSize {
                self.errorBuffer.append(data)
            }
            self.bufferLock.unlock()
        }
        
        // 进程终止检测
        task.terminationHandler = { [weak self] _ in
            guard let self = self else { return }
            self.queue.async {
                self.isAlive = false
                let completion = self.pendingCompletion
                self.pendingCompletion = nil
                self.pendingTimeoutWork?.cancel()
                self.pendingTimeoutWork = nil
                if let completion = completion {
                    completion(.failure(NSError(
                        domain: "RunProcess",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "会话已结束"]
                    )))
                }
                DispatchQueue.main.async {
                    self.onCrash?()
                }
            }
        }
        
        try task.run()
        isAlive = true
    }
    
    /// 关闭持久 shell
    func teardown() {
        stdoutPipe?.fileHandleForReading.readabilityHandler = nil
        stderrPipe?.fileHandleForReading.readabilityHandler = nil
        
        if let process = process, process.isRunning {
            process.terminate()
        }
        
        process = nil
        stdinPipe = nil
        stdoutPipe = nil
        stderrPipe = nil
        
        bufferLock.lock()
        outputBuffer.removeAll()
        errorBuffer.removeAll()
        bufferLock.unlock()
        
        isAlive = false
    }
    
    /// 重建会话（崩溃后调用）
    func restart() throws {
        teardown()
        try start()
    }
    
    // MARK: - 执行命令
    
    /// 异步执行一条命令
    /// - Parameters:
    ///   - command: 用户命令（不含标记）
    ///   - timeout: 超时秒数
    ///   - completion: 结果回调，主线程
    func execute(_ command: String, timeout: TimeInterval, completion: @escaping (Result<ShellResult, Error>) -> Void) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            guard self.isAlive, let stdin = self.stdinPipe?.fileHandleForWriting else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(
                        domain: "RunProcess",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "会话未启动"]
                    )))
                }
                return
            }
            
            // 已有命令在执行
            guard self.pendingCompletion == nil else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(
                        domain: "RunProcess",
                        code: -2,
                        userInfo: [NSLocalizedDescriptionKey: "会话正忙"]
                    )))
                }
                return
            }
            
            let marker = "__RUNPROCESS_DONE_\(UUID().uuidString)__"
            self.pendingMarker = marker
            self.pendingCompletion = completion
            
            // 清空缓冲
            self.bufferLock.lock()
            self.outputBuffer.removeAll()
            self.errorBuffer.removeAll()
            self.bufferLock.unlock()
            
            // 拼接：命令 + 标记 + cwd
            // 标记输出到 stdout：__RUNPROCESS_DONE_<uuid>__:<exit>:<cwd>
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
                        domain: "RunProcess",
                        code: -3,
                        userInfo: [NSLocalizedDescriptionKey: "命令编码失败"]
                    )))
                }
                return
            }
            
            do {
                try stdin.write(contentsOf: data)
            } catch {
                self.pendingCompletion = nil
                self.pendingMarker = nil
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            // 超时
            let timeoutWork = DispatchWorkItem { [weak self] in
                self?.handleTimeout(timeout: timeout)
            }
            self.pendingTimeoutWork = timeoutWork
            self.queue.asyncAfter(deadline: .now() + timeout, execute: timeoutWork)
        }
    }
    
    // MARK: - 内部：结果提取
    
    private func tryExtractResult() {
        queue.async { [weak self] in
            guard let self = self else { return }
            guard let marker = self.pendingMarker else { return }
            
            self.bufferLock.lock()
            let text = String(data: self.outputBuffer, encoding: .utf8) ?? ""
            self.bufferLock.unlock()
            
            // 查找标记：<marker>:<exit>:<cwd>
            guard let range = text.range(of: "\(marker):") else { return }
            
            // 找标记行的结束
            let afterMarker = text[range.upperBound...]
            guard let lineEnd = afterMarker.firstIndex(of: "\n") else { return }
            let payload = afterMarker[..<lineEnd]
            
            // payload 形如 "<exit>:<cwd>"
            let parts = payload.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2,
                  let exitCode = Int32(parts[0]) else { return }
            let cwd = String(parts[1])
            
            // 提取命令输出（标记之前的部分，去掉最后多余的换行）
            var output = String(text[..<range.lowerBound])
            // 移除尾部空行
            while output.hasSuffix("\n") {
                output.removeLast()
            }
            
            // stderr 附加
            self.bufferLock.lock()
            let errText = String(data: self.errorBuffer, encoding: .utf8) ?? ""
            self.bufferLock.unlock()
            if !errText.isEmpty {
                output += (output.isEmpty ? "" : "\n") + errText.trimmingCharacters(in: .newlines)
            }
            
            // 清状态
            self.pendingMarker = nil
            let completion = self.pendingCompletion
            self.pendingCompletion = nil
            self.pendingTimeoutWork?.cancel()
            self.pendingTimeoutWork = nil
            
            // 更新 cwd
            self.currentWorkingDirectory = cwd
            DispatchQueue.main.async {
                self.onCWDChange?(cwd)
            }
            
            let result = ShellResult(output: output, exitCode: exitCode, cwd: cwd)
            
            DispatchQueue.main.async {
                if exitCode == 0 {
                    completion?(.success(result))
                } else {
                    let message = output.isEmpty ? "退出码: \(exitCode)" : output
                    completion?(.failure(NSError(
                        domain: "RunProcess",
                        code: Int(exitCode),
                        userInfo: [NSLocalizedDescriptionKey: message]
                    )))
                }
            }
        }
    }
    
    // MARK: - 内部：超时
    
    private func handleTimeout(timeout: TimeInterval) {
        // 会话模式下不能 kill shell，改为发 SIGINT
        // 用 zsh 的交互式中断：写入 Ctrl+C 字符
        if let stdin = stdinPipe?.fileHandleForWriting {
            // \x03 = Ctrl+C
            try? stdin.write(contentsOf: Data([0x03]))
        }
        
        // 2 秒后如果还没结束，强制重建
        queue.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self else { return }
            guard self.pendingCompletion != nil else { return }
            
            // 还在等，说明 SIGINT 没生效，重建会话
            self.pendingMarker = nil
            let completion = self.pendingCompletion
            self.pendingCompletion = nil
            
            let error = NSError(
                domain: "RunProcess",
                code: 15,
                userInfo: [NSLocalizedDescriptionKey: "命令执行超时（超过 \(Int(timeout)) 秒）"]
            )
            
            try? self.restart()
            
            DispatchQueue.main.async {
                completion?(.failure(error))
            }
        }
    }
    
    // MARK: - Bootstrap
    
    /// 启动脚本：加载用户配置，关闭 prompt / 回显
    private static let bootstrapScript = """
    # 加载用户 zshrc（如果存在）
    if [ -f ~/.zshrc ]; then
        source ~/.zshrc
    fi
    # 关闭 prompt 和回显
    unsetopt PROMPT_SP 2>/dev/null
    unsetopt PROMPT_CR 2>/dev/null
    PROMPT=''
    RPROMPT=''
    PS1=''
    # 关闭 history 写入，避免污染用户的 .zsh_history
    unsetopt INC_APPEND_HISTORY 2>/dev/null
    unsetopt SHARE_HISTORY 2>/dev/null
    setopt NO_HIST_VERIFY 2>/dev/null
    # 读循环
    while IFS= read -r __rp_line; do
        eval "$__rp_line"
    done
    """
}
