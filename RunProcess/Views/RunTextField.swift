//
//  RunTextField.swift
//  RunProcess
//
//  Created by Haoran on 2026/8/21.
//

import SwiftUI
internal import AppKit

struct RunTextField: NSViewRepresentable {
    @Binding var text: String
    let onTab: () -> Void
    let onEnter: () -> Void
    let onOptionEnter: () -> Void // Option+Enter 触发（Root）
    let onUp: () -> String?
    let onDown: () -> String?
    var onCancel: (() -> Void)? = nil

    var onCoordinatorReady: ((Coordinator) -> Void)? = nil

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        let textView = CustomTextView()
        textView.delegate = context.coordinator
        textView.font = NSFont.monospacedSystemFont(ofSize: 18, weight: .regular)
        textView.isRichText = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.autoresizingMask = [.width]

        let dynamicTextColor = NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? .white : .black
        }
        textView.textColor = dynamicTextColor
        textView.insertionPointColor = dynamicTextColor

        textView.registerForDraggedTypes([NSPasteboard.PasteboardType("NSFilenamesPboardType")])

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.minimumLineHeight = 28
        paragraphStyle.maximumLineHeight = 28
        textView.defaultParagraphStyle = paragraphStyle

        textView.typingAttributes = [
            .font: NSFont.monospacedSystemFont(ofSize: 18, weight: .regular),
            .paragraphStyle: paragraphStyle,
            .foregroundColor: dynamicTextColor
        ]

        scrollView.documentView = textView
        context.coordinator.textView = textView
        context.coordinator.scrollView = scrollView
        textView.string = text
        
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.contentInsets = NSEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)

        DispatchQueue.main.async {
            onCoordinatorReady?(context.coordinator)
        }

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? CustomTextView else { return }
        if textView.string != text { textView.string = text }
        textView.textContainer?.containerSize = NSSize(width: nsView.contentSize.width, height: .greatestFiniteMagnitude)
        textView.layoutManager?.ensureLayout(for: textView.textContainer!)
        nsView.contentInsets = NSEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        let clipView = nsView.contentView
        let docHeight = textView.intrinsicContentSize.height
        let visibleHeight = clipView.bounds.height
        if docHeight > visibleHeight {
            clipView.scroll(to: NSPoint(x: 0, y: docHeight - visibleHeight))
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: RunTextField
        weak var textView: CustomTextView?
        weak var scrollView: NSScrollView?

        init(_ parent: RunTextField) { self.parent = parent }

        func restoreFocus() {
            guard let textView = textView, let window = textView.window else { return }
            guard window.isKeyWindow else { return }
            guard window.attachedSheet == nil else { return }
            guard window.firstResponder !== textView else { return }
            window.makeFirstResponder(textView)
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = textView else { return }
            parent.text = textView.string
            scrollView?.contentInsets = NSEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        }

        // 👇 这里只处理非回车键（Tab、上下方向键等）
        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                parent.onCancel?()
                return true
            }

            if commandSelector == #selector(NSResponder.insertTab(_:)) {
                parent.onTab()
                return true
            }

            if commandSelector == #selector(NSResponder.insertBacktab(_:)) {
                insertSpaces(textView)
                return true
            }

            if commandSelector == #selector(NSResponder.moveUp(_:)) {
                let pos = textView.selectedRange.location
                let ns = textView.string as NSString
                let lineRange = ns.lineRange(for: NSRange(location: pos, length: 0))
                if pos == 0 || lineRange.location == 0 {
                    if let cmd = parent.onUp() {
                        textView.string = cmd
                        parent.text = cmd
                        textView.selectedRange = NSRange(location: cmd.count, length: 0)
                    }
                    return true
                }
                return false
            }

            if commandSelector == #selector(NSResponder.moveDown(_:)) {
                let pos = textView.selectedRange.location
                let ns = textView.string as NSString
                let lineRange = ns.lineRange(for: NSRange(location: pos, length: 0))
                if pos == ns.length || lineRange.location + lineRange.length == ns.length {
                    if let cmd = parent.onDown() {
                        textView.string = cmd
                        parent.text = cmd
                        textView.selectedRange = NSRange(location: cmd.count, length: 0)
                    }
                    return true
                }
                return false
            }
            return false
        }

        private func insertSpaces(_ textView: NSTextView) {
            let ns = textView.string as NSString
            let range = textView.selectedRange
            let newText = ns.replacingCharacters(in: range, with: "    ")
            textView.string = newText
            textView.selectedRange = NSRange(location: range.location + 4, length: 0)
            parent.text = newText
        }
    }
}

class CustomTextView: NSTextView {
    // 👇 核心：在这里拦截回车键，直接和系统默认行为（Option+Return = 换行）解耦
    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let isReturn = event.keyCode == 36 || event.keyCode == 76 // 主键盘回车 / 小键盘回车

        if isReturn {
            if flags.contains(.option) {
                // Option + Enter：提权
                (delegate as? RunTextField.Coordinator)?.parent.onOptionEnter()
                return
            } else if flags.contains(.shift) {
                // Shift + Enter：插入换行
                self.insertNewline(nil)
                return
            } else if flags.contains(.command) {
                // Command + Enter：也插入换行（因为原来代码里有这个逻辑，顺手保留）
                self.insertNewline(nil)
                return
            } else {
                // 纯 Enter：执行
                (delegate as? RunTextField.Coordinator)?.parent.onEnter()
                return
            }
        }

        // 其他按键正常向下传递
        super.keyDown(with: event)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let type = NSPasteboard.PasteboardType("NSFilenamesPboardType")
        guard let paths = sender.draggingPasteboard.propertyList(forType: type) as? [String],
              !paths.isEmpty else { return false }

        let escaped = ShellQuoting.quoteAll(paths)

        let ns = self.string as NSString
        let range = self.selectedRange
        let newText = ns.replacingCharacters(in: range, with: escaped)
        self.string = newText
        self.selectedRange = NSRange(location: range.location + (escaped as NSString).length, length: 0)
        (delegate as? RunTextField.Coordinator)?.parent.text = newText
        return true
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { .copy }

    override var intrinsicContentSize: NSSize {
        guard let lm = layoutManager, let tc = textContainer else { return super.intrinsicContentSize }
        lm.ensureLayout(for: tc)
        let rect = lm.usedRect(for: tc)
        return NSSize(width: tc.containerSize.width, height: max(rect.height + 10, 40))
    }
}
