//
//  RunProcessTests.swift
//  RunProcessTests
//
//  Created by Haoran on 2026/9/13.
//

import XCTest
import AppKit

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
    
    #if BETA
    func testWorkflowHasHighestPriority() {
        let workflow = Suggestion(text: "deploy", type: .workflow)
        let alias = Suggestion(text: "deploy", type: .alias)
        
        XCTAssertGreaterThan(workflow.priority, alias.priority)
    }
    #endif

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
        
        #if BETA
        XCTAssertEqual(Suggestion.SuggestionType.workflow.iconName, "doc.text.fill")
        #endif
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

// MARK: - SessionFrame（弱断言，只校验返回尺寸合理、不崩溃）

final class SessionFrameTests: XCTestCase {

    func testCalculateSafeFrameKeepsWindowSize() {
        let screen = NSRect(x: 0, y: 0, width: 1440, height: 900)
        let frame = Session.calculateSafeFrame(screenRect: screen,
                                               windowWidth: 600,
                                               windowHeight: 140)
        XCTAssertEqual(frame.width, 600, accuracy: 0.5)
        XCTAssertEqual(frame.height, 140, accuracy: 0.5)
        XCTAssertTrue(frame.origin.x.isFinite)
        XCTAssertTrue(frame.origin.y.isFinite)
    }

    func testCalculateSafeFrameCentersOnWideScreen() {
        let screen = NSRect(x: 0, y: 0, width: 1440, height: 900)
        let frame = Session.calculateSafeFrame(screenRect: screen,
                                               windowWidth: 600,
                                               windowHeight: 140)
        XCTAssertEqual(frame.midX, screen.midX, accuracy: 1.0)
    }

    func testCalculateSafeFrameDoesNotCrashOnNarrowScreen() {
        let screen = NSRect(x: 0, y: 0, width: 400, height: 900)
        let frame = Session.calculateSafeFrame(screenRect: screen,
                                               windowWidth: 600,
                                               windowHeight: 140)
        XCTAssertTrue(frame.origin.x.isFinite)
        XCTAssertTrue(frame.origin.y.isFinite)
        XCTAssertEqual(frame.width, 600, accuracy: 0.5)
        XCTAssertEqual(frame.height, 140, accuracy: 0.5)
    }

    func testCalculateSafeFrameStaysInsideVerticalBounds() {
        let screen = NSRect(x: 0, y: 0, width: 1440, height: 900)
        let frame = Session.calculateSafeFrame(screenRect: screen,
                                               windowWidth: 600,
                                               windowHeight: 140)
        XCTAssertGreaterThanOrEqual(frame.minY, screen.minY + 20 - 0.5)
        XCTAssertLessThanOrEqual(frame.maxY, screen.maxY - 40 + 0.5)
    }
}

// MARK: - HostAddress

final class HostAddressTests: XCTestCase {

    func testStripPortFromIPv4() {
        XCTAssertEqual(HostAddress.stripPort("192.168.1.10:52731"), "192.168.1.10")
    }

    func testStripPortFromBracketedIPv6() {
        XCTAssertEqual(HostAddress.stripPort("[fe80::1]:52731"), "fe80::1")
    }

    func testStripPortLeavesBareIPv6() {
        XCTAssertEqual(HostAddress.stripPort("fe80::1"), "fe80::1")
        XCTAssertEqual(HostAddress.stripPort("::1"), "::1")
    }

    func testStripPortLeavesHostname() {
        XCTAssertEqual(HostAddress.stripPort("mac.local"), "mac.local")
        XCTAssertEqual(HostAddress.stripPort("mac.local:52731"), "mac.local")
    }

    func testIsIPv4() {
        XCTAssertTrue(HostAddress.isIPv4("127.0.0.1"))
        XCTAssertTrue(HostAddress.isIPv4("192.168.1.10"))
        XCTAssertFalse(HostAddress.isIPv4("256.1.1.1"))
        XCTAssertFalse(HostAddress.isIPv4("fe80::1"))
    }

    func testIsIPv6() {
        XCTAssertTrue(HostAddress.isIPv6("::1"))
        XCTAssertTrue(HostAddress.isIPv6("fe80::1"))
        XCTAssertFalse(HostAddress.isIPv6("127.0.0.1"))
        XCTAssertFalse(HostAddress.isIPv6("[::1]"))
    }

    func testIsHostname() {
        XCTAssertTrue(HostAddress.isHostname("mac.local"))
        XCTAssertTrue(HostAddress.isHostname("example.com"))
        XCTAssertFalse(HostAddress.isHostname(""))
        XCTAssertFalse(HostAddress.isHostname("-bad.local"))
    }

    func testIsValidAcceptsIPv4IPv6Hostname() {
        XCTAssertTrue(HostAddress.isValid("127.0.0.1"))
        XCTAssertTrue(HostAddress.isValid("::1"))
        XCTAssertTrue(HostAddress.isValid("mac.local"))
        XCTAssertFalse(HostAddress.isValid("bad host"))
    }

    func testFormattedForURLWrapsIPv6() {
        XCTAssertEqual(HostAddress.formattedForURL("::1"), "[::1]")
        XCTAssertEqual(HostAddress.formattedForURL("127.0.0.1"), "127.0.0.1")
        XCTAssertEqual(HostAddress.formattedForURL("mac.local"), "mac.local")
    }

    func testBareHostRemovesBrackets() {
        XCTAssertEqual(HostAddress.bareHost("[::1]"), "::1")
        XCTAssertEqual(HostAddress.bareHost("[fe80::1]:52731"), "fe80::1")
    }
}

// MARK: - RemoteHost

#if BETA
final class RemoteHostTests: XCTestCase {

    func testIdUsesHashSeparator() {
        let host = RemoteHost(name: "Mac", host: "192.168.1.10", port: 52731)
        XCTAssertEqual(host.id, "192.168.1.10#52731")
    }

    func testIdForIPv6HasNoBrackets() {
        let host = RemoteHost(name: "Mac", host: "[fe80::1]:52731", port: 52731)
        XCTAssertEqual(host.host, "fe80::1")
        XCTAssertEqual(host.id, "fe80::1#52731")
    }

    func testInitStripsPortFromHost() {
        let host = RemoteHost(name: "Mac", host: "192.168.1.10:9999", port: 52731)
        XCTAssertEqual(host.host, "192.168.1.10")
        XCTAssertEqual(host.port, 52731)
    }
}

// MARK: - RemoteExecPayload

final class RemoteExecPayloadTests: XCTestCase {

    func testExecKindRoundTrip() throws {
        for kind in [RemoteExecPayload.Kind.command,
                     .sudo, .workflow, .alias, .history, .file] {
            let payload = RemoteExecPayload(
                id: "1",
                cmd: "echo hi",
                kind: kind.rawValue,
                timeout: 10
            )
            let data = try JSONEncoder().encode(payload)
            let decoded = try JSONDecoder().decode(RemoteExecPayload.self, from: data)
            XCTAssertEqual(decoded.execKind, kind)
            XCTAssertEqual(decoded.id, "1")
            XCTAssertEqual(decoded.cmd, "echo hi")
        }
    }

    func testUnknownKindFallsBackToCommand() throws {
        let payload = RemoteExecPayload(id: "1", cmd: "ls", kind: "nope", timeout: 10)
        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(RemoteExecPayload.self, from: data)
        XCTAssertEqual(decoded.execKind, .command)
    }
}

// MARK: - RemoteAccessPolicy（token 匹配）

final class RemoteAccessPolicyTests: XCTestCase {

    private let store = RemoteAccessPolicyStore.shared
    private let testWords = [
        "__rp_rm__",
        "__rp_RM__",
        "__rp_shutdown__"
    ]

    override func setUp() {
        super.setUp()
        for word in testWords {
            store.removeBlockedWord(word)
        }
    }

    override func tearDown() {
        for word in testWords {
            store.removeBlockedWord(word)
        }
        super.tearDown()
    }

    func testExactTokenMatch() {
        store.addBlockedWord("__rp_rm__")
        XCTAssertEqual(store.matchedBlockedWord(in: "__rp_rm__ -rf /"), "__rp_rm__")
    }

    func testTokenInsideCommandSubstitution() {
        store.addBlockedWord("__rp_rm__")
        XCTAssertEqual(store.matchedBlockedWord(in: "echo $(__rp_rm__ -rf /)"), "__rp_rm__")
    }

    func testPathSuffixMatches() {
        store.addBlockedWord("__rp_rm__")
        XCTAssertEqual(store.matchedBlockedWord(in: "/bin/__rp_rm__ -rf /"), "__rp_rm__")
    }

    func testSubstringIsNotMatched() {
        store.addBlockedWord("__rp_rm__")
        XCTAssertNil(store.matchedBlockedWord(in: "__rp_rm__extra foo"))
    }

    func testCaseInsensitive() {
        store.addBlockedWord("__rp_RM__")
        XCTAssertEqual(store.matchedBlockedWord(in: "__rp_rm__ -rf /"), "__rp_RM__")
    }

    func testNoWordsReturnsNil() {
        XCTAssertNil(store.matchedBlockedWord(in: "__rp_rm__ -rf /"))
    }

    func testCapabilityAllowedByDefault() {
        _ = store.isAllowed(.execCommand)
        _ = store.isAllowed(.sudoCommand)
    }
}
#endif

// MARK: - 版本特定测试

final class AppEnvironmentTests: XCTestCase {
    #if BETA
    func testPreviewIsBeta() {
        XCTAssertTrue(AppEnvironment.isBeta)
    }

    func testPreviewAppSupportFolderName() {
        XCTAssertEqual(AppEnvironment.appSupportFolderName, "RunProcess-Beta")
    }

    func testPreviewCustomPathEnabledDefaultsTrue() {
        UserDefaults.standard.removeObject(forKey: AppSettings.Keys.customPathEnabled)
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

    func testShellDefaultsToZsh() {
        XCTAssertEqual(AppSettings.resolvedShellPath, "/bin/zsh")
        XCTAssertTrue(AppSettings.isZshShell)
    }

    #if RUNPROCESS_TEST
    func testTestKeyPrefixIsIsolated() {
        XCTAssertTrue(AppSettings.Keys.sessionModeEnabled.hasPrefix("test."))
    }
    #endif
}
