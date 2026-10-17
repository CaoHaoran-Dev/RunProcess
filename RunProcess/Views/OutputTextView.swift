//
//  OutputTextView.swift
//  RunProcess
//
//  Created by Haoran on 2026/10/7.
//

import SwiftUI
internal import AppKit

struct OutputTextView: NSViewRepresentable {
    let attributed: NSAttributedString
    let height: CGFloat
    var onContentWidth: ((CGFloat) -> Void)? = nil

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        let textView = NonFocusableTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = true
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.textContainerInset = NSSize(width: 0, height: 4)
        textView.textContainer?.lineFragmentPadding = 0

        let infinite: CGFloat = .greatestFiniteMagnitude
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.containerSize = NSSize(width: infinite, height: infinite)
        textView.isHorizontallyResizable = true
        textView.isVerticallyResizable = true
        textView.maxSize = NSSize(width: infinite, height: infinite)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.autoresizingMask = []

        textView.font = OutputFont.regular
        textView.typingAttributes = [
            .font: OutputFont.regular,
            .foregroundColor: NSColor.labelColor
        ]

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 1
        textView.defaultParagraphStyle = paragraphStyle

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NonFocusableTextView else { return }

        // 直接用 incoming（已经是最终 NSAttributedString，
        // 所有颜色都是 NSColor）。
        let incoming = NSMutableAttributedString(attributedString: attributed)

        // 补齐没有 font 的片段
        let fullRange = NSRange(location: 0, length: incoming.length)
        incoming.enumerateAttribute(.font,
                                    in: fullRange,
                                    options: []) { (value: Any?, range: NSRange, _: UnsafeMutablePointer<ObjCBool>) in
            if value == nil {
                incoming.addAttribute(.font, value: OutputFont.regular, range: range)
            }
        }

        if textView.textStorage?.isEqual(to: incoming) == false {
            textView.textStorage?.setAttributedString(incoming)

            if let onContentWidth = onContentWidth {
                let width = Self.measureWidth(incoming)
                DispatchQueue.main.async {
                    onContentWidth(width)
                }
            }
        }
    }

    private static func measureWidth(_ attr: NSAttributedString) -> CGFloat {
        let text = attr.string as NSString
        var maxWidth: CGFloat = 0
        var lineStart = 0
        while lineStart < text.length {
            var lineEnd = 0
            var contentEnd = 0
            text.getLineStart(&lineStart,
                              end: &lineEnd,
                              contentsEnd: &contentEnd,
                              for: NSRange(location: lineStart, length: 0))
            let lineRange = NSRange(location: lineStart, length: contentEnd - lineStart)
            let lineAttr = attr.attributedSubstring(from: lineRange)
            let size = lineAttr.size()
            maxWidth = max(maxWidth, size.width)
            lineStart = lineEnd
        }
        return maxWidth
    }
}

// MARK: - SF Mono 字体工具

enum OutputFont {
    static let size: CGFloat = 13

    static var regular: NSFont {
        if let f = NSFont(name: "SFMono-Regular", size: size) { return f }
        if let f = NSFont(name: "SF Mono", size: size) { return f }
        return NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
    }

    static var medium: NSFont {
        if let f = NSFont(name: "SFMono-Medium", size: size) { return f }
        return NSFont.monospacedSystemFont(ofSize: size, weight: .medium)
    }

    static var bold: NSFont {
        if let f = NSFont(name: "SFMono-Bold", size: size) { return f }
        return NSFont.monospacedSystemFont(ofSize: size, weight: .bold)
    }

    static var italic: NSFont {
        if let f = NSFont(name: "SFMono-RegularItalic", size: size) { return f }
        let base = NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
        let desc = base.fontDescriptor.withSymbolicTraits(.italic)
        return NSFont(descriptor: desc, size: size) ?? base
    }
}

// MARK: - 只读、可选择、永不抢焦点

class NonFocusableTextView: NSTextView {
    override var acceptsFirstResponder: Bool { false }
    override func becomeFirstResponder() -> Bool { false }

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = NSMenu()
        menu.addItem(withTitle: NSLocalizedString("button.copy", comment: ""),
                     action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        menu.addItem(withTitle: NSLocalizedString("button.selectAll", comment: ""),
                     action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        return menu
    }
}
