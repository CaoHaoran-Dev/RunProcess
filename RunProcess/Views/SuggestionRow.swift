//
//  SuggestionRow.swift
//  RunProcess
//
//  Created by Haoran on 2026/8/21.
//

import SwiftUI

struct SuggestionRow: View {
    let suggestion: Suggestion
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: suggestion.type.iconName)
                .font(.system(size: 14))
                .foregroundColor(isSelected ? .white : iconColor)
                .frame(width: 20, alignment: .center)

            VStack(alignment: .leading, spacing: 1) {
                Text(suggestion.text)
                    .font(.system(size: 15, design: .monospaced))
                    .foregroundColor(isSelected ? .white : .primary)
                    .lineLimit(1)

                if let subtitle = suggestion.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(isSelected ? .white.opacity(0.75) : .secondary.opacity(0.7))
                        .lineLimit(1)
                }
            }

            Spacer()

            if suggestion.type == .history, let count = suggestion.historyCount, count > 0 {
                Text("\(count)次")
                    .font(.system(size: 11))
                    .foregroundColor(isSelected ? .white.opacity(0.7) : .secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor : Color.clear)
        )
        .contentShape(Rectangle())
    }

    private var iconColor: Color {
        switch suggestion.type {
        case .alias: return .orange
        case .history: return .secondary
        case .command: return .secondary
        case .path: return .secondary
        }
    }
}
