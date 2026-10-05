//
//  SettingsView.swift
//  RunProcess
//
//  Created by Haoran on 2026/9/13.
//

import SwiftUI
internal import AppKit
import KeyboardShortcuts
import Sparkle

// MARK: - 分类

enum SettingsCategory: String, CaseIterable, Identifiable {
    case general
    case appearance
    case session
    case workingDirectory
    case sudo
    case aliases
    case startup
    case updates

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general:          return NSLocalizedString("settings.category.general", comment: "")
        case .appearance:       return NSLocalizedString("settings.category.appearance", comment: "")
        case .session:          return NSLocalizedString("settings.category.session", comment: "")
        case .workingDirectory: return NSLocalizedString("settings.category.workingDirectory", comment: "")
        case .sudo:             return NSLocalizedString("settings.category.sudo", comment: "")
        case .aliases:          return NSLocalizedString("settings.category.aliases", comment: "")
        case .startup:          return NSLocalizedString("settings.category.startup", comment: "")
        case .updates:          return NSLocalizedString("settings.category.updates", comment: "")
        }
    }

    var icon: String {
        switch self {
        case .general:          return "gearshape"
        case .appearance:       return "paintbrush"
        case .session:          return "terminal"
        case .workingDirectory: return "folder"
        case .sudo:             return "lock.shield"
        case .aliases:          return "wand.and.stars"
        case .startup:          return "power"
        case .updates:          return "arrow.triangle.2.circlepath"
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
                case .aliases:          AliasesPane()
                case .startup:          StartupPane()
                case .updates:          UpdatesPane()
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
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
    @State private var outputColorsEnabled = AppSettings.outputColorsEnabled
    @State private var outputColorScheme = AppSettings.outputColorScheme

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

            SettingGroup {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle(isOn: $outputColorsEnabled) {
                        Text(NSLocalizedString("settings.output.colors.enabled", comment: ""))
                            .font(.system(size: 12))
                    }
                    .onChange(of: outputColorsEnabled) { AppSettings.outputColorsEnabled = $0 }

                    Text(NSLocalizedString("settings.output.colors.hint", comment: ""))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Divider().padding(.vertical, 2)

                    HStack(spacing: 8) {
                        Text(NSLocalizedString("settings.output.colors.scheme", comment: ""))
                            .font(.system(size: 12))

                        Picker("", selection: $outputColorScheme) {
                            ForEach(AppSettings.OutputColorScheme.allCases, id: \.self) { scheme in
                                Text(NSLocalizedString(scheme.displayNameKey, comment: "")).tag(scheme)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(maxWidth: 220)
                        .onChange(of: outputColorScheme) { AppSettings.outputColorScheme = $0 }
                    }
                    .disabled(!outputColorsEnabled)
                    .opacity(outputColorsEnabled ? 1 : 0.5)
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

// MARK: - 别名

private struct AliasesPane: View {
    @State private var aliases: [CommandAlias] = AliasStore.shared.aliases
    @State private var editing: CommandAlias? = nil
    @State private var pendingDelete: CommandAlias? = nil
    @State private var showDeleteConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                PaneTitle(NSLocalizedString("settings.category.aliases", comment: ""))
                Spacer()
                Button {
                    editing = CommandAlias(name: "", expansion: "")
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12))
                }
                .buttonStyle(.borderless)
                .help(NSLocalizedString("settings.aliases.add", comment: ""))
            }

            SettingGroup {
                if aliases.isEmpty {
                    HStack {
                        Spacer()
                        Text(NSLocalizedString("settings.aliases.empty", comment: ""))
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.vertical, 20)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(aliases.enumerated()), id: \.element.id) { idx, alias in
                            AliasRow(
                                alias: alias,
                                isFirst: idx == 0,
                                isLast: idx == aliases.count - 1,
                                onEdit: {
                                    editing = alias
                                },
                                onDelete: {
                                    pendingDelete = alias
                                    showDeleteConfirm = true
                                },
                                onMoveUp: { moveAlias(from: idx, to: idx - 1) },
                                onMoveDown: { moveAlias(from: idx, to: idx + 1) }
                            )
                            if idx < aliases.count - 1 {
                                Divider().opacity(0.4)
                            }
                        }
                    }
                }
            }

            Text(NSLocalizedString("settings.aliases.hint", comment: ""))
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .sheet(item: $editing) { item in
            AliasEditorSheet(
                alias: item,
                existingNames: aliases.map { $0.name },
                onSave: { newAlias in
                    saveAlias(newAlias, original: item)
                    editing = nil
                },
                onCancel: {
                    editing = nil
                }
            )
        }
        .alert(
            NSLocalizedString("settings.aliases.delete.title", comment: ""),
            isPresented: $showDeleteConfirm,
            presenting: pendingDelete
        ) { alias in
            Button(NSLocalizedString("button.cancel", comment: ""), role: .cancel) {}
            Button(NSLocalizedString("button.delete", comment: ""), role: .destructive) {
                deleteAlias(alias)
            }
        } message: { alias in
            Text(String(format: NSLocalizedString("settings.aliases.delete.message", comment: ""),
                        alias.name))
        }
    }

    private func saveAlias(_ alias: CommandAlias, original: CommandAlias) {
        if original.name != alias.name, !original.name.isEmpty {
            AliasStore.shared.remove(name: original.name)
        }
        AliasStore.shared.add(alias)
        reload()
    }

    private func deleteAlias(_ alias: CommandAlias) {
        AliasStore.shared.remove(name: alias.name)
        reload()
    }

    private func moveAlias(from: Int, to: Int) {
        guard to >= 0, to < aliases.count else { return }
        aliases.swapAt(from, to)
        AliasStore.shared.replaceAll(aliases)
    }

    private func reload() {
        aliases = AliasStore.shared.aliases
    }
}

// MARK: - 别名行

private struct AliasRow: View {
    let alias: CommandAlias
    let isFirst: Bool
    let isLast: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 10) {
            Text(alias.name)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .frame(width: 110, alignment: .leading)
                .lineLimit(1)

            Image(systemName: "arrow.right")
                .font(.system(size: 9))
                .foregroundColor(.secondary.opacity(0.5))

            Text(alias.expansion)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 0)

            if isHovering {
                HStack(spacing: 4) {
                    Button(action: onMoveUp) {
                        Image(systemName: "chevron.up").font(.system(size: 10))
                    }
                    .buttonStyle(.borderless)
                    .disabled(isFirst)
                    .help(NSLocalizedString("settings.aliases.moveUp", comment: ""))

                    Button(action: onMoveDown) {
                        Image(systemName: "chevron.down").font(.system(size: 10))
                    }
                    .buttonStyle(.borderless)
                    .disabled(isLast)
                    .help(NSLocalizedString("settings.aliases.moveDown", comment: ""))

                    Button(action: onEdit) {
                        Image(systemName: "pencil").font(.system(size: 10))
                    }
                    .buttonStyle(.borderless)
                    .help(NSLocalizedString("settings.aliases.edit", comment: ""))

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 10))
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.borderless)
                    .help(NSLocalizedString("settings.aliases.delete", comment: ""))
                }
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .onTapGesture(count: 2) { onEdit() }
    }
}

// MARK: - 别名编辑 Sheet

private struct AliasEditorSheet: View {
    let alias: CommandAlias
    let existingNames: [String]
    let onSave: (CommandAlias) -> Void
    let onCancel: () -> Void

    @State private var name: String
    @State private var expansion: String
    @FocusState private var nameFocused: Bool

    init(alias: CommandAlias,
         existingNames: [String],
         onSave: @escaping (CommandAlias) -> Void,
         onCancel: @escaping () -> Void) {
        self.alias = alias
        self.existingNames = existingNames
        self.onSave = onSave
        self.onCancel = onCancel
        _name = State(initialValue: alias.name)
        _expansion = State(initialValue: alias.expansion)
    }

    private var isEditing: Bool { !alias.name.isEmpty }
    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }
    private var trimmedExpansion: String { expansion.trimmingCharacters(in: .whitespaces) }

    private var nameError: String? {
        if trimmedName.isEmpty { return NSLocalizedString("settings.aliases.error.empty", comment: "") }
        if trimmedName.contains(" ") { return NSLocalizedString("settings.aliases.error.space", comment: "") }
        if trimmedName != alias.name, existingNames.contains(trimmedName) {
            return NSLocalizedString("settings.aliases.error.duplicate", comment: "")
        }
        return nil
    }

    private var expansionError: String? {
        if trimmedExpansion.isEmpty { return NSLocalizedString("settings.aliases.error.empty", comment: "") }
        return nil
    }

    private var canSave: Bool { nameError == nil && expansionError == nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 16))
                    .foregroundColor(.accentColor)
                Text(isEditing
                     ? NSLocalizedString("settings.aliases.edit.title", comment: "")
                     : NSLocalizedString("settings.aliases.add.title", comment: ""))
                    .font(.headline)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(NSLocalizedString("settings.aliases.field.name", comment: ""))
                    .font(.system(size: 12, weight: .medium))
                TextField("gs", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13, design: .monospaced))
                    .focused($nameFocused)
                    .onAppear { nameFocused = true }
                if let error = nameError, !name.isEmpty {
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundColor(.red)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(NSLocalizedString("settings.aliases.field.expansion", comment: ""))
                    .font(.system(size: 12, weight: .medium))
                TextField("git status", text: $expansion)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13, design: .monospaced))
                if let error = expansionError, !expansion.isEmpty {
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundColor(.red)
                }
            }

            Text(NSLocalizedString("settings.aliases.editor.hint", comment: ""))
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                Spacer()
                Button(NSLocalizedString("button.cancel", comment: "")) { onCancel() }
                    .keyboardShortcut(.escape)
                Button(NSLocalizedString("button.save", comment: "")) {
                    onSave(CommandAlias(name: trimmedName, expansion: trimmedExpansion))
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(!canSave)
            }
        }
        .padding(20)
        .frame(width: 400)
    }
}

// MARK: - 启动

private struct StartupPane: View {
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var hideWindowOnLaunch = AppSettings.hideWindowOnLaunch
    @State private var showLaunchError = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PaneTitle(NSLocalizedString("settings.category.startup", comment: ""))

            SettingGroup {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle(isOn: $launchAtLogin) {
                        Text(NSLocalizedString("settings.startup.launchAtLogin", comment: ""))
                            .font(.system(size: 12))
                    }
                    .disabled(!LaunchAtLogin.isSupported)
                    .onChange(of: launchAtLogin) { newValue in
                        let ok = LaunchAtLogin.setEnabled(newValue)
                        if !ok {
                            launchAtLogin = LaunchAtLogin.isEnabled
                            showLaunchError = true
                        } else {
                            showLaunchError = false
                        }
                    }

                    Text(LaunchAtLogin.isSupported
                         ? NSLocalizedString("settings.startup.launchAtLogin.hint", comment: "")
                         : NSLocalizedString("settings.startup.launchAtLogin.unsupported", comment: ""))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if showLaunchError {
                        Text(NSLocalizedString("settings.startup.launchAtLogin.error", comment: ""))
                            .font(.system(size: 11))
                            .foregroundColor(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            SettingGroup {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle(isOn: $hideWindowOnLaunch) {
                        Text(NSLocalizedString("settings.startup.hideOnLaunch", comment: ""))
                            .font(.system(size: 12))
                    }
                    .onChange(of: hideWindowOnLaunch) { AppSettings.hideWindowOnLaunch = $0 }

                    Text(NSLocalizedString("settings.startup.hideOnLaunch.hint", comment: ""))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

// MARK: - 更新

private struct UpdatesPane: View {
    @State private var automaticallyChecksForUpdates = true
    @State private var automaticallyDownloadsUpdates = false
    @State private var lastCheckDate: Date? = nil
    @State private var isChecking = false
    @State private var statusMessage: String? = nil

    private var updater: SPUUpdater? {
        (NSApp.delegate as? AppDelegate)?.updaterControllerForSettings?.updater
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PaneTitle(NSLocalizedString("settings.category.updates", comment: ""))

            // 当前版本
            SettingGroup {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(NSLocalizedString("settings.updates.currentVersion", comment: ""))
                            .font(.system(size: 12))
                        Spacer()
                        Text(currentVersionString)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    Text(NSLocalizedString("settings.updates.currentVersion.hint", comment: ""))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            // 检查更新
            SettingGroup {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Button {
                            checkForUpdates()
                        } label: {
                            HStack(spacing: 4) {
                                if isChecking {
                                    ProgressView().controlSize(.small)
                                }
                                Text(NSLocalizedString("settings.updates.checkNow", comment: ""))
                            }
                        }
                        .disabled(isChecking)

                        Spacer()

                        if let date = lastCheckDate {
                            Text(String(
                                format: NSLocalizedString("settings.updates.lastCheck", comment: ""),
                                formatted(date)
                            ))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        }
                    }

                    if let msg = statusMessage {
                        Text(msg)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            // 自动更新
            SettingGroup {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle(isOn: $automaticallyChecksForUpdates) {
                        Text(NSLocalizedString("settings.updates.autoCheck", comment: ""))
                            .font(.system(size: 12))
                    }
                    .onChange(of: automaticallyChecksForUpdates) { newValue in
                        updater?.automaticallyChecksForUpdates = newValue
                    }

                    Text(NSLocalizedString("settings.updates.autoCheck.hint", comment: ""))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Divider().padding(.vertical, 2)

                    Toggle(isOn: $automaticallyDownloadsUpdates) {
                        Text(NSLocalizedString("settings.updates.autoDownload", comment: ""))
                            .font(.system(size: 12))
                    }
                    .onChange(of: automaticallyDownloadsUpdates) { newValue in
                        updater?.automaticallyDownloadsUpdates = newValue
                    }

                    Text(NSLocalizedString("settings.updates.autoDownload.hint", comment: ""))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            SettingGroup {
                Text(NSLocalizedString("settings.updates.note", comment: ""))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onAppear {
            automaticallyChecksForUpdates = updater?.automaticallyChecksForUpdates ?? true
            automaticallyDownloadsUpdates = updater?.automaticallyDownloadsUpdates ?? false
        }
    }

    private var currentVersionString: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(v) (\(b))"
    }

    private func formatted(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f.string(from: date)
    }

    private func checkForUpdates() {
        isChecking = true
        statusMessage = nil
        (NSApp.delegate as? AppDelegate)?.checkForUpdatesFromSettings()
        lastCheckDate = Date()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isChecking = false
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
