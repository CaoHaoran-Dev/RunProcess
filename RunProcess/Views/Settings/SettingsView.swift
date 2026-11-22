//
//  SettingsView.swift
//  RunProcess
//
//  Created by Haoran on 2026/10/18.
//

import SwiftUI
internal import AppKit

// MARK: - 分类

enum SettingsCategory: String, CaseIterable, Identifiable {
    case general
    case appearance
    case session
    case paths
    case sudo
    case aliases
    case workflows
    case remote
    case startup
    case updates

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general:    return NSLocalizedString("settings.category.general", comment: "")
        case .appearance: return NSLocalizedString("settings.category.appearance", comment: "")
        case .session:    return NSLocalizedString("settings.category.session", comment: "")
        case .paths:      return NSLocalizedString("settings.category.paths", comment: "")
        case .sudo:       return NSLocalizedString("settings.category.sudo", comment: "")
        case .aliases:    return NSLocalizedString("settings.category.aliases", comment: "")
        case .workflows:  return NSLocalizedString("settings.category.workflows", comment: "")
        case .remote:     return NSLocalizedString("settings.category.remote", comment: "")
        case .startup:    return NSLocalizedString("settings.category.startup", comment: "")
        case .updates:    return NSLocalizedString("settings.category.updates", comment: "")
        }
    }

    var icon: String {
        switch self {
        case .general:    return "gearshape"
        case .appearance: return "paintbrush"
        case .session:    return "terminal"
        case .paths:      return "folder"
        case .sudo:       return "lock.shield"
        case .aliases:    return "wand.and.stars"
        case .workflows:  return "doc.text.fill"
        case .remote:     return "server.rack"
        case .startup:    return "power"
        case .updates:    return "arrow.triangle.2.circlepath"
        }
    }

    var iconColor: Color {
        switch self {
        case .general:    return .gray
        case .appearance: return .blue
        case .session:    return .indigo
        case .paths:      return .teal
        case .sudo:       return .red
        case .aliases:    return .purple
        case .workflows:  return .blue
        case .remote:     return .green
        case .startup:    return .orange
        case .updates:    return .green
        }
    }

    var subtitle: String {
        switch self {
        case .general:    return NSLocalizedString("settings.general.subtitle", comment: "")
        case .appearance: return NSLocalizedString("settings.appearance.subtitle", comment: "")
        case .session:    return NSLocalizedString("settings.session.subtitle", comment: "")
        case .paths:      return NSLocalizedString("settings.paths.subtitle", comment: "")
        case .sudo:       return NSLocalizedString("settings.sudo.subtitle", comment: "")
        case .aliases:    return NSLocalizedString("settings.aliases.subtitle", comment: "")
        case .workflows:  return NSLocalizedString("settings.workflows.subtitle", comment: "")
        case .remote:     return NSLocalizedString("settings.remote.subtitle", comment: "")
        case .startup:    return NSLocalizedString("settings.startup.subtitle", comment: "")
        case .updates:    return NSLocalizedString("settings.updates.subtitle", comment: "")
        }
    }
}

// MARK: - 主视图

struct SettingsView: View {
    @State private var selected: SettingsCategory = .general

    @AppStorage(AppSettings.Keys.appearanceStyle) private var appearanceStyleRaw: String = AppSettings.appearanceStyleRaw.rawValue
    private var appearanceStyle: AppearanceStyle { AppSettings.resolvedAppearanceStyle }

    var body: some View {
        VStack(spacing: 0) {
            glassTitleBar

            HStack(spacing: 0) {
                sidebar
                    .frame(width: 180)

                Divider()

                detailPane
                    .frame(maxWidth: .infinity)
            }
        }
        .ignoresSafeArea(edges: .top)
        .frame(width: 720)
        .frame(minHeight: 480)
        .background(
            AdaptiveWindowBackground(
                style: appearanceStyle,
            )
            .ignoresSafeArea()
        )
    }

    /// 自绘的玻璃标题栏：占用系统标题栏的高度，压在内容之上，
    /// 材质跟随外观设置（纯色 / 毛玻璃 / 液态玻璃）。
    private var glassTitleBar: some View {
        Text(NSLocalizedString("window.settings.title", comment: ""))
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity)
            .frame(height: 28)
            .background(
                AdaptiveGlassBackground(
                    style: appearanceStyle,
                    material: .titlebar,
                    // .withinWindow 采样的是窗口内部已有的毛玻璃，
                    // 叠上去只剩一层平的半透明；必须 .behindWindow 才会
                    // 直接对桌面做模糊，得到真正的毛玻璃颗粒。
                    blendingMode: .behindWindow,
                    cornerRadius: 0
                )
            )
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.primary.opacity(0.08))
                    .frame(height: 1)
            }
    }

    private var sidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 1) {
                ForEach(SettingsCategory.allCases) { category in
                    SidebarRow(
                        category: category,
                        isSelected: category == selected,
                        onTap: { selected = category }
                    )
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 10)
        }
        // 侧边栏去掉白色滚动槽。
        .background(ScrollViewStyler())
    }

    private var detailPane: some View {
        Group {
            if #available(macOS 13.0, *) {
                formContent
                    .formStyle(.grouped)
                    .scrollContentBackground(.hidden)
            } else {
                formContent
            }
        }
        .frame(maxWidth: 540)
        .frame(maxWidth: .infinity, alignment: .center)
    }
    
    // 所有 Pane 共用的顶部「图标 + 标题 + 简介」头部。
    @ViewBuilder
    private func headerView(for category: SettingsCategory) -> some View {
        VStack(spacing: 10) {
            Image(systemName: category.icon)
                .font(.system(size: 48, weight: .light))
                .foregroundColor(category.iconColor)
                .frame(height: 64)

            Text(category.title)
                .font(.system(size: 20, weight: .semibold))

            Text(category.subtitle)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
    }

    private var formContent: some View {
        Form {
            Section {
                headerView(for: selected)
                    .listRowBackground(Color.clear)
            }

            switch selected {
            case .general:    GeneralPane()
            case .appearance: AppearancePane()
            case .session:    SessionPane()
            case .paths:      PathsPane()
            case .sudo:       SudoPane()
            case .aliases:    AliasesPane()
            case .workflows:  WorkflowsPane()
            case .remote:
                if #available(macOS 13.0, *) {
                    RemoteHostsPane()
                } else {
                    Text(NSLocalizedString("settings.remote.unsupported", comment: ""))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                }
            case .startup:    StartupPane()
            case .updates:    UpdatesPane()
            }
        }
        // 叠加式滚动条 + 透明底色，避免毛玻璃上露出白色轨道。
        .background(ScrollViewStyler())
    }
}

// MARK: - 侧边栏行

struct SidebarRow: View {
    let category: SettingsCategory
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: category.icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isSelected ? .white : category.iconColor)
                    .frame(width: 18, height: 18)

                Text(category.title)
                    .font(.system(size: 13))
                    .foregroundColor(isSelected ? .white : .primary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isSelected
                          ? Color(nsColor: .selectedContentBackgroundColor)
                          : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
