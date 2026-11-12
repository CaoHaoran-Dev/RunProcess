//
//  RunProcessApp.swift
//  RunProcess
//
//  Created by Haoran on 2026/8/19.
//

import SwiftUI
import KeyboardShortcuts
import Sparkle
import Network
import RemoteLinkKit
import UserNotifications

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

    private var updaterController: SPUStandardUpdaterController?

    var updaterControllerForSettings: SPUStandardUpdaterController? {
        updaterController
    }

    private var hasBeenActive = false

    // MARK: - Bonjour Discovery
    #if BETA
    private var bonjourBrowser: BonjourBrowser?
    private var discoveredHosts: [String: NWEndpoint] = [:]
    private var remoteSubmenu: NSMenu?
    private var isRemoteMenuOpen = false

    /// 是否已超时（10 秒内未发现任何设备）
    private var discoveryTimedOut = false
    /// 超时计时器
    private var discoveryTimeoutWork: DispatchWorkItem?
    private static let discoveryTimeout: TimeInterval = 10
    #endif

    // MARK: - Menu
    // 动态生成菜单，每次点击都会重新构建，确保能实时看到 Bonjour 发现的设备
    private var statusMenu: NSMenu {
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

        #if BETA
        let remoteMenu = NSMenu(title: NSLocalizedString("menu.remote.title", comment: ""))
        remoteMenu.autoenablesItems = false
        remoteMenu.delegate = self
        self.remoteSubmenu = remoteMenu

        let remoteSubItem = NSMenuItem(
            title: NSLocalizedString("menu.remote.title", comment: ""),
            action: nil,
            keyEquivalent: ""
        )
        if let img = NSImage(systemSymbolName: "network", accessibilityDescription: nil) {
            remoteSubItem.image = img
        }
        remoteSubItem.submenu = remoteMenu

        if let settingsIndex = menu.items.firstIndex(where: { $0.action == #selector(openSettings) }) {
            menu.insertItem(remoteSubItem, at: settingsIndex)
            menu.insertItem(NSMenuItem.separator(), at: settingsIndex + 1)
        } else {
            menu.addItem(remoteSubItem)
            menu.addItem(NSMenuItem.separator())
        }
        #endif

        let historyItem = NSMenuItem(
            title: NSLocalizedString("menu.history", comment: "Command history menu item"),
            action: #selector(openHistory),
            keyEquivalent: "h"
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
    }

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        updateFeedURLPreference()

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

        #if BETA
        // 先注册类别、设 delegate，再请求权限。
        // 避免启动早期收到的通知走默认展示行为。
        RemotePairingNotifier.registerCategoryIfNeeded()
        UNUserNotificationCenter.current().delegate = self
        RemotePairingNotifier.requestAuthorizationIfNeeded()

        startDiscovery()

        if AppSettings.allowRemoteControl {
            RemoteServerManager.shared.start()
        }
        #endif

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

        #if BETA
        discoveryTimeoutWork?.cancel()
        discoveryTimeoutWork = nil
        bonjourBrowser?.stop()
        RemoteServerManager.shared.stop()
        #endif

        sessionManager.removeAll()
        print("🛑 RunProcess is exiting")
    }

    // MARK: - Bonjour Browser

    #if BETA
    private func startDiscovery() {
        discoveryTimeoutWork?.cancel()
        discoveryTimeoutWork = nil

        discoveryTimedOut = false

        bonjourBrowser?.stop()
        bonjourBrowser = BonjourBrowser()
        bonjourBrowser?.onFound = { [weak self] service in
            DispatchQueue.main.async {
                guard let self = self else { return }
                // 已超时：后台仍可发现，但不刷新 UI，等待用户点重新搜索
                guard !self.discoveryTimedOut else { return }

                let wasEmpty = self.discoveredHosts.isEmpty
                self.discoveredHosts[service.name] = service.endpoint

                // 首次发现设备，取消超时
                if !self.discoveredHosts.isEmpty {
                    self.discoveryTimeoutWork?.cancel()
                    self.discoveryTimeoutWork = nil
                }

                if wasEmpty,
                   self.isRemoteMenuOpen,
                   let sub = self.remoteSubmenu {
                    self.rebuildRemoteSubmenu(sub)
                }
            }
        }
        bonjourBrowser?.onLost = { [weak self] service in
            DispatchQueue.main.async {
                guard let self = self else { return }
                guard !self.discoveryTimedOut else { return }
                self.discoveredHosts.removeValue(forKey: service.name)
                if self.discoveredHosts.isEmpty,
                   self.isRemoteMenuOpen,
                   let sub = self.remoteSubmenu {
                    self.rebuildRemoteSubmenu(sub)
                }
            }
        }
        bonjourBrowser?.start()

        let work = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            guard self.discoveredHosts.isEmpty else { return }
            self.discoveryTimedOut = true
            if self.isRemoteMenuOpen, let sub = self.remoteSubmenu {
                self.rebuildRemoteSubmenu(sub)
            }
        }
        discoveryTimeoutWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.discoveryTimeout, execute: work)
    }

    @objc private func retryDiscovery() {
        discoveredHosts.removeAll()
        startDiscovery()
        if isRemoteMenuOpen, let sub = remoteSubmenu {
            rebuildRemoteSubmenu(sub)
        }
    }
    #endif

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
               event.charactersIgnoringModifiers?.lowercased() == "w" {
                if let active = self.sessionManager.activeSession() {
                    active.hide()
                } else {
                    self.hideAllWindows()
                }
                return nil
            }

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
               event.charactersIgnoringModifiers?.lowercased() == "h" {
                self.openHistory()
                return nil
            }

            if flags == .command,
               event.charactersIgnoringModifiers == "/" {
                self.openHelp()
                return nil
            }

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
        // 每次点击时，把最新的动态菜单赋给 statusItem
        statusItem?.menu = statusMenu
        statusItem?.button?.performClick(nil)
    }

    #if BETA
    @objc func selectRemoteHost(_ sender: NSMenuItem) {
        let hostId = sender.representedObject as? String
        if let session = sessionManager.activeSession() {
            session.viewModel.activeRemoteHostId = hostId
            session.updateWindowTitle()
        }
    }

    @objc func connectToDiscoveredHost(_ sender: NSMenuItem) {
        guard let endpoint = sender.representedObject as? NWEndpoint else { return }

        Task {
            do {
                let (host, _) = try await BonjourBrowser.resolve(endpoint)
                let normalized = HostAddress.stripPort(host)

                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.messageText = NSLocalizedString("settings.remote.discovered.title", comment: "")
                    alert.informativeText = String(format: NSLocalizedString("settings.remote.discovered.message", comment: ""), normalized)
                    alert.addButton(withTitle: NSLocalizedString("settings.remote.discovered.action", comment: ""))
                    alert.addButton(withTitle: NSLocalizedString("button.cancel", comment: ""))

                    if alert.runModal() == .alertFirstButtonReturn {
                        self.openSettings()
                        NotificationCenter.default.post(name: NSNotification.Name("PreFillRemoteHost"), object: normalized)
                    }
                }
            } catch {
                print("Failed to resolve Bonjour endpoint: \(error)")
            }
        }
    }

    /// 没有系统通知权限时的兜底：直接把验证码弹出来。
    /// 不依赖设置页是否打开，也不依赖 SwiftUI 视图是否已挂载。
    func presentPairingCodeInApp(_ code: String) {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = NSLocalizedString("notification.pairing.title", comment: "")
        alert.informativeText = String(
            format: NSLocalizedString("settings.remote.pairingCodeIs", comment: ""),
            code
        )
        alert.alertStyle = .informational
        alert.addButton(withTitle: NSLocalizedString("button.ok", comment: ""))

        if let window = sessionManager.activeSession()?.window, window.isVisible {
            alert.beginSheetModal(for: window)
        } else {
            alert.runModal()
        }
    }
    #endif

    @objc func newWindow() {
        _ = sessionManager.newSession()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NotificationCenter.default.post(
                name: NSNotification.Name("FocusTextField"),
                object: nil
            )
        }
    }

    @discardableResult
    func createSessionWithCommand(_ command: String, runAsRoot: Bool = false) -> Session {
        let session = sessionManager.newSession()
        session.viewModel.inputText = command
        if runAsRoot {
            session.viewModel.pendingSudoRequest = true
        }

        NSApp.activate(ignoringOtherApps: true)
        session.show()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NotificationCenter.default.post(
                name: NSNotification.Name("FocusTextField"),
                object: nil
            )
        }
        return session
    }

    @objc func toggleWindow() {
        guard let session = sessionManager.activeSession() else {
            _ = sessionManager.newSession()
            return
        }

        if session.isVisible() {
            session.hide()
        } else {
            session.show(isWake: true)
            NSApp.activate(ignoringOtherApps: true)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NotificationCenter.default.post(
                    name: NSNotification.Name("FocusTextField"),
                    object: nil
                )
            }
        }
    }

    func hideAllWindows() {
        for session in sessionManager.allSessions {
            session.hide()
        }

        settingsWindow?.orderOut(nil)
        aboutWindow?.orderOut(nil)
        helpWindow?.orderOut(nil)
    }

    @objc func openHistory() {
        let session = sessionManager.activeSession() ?? sessionManager.newSession()

        if !session.isVisible() {
            session.show(isWake: true)
            NSApp.activate(ignoringOtherApps: true)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            session.viewModel.showHistoryPanel = true
        }
    }

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
        setupWindowCloseObserver(for: window)
    }

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
        setupWindowCloseObserver(for: window)
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

    private func setupWindowCloseObserver(for window: NSWindow) {
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            guard let activeSession = self.sessionManager.activeSession() else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                activeSession.window.makeKey()
                activeSession.viewModel.forceRestoreInputFocus()
            }
        }
    }

    @objc func clearHistory() {
        CommandHistory.shared.clearAll()

        let alert = NSAlert()
        alert.messageText = NSLocalizedString("alert.history.cleared.title", comment: "History cleared alert title")
        alert.informativeText = NSLocalizedString("alert.history.cleared.message", comment: "History cleared alert message")
        alert.alertStyle = .informational
        alert.addButton(withTitle: NSLocalizedString("button.ok", comment: "OK button"))
        alert.runModal()
    }

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
        setupWindowCloseObserver(for: window)
    }

    @objc func checkForUpdates() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self, let controller = self.updaterController else {
                print("⚠️ updaterController 未初始化")
                return
            }
            controller.checkForUpdates(nil)
        }
    }

    func updateFeedURLPreference() {
        let defaultFeed: String
        let mirrorFeed: String

        #if BETA
        defaultFeed = "https://github.com/CaoHaoran-Dev/RunProcess/releases/download/beta-appcast/appcast-beta.xml"
        mirrorFeed = "https://downloads.caohaoran.dpdns.org/downloads/runprocess/appcast-beta.xml"
        #else
        defaultFeed = "https://github.com/CaoHaoran-Dev/RunProcess/releases/latest/download/appcast.xml"
        mirrorFeed = "https://downloads.caohaoran.dpdns.org/downloads/runprocess/appcast.xml"
        #endif

        switch AppSettings.updateChannel {
        case .github:
            UserDefaults.standard.set(defaultFeed, forKey: "SUFeedURL")
        case .cloudflare:
            UserDefaults.standard.set(mirrorFeed, forKey: "SUFeedURL")
        case .custom:
            UserDefaults.standard.set(AppSettings.customUpdateURL, forKey: "SUFeedURL")
        }
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }
}

// MARK: - SPUUpdaterDelegate

extension AppDelegate: SPUUpdaterDelegate {
    func feedURLString(for updater: SPUUpdater) -> String? {
        return UserDefaults.standard.string(forKey: "SUFeedURL")
    }

    func updater(_ updater: SPUUpdater,
                 didFinishUpdateCycleFor updateCheck: SPUUpdateCheck,
                 error: Error?) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if NSApp.activationPolicy() == .regular {
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }
}

// MARK: - SPUStandardUserDriverDelegate

extension AppDelegate: SPUStandardUserDriverDelegate {
    var supportsGentleScheduledUpdateReminders: Bool {
        return true
    }

    func standardUserDriverShouldHandleShowingScheduledUpdate(
        _ update: SUAppcastItem,
        andInImmediateFocus immediateFocus: Bool
    ) -> Bool {
        return immediateFocus
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if let code = userInfo["pairingCode"] as? String {
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
                self.presentPairingCodeInApp(code)
            }
        }
        completionHandler()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}

// MARK: - Remote Submenu (BETA)

#if BETA
extension AppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        guard menu === remoteSubmenu else { return }
        isRemoteMenuOpen = true
        rebuildRemoteSubmenu(menu)
    }

    func menuDidClose(_ menu: NSMenu) {
        guard menu === remoteSubmenu else { return }
        isRemoteMenuOpen = false
    }

    private func rebuildRemoteSubmenu(_ menu: NSMenu) {
        menu.removeAllItems()

        // 1. 本地
        let localItem = NSMenuItem(
            title: NSLocalizedString("menu.remote.local", comment: ""),
            action: #selector(selectRemoteHost(_:)),
            keyEquivalent: ""
        )
        localItem.target = self
        localItem.representedObject = nil
        if let img = NSImage(systemSymbolName: "desktopcomputer", accessibilityDescription: nil) {
            localItem.image = img
        }
        menu.addItem(localItem)

        // 2. 已配对主机
        let hosts = RemoteHostStore.shared.hosts
        if !hosts.isEmpty {
            menu.addItem(NSMenuItem.separator())
            for host in hosts {
                let item = NSMenuItem(
                    title: host.name,
                    action: #selector(selectRemoteHost(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = host.id
                if let img = NSImage(systemSymbolName: "server.rack", accessibilityDescription: nil) {
                    item.image = img
                }
                menu.addItem(item)
            }
        }

        // 3. Bonjour 发现
        menu.addItem(NSMenuItem.separator())

        if !discoveredHosts.isEmpty {
            let headerItem = NSMenuItem(
                title: NSLocalizedString("menu.remote.discovered", comment: "Discovered Devices"),
                action: nil,
                keyEquivalent: ""
            )
            headerItem.isEnabled = false
            menu.addItem(headerItem)

            for name in discoveredHosts.keys.sorted() {
                guard let endpoint = discoveredHosts[name] else { continue }
                let item = NSMenuItem(
                    title: name,
                    action: #selector(connectToDiscoveredHost(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = endpoint
                if let img = NSImage(systemSymbolName: "wifi", accessibilityDescription: nil) {
                    item.image = img
                }
                menu.addItem(item)
            }
        } else if discoveryTimedOut {
            menu.addItem(makeRetryMenuItem())
        } else {
            menu.addItem(makeSearchingMenuItem())
        }
    }

    /// view-backed 菜单项：点击后不关闭菜单，直接触发重试。
    private func makeRetryMenuItem() -> NSMenuItem {
        let item = NSMenuItem()
        item.isEnabled = true

        let rowHeight: CGFloat = 26
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 240, height: rowHeight))

        let icon = NSImageView(frame: NSRect(x: 10, y: (rowHeight - 16) / 2, width: 16, height: 16))
        icon.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: nil)
        icon.contentTintColor = .secondaryLabelColor
        container.addSubview(icon)

        let label = NSTextField(labelWithString: NSLocalizedString("menu.remote.retry", comment: ""))
        label.font = NSFont.systemFont(ofSize: 13)
        label.textColor = .labelColor
        label.lineBreakMode = .byTruncatingTail
        label.frame = NSRect(
            x: 32,
            y: (rowHeight - 18) / 2,
            width: container.frame.width - 32 - 10,
            height: 18
        )
        container.addSubview(label)

        let button = NSButton(frame: container.bounds)
        button.isBordered = false
        button.title = ""
        button.target = self
        button.action = #selector(retryDiscovery)
        button.autoresizingMask = [.width, .height]
        container.addSubview(button)

        item.view = container
        return item
    }

    private func makeSearchingMenuItem() -> NSMenuItem {
        let item = NSMenuItem()
        item.isEnabled = false

        let spinner = NSProgressIndicator()
        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.isIndeterminate = true
        spinner.isDisplayedWhenStopped = true
        spinner.frame = NSRect(x: 0, y: 0, width: 14, height: 14)
        spinner.startAnimation(nil)

        let label = NSTextField(labelWithString: NSLocalizedString("menu.remote.searching", comment: ""))
        label.font = NSFont.systemFont(ofSize: 12)
        label.textColor = .secondaryLabelColor
        label.lineBreakMode = .byTruncatingTail
        label.sizeToFit()

        let spacing: CGFloat = 8
        let leftInset: CGFloat = 10
        let rightInset: CGFloat = 10
        let topInset: CGFloat = 4
        let bottomInset: CGFloat = 4

        let labelSize = label.frame.size
        let contentHeight = max(14, labelSize.height)
        let containerWidth = max(200, leftInset + 14 + spacing + labelSize.width + rightInset)
        let containerHeight = contentHeight + topInset + bottomInset

        let container = NSView(frame: NSRect(x: 0, y: 0, width: containerWidth, height: containerHeight))

        spinner.frame = NSRect(
            x: leftInset,
            y: topInset + (contentHeight - 14) / 2,
            width: 14,
            height: 14
        )
        label.frame = NSRect(
            x: leftInset + 14 + spacing,
            y: topInset + (contentHeight - labelSize.height) / 2,
            width: labelSize.width,
            height: labelSize.height
        )

        container.addSubview(spinner)
        container.addSubview(label)
        container.autoresizingMask = [.width]

        item.view = container
        return item
    }
}
#endif
