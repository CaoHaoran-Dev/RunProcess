//
//  CommandAlias.swift
//  RunProcess
//
//  Created by Haoran on 2026/10/3.
//

import Foundation

struct CommandAlias: Codable, Identifiable, Equatable {
    var id: String { name }
    let name: String
    let expansion: String

    init(name: String, expansion: String) {
        self.name = name
        self.expansion = expansion
    }
}

final class AliasStore {
    static let shared = AliasStore()

    private(set) var aliases: [CommandAlias] = []
    private let fileURL: URL
    private let queue = DispatchQueue(label: "com.runprocess.aliases", qos: .background)

    private init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("RunProcess")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("aliases.json")
        load()
        if aliases.isEmpty {
            // 首次运行写入默认示例
            aliases = [
                CommandAlias(name: "gs", expansion: "git status"),
                CommandAlias(name: "gp", expansion: "git pull --rebase"),
                CommandAlias(name: "ll", expansion: "ls -lah"),
                CommandAlias(name: "serve", expansion: "python3 -m http.server 8000"),
            ]
            save()
        }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            aliases = try JSONDecoder().decode([CommandAlias].self, from: data)
        } catch {
            print("⚠️ 加载别名失败: \(error)")
            aliases = []
        }
    }

    private func save() {
        let copy = aliases
        queue.async { [fileURL] in
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let data = try encoder.encode(copy)
                try data.write(to: fileURL)
            } catch {
                print("⚠️ 保存别名失败: \(error)")
            }
        }
    }

    func add(_ alias: CommandAlias) {
        if let idx = aliases.firstIndex(where: { $0.name == alias.name }) {
            aliases[idx] = alias
        } else {
            aliases.append(alias)
        }
        save()
    }

    func remove(name: String) {
        aliases.removeAll { $0.name == name }
        save()
    }

    func match(prefix: String) -> [CommandAlias] {
        guard !prefix.isEmpty else { return [] }
        return aliases.filter { $0.name.hasPrefix(prefix) }
    }

    func expansion(for name: String) -> String? {
        aliases.first { $0.name == name }?.expansion
    }
}
