//
//  ShellStore.swift
//  RunProcess
//
//  Created by Haoran on 2026/10/23.
//

#if BETA

import Foundation

/// 可选 shell 列表。内置常见 shell，同时支持用户自定义添加。
/// Beta 专属功能。
final class ShellStore {
    static let shared = ShellStore()

    struct Entry: Identifiable, Hashable {
        let path: String
        var id: String { path }
        var name: String { (path as NSString).lastPathComponent }
    }

    /// 内置候选（存在才展示）
    private static let builtinCandidates: [String] = [
        "/bin/zsh",
        "/bin/bash",
        "/bin/sh",
        "/bin/dash",
        "/bin/ksh",
        "/bin/csh",
        "/bin/tcsh",
        "/usr/bin/fish",
        "/usr/local/bin/fish",
        "/opt/homebrew/bin/fish",
        "/usr/local/bin/bash",
        "/opt/homebrew/bin/bash",
        "/usr/local/bin/zsh",
        "/opt/homebrew/bin/zsh",
        "/usr/local/bin/nu",
        "/opt/homebrew/bin/nu",
        "/usr/local/bin/elvish",
        "/opt/homebrew/bin/elvish",
        "/usr/local/bin/xonsh",
        "/opt/homebrew/bin/xonsh",
        "/usr/local/bin/oil",
        "/opt/homebrew/bin/oil",
    ]

    private var customPath: String? {
        get {
            let raw = UserDefaults.standard.string(forKey: "shell.customPath") ?? ""
            return raw.isEmpty ? nil : raw
        }
        set {
            UserDefaults.standard.set(newValue ?? "", forKey: "shell.customPath")
        }
    }

    private init() {}

    /// 返回所有可用 shell（内置中存在的 + 用户自定义 + 当前选中的）
    func availableShells() -> [Entry] {
        var seen = Set<String>()
        var result: [Entry] = []

        for path in Self.builtinCandidates {
            guard FileManager.default.isExecutableFile(atPath: path) else { continue }
            let resolved = resolveSymlink(path)
            guard seen.insert(resolved).inserted else { continue }
            result.append(Entry(path: resolved))
        }

        if let custom = customPath,
           FileManager.default.isExecutableFile(atPath: custom) {
            let resolved = resolveSymlink(custom)
            if seen.insert(resolved).inserted {
                result.append(Entry(path: resolved))
            }
        }

        let current = AppSettings.resolvedShellPath
        if FileManager.default.isExecutableFile(atPath: current) {
            let resolved = resolveSymlink(current)
            if seen.insert(resolved).inserted {
                result.append(Entry(path: resolved))
            }
        }

        return result.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// 用户通过 NSOpenPanel 添加自定义 shell
    func addCustomShell(path: String) {
        let resolved = resolveSymlink(path)
        guard FileManager.default.isExecutableFile(atPath: resolved) else { return }
        customPath = resolved
        AppSettings.shellPathRaw = resolved
    }

    func removeCustomShell() {
        customPath = nil
    }

    /// 选择某个 shell
    func selectShell(path: String) {
        let resolved = resolveSymlink(path)
        guard FileManager.default.isExecutableFile(atPath: resolved) else { return }
        AppSettings.shellPathRaw = resolved
    }

    /// 解析符号链接，避免重复（/bin/sh -> /bin/bash 等）
    private func resolveSymlink(_ path: String) -> String {
        let url = URL(fileURLWithPath: path)
        let resolved = url.resolvingSymlinksInPath()
        if resolved.path != path {
            return resolved.path
        }
        return path
    }
}

#endif
