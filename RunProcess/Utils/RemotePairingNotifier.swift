//
//  RemotePairingNotifier.swift
//  RunProcess
//
//  Created by Haoran on 2026/11/11.
//

#if BETA

import Foundation
import UserNotifications
internal import AppKit

nonisolated enum RemotePairingNotifier {

    private static let categoryId = "RunProcessPairingCode"

    /// 在 App 启动时调用一次，注册通知类别。
    static func registerCategoryIfNeeded() {
        let center = UNUserNotificationCenter.current()

        let openAction = UNNotificationAction(
            identifier: "OPEN_SETTINGS",
            title: NSLocalizedString("notification.pairing.open", comment: ""),
            options: [.foreground]
        )
        let category = UNNotificationCategory(
            identifier: categoryId,
            actions: [openAction],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([category])
    }

    /// 请求通知权限（启动时调用一次）。
    static func requestAuthorizationIfNeeded() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error {
                print("⚠️ 通知权限请求失败: \(error)")
            }
            print("🔔 通知权限: \(granted)")
        }
    }

    /// 当前是否已授权系统通知。
    static func isAuthorized() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied, .notDetermined:
            return false
        @unknown default:
            return false
        }
    }

    /// 发送配对码通知。
    /// 返回是否成功投递到系统通知中心。
    /// 调用方在返回 false 时应走 App 内提示兜底。
    @discardableResult
    static func notifyPairingCode(_ code: String) async -> Bool {
        guard await isAuthorized() else { return false }

        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("notification.pairing.title", comment: "")

        let format = NSLocalizedString("notification.pairing.body", comment: "")
        content.body = String(format: format, code)

        content.sound = .default
        content.categoryIdentifier = categoryId
        content.userInfo = ["pairingCode": code]

        let request = UNNotificationRequest(
            identifier: "pairing-\(code)-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            return true
        } catch {
            print("⚠️ 发送配对通知失败: \(error)")
            return false
        }
    }
}

#endif
