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
    
    @State private var useSudo: Bool = false
    @State private var showSudoPasswordDialog: Bool = false
    @State private var sudoPassword: String = ""
    @State private var outputHeight: CGFloat = 100
    
    init(viewModel: CommandViewModel) {
        self.viewModel = viewModel
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Input row
            HStack(spacing: 8) {
                Image(systemName: "terminal")
                    .foregroundColor(.secondary)
                    .font(.system(size: 16))
                
                RunTextField(
                    text: $viewModel.inputText,
                    onTab: viewModel.requestSuggestions,
                    onEnter: executeCommand,
                    onUp: { viewModel.navigateHistoryUp() },
                    onDown: { viewModel.navigateHistoryDown() }
                )
                .font(.system(size: 18, design: .monospaced))
                .textFieldStyle(.plain)
                .focused($isFocused)
                .onAppear {
                    isFocused = true
                }
                .overlay(
                    NSViewAccessor { nsView in
                        viewModel.registerTextField(nsView)
                    }
                )
                
                if viewModel.isRunning && viewModel.canCancel {
                    Button(action: viewModel.cancelExecution) {
                        Image(systemName: "stop.circle.fill")
                            .foregroundColor(.red)
                            .font(.system(size: 20))
                    }
                    .buttonStyle(.plain)
                    .help(NSLocalizedString("button.cancel.tooltip", comment: "Cancel button tooltip"))
                }
                
                Button(action: executeCommand) {
                    Image(systemName: viewModel.isRunning ? "ellipsis.circle" : "return")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.defaultAction)
                .disabled(viewModel.inputText.isEmpty || viewModel.isRunning)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.6))
                    .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
            )
            
            // Options row
            HStack {
                Toggle(isOn: $useSudo) {
                    HStack(spacing: 4) {
                        Image(systemName: "lock.shield")
                            .font(.system(size: 12))
                            .foregroundColor(useSudo ? .orange : .secondary)
                        Text(NSLocalizedString("sudo.toggle.label", comment: "Sudo toggle label"))
                            .font(.system(size: 12))
                            .foregroundColor(useSudo ? .orange : .secondary)
                    }
                }
                .toggleStyle(.checkbox)
                .help(NSLocalizedString("sudo.toggle.label", comment: "Sudo toggle label"))
                
                Spacer()
                
                if !viewModel.outputText.isEmpty {
                    Button(action: viewModel.clearOutput) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                    .help(NSLocalizedString("output.clear.tooltip", comment: "Clear output tooltip"))
                }
                
                if viewModel.isRunning {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.leading, 4)
                }
            }
            .padding(.horizontal, 4)
            
            // Output area
            if !viewModel.outputText.isEmpty {
                ScrollView {
                    Text(viewModel.outputText)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                        .textSelection(.enabled)
                }
                .frame(minHeight: 60, maxHeight: 200)
                .transition(.opacity)
                .background(
                    GeometryReader { geometry in
                        Color.clear
                            .onChange(of: viewModel.outputText) { _ in
                                let lines = viewModel.outputText.components(separatedBy: "\n").count
                                let newHeight = min(max(CGFloat(lines) * 20 + 20, 60), 200)
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    outputHeight = newHeight
                                }
                            }
                            .onAppear {
                                let lines = viewModel.outputText.components(separatedBy: "\n").count
                                outputHeight = min(max(CGFloat(lines) * 20 + 20, 60), 200)
                            }
                    }
                )
                .frame(height: outputHeight)
            } else {
                HStack(spacing: 16) {
                    Text(NSLocalizedString("hint.drag.file", comment: "Drag file hint"))
                    Text("·")
                    Text(NSLocalizedString("hint.tab.completion", comment: "Tab completion hint"))
                    Text("·")
                    Text(NSLocalizedString("hint.history.navigation", comment: "History navigation hint"))
                    Text("·")
                    Text(NSLocalizedString("hint.global.hotkey", comment: "Global hotkey hint"))
                    Text("·")
                    Text(NSLocalizedString("hint.hide.window", comment: "Hide window hint"))
                }
                .font(.system(size: 11))
                .foregroundColor(.secondary.opacity(0.6))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
            }
        }
        .padding(20)
        .frame(width: 520, height: viewModel.outputText.isEmpty ? 160 : 240 + (outputHeight - 100))
        .background(
            VisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow)
                .ignoresSafeArea()
        )
        .onExitCommand {
            viewModel.closeSuggestions()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("FocusTextField"))) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isFocused = true
            }
        }
        .sheet(isPresented: $showSudoPasswordDialog) {
            SudoPasswordDialog(
                password: $sudoPassword,
                onConfirm: {
                    executeWithSudo()
                },
                onCancel: {
                    showSudoPasswordDialog = false
                    sudoPassword = ""
                }
            )
        }
    }
    
    func executeCommand() {
        guard !viewModel.inputText.isEmpty else { return }
        
        if useSudo {
            showSudoPasswordDialog = true
            sudoPassword = ""
        } else {
            viewModel.executeCommand { _ in
                viewModel.closeSuggestions()
            }
        }
    }
    
    func executeWithSudo() {
        showSudoPasswordDialog = false
        
        let command = viewModel.inputText
        let password = sudoPassword
        sudoPassword = ""
        
        viewModel.executeCommandWithSudo(command, password: password) { _ in
            viewModel.closeSuggestions()
        }
    }
}

// MARK: - Sudo Password Dialog

struct SudoPasswordDialog: View {
    @Binding var password: String
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    @FocusState private var isPasswordFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "lock.shield.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 18))
                Text(NSLocalizedString("sudo.dialog.title", comment: "Sudo dialog title"))
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 4)
            
            Text(NSLocalizedString("sudo.dialog.message", comment: "Sudo dialog message"))
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            SecureField(
                NSLocalizedString("sudo.dialog.password.placeholder", comment: "Password placeholder"),
                text: $password
            )
            .textFieldStyle(.roundedBorder)
            .focused($isPasswordFieldFocused)
            .onAppear {
                isPasswordFieldFocused = true
            }
            .onSubmit {
                if !password.isEmpty {
                    onConfirm()
                }
            }
            
            HStack {
                Image(systemName: "info.circle")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.6))
                Text(NSLocalizedString("sudo.dialog.security.hint", comment: "Security hint"))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.6))
                Spacer()
            }
            
            HStack(spacing: 12) {
                Button(NSLocalizedString("button.cancel", comment: "Cancel button")) {
                    onCancel()
                }
                .keyboardShortcut(.escape)
                
                Button(NSLocalizedString("button.execute", comment: "Execute button")) {
                    if !password.isEmpty {
                        onConfirm()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(password.isEmpty)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(20)
        .frame(width: 380)
        .background(
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .cornerRadius(12)
        )
    }
}

// MARK: - Helper Views

struct NSViewAccessor: NSViewRepresentable {
    let callback: (NSView) -> Void
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            callback(view)
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
}
