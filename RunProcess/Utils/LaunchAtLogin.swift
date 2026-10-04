//
//  LaunchAtLogin.swift
//  RunProcess
//
//  Created by Haoran on 2026/10/4.
//

import Foundation
import ServiceManagement

/// 封装开机自启动。macOS 13+ 用 SMAppService。
enum LaunchAtLogin {

    /// 当前系统是否支持（macOS 13+）
    static var isSupported: Bool {
        if #available(macOS 13.0, *) { return true }
        return false
    }

    /// 系统里当前是否已注册为登录项
    static var isEnabled: Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }

    /// 尝试设置开机自启动。返回是否成功。
    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        guard #available(macOS 13.0, *) else { return false }
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
            AppSettings.launchAtLogin = enabled
            return true
        } catch {
            print("⚠️ 设置开机自启动失败: \(error)")
            return false
        }
    }
}
