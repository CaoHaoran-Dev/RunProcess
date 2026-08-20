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
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        createWindow()
        setupStatusBar()
    }
    
    func createWindow() {
        let contentView = ContentView()
        let hostingController = NSHostingController(rootView: contentView)
        
        window = NSWindow(contentViewController: hostingController)
        window?.title = "RunProcess"
        window?.setContentSize(NSSize(width: 520, height: 160))
        window?.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
        window?.titlebarAppearsTransparent = true
        window?.isMovableByWindowBackground = true
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        window?.delegate = self
    }
    
    func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.title = "⚡"
        statusItem?.button?.action = #selector(toggleWindow)
        statusItem?.button?.target = self
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
}

extension AppDelegate: NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil) // 点击关闭只是隐藏
        return false
    }
}
