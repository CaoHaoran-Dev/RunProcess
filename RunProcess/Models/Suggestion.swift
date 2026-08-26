//
//  Suggestion.swift
//  RunProcess
//
//  Created by Haoran on 2026/8/21.
//

import Foundation

/// 补全建议项
struct Suggestion: Identifiable, Equatable, Sendable {
    let id = UUID()
    let text: String
    let type: SuggestionType
    let priority: Int
    
    enum SuggestionType: String, Sendable {
        case history = "clock.arrow.circlepath"
        case command = "terminal"
        case path = "folder"
        
        var iconName: String {
            return self.rawValue
        }
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
    
    // 显式实现 Equatable，标记为 nonisolated 避免 MainActor 隔离问题
    nonisolated static func == (lhs: Suggestion, rhs: Suggestion) -> Bool {
        return lhs.text == rhs.text && lhs.type == rhs.type
    }
}
