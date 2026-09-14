//
//  Session.swift
//  RunProcess
//
//  Created by Haoran on 2026/9/13.
//

internal import AppKit
import SwiftUI

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
    private var didResignKeyObserver: NSObjectProtocol?
    
    // MARK: - Init
    
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
        window.setContentSize(NSSize(width: 520, height: 160))
        window.styleMask = [
            .titled,
            .closable,
            .miniaturizable,
            .resizable,
            .fullSizeContentView
        ]
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.center()
        window.level = .normal
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        self.window = window
        
        if usesSessionMode {
            let shell = PersistentShell(initialCWD: initialCWD)
            shell.onCWDChange = { [weak self] cwd in
                self?.currentWorkingDirectory = cwd
                self?.updateWindowTitle()
            }
            shell.onCrash = { [weak self] in
                self?.handleShellCrash()
            }
            self.persistentShell = shell
            try? shell.start()
        }
        
        viewModel.executeHandler = { [weak self] command, useSudo, password, completion in
            self?.execute(command: command, useSudo: useSudo, password: password, completion: completion)
        }
        viewModel.cancelHandler = { [weak self] in
            self?.cancelExecution()
        }
        
        SessionRegistry.shared.register(viewModel: viewModel, session: self)
    }
    
    // MARK: - 窗口观察
    
    func observeWindow(manager: SessionManager) {
        willCloseObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self, weak manager] _ in
            guard let self = self else { return }
            manager?.removeSession(self)
        }
        
        didBecomeKeyObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: window,
            queue: .main
        ) { [weak self, weak manager] _ in
            guard let self = self else { return }
            manager?.markActive(self)
            (NSApp.delegate as? AppDelegate)?.reparentAuxiliaryWindows(to: self.window)
        }
        
        // ✅ 主窗口失去 key 时，检查 App 是否还 active
        didResignKeyObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            // 延迟到下一个 runloop，让 key window 切换完成
            DispatchQueue.main.async {
                self.handleResignKey()
            }
        }
    }
    
    private func handleResignKey() {
        guard AppSettings.hideOnDeactivate else { return }
        // App 不再 active，隐藏所有窗口
        guard !NSApp.isActive else { return }
        (NSApp.delegate as? AppDelegate)?.hideAllWindows()
    }
    
    deinit {
        if let token = willCloseObserver {
            NotificationCenter.default.removeObserver(token)
        }
        if let token = didBecomeKeyObserver {
            NotificationCenter.default.removeObserver(token)
        }
        if let token = didResignKeyObserver {
            NotificationCenter.default.removeObserver(token)
        }
        
        SessionRegistry.shared.unregister(viewModel: viewModel)
        persistentShell?.teardown()
        sudoAuth.revoke()
    }
    
    // MARK: - 执行
    
    private func execute(
        command: String,
        useSudo: Bool,
        password: String?,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        if useSudo {
            guard let password = password else {
                completion(.failure(NSError(
                    domain: "RunProcess",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("error.sudo.missing.password", comment: "Missing password")]
                )))
                return
            }
            executeWithSudo(command: command, password: password, completion: completion)
        } else {
            executeNormal(command: command, completion: completion)
        }
    }
    
    private func executeNormal(command: String, completion: @escaping (Result<String, Error>) -> Void) {
        if usesSessionMode, let shell = persistentShell {
            shell.execute(command, timeout: 10.0) { result in
                switch result {
                case .success(let shellResult):
                    completion(.success(shellResult.output))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        } else {
            CommandExecutor.shared.execute(command, timeout: 10.0, completion: completion)
        }
    }
    
    private func executeWithSudo(
        command: String,
        password: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        sudoAuth.executeSudo(command, password: password, timeout: 10.0, completion: completion)
    }
    
    private func cancelExecution() {
        CommandExecutor.shared.cancelCurrentTask()
    }
    
    // MARK: - Shell 崩溃
    
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
            shell.onCrash = { [weak self] in
                self?.handleShellCrash()
            }
            self.persistentShell = shell
            try? shell.start()
        }
    }
    
    // MARK: - 窗口标题
    
    private func updateWindowTitle() {
        guard usesSessionMode else {
            window.title = baseTitle
            return
        }
        let displayCWD = (currentWorkingDirectory as NSString).abbreviatingWithTildeInPath
        window.title = "\(baseTitle) — \(displayCWD)"
    }
    
    // MARK: - 生命周期
    
    func show() {
        window.makeKeyAndOrderFront(nil)
    }
    
    func hide() {
        window.orderOut(nil)
    }
    
    func isVisible() -> Bool {
        return window.isVisible
    }
}
