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
    @Published var canCancel: Bool = false
    
    // 候选列表相关
    @Published var suggestions: [Suggestion] = []
    @Published var selectedIndex: Int = 0
    
    // 历史命令导航
    private var historyIndex: Int = -1
    private var historyCommands: [String] = []
    private var currentInputBackup: String = ""  // 保存当前输入，按↓时恢复
    
    // MARK: - 私有属性
    
    private let suggester = CommandSuggester()
    private let history = CommandHistory()
    private var cancellables = Set<AnyCancellable>()
    private weak var textField: NSView?
    private var currentCompletion: ((String) -> Void)?
    
    // MARK: - 初始化
    
    init() {
        $inputText
            .dropFirst()
            .sink { [weak self] _ in
                self?.closeSuggestions()
                // 用户打字时重置历史导航
                self?.resetHistoryNavigation()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - 公开方法
    
    func registerTextField(_ view: NSView) {
        textField = view
    }
    
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
    
    private func showPanel() {
        guard let textField = textField else { return }
        SuggestionPanel.shared.show(with: self, relativeTo: textField)
    }
    
    func selectNext() {
        guard !suggestions.isEmpty else { return }
        selectedIndex = (selectedIndex + 1) % suggestions.count
        SuggestionPanel.shared.updateContent(self)
    }
    
    func selectPrevious() {
        guard !suggestions.isEmpty else { return }
        selectedIndex = (selectedIndex - 1 + suggestions.count) % suggestions.count
        SuggestionPanel.shared.updateContent(self)
    }
    
    func confirmSelection() {
        guard selectedIndex < suggestions.count else { return }
        
        let selected = suggestions[selectedIndex]
        applySuggestion(selected)
    }
    
    func closeSuggestions() {
        suggestions = []
        selectedIndex = 0
        SuggestionPanel.shared.hide()
    }
    
    /// 导航到上一条历史命令（按上键）
    func navigateHistoryUp() -> String? {
        // 首次按上键时，加载历史列表并保存当前输入
        if historyCommands.isEmpty {
            historyCommands = history.getAll().map { $0.command }
            currentInputBackup = inputText
        }
        
        guard !historyCommands.isEmpty else { return nil }
        
        // 如果当前没有选中任何历史，从最后一条开始
        if historyIndex == -1 {
            historyIndex = historyCommands.count - 1
        } else if historyIndex > 0 {
            historyIndex -= 1
        }
        
        return historyCommands[historyIndex]
    }
    
    /// 导航到下一条历史命令（按下键）
    func navigateHistoryDown() -> String? {
        guard !historyCommands.isEmpty else { return nil }
        
        if historyIndex < historyCommands.count - 1 && historyIndex >= 0 {
            historyIndex += 1
            return historyCommands[historyIndex]
        } else if historyIndex == historyCommands.count - 1 {
            // 已经到最后一条，再按↓回到当前输入
            historyIndex = -1
            return currentInputBackup
        } else {
            // historyIndex == -1，没有历史可下翻
            return nil
        }
    }
    
    /// 重置历史导航
    func resetHistoryNavigation() {
        historyIndex = -1
        historyCommands = []
        currentInputBackup = ""
    }
    
    private func isInteractiveCommand(_ command: String) -> Bool {
        if command.contains(" -c ") || command.contains(" --command ") {
            return false
        }
        
        let patterns = [
            #"^(vim?|nano|emacs|top|htop|less|more)\b"#,
            #"^(ssh|telnet|ftp|sftp)\s+[^-]"#,
            #"^(python|python3|ipython|irb|node)\b"#,
            #"^(mysql|psql|sqlite3)\b"#,
            #"^(gdb|lldb|bc|dc)\b"#,
            #"^(sh|bash|zsh|fish)\b"#,
            #"^(mail|mutt|pine)\b"#,
            #"\b(-i|--interactive)\b"#
        ]
        
        for pattern in patterns {
            if command.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }
        
        return false
    }
    
    func executeCommand(completion: @escaping (String) -> Void) {
        guard !inputText.isEmpty else { return }
        
        if isInteractiveCommand(inputText) {
            isRunning = false
            canCancel = false
            outputText = "⚠️ 交互式命令（如 vim、python、top 等）暂不支持\n💡 请在系统终端中执行此命令"
            completion(outputText)
            return
        }
        
        history.record(inputText)
        resetHistoryNavigation()
        
        isRunning = true
        canCancel = true
        outputText = ""
        
        currentCompletion = completion
        
        CommandExecutor.shared.execute(inputText, timeout: 10.0) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isRunning = false
                self.canCancel = false
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
                self.currentCompletion = nil
            }
        }
    }
    
    func cancelExecution() {
        guard isRunning else { return }
        CommandExecutor.shared.cancelCurrentTask()
        isRunning = false
        canCancel = false
        outputText = "⏹️ 已取消执行"
        currentCompletion?(outputText)
        currentCompletion = nil
    }
    
    func executeCommandWithSudo(_ command: String, password: String, completion: @escaping (String) -> Void) {
        guard !command.isEmpty else { return }
        
        if isInteractiveCommand(command) {
            isRunning = false
            canCancel = false
            outputText = "⚠️ 交互式命令（如 vim、python、top 等）暂不支持\n💡 请在系统终端中执行此命令"
            completion(outputText)
            return
        }
        
        history.record(command)
        resetHistoryNavigation()
        
        isRunning = true
        canCancel = true
        outputText = ""
        
        currentCompletion = completion
        
        CommandExecutor.shared.executeWithSudo(command, password: password, timeout: 10.0) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isRunning = false
                self.canCancel = false
                switch result {
                case .success(let text):
                    if text.isEmpty {
                        self.outputText = "✅ 执行成功（root 权限）"
                    } else {
                        self.outputText = text
                    }
                case .failure(let error):
                    self.outputText = "❌ \(error.localizedDescription)"
                }
                completion(self.outputText)
                self.currentCompletion = nil
            }
        }
    }
    
    func clearHistory() {
        history.clearAll()
        resetHistoryNavigation()
        closeSuggestions()
    }
    
    func clearOutput() {
        outputText = ""
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
        resetHistoryNavigation()
    }
}
