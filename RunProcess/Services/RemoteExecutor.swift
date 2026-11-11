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
        let channel = try await RemoteConnectionManager.shared.getChannel(for: host)
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
            Task { @MainActor in
                RemoteConnectionManager.shared.removeChannel(for: host.id)
            }
        }
        
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
        
        return try await buffer.waitForResult(timeout: timeout + 2)
    }
}

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
        lock.withLock {
            self.exitCode = exitCode
            self.isFinished = true
        }
        resumeIfPossible()
    }
    
    func finish(error: String) {
        lock.withLock {
            self.error = error
            self.isFinished = true
        }
        resumeIfPossible()
    }
    
    func waitForResult(timeout: TimeInterval) async throws -> String {
        return try await withCheckedThrowingContinuation { cont in
            lock.withLock { self.continuation = cont }
            
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) { [weak self] in
                guard let self = self else { return }
                let finished = self.lock.withLock { self.isFinished }
                if !finished {
                    self.finish(error: NSLocalizedString("error.remote.timeout", comment: ""))
                }
            }
        }
    }
    
    private func resumeIfPossible() {
        let (cont, text, err): (CheckedContinuation<String, Error>?, String?, String?) = lock.withLock {
            guard let c = continuation else { return (nil, nil, nil) }
            self.continuation = nil
            let out = String(data: data, encoding: .utf8) ?? ""
            return (c, out, error)
        }
        
        if let cont = cont {
            if let e = err {
                cont.resume(throwing: NSError(domain: "RunProcess.Remote", code: -1, userInfo: [NSLocalizedDescriptionKey: e]))
            } else {
                cont.resume(returning: text ?? "")
            }
        }
    }
}

#endif
