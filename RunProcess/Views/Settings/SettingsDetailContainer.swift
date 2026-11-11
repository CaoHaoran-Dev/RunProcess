//
//  SettingsDetailContainer.swift
//  RunProcess
//
//  Created by Haoran on 2026/11/11.
//

import SwiftUI

/// 设置右栏的统一容器。
/// - 单页 Pane：`onBack` 为 nil，不显示返回栏。
/// - 二级详情页：传 `onBack` 与标题，顶部显示“‹ 返回 + 标题”，无动画。
struct SettingsDetailContainer<Content: View>: View {
    let title: String?
    let onBack: (() -> Void)?
    @ViewBuilder var content: () -> Content

    init(title: String? = nil,
         onBack: (() -> Void)? = nil,
         @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.onBack = onBack
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let onBack {
                backBar(onBack: onBack)
                Divider()
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    content()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .frame(maxWidth: 560, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    private func backBar(onBack: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            Button {
                onBack()
            } label: {
                HStack(spacing: 2) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .semibold))
                    Text(NSLocalizedString("button.back", comment: ""))
                        .font(.system(size: 12))
                }
            }
            .buttonStyle(.plain)
            .foregroundColor(.accentColor)

            if let title, !title.isEmpty {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }
}

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
