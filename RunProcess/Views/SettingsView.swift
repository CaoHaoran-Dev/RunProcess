//
//  SettingsView.swift
//  RunProcess
//
//  Created by Haoran on 2026/9/13.
//

import SwiftUI
internal import AppKit
import KeyboardShortcuts

// MARK: - 分类

enum SettingsCategory: String, CaseIterable, Identifiable {
    case general
    case appearance
    case session
    case workingDirectory
    case sudo

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general:          return NSLocalizedString("settings.category.general", comment: "")
        case .appearance:       return NSLocalizedString("settings.category.appearance", comment: "")
        case .session:          return NSLocalizedString("settings.category.session", comment: "")
        case .workingDirectory: return NSLocalizedString("settings.category.workingDirectory", comment: "")
        case .sudo:             return NSLocalizedString("settings.category.sudo", comment: "")
        }
    }

    var icon: String {
        switch self {
        case .general:          return "gearshape"
        case .appearance:       return "paintbrush"
        case .session:          return "terminal"
        case .workingDirectory: return "folder"
        case .sudo:             return "lock.shield"
        }
    }
}

// MARK: - 主视图

struct SettingsView: View {
    @State private var selected: SettingsCategory = .general

    @AppStorage(AppSettings.Keys.appearanceStyle) private var appearanceStyleRaw: String = AppSettings.appearanceStyleRaw.rawValue

    private var appearanceStyle: AppearanceStyle { AppSettings.resolvedAppearanceStyle }

    var body: some View {
        Group {
            if #available(macOS 13.0, *) {
                modernLayout
            } else {
                legacyLayout
            }
        }
        .frame(minWidth: 520, idealWidth: 560, minHeight: 300, idealHeight: 340)
        // ✅ 毛玻璃 / 液态玻璃背景
        .background(
            AdaptiveWindowBackground(
                style: appearanceStyle,
                material: .sidebar,
                blendingMode: .behindWindow
            )
            .ignoresSafeArea()
        )
    }

    @available(macOS 13.0, *)
    private var modernLayout: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailPane
        }
        .navigationTitle(NSLocalizedString("window.settings.title", comment: ""))
    }

    private var legacyLayout: some View {
        HStack(spacing: 0) {
            sidebar.frame(width: 170)
            Divider()
            detailPane
        }
    }

    private var sidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(SettingsCategory.allCases) { category in
                    CategoryRow(
                        category: category,
                        isSelected: category == selected,
                        onTap: { selected = category }
                    )
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 8)
        }
        // ✅ 侧边栏透明，让毛玻璃透出来
        .background(Color.clear)
    }

    private var detailPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                switch selected {
                case .general:          GeneralPane()
                case .appearance:       AppearancePane()
                case .session:          SessionPane()
                case .workingDirectory: WorkingDirectoryPane()
                case .sudo:             SudoPane()
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        // ✅ 内容区半透明
        .background(Color.clear)
    }
}

// MARK: - 侧边栏行

private struct CategoryRow: View {
    let category: SettingsCategory
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: category.icon)
                .font(.system(size: 12))
                .foregroundColor(isSelected ? .white : .accentColor)
                .frame(width: 16)
            Text(category.title)
                .font(.system(size: 12))
                .foregroundColor(isSelected ? .white : .primary)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(isSelected ? Color.accentColor : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }
}

// MARK: - 通用

private struct GeneralPane: View {
    @State private var hideOnDeactivate = AppSettings.hideOnDeactivate

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PaneTitle(NSLocalizedString("settings.category.general", comment: ""))

            SettingGroup {
                VStack(alignment: .leading, spacing: 6) {
                    Text(NSLocalizedString("settings.shortcut.toggle", comment: ""))
                        .font(.system(size: 12))
                    KeyboardShortcuts.Recorder(
                        NSLocalizedString("shortcut.toggle.window.label", comment: ""),
                        name: .toggleWindow
                    )
                    Text(NSLocalizedString("settings.shortcut.hint", comment: ""))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            SettingGroup {
                Toggle(isOn: $hideOnDeactivate) {
                    Text(NSLocalizedString("settings.window.hideOnDeactivate", comment: ""))
                        .font(.system(size: 12))
                }
                .onChange(of: hideOnDeactivate) { AppSettings.hideOnDeactivate = $0 }
            }

            if #available(macOS 13.0, *) {
                SettingGroup {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(NSLocalizedString("settings.section.language", comment: ""))
                            .font(.system(size: 12, weight: .medium))
                        Text(NSLocalizedString("settings.language.hint", comment: ""))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}

// MARK: - 外观

private struct AppearancePane: View {
    @State private var appearanceStyle = AppSettings.appearanceStyleRaw

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PaneTitle(NSLocalizedString("settings.category.appearance", comment: ""))

            SettingGroup {
                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("settings.appearance.style", comment: ""))
                        .font(.system(size: 12, weight: .medium))

                    Picker("", selection: $appearanceStyle) {
                        ForEach(AppearanceStyle.allCases.filter { $0.isSupported }, id: \.self) { style in
                            Text(NSLocalizedString(style.displayNameKey, comment: "")).tag(style)
                        }
                    }
                    .pickerStyle(.radioGroup)
                    .labelsHidden()
                    .onChange(of: appearanceStyle) { AppSettings.appearanceStyleRaw = $0 }

                    Text(NSLocalizedString("settings.appearance.hint", comment: ""))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

// MARK: - 会话

private struct SessionPane: View {
    @State private var sessionModeEnabled = AppSettings.sessionModeEnabled

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PaneTitle(NSLocalizedString("settings.category.session", comment: ""))

            SettingGroup {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle(isOn: $sessionModeEnabled) {
                        Text(NSLocalizedString("settings.session.enabled", comment: ""))
                            .font(.system(size: 12))
                    }
                    .onChange(of: sessionModeEnabled) { AppSettings.sessionModeEnabled = $0 }

                    Text(NSLocalizedString("settings.session.description", comment: ""))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(NSLocalizedString("settings.session.new.window.hint", comment: ""))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: - 工作目录

private struct WorkingDirectoryPane: View {
    @State private var workingDirectoryDisplay = AppSettings.displayWorkingDirectory
    @State private var workingDirectoryIsValid = AppSettings.isWorkingDirectoryValid

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PaneTitle(NSLocalizedString("settings.category.workingDirectory", comment: ""))

            SettingGroup {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(displayPath)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(workingDirectoryDisplay.isEmpty ? .secondary : .primary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.6))
                            )

                        Button(NSLocalizedString("settings.workingDirectory.choose", comment: "")) {
                            chooseWorkingDirectory()
                        }
                        .controlSize(.small)

                        Button(NSLocalizedString("settings.workingDirectory.reset", comment: "")) {
                            resetWorkingDirectory()
                        }
                        .controlSize(.small)
                        .disabled(workingDirectoryDisplay.isEmpty)
                    }

                    if !workingDirectoryIsValid {
                        Text(NSLocalizedString("settings.workingDirectory.invalid", comment: ""))
                            .font(.system(size: 11))
                            .foregroundColor(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Text(NSLocalizedString("settings.workingDirectory.new.window.hint", comment: ""))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var displayPath: String {
        if workingDirectoryDisplay.isEmpty {
            let home = FileManager.default.homeDirectoryForCurrentUser.path
            return (home as NSString).abbreviatingWithTildeInPath
        }
        return workingDirectoryDisplay
    }

    private func chooseWorkingDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = NSLocalizedString("settings.workingDirectory.panel.prompt", comment: "")

        if !workingDirectoryDisplay.isEmpty {
            let expanded = (workingDirectoryDisplay as NSString).expandingTildeInPath
            if FileManager.default.fileExists(atPath: expanded) {
                panel.directoryURL = URL(fileURLWithPath: expanded)
            }
        }

        if panel.runModal() == .OK, let url = panel.url {
            AppSettings.defaultWorkingDirectoryRaw = url.path
            workingDirectoryDisplay = (url.path as NSString).abbreviatingWithTildeInPath
            workingDirectoryIsValid = true
        }
    }

    private func resetWorkingDirectory() {
        AppSettings.defaultWorkingDirectoryRaw = ""
        workingDirectoryDisplay = ""
        workingDirectoryIsValid = true
    }
}

// MARK: - Sudo

private struct SudoPane: View {
    @State private var defaultSudo = AppSettings.defaultSudo

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PaneTitle(NSLocalizedString("settings.category.sudo", comment: ""))

            SettingGroup {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle(isOn: $defaultSudo) {
                        Text(NSLocalizedString("settings.sudo.default", comment: ""))
                            .font(.system(size: 12))
                    }
                    .onChange(of: defaultSudo) { AppSettings.defaultSudo = $0 }

                    Text(NSLocalizedString("settings.sudo.default.hint", comment: ""))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            SettingGroup {
                Text(NSLocalizedString("settings.sudo.hint", comment: ""))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - 通用小组件

private struct PaneTitle: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.system(size: 16, weight: .semibold))
    }
}

private struct SettingGroup<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
            )
    }
}
