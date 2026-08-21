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
    
    // 复选框状态
    @State private var useSudo: Bool = false
    @State private var showSudoPasswordDialog: Bool = false
    @State private var sudoPassword: String = ""
    
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
                    onEnter: executeCommand
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
                
                Button(action: executeCommand) {
                    Image(systemName: "return")
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
            
            // 选项行：Sudo 复选框
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
                
                // 执行状态指示器
                if viewModel.isRunning {
                    ProgressView()
                        .controlSize(.small)
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
                .frame(maxHeight: 100)
                .transition(.opacity)
            } else {
                HStack {
                    Text("拖入文件自动填充路径 · Tab 补全 · ⌘W 隐藏")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary.opacity(0.6))
                    Spacer()
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(20)
        .frame(width: 520, height: viewModel.outputText.isEmpty ? 160 : 240)
        .background(
            VisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow)
                .ignoresSafeArea()
        )
        .onExitCommand {
            viewModel.closeSuggestions()
        }
        // 密码对话框
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
        
        // 如果勾选了 sudo，弹出密码对话框
        if useSudo {
            showSudoPasswordDialog = true
            sudoPassword = ""
        } else {
            // 直接执行
            viewModel.executeCommand { _ in
                viewModel.closeSuggestions()
            }
        }
    }
    
    func executeWithSudo() {
        showSudoPasswordDialog = false
        
        // 构建带 sudo 的命令
        let command = viewModel.inputText
        let sudoCommand = "echo '\(sudoPassword)' | sudo -S \(command)"
        sudoPassword = ""
        
        // 执行
        viewModel.executeCommandWithSudo(sudoCommand) { _ in
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
            // 标题
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
            
            // 密码输入框
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
            
            // 提示
            HStack {
                Text("💡 密码仅用于本次执行，不会被存储")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.6))
                Spacer()
            }
            
            // 按钮
            HStack(spacing: 12) {
                Button("取消") {
                    onCancel()
                }
                .keyboardShortcut(.escape)  // 修复：使用 .escape 替代 .cancel
                
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
