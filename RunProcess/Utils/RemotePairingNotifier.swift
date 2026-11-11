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

    /// 在 App 启动时调用一次，请求权限并注册通知类别。
    static func requestAuthorizationIfNeeded() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error {
                print("⚠️ 通知权限请求失败: \(error)")
            }
            print("🔔 通知权限: \(granted)")
        }

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

    /// 发送配对码通知。`code` 是 6 位数字。
    /// 注意：body 必须是最终文本，不能包含 `%@` 之类的占位符，
    /// 系统会剥离 printf 风格转义字符。
    static func notifyPairingCode(_ code: String) {
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

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("⚠️ 发送配对通知失败: \(error)")
            }
        }
    }
}

#endif
