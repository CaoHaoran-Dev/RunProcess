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
            // 输入行
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
                
                // 取消按钮（执行时显示）
                if viewModel.isRunning && viewModel.canCancel {
                    Button(action: viewModel.cancelExecution) {
                        Image(systemName: "stop.circle.fill")
                            .foregroundColor(.red)
                            .font(.system(size: 20))
                    }
                    .buttonStyle(.plain)
                    .help("取消执行")
                }
                
                // 执行按钮
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
            
            // 选项行
            HStack {
                Toggle(isOn: $useSudo) {
                    HStack(spacing: 4) {
                        Image(systemName: "lock.shield")
                            .font(.system(size: 12))
                            .foregroundColor(useSudo ? .orange : .secondary)
                        Text("以 root 执行")
                            .font(.system(size: 12))
                            .foregroundColor(useSudo ? .orange : .secondary)
                    }
                }
                .toggleStyle(.checkbox)
                .help("勾选后命令前会自动添加 sudo")
                
                Spacer()
                
                // 清空输出按钮
                if !viewModel.outputText.isEmpty {
                    Button(action: viewModel.clearOutput) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                    .help("清空输出")
                }
                
                // 执行状态指示器
                if viewModel.isRunning {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.leading, 4)
                }
            }
            .padding(.horizontal, 4)
            
            // 输出区域
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
                // ✅ 底部提示：简洁文字，不加图标
                HStack(spacing: 16) {
                    Text("拖入文件")
                    Text("·")
                    Text("Tab 补全")
                    Text("·")
                    Text("↑↓ 历史")
                    Text("·")
                    Text("⌘⌥R 全局")
                    Text("·")
                    Text("⌘W 隐藏")
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

// MARK: - Sudo 密码对话框

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
                Text("需要管理员权限")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 4)
            
            Text("执行此命令需要 root 权限，请输入密码")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            SecureField("输入密码", text: $password)
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
                Text("密码仅在内存中临时使用，不会被存储或记录")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.6))
                Spacer()
            }
            
            HStack(spacing: 12) {
                Button("取消") {
                    onCancel()
                }
                .keyboardShortcut(.escape)
                
                Button("执行") {
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
