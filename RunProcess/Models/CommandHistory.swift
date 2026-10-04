//
//  CommandHistory.swift
//  RunProcess
//
//  Created by Haoran on 2026/8/21.
//

import Foundation
import Yams

nonisolated struct HistoryEntry: Codable {
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

    var frecency: Double {
        let days = max(0, Date().timeIntervalSince(lastUsed) / 86400)
        return Double(count) / (1.0 + days)
    }
}

/// YAML 顶层结构
private nonisolated struct HistoryFile: Codable {
    var entries: [HistoryEntry]
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
        fileURL = appDir.appendingPathComponent("history.yml")
        load()
    }

    // MARK: - 加载

    private func load() {
        if FileManager.default.fileExists(atPath: fileURL.path) {
            loadYAML()
            return
        }
        let legacyURL = fileURL
            .deletingPathExtension()
            .appendingPathExtension("json")
        if FileManager.default.fileExists(atPath: legacyURL.path) {
            loadLegacyJSON(from: legacyURL)
            saveSync()
            try? FileManager.default.removeItem(at: legacyURL)
        }
    }

    private func loadYAML() {
        do {
            let text = try String(contentsOf: fileURL, encoding: .utf8)
            let file = try YAMLDecoder().decode(HistoryFile.self, from: text)
            readWriteLock.lock()
            entries = Dictionary(uniqueKeysWithValues: file.entries.map { ($0.command, $0) })
            readWriteLock.unlock()
        } catch {
            print("⚠️ 加载历史记录失败: \(error)")
            readWriteLock.lock(); entries = [:]; readWriteLock.unlock()
        }
    }

    private func loadLegacyJSON(from url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .deferredToDate
            let decoded = try decoder.decode([String: HistoryEntry].self, from: data)
            readWriteLock.lock()
            entries = decoded
            readWriteLock.unlock()
        } catch {
            print("⚠️ 迁移旧历史失败: \(error)")
            readWriteLock.lock(); entries = [:]; readWriteLock.unlock()
        }
    }

    // MARK: - 保存

    private func saveSync() {
        readWriteLock.lock()
        let copy = Array(entries.values)
        readWriteLock.unlock()

        let file = HistoryFile(entries: copy.sorted { $0.lastUsed > $1.lastUsed })
        let url = fileURL

        queue.async {
            do {
                let encoder = YAMLEncoder()
                encoder.options.indent = 2
                let yaml = try encoder.encode(file)
                try yaml.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                print("⚠️ 保存历史记录失败: \(error)")
            }
        }
    }

    // MARK: - 记录

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

    // MARK: - 查询

    func query(prefix: String) -> [HistoryEntry] {
        guard !prefix.isEmpty else { return [] }
        readWriteLock.lock(); let copy = entries; readWriteLock.unlock()
        return copy.values
            .filter { $0.command.hasPrefix(prefix) }
            .sorted { $0.count > $1.count }
            .prefix(20).map { $0 }
    }

    func queryByFrecency(prefix: String) -> [HistoryEntry] {
        guard !prefix.isEmpty else { return [] }
        readWriteLock.lock(); let copy = entries; readWriteLock.unlock()
        return copy.values
            .filter { $0.command.hasPrefix(prefix) }
            .sorted { $0.frecency > $1.frecency }
            .prefix(20).map { $0 }
    }

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

    // MARK: - 管理

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
