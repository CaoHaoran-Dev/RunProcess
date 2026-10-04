//
//  HelpView.swift
//  RunProcess
//
//  Created by Haoran on 2026/10/3.
//

import SwiftUI

// MARK: - Topic 数据

enum HelpTopic: String, CaseIterable, Identifiable {
    case overview
    case shortcuts
    case tips
    case session
    case sudo
    case aliases
    case appearance

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview:   return NSLocalizedString("help.topic.overview", comment: "")
        case .shortcuts:  return NSLocalizedString("help.topic.shortcuts", comment: "")
        case .tips:       return NSLocalizedString("help.topic.tips", comment: "")
        case .session:    return NSLocalizedString("help.topic.session", comment: "")
        case .sudo:       return NSLocalizedString("help.topic.sudo", comment: "")
        case .aliases:    return NSLocalizedString("help.topic.aliases", comment: "")
        case .appearance: return NSLocalizedString("help.topic.appearance", comment: "")
        }
    }

    var icon: String {
        switch self {
        case .overview:   return "book"
        case .shortcuts:  return "keyboard"
        case .tips:       return "lightbulb"
        case .session:    return "terminal"
        case .sudo:       return "lock.shield"
        case .aliases:    return "wand.and.stars"
        case .appearance: return "paintbrush"
        }
    }

    /// 该主题对应的全文，用于搜索
    /// 从 Localizable.strings 里拼出来，跟 HelpContent 渲染的内容一致
    var searchableText: String {
        let keys: [String]
        switch self {
        case .overview:
            keys = [
                "help.overview.p1",
                "help.overview.p2",
                "help.overview.quick",
                "help.shortcut.toggle",
                "help.shortcut.new",
                "help.shortcut.history",
                "help.shortcut.settings",
                "help.shortcut.enter",
                "help.shortcut.newline",
                "help.shortcut.complete",
                "help.shortcut.navigate",
            ]
        case .shortcuts:
            keys = [
                "help.shortcuts.global",
                "help.shortcut.toggle",
                "help.shortcut.new",
                "help.shortcut.history",
                "help.shortcut.settings",
                "help.shortcut.hide",
                "help.shortcut.quit",
                "help.shortcuts.input",
                "help.shortcut.enter",
                "help.shortcut.newline",
                "help.shortcut.complete",
                "help.shortcut.navigate",
                "help.shortcuts.note",
            ]
        case .tips:
            keys = [
                "help.tip.drag.title",
                "help.tip.drag.desc",
                "help.tip.app.title",
                "help.tip.app.desc",
                "help.tip.app.example",
                "help.tip.multiline.title",
                "help.tip.multiline.desc",
            ]
        case .session:
            keys = [
                "help.session.desc",
                "help.session.bullet1",
                "help.session.bullet2",
                "help.session.bullet3",
                "help.session.example",
                "help.session.example.desc",
            ]
        case .sudo:
            keys = [
                "help.sudo.desc",
                "help.sudo.bullet1",
                "help.sudo.bullet2",
                "help.sudo.bullet3",
            ]
        case .aliases:
            keys = [
                "help.aliases.desc",
                "help.aliases.defaults",
                "help.aliases.custom",
                "help.aliases.custom.desc",
            ]
        case .appearance:
            keys = [
                "help.appearance.desc",
                "help.appearance.none",
                "help.appearance.frosted",
                "help.appearance.liquid",
                "help.appearance.note",
            ]
        }

        return keys
            .map { NSLocalizedString($0, comment: "") }
            .joined(separator: " ")
    }

    /// 是否匹配搜索词（标题或内容）
    func matches(_ query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return true }
        if title.localizedCaseInsensitiveContains(q) { return true }
        return searchableText.localizedCaseInsensitiveContains(q)
    }

    /// 命中的片段（用于侧边栏下方预览）
    func snippet(for query: String) -> String? {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return nil }
        if title.localizedCaseInsensitiveContains(q) { return nil }

        let text = searchableText
        guard let range = text.range(of: q, options: .caseInsensitive) else { return nil }

        // 取前后各 30 个字符
        let start = text.index(range.lowerBound, offsetBy: -30, limitedBy: text.startIndex) ?? text.startIndex
        let end = text.index(range.upperBound, offsetBy: 30, limitedBy: text.endIndex) ?? text.endIndex
        var snippet = String(text[start..<end])

        if start != text.startIndex { snippet = "…" + snippet }
        if end != text.endIndex { snippet = snippet + "…" }
        return snippet
    }
}

// MARK: - 主视图

struct HelpView: View {
    @State private var selected: HelpTopic = .overview
    @State private var searchText: String = ""

    @AppStorage(AppSettings.Keys.appearanceStyle) private var appearanceStyleRaw: String = AppSettings.appearanceStyleRaw.rawValue
    private var appearanceStyle: AppearanceStyle { AppSettings.resolvedAppearanceStyle }

    private var filteredTopics: [HelpTopic] {
        let q = searchText.trimmingCharacters(in: .whitespaces)
        if q.isEmpty { return HelpTopic.allCases }
        return HelpTopic.allCases.filter { $0.matches(q) }
    }

    var body: some View {
        Group {
            if #available(macOS 13.0, *) {
                modernLayout
            } else {
                legacyLayout
            }
        }
        .frame(minWidth: 680, idealWidth: 720, minHeight: 400, idealHeight: 480)
        .background(
            AdaptiveWindowBackground(
                style: appearanceStyle,
                material: .sidebar,
                blendingMode: .behindWindow
            )
            .ignoresSafeArea()
        )
    }

    @available(macOS 13.0, *)
    private var modernLayout: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailPane
        }
        .navigationTitle(NSLocalizedString("window.help.title", comment: ""))
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    selected = .overview
                    searchText = ""
                } label: {
                    Image(systemName: "house")
                }
                .help(NSLocalizedString("help.home", comment: ""))
            }
        }
    }

    private var legacyLayout: some View {
        HStack(spacing: 0) {
            sidebar.frame(width: 220)
            Divider()
            detailPane
        }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            // 搜索框
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                TextField(NSLocalizedString("help.search", comment: ""), text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.6))
            )
            .padding(10)

            Divider()

            // 结果列表
            if filteredTopics.isEmpty {
                VStack(spacing: 6) {
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text(NSLocalizedString("help.search.noResults", comment: ""))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(filteredTopics) { topic in
                            TopicRow(
                                topic: topic,
                                isSelected: topic == selected,
                                snippet: topic.snippet(for: searchText),
                                onTap: { selected = topic }
                            )
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 6)
                }
            }
        }
        .background(Color.clear)
    }

    private var detailPane: some View {
        ScrollView {
            HelpContent(topic: selected)
                .padding(28)
                .frame(maxWidth: 680, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.clear)
    }
}

// MARK: - 侧边栏行

private struct TopicRow: View {
    let topic: HelpTopic
    let isSelected: Bool
    let snippet: String?
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Image(systemName: topic.icon)
                    .font(.system(size: 12))
                    .foregroundColor(isSelected ? .white : .accentColor)
                    .frame(width: 16)
                Text(topic.title)
                    .font(.system(size: 12))
                    .foregroundColor(isSelected ? .white : .primary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }

            if let snippet = snippet, !snippet.isEmpty {
                Text(snippet)
                    .font(.system(size: 10))
                    .foregroundColor(isSelected ? .white.opacity(0.7) : .secondary)
                    .lineLimit(2)
                    .padding(.leading, 24)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(isSelected ? Color.accentColor : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }
}

// MARK: - 内容分发

private struct HelpContent: View {
    let topic: HelpTopic

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: topic.icon)
                    .font(.system(size: 22))
                    .foregroundColor(.accentColor)
                Text(topic.title)
                    .font(.system(size: 24, weight: .semibold))
            }
            .padding(.bottom, 4)

            Divider()

            switch topic {
            case .overview:   OverviewSection()
            case .shortcuts:  ShortcutsSection()
            case .tips:       TipsSection()
            case .session:    SessionSection()
            case .sudo:       SudoSection()
            case .aliases:    AliasesSection()
            case .appearance: AppearanceSection()
            }
        }
    }
}

// MARK: - 通用排版组件

private struct HelpH2: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.system(size: 15, weight: .semibold))
            .padding(.top, 8)
    }
}

private struct HelpP: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundColor(.primary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct HelpBullet: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}

private struct KeyRow: View {
    let keys: String
    let desc: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(keys)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.primary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .frame(width: 110, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(NSColor.controlBackgroundColor).opacity(0.6))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
                )
            Text(desc)
                .font(.system(size: 13))
                .foregroundColor(.primary)
            Spacer(minLength: 0)
        }
    }
}

private struct CodeBlock: View {
    let code: String
    init(_ code: String) { self.code = code }
    var body: some View {
        Text(code)
            .font(.system(size: 12, design: .monospaced))
            .foregroundColor(.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
            )
    }
}

// MARK: - 各章节内容

private struct OverviewSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HelpP(NSLocalizedString("help.overview.p1", comment: ""))
            HelpP(NSLocalizedString("help.overview.p2", comment: ""))

            HelpH2(NSLocalizedString("help.overview.quick", comment: ""))
            KeyRow(keys: "⌘⌥R", desc: NSLocalizedString("help.shortcut.toggle", comment: ""))
            KeyRow(keys: "⌘N", desc: NSLocalizedString("help.shortcut.new", comment: ""))
            KeyRow(keys: "⌘R", desc: NSLocalizedString("help.shortcut.history", comment: ""))
            KeyRow(keys: "⌘,", desc: NSLocalizedString("help.shortcut.settings", comment: ""))
            KeyRow(keys: "Enter", desc: NSLocalizedString("help.shortcut.enter", comment: ""))
            KeyRow(keys: "Shift+Enter", desc: NSLocalizedString("help.shortcut.newline", comment: ""))
            KeyRow(keys: "Tab", desc: NSLocalizedString("help.shortcut.complete", comment: ""))
            KeyRow(keys: "↑ ↓", desc: NSLocalizedString("help.shortcut.navigate", comment: ""))
        }
    }
}

private struct ShortcutsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HelpH2(NSLocalizedString("help.shortcuts.global", comment: ""))
            KeyRow(keys: "⌘⌥R", desc: NSLocalizedString("help.shortcut.toggle", comment: ""))
            KeyRow(keys: "⌘N", desc: NSLocalizedString("help.shortcut.new", comment: ""))
            KeyRow(keys: "⌘R", desc: NSLocalizedString("help.shortcut.history", comment: ""))
            KeyRow(keys: "⌘,", desc: NSLocalizedString("help.shortcut.settings", comment: ""))
            KeyRow(keys: "⌘W", desc: NSLocalizedString("help.shortcut.hide", comment: ""))
            KeyRow(keys: "⌘Q", desc: NSLocalizedString("help.shortcut.quit", comment: ""))

            HelpH2(NSLocalizedString("help.shortcuts.input", comment: ""))
            KeyRow(keys: "Enter", desc: NSLocalizedString("help.shortcut.enter", comment: ""))
            KeyRow(keys: "Shift+Enter", desc: NSLocalizedString("help.shortcut.newline", comment: ""))
            KeyRow(keys: "Tab", desc: NSLocalizedString("help.shortcut.complete", comment: ""))
            KeyRow(keys: "↑ ↓", desc: NSLocalizedString("help.shortcut.navigate", comment: ""))

            HelpP(NSLocalizedString("help.shortcuts.note", comment: ""))
        }
    }
}

private struct TipsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HelpH2(NSLocalizedString("help.tip.drag.title", comment: ""))
            HelpP(NSLocalizedString("help.tip.drag.desc", comment: ""))

            HelpH2(NSLocalizedString("help.tip.app.title", comment: ""))
            HelpP(NSLocalizedString("help.tip.app.desc", comment: ""))
            CodeBlock("/Applications/Safari.app")
            HelpP(NSLocalizedString("help.tip.app.example", comment: ""))

            HelpH2(NSLocalizedString("help.tip.multiline.title", comment: ""))
            HelpP(NSLocalizedString("help.tip.multiline.desc", comment: ""))
        }
    }
}

private struct SessionSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HelpP(NSLocalizedString("help.session.desc", comment: ""))
            HelpBullet(NSLocalizedString("help.session.bullet1", comment: ""))
            HelpBullet(NSLocalizedString("help.session.bullet2", comment: ""))
            HelpBullet(NSLocalizedString("help.session.bullet3", comment: ""))

            HelpH2(NSLocalizedString("help.session.example", comment: ""))
            CodeBlock("cd ~/Projects\ngit status")
            HelpP(NSLocalizedString("help.session.example.desc", comment: ""))
        }
    }
}

private struct SudoSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HelpP(NSLocalizedString("help.sudo.desc", comment: ""))
            HelpBullet(NSLocalizedString("help.sudo.bullet1", comment: ""))
            HelpBullet(NSLocalizedString("help.sudo.bullet2", comment: ""))
            HelpBullet(NSLocalizedString("help.sudo.bullet3", comment: ""))
        }
    }
}

private struct AliasesSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HelpP(NSLocalizedString("help.aliases.desc", comment: ""))

            HelpH2(NSLocalizedString("help.aliases.defaults", comment: ""))
            CodeBlock("""
            gs    → git status
            gp    → git pull --rebase
            ll    → ls -lah
            serve → python3 -m http.server 8000
            """)

            HelpH2(NSLocalizedString("help.aliases.custom", comment: ""))
            HelpP(NSLocalizedString("help.aliases.custom.desc", comment: ""))
            CodeBlock("~/Library/Application Support/RunProcess/aliases.yml")
        }
    }
}

private struct AppearanceSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HelpP(NSLocalizedString("help.appearance.desc", comment: ""))
            HelpBullet(NSLocalizedString("help.appearance.none", comment: ""))
            HelpBullet(NSLocalizedString("help.appearance.frosted", comment: ""))
            HelpBullet(NSLocalizedString("help.appearance.liquid", comment: ""))
            HelpP(NSLocalizedString("help.appearance.note", comment: ""))
        }
    }
}
