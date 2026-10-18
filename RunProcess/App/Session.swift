//
//  Session.swift
//  RunProcess
//
//  Created by Haoran on 2026/9/13.
//

internal import AppKit
import SwiftUI
import QuartzCore

class BorderlessWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class Session {
    let id = UUID()
    let window: NSWindow
    let viewModel: CommandViewModel
    let sudoAuth: SudoAuthManager

    private(set) var persistentShell: PersistentShell?
    let usesSessionMode: Bool
    private(set) var currentWorkingDirectory: String
    private let baseTitle: String

    private var willCloseObserver: NSObjectProtocol?
    private var didBecomeKeyObserver: NSObjectProtocol?
    private var hasShown = false

    var onClose: (() -> Void)?
    var onBecomeKey: (() -> Void)?

    init(usesSessionMode: Bool) {
        self.usesSessionMode = usesSessionMode
        self.sudoAuth = SudoAuthManager()

        let initialCWD = AppSettings.resolvedWorkingDirectory
        self.currentWorkingDirectory = initialCWD
        self.baseTitle = usesSessionMode
            ? NSLocalizedString("window.title.session", comment: "Session window title")
            : "RunProcess"

        let viewModel = CommandViewModel()
        viewModel.usesSessionMode = usesSessionMode
        self.viewModel = viewModel

        let contentView = ContentView(viewModel: viewModel)
        let hostingController = NSHostingController(rootView: contentView)

        let window = BorderlessWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 140),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = hostingController
        window.title = baseTitle
        
        window.isReleasedWhenClosed = false
        
        #if BETA
        if AppSettings.mainUIMode == .lite {
            window.styleMask = [.borderless, .fullSizeContentView, .resizable]
            window.titleVisibility = .hidden
            window.isMovableByWindowBackground = true
            
            window.contentView?.wantsLayer = true
            window.contentView?.layer?.cornerRadius = 12
            window.contentView?.layer?.masksToBounds = true
            
            window.setContentSize(NSSize(width: 600, height: 56))
            window.minSize = NSSize(width: 400, height: 56)
            
            if let screen = NSScreen.main {
                let screenRect = screen.visibleFrame
                let x = screenRect.midX - 300
                let y = screenRect.maxY - (screenRect.height / 4)
                window.setFrameOrigin(NSPoint(x: x, y: y))
            }
        } else {
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
            window.titlebarAppearsTransparent = true
            window.setContentSize(NSSize(width: 600, height: 140))
            window.minSize = NSSize(width: 520, height: 140)
            
            if let screen = NSScreen.main {
                let screenRect = screen.visibleFrame
                let x = screenRect.midX - 300
                let y = screenRect.maxY - (screenRect.height / 4)
                window.setFrameOrigin(NSPoint(x: x, y: y))
            }
        }
        #else
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.setContentSize(NSSize(width: 600, height: 140))
        window.minSize = NSSize(width: 520, height: 140)
        window.center()
        #endif

        window.isMovableByWindowBackground = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .normal
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        self.window = window
        viewModel.session = self

        if usesSessionMode {
            // 👇 窗口创建后立刻开始异步加载 zsh，不阻塞界面
            let shell = PersistentShell(initialCWD: initialCWD)
            shell.onCWDChange = { [weak self] cwd in
                self?.currentWorkingDirectory = cwd
                self?.updateWindowTitle()
            }
            shell.onCrash = { [weak self] in self?.handleShellCrash() }
            self.persistentShell = shell
            
            // 👇 这里去掉了 try，直接调用
            shell.start()
        }

        viewModel.executeHandler = { [weak self] command, useSudo, password, completion in
            self?.execute(command: command, useSudo: useSudo, password: password, completion: completion)
        }
        viewModel.cancelHandler = { [weak self] in self?.cancelExecution() }
    }

    func observeWindow(manager: SessionManager) {
        willCloseObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification, object: window, queue: .main
        ) { [weak self] _ in
            guard let self = self, self.hasShown else { return }
            self.onClose?()
        }

        didBecomeKeyObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification, object: window, queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            self.onBecomeKey?()
            (NSApp.delegate as? AppDelegate)?.reparentAuxiliaryWindows(to: self.window)
        }
    }

    deinit {
        if let token = willCloseObserver { NotificationCenter.default.removeObserver(token) }
        if let token = didBecomeKeyObserver { NotificationCenter.default.removeObserver(token) }
        persistentShell?.teardown()
        sudoAuth.revoke()
    }

    func setContentWidth(_ width: CGFloat, animated: Bool = true) {
        guard let contentView = window.contentView else { return }
        let currentWidth = contentView.frame.width
        guard abs(currentWidth - width) > 1 else { return }

        var frame = window.frame
        let delta = width - currentWidth
        frame.size.width += delta
        frame.origin.x -= delta / 2

        if animated {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.18
                ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                window.animator().setFrame(frame, display: true)
            }
        } else {
            window.setFrame(frame, display: true)
        }
    }

    private func execute(command: String, useSudo: Bool, password: String?,
                         completion: @escaping (Result<String, Error>) -> Void) {
        if useSudo {
            guard let password = password else {
                completion(.failure(NSError(
                    domain: "RunProcess", code: -1,
                    userInfo: [NSLocalizedDescriptionKey:
                        NSLocalizedString("error.sudo.missing.password", comment: "")])))
                return
            }
            sudoAuth.executeSudo(command, password: password, timeout: 10.0, completion: completion)
        } else if usesSessionMode, let shell = persistentShell {
            shell.execute(command, timeout: 10.0) { result in
                switch result {
                case .success(let r): completion(.success(r.output))
                case .failure(let e): completion(.failure(e))
                }
            }
        } else {
            CommandExecutor.shared.execute(command, timeout: 10.0, completion: completion)
        }
    }

    private func cancelExecution() {
        CommandExecutor.shared.cancelCurrentTask()
    }

    private func handleShellCrash() {
        guard usesSessionMode else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.viewModel.showSessionResetNotice()

            let cwd = AppSettings.resolvedWorkingDirectory
            let shell = PersistentShell(initialCWD: cwd)
            shell.onCWDChange = { [weak self] cwd in
                self?.currentWorkingDirectory = cwd
                self?.updateWindowTitle()
            }
            shell.onCrash = { [weak self] in self?.handleShellCrash() }
            self.persistentShell = shell
            
            // 👇 这里去掉了 try，直接调用
            shell.start()
        }
    }

    private func updateWindowTitle() {
        guard usesSessionMode else { window.title = baseTitle; return }
        let displayCWD = (currentWorkingDirectory as NSString).abbreviatingWithTildeInPath
        window.title = "\(baseTitle) — \(displayCWD)"
    }

    func show() {
        hasShown = true
        window.makeKeyAndOrderFront(nil)
    }

    func hide() {
        window.orderOut(nil)
    }

    func isVisible() -> Bool {
        window.isVisible
    }
}
