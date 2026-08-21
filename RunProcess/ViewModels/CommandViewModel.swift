//
//  CommandViewModel.swift
//  RunProcess
//
//  Created by Haoran on 2026/8/21.
//

import SwiftUI
import Combine

class CommandViewModel: ObservableObject {
    // MARK: - Published 属性
    
    @Published var inputText: String = ""
    @Published var outputText: String = ""
    @Published var isRunning: Bool = false
    
    // 候选列表相关
    @Published var suggestions: [Suggestion] = []
    @Published var selectedIndex: Int = 0
    
    // MARK: - 私有属性
    
    private let suggester = CommandSuggester()
    private let history = CommandHistory()
    private var cancellables = Set<AnyCancellable>()
    private weak var textField: NSView?
    
    // MARK: - 初始化
    
    init() {
        // 监听输入变化，关闭候选列表（打字时自动关闭）
        $inputText
            .dropFirst()
            .sink { [weak self] _ in
                self?.closeSuggestions()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - 公开方法
    
    /// 注册输入框（用于面板定位）
    func registerTextField(_ view: NSView) {
        textField = view
    }
    
    /// 请求补全建议（按 Tab 时调用）
    func requestSuggestions() {
        guard !inputText.isEmpty else {
            closeSuggestions()
            return
        }
        
        suggester.suggest(for: inputText) { [weak self] results in
            guard let self = self else { return }
            
            if results.isEmpty {
                self.closeSuggestions()
            } else {
                self.suggestions = results
                self.selectedIndex = 0
                self.showPanel()
            }
        }
    }
    
    /// 显示面板
    private func showPanel() {
        guard let textField = textField else { return }
        SuggestionPanel.shared.show(with: self, relativeTo: textField)
    }
    
    /// 选择下一个候选
    func selectNext() {
        guard !suggestions.isEmpty else { return }
        selectedIndex = (selectedIndex + 1) % suggestions.count
        SuggestionPanel.shared.updateContent(self)
    }
    
    /// 选择上一个候选
    func selectPrevious() {
        guard !suggestions.isEmpty else { return }
        selectedIndex = (selectedIndex - 1 + suggestions.count) % suggestions.count
        SuggestionPanel.shared.updateContent(self)
    }
    
    /// 确认当前选中的候选
    func confirmSelection() {
        guard selectedIndex < suggestions.count else { return }
        
        let selected = suggestions[selectedIndex]
        applySuggestion(selected)
    }
    
    /// 关闭候选列表
    func closeSuggestions() {
        suggestions = []
        selectedIndex = 0
        SuggestionPanel.shared.hide()
    }
    
    /// 检测是否是交互式命令
    private func isInteractiveCommand(_ command: String) -> Bool {
        let interactiveCommands = [
            "vim", "vi", "nano", "emacs", "top", "htop", "less", "more",
            "ssh", "telnet", "ftp", "sftp", "python", "python3", "ipython",
            "irb", "node", "sh", "bash", "zsh", "fish", "mysql", "psql",
            "sqlite3", "gdb", "lldb", "bc", "dc", "mail", "mutt", "pine"
        ]
        
        // 提取命令的第一个单词
        let firstWord = command.split(separator: " ").first.map(String.init) ?? ""
        
        // 检查是否是交互式命令
        if interactiveCommands.contains(firstWord) {
            return true
        }
        
        // 检查是否有交互式参数
        if command.contains(" -i") || command.contains(" --interactive") {
            return true
        }
        
        return false
    }
    
    /// 执行命令
    func executeCommand(completion: @escaping (String) -> Void) {
        guard !inputText.isEmpty else { return }
        
        // 检测交互式命令
        if isInteractiveCommand(inputText) {
            isRunning = false
            outputText = "⚠️ 交互式命令（如 vim、python、top 等）暂不支持\n💡 请在系统终端中执行此命令"
            completion(outputText)
            return
        }
        
        // 记录历史
        history.record(inputText)
        
        isRunning = true
        outputText = ""
        
        // 执行命令（带 10 秒超时）
        CommandExecutor.shared.execute(inputText, timeout: 10.0) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isRunning = false
                switch result {
                case .success(let text):
                    if text.isEmpty {
                        self.outputText = "✅ 执行成功"
                    } else {
                        self.outputText = text
                    }
                case .failure(let error):
                    self.outputText = "❌ \(error.localizedDescription)"
                }
                completion(self.outputText)
            }
        }
    }
    
    /// 执行 sudo 命令
    func executeCommandWithSudo(_ sudoCommand: String, completion: @escaping (String) -> Void) {
        guard !sudoCommand.isEmpty else { return }
        
        isRunning = true
        outputText = ""
        
        // 记录历史（记录原始命令，不记录密码）
        history.record(inputText)
        
        // 执行命令（带 10 秒超时）
        CommandExecutor.shared.execute(sudoCommand, timeout: 10.0) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isRunning = false
                switch result {
                case .success(let text):
                    if text.isEmpty {
                        self.outputText = "✅ 执行成功（root 权限）"
                    } else {
                        self.outputText = text
                    }
                case .failure(let error):
                    let errorMsg = error.localizedDescription
                    if errorMsg.contains("sudo") || errorMsg.contains("password") {
                        self.outputText = "❌ sudo 执行失败\n💡 请检查密码是否正确"
                    } else {
                        self.outputText = "❌ \(errorMsg)"
                    }
                }
                completion(self.outputText)
            }
        }
    }
    
    /// 清空历史记录
    func clearHistory() {
        history.clearAll()
        closeSuggestions()
    }
    
    // MARK: - 私有方法
    
    private func applySuggestion(_ suggestion: Suggestion) {
        let words = inputText.split(separator: " ", omittingEmptySubsequences: false)
        if words.count > 1 {
            let prefix = words.dropLast().joined(separator: " ")
            inputText = prefix + " " + suggestion.text
        } else {
            inputText = suggestion.text
        }
        
        closeSuggestions()
    }
}
