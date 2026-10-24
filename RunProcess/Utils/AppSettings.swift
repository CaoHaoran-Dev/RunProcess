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
        static let explainErrors = "output.explainErrors"
        
        // 更新源
        static let updateChannel = "updates.channel"
        static let customUpdateURL = "updates.customURL"
        
        #if BETA
        // 👇 Beta 专属：自定义 shell 与 PATH 注入开关
        static let shellPath = "shell.path"
        static let customPathEnabled = "paths.customEnabled"
        #endif
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

    // MARK: - Shell（Beta 专属）

    #if BETA
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
    #else
    // 非 Beta 固定 zsh
    static var shellPathRaw: String {
        get { "/bin/zsh" }
        set { _ = newValue }
    }
    static var resolvedShellPath: String { "/bin/zsh" }
    static var isZshShell: Bool { true }
    #endif

    // MARK: - 会话模式

    static var sessionModeEnabled: Bool {
        get {
            #if BETA
            // 非 zsh 强制关闭
            guard isZshShell else { return false }
            #endif
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

    // MARK: - 自定义 PATH 注入（Beta 专属）

    #if BETA
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
    #else
    /// 正式版固定开启（保持原有行为）
    static var customPathEnabled: Bool {
        get { true }
        set { _ = newValue }
    }
    #endif
    
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
