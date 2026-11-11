//
//  AppEnvironment.swift
//  RunProcess
//
//  Created by Haoran on 2026/10/18.
//

import Foundation

enum AppEnvironment {

    /// 是否为测试构建（由 test target 的 Other Swift Flags 注入 -D RUNPROCESS_TEST）
    static var isTest: Bool {
        #if RUNPROCESS_TEST
        return true
        #else
        return false
        #endif
    }

    /// 是否为 Preview / Beta 构建（-D BETA）
    static var isBeta: Bool {
        #if BETA
        return true
        #else
        return false
        #endif
    }

    /// 用户数据目录名。
    /// - 正式版：RunProcess
    /// - Preview / Beta：RunProcess-Beta
    static var appSupportFolderName: String {
        if isBeta { return "RunProcess-Beta" }
        return "RunProcess"
    }
}

// MARK: - 旧数据目录迁移

/// 早期版本把 Beta / 测试构建的数据写到 `RunProcess-Beta-Test/`。
/// 这里在新目录不存在、旧目录存在时做一次性整体搬移。
enum AppDataMigration {
    static func migrateLegacyTestFolderIfNeeded() {
        guard AppEnvironment.isBeta else { return }

        let fm = FileManager.default
        guard let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return
        }

        let old = base.appendingPathComponent("RunProcess-Beta-Test")
        let new = base.appendingPathComponent(AppEnvironment.appSupportFolderName)

        guard fm.fileExists(atPath: old.path),
              !fm.fileExists(atPath: new.path) else { return }

        do {
            try fm.moveItem(at: old, to: new)
            print("📦 已迁移旧数据目录: RunProcess-Beta-Test → \(new.lastPathComponent)")
        } catch {
            print("⚠️ 迁移旧数据目录失败: \(error)")
        }
    }
}
