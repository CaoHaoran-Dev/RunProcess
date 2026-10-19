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

/// 主界面风格
enum MainUIMode: String, CaseIterable {
    case classic
    case lite

    var displayNameKey: String {
        switch self {
        case .classic: return "interface.mode.classic"
        case .lite:    return "interface.mode.lite"
        }
    }
}

/// 全局设置，封装 UserDefaults
enum AppSettings {

    // MARK: - Keys

    enum Keys {
        static let sessionModeEnabled = "session.enabled"
        static let defaultWorkingDirectory = "workingDirectory.default"
        static let appearanceStyle = "appearance.style"
        static let mainUIMode = "interface.mainUIMode"
        static let hideOnDeactivate = "window.hideOnDeactivate"
        static let defaultSudo = "sudo.default"
        static let launchAtLogin = "startup.launchAtLogin"
        static let hideWindowOnLaunch = "startup.hideOnLaunch"
        static let outputColorsEnabled = "output.colorsEnabled"
        static let outputColorScheme = "output.colorScheme"
        static let explainErrors = "output.explainErrors" // 👈 新增
    }

    private static let defaults = UserDefaults.standard

    // MARK: - 界面模式

    static var mainUIMode: MainUIMode {
        get {
            let raw = defaults.string(forKey: Keys.mainUIMode) ?? ""
            return MainUIMode(rawValue: raw) ?? .classic
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.mainUIMode)
        }
    }

    // MARK: - 会话模式

    static var sessionModeEnabled: Bool {
        get { defaults.bool(forKey: Keys.sessionModeEnabled) }
        set { defaults.set(newValue, forKey: Keys.sessionModeEnabled) }
    }

    // MARK: - 默认工作目录
    
    static var defaultWorkingDirectoryRaw: String {
        get { defaults.string(forKey: Keys.defaultWorkingDirectory) ?? "" }
        set { defaults.set(newValue, forKey: Keys.defaultWorkingDirectory) }
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

    static var appearanceStyleRaw: AppearanceStyle {
        get {
            let raw = defaults.string(forKey: Keys.appearanceStyle) ?? ""
            return AppearanceStyle(rawValue: raw) ?? defaultAppearance
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.appearanceStyle)
        }
    }

    static var resolvedAppearanceStyle: AppearanceStyle {
        let raw = appearanceStyleRaw
        if raw == .liquidGlass && !AppearanceStyle.liquidGlass.isSupported {
            return .frostedGlass
        }
        return raw
    }

    private static var defaultAppearance: AppearanceStyle {
        if #available(macOS 26.0, *) {
            return .liquidGlass
        }
        return .frostedGlass
    }

    // MARK: - 失焦关闭

    static var hideOnDeactivate: Bool {
        get {
            if defaults.object(forKey: Keys.hideOnDeactivate) == nil {
                return true
            }
            return defaults.bool(forKey: Keys.hideOnDeactivate)
        }
        set { defaults.set(newValue, forKey: Keys.hideOnDeactivate) }
    }

    // MARK: - 默认 Sudo

    static var defaultSudo: Bool {
        get { defaults.bool(forKey: Keys.defaultSudo) }
        set { defaults.set(newValue, forKey: Keys.defaultSudo) }
    }

    // MARK: - 启动

    static var launchAtLogin: Bool {
        get { defaults.bool(forKey: Keys.launchAtLogin) }
        set { defaults.set(newValue, forKey: Keys.launchAtLogin) }
    }

    static var hideWindowOnLaunch: Bool {
        get { defaults.bool(forKey: Keys.hideWindowOnLaunch) }
        set { defaults.set(newValue, forKey: Keys.hideWindowOnLaunch) }
    }

    // MARK: - 输出颜色

    static var outputColorsEnabled: Bool {
        get {
            if defaults.object(forKey: Keys.outputColorsEnabled) == nil {
                return true
            }
            return defaults.bool(forKey: Keys.outputColorsEnabled)
        }
        set { defaults.set(newValue, forKey: Keys.outputColorsEnabled) }
    }

    enum OutputColorScheme: String, CaseIterable {
        case auto
        case dark
        case light

        var displayNameKey: String {
            switch self {
            case .auto:  return "output.colors.scheme.auto"
            case .dark:  return "output.colors.scheme.dark"
            case .light: return "output.colors.scheme.light"
            }
        }
    }

    static var outputColorScheme: OutputColorScheme {
        get {
            let raw = defaults.string(forKey: Keys.outputColorScheme) ?? ""
            return OutputColorScheme(rawValue: raw) ?? .auto
        }
        set { defaults.set(newValue.rawValue, forKey: Keys.outputColorScheme) }
    }
    
    // MARK: - 错误解释
    
    static var explainErrors: Bool {
        get {
            if defaults.object(forKey: Keys.explainErrors) == nil {
                return true // 默认开启
            }
            return defaults.bool(forKey: Keys.explainErrors)
        }
        set { defaults.set(newValue, forKey: Keys.explainErrors) }
    }
}
