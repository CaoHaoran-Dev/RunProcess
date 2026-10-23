//
//  CommandViewModel.swift
//  RunProcess
//
//  Created by Haoran on 2026/8/21.
//

import SwiftUI
import Combine
internal import AppKit

class CommandViewModel: ObservableObject {
    @Published var inputText: String = ""
    @Published var outputText: String = ""
    @Published var outputAttributed: NSAttributedString = NSAttributedString()
    @Published var isRunning: Bool = false
    @Published var canCancel: Bool = false
    @Published var suggestions: [Suggestion] = []
    @Published var selectedIndex: Int = 0
    @Published var showHistoryPanel: Bool = false

    var usesSessionMode: Bool = false
    weak var session: Session?

    var executeHandler: ((String, Bool, String?, @escaping (Result<String, Error>) -> Void) -> Void)?
    var cancelHandler: (() -> Void)?

    private var historyIndex: Int = -1
    private var historyCommands: [String] = []
    private var currentInputBackup: String = ""

    private let suggester = CommandSuggester()
    private let history = CommandHistory.shared
    private var cancellables = Set<AnyCancellable>()
    private weak var textField: NSView?

    private weak var textFieldCoordinator: RunTextField.Coordinator?

    private var cachedColorsEnabled = AppSettings.outputColorsEnabled
    private var cachedColorScheme = AppSettings.outputColorScheme

    // MARK: - Init

    init() {
        $inputText
            .dropFirst()
            .sink { [weak self] _ in
                self?.closeSuggestions()
                self?.resetHistoryNavigation()
            }
            .store(in: &cancellables)

        $outputText
            .sink { [weak self] text in
                self?.outputAttributed = ANSIParser.parse(text)
            }
            .store(in: &cancellables)

        NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            let enabled = AppSettings.outputColorsEnabled
            let scheme = AppSettings.outputColorScheme
            if enabled != self.cachedColorsEnabled || scheme != self.cachedColorScheme {
                self.cachedColorsEnabled = enabled
                self.cachedColorScheme = scheme
                self.outputAttributed = ANSIParser.parse(self.outputText)
            }
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - TextField 注册

    func registerTextField(_ view: NSView) {
        textField = view
    }

    func registerTextFieldCoordinator(_ coordinator: RunTextField.Coordinator) {
        textFieldCoordinator = coordinator
    }

    func restoreInputFocus() {
        if let coordinator = textFieldCoordinator {
            coordinator.restoreFocus()
        } else if let tv = textField as? NSTextView, let win = tv.window {
            guard win.isKeyWindow, win.attachedSheet == nil else { return }
            win.makeFirstResponder(tv)
        }
    }

    var positioningView: NSView? {
        textField
    }

    // MARK: - 窗口宽度

    func resizeWindow(to width: CGFloat) {
        session?.setContentWidth(width)
    }

    // MARK: - 补全

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
                SuggestionPanel.shared.show(with: self)
            }
        }
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
        applySuggestion(suggestions[selectedIndex])
    }

    func closeSuggestions() {
        suggestions = []
        selectedIndex = 0
        SuggestionPanel.shared.hide()
    }

    // MARK: - 历史导航

    func navigateHistoryUp() -> String? {
        if historyCommands.isEmpty {
            historyCommands = history.getAll()
                .sorted { $0.frecency > $1.frecency }
                .map { $0.command }
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
        }
        return nil
    }

    func resetHistoryNavigation() {
        historyIndex = -1
        historyCommands = []
        currentInputBackup = ""
    }

    // MARK: - 执行

    func executeCommand(useSudo: Bool, password: String?,
                        completion: @escaping (String) -> Void) {
        guard !inputText.isEmpty else { return }

        var processedCommand = CommandPreprocessor.process(inputText)
        processedCommand = CommandPreprocessor.resolveCustomPath(processedCommand)
        processedCommand = expandAlias(in: processedCommand)

        if processedCommand != inputText {
            inputText = processedCommand
        }

        // 多行命令跳过交互式检查
        if !processedCommand.contains("\n") && CommandPreprocessor.isInteractive(processedCommand) {
            isRunning = false
            canCancel = false
            outputText = NSLocalizedString("error.interactive.command", comment: "")
            completion(outputText)
            return
        }

        history.record(processedCommand)
        resetHistoryNavigation()

        isRunning = true
        canCancel = true
        outputText = ""

        guard let handler = executeHandler else {
            isRunning = false
            canCancel = false
            outputText = "❌ 执行器未配置"
            completion(outputText)
            return
        }

        handler(processedCommand, useSudo, password) { [weak self] result in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.isRunning = false
                self.canCancel = false
                switch result {
                case .success(let text):
                    self.outputText = text.isEmpty
                        ? NSLocalizedString("output.success", comment: "")
                        : text
                case .failure(let error):
                    let rawError = error.localizedDescription

                    // 👇 新增：交互式命令 / TTY 相关错误统一拦截
                    let lower = rawError.lowercased()
                    if lower.contains("not a terminal")
                        || lower.contains("requires a tty")
                        || lower.contains("can't be run in this context")
                        || lower.contains("cannot be run in this context")
                        || lower.contains("stdin is not a tty")
                        || lower.contains("inappropriate ioctl")
                    {
                        self.outputText = "❌ " + NSLocalizedString("error.interactive.command", comment: "")
                        completion(self.outputText)
                        return
                    }

                    // 追加错误解释
                    let explanation = self.explainError(rawError)
                    self.outputText = "❌ \(rawError)\(explanation)"
                }
                completion(self.outputText)
            }
        }
    }

    // 👈 重新执行上一条命令
    func executeLastCommand(useSudo: Bool, password: String?, completion: @escaping (String) -> Void) {
        let entries = history.getAll()
        guard let lastEntry = entries.sorted(by: { $0.lastUsed > $1.lastUsed }).first else {
            return
        }
        inputText = lastEntry.command
        restoreInputFocus()
        executeCommand(useSudo: useSudo, password: password, completion: completion)
    }

    // 👇 修改：错误解释改为更通用的关键词匹配
    private func explainError(_ rawError: String) -> String {
        guard AppSettings.explainErrors else { return "" }

        let lower = rawError.lowercased()

        // 1. 找不到命令（覆盖 zsh/bash/sh 的多种措辞）
        if lower.contains("command not found")
            || lower.contains("not found in path")
            || lower.contains("no such file or directory: ")
        {
            var cmdName = "unknown"
            let candidates = rawError.split(whereSeparator: { $0 == " " || $0 == ":" || $0 == "\n" })
            if let idx = candidates.firstIndex(where: { $0.lowercased() == "command" || $0.lowercased() == "not" }),
               idx > 0 {
                cmdName = String(candidates[idx - 1])
            } else if let first = candidates.first, !first.isEmpty {
                cmdName = String(first)
            }
            return String(format: NSLocalizedString("error.explain.not.found", comment: ""), cmdName)
        }

        // 2. 权限问题
        if lower.contains("permission denied")
            || lower.contains("operation not permitted")
            || lower.contains("access denied")
            || lower.contains("not authorized")
        {
            return NSLocalizedString("error.explain.permission", comment: "")
        }

        // 3. 文件/目录不存在
        if lower.contains("no such file or directory")
            || lower.contains("does not exist")
            || lower.contains("cannot find")
            || lower.contains("can't find")
            || lower.contains("unable to find")
        {
            return NSLocalizedString("error.explain.no.file", comment: "")
        }

        // 4. 需要 root / sudo
        if lower.contains("must be run as root")
            || lower.contains("requires root")
            || lower.contains("try again as root")
            || lower.contains("you need to be root")
            || lower.contains("not permitted")
        {
            return NSLocalizedString("error.explain.sudo.required", comment: "")
        }

        // 5. 网络错误
        if lower.contains("could not resolve host")
            || lower.contains("connection refused")
            || lower.contains("connection timed out")
            || lower.contains("network is unreachable")
            || lower.contains("no route to host")
        {
            return NSLocalizedString("error.explain.network", comment: "")
        }

        // 6. 磁盘 / 空间问题
        if lower.contains("no space left")
            || lower.contains("disk full")
            || lower.contains("read-only file system")
        {
            return NSLocalizedString("error.explain.disk", comment: "")
        }

        // 7. Shell 语法错误
        if lower.contains("parse error")
            || lower.contains("syntax error")
            || lower.contains("bad substitution")
            || lower.contains("unmatched")
            || lower.contains("unexpected token")
        {
            return NSLocalizedString("error.explain.syntax", comment: "")
        }

        return ""
    }

    private func expandAlias(in command: String) -> String {
        let parts = command.split(separator: " ", maxSplits: 1,
                                  omittingEmptySubsequences: false)
        guard let first = parts.first, !first.isEmpty else { return command }
        let name = String(first)
        guard let expansion = AliasStore.shared.expansion(for: name) else { return command }
        if parts.count == 1 { return expansion }
        return expansion + " " + parts[1]
    }

    func cancelExecution() {
        guard isRunning else { return }
        cancelHandler?()
        isRunning = false
        canCancel = false
        outputText = NSLocalizedString("output.cancelled", comment: "")
    }

    func clearHistory() {
        history.clearAll()
        resetHistoryNavigation()
        closeSuggestions()
    }

    func clearOutput() {
        outputText = ""
        outputAttributed = NSAttributedString()
    }

    func copyOutputToPasteboard() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(outputText, forType: .string)
        restoreInputFocus()
    }

    func showSessionResetNotice() {
        outputText = NSLocalizedString("session.reset.notice", comment: "")
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
        restoreInputFocus()
    }
}

// MARK: - 纯函数：命令预处理

enum CommandPreprocessor {

    static func process(_ input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()

        if lower.hasPrefix("open ") || lower.hasPrefix("start ") { return trimmed }

        let unwrapped = unwrapQuotes(trimmed)

        if unwrapped.hasSuffix(".app") || unwrapped.hasSuffix(".app/") {
            return "open \(ShellQuoting.quote(unwrapped))"
        }

        if unwrapped.contains(".app/Contents/") || unwrapped.contains(".app/Contents/MacOS/") {
            if let range = unwrapped.range(of: ".app", options: .backwards) {
                let appPath = String(unwrapped[..<range.upperBound])
                return "open \(ShellQuoting.quote(appPath))"
            }
        }
        return trimmed
    }

    static func resolveCustomPath(_ command: String) -> String {
        let parts = command.split(separator: " ", maxSplits: 1,
                                  omittingEmptySubsequences: false)
        guard let first = parts.first, !first.isEmpty else { return command }
        let name = String(first)

        if name.contains("/") { return command }

        guard let appPath = PathStore.shared.findApp(named: name) else {
            return command
        }

        if parts.count == 1 {
            return "open \(ShellQuoting.quote(appPath))"
        } else {
            return "open -a \(ShellQuoting.quote(name)) \(parts[1])"
        }
    }

    static func isInteractive(_ command: String) -> Bool {
        let unquoted = stripQuotes(command)
        let hasPipe = unquoted.contains("|")
        let hasRedirect = unquoted.contains(">") || unquoted.contains("<")

        let firstPart = command.split(separator: "|").first.map(String.init) ?? command
        let trimmed = firstPart.trimmingCharacters(in: .whitespacesAndNewlines)

        let interactive = [
            "vim","vi","nano","emacs","top","htop","less","more",
            "ssh","telnet","ftp","sftp",
            "python","python3","ipython","irb","node",
            "mysql","psql","sqlite3",
            "gdb","lldb","bc","dc",
            "sh","bash","zsh","fish",
            "mail","mutt","pine"
        ]
        for cmd in interactive {
            if trimmed == cmd || trimmed.hasPrefix(cmd + " ") {
                if hasPipe || hasRedirect { return false }
                return true
            }
        }
        if unquoted.contains(" -i ") || unquoted.contains(" --interactive ") { return true }
        return false
    }

    private static func unwrapQuotes(_ s: String) -> String {
        guard s.count >= 2 else { return s }
        let first = s.first!
        let last = s.last!
        if (first == "\"" && last == "\"") || (first == "'" && last == "'") {
            let inner = String(s.dropFirst().dropLast())
            if !inner.contains(first) {
                return inner
            }
        }
        return s
    }

    private static func stripQuotes(_ s: String) -> String {
        var result = ""
        var inSingle = false
        var inDouble = false
        var escaped = false
        for ch in s {
            if escaped { escaped = false; continue }
            if ch == "\\" { escaped = true; continue }
            if ch == "'" && !inDouble { inSingle.toggle(); continue }
            if ch == "\"" && !inSingle { inDouble.toggle(); continue }
            if !inSingle && !inDouble { result.append(ch) }
        }
        return result
    }
}
