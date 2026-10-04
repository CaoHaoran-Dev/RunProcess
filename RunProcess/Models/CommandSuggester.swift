//
//  CommandSuggester.swift
//  RunProcess
//
//  Created by Haoran on 2026/8/21.
//

import Foundation

class CommandSuggester {
    private let history = CommandHistory.shared
    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "com.runprocess.suggester", qos: .userInitiated)

    private var cachedCommands: [String] = []
    private var lastCacheUpdate: Date = .distantPast
    private let cacheTTL: TimeInterval = 60

    func suggest(for input: String, completion: @escaping ([Suggestion]) -> Void) {
        queue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion([]) }
                return
            }
            let results = self.generateSuggestions(for: input)
            DispatchQueue.main.async { completion(results) }
        }
    }

    private func generateSuggestions(for input: String) -> [Suggestion] {
        let words = input.split(separator: " ", omittingEmptySubsequences: false)
        guard let lastWord = words.last.map(String.init), !lastWord.isEmpty else { return [] }

        let isFirstWord = words.count <= 1
        if lastWord.hasPrefix("/") || lastWord.hasPrefix("~") || lastWord.hasPrefix(".") {
            return suggestPaths(for: lastWord)
        }
        if isFirstWord {
            return suggestCommandsHistoryAliases(for: lastWord)
        }
        return suggestCommandsHistoryAliases(for: lastWord)
    }

    // MARK: - Aliases + History + Commands

    private func suggestCommandsHistoryAliases(for prefix: String) -> [Suggestion] {
        guard !prefix.isEmpty else { return [] }
        var suggestions: [Suggestion] = []
        var seen = Set<String>()

        // 1. 别名：一条补全，大标题是展开内容，副标题是别名
        for alias in AliasStore.shared.match(prefix: prefix) {
            if seen.insert(alias.expansion).inserted {
                suggestions.append(Suggestion(
                    text: alias.expansion,
                    type: .alias,
                    subtitle: alias.name
                ))
            }
        }

        // 2. 历史（frecency 排序）
        for entry in history.queryByFrecency(prefix: prefix) {
            if seen.insert(entry.command).inserted {
                suggestions.append(Suggestion(
                    text: entry.command, type: .history, historyCount: entry.count))
            }
        }

        // 3. 系统命令
        for cmd in findSystemCommands(prefix: prefix) {
            if seen.insert(cmd).inserted {
                suggestions.append(Suggestion(text: cmd, type: .command))
            }
        }

        return suggestions.sorted { $0.priority > $1.priority }
    }

    // MARK: - Paths

    private func suggestPaths(for input: String) -> [Suggestion] {
        let path = (input as NSString).expandingTildeInPath
        let partial = (path as NSString).lastPathComponent
        let dir = (path as NSString).deletingLastPathComponent

        guard !dir.isEmpty,
              let files = try? fileManager.contentsOfDirectory(atPath: dir) else { return [] }

        let showHidden = partial.hasPrefix(".")
        var isDir: ObjCBool = false

        return files
            .filter { showHidden || !$0.hasPrefix(".") }
            .filter { $0.hasPrefix(partial) }
            .sorted()
            .prefix(20)
            .map { name -> String in
                let full = (dir as NSString).appendingPathComponent(name)
                FileManager.default.fileExists(atPath: full, isDirectory: &isDir)
                let suffix = isDir.boolValue ? "/" : ""
                return dir + "/" + name + suffix
            }
            .map { ($0 as NSString).abbreviatingWithTildeInPath }
            .map { ShellQuoting.quote($0) }
            .map { Suggestion(text: $0, type: .path) }
    }

    // MARK: - System commands

    private func findSystemCommands(prefix: String) -> [String] {
        let now = Date()
        if now.timeIntervalSince(lastCacheUpdate) < cacheTTL && !cachedCommands.isEmpty {
            return cachedCommands.filter { $0.hasPrefix(prefix) }.prefix(20).map { $0 }
        }

        if let all = loadCommandsViaCompgen() {
            cachedCommands = all
        } else {
            cachedCommands = loadCommandsViaPATH()
        }
        lastCacheUpdate = now
        return cachedCommands.filter { $0.hasPrefix(prefix) }.prefix(20).map { $0 }
    }

    private func loadCommandsViaCompgen() -> [String]? {
        let task = Process()
        let pipe = Pipe()
        task.launchPath = "/bin/zsh"
        task.arguments = ["-l", "-c", "compgen -c"]
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        do { try task.run() } catch { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        guard task.terminationStatus == 0,
              let text = String(data: data, encoding: .utf8) else { return nil }
        let set = Set(text.split(separator: "\n").map(String.init).filter { !$0.isEmpty })
        return set.sorted()
    }

    private func loadCommandsViaPATH() -> [String] {
        let pathString = ProcessInfo.processInfo.environment["PATH"]
            ?? "/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin"
        let paths = pathString.split(separator: ":").map(String.init)
        var all: [String] = []
        var seen = Set<String>()
        for path in paths {
            guard !path.isEmpty,
                  let files = try? fileManager.contentsOfDirectory(atPath: path) else { continue }
            for file in files {
                guard !file.hasPrefix("."), seen.insert(file).inserted else { continue }
                let full = (path as NSString).appendingPathComponent(file)
                if isFileExecutable(atPath: full) { all.append(file) }
            }
        }
        return all.sorted()
    }

    private func isFileExecutable(atPath path: String) -> Bool {
        var info = stat()
        guard lstat(path, &info) == 0 else { return false }
        let isRegular = (info.st_mode & S_IFMT) == S_IFREG
        let isSymlink = (info.st_mode & S_IFMT) == S_IFLNK
        let isExec = (info.st_mode & S_IXUSR) != 0
        return (isRegular || isSymlink) && isExec
    }
}
