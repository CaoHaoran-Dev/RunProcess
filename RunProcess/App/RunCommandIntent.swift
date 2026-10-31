//
//  RunCommandIntent.swift
//  RunProcess
//
//  Created by Haoran on 2026/10/24.
//

import AppIntents
import Foundation
internal import AppKit

// MARK: - 运行命令

@available(macOS 13.0, *)
struct RunCommandIntent: AppIntent {
    static var title: LocalizedStringResource = "intent.runCommand.title"
    static var description = IntentDescription("intent.runCommand.description")
    static var openAppWhenRun: Bool = false // 后台静默执行，不弹主窗口

    @Parameter(title: "intent.runCommand.parameter.command")
    var command: String

    @Parameter(title: "intent.runCommand.parameter.runAsRoot", default: false)
    var runAsRoot: Bool

    @Parameter(title: "intent.runCommand.parameter.throwOnFailure", default: false)
    var throwOnFailure: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("运行 \(\.$command)") {
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

        // 👇 加入别名展开逻辑
        let processedCommand = AliasStore.shared.expandAlias(in: trimmed)

        if runAsRoot {
            // AppleScript 提权，弹系统密码框
            let escapedCommand = processedCommand.replacingOccurrences(of: "\"", with: "\\\"")
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
                // 👇 改为执行展开后的 processedCommand
                CommandExecutor.shared.execute(processedCommand, timeout: 10.0) { result in
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

// MARK: - 搜索命令历史

@available(macOS 13.0, *)
struct SearchHistoryIntent: AppIntent {
    static var title: LocalizedStringResource = "intent.searchHistory.title"
    static var description = IntentDescription("intent.searchHistory.description")
    static var openAppWhenRun: Bool = false // 后台返回搜索结果即可

    @Parameter(title: "intent.searchHistory.parameter.query")
    var query: String

    @Parameter(title: "intent.searchHistory.parameter.limit", default: 10)
    var limit: Int

    static var parameterSummary: some ParameterSummary {
        Summary("搜索历史 \(\.$query)") {
            \.$limit
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<[String]> {
        let results = CommandHistory.shared.search(query)
        let limited = Array(results.prefix(max(0, min(limit, 50))).map { $0.command })
        return .result(value: limited)
    }
}

// MARK: - 添加别名

@available(macOS 13.0, *)
struct AddAliasIntent: AppIntent {
    static var title: LocalizedStringResource = "intent.addAlias.title"
    static var description = IntentDescription("intent.addAlias.description")
    static var openAppWhenRun: Bool = false // 后台静默写入

    @Parameter(title: "intent.addAlias.parameter.name")
    var name: String

    @Parameter(title: "intent.addAlias.parameter.expansion")
    var expansion: String

    static var parameterSummary: some ParameterSummary {
        Summary("添加别名 \(\.$name) → \(\.$expansion)")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedExpansion = expansion.trimmingCharacters(in: .whitespaces)

        guard !trimmedName.isEmpty, !trimmedExpansion.isEmpty else {
            throw RunCommandIntentError.emptyCommand
        }
        guard !trimmedName.contains(" ") else {
            throw RunCommandIntentError.aliasNameInvalid
        }

        AliasStore.shared.add(CommandAlias(name: trimmedName, expansion: trimmedExpansion))
        return .result()
    }
}

// MARK: - 清除命令历史

@available(macOS 13.0, *)
struct ClearHistoryIntent: AppIntent {
    static var title: LocalizedStringResource = "intent.clearHistory.title"
    static var description = IntentDescription("intent.clearHistory.description")
    static var openAppWhenRun: Bool = false // 后台静默执行

    @MainActor
    func perform() async throws -> some IntentResult {
        CommandHistory.shared.clearAll()
        return .result()
    }
}

// MARK: - 错误类型

private struct IntentExecutionError: Error, Sendable {
    let message: String
}

@available(macOS 13.0, *)
enum RunCommandIntentError: LocalizedError, CustomLocalizedStringResourceConvertible {
    case emptyCommand
    case aliasNameInvalid
    case executionFailed(String)

    var errorDescription: String? {
        switch self {
        case .emptyCommand:
            return NSLocalizedString("error.intent.empty.command", comment: "")
        case .aliasNameInvalid:
            return NSLocalizedString("error.intent.alias.name.invalid", comment: "")
        case .executionFailed(let message):
            return message
        }
    }

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .emptyCommand:
            return "error.intent.empty.command"
        case .aliasNameInvalid:
            return "error.intent.alias.name.invalid"
        case .executionFailed(let message):
            return LocalizedStringResource(stringLiteral: message)
        }
    }
}

// MARK: - App Shortcuts

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

        AppShortcut(
            intent: SearchHistoryIntent(),
            phrases: [
                "在 \(.applicationName) 中搜索命令历史",
                "Search command history in \(.applicationName)"
            ],
            shortTitle: "intent.searchHistory.shortTitle",
            systemImageName: "clock.arrow.circlepath"
        )

        AppShortcut(
            intent: AddAliasIntent(),
            phrases: [
                "在 \(.applicationName) 中添加别名",
                "Add an alias in \(.applicationName)"
            ],
            shortTitle: "intent.addAlias.shortTitle",
            systemImageName: "wand.and.stars"
        )
    }
}
