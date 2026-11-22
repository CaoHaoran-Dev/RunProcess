//
//  RemoteExecutor.swift
//  RunProcess
//
//  Created by Haoran on 2026/11/7.
//


import Foundation
import RemoteLinkKit
import RemoteProcessProtocol

nonisolated final class RemoteExecutor {

    nonisolated init() {}

    func execute(command: String,
                 on host: RemoteHost,
                 kind: RemoteExecPayload.Kind = .command,
                 timeout: TimeInterval = 10) async throws -> String {

        // 防止 Shortcuts 进程复用旧的脏连接
        await RemoteConnectionManager.shared.removeChannel(for: host.id)
        try? await Task.sleep(nanoseconds: 200_000_000)

        do {
            return try await _execute(command: command, on: host, kind: kind, timeout: timeout)
        } catch let error as RemoteExecError where error.isRetryable {
            // 仅连接层错误可重试；命令已执行（非零退出码）绝不重试，
            // 避免 rm / deploy 之类命令被执行两次。
            print("⚠️ [Remote] Connection error, retrying once. Error: \(error)")
            await RemoteConnectionManager.shared.removeChannel(for: host.id)
            try? await Task.sleep(nanoseconds: 500_000_000)
            return try await _execute(command: command, on: host, kind: kind, timeout: timeout)
        }
    }
    
    private func _execute(command: String,
                          on host: RemoteHost,
                          kind: RemoteExecPayload.Kind,
                          timeout: TimeInterval) async throws -> String {
        
        let channel = try await RemoteConnectionManager.shared.makeChannel(for: host)
        let commandId = UUID().uuidString
        let buffer = OutputBuffer()

        await channel.setOnServerMessage { msg in
            switch msg {
            case .output(let id, _, let data):
                if id == commandId { buffer.append(data) }
            case .done(let id, let exit, _):
                if id == commandId { buffer.finish(exitCode: exit) }
            case .error(let id, let message):
                if id == commandId || id == nil { buffer.finish(error: message) }
            default:
                break
            }
        }

        await channel.setOnError { error in
            buffer.finish(error: error.localizedDescription)
        }

        do {
            // 👇 核心修复：先发一个 ping 强制打通底层 WebSocket，并等待 300ms。
            // 在 Shortcuts 的 BackgroundShortcutRunner 沙盒里，建立连接后直接发复杂包容易卡死。
            let pingMsg = RemoteProcessProtocol.ClientMessage.ping(timestamp: Date())
            try await channel.send(pingMsg)
            try await Task.sleep(nanoseconds: 300_000_000)

            if kind == .command {
                let msg: RemoteProcessProtocol.ClientMessage = .exec(
                    id: commandId,
                    cmd: command,
                    timeout: timeout
                )
                try await channel.send(msg)
            } else {
                let payload = RemoteExecPayload(
                    id: commandId,
                    cmd: command,
                    kind: kind.rawValue,
                    timeout: timeout
                )
                let data = try JSONEncoder().encode(payload)
                let msg: RemoteProcessProtocol.ClientMessage = .custom(
                    type: "exec-v2",
                    payload: data
                )
                try await channel.send(msg)
            }

            // 服务端超时会发 .error；本地 +2 秒兜底，防服务端静默崩溃。
            let result = try await buffer.waitForResult(timeout: timeout + 2)
            await RemoteConnectionManager.shared.removeChannel(for: host.id, channel: channel)
            return result
        } catch let error as RemoteExecError {
            // 业务层已分类的错误（命令非零退出、服务端错误、连接错误）原样抛出。
            await RemoteConnectionManager.shared.removeChannel(for: host.id, channel: channel)
            throw error
        } catch {
            // channel.send / JSONEncoder / waitForResult 之外的 RemoteLinkKit 错误
            // 一律视为连接层错误，允许上层重试一次。
            await RemoteConnectionManager.shared.removeChannel(for: host.id, channel: channel)
            throw RemoteExecError.connection(error.localizedDescription)
        }
    }
}

/// 远程执行错误。区分「连接层可重试」与「命令已执行不可重试」。
nonisolated enum RemoteExecError: Error, LocalizedError {
    /// 连接/握手/传输层错误，可安全重试。
    case connection(String)
    /// 命令已在远端执行并返回非零退出码，不可重试。
    case commandFailed(exitCode: Int32, message: String)
    /// 服务端返回业务错误或超时，不可重试。
    case server(String)

    var isRetryable: Bool {
        if case .connection = self { return true }
        return false
    }

    var errorDescription: String? {
        switch self {
        case .connection(let m): return m
        case .commandFailed(_, let m): return m
        case .server(let m): return m
        }
    }

    var exitCode: Int32? {
        if case .commandFailed(let code, _) = self { return code }
        return nil
    }
}

// MARK: - OutputBuffer

private nonisolated final class OutputBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()
    private var isFinished = false
    private var error: String?
    private var exitCode: Int32 = 0
    private var continuation: CheckedContinuation<String, Error>?

    func append(_ chunk: Data) {
        lock.withLock { data.append(chunk) }
    }

    func finish(exitCode: Int32) {
        let shouldResume: Bool = lock.withLock {
            guard !isFinished else { return false }
            self.exitCode = exitCode
            self.isFinished = true
            return true
        }
        if shouldResume { resumeIfPossible() }
    }

    func finish(error: String) {
        let shouldResume: Bool = lock.withLock {
            guard !isFinished else { return false }
            self.error = error
            self.isFinished = true
            return true
        }
        if shouldResume { resumeIfPossible() }
    }

    func waitForResult(timeout: TimeInterval) async throws -> String {
        return try await withCheckedThrowingContinuation { cont in
            let snapshot: (finished: Bool, text: String, error: String?, exitCode: Int32) = lock.withLock {
                (isFinished,
                 String(data: data, encoding: .utf8) ?? "",
                 error,
                 exitCode)
            }

            if snapshot.finished {
                Self.resume(cont,
                            text: snapshot.text,
                            error: snapshot.error,
                            exitCode: snapshot.exitCode)
                return
            }

            lock.withLock { self.continuation = cont }

            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) { [weak self] in
                guard let self else { return }
                self.finish(error: NSLocalizedString("error.remote.timeout", comment: ""))
            }
        }
    }

    private func resumeIfPossible() {
        let snapshot: (cont: CheckedContinuation<String, Error>?, text: String, error: String?, exitCode: Int32) = lock.withLock {
            guard let c = continuation else { return (nil, "", nil, 0) }
            self.continuation = nil
            let out = String(data: data, encoding: .utf8)
                ?? String(decoding: data, as: UTF8.self)
            return (c, out, error, exitCode)
        }

        guard let cont = snapshot.cont else { return }
        Self.resume(cont, text: snapshot.text, error: snapshot.error, exitCode: snapshot.exitCode)
    }

    private static func resume(_ cont: CheckedContinuation<String, Error>,
                               text: String,
                               error: String?,
                               exitCode: Int32) {
        // 服务端返回的 error 属于业务/超时错误，不可重试。
        if let error {
            cont.resume(throwing: RemoteExecError.server(error))
            return
        }

        // 命令已执行，非零退出码不可重试。
        if exitCode != 0 {
            let message: String
            if text.isEmpty {
                message = String(
                    format: NSLocalizedString("error.exit.code", comment: ""),
                    Int(exitCode))
            } else {
                message = text
            }
            cont.resume(throwing: RemoteExecError.commandFailed(
                exitCode: exitCode, message: message))
            return
        }
        
        cont.resume(returning: text)
    }
}

