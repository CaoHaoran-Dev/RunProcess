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

    /// 快捷指令预设的 sudo 状态。ContentView 监听它并同步到本地 useSudo，
    /// 消费后立即复位为 false。
    @Published var pendingSudoRequest: Bool = false

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

                    // 交互式命令 / TTY 相关错误统一拦截（关键词集中在 ErrorClassifier）
                    if ErrorClassifier.isTTYError(rawError) {
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

    // MARK: - 错误解释

    /// 通用错误解释：把原始报错归类，追加人类可读的说明。
    /// 匹配不到任何已知类别时返回空串，保留原始报错。
    private func explainError(_ rawError: String) -> String {
        guard AppSettings.explainErrors else { return "" }

        switch ErrorClassifier.classify(rawError) {
        case .commandNotFound(let name):
            return String(format: NSLocalizedString("error.explain.not.found", comment: ""), name)
        case .permissionDenied:
            return NSLocalizedString("error.explain.permission", comment: "")
        case .fileNotFound:
            return NSLocalizedString("error.explain.no.file", comment: "")
        case .sudoRequired:
            return NSLocalizedString("error.explain.sudo.required", comment: "")
        case .network:
            return NSLocalizedString("error.explain.network", comment: "")
        case .disk:
            return NSLocalizedString("error.explain.disk", comment: "")
        case .syntax:
            return NSLocalizedString("error.explain.syntax", comment: "")
        case .none:
            return ""
        }
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

// MARK: - 纯函数：错误分类

/// 把常见 shell 报错归类。
///
/// 判断顺序从"最具体"到"最宽泛"，避免 "No such file or directory"
/// 这类既可能指命令、又可能指文件的歧义。
///
/// 匹配前统一剥离 ANSI 转义序列：zsh 插件（语法高亮、autosuggestions 等）
/// 可能给报错着色，转义序列会插在关键词中间导致 `contains` 失配。
enum ErrorClassifier {

    enum Kind {
        case commandNotFound(String)
        case permissionDenied
        case fileNotFound
        case sudoRequired
        case network
        case disk
        case syntax
    }

    /// TTY / 交互式错误，单独判断，供执行层拦截。
    static func isTTYError(_ text: String) -> Bool {
        let t = ANSIParser.stripANSI(text).lowercased()
        let needles = [
            "not a terminal",
            "requires a tty",
            "a terminal is required",
            "no tty present",
            "stdin is not a tty",
            "inappropriate ioctl",
            "can't be run in this context",
            "cannot be run in this context",
            "unable to open /dev/tty",
        ]
        return needles.contains { t.contains($0) }
    }

    static func classify(_ text: String) -> Kind? {
        let t = ANSIParser.stripANSI(text).lowercased()

        // 1. 命令找不到（覆盖普通 shell 与 eval 上下文）
        //    zsh: command not found: foo
        //    (eval):1: command not found: foo
        //    bash: foo: command not found
        //    fish: Unknown command: foo
        //    sh: 1: foo: not found
        if t.contains("command not found")
            || t.contains("unknown command")
            || t.contains("not found in path")
            || (t.contains("not found") && (t.contains("command") || t.contains("(eval)")))
        {
            return .commandNotFound(extractCommandName(from: t))
        }

        // 2. 权限（放在文件不存在之前，因为 "Operation not permitted" 也常伴随路径）
        if t.contains("permission denied")
            || t.contains("operation not permitted")
            || t.contains("access denied")
            || t.contains("not authorized")
            || t.contains("must be owner")
            || t.contains("eacces")
        {
            return .permissionDenied
        }

        // 3. 需要 root
        if t.contains("must be run as root")
            || t.contains("requires root")
            || t.contains("try again as root")
            || t.contains("you need to be root")
            || t.contains("superuser")
            || t.contains("are you root")
            || t.contains("not permitted")
        {
            return .sudoRequired
        }

        // 4. 文件 / 目录不存在
        if t.contains("no such file or directory")
            || t.contains("does not exist")
            || t.contains("cannot find")
            || t.contains("can't find")
            || t.contains("unable to find")
            || t.contains("no such file")
        {
            return .fileNotFound
        }

        // 5. 网络
        if t.contains("could not resolve host")
            || t.contains("name or service not known")
            || t.contains("temporary failure in name resolution")
            || t.contains("connection refused")
            || t.contains("connection timed out")
            || t.contains("connection reset")
            || t.contains("network is unreachable")
            || t.contains("no route to host")
            || t.contains("could not connect")
            || t.contains("failed to connect")
        {
            return .network
        }

        // 6. 磁盘 / 文件系统
        if t.contains("no space left")
            || t.contains("disk full")
            || t.contains("read-only file system")
            || t.contains("quota exceeded")
            || t.contains("input/output error")
            || t.contains("structure needs cleaning")
        {
            return .disk
        }

        // 7. Shell 语法
        if t.contains("parse error")
            || t.contains("syntax error")
            || t.contains("bad substitution")
            || t.contains("unmatched")
            || t.contains("unexpected token")
            || t.contains("unexpected end of file")
            || t.contains("unexpected eof")
            || t.contains("command substitution")
            || t.contains("unbound variable")
        {
            return .syntax
        }

        return nil
    }

    /// 从 "command not found" 类报错里提取命令名。
    ///
    /// 正则优先，覆盖各 shell 的常见措辞；token 扫描兜底，处理正则匹配不到的
    /// 极端格式（如用户自定义的 fish_command_not_found）。
    /// 提取失败时返回 "unknown"。
    private static func extractCommandName(from text: String) -> String {
        // 按行处理，优先看包含关键词的那一行
        let lines = text.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        let target = lines.first {
            let l = $0.lowercased()
            return l.contains("command not found")
                || l.contains("unknown command")
                || l.contains("not found in path")
                || l.contains("not found")
        } ?? text

        // 正则模式：关键词之后是命令名（zsh / fish / eval）
        //   zsh: command not found: foo
        //   (eval):1: command not found: foo
        //   fish: Unknown command: foo
        //   sh: 1: foo: not found  —— 这种是"关键词之前"，见下一条
        let afterPatterns: [String] = [
            #"(?:command not found|not found|unknown command)\s*:\s*(\S+)"#,
        ]
        // 正则模式：关键词之前是命令名（bash / sh）
        //   bash: foo: command not found
        //   sh: 1: foo: not found
        let beforePatterns: [String] = [
            #"(\S+)\s*:\s*(?:command not found|not found)"#,
        ]

        for pattern in afterPatterns + beforePatterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                  let match = regex.firstMatch(in: target, range: NSRange(target.startIndex..., in: target)),
                  match.numberOfRanges > 1,
                  let range = Range(match.range(at: 1), in: target) else { continue }

            let candidate = String(target[range])
                .trimmingCharacters(in: CharacterSet(charactersIn: ":\"'`"))
            if isLikelyCommandName(candidate) {
                return candidate
            }
        }

        // 兜底：token 扫描，跳过 shell 名、行号、关键词、纯标点
        let separators: [Character] = [":", " ", "\t", "`", "'", "\""]
        let tokens = target.split(whereSeparator: { separators.contains($0) })
            .map(String.init)
            .filter { !$0.isEmpty }

        let keywordIndex = tokens.firstIndex {
            let l = $0.lowercased()
            return l == "command"
                || l == "unknown"
                || l == "not"
                || l == "found"
                || l == "path"
        }

        if let idx = keywordIndex {
            // "command not found: foo" —— 命令名在关键词之后
            let after = tokens[(idx + 1)...]
            if let candidate = after.first(where: { isLikelyCommandName($0) }) {
                return candidate
            }
            // "bash: foo: command not found" —— 命令名在关键词之前
            let before = tokens[..<idx]
            if let candidate = before.last(where: { isLikelyCommandName($0) }) {
                return candidate
            }
        }

        // 最后兜底：第一个像命令名的 token
        for token in tokens {
            if isLikelyCommandName(token) { return token }
        }
        return "unknown"
    }

    private static func isLikelyCommandName(_ token: String) -> Bool {
        guard !token.isEmpty else { return false }
        let excluded: Set<String> = [
            // shell 名
            "zsh", "bash", "sh", "fish", "dash", "ksh", "csh", "tcsh",
            // 关键词
            "command", "unknown", "not", "found", "path",
            "no", "such", "file", "or", "directory",
            // zsh 内部上下文前缀
            "(eval)", "(command)", "(anon)", "eval", "command", "anon",
        ]
        if excluded.contains(token.lowercased()) { return false }
        if Int(token) != nil { return false }
        // 排除纯标点
        if token.allSatisfy({ !$0.isLetter && !$0.isNumber && $0 != "_" && $0 != "-" && $0 != "." }) {
            return false
        }
        return true
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
