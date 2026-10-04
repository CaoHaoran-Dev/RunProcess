//
//  CommandAlias.swift
//  RunProcess
//
//  Created by Haoran on 2026/10/3.
//

import Foundation
import Yams

nonisolated struct CommandAlias: Codable, Identifiable, Equatable {
    var id: String { name }
    let name: String
    let expansion: String

    init(name: String, expansion: String) {
        self.name = name
        self.expansion = expansion
    }
}

/// YAML 顶层结构
private nonisolated struct AliasFile: Codable {
    var aliases: [CommandAlias]
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
        fileURL = dir.appendingPathComponent("aliases.yml")

        load()

        if aliases.isEmpty {
            aliases = [
                CommandAlias(name: "gs", expansion: "git status"),
                CommandAlias(name: "gp", expansion: "git pull --rebase"),
                CommandAlias(name: "ll", expansion: "ls -lah"),
                CommandAlias(name: "serve", expansion: "python3 -m http.server 8000"),
            ]
            save()
        }
    }

    // MARK: - 加载

    private func load() {
        // 优先读 yml
        if FileManager.default.fileExists(atPath: fileURL.path) {
            loadYAML()
            return
        }
        // 回退：读旧的 json，迁移到 yml
        let legacyURL = fileURL
            .deletingPathExtension()
            .appendingPathExtension("json")
        if FileManager.default.fileExists(atPath: legacyURL.path) {
            loadLegacyJSON(from: legacyURL)
            save()
            try? FileManager.default.removeItem(at: legacyURL)
        }
    }

    private func loadYAML() {
        do {
            let text = try String(contentsOf: fileURL, encoding: .utf8)
            let file = try YAMLDecoder().decode(AliasFile.self, from: text)
            aliases = file.aliases
        } catch {
            print("⚠️ 加载别名失败: \(error)")
            aliases = []
        }
    }

    private func loadLegacyJSON(from url: URL) {
        do {
            let data = try Data(contentsOf: url)
            aliases = try JSONDecoder().decode([CommandAlias].self, from: data)
        } catch {
            print("⚠️ 迁移旧别名失败: \(error)")
            aliases = []
        }
    }

    // MARK: - 保存

    private func save() {
        let file = AliasFile(aliases: aliases)
        let url = fileURL
        queue.async {
            do {
                let encoder = YAMLEncoder()
                encoder.options.indent = 2
                var yaml = try encoder.encode(file)

                // Yams 默认 list 项之间不空行，加个空行更易读
                yaml = yaml.replacingOccurrences(of: "\n- ", with: "\n\n- ")

                // 文件头注释
                let header = """
                # RunProcess aliases
                #
                # 格式:
                #   aliases:
                #     - name: gs
                #       expansion: git status
                #
                # 修改后重启应用生效。

                """
                try (header + yaml).write(to: url, atomically: true, encoding: .utf8)
            } catch {
                print("⚠️ 保存别名失败: \(error)")
            }
        }
    }

    // MARK: - 增删查

    func add(_ alias: CommandAlias) {
        if let idx = aliases.firstIndex(where: { $0.name == alias.name }) {
            aliases[idx] = alias
        } else {
            aliases.append(alias)
        }
        save()
    }

    /// 整体替换所有别名（用于排序等批量操作）
    func replaceAll(_ aliases: [CommandAlias]) {
        self.aliases = aliases
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
