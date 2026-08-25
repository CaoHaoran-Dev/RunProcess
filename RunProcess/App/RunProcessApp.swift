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
    
    private lazy var statusMenu: NSMenu = {
        let menu = NSMenu()
        
        let toggleItem = NSMenuItem(
            title: NSLocalizedString("menu.toggle.window", comment: "Toggle window menu item"),
            action: #selector(toggleWindow),
            keyEquivalent: "r"
        )
        toggleItem.keyEquivalentModifierMask = [.command, .option]
        toggleItem.target = self
        menu.addItem(toggleItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let clearItem = NSMenuItem(
            title: NSLocalizedString("menu.clear.history", comment: "Clear history menu item"),
            action: #selector(clearHistory),
            keyEquivalent: ""
        )
        clearItem.target = self
        menu.addItem(clearItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(
            title: NSLocalizedString("menu.quit", comment: "Quit menu item"),
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.keyEquivalentModifierMask = .command
        quitItem.target = self
        menu.addItem(quitItem)
        
        return menu
    }()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
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
        
        window?.styleMask = [
            .titled,
            .closable,
            .miniaturizable,
            .resizable,
            .fullSizeContentView
        ]
        window?.titlebarAppearsTransparent = true
        window?.isMovableByWindowBackground = true
        window?.isOpaque = false
        window?.backgroundColor = .clear
        
        window?.center()
        window?.level = .floating
        window?.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
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
    
    private func setupGlobalHotkey() {
        hotKey = HotKey(key: .r, modifiers: [.command, .option])
        
        hotKey?.keyDownHandler = { [weak self] in
            DispatchQueue.main.async {
                self?.toggleWindow()
            }
        }
        
        print("✅ Global hotkey registered: ⌘⌥R")
    }
    
    @objc func toggleMenu() {
        statusItem?.menu = statusMenu
        statusItem?.button?.performClick(nil)
    }
    
    @objc func toggleWindow() {
        guard let window = window else { return }
        if window.isVisible {
            window.orderOut(nil)
        } else {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            
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
        alert.messageText = NSLocalizedString("alert.history.cleared.title", comment: "History cleared alert title")
        alert.informativeText = NSLocalizedString("alert.history.cleared.message", comment: "History cleared alert message")
        alert.alertStyle = .informational
        alert.addButton(withTitle: NSLocalizedString("button.ok", comment: "OK button"))
        alert.runModal()
    }
    
    @objc func quitApp() {
        hotKey = nil
        NSApp.terminate(nil)
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        print("🛑 RunProcess is exiting")
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }
}
