//
//  HistorySearchView.swift
//  RunProcess
//
//  Created by Haoran on 2026/10/3.
//

import SwiftUI

struct HistorySearchView: View {
    @ObservedObject var viewModel: CommandViewModel
    @State private var query = ""
    @State private var results: [HistoryEntry] = []
    @State private var selected = 0
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // 搜索框
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 14))
                TextField(NSLocalizedString("history.search.placeholder", comment: ""),
                          text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15, design: .monospaced))
                    .focused($focused)
                    .onAppear {
                        focused = true
                        refresh()
                    }
                    .onChange(of: query) { _ in
                        refresh()
                    }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Divider()

            // 结果列表
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(results.enumerated()), id: \.offset) { idx, entry in
                            HistoryRow(
                                entry: entry,
                                isSelected: idx == selected
                            )
                            .id(idx)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selected = idx
                                apply()
                            }
                        }
                    }
                }
                .frame(height: 280)
                .onChange(of: selected) { newValue in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        proxy.scrollTo(newValue, anchor: .center)
                    }
                }
            }

            Divider()

            // 底部提示
            HStack(spacing: 12) {
                Text("↑↓")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(.secondary.opacity(0.6))
                Text(NSLocalizedString("history.hint.navigate", comment: ""))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary.opacity(0.6))
                Text("Enter")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(.secondary.opacity(0.6))
                Text(NSLocalizedString("history.hint.apply", comment: ""))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary.opacity(0.6))
                Text("Esc")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(.secondary.opacity(0.6))
                Text(NSLocalizedString("history.hint.close", comment: ""))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary.opacity(0.6))
                Spacer()
                Text("\(results.count)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary.opacity(0.5))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
        }
        .frame(width: 480)
        .onExitCommand {
            viewModel.showHistoryPanel = false
        }
        // ✅ 键盘导航：需要一层 NSView 捕获上下键
        .background(KeyCaptureView(
            onUp: { moveSelection(-1) },
            onDown: { moveSelection(1) },
            onEnter: { apply() },
            onEscape: { viewModel.showHistoryPanel = false }
        ))
    }

    private func refresh() {
        results = CommandHistory.shared.search(query)
        selected = 0
    }

    private func moveSelection(_ delta: Int) {
        guard !results.isEmpty else { return }
        selected = (selected + delta + results.count) % results.count
    }

    private func apply() {
        guard selected < results.count else { return }
        viewModel.inputText = results[selected].command
        viewModel.showHistoryPanel = false
    }
}

// MARK: - Row

private struct HistoryRow: View {
    let entry: HistoryEntry
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Text(entry.command)
                .font(.system(size: 13, design: .monospaced))
                .lineLimit(1)
                .foregroundColor(isSelected ? .white : .primary)

            Spacer()

            Text("\(entry.count)×")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(isSelected ? Color.accentColor : Color.clear)
    }
}

// MARK: - KeyCaptureView

/// 捕获上下键 / Enter / Esc，转发给 SwiftUI
private struct KeyCaptureView: NSViewRepresentable {
    let onUp: () -> Void
    let onDown: () -> Void
    let onEnter: () -> Void
    let onEscape: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = KeyView()
        view.onUp = onUp
        view.onDown = onDown
        view.onEnter = onEnter
        view.onEscape = onEscape
        DispatchQueue.main.async { view.window?.makeFirstResponder(view) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let v = nsView as? KeyView else { return }
        v.onUp = onUp
        v.onDown = onDown
        v.onEnter = onEnter
        v.onEscape = onEscape
    }

    class KeyView: NSView {
        var onUp: (() -> Void)?
        var onDown: (() -> Void)?
        var onEnter: (() -> Void)?
        var onEscape: (() -> Void)?

        override var acceptsFirstResponder: Bool { true }

        override func keyDown(with event: NSEvent) {
            switch event.keyCode {
            case 126: onUp?()        // ↑
            case 125: onDown?()      // ↓
            case 36, 76: onEnter?()  // Return / Enter
            case 53: onEscape?()     // Esc
            default: super.keyDown(with: event)
            }
        }

        // 不拦截鼠标，只当键盘事件
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }
}
