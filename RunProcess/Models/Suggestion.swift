//
//  Suggestion.swift
//  RunProcess
//
//  Created by Haoran on 2026/8/21.
//

import Foundation

struct Suggestion: Identifiable, Equatable, Sendable {
    let id = UUID()
    let text: String
    let type: SuggestionType
    let subtitle: String?
    let historyCount: Int?
    let priority: Int

    enum SuggestionType: String, Sendable {
        case alias = "wand.and.stars"
        case history = "clock.arrow.circlepath"
        case command = "terminal"
        case path = "folder"

        var iconName: String { rawValue }
    }

    init(text: String, type: SuggestionType, subtitle: String? = nil) {
        self.text = text
        self.type = type
        self.subtitle = subtitle
        self.historyCount = nil
        switch type {
        case .alias:   self.priority = 500
        case .history: self.priority = 300
        case .command: self.priority = 200
        case .path:    self.priority = 100
        }
    }

    init(text: String, type: SuggestionType, historyCount: Int) {
        self.text = text
        self.type = type
        self.subtitle = nil
        let safe = min(max(historyCount, 0), 100)
        self.historyCount = safe
        switch type {
        case .alias:   self.priority = 500
        case .history: self.priority = 300 + safe
        case .command: self.priority = 200
        case .path:    self.priority = 100
        }
    }

    nonisolated static func == (lhs: Suggestion, rhs: Suggestion) -> Bool {
        lhs.text == rhs.text && lhs.type == rhs.type
    }
}
