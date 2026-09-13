//
//  AppSettings.swift
//  RunProcess
//
//  Created by Haoran on 2026/9/13.
//

import Foundation

/// 全局设置，封装 UserDefaults
///
/// 注意：不要叫 `Settings`，会与 SwiftUI 的 `Settings` 场景类型冲突。
enum AppSettings {
    
    private static let defaults = UserDefaults.standard
    
    // MARK: - Keys
    
    private enum Key {
        static let sessionModeEnabled = "session.enabled"
        static let defaultWorkingDirectory = "workingDirectory.default"
    }
    
    // MARK: - 会话模式
    
    /// 是否启用会话模式（持久 shell）
    /// 默认 false，开启后只影响新窗口
    static var sessionModeEnabled: Bool {
        get { defaults.bool(forKey: Key.sessionModeEnabled) }
        set { defaults.set(newValue, forKey: Key.sessionModeEnabled) }
    }
    
    // MARK: - 默认工作目录
    
    /// 用户设置的工作目录（原始值，可能包含 `~`，可能为空）
    static var defaultWorkingDirectoryRaw: String {
        get { defaults.string(forKey: Key.defaultWorkingDirectory) ?? "" }
        set { defaults.set(newValue, forKey: Key.defaultWorkingDirectory) }
    }
    
    /// 解析后的实际工作目录
    ///
    /// - 如果未设置，返回用户主目录
    /// - 如果设置了但路径不存在，回退到用户主目录
    /// - 支持 `~` 展开
    static var resolvedWorkingDirectory: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let raw = defaultWorkingDirectoryRaw
        guard !raw.isEmpty else { return home }
        
        let expanded = (raw as NSString).expandingTildeInPath
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: expanded, isDirectory: &isDirectory)
        
        if exists && isDirectory.boolValue {
            return expanded
        } else {
            return home
        }
    }
    
    /// 设置的工作目录是否有效（用于 UI 显示警告）
    ///
    /// - 未设置时返回 true（表示用 home，是"有效"的默认状态）
    /// - 设置了但路径无效时返回 false
    static var isWorkingDirectoryValid: Bool {
        let raw = defaultWorkingDirectoryRaw
        guard !raw.isEmpty else { return true }
        
        let expanded = (raw as NSString).expandingTildeInPath
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: expanded, isDirectory: &isDirectory)
        return exists && isDirectory.boolValue
    }
    
    /// 用于 UI 显示的缩写路径
    ///
    /// - 未设置时返回空字符串
    /// - 设置了返回 `~` 缩写后的路径
    static var displayWorkingDirectory: String {
        let raw = defaultWorkingDirectoryRaw
        guard !raw.isEmpty else { return "" }
        return (raw as NSString).abbreviatingWithTildeInPath
    }
}
