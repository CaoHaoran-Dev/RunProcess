//
//  RunProcessApp.swift
//  RunProcess
//
//  Created by Haoran on 2026/8/19.
//

import SwiftUI
import HotKey

@main
struct RunProcessApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow?
    var statusItem: NSStatusItem?
    var viewModel: CommandViewModel?
    private var hotKey: HotKey?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 隐藏 Dock 图标
        NSApp.setActivationPolicy(.accessory)
        
        createWindow()
        setupStatusBar()
        setupGlobalHotkey()
    }
    
    func createWindow() {
        let viewModel = CommandViewModel()
        self.viewModel = viewModel
        
        let contentView = ContentView(viewModel: viewModel)
        let hostingController = NSHostingController(rootView: contentView)
        
        window = NSWindow(contentViewController: hostingController)
        window?.title = "RunProcess"
        window?.setContentSize(NSSize(width: 520, height: 160))
        
        // ✅ 标准窗口样式：有红绿灯 + 可调整大小
        window?.styleMask = [
            .titled,           // 标题栏（显示红绿灯）
            .closable,         // 关闭按钮
            .miniaturizable,   // 最小化按钮
            .resizable,        // 可调整大小（右下角拖拽）
            .fullSizeContentView
        ]
        window?.titlebarAppearsTransparent = true
        window?.isMovableByWindowBackground = true
        window?.isOpaque = false
        window?.backgroundColor = .clear
        
        // ✅ 居中显示
        window?.center()
        
        // ✅ 设置为浮动窗口（类似 Spotlight）
        window?.level = .floating
        window?.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        // ✅ 点击其他区域时不关闭（但可以保持焦点）
        window?.makeKeyAndOrderFront(nil)
        window?.delegate = self
    }
    
    func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            let image = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: "RunProcess")
            image?.isTemplate = true
            button.image = image
            button.imagePosition = .imageOnly
            button.action = #selector(toggleMenu)
            button.target = self
        }
    }
    
    // MARK: - 全局快捷键（使用 HotKey 库）
    
    private func setupGlobalHotkey() {
        hotKey = HotKey(key: .r, modifiers: [.command, .option])
        
        hotKey?.keyDownHandler = { [weak self] in
            DispatchQueue.main.async {
                self?.toggleWindow()
            }
        }
        
        print("✅ 全局热键注册成功: ⌘⌥R")
    }
    
    @objc func toggleMenu() {
        let menu = NSMenu()
        
        let toggleItem = NSMenuItem(
            title: "显示/隐藏窗口",
            action: #selector(toggleWindow),
            keyEquivalent: ""
        )
        toggleItem.keyEquivalentModifierMask = [.command, .option]
        toggleItem.keyEquivalent = "r"
        menu.addItem(toggleItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let clearItem = NSMenuItem(
            title: "清空历史命令",
            action: #selector(clearHistory),
            keyEquivalent: ""
        )
        clearItem.target = self
        menu.addItem(clearItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(
            title: "退出",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.keyEquivalentModifierMask = .command
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
    }
    
    @objc func toggleWindow() {
        guard let window = window else { return }
        if window.isVisible {
            window.orderOut(nil)
        } else {
            // ✅ 显示并激活
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            
            // ✅ 自动聚焦到输入框
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NotificationCenter.default.post(
                    name: NSNotification.Name("FocusTextField"),
                    object: nil
                )
            }
        }
    }
    
    @objc func clearHistory() {
        viewModel?.clearHistory()
        
        let alert = NSAlert()
        alert.messageText = "已清空"
        alert.informativeText = "所有历史命令已删除"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "确定")
        alert.runModal()
    }
    
    @objc func quitApp() {
        hotKey = nil
        NSApp.terminate(nil)
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        print("🛑 RunProcess 即将退出")
    }
}

// MARK: - NSWindowDelegate

extension AppDelegate: NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // 点击关闭按钮 → 隐藏窗口而不是退出
        sender.orderOut(nil)
        return false
    }
}
