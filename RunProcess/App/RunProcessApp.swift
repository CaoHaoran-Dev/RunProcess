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
    var window: NSWindow?
    var statusItem: NSStatusItem?
    var viewModel: CommandViewModel?
    
    private var shortcutSettingsWindow: NSWindow?
    private var aboutWindow: NSWindow?
    
    private lazy var statusMenu: NSMenu = {
        let menu = NSMenu()
        
        let toggleItem = NSMenuItem(
            title: NSLocalizedString("menu.toggle.window", comment: "Toggle window menu item"),
            action: #selector(toggleWindow),
            keyEquivalent: ""
        )
        toggleItem.target = self
        menu.addItem(toggleItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let settingsItem = NSMenuItem(
            title: NSLocalizedString("menu.settings.shortcut", comment: "Shortcut settings menu item"),
            action: #selector(openShortcutSettings),
            keyEquivalent: ""
        )
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
    
    // MARK: - Global Hotkey (KeyboardShortcuts)
    
    private func setupGlobalHotkey() {
        KeyboardShortcuts.onKeyUp(for: .toggleWindow) { [weak self] in
            Task { @MainActor in
                self?.toggleWindow()
            }
        }
        
        print("✅ Global hotkey registered")
    }
    
    // MARK: - Menu Actions
    
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
    
    // MARK: - Shortcut Settings
    
    @objc func openShortcutSettings() {
        if let existing = shortcutSettingsWindow, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let settingsView = ShortcutSettingsView()
        let hostingController = NSHostingController(rootView: settingsView)
        
        let settingsWindow = NSWindow(contentViewController: hostingController)
        settingsWindow.title = NSLocalizedString("window.shortcut.settings.title", comment: "Shortcut settings window title")
        settingsWindow.styleMask = [.titled, .closable]
        settingsWindow.isReleasedWhenClosed = false
        settingsWindow.center()
        settingsWindow.level = .floating
        
        shortcutSettingsWindow = settingsWindow
        
        settingsWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    // MARK: - About
    
    @objc func openAbout() {
        if let existing = aboutWindow, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let aboutView = AboutView()
        let hostingController = NSHostingController(rootView: aboutView)
        
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
    
    // MARK: - Clear History
    
    @objc func clearHistory() {
        viewModel?.clearHistory()
        
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("alert.history.cleared.title", comment: "History cleared alert title")
        alert.informativeText = NSLocalizedString("alert.history.cleared.message", comment: "History cleared alert message")
        alert.alertStyle = .informational
        alert.addButton(withTitle: NSLocalizedString("button.ok", comment: "OK button"))
        alert.runModal()
    }
    
    // MARK: - Quit
    
    @objc func quitApp() {
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

// MARK: - Shortcut Settings View

struct ShortcutSettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(NSLocalizedString("shortcut.settings.title", comment: "Shortcut settings title"))
                .font(.headline)
            
            KeyboardShortcuts.Recorder(
                NSLocalizedString("shortcut.toggle.window.label", comment: "Toggle window shortcut label"),
                name: .toggleWindow
            )
            
            Divider()
            
            Text(NSLocalizedString("shortcut.settings.hint", comment: "Shortcut settings hint"))
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding(20)
        .frame(width: 360, height: 160)
    }
}

// MARK: - About View

struct AboutView: View {
    private var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // 图标
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 80, height: 80)
            
            // 名称 + 版本
            VStack(spacing: 4) {
                Text("RunProcess")
                    .font(.title2.weight(.semibold))
                Text(NSLocalizedString("about.version", comment: "Version label") + " " + version)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            // 简介
            Text(NSLocalizedString("about.description", comment: "About description"))
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            
            Divider()
            
            // 链接
            VStack(spacing: 8) {
                Link(destination: URL(string: "https://github.com/CaoHaoran-Dev/RunProcess")!) {
                    HStack(spacing: 6) {
                        Image(systemName: "link")
                            .font(.system(size: 11))
                        Text(NSLocalizedString("about.repository", comment: "Repository link"))
                            .font(.system(size: 12))
                    }
                }
                
                Link(destination: URL(string: "https://github.com/CaoHaoran-Dev/RunProcess/blob/main/LICENSE.md")!) {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 11))
                        Text(NSLocalizedString("about.license", comment: "License link"))
                            .font(.system(size: 12))
                    }
                }
            }
            .buttonStyle(.link)
            
            // 版权
            Text(NSLocalizedString("about.copyright", comment: "Copyright"))
                .font(.system(size: 10))
                .foregroundColor(.secondary.opacity(0.6))
                .padding(.top, 4)
        }
        .padding(28)
        .frame(width: 320)
    }
}
