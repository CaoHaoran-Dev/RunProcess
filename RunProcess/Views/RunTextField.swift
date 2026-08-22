//
//  RunTextField.swift
//  RunProcess
//
//  Created by Haoran on 2026/8/21.
//

import SwiftUI

struct RunTextField: NSViewRepresentable {
    @Binding var text: String
    let onTab: () -> Void
    let onEnter: () -> Void
    let onUp: () -> String?   // 返回历史命令，nil 表示没有更多历史
    let onDown: () -> String? // 返回历史命令，nil 表示没有更多历史
    
    func makeNSView(context: Context) -> NSTextField {
        let field = CustomTextField()
        field.delegate = context.coordinator
        field.placeholderString = "输入命令或拖入文件..."
        field.font = NSFont.monospacedSystemFont(ofSize: 18, weight: .regular)
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.registerForDraggedTypes([NSPasteboard.PasteboardType("NSFilenamesPboardType")])
        return field
    }
    
    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: RunTextField
        
        init(_ parent: RunTextField) {
            self.parent = parent
        }
        
        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            parent.text = field.stringValue
        }
        
        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            // 回车 - 执行
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onEnter()
                return true
            }
            
            // Tab - 补全
            if commandSelector == #selector(NSResponder.insertTab(_:)) {
                parent.onTab()
                return true
            }
            
            // 上箭头 - 历史命令上一条
            if commandSelector == #selector(NSResponder.moveUp(_:)) {
                if let command = parent.onUp() {
                    parent.text = command
                    if let field = control as? NSTextField {
                        field.stringValue = command
                        // 光标移到末尾
                        if let editor = field.currentEditor() as? NSTextView {
                            editor.selectedRange = NSRange(location: command.count, length: 0)
                        }
                    }
                }
                return true
            }
            
            // 下箭头 - 历史命令下一条
            if commandSelector == #selector(NSResponder.moveDown(_:)) {
                if let command = parent.onDown() {
                    parent.text = command
                    if let field = control as? NSTextField {
                        field.stringValue = command
                        if let editor = field.currentEditor() as? NSTextView {
                            editor.selectedRange = NSRange(location: command.count, length: 0)
                        }
                    }
                }
                return true
            }
            
            return false
        }
    }
}

// MARK: - CustomTextField

class CustomTextField: NSTextField {
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pasteboardType = NSPasteboard.PasteboardType("NSFilenamesPboardType")
        guard let board = sender.draggingPasteboard.propertyList(forType: pasteboardType) as? [String],
              let path = board.first else { return false }
        
        let escaped = path.replacingOccurrences(of: " ", with: "\\ ")
        stringValue = escaped
        (delegate as? RunTextField.Coordinator)?.parent.text = escaped
        
        return true
    }
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        return .copy
    }
}
