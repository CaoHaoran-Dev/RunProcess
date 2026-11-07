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
        // 非 zsh 强制关闭会话模式
        let effectiveSessionMode = usesSessionMode && AppSettings.isZshShell

        self.usesSessionMode = effectiveSessionMode
        self.sudoAuth = SudoAuthManager()

        let initialCWD = AppSettings.resolvedWorkingDirectory
        self.currentWorkingDirectory = initialCWD
        self.baseTitle = effectiveSessionMode
            ? NSLocalizedString("window.title.session", comment: "Session window title")
            : "RunProcess"

        let viewModel = CommandViewModel()
        viewModel.usesSessionMode = effectiveSessionMode
        self.viewModel = viewModel

        let contentView = ContentView(viewModel: viewModel)
        let hostingController = NSHostingController(rootView: contentView)

        // 初始宽高：Lite 模式高度 56，经典模式 140
        let initialHeight: CGFloat = (AppSettings.mainUIMode == .lite) ? 56 : 140
        let window = BorderlessWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: initialHeight),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = hostingController
        window.title = baseTitle
        window.isReleasedWhenClosed = false

        if AppSettings.mainUIMode == .lite {
            window.styleMask = [.borderless, .fullSizeContentView, .resizable]
            window.isMovableByWindowBackground = true
            window.minSize = NSSize(width: 400, height: 56)
        } else {
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
            window.titlebarAppearsTransparent = true
            window.minSize = NSSize(width: 520, height: 140)
        }

        window.isMovableByWindowBackground = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .normal
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        self.window = window
        viewModel.session = self

        if effectiveSessionMode {
            let shell = PersistentShell(initialCWD: initialCWD)
            shell.onCWDChange = { [weak self] cwd in
                self?.currentWorkingDirectory = cwd
                self?.updateWindowTitle()
            }
            shell.onCrash = { [weak self] in self?.handleShellCrash() }
            self.persistentShell = shell
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self.viewModel.forceRestoreInputFocus()
            }
        }
    }

    deinit {
        if let token = willCloseObserver { NotificationCenter.default.removeObserver(token) }
        if let token = didBecomeKeyObserver { NotificationCenter.default.removeObserver(token) }
        persistentShell?.teardown()
        sudoAuth.revoke()
    }

    // MARK: - Frame Calculation (Multi-Display Support)

    /// 纯函数：计算窗口在指定屏幕可见区内的安全位置（固定宽度）
    static func calculateSafeFrame(screenRect: NSRect, windowWidth: CGFloat, windowHeight: CGFloat) -> NSRect {
        // 1. X 轴：始终水平居中
        var safeX = screenRect.midX - (windowWidth / 2)
        
        // 2. Y 轴：距离顶部固定比例（约占屏幕可见高度的 1/4）
        var safeY = screenRect.maxY - (screenRect.height / 4) - (windowHeight / 2)
        
        // 3. 边界兜底保护
        // 保证左右不超出屏幕边缘
        safeX = max(screenRect.minX + 20, min(safeX, screenRect.maxX - windowWidth - 20))
        
        // 保证顶部不贴死在菜单栏上（预留至少 40pt 的顶部空间）
        if safeY + windowHeight > screenRect.maxY - 40 {
            safeY = screenRect.maxY - 40 - windowHeight
        }
        
        // 保证底部不会掉出屏幕
        if safeY < screenRect.minY + 20 {
            safeY = screenRect.minY + 20
        }
        
        return NSRect(x: safeX, y: safeY, width: windowWidth, height: windowHeight)
    }

    /// 动态计算并应用窗口位置（严格的安全区保护，且锁定宽度）
    func updateFrameForActiveScreen(forceCenter: Bool = false) {
        let targetScreen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
        guard let screen = targetScreen else { return }
        
        let screenRect = screen.visibleFrame
        let currentFrame = window.frame
        
        // 如果不需要强制居中，且窗口已经完全在当前屏幕的安全区内，就保留用户手动拖拽的位置
        if !forceCenter && screenRect.contains(currentFrame) {
            return
        }
        
        // 宽度固定为 600，高度保持当前高度（或者初始高度）
        let finalWidth: CGFloat = 600
        let finalHeight = currentFrame.height > 0 ? currentFrame.height : ((AppSettings.mainUIMode == .lite) ? 56 : 140)
        
        // 调用纯函数计算安全 Frame
        let newFrame = Session.calculateSafeFrame(
            screenRect: screenRect,
            windowWidth: finalWidth,
            windowHeight: finalHeight
        )
        
        // 增加一点点动画会让跨屏显得更平滑
        if window.isVisible {
            window.setFrame(newFrame, display: true, animate: true)
        } else {
            window.setFrame(newFrame, display: false)
        }
    }

    // MARK: - Window Management

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

    func setContentHeight(_ height: CGFloat, animated: Bool = true) {
        guard let contentView = window.contentView else { return }
        let currentHeight = contentView.frame.height
        guard abs(currentHeight - height) > 1 else { return }

        var frame = window.frame
        let delta = height - currentHeight
        frame.size.height += delta
        frame.origin.y -= delta

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
                completion(.failure(NSError(domain: "RunProcess", code: -1, userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("error.sudo.missing.password", comment: "")])))
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
            executeWithSelectedShell(command, timeout: 10.0, completion: completion)
        }
    }

    private func executeWithSelectedShell(_ command: String, timeout: TimeInterval,
                                          completion: @escaping (Result<String, Error>) -> Void) {
        let shellPath = AppSettings.resolvedShellPath
        let cwd = AppSettings.resolvedWorkingDirectory

        let task = Process()
        let outPipe = Pipe()
        let errPipe = Pipe()

        task.executableURL = URL(fileURLWithPath: shellPath)
        task.currentDirectoryURL = URL(fileURLWithPath: cwd)

        var script = command
        if AppSettings.isZshShell && AppSettings.customPathEnabled {
            let extra = PathStore.shared.customPathString()
            if !extra.isEmpty {
                let quoted = extra.replacingOccurrences(of: "'", with: "'\\''")
                script = "export PATH=\"$PATH:'\(quoted)'\"; \(command)"
            }
        }

        task.arguments = ["-l", "-c", script]
        task.standardOutput = outPipe
        task.standardError = errPipe

        let bufferLock = NSLock()
        var outputData = Data()
        var errorData = Data()

        outPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            bufferLock.lock()
            outputData.append(data)
            bufferLock.unlock()
        }

        errPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            bufferLock.lock()
            errorData.append(data)
            bufferLock.unlock()
        }

        let timeoutWork = DispatchWorkItem {
            if task.isRunning { task.terminate() }
        }
        DispatchQueue.global(qos: .default).asyncAfter(deadline: .now() + timeout, execute: timeoutWork)

        task.terminationHandler = { proc in
            timeoutWork.cancel()
            outPipe.fileHandleForReading.readabilityHandler = nil
            errPipe.fileHandleForReading.readabilityHandler = nil

            let outTail = outPipe.fileHandleForReading.readDataToEndOfFile()
            let errTail = errPipe.fileHandleForReading.readDataToEndOfFile()

            bufferLock.lock()
            if !outTail.isEmpty { outputData.append(outTail) }
            if !errTail.isEmpty { errorData.append(errTail) }
            let outStr = String(data: outputData, encoding: .utf8) ?? ""
            let errStr = String(data: errorData, encoding: .utf8) ?? ""
            bufferLock.unlock()

            var combined = outStr
            if !errStr.isEmpty {
                combined += (combined.isEmpty ? "" : "\n") + errStr
            }
            combined = combined.trimmingCharacters(in: .newlines)

            let status = proc.terminationStatus
            DispatchQueue.main.async {
                if status == 0 {
                    completion(.success(combined))
                } else {
                    let message = combined.isEmpty
                        ? "exit code: \(status)"
                        : combined
                    completion(.failure(NSError(
                        domain: "RunProcess",
                        code: Int(status),
                        userInfo: [NSLocalizedDescriptionKey: message])))
                }
            }
        }

        do {
            try task.run()
        } catch {
            outPipe.fileHandleForReading.readabilityHandler = nil
            errPipe.fileHandleForReading.readabilityHandler = nil
            timeoutWork.cancel()
            completion(.failure(error))
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
        
        // 关键修复：先显示窗口，让底层 Window Server 感知到它要在这个屏幕呈现
        window.makeKeyAndOrderFront(nil)
        
        // 显示后再平滑调整位置（如果不在目标屏幕内）
        updateFrameForActiveScreen(forceCenter: false)
    }

    func hide() {
        window.orderOut(nil)
    }

    func isVisible() -> Bool {
        window.isVisible
    }
}
