//
//  RunProcessApp.swift
//  RunProcess
//
//  Created by Haoran on 2026/8/19.
//

import SwiftUI
import KeyboardShortcuts

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
    
    private let sessionManager = SessionManager()
    
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    private var aboutWindow: NSWindow?
    
    // MARK: - Menu
    
    private lazy var statusMenu: NSMenu = {
        let menu = NSMenu()
        
        let newWindowItem = NSMenuItem(
            title: NSLocalizedString("menu.new.window", comment: "New window menu item"),
            action: #selector(newWindow),
            keyEquivalent: "n"
        )
        newWindowItem.target = self
        menu.addItem(newWindowItem)
        
        let toggleItem = NSMenuItem(
            title: NSLocalizedString("menu.toggle.window", comment: "Toggle window menu item"),
            action: #selector(toggleWindow),
            keyEquivalent: ""
        )
        toggleItem.target = self
        menu.addItem(toggleItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let settingsItem = NSMenuItem(
            title: NSLocalizedString("menu.settings", comment: "Settings menu item"),
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.keyEquivalentModifierMask = .command
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        let clearItem = NSMenuItem(
            title: NSLocalizedString("menu.clear.history", comment: "Clear history menu item"),
            action: #selector(clearHistory),
            keyEquivalent: ""
        )
        clearItem.target = self
        menu.addItem(clearItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let aboutItem = NSMenuItem(
            title: NSLocalizedString("menu.about", comment: "About menu item"),
            action: #selector(openAbout),
            keyEquivalent: ""
        )
        aboutItem.target = self
        menu.addItem(aboutItem)
        
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
    
    // MARK: - Lifecycle
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        
        setupStatusBar()
        setupGlobalHotkey()
        
        _ = sessionManager.newSession()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        sessionManager.removeAll()
        print("🛑 RunProcess is exiting")
    }
    
    // MARK: - Status Bar
    
    private func setupStatusBar() {
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
    
    // MARK: - Global Hotkey
    
    private func setupGlobalHotkey() {
        KeyboardShortcuts.onKeyUp(for: .toggleWindow) { [weak self] in
            Task { @MainActor in
                self?.toggleWindow()
            }
        }
    }
    
    // MARK: - Actions
    
    @objc func toggleMenu() {
        statusItem?.menu = statusMenu
        statusItem?.button?.performClick(nil)
    }
    
    @objc func newWindow() {
        _ = sessionManager.newSession()
    }
    
    @objc func toggleWindow() {
        guard let session = sessionManager.activeSession() else {
            _ = sessionManager.newSession()
            return
        }
        
        if session.isVisible() {
            session.hide()
        } else {
            session.show()
            NSApp.activate(ignoringOtherApps: true)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NotificationCenter.default.post(
                    name: NSNotification.Name("FocusTextField"),
                    object: nil
                )
            }
        }
    }
    
    @objc func openSettings() {
        if let existing = settingsWindow, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let view = SettingsView()
        let hostingController = NSHostingController(rootView: view)
        
        let window = NSWindow(contentViewController: hostingController)
        window.title = NSLocalizedString("window.settings.title", comment: "Settings window title")
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        window.level = .floating
        
        settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func clearHistory() {
        CommandHistory().clearAll()
        
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("alert.history.cleared.title", comment: "History cleared alert title")
        alert.informativeText = NSLocalizedString("alert.history.cleared.message", comment: "History cleared alert message")
        alert.alertStyle = .informational
        alert.addButton(withTitle: NSLocalizedString("button.ok", comment: "OK button"))
        alert.runModal()
    }
    
    @objc func openAbout() {
        if let existing = aboutWindow, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let view = AboutView()
        let hostingController = NSHostingController(rootView: view)
        
        let window = NSWindow(contentViewController: hostingController)
        window.title = NSLocalizedString("window.about.title", comment: "About window title")
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        window.level = .floating
        
        aboutWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func quitApp() {
        NSApp.terminate(nil)
    }
}
