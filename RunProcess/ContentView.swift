//
//  ContentView.swift
//  RunProcess
//
//  Created by Haoran on 2026/8/19.
//

import SwiftUI

struct ContentView: View {
    @State private var input: String = ""
    @State private var output: String = ""
    @State private var isRunning: Bool = false
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            // 输入框
            HStack(spacing: 8) {
                Image(systemName: "terminal")
                    .foregroundColor(.secondary)
                    .font(.system(size: 16))
                
                RunTextField(text: $input, onEnter: executeCommand)
                    .font(.system(size: 18, design: .monospaced))
                    .textFieldStyle(.plain)
                    .focused($isFocused)
                    .onAppear {
                        isFocused = true
                    }
                
                Button(action: executeCommand) {
                    Image(systemName: "return")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.defaultAction)
                .disabled(input.isEmpty || isRunning)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
            )
            
            // 输出/提示区域
            if !output.isEmpty {
                ScrollView {
                    Text(output)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                }
                .frame(maxHeight: 60)
                .transition(.opacity)
            } else {
                HStack {
                    Text("拖入文件自动填充路径 · ⌘W隐藏")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary.opacity(0.6))
                    Spacer()
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(20)
        .frame(width: 520, height: output.isEmpty ? 120 : 180)
        .background(
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()
        )
    }
    
    func executeCommand() {
        guard !input.isEmpty else { return }
        isRunning = true
        output = ""
        
        CommandExecutor.shared.execute(input) { result in
            DispatchQueue.main.async {
                isRunning = false
                switch result {
                case .success(let text):
                    if text.isEmpty {
                        output = "✅ 执行成功"
                    } else {
                        output = text
                    }
                case .failure(let error):
                    output = "❌ \(error.localizedDescription)"
                }
            }
        }
    }
}

// 毛玻璃效果
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
