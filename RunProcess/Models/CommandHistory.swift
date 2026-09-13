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
    private let saveQueue = DispatchQueue(label: "com.runprocess.history.save", qos: .background)
    private let readWriteLock = NSLock()
    
    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("RunProcess")
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        fileURL = appDir.appendingPathComponent("history.json")
        load()
    }
    
    // MARK: - 私有方法
    
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
    
    /// 把一份快照异步写到磁盘。调用方负责传入不可变的副本。
    private func save(_ snapshot: [String: HistoryEntry]) {
        saveQueue.async { [weak self] in
            guard let self = self else { return }
            do {
                let data = try JSONEncoder().encode(snapshot)
                try data.write(to: self.fileURL)
            } catch {
                print("⚠️ 保存历史记录失败: \(error)")
            }
        }
    }
    
    // MARK: - 公开方法
    
    /// 记录一条命令执行
    /// 内存同步更新（读路径立即可见），磁盘异步保存
    func record(_ command: String) {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        readWriteLock.lock()
        
        if var existing = entries[trimmed] {
            existing.recordUsage()
            entries[trimmed] = existing
        } else {
            if entries.count >= maxEntries {
                let oldest = entries.min { $0.value.lastUsed < $1.value.lastUsed }
                if let key = oldest?.key {
                    entries.removeValue(forKey: key)
                }
            }
            entries[trimmed] = HistoryEntry(command: trimmed)
        }
        
        let snapshot = entries
        readWriteLock.unlock()
        
        save(snapshot)
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
    /// 内存同步清空（读路径立即可见），磁盘异步保存
    func clearAll() {
        readWriteLock.lock()
        entries.removeAll()
        let snapshot = entries
        readWriteLock.unlock()
        
        save(snapshot)
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
