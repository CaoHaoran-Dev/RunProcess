//
//  RunCommandIntent.swift
//  RunProcess
//
//  Created by Haoran on 2026/10/24.
//

#if BETA

import AppIntents
import Foundation

@available(macOS 13.0, *)
struct RunCommandIntent: AppIntent {
    static var title: LocalizedStringResource = "intent.runCommand.title"
    static var description = IntentDescription("intent.runCommand.description")

    @Parameter(title: "intent.runCommand.parameter.command")
    var command: String

    @Parameter(title: "intent.runCommand.parameter.runAsRoot", default: false)
    var runAsRoot: Bool

    @Parameter(title: "intent.runCommand.parameter.throwOnFailure", default: false)
    var throwOnFailure: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("Run \(\.$command)") {
            \.$runAsRoot
            \.$throwOnFailure
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw RunCommandIntentError.emptyCommand
        }

        if runAsRoot {
            // AppleScript 提权，弹系统密码框
            let escapedCommand = trimmed.replacingOccurrences(of: "\"", with: "\\\"")
            let script = """
            do shell script "\(escapedCommand)" with administrator privileges
            """
            
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", script]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            
            do {
                try process.run()
                process.waitUntilExit()
                
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                
                if process.terminationStatus == 0 {
                    return .result(value: output.isEmpty ? NSLocalizedString("output.success", comment: "") : output)
                } else {
                    if process.terminationStatus == -128 {
                        throw RunCommandIntentError.executionFailed(
                            NSLocalizedString("error.intent.sudo.cancelled", comment: "")
                        )
                    }
                    throw RunCommandIntentError.executionFailed(output)
                }
            } catch {
                throw RunCommandIntentError.executionFailed(error.localizedDescription)
            }
        } else {
            let result: Result<String, IntentExecutionError> = await withCheckedContinuation { continuation in
                CommandExecutor.shared.execute(trimmed, timeout: 10.0) { result in
                    switch result {
                    case .success(let output):
                        continuation.resume(returning: .success(output))
                    case .failure(let error):
                        continuation.resume(returning: .failure(IntentExecutionError(message: error.localizedDescription)))
                    }
                }
            }

            switch result {
            case .success(let output):
                let text = output.isEmpty ? NSLocalizedString("output.success", comment: "") : output
                return .result(value: text)
            case .failure(let error):
                let friendly = friendlyError(fromMessage: error.message, runAsRoot: false)
                if throwOnFailure {
                    throw RunCommandIntentError.executionFailed(friendly)
                }
                return .result(value: "❌ \(friendly)")
            }
        }
    }

    private func friendlyError(fromMessage raw: String, runAsRoot: Bool) -> String {
        let lower = raw.lowercased()

        if runAsRoot,
           lower.contains("password is required")
            || lower.contains("a terminal is required")
            || lower.contains("no tty present")
            || lower.contains("not permitted") {
            return NSLocalizedString("error.intent.sudo.not.authorized", comment: "")
        }

        let firstLine = raw
            .split(separator: "\n", omittingEmptySubsequences: true)
            .first
            .map(String.init) ?? raw
        let clipped = firstLine.count > 200
            ? String(firstLine.prefix(200)) + "…"
            : firstLine
        return clipped.isEmpty
            ? NSLocalizedString("error.intent.execution.failed", comment: "")
            : clipped
    }
}

private struct IntentExecutionError: Error, Sendable {
    let message: String
}

@available(macOS 13.0, *)
enum RunCommandIntentError: LocalizedError {
    case emptyCommand
    case executionFailed(String)

    var errorDescription: String? {
        switch self {
        case .emptyCommand:
            return NSLocalizedString("error.intent.empty.command", comment: "")
        case .executionFailed(let message):
            return message
        }
    }
}

@available(macOS 13.0, *)
struct RunProcessShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RunCommandIntent(),
            phrases: [
                "在 \(.applicationName) 里运行命令",
                "Run command in \(.applicationName)",
                "用 \(.applicationName) 执行命令"
            ],
            shortTitle: "intent.runCommand.shortTitle",
            systemImageName: "terminal"
        )
    }
}

#endif
