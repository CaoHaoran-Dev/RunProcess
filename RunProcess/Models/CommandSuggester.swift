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
        
        // 2. 系统命令（实时查找）
        let commands = findSystemCommands(prefix: prefix)
        for cmd in commands {
            if seen.insert(cmd).inserted {
                suggestions.append(Suggestion(text: cmd, type: .command))
            }
        }
        
        // 3. 按优先级排序（priority 高的在前）
        return suggestions.sorted { $0.priority > $1.priority }
    }
    
    // MARK: - 系统命令查找（安全修复版）
    
    private func findSystemCommands(prefix: String) -> [String] {
        // 获取 PATH 环境变量
        let pathString = ProcessInfo.processInfo.environment["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin"
        let paths = pathString.split(separator: ":").map(String.init)
        
        var allCommands: [String] = []
        var seen = Set<String>()
        
        for path in paths {
            // 安全检查：跳过空路径
            guard !path.isEmpty else { continue }
            
            // 使用 withSecureDirectory 方式读取
            guard let files = try? fileManager.contentsOfDirectory(atPath: path) else {
                continue
            }
            
            for file in files {
                // 跳过隐藏文件和系统文件
                guard !file.hasPrefix(".") else { continue }
                
                // 安全检查：只处理匹配前缀的文件
                guard file.hasPrefix(prefix) else { continue }
                
                // 去重
                guard seen.insert(file).inserted else { continue }
                
                // 构建完整路径
                let fullPath = (path as NSString).appendingPathComponent(file)
                
                // 安全地检查是否可执行
                if isFileExecutableSafely(atPath: fullPath) {
                    allCommands.append(file)
                }
            }
        }
        
        // 按字母排序，最多返回 20 个
        return allCommands.sorted().prefix(20).map { $0 }
    }
    
    // MARK: - 安全文件检查
    
    private func isFileExecutableSafely(atPath path: String) -> Bool {
        // 使用 withUnsafeFileSystemRepresentation 或简单的方式
        // 先检查文件是否存在且不是目录
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory) else {
            return false
        }
        
        // 如果是目录，跳过
        guard !isDirectory.boolValue else {
            return false
        }
        
        // 检查是否可执行（使用 POSIX 权限）
        // 这里使用更安全的方式：通过 FileManager 的属性检查
        do {
            let attributes = try fileManager.attributesOfItem(atPath: path)
            // 检查 POSIX 权限中的可执行位
            if let posixPermissions = attributes[.posixPermissions] as? NSNumber {
                let permissions = posixPermissions.intValue
                // 检查 owner、group 或 other 是否有执行权限
                // 执行位：0100 (owner), 0010 (group), 0001 (other)
                return (permissions & 0o111) != 0
            }
        } catch {
            // 如果获取属性失败，尝试使用系统调用
            return access(path, X_OK) == 0
        }
        
        return false
    }
}
