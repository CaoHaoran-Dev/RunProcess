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
            // 类型图标（使用 SF Symbol）
            Image(systemName: suggestion.type.iconName)
                .font(.system(size: 14))
                .foregroundColor(isSelected ? .white : .secondary)
                .frame(width: 20, alignment: .center)
            
            // 命令文本
            Text(suggestion.text)
                .font(.system(size: 15, design: .monospaced))
                .foregroundColor(isSelected ? .white : .primary)
                .lineLimit(1)
            
            Spacer()
            
            // 如果是历史命令，显示频次
            if suggestion.type == .history {
                let count = suggestion.priority - 300
                if count > 0 {
                    Text("\(count)次")
                        .font(.system(size: 11))
                        .foregroundColor(isSelected ? .white.opacity(0.7) : .secondary)
                }
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
}
