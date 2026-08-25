//
//  RunTextField.swift
//  RunProcess
//
//  Created by Haoran on 2026/8/21.
//

import SwiftUI
import AppKit

struct RunTextField: NSViewRepresentable {
    @Binding var text: String
    let onTab: () -> Void
    let onEnter: () -> Void
    let onUp: () -> String?
    let onDown: () -> String?
    
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
        
        textView.textColor = .labelColor
        textView.insertionPointColor = .labelColor
        
        textView.registerForDraggedTypes([NSPasteboard.PasteboardType("NSFilenamesPboardType")])
        
        // ✅ 固定行高让光标居中
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.minimumLineHeight = 28
        paragraphStyle.maximumLineHeight = 28
        textView.defaultParagraphStyle = paragraphStyle
        textView.typingAttributes = [
            .font: NSFont.monospacedSystemFont(ofSize: 18, weight: .regular),
            .paragraphStyle: paragraphStyle
        ]
        
        scrollView.documentView = textView
        
        context.coordinator.textView = textView
        context.coordinator.scrollView = scrollView
        
        textView.string = text
        
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.heightAnchor.constraint(equalToConstant: 44).isActive = true
        
        // ✅ contentInsets 让内容居中
        scrollView.contentInsets = NSEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? CustomTextView else { return }
        
        if textView.string != text {
            textView.string = text
        }
        
        textView.textContainer?.containerSize = NSSize(width: nsView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.layoutManager?.ensureLayout(for: textView.textContainer!)
        
        nsView.contentInsets = NSEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        
        let clipView = nsView.contentView
        let documentHeight = textView.intrinsicContentSize.height
        let visibleHeight = clipView.bounds.height
        if documentHeight > visibleHeight {
            let newOrigin = NSPoint(x: 0, y: documentHeight - visibleHeight)
            clipView.scroll(to: newOrigin)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: RunTextField
        weak var textView: CustomTextView?
        weak var scrollView: NSScrollView?
        private var isNavigatingHistory = false
        
        init(_ parent: RunTextField) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = textView else { return }
            parent.text = textView.string
            
            if let scrollView = scrollView {
                scrollView.contentInsets = NSEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
            }
        }
        
        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                let event = NSApp.currentEvent
                if let event = event, event.modifierFlags.contains(.shift) || event.modifierFlags.contains(.command) {
                    insertNewline(textView)
                    return false
                }
                parent.onEnter()
                return true
            }
            
            if commandSelector == #selector(NSResponder.insertTab(_:)) {
                parent.onTab()
                return true
            }
            
            if commandSelector == #selector(NSResponder.insertBacktab(_:)) {
                insertTab(textView)
                return true
            }
            
            if commandSelector == #selector(NSResponder.moveUp(_:)) {
                let cursorPosition = textView.selectedRange.location
                let text = textView.string as NSString
                let lineRange = text.lineRange(for: NSRange(location: cursorPosition, length: 0))
                
                if cursorPosition == 0 || lineRange.location == 0 {
                    if let command = parent.onUp() {
                        isNavigatingHistory = true
                        textView.string = command
                        parent.text = command
                        textView.selectedRange = NSRange(location: command.count, length: 0)
                        isNavigatingHistory = false
                    }
                    return true
                }
                return false
            }
            
            if commandSelector == #selector(NSResponder.moveDown(_:)) {
                let cursorPosition = textView.selectedRange.location
                let text = textView.string as NSString
                let lineRange = text.lineRange(for: NSRange(location: cursorPosition, length: 0))
                
                if cursorPosition == text.length || lineRange.location + lineRange.length == text.length {
                    if let command = parent.onDown() {
                        isNavigatingHistory = true
                        textView.string = command
                        parent.text = command
                        textView.selectedRange = NSRange(location: command.count, length: 0)
                        isNavigatingHistory = false
                    }
                    return true
                }
                return false
            }
            
            return false
        }
        
        private func insertNewline(_ textView: NSTextView) {
            let currentText = textView.string as NSString
            let range = textView.selectedRange
            let newText = currentText.replacingCharacters(in: range, with: "\n")
            textView.string = newText
            textView.selectedRange = NSRange(location: range.location + 1, length: 0)
            parent.text = newText
        }
        
        private func insertTab(_ textView: NSTextView) {
            let currentText = textView.string as NSString
            let range = textView.selectedRange
            let newText = currentText.replacingCharacters(in: range, with: "    ")
            textView.string = newText
            textView.selectedRange = NSRange(location: range.location + 4, length: 0)
            parent.text = newText
        }
    }
}

// MARK: - CustomTextView

class CustomTextView: NSTextView {
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pasteboardType = NSPasteboard.PasteboardType("NSFilenamesPboardType")
        guard let board = sender.draggingPasteboard.propertyList(forType: pasteboardType) as? [String],
              let path = board.first else { return false }
        
        let escaped = path.replacingOccurrences(of: " ", with: "\\ ")
        
        let currentText = self.string as NSString
        let range = self.selectedRange
        let newText = currentText.replacingCharacters(in: range, with: escaped)
        self.string = newText
        let newCursor = range.location + (escaped as NSString).length
        self.selectedRange = NSRange(location: newCursor, length: 0)
        
        (delegate as? RunTextField.Coordinator)?.parent.text = newText
        
        return true
    }
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        return .copy
    }
    
    override var intrinsicContentSize: NSSize {
        guard let layoutManager = layoutManager,
              let textContainer = textContainer else {
            return super.intrinsicContentSize
        }
        
        layoutManager.ensureLayout(for: textContainer)
        let rect = layoutManager.usedRect(for: textContainer)
        let height = max(rect.height + 10, 40)
        let width = textContainer.containerSize.width
        
        return NSSize(width: width, height: height)
    }
}
