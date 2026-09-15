//
//  KeyboardShortcuts+Names.swift
//  RunProcess
//
//  Created by Haoran on 2026/9/13.
//

import KeyboardShortcuts
internal import AppKit

extension KeyboardShortcuts.Name {
    /// 全局显示 / 隐藏窗口
    /// 默认 ⌘⌥R，用户可在"快捷键设置"中自定义
    static let toggleWindow = Self(
        "toggleWindow",
        initial: .init(.r, modifiers: [.command, .option])
    )
}
