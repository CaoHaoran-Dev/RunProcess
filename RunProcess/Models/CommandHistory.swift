//
//  CommandHistory.swift
//  RunProcess
//
//  Created by Haoran on 2026/8/21.
//

import Foundation

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

    /// frecency：频次越高、越近，分越高
    var frecency: Double {
        let days = max(0, Date().timeIntervalSince(lastUsed) / 86400)
        return Double(count) / (1.0 + days)
    }
}

class CommandHistory {
    static let shared = CommandHistory()

    private let maxEntries = 500
    private let fileURL: URL
    private var entries: [String: HistoryEntry] = [:]
    private let queue = DispatchQueue(label: "com.runprocess.history", qos: .background)
    private let readWriteLock = NSLock()

    private init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("RunProcess")
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        fileURL = appDir.appendingPathComponent("history.json")
        load()
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoded = try JSONDecoder().decode([String: HistoryEntry].self, from: data)
            readWriteLock.lock(); entries = decoded; readWriteLock.unlock()
        } catch {
            print("⚠️ 加载历史记录失败: \(error)")
            readWriteLock.lock(); entries = [:]; readWriteLock.unlock()
        }
    }

    private func saveSync() {
        readWriteLock.lock()
        let copy = entries
        readWriteLock.unlock()
        queue.async { [fileURL] in
            do {
                let data = try JSONEncoder().encode(copy)
                try data.write(to: fileURL)
            } catch {
                print("⚠️ 保存历史记录失败: \(error)")
            }
        }
    }

    func record(_ command: String) {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        readWriteLock.lock()
        if var existing = entries[trimmed] {
            existing.recordUsage()
            entries[trimmed] = existing
        } else {
            if entries.count >= maxEntries,
               let oldest = entries.min(by: { $0.value.lastUsed < $1.value.lastUsed }) {
                entries.removeValue(forKey: oldest.key)
            }
            entries[trimmed] = HistoryEntry(command: trimmed)
        }
        readWriteLock.unlock()
        saveSync()
    }

    /// 按频次排序（旧接口）
    func query(prefix: String) -> [HistoryEntry] {
        guard !prefix.isEmpty else { return [] }
        readWriteLock.lock(); let copy = entries; readWriteLock.unlock()
        return copy.values
            .filter { $0.command.hasPrefix(prefix) }
            .sorted { $0.count > $1.count }
            .prefix(20).map { $0 }
    }

    /// 按 frecency 排序（新接口，补全用）
    func queryByFrecency(prefix: String) -> [HistoryEntry] {
        guard !prefix.isEmpty else { return [] }
        readWriteLock.lock(); let copy = entries; readWriteLock.unlock()
        return copy.values
            .filter { $0.command.hasPrefix(prefix) }
            .sorted { $0.frecency > $1.frecency }
            .prefix(20).map { $0 }
    }

    /// 模糊搜索（用于 ⌘R 历史面板）
    func search(_ query: String) -> [HistoryEntry] {
        readWriteLock.lock(); let copy = entries; readWriteLock.unlock()
        let q = query.lowercased()
        guard !q.isEmpty else {
            return copy.values.sorted { $0.frecency > $1.frecency }.prefix(50).map { $0 }
        }
        return copy.values
            .filter { fuzzyMatch(q, in: $0.command.lowercased()) }
            .sorted { $0.frecency > $1.frecency }
            .prefix(50).map { $0 }
    }

    private func fuzzyMatch(_ query: String, in text: String) -> Bool {
        var qi = query.startIndex
        for ch in text {
            if qi < query.endIndex, ch == query[qi] {
                qi = query.index(after: qi)
            }
        }
        return qi == query.endIndex
    }

    func clearAll() {
        readWriteLock.lock(); entries.removeAll(); readWriteLock.unlock()
        saveSync()
    }

    func count() -> Int {
        readWriteLock.lock(); defer { readWriteLock.unlock() }
        return entries.count
    }

    func getAll() -> [HistoryEntry] {
        readWriteLock.lock(); defer { readWriteLock.unlock() }
        return Array(entries.values)
    }
}
