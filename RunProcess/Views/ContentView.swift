//
//  ContentView.swift
//  RunProcess
//
//  Created by Haoran on 2026/8/19.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: CommandViewModel
    @FocusState private var isFocused: Bool

    @State private var useSudo: Bool = AppSettings.defaultSudo
    @State private var showSudoPasswordDialog = false
    @State private var sudoPassword = ""
    @State private var outputHeight: CGFloat = 100

    @AppStorage(AppSettings.Keys.appearanceStyle) private var appearanceStyleRaw: String = AppSettings.appearanceStyleRaw.rawValue
    @AppStorage(AppSettings.Keys.defaultSudo) private var defaultSudo: Bool = false
    @AppStorage(AppSettings.Keys.mainUIMode) private var uiModeRaw: String = AppSettings.mainUIMode.rawValue

    private var appearanceStyle: AppearanceStyle { AppSettings.resolvedAppearanceStyle }

    private var uiMode: MainUIMode {
        #if BETA
        return MainUIMode(rawValue: uiModeRaw) ?? .classic
        #else
        return .classic
        #endif
    }

    private let cornerRadius: CGFloat = 12

    init(viewModel: CommandViewModel) { self.viewModel = viewModel }

    var body: some View {
        Group {
            if uiMode == .classic {
                classicLayout
            } else {
                liteLayout
            }
        }
        .frame(height: contentHeight)
        .background(
            uiMode == .classic
                ? AnyView(AdaptiveWindowBackground(style: appearanceStyle, material: .underWindowBackground, blendingMode: .behindWindow).ignoresSafeArea())
                : AnyView(Color.clear)
        )
        // 👈 隐藏按钮拦截 Cmd + R 用于重新执行
        .background(
            Button("") {
                executeLastCommand()
            }
            .keyboardShortcut("r", modifiers: .command)
            .opacity(0)
            .frame(width: 0, height: 0)
        )
        .onExitCommand {
            if viewModel.isRunning {
                viewModel.cancelExecution()
            } else {
                viewModel.closeSuggestions()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("FocusTextField"))) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { isFocused = true }
        }
        .sheet(isPresented: $showSudoPasswordDialog) {
            SudoPasswordDialog(
                password: $sudoPassword,
                onConfirm: { executeWithSudo() },
                onCancel: { showSudoPasswordDialog = false; sudoPassword = "" }
            )
        }
        .sheet(isPresented: $viewModel.showHistoryPanel) {
            HistorySearchView(viewModel: viewModel)
        }
        .onChange(of: showSudoPasswordDialog) { isShowing in
            if !isShowing { restoreInputFocus() }
        }
        .onChange(of: viewModel.showHistoryPanel) { isShowing in
            if !isShowing { restoreInputFocus() }
        }
        // 👈 快捷指令预设的 sudo 状态：消费后复位
        .onChange(of: viewModel.pendingSudoRequest) { pending in
            guard pending else { return }
            useSudo = true
            viewModel.pendingSudoRequest = false
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didEndSheetNotification)) { _ in
            restoreInputFocus()
        }
        .onChange(of: contentHeight) { newHeight in
            guard uiMode == .lite else { return }
            viewModel.session?.setContentHeight(newHeight)
        }
    }

    private func restoreInputFocus() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            isFocused = true
            viewModel.restoreInputFocus()
        }
    }

    private var contentHeight: CGFloat {
        if uiMode == .classic {
            return viewModel.outputText.isEmpty ? 140 : 120 + outputHeight
        } else {
            return viewModel.outputText.isEmpty
                ? 56
                : 56 + outputHeight + 24
        }
    }

    // MARK: - Classic
    private var classicLayout: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "terminal")
                    .foregroundColor(.secondary)
                    .font(.system(size: 18))
                    .frame(width: 24, height: 44)

                inputField.frame(maxWidth: .infinity)

                if viewModel.isRunning && viewModel.canCancel {
                    Button(action: viewModel.cancelExecution) {
                        Image(systemName: "stop.circle.fill")
                            .foregroundColor(.red)
                            .font(.system(size: 22))
                    }
                    .buttonStyle(.plain)
                    .frame(width: 24, height: 44)
                }

                Button(action: executeCommand) {
                    Image(systemName: viewModel.isRunning ? "ellipsis.circle" : "return")
                        .foregroundColor(.secondary)
                        .font(.system(size: 20))
                }
                .buttonStyle(.plain)
                .frame(width: 24, height: 44)
                .keyboardShortcut(.defaultAction)
                .disabled(viewModel.inputText.isEmpty || viewModel.isRunning)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.6))
                    .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
            )

            optionsRow
            outputRow
        }
        .padding(20)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Lite
    private var liteLayout: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Image(systemName: "terminal.fill")
                    .foregroundColor(.secondary.opacity(0.4))
                    .font(.system(size: 16))
                    .frame(width: 44, height: 44)
                    .help("Option + Return 以 root 执行")

                inputField.frame(maxWidth: .infinity)

                if viewModel.isRunning {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 44, height: 44)
                } else {
                    if !viewModel.outputText.isEmpty {
                        // Lite 复制按钮
                        Button(action: viewModel.copyOutputToPasteboard) {
                            Image(systemName: "doc.on.doc")
                                .foregroundColor(.secondary.opacity(0.5))
                                .font(.system(size: 14))
                        }
                        .buttonStyle(.plain)
                        .help(NSLocalizedString("button.copy.output", comment: ""))
                        .padding(.trailing, 8)
                    }
                    
                    Button(action: executeCommand) {
                        Image(systemName: "return")
                            .foregroundColor(.secondary.opacity(0.3))
                            .font(.system(size: 16))
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.defaultAction)
                    .disabled(viewModel.inputText.isEmpty || viewModel.isRunning)
                    .frame(width: 44, height: 44)
                }
            }
            .frame(height: 56)
            .padding(.horizontal, 8)

            if !viewModel.outputText.isEmpty {
                Divider().opacity(0.5)
                outputRow
                    .padding(.vertical, 12)
                    .padding(.horizontal, 20)
                    .textSelection(.enabled)
            }
        }
        .frame(maxWidth: .infinity)
        .background(liteGlassBackground)
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
    }

    @ViewBuilder
    private var liteGlassBackground: some View {
        switch appearanceStyle {
        case .none:
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color(NSColor.windowBackgroundColor))
        case .frostedGlass, .liquidGlass:
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
        }
    }

    // MARK: - 组件
    private var inputField: some View {
        RunTextField(
            text: $viewModel.inputText,
            onTab: viewModel.requestSuggestions,
            onEnter: executeCommand,
            onOptionEnter: executeWithSudoDirectly,
            onUp: { viewModel.navigateHistoryUp() },
            onDown: { viewModel.navigateHistoryDown() },
            onCoordinatorReady: { coordinator in
                viewModel.registerTextFieldCoordinator(coordinator)
            }
        )
        .focused($isFocused)
        .onAppear { isFocused = true }
        .frame(height: 44)
        .overlay(
            NSViewAccessor { nsView in viewModel.registerTextField(nsView) }
        )
    }

    private var optionsRow: some View {
        HStack {
            Toggle(isOn: $useSudo) {
                HStack(spacing: 4) {
                    Image(systemName: defaultSudo ? "lock.fill" : "lock.shield")
                        .font(.system(size: 12))
                        .foregroundColor(useSudo ? .orange : .secondary)
                    Text(NSLocalizedString("sudo.toggle.label", comment: ""))
                        .font(.system(size: 12))
                        .foregroundColor(useSudo ? .orange : .secondary)
                }
            }
            .toggleStyle(.checkbox)
            .disabled(defaultSudo)

            Spacer()

            if !viewModel.outputText.isEmpty {
                Button(action: viewModel.clearOutput) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary.opacity(0.5))
                }
                .buttonStyle(.plain)

                Button {
                    viewModel.copyOutputToPasteboard()
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    private var outputRow: some View {
        if !viewModel.outputText.isEmpty {
            OutputTextView(
                attributed: viewModel.outputAttributed,
                height: outputHeight,
                onContentWidth: { width in
                    let target = min(max(width + 40, 520), 1200)
                    viewModel.resizeWindow(to: target)
                }
            )
            .frame(height: outputHeight)
            .background(
                OutputHeightMeasurer(
                    outputText: viewModel.outputText,
                    outputHeight: $outputHeight
                )
            )
            .transition(.opacity)
        } else {
            if uiMode == .classic {
                HStack(spacing: 16) {
                    Text(NSLocalizedString("hint.drag.file", comment: ""))
                    Text("·")
                    Text(NSLocalizedString("hint.tab.completion", comment: ""))
                    Text("·")
                    Text(NSLocalizedString("hint.history.navigation", comment: ""))
                    Text("·")
                    Text(NSLocalizedString("hint.hide.window", comment: ""))
                    Text("·")
                    Text(NSLocalizedString("hint.shift.enter", comment: ""))
                }
                .font(.system(size: 11))
                .foregroundColor(.secondary.opacity(0.6))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
            }
        }
    }

    // MARK: - 逻辑
    func executeCommand() {
        guard !viewModel.inputText.isEmpty else { return }
        if useSudo {
            showSudoPasswordDialog = true
            sudoPassword = ""
        } else {
            viewModel.executeCommand(useSudo: false, password: nil) { _ in
                viewModel.closeSuggestions()
            }
        }
    }

    // 👈 重新执行上一条命令
    func executeLastCommand() {
        guard !viewModel.isRunning else { return }
        if useSudo {
            // 如果启用了 sudo，将历史命令填入输入框，唤起密码框
            let entries = CommandHistory.shared.getAll()
            if let last = entries.sorted(by: { $0.lastUsed > $1.lastUsed }).first {
                viewModel.inputText = last.command
                showSudoPasswordDialog = true
                sudoPassword = ""
            }
        } else {
            viewModel.executeLastCommand(useSudo: false, password: nil) { _ in
                viewModel.closeSuggestions()
            }
        }
    }

    func executeWithSudoDirectly() {
        guard !viewModel.inputText.isEmpty else { return }
        showSudoPasswordDialog = true
        sudoPassword = ""
    }

    func executeWithSudo() {
        showSudoPasswordDialog = false
        let password = sudoPassword
        sudoPassword = ""
        viewModel.executeCommand(useSudo: true, password: password) { _ in
            viewModel.closeSuggestions()
        }
    }
}

// MARK: - 底部辅助 View

private struct OutputHeightMeasurer: View {
    let outputText: String
    @Binding var outputHeight: CGFloat

    var body: some View {
        GeometryReader { _ in
            Color.clear
                .onChange(of: outputText) { _ in updateHeight() }
                .onAppear { updateHeight() }
        }
    }

    private func updateHeight() {
        let lines = outputText.components(separatedBy: "\n").count
        let newHeight = min(max(CGFloat(lines) * 20 + 20, 60), 220)
        withAnimation(.easeInOut(duration: 0.15)) {
            outputHeight = newHeight
        }
    }
}

struct SudoPasswordDialog: View {
    @Binding var password: String
    let onConfirm: () -> Void
    let onCancel: () -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "lock.shield.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 18))
                Text(NSLocalizedString("sudo.dialog.title", comment: ""))
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 4)

            Text(NSLocalizedString("sudo.dialog.message", comment: ""))
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            SecureField(NSLocalizedString("sudo.dialog.password.placeholder", comment: ""), text: $password)
                .textFieldStyle(.roundedBorder)
                .focused($isFocused)
                .onAppear { isFocused = true }
                .onSubmit { if !password.isEmpty { onConfirm() } }

            HStack(spacing: 12) {
                Spacer()
                Button(NSLocalizedString("button.cancel", comment: "")) { onCancel() }
                    .keyboardShortcut(.escape)
                Button(NSLocalizedString("button.execute", comment: "")) {
                    if !password.isEmpty { onConfirm() }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(password.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 380)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }
}

struct NSViewAccessor: NSViewRepresentable {
    let callback: (NSView) -> Void
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { callback(view) }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}
