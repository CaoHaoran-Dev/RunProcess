//
//  CommandViewModel.swift
//  RunProcess
//
//  Created by Haoran on 2026/8/21.
//

import SwiftUI
import Combine

class CommandViewModel: ObservableObject {
    @Published var inputText: String = ""
    @Published var outputText: String = ""
    @Published var isRunning: Bool = false
    @Published var canCancel: Bool = false
    @Published var suggestions: [Suggestion] = []
    @Published var selectedIndex: Int = 0
    
    private var historyIndex: Int = -1
    private var historyCommands: [String] = []
    private var currentInputBackup: String = ""
    
    private let suggester = CommandSuggester()
    private let history = CommandHistory()
    private var cancellables = Set<AnyCancellable>()
    private weak var textField: NSView?
    private var currentCompletion: ((String) -> Void)?
    
    init() {
        $inputText
            .dropFirst()
            .sink { [weak self] _ in
                self?.closeSuggestions()
                self?.resetHistoryNavigation()
            }
            .store(in: &cancellables)
    }
    
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
    
    func navigateHistoryUp() -> String? {
        if historyCommands.isEmpty {
            historyCommands = history.getAll().map { $0.command }
            currentInputBackup = inputText
        }
        
        guard !historyCommands.isEmpty else { return nil }
        
        if historyIndex == -1 {
            historyIndex = historyCommands.count - 1
        } else if historyIndex > 0 {
            historyIndex -= 1
        }
        
        return historyCommands[historyIndex]
    }
    
    func navigateHistoryDown() -> String? {
        guard !historyCommands.isEmpty else { return nil }
        
        if historyIndex < historyCommands.count - 1 && historyIndex >= 0 {
            historyIndex += 1
            return historyCommands[historyIndex]
        } else if historyIndex == historyCommands.count - 1 {
            historyIndex = -1
            return currentInputBackup
        } else {
            return nil
        }
    }
    
    func resetHistoryNavigation() {
        historyIndex = -1
        historyCommands = []
        currentInputBackup = ""
    }
    
    private func isInteractiveCommand(_ command: String) -> Bool {
        let hasPipe = command.contains("|")
        let hasRedirect = command.contains(">") || command.contains("<")
        
        let firstPart = command.split(separator: "|").first.map(String.init) ?? command
        let trimmed = firstPart.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let interactiveCommands = [
            "vim", "vi", "nano", "emacs", "top", "htop", "less", "more",
            "ssh", "telnet", "ftp", "sftp",
            "python", "python3", "ipython", "irb", "node",
            "mysql", "psql", "sqlite3",
            "gdb", "lldb", "bc", "dc",
            "sh", "bash", "zsh", "fish",
            "mail", "mutt", "pine"
        ]
        
        for cmd in interactiveCommands {
            if trimmed == cmd || trimmed.hasPrefix(cmd + " ") {
                if hasPipe || hasRedirect {
                    return false
                }
                return true
            }
        }
        
        if command.contains(" -i ") || command.contains(" --interactive ") {
            return true
        }
        
        return false
    }
    
    func executeCommand(completion: @escaping (String) -> Void) {
        guard !inputText.isEmpty else { return }
        
        if isInteractiveCommand(inputText) {
            isRunning = false
            canCancel = false
            outputText = NSLocalizedString("error.interactive.command", comment: "Interactive command error")
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
                        self.outputText = NSLocalizedString("output.success", comment: "Success message")
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
        outputText = NSLocalizedString("output.cancelled", comment: "Cancelled message")
        currentCompletion?(outputText)
        currentCompletion = nil
    }
    
    func executeCommandWithSudo(_ command: String, password: String, completion: @escaping (String) -> Void) {
        guard !command.isEmpty else { return }
        
        if isInteractiveCommand(command) {
            isRunning = false
            canCancel = false
            outputText = NSLocalizedString("error.interactive.command", comment: "Interactive command error")
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
                        self.outputText = NSLocalizedString("output.success.sudo", comment: "Success message with sudo")
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
