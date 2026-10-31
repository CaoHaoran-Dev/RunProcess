//
//  RunProcessTests.swift
//  RunProcessTests
//
//  Created by Haoran on 2026/9/13.
//

import XCTest

// 根据编译条件，动态决定测试哪个 Target
#if BETA
@testable import RunProcess_Preview
#else
@testable import RunProcess
#endif

// MARK: - CommandPreprocessor

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

    func testAppBundleTrailingSlashGetsOpenPrefix() {
        XCTAssertEqual(
            CommandPreprocessor.process("/Applications/Safari.app/"),
            "open /Applications/Safari.app/")
    }

    func testQuotedAppBundleUnwrapsThenQuotes() {
        XCTAssertEqual(
            CommandPreprocessor.process("\"/Applications/My App.app\""),
            "open \"/Applications/My App.app\"")
    }

    func testAppContentsPathExtractsAppBundle() {
        XCTAssertEqual(
            CommandPreprocessor.process("/Applications/Safari.app/Contents/MacOS/Safari"),
            "open /Applications/Safari.app")
    }

    func testAppContentsPathWithSpaceGetsQuoted() {
        XCTAssertEqual(
            CommandPreprocessor.process("/Applications/My App.app/Contents/MacOS/MyApp"),
            "open \"/Applications/My App.app\"")
    }

    func testOpenPrefixIsPreserved() {
        XCTAssertEqual(CommandPreprocessor.process("open ."), "open .")
    }

    func testStartPrefixIsPreserved() {
        XCTAssertEqual(CommandPreprocessor.process("start ."), "start .")
    }

    func testPlainCommandUnchanged() {
        XCTAssertEqual(CommandPreprocessor.process("ls -la"), "ls -la")
    }

    func testTrimsWhitespace() {
        XCTAssertEqual(CommandPreprocessor.process("  ls -la  "), "ls -la")
    }

    func testInteractiveDetected() {
        XCTAssertTrue(CommandPreprocessor.isInteractive("vim"))
        XCTAssertTrue(CommandPreprocessor.isInteractive("top"))
        XCTAssertTrue(CommandPreprocessor.isInteractive("python3 script.py"))
    }

    func testPipedInteractiveIsNotInteractive() {
        XCTAssertFalse(CommandPreprocessor.isInteractive("echo hi | vim"))
    }

    func testRedirectOnInteractiveIsNotInteractive() {
        XCTAssertFalse(CommandPreprocessor.isInteractive("top > out.txt"))
    }

    func testInteractiveWithRedirectInQuotesStillInteractive() {
        XCTAssertTrue(CommandPreprocessor.isInteractive("top \"a > b\""))
    }

    func testNonInteractiveCommand() {
        XCTAssertFalse(CommandPreprocessor.isInteractive("ls -la"))
        XCTAssertFalse(CommandPreprocessor.isInteractive("git status"))
    }
}

// MARK: - ShellQuoting

final class ShellQuotingTests: XCTestCase {

    func testPlainPathUnchanged() {
        XCTAssertEqual(ShellQuoting.quote("/usr/bin/ls"), "/usr/bin/ls")
    }

    func testPathWithSpaceQuoted() {
        XCTAssertEqual(ShellQuoting.quote("/Applications/My App.app"),
                       "\"/Applications/My App.app\"")
    }

    func testPathWithDoubleQuoteEscaped() {
        XCTAssertEqual(ShellQuoting.quote("/tmp/a\"b"), "\"/tmp/a\\\"b\"")
    }

    func testPathWithBackslashEscaped() {
        XCTAssertEqual(ShellQuoting.quote("/tmp/a\\b"), "\"/tmp/a\\\\b\"")
    }

    func testTildeAndAllowedCharsUnchanged() {
        XCTAssertEqual(ShellQuoting.quote("~/bin/tool-1.0_2@x+y"),
                       "~/bin/tool-1.0_2@x+y")
    }

    func testQuoteAllJoinsWithSpace() {
        XCTAssertEqual(ShellQuoting.quoteAll(["/a", "/b c"]),
                       "/a \"/b c\"")
    }
}

// MARK: - AppSettings

final class AppSettingsTests: XCTestCase {

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: AppSettings.Keys.defaultWorkingDirectory)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: AppSettings.Keys.defaultWorkingDirectory)
        super.tearDown()
    }

    func testEmptyWorkingDirectoryResolvesToHome() {
        AppSettings.defaultWorkingDirectoryRaw = ""
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        XCTAssertEqual(AppSettings.resolvedWorkingDirectory, home)
        XCTAssertTrue(AppSettings.isWorkingDirectoryValid)
        XCTAssertEqual(AppSettings.displayWorkingDirectory, "")
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

    func testDisplayWorkingDirectoryAbbreviatesHome() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        AppSettings.defaultWorkingDirectoryRaw = home + "/Projects"
        XCTAssertEqual(AppSettings.displayWorkingDirectory, "~/Projects")
    }
}

// MARK: - CommandHistory

final class CommandHistoryTests: XCTestCase {

    private let history = CommandHistory.shared

    override func setUp() {
        super.setUp()
        history.clearAll()
    }

    override func tearDown() {
        history.clearAll()
        super.tearDown()
    }

    func testRecordAndQuery() {
        history.record("git status")
        history.record("git status")
        history.record("git pull")

        let results = history.query(prefix: "git")
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results.first?.command, "git status")
        XCTAssertEqual(results.first?.count, 2)
    }

    func testRecordIncrementsCount() {
        history.record("ls")
        history.record("ls")
        history.record("ls")
        let all = history.getAll()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.command, "ls")
        XCTAssertEqual(all.first?.count, 3)
    }

    func testEmptyCommandIgnored() {
        history.record("   ")
        history.record("")
        XCTAssertEqual(history.count(), 0)
    }

    func testTrimmedCommandRecorded() {
        history.record("  git status  ")
        let all = history.getAll()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.command, "git status")
    }

    func testQueryByPrefixFilters() {
        history.record("git status")
        history.record("grep foo")
        history.record("ls")
        let results = history.query(prefix: "g")
        XCTAssertEqual(Set(results.map { $0.command }), ["git status", "grep foo"])
    }

    func testQueryEmptyPrefixReturnsEmpty() {
        history.record("ls")
        XCTAssertTrue(history.query(prefix: "").isEmpty)
        XCTAssertTrue(history.queryByFrecency(prefix: "").isEmpty)
    }

    func testSearchFuzzyMatches() {
        history.record("git status")
        history.record("git pull --rebase")
        history.record("ls -lah")

        let results = history.search("gst")
        XCTAssertTrue(results.contains { $0.command == "git status" })
        XCTAssertFalse(results.contains { $0.command == "ls -lah" })
    }

    func testSearchEmptyQueryReturnsRecent() {
        history.record("ls")
        history.record("pwd")
        let results = history.search("")
        XCTAssertFalse(results.isEmpty)
    }

    func testClearAll() {
        history.record("ls")
        XCTAssertEqual(history.count(), 1)
        history.clearAll()
        XCTAssertEqual(history.count(), 0)
    }
}

// MARK: - Suggestion

final class SuggestionTests: XCTestCase {

    func testEqualityIgnoresCountAndSubtitle() {
        let a = Suggestion(text: "ls", type: .history, historyCount: 1)
        let b = Suggestion(text: "ls", type: .history, historyCount: 5)
        XCTAssertEqual(a, b)

        let c = Suggestion(text: "gs", type: .alias, subtitle: "gs")
        let d = Suggestion(text: "gs", type: .alias, subtitle: "other")
        XCTAssertEqual(c, d)
    }

    func testEqualityConsidersTextAndType() {
        let a = Suggestion(text: "git", type: .history, historyCount: 1)
        let b = Suggestion(text: "git", type: .command)
        XCTAssertNotEqual(a, b)

        let c = Suggestion(text: "git", type: .command)
        let d = Suggestion(text: "gitx", type: .command)
        XCTAssertNotEqual(c, d)
    }

    func testHistoryBeatsCommand() {
        let h = Suggestion(text: "git", type: .history, historyCount: 3)
        let c = Suggestion(text: "git", type: .command)
        XCTAssertGreaterThan(h.priority, c.priority)
    }

    func testAliasHasHighestPriority() {
        let alias = Suggestion(text: "git status", type: .alias)
        let history = Suggestion(text: "git status", type: .history, historyCount: 100)
        let command = Suggestion(text: "git status", type: .command)
        let path = Suggestion(text: "/tmp/x", type: .path)

        XCTAssertGreaterThan(alias.priority, history.priority)
        XCTAssertGreaterThan(history.priority, command.priority)
        XCTAssertGreaterThan(command.priority, path.priority)
    }

    func testHistoryCountClampedInPriority() {
        let low = Suggestion(text: "x", type: .history, historyCount: -5)
        let high = Suggestion(text: "x", type: .history, historyCount: 999)
        XCTAssertEqual(low.historyCount, 0)
        XCTAssertEqual(high.historyCount, 100)
        XCTAssertLessThan(low.priority, high.priority)
    }

    func testIconNames() {
        XCTAssertEqual(Suggestion.SuggestionType.alias.iconName, "wand.and.stars")
        XCTAssertEqual(Suggestion.SuggestionType.history.iconName, "clock.arrow.circlepath")
        XCTAssertEqual(Suggestion.SuggestionType.command.iconName, "terminal")
        XCTAssertEqual(Suggestion.SuggestionType.path.iconName, "folder")
    }
}

// MARK: - ErrorClassifier

final class ErrorClassifierTests: XCTestCase {

    func testCommandNotFound() {
        let kind = ErrorClassifier.classify("zsh: command not found: foo")
        if case .commandNotFound(let name)? = kind {
            XCTAssertEqual(name, "foo")
        } else {
            XCTFail("Expected commandNotFound, got \(String(describing: kind))")
        }
    }

    func testPermissionDenied() {
        let kind = ErrorClassifier.classify("Permission denied")
        if case .permissionDenied? = kind {
        } else {
            XCTFail("Expected permissionDenied, got \(String(describing: kind))")
        }
    }

    func testFileNotFound() {
        let kind = ErrorClassifier.classify("No such file or directory")
        if case .fileNotFound? = kind {
        } else {
            XCTFail("Expected fileNotFound, got \(String(describing: kind))")
        }
    }

    func testNetwork() {
        let kind = ErrorClassifier.classify("Could not resolve host: example.com")
        if case .network? = kind {
        } else {
            XCTFail("Expected network, got \(String(describing: kind))")
        }
    }

    func testSyntax() {
        let kind = ErrorClassifier.classify("zsh: parse error near `}'")
        if case .syntax? = kind {
        } else {
            XCTFail("Expected syntax, got \(String(describing: kind))")
        }
    }

    func testNone() {
        XCTAssertNil(ErrorClassifier.classify("everything is fine"))
    }

    func testTTYError() {
        XCTAssertTrue(ErrorClassifier.isTTYError("stdin is not a tty"))
        XCTAssertTrue(ErrorClassifier.isTTYError("a terminal is required"))
        XCTAssertFalse(ErrorClassifier.isTTYError("command not found"))
    }

    func testANSIStrippedBeforeClassify() {
        let colored = "\u{1B}[31mzsh: command not found: foo\u{1B}[0m"
        let kind = ErrorClassifier.classify(colored)
        if case .commandNotFound(let name)? = kind {
            XCTAssertEqual(name, "foo")
        } else {
            XCTFail("Expected commandNotFound, got \(String(describing: kind))")
        }
    }
}

// MARK: - ANSIParser

final class ANSIParserTests: XCTestCase {

    func testStripANSIRemovesColorCodes() {
        let input = "\u{1B}[31mred\u{1B}[0m plain"
        XCTAssertEqual(ANSIParser.stripANSI(input), "red plain")
    }

    func testStripANSILeavesPlainText() {
        XCTAssertEqual(ANSIParser.stripANSI("hello world"), "hello world")
    }

    func testParseWithoutColorsReturnsStrippedText() {
        let input = "\u{1B}[32mgreen\u{1B}[0m"
        let attr = ANSIParser.parse(input)
        XCTAssertEqual(attr.string, "green")
    }
}

// MARK: - AliasStore

final class AliasExpansionTests: XCTestCase {

    private let store = AliasStore.shared
    private let testName = "__rp_test_alias__"

    override func setUp() {
        super.setUp()
        store.remove(name: testName)
    }

    override func tearDown() {
        store.remove(name: testName)
        super.tearDown()
    }

    func testExpandAliasReplacesFirstToken() {
        store.add(CommandAlias(name: testName, expansion: "echo hello"))
        XCTAssertEqual(store.expandAlias(in: testName), "echo hello")
    }

    func testExpandAliasKeepsArguments() {
        store.add(CommandAlias(name: testName, expansion: "echo hello"))
        XCTAssertEqual(store.expandAlias(in: "\(testName) world"), "echo hello world")
    }

    func testExpandAliasUnknownTokenUnchanged() {
        let input = "definitely-not-an-alias"
        XCTAssertEqual(store.expandAlias(in: input), input)
    }

    func testExpandAliasEmptyStringUnchanged() {
        XCTAssertEqual(store.expandAlias(in: ""), "")
    }
}

// MARK: - 版本特定测试 (条件编译)

final class AppEnvironmentTests: XCTestCase {
    #if BETA
    func testPreviewIsBeta() {
        XCTAssertTrue(AppEnvironment.isBeta)
    }

    func testPreviewAppSupportFolderName() {
        XCTAssertEqual(AppEnvironment.appSupportFolderName, "RunProcess-Beta")
    }

    func testPreviewCustomPathEnabledDefaultsTrue() {
        UserDefaults.standard.removeObject(forKey: "paths.customEnabled")
        XCTAssertTrue(AppSettings.customPathEnabled)
    }
    #else
    func testReleaseIsNotBeta() {
        XCTAssertFalse(AppEnvironment.isBeta)
    }

    func testReleaseAppSupportFolderName() {
        XCTAssertEqual(AppEnvironment.appSupportFolderName, "RunProcess")
    }

    func testReleaseCustomPathAlwaysEnabled() {
        XCTAssertTrue(AppSettings.customPathEnabled)
    }
    #endif
    
    // 两个版本共用的断言
    func testShellDefaultsToZsh() {
        XCTAssertEqual(AppSettings.resolvedShellPath, "/bin/zsh")
        XCTAssertTrue(AppSettings.isZshShell)
    }
}
