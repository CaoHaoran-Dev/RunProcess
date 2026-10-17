//
//  PathStore.swift
//  RunProcess
//
//  Created by Haoran on 2026/10/7.
//

import Foundation
import Yams

/// 用户配置的可执行文件搜索路径。
///
/// 用法：
/// - 命令行工具：调用 `customPathString()` 拿到用户自定义路径，
///   追加到子进程 PATH 末尾，由 zsh 按 PATH 顺序查找。
/// - `.app` bundle：由 `resolveCustomPath` 单独识别，
///   拼成 `open -b <bundleId>`。
final class PathStore {
    static let shared = PathStore()

    private(set) var paths: [String] = []
    private let fileURL: URL
    private let queue = DispatchQueue(label: "com.runprocess.paths", qos: .background)

    private init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("RunProcess")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("paths.yml")

        load()
    }

    // MARK: - 加载

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }

        do {
            let text = try String(contentsOf: fileURL, encoding: .utf8)
            let file = try YAMLDecoder().decode(PathFile.self, from: text)
            paths = file.paths
        } catch {
            print("⚠️ 加载路径失败: \(error)")
            paths = []
        }
    }

    /// 重新从磁盘读取（外部编辑 paths.yml 后调用）
    func reload() {
        load()
    }

    // MARK: - 保存

    private func save() {
        let file = PathFile(paths: paths)
        let url = fileURL

        queue.async {
            do {
                let encoder = YAMLEncoder()
                encoder.options.indent = 2
                let yaml = try encoder.encode(file)

                let header = """
                # RunProcess custom paths
                #
                # 用户自定义的可执行文件搜索路径。
                # 输入命令时，如果系统 PATH 找不到，就按顺序在这些目录里查找。
                # 支持 ~ 表示用户主目录。
                #
                # 修改后立即生效，无需重启。

                """
                try (header + yaml).write(to: url, atomically: true, encoding: .utf8)
            } catch {
                print("⚠️ 保存路径失败: \(error)")
            }
        }
    }

    // MARK: - 增删改

    func add(_ path: String) {
        let normalized = normalize(path)
        guard !normalized.isEmpty, !paths.contains(normalized) else { return }
        paths.append(normalized)
        save()
    }

    func remove(_ path: String) {
        paths.removeAll { $0 == path }
        save()
    }

    func replaceAll(_ newPaths: [String]) {
        paths = newPaths.map { normalize($0) }.filter { !$0.isEmpty }
        save()
    }

    func move(from: Int, to: Int) {
        guard to >= 0, to < paths.count else { return }
        paths.swapAt(from, to)
        save()
    }

    // MARK: - PATH 拼接

    /// 只返回用户自定义路径，用冒号连接。
    /// 调用方负责追加到现有 PATH 后面，不要覆盖。
    func customPathString() -> String {
        let userPaths = paths.map { ($0 as NSString).expandingTildeInPath }
        return userPaths.joined(separator: ":")
    }

    // MARK: - .app 查找

    /// 在用户配置的路径里查找同名 `.app` bundle（大小写不敏感）。
    /// 返回 `.app` 的真实路径，找不到返回 nil。
    func findApp(named name: String) -> String? {
        for dir in paths {
            let expanded = (dir as NSString).expandingTildeInPath

            // 精确匹配
            let exact = (expanded as NSString).appendingPathComponent(name + ".app")
            if isRealAppBundle(exact) {
                return exact
            }

            // 大小写不敏感
            if let real = findCaseInsensitive(in: expanded, appName: name),
               isRealAppBundle(real) {
                return real
            }
        }
        return nil
    }

    /// 在目录里大小写不敏感地查找 `<name>.app`
    private func findCaseInsensitive(in dir: String, appName: String) -> String? {
        guard let entries = try? FileManager.default.contentsOfDirectory(atPath: dir) else {
            return nil
        }
        let target = (appName + ".app").lowercased()
        for entry in entries {
            if entry.lowercased() == target {
                let full = (dir as NSString).appendingPathComponent(entry)
                if isDirectory(full) {
                    return full
                }
            }
        }
        return nil
    }

    /// 读取 `.app` 的 bundle identifier
    func bundleIdentifier(forAppAt path: String) -> String? {
        let plistPath = (path as NSString).appendingPathComponent("Contents/Info.plist")
        guard let dict = NSDictionary(contentsOfFile: plistPath),
              let bundleId = dict["CFBundleIdentifier"] as? String else {
            return nil
        }
        return bundleId
    }

    // MARK: - 校验

    func isValid(_ path: String) -> Bool {
        let expanded = (path as NSString).expandingTildeInPath
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: expanded, isDirectory: &isDir)
        return exists && isDir.boolValue
    }

    /// 路径是目录，并且含有 Contents/Info.plist，才认为是真 `.app`
    private func isRealAppBundle(_ path: String) -> Bool {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir),
              isDir.boolValue else { return false }

        let plist = (path as NSString).appendingPathComponent("Contents/Info.plist")
        return FileManager.default.fileExists(atPath: plist)
    }

    private func isDirectory(_ path: String) -> Bool {
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDir)
        return exists && isDir.boolValue
    }

    /// 把绝对路径转成 ~ 开头的形式
    private func normalize(_ path: String) -> String {
        let expanded = (path as NSString).expandingTildeInPath
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let homePrefix = home.hasSuffix("/") ? home : home + "/"

        if expanded == home {
            return "~"
        }
        if expanded.hasPrefix(homePrefix) {
            return "~/" + expanded.dropFirst(homePrefix.count)
        }
        return expanded
    }
}

// MARK: - YAML 顶层结构

private nonisolated struct PathFile: Codable {
    var paths: [String]
}
