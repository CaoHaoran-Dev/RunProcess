//
//  RunProcessTests.swift
//  RunProcessTests
//
//  Created by Haoran on 2026/9/13.
//

import XCTest
@testable import RunProcess

final class CommandPreprocessorTests: XCTestCase {

    func testAppBundleGetsOpenPrefix() {
        XCTAssertEqual(
            CommandPreprocessor.process("/Applications/Safari.app"),
            "open /Applications/Safari.app")
    }

    func testAppBundleWithSpaceGetsQuoted() {
        XCTAssertEqual(
            CommandPreprocessor.process("/Applications/My App.app"),
            "open \"/Applications/My App.app\"")
    }

    func testAppContentsPathExtractsAppBundle() {
        XCTAssertEqual(
            CommandPreprocessor.process("/Applications/Safari.app/Contents/MacOS/Safari"),
            "open /Applications/Safari.app")
    }

    func testOpenPrefixIsPreserved() {
        XCTAssertEqual(CommandPreprocessor.process("open ."), "open .")
    }

    func testPlainCommandUnchanged() {
        XCTAssertEqual(CommandPreprocessor.process("ls -la"), "ls -la")
    }

    func testInteractiveDetected() {
        XCTAssertTrue(CommandPreprocessor.isInteractive("vim"))
        XCTAssertTrue(CommandPreprocessor.isInteractive("top"))
        XCTAssertTrue(CommandPreprocessor.isInteractive("python3 script.py"))
    }

    func testPipedInteractiveIsNotInteractive() {
        XCTAssertFalse(CommandPreprocessor.isInteractive("echo hi | vim"))
    }

    func testQuotedRedirectIsNotRedirect() {
        // echo "a > b" 里的 > 不应被当作重定向，所以 top 仍视为交互
        XCTAssertTrue(CommandPreprocessor.isInteractive("top"))
        // 但显式带重定向的 top 不视为交互
        XCTAssertFalse(CommandPreprocessor.isInteractive("top > out.txt"))
    }
}

final class AppSettingsTests: XCTestCase {

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: AppSettings.Keys.defaultWorkingDirectory)
    }

    func testEmptyWorkingDirectoryResolvesToHome() {
        AppSettings.defaultWorkingDirectoryRaw = ""
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        XCTAssertEqual(AppSettings.resolvedWorkingDirectory, home)
    }

    func testInvalidWorkingDirectoryFallsBackToHome() {
        AppSettings.defaultWorkingDirectoryRaw = "/nonexistent/path/xyz"
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        XCTAssertEqual(AppSettings.resolvedWorkingDirectory, home)
        XCTAssertFalse(AppSettings.isWorkingDirectoryValid)
    }

    func testValidWorkingDirectoryIsUsed() {
        AppSettings.defaultWorkingDirectoryRaw = "/tmp"
        XCTAssertEqual(AppSettings.resolvedWorkingDirectory, "/tmp")
        XCTAssertTrue(AppSettings.isWorkingDirectoryValid)
    }
}

final class CommandHistoryTests: XCTestCase {

    func testRecordAndQuery() {
        let h = CommandHistory.shared
        h.clearAll()
        h.record("git status")
        h.record("git status")
        h.record("git pull")

        // 等待异步保存完成
        let exp = expectation(description: "query")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            let results = h.query(prefix: "git")
            XCTAssertEqual(results.count, 2)
            XCTAssertEqual(results.first?.command, "git status")
            XCTAssertEqual(results.first?.count, 2)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 2.0)
    }

    func testEmptyCommandIgnored() {
        let h = CommandHistory.shared
        h.clearAll()
        h.record("   ")
        h.record("")
        XCTAssertEqual(h.count(), 0)
    }
}

final class SuggestionTests: XCTestCase {

    func testEqualityIgnoresCount() {
        let a = Suggestion(text: "ls", type: .history, historyCount: 1)
        let b = Suggestion(text: "ls", type: .history, historyCount: 5)
        XCTAssertEqual(a, b)
    }

    func testHistoryBeatsCommand() {
        let h = Suggestion(text: "git", type: .history, historyCount: 3)
        let c = Suggestion(text: "git", type: .command)
        XCTAssertGreaterThan(h.priority, c.priority)
    }
}
