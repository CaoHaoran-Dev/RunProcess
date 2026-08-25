//
//  CommandSuggester.swift
//  RunProcess
//
//  Created by Haoran on 2026/8/21.
//

import Foundation

/// 补全建议生成器
class CommandSuggester {
    private let history = CommandHistory()
    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "com.runprocess.suggester", qos: .userInitiated)
    
    // 命令缓存
    private var cachedCommands: [String] = []
    private var lastCacheUpdate: Date = Date.distantPast
    private let cacheTTL: TimeInterval = 60 // ✅ 修复：60秒缓存，新命令更快生效
    
    /// 根据输入生成补全建议（异步回调，避免阻塞 UI）
    func suggest(for input: String, completion: @escaping ([Suggestion]) -> Void) {
        queue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion([]) }
                return
            }
            
            let results = self.generateSuggestions(for: input)
            
            DispatchQueue.main.async {
                completion(results)
            }
        }
    }
    
    // MARK: - 私有方法
    
    private func generateSuggestions(for input: String) -> [Suggestion] {
        let words = input.split(separator: " ", omittingEmptySubsequences: false)
        guard let lastWord = words.last.map(String.init), !lastWord.isEmpty else {
            return []
        }
        
        if lastWord.hasPrefix("/") || lastWord.hasPrefix("~") {
            return suggestPaths(for: lastWord)
        }
        
        return suggestCommandsAndHistory(for: lastWord)
    }
    
    // MARK: - 路径补全
    
    private func suggestPaths(for input: String) -> [Suggestion] {
        let path = (input as NSString).expandingTildeInPath
        let partial = (path as NSString).lastPathComponent
        let dir = (path as NSString).deletingLastPathComponent
        
        guard !dir.isEmpty,
              let files = try? fileManager.contentsOfDirectory(atPath: dir) else {
            return []
        }
        
        return files
            .filter { $0.hasPrefix(partial) }
            .prefix(20)
            .map { dir + "/" + $0 }
            .map { ($0 as NSString).abbreviatingWithTildeInPath }
            .map { $0.replacingOccurrences(of: " ", with: "\\ ") }
            .map { Suggestion(text: $0, type: .path) }
    }
    
    // MARK: - 命令 + 历史补全
    
    private func suggestCommandsAndHistory(for prefix: String) -> [Suggestion] {
        guard !prefix.isEmpty else { return [] }
        
        var suggestions: [Suggestion] = []
        var seen = Set<String>()
        
        let historyEntries = history.query(prefix: prefix)
        for entry in historyEntries {
            if seen.insert(entry.command).inserted {
                let suggestion = Suggestion(
                    text: entry.command,
                    type: .history,
                    historyCount: entry.count
                )
                suggestions.append(suggestion)
            }
        }
        
        let commands = findSystemCommands(prefix: prefix)
        for cmd in commands {
            if seen.insert(cmd).inserted {
                suggestions.append(Suggestion(text: cmd, type: .command))
            }
        }
        
        return suggestions.sorted { $0.priority > $1.priority }
    }
    
    // MARK: - 系统命令查找（带缓存）
    
    private func findSystemCommands(prefix: String) -> [String] {
        let now = Date()
        if now.timeIntervalSince(lastCacheUpdate) < cacheTTL && !cachedCommands.isEmpty {
            return cachedCommands.filter { $0.hasPrefix(prefix) }.prefix(20).map { $0 }
        }
        
        let pathString = ProcessInfo.processInfo.environment["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin"
        let paths = pathString.split(separator: ":").map(String.init)
        
        var allCommands: [String] = []
        var seen = Set<String>()
        
        for path in paths {
            guard !path.isEmpty else { continue }
            guard let files = try? fileManager.contentsOfDirectory(atPath: path) else { continue }
            
            for file in files {
                guard !file.hasPrefix(".") else { continue }
                guard seen.insert(file).inserted else { continue }
                
                let fullPath = (path as NSString).appendingPathComponent(file)
                // ✅ 修复：直接检查文件是否可执行，使用 stat 替代 access
                if isFileExecutable(atPath: fullPath) {
                    allCommands.append(file)
                }
            }
        }
        
        cachedCommands = allCommands.sorted()
        lastCacheUpdate = now
        
        return cachedCommands.filter { $0.hasPrefix(prefix) }.prefix(20).map { $0 }
    }
    
    // MARK: - 安全文件检查（使用 stat 替代 access，避免 TOCTOU）
    
    private func isFileExecutable(atPath path: String) -> Bool {
        var statInfo = stat()
        guard stat(path, &statInfo) == 0 else { return false }
        
        // 检查是否为普通文件或符号链接，且拥有者可执行
        let isRegular = (statInfo.st_mode & S_IFMT) == S_IFREG
        let isSymlink = (statInfo.st_mode & S_IFMT) == S_IFLNK
        let isExecutable = (statInfo.st_mode & S_IXUSR) != 0
        
        return (isRegular || isSymlink) && isExecutable
    }
}
