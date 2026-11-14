//
//  RemoteExecutor.swift
//  RunProcess
//
//  Created by Haoran on 2026/11/7.
//

#if BETA

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
        } catch {
            // 第一次失败（可能是沙盒环境冷启动导致 WebSocket 状态异常），清理后重试一次
            print("⚠️ [Remote] Execution failed, retrying once. Error: \(error.localizedDescription)")
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
        } catch {
            await RemoteConnectionManager.shared.removeChannel(for: host.id, channel: channel)
            throw error
        }
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
        if let error {
            cont.resume(throwing: NSError(
                domain: "RunProcess.Remote",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: error]))
            return
        }

        if exitCode != 0 {
            let message: String
            if text.isEmpty {
                message = String(
                    format: NSLocalizedString("error.exit.code", comment: ""),
                    exitCode)
            } else {
                message = text
            }
            cont.resume(throwing: NSError(
                domain: "RunProcess.Remote",
                code: Int(exitCode),
                userInfo: [NSLocalizedDescriptionKey: message]))
            return
        }

        cont.resume(returning: text)
    }
}

#endif
