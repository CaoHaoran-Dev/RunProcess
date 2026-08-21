//
//  SuggestionPopover.swift
//  RunProcess
//
//  Created by Haoran on 2026/8/21.
//

import SwiftUI

struct SuggestionPopover: View {
    @ObservedObject var viewModel: CommandViewModel
    
    var body: some View {
        // 直接用 suggestions 是否为空来判断显示
        if !viewModel.suggestions.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.6))
                    Spacer()
                    Text("\(viewModel.selectedIndex + 1)/\(viewModel.suggestions.count)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.6))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
                
                Divider()
                
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(Array(viewModel.suggestions.enumerated()), id: \.element.id) { index, suggestion in
                            SuggestionRow(
                                suggestion: suggestion,
                                isSelected: index == viewModel.selectedIndex
                            )
                            .onTapGesture {
                                viewModel.selectedIndex = index
                                viewModel.confirmSelection()
                            }
                            .onHover { hovering in
                                if hovering {
                                    viewModel.selectedIndex = index
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                }
                .frame(height: calculateListHeight())
            }
            .frame(width: 480)
            .background(
                VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                    .cornerRadius(10)
                    .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
            )
            .padding(.top, 4)
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
        }
    }
    
    private func calculateListHeight() -> CGFloat {
        let rowHeight: CGFloat = 38
        let visibleCount = min(viewModel.suggestions.count, 5)
        let padding: CGFloat = 12
        return CGFloat(visibleCount) * rowHeight + padding
    }
}
