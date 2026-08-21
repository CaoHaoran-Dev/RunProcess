//
//  Suggestion.swift
//  RunProcess
//
//  Created by Haoran on 2026/8/21.
//

import Foundation

/// 补全建议项
struct Suggestion: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let type: SuggestionType
    let priority: Int
    
    enum SuggestionType: String {
        case history = "📜"
        case command = "⚡"
        case path = "📁"
    }
    
    init(text: String, type: SuggestionType) {
        self.text = text
        self.type = type
        switch type {
        case .history:
            self.priority = 300
        case .command:
            self.priority = 200
        case .path:
            self.priority = 100
        }
    }
    
    init(text: String, type: SuggestionType, historyCount: Int) {
        self.text = text
        self.type = type
        // 安全限制：确保 historyCount 不超过 100
        let safeCount = min(max(historyCount, 0), 100)
        switch type {
        case .history:
            self.priority = 300 + safeCount
        case .command:
            self.priority = 200
        case .path:
            self.priority = 100
        }
    }
    
    static func == (lhs: Suggestion, rhs: Suggestion) -> Bool {
        lhs.text == rhs.text && lhs.type == rhs.type
    }
}
