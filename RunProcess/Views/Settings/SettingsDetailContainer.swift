//
//  SettingsDetailContainer.swift
//  RunProcess
//
//  Created by Haoran on 2026/11/11.
//

import SwiftUI

/// 二级列表里可点击的行：左内容 + 右 chevron。
struct SettingsListRow<Label: View>: View {
    let action: () -> Void
    @ViewBuilder var label: () -> Label

    init(action: @escaping () -> Void, @ViewBuilder label: @escaping () -> Label) {
        self.action = action
        self.label = label
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                label()
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary.opacity(0.6))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
