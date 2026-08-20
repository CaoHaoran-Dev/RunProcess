//
//  RunTextField.swift
//  RunProcess
//
//  Created by Haoran on 2026/8/19.
//

import SwiftUI

struct RunTextField: NSViewRepresentable {
    @Binding var text: String
    let onEnter: () -> Void
    
    func makeNSView(context: Context) -> NSTextField {
        let field = CustomTextField()
        field.delegate = context.coordinator
        field.placeholderString = "输入命令或拖入文件..."
        field.font = NSFont.monospacedSystemFont(ofSize: 18, weight: .regular)
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.registerForDraggedTypes([.fileURL])
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
        var lastCompletions: [String] = []
        
        init(_ parent: RunTextField) {
            self.parent = parent
        }
        
        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            parent.text = field.stringValue
        }
        
        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onEnter()
                return true
            }
            
            if commandSelector == #selector(NSResponder.insertTab(_:)) {
                performTabCompletion(textView: textView)
                return true
            }
            
            return false
        }
        
        func performTabCompletion(textView: NSTextView) {
            let input = textView.string
            guard input.hasPrefix("/") || input.hasPrefix("~") else { return }
            
            let completions = CommandExecutor.shared.pathCompletions(for: input)
            guard !completions.isEmpty else { return }
            
            if let first = completions.first {
                textView.string = first
                parent.text = first
                textView.selectAll(nil)
            }
        }
    }
}

// 自定义 NSTextField 支持拖拽
class CustomTextField: NSTextField {
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let board = sender.draggingPasteboard.propertyList(forType: .fileURL) as? [String],
              let path = board.first else { return false }
        
        // 自动转义空格
        let escaped = path.replacingOccurrences(of: " ", with: "\\ ")
        stringValue = escaped
        (delegate as? RunTextField.Coordinator)?.parent.text = escaped
        
        return true
    }
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        return .copy
    }
}
