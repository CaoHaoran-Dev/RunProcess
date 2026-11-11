//
//  RemoteAccessPolicy.swift
//  RunProcess
//
//  Created by Haoran on 2026/11/11.
//

#if BETA

import Foundation
import Yams

nonisolated enum RemoteCapability: String, Codable, CaseIterable, Identifiable {
    case execCommand
    case runWorkflow
    case sudoCommand
    case modifyAliases
    case modifyHistory
    case fileAccess

    var id: String { rawValue }

    var displayNameKey: String {
        switch self {
        case .execCommand:   return "settings.remote.capability.exec"
        case .runWorkflow:   return "settings.remote.capability.workflow"
        case .sudoCommand:   return "settings.remote.capability.sudo"
        case .modifyAliases: return "settings.remote.capability.aliases"
        case .modifyHistory: return "settings.remote.capability.history"
        case .fileAccess:    return "settings.remote.capability.file"
        }
    }
}

nonisolated struct RemoteAccessPolicyFile: Codable {
    var allowedCapabilities: [String]
    var blockedWords: [String]
}

nonisolated final class RemoteAccessPolicyStore: @unchecked Sendable {
    static let shared = RemoteAccessPolicyStore()

    private(set) var allowedCapabilities: Set<RemoteCapability> = Set(RemoteCapability.allCases)
    private(set) var blockedWords: [String] = []

    private let fileURL: URL
    private let queue = DispatchQueue(label: "com.runprocess.remoteaccesspolicy", qos: .background)
    private let lock = NSLock()

    private init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent(AppEnvironment.appSupportFolderName)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("remote_access.yml")
        load()
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let text = try String(contentsOf: fileURL, encoding: .utf8)
            let file = try YAMLDecoder().decode(RemoteAccessPolicyFile.self, from: text)
            lock.lock()
            allowedCapabilities = Set(file.allowedCapabilities.compactMap { RemoteCapability(rawValue: $0) })
            blockedWords = file.blockedWords
            lock.unlock()
        } catch {
            print("⚠️ 加载远程访问策略失败: \(error)")
        }
    }

    private func save() {
        lock.lock()
        let file = RemoteAccessPolicyFile(
            allowedCapabilities: RemoteCapability.allCases
                .filter { allowedCapabilities.contains($0) }
                .map { $0.rawValue },
            blockedWords: blockedWords
        )
        lock.unlock()

        let url = fileURL
        queue.async {
            do {
                let encoder = YAMLEncoder()
                encoder.options.indent = 2
                let yaml = try encoder.encode(file)

                let header = """
                # RunProcess remote access policy
                #
                # allowedCapabilities: 允许远程使用的功能。
                # blockedWords: 远程命令中命中任一关键词即拒绝执行。
                # 修改后立即生效。

                """
                try (header + yaml).write(to: url, atomically: true, encoding: .utf8)
            } catch {
                print("⚠️ 保存远程访问策略失败: \(error)")
            }
        }
    }

    func isAllowed(_ capability: RemoteCapability) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return allowedCapabilities.contains(capability)
    }

    func setAllowed(_ capability: RemoteCapability, enabled: Bool) {
        lock.lock()
        if enabled { allowedCapabilities.insert(capability) }
        else { allowedCapabilities.remove(capability) }
        lock.unlock()
        save()
    }

    /// 按 shell token 边界匹配违禁词，避免 `grep "rm"` 之类的子串误伤。
    func matchedBlockedWord(in text: String) -> String? {
        lock.lock()
        let words = blockedWords
        lock.unlock()
        guard !words.isEmpty else { return nil }

        let tokens = Self.tokenize(text)
        let lowerTokens = tokens.map { $0.lowercased() }

        for word in words where !word.isEmpty {
            let needle = word.lowercased()
            if lowerTokens.contains(needle) { return word }
            for token in lowerTokens {
                let base = token.split(separator: "/").last.map(String.init) ?? token
                if base == needle { return word }
            }
        }
        return nil
    }

    /// 极简 shell token 化：按空白和 shell 元字符切分，保留引号内空白，去掉引号。
    private static func tokenize(_ text: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var inSingle = false
        var inDouble = false
        var escaped = false

        let separators: Set<Character> = [
            " ", "\t", "\n", "\r", ";", "|", "&",
            "(", ")", "{", "}", "`", "$"
        ]

        for ch in text {
            if escaped {
                current.append(ch)
                escaped = false
                continue
            }
            if ch == "\\" && !inSingle {
                escaped = true
                continue
            }
            if ch == "'" && !inDouble {
                inSingle.toggle()
                continue
            }
            if ch == "\"" && !inSingle {
                inDouble.toggle()
                continue
            }
            if separators.contains(ch) && !inSingle && !inDouble {
                if !current.isEmpty { tokens.append(current); current = "" }
                continue
            }
            current.append(ch)
        }
        if !current.isEmpty { tokens.append(current) }
        return tokens
    }

    func addBlockedWord(_ word: String) {
        let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        lock.lock()
        if !blockedWords.contains(trimmed) { blockedWords.append(trimmed) }
        lock.unlock()
        save()
    }

    func removeBlockedWord(_ word: String) {
        lock.lock()
        blockedWords.removeAll { $0 == word }
        lock.unlock()
        save()
    }

    func replaceBlockedWords(_ words: [String]) {
        lock.lock()
        blockedWords = words.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        lock.unlock()
        save()
    }

    func validate(command: String, capability: RemoteCapability) -> String? {
        guard isAllowed(capability) else {
            return NSLocalizedString("error.remote.capability.denied", comment: "")
        }
        if let word = matchedBlockedWord(in: command) {
            return String(format: NSLocalizedString("error.remote.blocked.word", comment: ""), word)
        }
        return nil
    }
}

#endif
