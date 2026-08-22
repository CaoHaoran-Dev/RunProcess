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
    private let cacheTTL: TimeInterval = 300 // 5分钟缓存
    
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
        // 提取当前正在输入的最后一个单词
        let words = input.split(separator: " ", omittingEmptySubsequences: false)
        guard let lastWord = words.last.map(String.init), !lastWord.isEmpty else {
            return []
        }
        
        // 判断是否路径补全
        if lastWord.hasPrefix("/") || lastWord.hasPrefix("~") {
            return suggestPaths(for: lastWord)
        }
        
        // 否则：命令补全 + 历史补全
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
        
        // 1. 历史命令（带频次权重）
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
        
        // 2. 系统命令（从缓存获取）
        let commands = findSystemCommands(prefix: prefix)
        for cmd in commands {
            if seen.insert(cmd).inserted {
                suggestions.append(Suggestion(text: cmd, type: .command))
            }
        }
        
        // 3. 按优先级排序（priority 高的在前）
        return suggestions.sorted { $0.priority > $1.priority }
    }
    
    // MARK: - 系统命令查找（带缓存）
    
    private func findSystemCommands(prefix: String) -> [String] {
        // 检查缓存是否有效
        let now = Date()
        if now.timeIntervalSince(lastCacheUpdate) < cacheTTL && !cachedCommands.isEmpty {
            // 从缓存中过滤
            return cachedCommands.filter { $0.hasPrefix(prefix) }.prefix(20).map { $0 }
        }
        
        // 重新加载命令列表
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
                if isFileExecutableSafely(atPath: fullPath) {
                    allCommands.append(file)
                }
            }
        }
        
        // 更新缓存
        cachedCommands = allCommands.sorted()
        lastCacheUpdate = now
        
        // 返回匹配结果
        return cachedCommands.filter { $0.hasPrefix(prefix) }.prefix(20).map { $0 }
    }
    
    // MARK: - 安全文件检查
    
    private func isFileExecutableSafely(atPath path: String) -> Bool {
        // 直接使用 access() 系统调用，简化逻辑并避免 TOCTOU
        return access(path, X_OK) == 0
    }
}
