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

    // MARK: - Key Prefix
    //
    // 正式版与 Beta 版共用同一套 UserDefaults，但 key 按 target 加前缀隔离，
    // 保证两版的偏好设置互不干扰。
    //   - 正式版：无前缀
    //   - Beta  ："beta." 前缀

    private static var keyPrefix: String {
        AppEnvironment.isBeta ? "beta." : ""
    }

    // MARK: - Update Channel

    /// 更新源通道
    enum UpdateChannel: String, CaseIterable {
        case github
        case cloudflare
        case custom

        var displayNameKey: String {
            switch self {
            case .github:     return "updates.channel.github"
            case .cloudflare: return "updates.channel.cloudflare"
            case .custom:     return "updates.channel.custom"
            }
        }
    }

    // MARK: - Keys

    enum Keys {
        static var sessionModeEnabled: String     { keyPrefix + "session.enabled" }
        static var defaultWorkingDirectory: String { keyPrefix + "workingDirectory.default" }
        static var appearanceStyle: String         { keyPrefix + "appearance.style" }
        static var mainUIMode: String              { keyPrefix + "interface.mainUIMode" }
        static var hideOnDeactivate: String        { keyPrefix + "window.hideOnDeactivate" }
        static var defaultSudo: String             { keyPrefix + "sudo.default" }
        static var launchAtLogin: String           { keyPrefix + "startup.launchAtLogin" }
        static var hideWindowOnLaunch: String      { keyPrefix + "startup.hideOnLaunch" }
        static var outputColorsEnabled: String     { keyPrefix + "output.colorsEnabled" }
        static var outputColorScheme: String       { keyPrefix + "output.colorScheme" }
        static var explainErrors: String           { keyPrefix + "output.explainErrors" }

        // 更新源
        static var updateChannel: String           { keyPrefix + "updates.channel" }
        static var customUpdateURL: String         { keyPrefix + "updates.customURL" }

        // Shell 与自定义 PATH 注入
        static var shellPath: String               { keyPrefix + "shell.path" }
        static var customPathEnabled: String       { keyPrefix + "paths.customEnabled" }
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

    // MARK: - Shell

    /// 当前选择的 shell 绝对路径。默认 /bin/zsh。
    static var shellPathRaw: String {
        get {
            let raw = defaults.string(forKey: Keys.shellPath) ?? ""
            return raw.isEmpty ? "/bin/zsh" : raw
        }
        set { defaults.set(newValue, forKey: Keys.shellPath) }
    }

    /// 生效的 shell 路径（若文件不存在回退到 /bin/zsh）
    static var resolvedShellPath: String {
        let raw = shellPathRaw
        if FileManager.default.isExecutableFile(atPath: raw) {
            return raw
        }
        return "/bin/zsh"
    }

    /// 当前选择的是否为 zsh（会话模式与 PATH 注入仅 zsh 可用）
    static var isZshShell: Bool {
        (resolvedShellPath as NSString).lastPathComponent == "zsh"
    }

    // MARK: - 会话模式

    static var sessionModeEnabled: Bool {
        get {
            // 非 zsh 强制关闭
            guard isZshShell else { return false }
            return defaults.bool(forKey: Keys.sessionModeEnabled)
        }
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
                return true
            }
            return defaults.bool(forKey: Keys.explainErrors)
        }
        set { defaults.set(newValue, forKey: Keys.explainErrors) }
    }

    // MARK: - 自定义 PATH 注入

    /// 是否把 PathStore 里的自定义路径追加到子进程 PATH。
    /// 仅 zsh 可用；非 zsh 强制关闭。
    static var customPathEnabled: Bool {
        get {
            guard isZshShell else { return false }
            if defaults.object(forKey: Keys.customPathEnabled) == nil {
                return true
            }
            return defaults.bool(forKey: Keys.customPathEnabled)
        }
        set { defaults.set(newValue, forKey: Keys.customPathEnabled) }
    }

    // MARK: - 更新源

    static var updateChannel: UpdateChannel {
        get {
            let raw = defaults.string(forKey: Keys.updateChannel) ?? ""
            return UpdateChannel(rawValue: raw) ?? .github // 默认 GitHub
        }
        set { defaults.set(newValue.rawValue, forKey: Keys.updateChannel) }
    }

    static var customUpdateURL: String {
        get { defaults.string(forKey: Keys.customUpdateURL) ?? "" }
        set { defaults.set(newValue, forKey: Keys.customUpdateURL) }
    }
}
