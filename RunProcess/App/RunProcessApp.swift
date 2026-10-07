//
//  RunProcessApp.swift
//  RunProcess
//
//  Created by Haoran on 2026/8/19.
//

import SwiftUI
import KeyboardShortcuts
import Sparkle

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

    /// Sparkle 更新控制器
    private var updaterController: SPUStandardUpdaterController?

    /// 供设置页访问
    var updaterControllerForSettings: SPUStandardUpdaterController? {
        updaterController
    }

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

        // 检查更新，菜单里显示 ⌘U 提示
        let checkUpdateItem = NSMenuItem(
            title: NSLocalizedString("menu.check.updates", comment: "Check for updates menu item"),
            action: #selector(checkForUpdates),
            keyEquivalent: "u"
        )
        checkUpdateItem.keyEquivalentModifierMask = .command
        checkUpdateItem.target = self
        menu.addItem(checkUpdateItem)

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
        // ✅ 初始化 Sparkle
        // 菜单栏应用（.accessory）需要 userDriverDelegate 处理 gentle reminders
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: self,
            userDriverDelegate: self
        )

        NSApp.setActivationPolicy(.accessory)

        setupStatusBar()
        setupGlobalHotkey()
        setupKeyMonitor()
        setupAppActiveObserver()

        if AppSettings.hideWindowOnLaunch {
            _ = sessionManager.newSessionWithoutShowing()
        } else {
            _ = sessionManager.newSession()

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

            // ✅ ⌘U 检查更新（不依赖 NSMenuItem.keyEquivalent，
            //    因为 statusItem.menu 是临时赋值的，菜单关闭后 keyEquivalent 失效）
            if flags == .command,
               event.charactersIgnoringModifiers?.lowercased() == "u" {
                self.checkForUpdates()
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
        window.setContentSize(NSSize(width: 720, height: 480))
        window.minSize = NSSize(width: 680, height: 400)

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

    // MARK: - Updates

    /// 菜单栏「检查更新」。绑定 ⌘U。
    ///
    /// 菜单栏应用（.accessory）点击菜单项时，Sparkle 的独立窗口可能不会弹出。
    /// 参考 Sparkle 官方文档：需要临时切换到 .regular，让更新窗口能正常显示。
    /// https://sparkle-project.org/documentation/gentle-reminders/
    @objc func checkForUpdates() {
        // ✅ 临时切换到 regular，让 Sparkle 窗口能正常弹出
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        // 延迟一拍，等 activation 完成
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self, let controller = self.updaterController else {
                print("⚠️ updaterController 未初始化")
                return
            }
            controller.checkForUpdates(nil)
        }
    }

    // MARK: - Quit

    @objc func quitApp() {
        NSApp.terminate(nil)
    }
}

// MARK: - SPUUpdaterDelegate

extension AppDelegate: SPUUpdaterDelegate {
    /// 更新检查周期结束（无论成功、无更新、还是出错）后回调。
    /// 切回 .accessory，让 App 回到菜单栏模式。
    func updater(_ updater: SPUUpdater,
                 didFinishUpdateCycleFor updateCheck: SPUUpdateCheck,
                 error: Error?) {
        // 延迟 1 秒切回，给 Sparkle 窗口关闭留出时间
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // 只在当前是 regular 时才切回，避免误改
            if NSApp.activationPolicy() == .regular {
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }
}

// MARK: - SPUStandardUserDriverDelegate

extension AppDelegate: SPUStandardUserDriverDelegate {
    /// 声明支持 gentle scheduled update reminders。
    var supportsGentleScheduledUpdateReminders: Bool {
        return true
    }

    /// 决定 Sparkle 是否应该处理 scheduled update 的弹窗。
    ///
    /// 返回 `immediateFocus`：如果 Sparkle 认为这次检查是「即时焦点」
    /// （比如用户主动点击检查更新），就由 Sparkle 弹窗到前台。
    /// 否则（后台自动检查）由 App 决定如何处理。
    ///
    /// 参考：https://sparkle-project.org/documentation/gentle-reminders/
    func standardUserDriverShouldHandleShowingScheduledUpdate(
        _ update: SUAppcastItem,
        andInImmediateFocus immediateFocus: Bool
    ) -> Bool {
        return immediateFocus
    }
}
