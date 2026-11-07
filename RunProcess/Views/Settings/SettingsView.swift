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
        HStack(spacing: 0) {
            sidebar
                .frame(width: 180)

            Divider()

            detailPane
                .frame(maxWidth: .infinity)
        }
        .frame(width: 720)
        .frame(minHeight: 480)
        .background(
            AdaptiveWindowBackground(
                style: appearanceStyle,
                material: .underWindowBackground,
                blendingMode: .behindWindow
            )
            .ignoresSafeArea()
        )
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
        .background(Color.clear)
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

    private var formContent: some View {
        Form {
            Section {
                VStack(spacing: 10) {
                    Image(systemName: selected.icon)
                        .font(.system(size: 48, weight: .light))
                        .foregroundColor(selected.iconColor)
                        .frame(height: 64)

                    Text(selected.title)
                        .font(.system(size: 20, weight: .semibold))

                    Text(selected.subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }

            switch selected {
            case .general:    GeneralPane()
            case .appearance: AppearancePane()
            case .session:    SessionPane()
            case .paths:      PathsPane()
            case .sudo:       SudoPane()
            case .aliases:    AliasesPane()
            case .startup:    StartupPane()
            case .updates:    UpdatesPane()
            }
        }
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
