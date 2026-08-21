//
//  RunProcessApp.swift
//  RunProcess
//
//  Created by Haoran on 2026/8/19.
//

import SwiftUI

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
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 隐藏 Dock 图标
        NSApp.setActivationPolicy(.accessory)
        
        createWindow()
        setupStatusBar()
    }
    
    func createWindow() {
        let viewModel = CommandViewModel()
        self.viewModel = viewModel
        
        let contentView = ContentView(viewModel: viewModel)
        let hostingController = NSHostingController(rootView: contentView)
        
        window = NSWindow(contentViewController: hostingController)
        window?.title = "RunProcess"
        window?.setContentSize(NSSize(width: 520, height: 160))
        window?.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
        window?.titlebarAppearsTransparent = true
        window?.isMovableByWindowBackground = true
        window?.isOpaque = false
        window?.backgroundColor = .clear
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        window?.delegate = self
    }
    
    func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            let image = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: "RunProcess")
            image?.isTemplate = true
            button.image = image
            button.action = #selector(toggleMenu)
            button.target = self
        }
    }
    
    @objc func toggleMenu() {
        let menu = NSMenu()
        
        let toggleItem = NSMenuItem(
            title: window?.isVisible == true ? "显示/隐藏窗口" : "显示窗口",
            action: #selector(toggleWindow),
            keyEquivalent: ""
        )
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
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
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
        NSApp.terminate(nil)
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        print("🛑 RunProcess 即将退出")
    }
}

// MARK: - NSWindowDelegate

extension AppDelegate: NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }
}
