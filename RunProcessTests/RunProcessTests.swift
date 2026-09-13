//
//  RunProcessTests.swift
//  RunProcessTests
//
//  Created by Haoran on 2026/8/26.
//

import XCTest
@testable import RunProcess

// MARK: - Test Environment Assumptions
//
// 本测试套件假设运行在"纯净 macOS 原始系统"上：
// - 只使用系统自带命令（/bin, /usr/bin）
// - 不假设 git / docker / homebrew / 第三方工具存在
// - 不假设用户目录、Desktop、Applications 有特定内容
// - 涉及 GUI、系统 App、sudo 的用例一律 skip

// MARK: - Test Helpers

extension ProcessInfo {
    static var isRunningOnCI: Bool {
        return ProcessInfo.processInfo.environment["CI"] == "true"
    }
}

/// 系统 guaranteed 存在的命令（纯净 macOS 一定在）
enum SystemCommand {
    static let echo = "/bin/echo"
    static let pwd = "/bin/pwd"
    static let sleep = "/bin/sleep"
    static let seq = "/usr/bin/seq"
    static let trueCmd = "/usr/bin/true"
    static let falseCmd = "/usr/bin/false"
}

/// 临时目录辅助：每个测试自建目录，测完清理
final class TempDirectory {
    let url: URL
    
    init() throws {
        let name = "RunProcessTests-\(UUID().uuidString)"
        url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
    
    func createFile(_ name: String) throws {
        let fileURL = url.appendingPathComponent(name)
        try "test".write(to: fileURL, atomically: true, encoding: .utf8)
    }
    
    func createDirectory(_ name: String) throws {
        let dirURL = url.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
    }
    
    func cleanup() {
        try? FileManager.default.removeItem(at: url)
    }
    
    deinit {
        cleanup()
    }
}

// MARK: - CommandHistory Tests

final class CommandHistoryTests: XCTestCase {
    
    var history: CommandHistory!
    
    override func setUp() {
        super.setUp()
        history = CommandHistory()
        history.clearAll()
    }
    
    override func tearDown() {
        history.clearAll()
        history = nil
        super.tearDown()
    }
    
    func testRecordAndQuery() {
        history.record("ls -la")
        let results = history.query(prefix: "ls")
        
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.command, "ls -la")
        XCTAssertEqual(results.first?.count, 1)
    }
    
    func testRecordIncrementsCount() {
        history.record("git status")
        history.record("git status")
        let results = history.query(prefix: "git")
        
        XCTAssertEqual(results.first?.count, 2)
    }
    
    func testQueryReturnsSortedByFrequency() {
        history.record("git status")
        history.record("git status")
        history.record("git log")
        history.record("git log")
        history.record("git log")
        history.record("grep test")
        
        let results = history.query(prefix: "git")
        
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0].command, "git log")
        XCTAssertEqual(results[1].command, "git status")
    }
    
    func testQueryPrefixMatching() {
        history.record("docker ps")
        history.record("docker-compose up")
        history.record("git status")
        
        let results = history.query(prefix: "docker")
        
        XCTAssertEqual(results.count, 2)
        XCTAssertTrue(results.contains { $0.command == "docker ps" })
        XCTAssertTrue(results.contains { $0.command == "docker-compose up" })
    }
    
    func testClearAll() {
        history.record("test command")
        XCTAssertGreaterThan(history.count(), 0)
        
        history.clearAll()
        
        XCTAssertEqual(history.count(), 0)
    }
    
    func testGetAll() {
        history.record("cmd1")
        history.record("cmd2")
        
        let all = history.getAll()
        
        XCTAssertEqual(all.count, 2)
    }
    
    func testMaxEntriesLimit() {
        for i in 0..<550 {
            history.record("command_\(i)")
        }
        
        XCTAssertLessThanOrEqual(history.count(), 500)
    }
    
    func testEmptyQuery() {
        let results = history.query(prefix: "")
        XCTAssertTrue(results.isEmpty)
    }
    
    func testCaseSensitiveQuery() {
        history.record("GitStatus")
        history.record("gitstatus")
        
        let results = history.query(prefix: "git")
        
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.command, "gitstatus")
    }
    
    func testRecordEmptyStringIsIgnored() {
        history.record("")
        history.record("   ")
        history.record("\n")
        
        XCTAssertEqual(history.count(), 0)
    }
    
    func testRecordTrimsWhitespace() {
        history.record("  ls -la  ")
        let results = history.query(prefix: "ls")
        
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.command, "ls -la")
    }
    
    // 回归测试：写后立即读必须一致（修复异步写 bug）
    func testRecordThenQueryIsImmediatelyConsistent() {
        history.record("git status")
        let results = history.query(prefix: "git")
        XCTAssertEqual(results.count, 1, "record 后立即 query 应该能看到结果")
    }
    
    func testClearAllThenQueryIsImmediatelyEmpty() {
        history.record("cmd1")
        history.record("cmd2")
        history.clearAll()
        
        XCTAssertEqual(history.count(), 0)
        XCTAssertTrue(history.query(prefix: "cmd").isEmpty)
    }
}

// MARK: - Suggestion Tests

final class SuggestionTests: XCTestCase {
    
    func testSuggestionCreation() {
        let suggestion = Suggestion(text: "ls -la", type: .command)
        
        XCTAssertEqual(suggestion.text, "ls -la")
        XCTAssertEqual(suggestion.type, .command)
        XCTAssertEqual(suggestion.type.iconName, "terminal")
    }
    
    func testSuggestionPriority() {
        let historySuggestion = Suggestion(text: "git", type: .history, historyCount: 5)
        let commandSuggestion = Suggestion(text: "git", type: .command)
        
        XCTAssertGreaterThan(historySuggestion.priority, commandSuggestion.priority)
    }
    
    func testSuggestionEquality() {
        let s1 = Suggestion(text: "test", type: .command)
        let s2 = Suggestion(text: "test", type: .command)
        let s3 = Suggestion(text: "test", type: .history)
        
        XCTAssertEqual(s1, s2)
        XCTAssertNotEqual(s1, s3)
    }
    
    func testHistoryCountPriorityClamping() {
        let suggestion = Suggestion(text: "git", type: .history, historyCount: 200)
        // clamp 到 100，priority = 300 + 100 = 400
        XCTAssertEqual(suggestion.priority, 400)
    }
    
    func testHistoryCountNegativeClamping() {
        let suggestion = Suggestion(text: "git", type: .history, historyCount: -5)
        // clamp 到 0，priority = 300 + 0 = 300
        XCTAssertEqual(suggestion.priority, 300)
    }
    
    func testSuggestionIdentifiable() {
        let s1 = Suggestion(text: "test", type: .command)
        let s2 = Suggestion(text: "test", type: .command)
        
        // 每个实例应该有唯一的 id
        XCTAssertNotEqual(s1.id, s2.id)
    }
    
    func testSuggestionTypeIconNames() {
        XCTAssertEqual(Suggestion.SuggestionType.history.iconName, "clock.arrow.circlepath")
        XCTAssertEqual(Suggestion.SuggestionType.command.iconName, "terminal")
        XCTAssertEqual(Suggestion.SuggestionType.path.iconName, "folder")
    }
}

// MARK: - CommandSuggester Tests
//
// 注意：以下用例只验证 CommandSuggester 在"纯净系统"下不会崩溃、
// 且对明显的边界输入返回合理结果。
// 不验证"系统里恰好有 git/docker"这类依赖环境的行为。

final class CommandSuggesterTests: XCTestCase {
    
    var suggester: CommandSuggester!
    
    override func setUp() {
        super.setUp()
        suggester = CommandSuggester()
    }
    
    override func tearDown() {
        suggester = nil
        super.tearDown()
    }
    
    func testSuggestEmptyInputReturnsEmpty() {
        let expectation = XCTestExpectation(description: "Empty input")
        
        suggester.suggest(for: "") { suggestions in
            XCTAssertTrue(suggestions.isEmpty)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testSuggestWhitespaceInputReturnsEmpty() {
        let expectation = XCTestExpectation(description: "Whitespace input")
        
        suggester.suggest(for: "   ") { suggestions in
            XCTAssertTrue(suggestions.isEmpty)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testSuggestNeverCrashesOnArbitraryInput() {
        let expectation = XCTestExpectation(description: "Arbitrary input")
        
        // 对随机前缀不崩溃即可
        suggester.suggest(for: "zzzz_nonexistent_command_zzzz") { suggestions in
            XCTAssertNotNil(suggestions)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testSuggestPathInTempDirectory() throws {
        let temp = try TempDirectory()
        defer { temp.cleanup() }
        try temp.createFile("alpha.txt")
        try temp.createFile("alpine.txt")
        try temp.createFile("beta.txt")
        
        let prefix = temp.url.path + "/alp"
        let expectation = XCTestExpectation(description: "Path suggestion")
        
        suggester.suggest(for: prefix) { suggestions in
            let texts = suggestions.map { $0.text }
            XCTAssertTrue(texts.contains { $0.contains("alpha.txt") },
                          "应该建议 alpha.txt，实际: \(texts)")
            XCTAssertTrue(texts.contains { $0.contains("alpine.txt") },
                          "应该建议 alpine.txt，实际: \(texts)")
            XCTAssertFalse(texts.contains { $0.contains("beta.txt") },
                           "不应该建议 beta.txt")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testSuggestPathEscapesSpaces() throws {
        let temp = try TempDirectory()
        defer { temp.cleanup() }
        try temp.createDirectory("My Folder")
        
        let prefix = temp.url.path + "/My"
        let expectation = XCTestExpectation(description: "Path with space")
        
        suggester.suggest(for: prefix) { suggestions in
            let texts = suggestions.map { $0.text }
            XCTAssertTrue(texts.contains { $0.contains("My\\ Folder") },
                          "路径中的空格应该被转义，实际: \(texts)")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testSuggestPathWithTilde() throws {
        let expectation = XCTestExpectation(description: "Tilde path")
        
        // ~/ 前缀应该展开，不崩溃
        suggester.suggest(for: "~/") { suggestions in
            XCTAssertNotNil(suggestions)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
}

// MARK: - CommandViewModel Tests
//
// 注意：当前生产代码将 processCommand / isInteractiveCommand 标记为 private，
// 测试无法直接访问。依赖这两个方法的用例已被移除（见文件末尾说明）。
// 以下用例只验证 CommandViewModel 的公开 API。

final class CommandViewModelTests: XCTestCase {
    
    var viewModel: CommandViewModel!
    
    override func setUp() {
        super.setUp()
        viewModel = CommandViewModel()
    }
    
    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }
    
    // MARK: - Output 管理
    
    func testClearOutput() {
        viewModel.outputText = "some output"
        viewModel.clearOutput()
        XCTAssertTrue(viewModel.outputText.isEmpty)
    }
    
    // MARK: - 建议列表导航
    
    func testCloseSuggestions() {
        viewModel.suggestions = [Suggestion(text: "test", type: .command)]
        viewModel.selectedIndex = 0
        
        viewModel.closeSuggestions()
        
        XCTAssertTrue(viewModel.suggestions.isEmpty)
        XCTAssertEqual(viewModel.selectedIndex, 0)
    }
    
    func testSelectNextSuggestion() {
        viewModel.suggestions = [
            Suggestion(text: "cmd1", type: .command),
            Suggestion(text: "cmd2", type: .command),
            Suggestion(text: "cmd3", type: .command)
        ]
        viewModel.selectedIndex = 0
        
        viewModel.selectNext()
        XCTAssertEqual(viewModel.selectedIndex, 1)
        
        viewModel.selectNext()
        XCTAssertEqual(viewModel.selectedIndex, 2)
        
        viewModel.selectNext()
        XCTAssertEqual(viewModel.selectedIndex, 0)
    }
    
    func testSelectPreviousSuggestion() {
        viewModel.suggestions = [
            Suggestion(text: "cmd1", type: .command),
            Suggestion(text: "cmd2", type: .command)
        ]
        viewModel.selectedIndex = 0
        
        viewModel.selectPrevious()
        XCTAssertEqual(viewModel.selectedIndex, 1)
    }
    
    func testSelectPreviousFromMiddle() {
        viewModel.suggestions = [
            Suggestion(text: "cmd1", type: .command),
            Suggestion(text: "cmd2", type: .command),
            Suggestion(text: "cmd3", type: .command)
        ]
        viewModel.selectedIndex = 1
        
        viewModel.selectPrevious()
        XCTAssertEqual(viewModel.selectedIndex, 0)
    }
    
    func testSelectNextWithEmptyListDoesNotCrash() {
        viewModel.suggestions = []
        viewModel.selectedIndex = 0
        
        viewModel.selectNext()
        XCTAssertEqual(viewModel.selectedIndex, 0)
    }
    
    func testSelectPreviousWithEmptyListDoesNotCrash() {
        viewModel.suggestions = []
        viewModel.selectedIndex = 0
        
        viewModel.selectPrevious()
        XCTAssertEqual(viewModel.selectedIndex, 0)
    }
    
    func testConfirmSelectionUpdatesInput() {
        viewModel.suggestions = [
            Suggestion(text: "selected command", type: .command)
        ]
        viewModel.selectedIndex = 0
        viewModel.inputText = "test"
        
        viewModel.confirmSelection()
        
        XCTAssertEqual(viewModel.inputText, "selected command")
        XCTAssertTrue(viewModel.suggestions.isEmpty)
    }
    
    // MARK: - 历史导航
    
    func testResetHistoryNavigation() {
        viewModel.resetHistoryNavigation()
        // 只是确保不崩溃
        XCTAssertTrue(true)
    }
    
    func testNavigateHistoryUpWithEmptyHistory() {
        // 新建的 ViewModel 内部 history 是空的，但可能已有磁盘记录
        // 这里只验证不崩溃
        _ = viewModel.navigateHistoryUp()
        XCTAssertTrue(true)
    }
    
    func testNavigateHistoryDownWithEmptyHistory() {
        _ = viewModel.navigateHistoryDown()
        XCTAssertTrue(true)
    }
    
    // MARK: - 执行前状态
    
    func testInitialState() {
        XCTAssertTrue(viewModel.inputText.isEmpty)
        XCTAssertTrue(viewModel.outputText.isEmpty)
        XCTAssertFalse(viewModel.isRunning)
        XCTAssertFalse(viewModel.canCancel)
        XCTAssertTrue(viewModel.suggestions.isEmpty)
        XCTAssertEqual(viewModel.selectedIndex, 0)
    }
}

// MARK: - CommandExecutor Tests
//
// 只使用系统 guaranteed 存在的命令。

final class CommandExecutorTests: XCTestCase {
    
    var executor: CommandExecutor!
    
    override func setUp() {
        super.setUp()
        executor = CommandExecutor.shared
    }
    
    override func tearDown() {
        executor.cancelCurrentTask()
        super.tearDown()
    }
    
    func testExecuteSimpleCommand() {
        let expectation = XCTestExpectation(description: "Simple echo")
        
        executor.execute("\(SystemCommand.echo) 'Hello World'", timeout: 5.0) { result in
            switch result {
            case .success(let output):
                XCTAssertEqual(output, "Hello World")
            case .failure(let error):
                XCTFail("命令执行失败: \(error.localizedDescription)")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testExecuteCommandWithMultipleLines() {
        let expectation = XCTestExpectation(description: "Multi-line output")
        
        executor.execute("\(SystemCommand.echo) 'line1' && \(SystemCommand.echo) 'line2'",
                         timeout: 5.0) { result in
            switch result {
            case .success(let output):
                let lines = output.components(separatedBy: "\n")
                XCTAssertTrue(lines.count >= 2)
            case .failure(let error):
                XCTFail("命令执行失败: \(error.localizedDescription)")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testExecuteCommandWithNonZeroExit() {
        let expectation = XCTestExpectation(description: "Non-zero exit")
        
        executor.execute(SystemCommand.falseCmd, timeout: 5.0) { result in
            switch result {
            case .success:
                XCTFail("false 命令应该返回非零退出码")
            case .failure:
                break // 预期行为
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testExecuteCommandWithZeroExit() {
        let expectation = XCTestExpectation(description: "Zero exit")
        
        executor.execute(SystemCommand.trueCmd, timeout: 5.0) { result in
            switch result {
            case .success:
                break // 预期行为
            case .failure(let error):
                XCTFail("true 命令应该成功: \(error.localizedDescription)")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testExecuteCommandWorkingDirectoryIsHome() {
        let expectation = XCTestExpectation(description: "Working directory")
        
        executor.execute(SystemCommand.pwd, timeout: 5.0) { result in
            switch result {
            case .success(let output):
                let home = FileManager.default.homeDirectoryForCurrentUser.lastPathComponent
                let trimmed = output.trimmingCharacters(in: .newlines)
                XCTAssertTrue(trimmed.contains(home),
                              "pwd 应该包含主目录名 '\(home)'，实际: \(trimmed)")
            case .failure(let error):
                XCTFail("命令执行失败: \(error.localizedDescription)")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testExecuteLongOutput() {
        let expectation = XCTestExpectation(description: "Long output")
        
        executor.execute("\(SystemCommand.seq) 1 1000", timeout: 10.0) { result in
            switch result {
            case .success(let output):
                let lines = output.components(separatedBy: "\n")
                XCTAssertGreaterThanOrEqual(lines.count, 500)
            case .failure(let error):
                XCTFail("命令执行失败: \(error.localizedDescription)")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 15.0)
    }
    
    func testExecuteCommandWithSpecialCharacters() {
        let expectation = XCTestExpectation(description: "Special chars")
        
        executor.execute("\(SystemCommand.echo) 'Hello & World'", timeout: 5.0) { result in
            switch result {
            case .success(let output):
                XCTAssertEqual(output, "Hello & World")
            case .failure(let error):
                XCTFail("命令执行失败: \(error.localizedDescription)")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testExecuteCommandWithQuotes() {
        let expectation = XCTestExpectation(description: "Quotes")
        
        executor.execute("\(SystemCommand.echo) \"Hello 'World'\"", timeout: 5.0) { result in
            switch result {
            case .success(let output):
                XCTAssertTrue(output.contains("Hello") && output.contains("World"))
            case .failure(let error):
                XCTFail("命令执行失败: \(error.localizedDescription)")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testExecuteCommandWithEnvironmentVariable() {
        let expectation = XCTestExpectation(description: "Environment variable")
        
        executor.execute("\(SystemCommand.echo) $HOME", timeout: 5.0) { result in
            switch result {
            case .success(let output):
                let home = FileManager.default.homeDirectoryForCurrentUser.path
                XCTAssertTrue(output.contains(home))
            case .failure(let error):
                XCTFail("命令执行失败: \(error.localizedDescription)")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    // MARK: - Timeout 与 Cancel
    //
    // 这两个用例在纯净系统 + CI 环境下都可能因调度时序不稳定，
    // 单独隔离到一个时间窗口较宽松的测试里。
    
    func testExecuteCommandTimeout() {
        let expectation = XCTestExpectation(description: "Timeout")
        
        executor.execute("\(SystemCommand.sleep) 5", timeout: 1.0) { result in
            switch result {
            case .success:
                XCTFail("sleep 5 应该在 1 秒超时")
            case .failure(let error):
                XCTAssertNotNil(error)
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testCancelCurrentTask() {
        let expectation = XCTestExpectation(description: "Cancel")
        
        executor.execute("\(SystemCommand.sleep) 10", timeout: 10.0) { result in
            if case .failure = result {
                // 预期行为
            } else {
                XCTFail("任务应该被取消")
            }
            expectation.fulfill()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.executor.cancelCurrentTask()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
}

// MARK: - Integration Tests
//
// 只保留不依赖 GUI、系统 App、sudo 的端到端用例。

final class RunProcessIntegrationTests: XCTestCase {
    
    var viewModel: CommandViewModel!
    
    override func setUp() {
        super.setUp()
        viewModel = CommandViewModel()
    }
    
    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }
    
    func testEndToEndSimpleCommand() {
        let expectation = XCTestExpectation(description: "End to end")
        
        viewModel.inputText = "\(SystemCommand.echo) 'Integration Test'"
        viewModel.executeCommand { output in
            XCTAssertTrue(output.contains("Integration Test"))
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testEndToEndNonZeroExitShowsError() {
        let expectation = XCTestExpectation(description: "Non-zero exit shows error")
        
        viewModel.inputText = SystemCommand.falseCmd
        viewModel.executeCommand { output in
            // 非零退出应该显示错误信息
            XCTAssertFalse(output.isEmpty)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testInteractiveCommandRejection() {
        let expectation = XCTestExpectation(description: "Interactive rejection")
        
        viewModel.inputText = "vim"
        viewModel.executeCommand { output in
            // 应该输出错误信息，而不是真的启动 vim
            XCTAssertFalse(output.isEmpty, "交互式命令应该被拒绝并输出提示")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testDotAppPathConversion() throws {
        // 该用例验证 .app 路径被自动转换，但当前生产代码的 processCommand
        // 是 private，无法直接断言。改为通过 executeCommand 的副作用间接验证：
        // 输入 .app 路径后，viewModel.inputText 应该被改写成 "open ..."
        // 但 .app 文件可能不存在，命令会失败，这不影响路径转换本身。
        
        let appPath = "/System/Applications/Calculator.app"
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: appPath, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw XCTSkip("Calculator.app 不存在，跳过测试")
        }
        
        viewModel.inputText = appPath
        // 触发路径处理：调用 executeCommand，其内部会改写 inputText
        let expectation = XCTestExpectation(description: "Path conversion")
        viewModel.executeCommand { _ in
            // 执行后 inputText 应该已经变成 "open ..." 形式
            XCTAssertTrue(self.viewModel.inputText.hasPrefix("open "),
                          "inputText 应该被改写为 open 开头，实际: \(self.viewModel.inputText)")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testSudoIsSkippedOnPureSystem() throws {
        // 纯净 macOS 系统没有配置 sudo 免密，也不应有测试密码。
        // 这个用例无条件 skip，保留占位以便未来在专用测试机上启用。
        throw XCTSkip("sudo 测试需要真实密码，纯净系统上跳过")
    }
}

// MARK: - Performance Tests

final class RunProcessPerformanceTests: XCTestCase {
    
    var history: CommandHistory!
    
    override func setUp() {
        super.setUp()
        history = CommandHistory()
        history.clearAll()
    }
    
    override func tearDown() {
        history.clearAll()
        history = nil
        super.tearDown()
    }
    
    func testHistoryRecordPerformance() {
        measure {
            for i in 0..<500 {
                history.record("command_\(i)")
            }
            history.clearAll()
        }
    }
    
    func testHistoryQueryPerformance() {
        for i in 0..<500 {
            history.record("command_\(i)")
        }
        
        measure {
            _ = history.query(prefix: "command_1")
        }
    }
}

// MARK: - Removed Tests (需要改生产代码才能恢复)
//
// 以下用例在"不改生产代码"的前提下无法正确测试，已从套件中移除：
//
// 1. CommandViewModelTests 中所有 processCommandForTesting 相关用例
//    原因：processCommand 是 private，测试通过复制一份实现来测，
//    但副本与生产代码可能漂移，且实际上没有测试生产代码。
//    恢复方式：将 processCommand 改为 internal，测试直接调用。
//
// 2. CommandViewModelTests 中所有 isInteractiveCommandForTesting 相关用例
//    原因：同上，isInteractiveCommand 是 private。
//    恢复方式：同上。
//
// 3. CommandSuggesterTests 中所有依赖具体系统命令的用例
//    （如 testSuggestFromHistory、testSuggestSystemCommands）
//    原因：CommandSuggester 内部 new 了自己的 CommandHistory，
//    外部 record 的历史它看不到；系统命令是否存在也依赖环境。
//    恢复方式：让 CommandSuggester 接受外部注入的 CommandHistory。
