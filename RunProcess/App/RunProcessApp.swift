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
            SettingsView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {

    private let sessionManager = SessionManager()

    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    private var aboutWindow: NSWindow?
    private var helpWindow: NSWindow?
    private var keyMonitor: Any?

    /// 启动后是否真正被激活过。用于忽略启动瞬间的 didResignActive。
    private var hasBeenActive = false

    // MARK: - Menu

    private lazy var statusMenu: NSMenu = {
        let menu = NSMenu()

        let newWindowItem = NSMenuItem(
            title: NSLocalizedString("menu.new.window", comment: "New window menu item"),
            action: #selector(newWindow),
            keyEquivalent: "n"
        )
        newWindowItem.keyEquivalentModifierMask = .command
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

        let historyItem = NSMenuItem(
            title: NSLocalizedString("menu.history", comment: "Command history menu item"),
            action: #selector(openHistory),
            keyEquivalent: "r"
        )
        historyItem.keyEquivalentModifierMask = .command
        historyItem.target = self
        menu.addItem(historyItem)

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

        let helpItem = NSMenuItem(
            title: NSLocalizedString("menu.help", comment: "Help menu item"),
            action: #selector(openHelp),
            keyEquivalent: "/"
        )
        helpItem.keyEquivalentModifierMask = .command
        helpItem.target = self
        menu.addItem(helpItem)

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
        setupKeyMonitor()
        setupAppActiveObserver()

        if AppSettings.hideWindowOnLaunch {
            // ✅ 静默启动：只创建会话，不显示窗口
            _ = sessionManager.newSessionWithoutShowing()
        } else {
            _ = sessionManager.newSession()

            // ✅ 主动激活 App，让首个窗口拿到键盘焦点
            NSApp.activate(ignoringOtherApps: true)
            hasBeenActive = true

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NotificationCenter.default.post(
                    name: NSNotification.Name("FocusTextField"),
                    object: nil
                )
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        NotificationCenter.default.removeObserver(
            self,
            name: NSApplication.didResignActiveNotification,
            object: nil
        )
        NotificationCenter.default.removeObserver(
            self,
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )

        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }

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

    // MARK: - Key Monitor

    private func setupKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }

            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

            if flags == .command,
               event.charactersIgnoringModifiers?.lowercased() == "n" {
                self.newWindow()
                return nil
            }

            if flags == .command,
               event.charactersIgnoringModifiers == "," {
                self.openSettings()
                return nil
            }

            if flags == .command,
               event.charactersIgnoringModifiers?.lowercased() == "r" {
                self.openHistory()
                return nil
            }

            if flags == .command,
               event.charactersIgnoringModifiers == "/" {
                self.openHelp()
                return nil
            }

            return event
        }
    }

    // MARK: - App Active Observer

    private func setupAppActiveObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidResignActive),
            name: NSApplication.didResignActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    @objc func applicationDidBecomeActive() {
        hasBeenActive = true
    }

    @objc func applicationDidResignActive() {
        // 启动瞬间忽略一次失焦，避免新窗口被立刻隐藏
        guard hasBeenActive else { return }
        guard AppSettings.hideOnDeactivate else { return }
        hideAllWindows()
    }

    // MARK: - Actions

    @objc func toggleMenu() {
        statusItem?.menu = statusMenu
        statusItem?.button?.performClick(nil)
    }

    @objc func newWindow() {
        _ = sessionManager.newSession()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NotificationCenter.default.post(
                name: NSNotification.Name("FocusTextField"),
                object: nil
            )
        }
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

    /// 隐藏所有窗口（App 失活时调用）
    func hideAllWindows() {
        for session in sessionManager.allSessions {
            session.hide()
        }

        settingsWindow?.orderOut(nil)
        aboutWindow?.orderOut(nil)
        helpWindow?.orderOut(nil)
    }

    // MARK: - History

    @objc func openHistory() {
        let session = sessionManager.activeSession() ?? sessionManager.newSession()

        if !session.isVisible() {
            session.show()
            NSApp.activate(ignoringOtherApps: true)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            session.viewModel.showHistoryPanel = true
        }
    }

    // MARK: - Help

    @objc func openHelp() {
        NSApp.activate(ignoringOtherApps: true)

        if let existing = helpWindow {
            existing.makeKeyAndOrderFront(nil)

            if let parentWindow = sessionManager.activeSession()?.window,
               existing.parent !== parentWindow {
                existing.parent?.removeChildWindow(existing)
                parentWindow.addChildWindow(existing, ordered: .above)
            }
            return
        }

        let hosting = NSHostingController(rootView: HelpView())
        let window = NSWindow(contentViewController: hosting)
        window.title = NSLocalizedString("window.help.title", comment: "Help window title")
        window.styleMask = [.titled, .closable, .resizable, .miniaturizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.isReleasedWhenClosed = false
        window.center()
        window.level = .normal
        window.setContentSize(NSSize(width: 720, height: 480))
        window.minSize = NSSize(width: 680, height: 400)

        helpWindow = window

        if let parentWindow = sessionManager.activeSession()?.window {
            parentWindow.addChildWindow(window, ordered: .above)
        }

        window.makeKeyAndOrderFront(nil)
    }

    // MARK: - Settings

    @objc func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        openSettingsWindow()
    }

    private func openSettingsWindow() {
        if let existing = settingsWindow {
            existing.makeKeyAndOrderFront(nil)

            if let parentWindow = sessionManager.activeSession()?.window,
               existing.parent !== parentWindow {
                existing.parent?.removeChildWindow(existing)
                parentWindow.addChildWindow(existing, ordered: .above)
            }
            return
        }

        let view = SettingsView()
        let hostingController = NSHostingController(rootView: view)

        let window = NSWindow(contentViewController: hostingController)
        window.title = NSLocalizedString("window.settings.title", comment: "Settings window title")
        window.styleMask = [.titled, .closable, .resizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.isReleasedWhenClosed = false
        window.center()
        window.level = .normal
        window.setContentSize(NSSize(width: 560, height: 340))
        window.minSize = NSSize(width: 520, height: 300)

        settingsWindow = window

        if let parentWindow = sessionManager.activeSession()?.window {
            parentWindow.addChildWindow(window, ordered: .above)
        }

        window.makeKeyAndOrderFront(nil)
    }

    func reparentAuxiliaryWindows(to parent: NSWindow) {
        if let settings = settingsWindow, settings.parent !== parent {
            settings.parent?.removeChildWindow(settings)
            parent.addChildWindow(settings, ordered: .above)
        }

        if let about = aboutWindow, about.parent !== parent {
            about.parent?.removeChildWindow(about)
            parent.addChildWindow(about, ordered: .above)
        }

        if let help = helpWindow, help.parent !== parent {
            help.parent?.removeChildWindow(help)
            parent.addChildWindow(help, ordered: .above)
        }
    }

    // MARK: - Clear History

    @objc func clearHistory() {
        CommandHistory.shared.clearAll()

        let alert = NSAlert()
        alert.messageText = NSLocalizedString("alert.history.cleared.title", comment: "History cleared alert title")
        alert.informativeText = NSLocalizedString("alert.history.cleared.message", comment: "History cleared alert message")
        alert.alertStyle = .informational
        alert.addButton(withTitle: NSLocalizedString("button.ok", comment: "OK button"))
        alert.runModal()
    }

    // MARK: - About

    @objc func openAbout() {
        if let existing = aboutWindow {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)

            if let parentWindow = sessionManager.activeSession()?.window,
               existing.parent !== parentWindow {
                existing.parent?.removeChildWindow(existing)
                parentWindow.addChildWindow(existing, ordered: .above)
            }
            return
        }

        let view = AboutView()
        let hostingController = NSHostingController(rootView: view)

        let window = NSWindow(contentViewController: hostingController)
        window.title = NSLocalizedString("window.about.title", comment: "About window title")
        window.styleMask = [.titled, .closable]
        window.isOpaque = false
        window.backgroundColor = .clear
        window.isReleasedWhenClosed = false
        window.center()
        window.level = .normal

        aboutWindow = window

        if let parentWindow = sessionManager.activeSession()?.window {
            parentWindow.addChildWindow(window, ordered: .above)
        }

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Quit

    @objc func quitApp() {
        NSApp.terminate(nil)
    }
}
