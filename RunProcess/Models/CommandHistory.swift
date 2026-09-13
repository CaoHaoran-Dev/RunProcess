//
//  CommandHistory.swift
//  RunProcess
//
//  Created by Haoran on 2026/8/21.
//

import Foundation

/// 单条历史命令
struct HistoryEntry: Codable {
    let command: String
    var count: Int
    var lastUsed: Date
    
    init(command: String) {
        self.command = command
        self.count = 1
        self.lastUsed = Date()
    }
    
    /// 更新使用记录（频次+1，刷新时间）
    mutating func recordUsage() {
        count += 1
        lastUsed = Date()
    }
}

/// 历史命令管理器 - 负责读写和查询
class CommandHistory {
    private let maxEntries = 500
    private let fileURL: URL
    private var entries: [String: HistoryEntry] = [:]
    private let queue = DispatchQueue(label: "com.runprocess.history", qos: .background)
    private let readWriteLock = NSLock()  // 保护 entries 的并发访问
    
    init() {
        // 存储到 Application Support 目录
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("RunProcess")
        
        // 确保目录存在
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        
        fileURL = appDir.appendingPathComponent("history.json")
        load()
    }
    
    // MARK: - 私有方法
    
    /// 加载历史记录
    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let decoded = try JSONDecoder().decode([String: HistoryEntry].self, from: data)
            readWriteLock.lock()
            entries = decoded
            readWriteLock.unlock()
        } catch {
            print("⚠️ 加载历史记录失败: \(error)")
            readWriteLock.lock()
            entries = [:]
            readWriteLock.unlock()
        }
    }
    
    /// 保存历史记录
    private func save() {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.readWriteLock.lock()
            let entriesCopy = self.entries
            self.readWriteLock.unlock()
            
            do {
                let data = try JSONEncoder().encode(entriesCopy)
                try data.write(to: self.fileURL)
            } catch {
                print("⚠️ 保存历史记录失败: \(error)")
            }
        }
    }
    
    // MARK: - 公开方法
    
    /// 记录一条命令执行
    func record(_ command: String) {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        queue.async { [weak self] in
            guard let self = self else { return }
            
            self.readWriteLock.lock()
            
            if var existing = self.entries[trimmed] {
                existing.recordUsage()
                self.entries[trimmed] = existing
            } else {
                // 如果超过最大条目数，删除最旧的一条
                if self.entries.count >= self.maxEntries {
                    let oldest = self.entries.min { $0.value.lastUsed < $1.value.lastUsed }
                    if let key = oldest?.key {
                        self.entries.removeValue(forKey: key)
                    }
                }
                self.entries[trimmed] = HistoryEntry(command: trimmed)
            }
            
            self.readWriteLock.unlock()
            self.save()
        }
    }
    
    /// 查询匹配前缀的历史命令（按频次降序）
    func query(prefix: String) -> [HistoryEntry] {
        guard !prefix.isEmpty else { return [] }
        
        readWriteLock.lock()
        let entriesCopy = entries
        readWriteLock.unlock()
        
        return entriesCopy.values
            .filter { $0.command.hasPrefix(prefix) }
            .sorted { $0.count > $1.count }
            .prefix(20)
            .map { $0 }
    }
    
    /// 清空所有历史记录
    func clearAll() {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.readWriteLock.lock()
            self.entries.removeAll()
            self.readWriteLock.unlock()
            self.save()
        }
    }
    
    /// 获取历史记录总数
    func count() -> Int {
        readWriteLock.lock()
        let count = entries.count
        readWriteLock.unlock()
        return count
    }
    
    /// 获取所有历史命令（用于调试和历史导航）
    func getAll() -> [HistoryEntry] {
        readWriteLock.lock()
        let entriesCopy = entries
        readWriteLock.unlock()
        return Array(entriesCopy.values)
    }
}
