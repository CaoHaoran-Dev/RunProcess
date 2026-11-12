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
        // 每次执行使用独立的 channel，避免多窗口并发时
        // setOnServerMessage / setOnError 被互相覆盖。
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
            // 普通命令走 .exec，保持与旧服务端兼容；
            // 其余 kind 走 .custom("exec-v2")。
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
            // 无论成败都要关闭独立 channel，避免连接泄漏。
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
        // 在锁内完成「检查是否已结束 + 写状态」，
        // 已结束后直接返回，避免超时路径覆盖状态。
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
            // 如果结果在 continuation 安装前就已产生
            //（例如 setOnError 早于 waitForResult），立即用已有状态 resume，
            // 否则任务会永久挂起。
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
                // finish(error:) 内部是原子的，无需先读 isFinished。
                self.finish(error: NSLocalizedString("error.remote.timeout", comment: ""))
            }
        }
    }

    private func resumeIfPossible() {
        let snapshot: (cont: CheckedContinuation<String, Error>?, text: String, error: String?, exitCode: Int32) = lock.withLock {
            guard let c = continuation else { return (nil, "", nil, 0) }
            self.continuation = nil
            let out = String(data: data, encoding: .utf8)
                ?? String(decoding: data, as: UTF8.self) // 宽容解码，二进制输出不丢
            return (c, out, error, exitCode)
        }

        guard let cont = snapshot.cont else { return }
        Self.resume(cont, text: snapshot.text, error: snapshot.error, exitCode: snapshot.exitCode)
    }

    // 非零退出码视为失败，与本地执行路径行为保持一致。
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
