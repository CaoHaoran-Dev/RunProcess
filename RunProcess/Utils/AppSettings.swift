//
//  AppSettings.swift
//  RunProcess
//
//  Created by Haoran on 2026/9/13.
//

import Foundation

/// 外观风格
enum AppearanceStyle: String, CaseIterable {
    case none
    case frostedGlass
    case liquidGlass
    
    var displayNameKey: String {
        switch self {
        case .none: return "appearance.none"
        case .frostedGlass: return "appearance.frostedGlass"
        case .liquidGlass: return "appearance.liquidGlass"
        }
    }
    
    /// 当前系统是否支持该风格
    var isSupported: Bool {
        switch self {
        case .none, .frostedGlass:
            return true
        case .liquidGlass:
            if #available(macOS 26.0, *) { return true }
            return false
        }
    }
}

/// 全局设置，封装 UserDefaults
///
/// 注意：不要叫 `Settings`，会与 SwiftUI 的 `Settings` 场景类型冲突。
enum AppSettings {
    
    private static let defaults = UserDefaults.standard
    
    // MARK: - Keys
    
    private enum Key {
        static let sessionModeEnabled = "session.enabled"
        static let defaultWorkingDirectory = "workingDirectory.default"
        static let appearanceStyle = "appearance.style"
        static let hideOnDeactivate = "window.hideOnDeactivate"
    }
    
    // MARK: - 会话模式
    
    static var sessionModeEnabled: Bool {
        get { defaults.bool(forKey: Key.sessionModeEnabled) }
        set { defaults.set(newValue, forKey: Key.sessionModeEnabled) }
    }
    
    // MARK: - 默认工作目录
    
    static var defaultWorkingDirectoryRaw: String {
        get { defaults.string(forKey: Key.defaultWorkingDirectory) ?? "" }
        set { defaults.set(newValue, forKey: Key.defaultWorkingDirectory) }
    }
    
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
    
    static var isWorkingDirectoryValid: Bool {
        let raw = defaultWorkingDirectoryRaw
        guard !raw.isEmpty else { return true }
        
        let expanded = (raw as NSString).expandingTildeInPath
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: expanded, isDirectory: &isDirectory)
        return exists && isDirectory.boolValue
    }
    
    static var displayWorkingDirectory: String {
        let raw = defaultWorkingDirectoryRaw
        guard !raw.isEmpty else { return "" }
        return (raw as NSString).abbreviatingWithTildeInPath
    }
    
    // MARK: - 外观风格
    
    /// 用户选择的原始外观风格（可能包含 macOS 15 不支持的 liquidGlass）
    static var appearanceStyleRaw: AppearanceStyle {
        get {
            let raw = defaults.string(forKey: Key.appearanceStyle) ?? ""
            return AppearanceStyle(rawValue: raw) ?? defaultAppearance
        }
        set {
            defaults.set(newValue.rawValue, forKey: Key.appearanceStyle)
        }
    }
    
    /// 根据系统版本解析后的实际外观风格
    ///
    /// - macOS 15 及以下：liquidGlass 回退到 frostedGlass
    /// - 默认值：macOS 26+ 为 liquidGlass，否则 frostedGlass
    static var resolvedAppearanceStyle: AppearanceStyle {
        let raw = appearanceStyleRaw
        if raw == .liquidGlass && !AppearanceStyle.liquidGlass.isSupported {
            return .frostedGlass
        }
        return raw
    }
    
    /// 系统默认外观：macOS 26+ 液态玻璃，否则毛玻璃
    private static var defaultAppearance: AppearanceStyle {
        if #available(macOS 26.0, *) {
            return .liquidGlass
        }
        return .frostedGlass
    }
    
    // MARK: - 失焦关闭
    
    /// 窗口失去焦点（App 不再 active）时是否自动隐藏
    /// 默认 true
    static var hideOnDeactivate: Bool {
        get {
            // 未设置过时返回 true
            if defaults.object(forKey: Key.hideOnDeactivate) == nil {
                return true
            }
            return defaults.bool(forKey: Key.hideOnDeactivate)
        }
        set { defaults.set(newValue, forKey: Key.hideOnDeactivate) }
    }
}
