//
//  Session.swift
//  RunProcess
//
//  Created by Haoran on 2026/9/13.
//

internal import AppKit
import SwiftUI
import QuartzCore

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

    /// ✅ 是否已经真正显示过。用于过滤 show() 之前的 willClose。
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

        let window = NSWindow(contentViewController: hostingController)
        window.title = baseTitle
        window.setContentSize(NSSize(width: 520, height: 140))
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.center()
        window.level = .normal
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        self.window = window
        viewModel.session = self

        if usesSessionMode {
            let shell = PersistentShell(initialCWD: initialCWD)
            shell.onCWDChange = { [weak self] cwd in
                self?.currentWorkingDirectory = cwd
                self?.updateWindowTitle()
            }
            shell.onCrash = { [weak self] in self?.handleShellCrash() }
            self.persistentShell = shell
            try? shell.start()
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

    // MARK: - 窗口尺寸

    /// 输出内容变宽 / 变窄时调用，平滑改变窗口宽度。
    /// - Parameter width: 目标内容区宽度（不含窗口边框）
    func setContentWidth(_ width: CGFloat, animated: Bool = true) {
        guard let contentView = window.contentView else { return }
        let currentWidth = contentView.frame.width
        guard abs(currentWidth - width) > 1 else { return }

        var frame = window.frame
        let delta = width - currentWidth
        frame.size.width += delta
        // 居中扩展：左右各推 delta/2，视觉上是「从中心长出来」
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

    // MARK: - Execution

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
            try? shell.start()
        }
    }

    private func updateWindowTitle() {
        guard usesSessionMode else { window.title = baseTitle; return }
        let displayCWD = (currentWorkingDirectory as NSString).abbreviatingWithTildeInPath
        window.title = "\(baseTitle) — \(displayCWD)"
    }

    // MARK: - Lifecycle

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
