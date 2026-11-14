//
//  RemoteIntents.swift
//  RunProcess
//
//  Created by Haoran on 2026/11/14.
//

#if BETA

import AppIntents
import Foundation
internal import AppKit

// MARK: - RemoteHostEntity

@available(macOS 13.0, *)
struct RemoteHostEntity: AppEntity, Identifiable {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Remote Host")
    static var defaultQuery = RemoteHostQuery()

    let id: String
    let name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    init(from host: RemoteHost) {
        self.id = host.id
        self.name = host.name
    }
}

// MARK: - RemoteHostQuery

@available(macOS 13.0, *)
struct RemoteHostQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [RemoteHostEntity] {
        await MainActor.run {
            RemoteHostStore.shared.hosts
                .filter { identifiers.contains($0.id) }
                .map(RemoteHostEntity.init)
        }
    }

    func suggestedEntities() async throws -> [RemoteHostEntity] {
        await MainActor.run {
            RemoteHostStore.shared.hosts.map(RemoteHostEntity.init)
        }
    }
}

// MARK: - 运行远程命令

@available(macOS 13.0, *)
struct RunRemoteCommandIntent: AppIntent {
    static var title: LocalizedStringResource = "intent.runRemoteCommand.title"
    static var description = IntentDescription("intent.runRemoteCommand.description")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "intent.runRemoteCommand.parameter.host")
    var host: RemoteHostEntity

    @Parameter(title: "intent.runRemoteCommand.parameter.command")
    var command: String

    @Parameter(title: "intent.runRemoteCommand.parameter.throwOnFailure", default: false)
    var throwOnFailure: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("在 \(\.$host) 上运行 \(\.$command)") {
            \.$throwOnFailure
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw RunCommandIntentError.emptyCommand
        }

        let expanded = AliasStore.shared.expandAlias(in: trimmed)

        guard let realHost = RemoteHostStore.shared.get(id: host.id) else {
            throw RunCommandIntentError.executionFailed(
                NSLocalizedString("error.intent.remote.host.missing", comment: ""))
        }

        if let reason = RemoteAccessPolicyStore.shared.validate(
            command: expanded, capability: .execCommand) {
            if throwOnFailure { throw RunCommandIntentError.executionFailed(reason) }
            return .result(value: "❌ \(reason)")
        }

        do {
            let output = try await RemoteExecutor().execute(
                command: expanded, on: realHost, kind: .command)
            let text = output.isEmpty
                ? NSLocalizedString("output.success", comment: "")
                : output
            return .result(value: text)
        } catch {
            let msg = error.localizedDescription
            if throwOnFailure { throw RunCommandIntentError.executionFailed(msg) }
            return .result(value: "❌ \(msg)")
        }
    }
}

// MARK: - 搜索远程历史

@available(macOS 13.0, *)
struct SearchRemoteHistoryIntent: AppIntent {
    static var title: LocalizedStringResource = "intent.searchRemoteHistory.title"
    static var description = IntentDescription("intent.searchRemoteHistory.description")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "intent.searchRemoteHistory.parameter.host")
    var host: RemoteHostEntity

    @Parameter(title: "intent.searchRemoteHistory.parameter.query")
    var query: String

    @Parameter(title: "intent.searchRemoteHistory.parameter.limit", default: 10)
    var limit: Int

    static var parameterSummary: some ParameterSummary {
        Summary("在 \(\.$host) 上搜索历史 \(\.$query)") {
            \.$limit
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<[String]> {
        guard let realHost = RemoteHostStore.shared.get(id: host.id) else {
            throw RunCommandIntentError.executionFailed(
                NSLocalizedString("error.intent.remote.host.missing", comment: ""))
        }

        if let reason = RemoteAccessPolicyStore.shared.validate(
            command: "history search \(query)", capability: .modifyHistory) {
            throw RunCommandIntentError.executionFailed(reason)
        }

        let safeLimit = max(0, min(limit, 50))
        let cmd = "search \(query) \(safeLimit)"

        do {
            let output = try await RemoteExecutor().execute(
                command: cmd, on: realHost, kind: .history)
            let lines = output
                .split(separator: "\n", omittingEmptySubsequences: true)
                .map(String.init)
            return .result(value: lines)
        } catch {
            throw RunCommandIntentError.executionFailed(error.localizedDescription)
        }
    }
}

#endif
