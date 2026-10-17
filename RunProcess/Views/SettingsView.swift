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

private struct SidebarRow: View {
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

// MARK: - 通用

private struct GeneralPane: View {
    @State private var hideOnDeactivate = AppSettings.hideOnDeactivate

    var body: some View {
        Section {
            HStack {
                Text(NSLocalizedString("settings.shortcut.toggle", comment: ""))
                    .font(.system(size: 13))
                Spacer(minLength: 12)
                KeyboardShortcuts.Recorder(for: .toggleWindow)
            }

            Toggle(NSLocalizedString("settings.window.hideOnDeactivate", comment: ""), isOn: $hideOnDeactivate)
                .font(.system(size: 13))
                .onChange(of: hideOnDeactivate) { AppSettings.hideOnDeactivate = $0 }
        }

        if #available(macOS 13.0, *) {
            Section {
                Text(NSLocalizedString("settings.language.hint", comment: ""))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            } header: {
                Text(NSLocalizedString("settings.section.language", comment: ""))
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
        Section {
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
        } header: {
            Text(NSLocalizedString("settings.appearance.style", comment: ""))
        }

        Section {
            Toggle(NSLocalizedString("settings.output.colors.enabled", comment: ""), isOn: $outputColorsEnabled)
                .font(.system(size: 13))
                .onChange(of: outputColorsEnabled) { AppSettings.outputColorsEnabled = $0 }

            Picker(NSLocalizedString("settings.output.colors.scheme", comment: ""), selection: $outputColorScheme) {
                ForEach(AppSettings.OutputColorScheme.allCases, id: \.self) { scheme in
                    Text(NSLocalizedString(scheme.displayNameKey, comment: "")).tag(scheme)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: outputColorScheme) { AppSettings.outputColorScheme = $0 }
            .disabled(!outputColorsEnabled)
        }
    }
}

// MARK: - 会话

private struct SessionPane: View {
    @State private var sessionModeEnabled = AppSettings.sessionModeEnabled

    var body: some View {
        Section {
            Toggle(NSLocalizedString("settings.session.enabled", comment: ""), isOn: $sessionModeEnabled)
                .font(.system(size: 13))
                .onChange(of: sessionModeEnabled) { AppSettings.sessionModeEnabled = $0 }

            Text(NSLocalizedString("settings.session.description", comment: ""))
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            Text(NSLocalizedString("settings.session.new.window.hint", comment: ""))
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - 路径

private struct PathsPane: View {
    @State private var workingDirectoryDisplay = AppSettings.displayWorkingDirectory
    @State private var workingDirectoryIsValid = AppSettings.isWorkingDirectoryValid
    @State private var paths: [String] = PathStore.shared.paths

    var body: some View {
        // Section 1: 默认工作目录
        Section {
            HStack(spacing: 8) {
                Text(displayPath)
                    .font(.system(size: 12, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)

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
            }

            Text(NSLocalizedString("settings.workingDirectory.new.window.hint", comment: ""))
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        } header: {
            Text(NSLocalizedString("settings.workingDirectory.title", comment: ""))
        }

        // Section 2: 自定义路径列表
        Section {
            if paths.isEmpty {
                Text(NSLocalizedString("settings.paths.empty", comment: ""))
                    .foregroundColor(.secondary)
            } else {
                ForEach(Array(paths.enumerated()), id: \.offset) { idx, path in
                    PathRow(
                        path: path,
                        isFirst: idx == 0,
                        isLast: idx == paths.count - 1,
                        onDelete: {
                            PathStore.shared.remove(path)
                            reload()
                        },
                        onMoveUp: {
                            PathStore.shared.move(from: idx, to: idx - 1)
                            reload()
                        },
                        onMoveDown: {
                            PathStore.shared.move(from: idx, to: idx + 1)
                            reload()
                        }
                    )
                }
            }

            Button(NSLocalizedString("settings.paths.add", comment: "")) {
                choosePath()
            }

            Text(NSLocalizedString("settings.paths.hint", comment: ""))
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        } header: {
            Text(NSLocalizedString("settings.paths.title", comment: ""))
        }
        .onAppear {
            // ✅ 打开这个面板时重新读一遍 paths.yml，
            //    这样外部手动编辑文件后切到这里就能刷新。
            PathStore.shared.reload()
            paths = PathStore.shared.paths
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

    private func choosePath() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = NSLocalizedString("settings.paths.panel.prompt", comment: "")

        if panel.runModal() == .OK, let url = panel.url {
            PathStore.shared.add(url.path)
            reload()
        }
    }

    private func reload() {
        paths = PathStore.shared.paths
    }
}

// MARK: - 路径行

private struct PathRow: View {
    let path: String
    let isFirst: Bool
    let isLast: Bool
    let onDelete: () -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 8) {
            Text(path)
                .font(.system(size: 12, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundColor(isValid ? .primary : .red)

            Spacer(minLength: 0)

            if isHovering {
                HStack(spacing: 4) {
                    Button(action: onMoveUp) {
                        Image(systemName: "chevron.up").font(.system(size: 10))
                    }
                    .buttonStyle(.borderless)
                    .disabled(isFirst)

                    Button(action: onMoveDown) {
                        Image(systemName: "chevron.down").font(.system(size: 10))
                    }
                    .buttonStyle(.borderless)
                    .disabled(isLast)

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 10))
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
    }

    private var isValid: Bool {
        PathStore.shared.isValid(path)
    }
}

// MARK: - Sudo

private struct SudoPane: View {
    @State private var defaultSudo = AppSettings.defaultSudo

    var body: some View {
        Section {
            Toggle(NSLocalizedString("settings.sudo.default", comment: ""), isOn: $defaultSudo)
                .font(.system(size: 13))
                .onChange(of: defaultSudo) { AppSettings.defaultSudo = $0 }

            Text(NSLocalizedString("settings.sudo.default.hint", comment: ""))
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }

        Section {
            Text(NSLocalizedString("settings.sudo.hint", comment: ""))
                .font(.system(size: 11))
                .foregroundColor(.secondary)
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
        Section {
            if aliases.isEmpty {
                Text(NSLocalizedString("settings.aliases.empty", comment: ""))
                    .foregroundColor(.secondary)
            } else {
                ForEach(aliases) { alias in
                    HStack(spacing: 10) {
                        Text(alias.name)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .frame(width: 100, alignment: .leading)
                        Text("→")
                            .foregroundColor(.secondary)
                        Text(alias.expansion)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.secondary)
                        Spacer()
                        Button {
                            editing = alias
                        } label: {
                            Image(systemName: "pencil")
                        }
                        .buttonStyle(.borderless)
                        Button {
                            pendingDelete = alias
                            showDeleteConfirm = true
                        } label: {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }

            Button(NSLocalizedString("settings.aliases.add", comment: "")) {
                editing = CommandAlias(name: "", expansion: "")
            }

            Text(NSLocalizedString("settings.aliases.hint", comment: ""))
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .sheet(item: $editing) { item in
            AliasEditorSheet(
                alias: item,
                existingNames: aliases.map { $0.name },
                onSave: { newAlias in
                    saveAlias(newAlias, original: item)
                    editing = nil
                },
                onCancel: { editing = nil }
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
            Text(String(format: NSLocalizedString("settings.aliases.delete.message", comment: ""), alias.name))
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

    private func reload() {
        aliases = AliasStore.shared.aliases
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
                    Text(error).font(.system(size: 11)).foregroundColor(.red)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(NSLocalizedString("settings.aliases.field.expansion", comment: ""))
                    .font(.system(size: 12, weight: .medium))
                TextField("git status", text: $expansion)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13, design: .monospaced))
                if let error = expansionError, !expansion.isEmpty {
                    Text(error).font(.system(size: 11)).foregroundColor(.red)
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
        Section {
            Toggle(NSLocalizedString("settings.startup.launchAtLogin", comment: ""), isOn: $launchAtLogin)
                .font(.system(size: 13))
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

            if showLaunchError {
                Text(NSLocalizedString("settings.startup.launchAtLogin.error", comment: ""))
                    .font(.system(size: 11))
                    .foregroundColor(.red)
            }
        }

        Section {
            Toggle(NSLocalizedString("settings.startup.hideOnLaunch", comment: ""), isOn: $hideWindowOnLaunch)
                .font(.system(size: 13))
                .onChange(of: hideWindowOnLaunch) { AppSettings.hideWindowOnLaunch = $0 }

            Text(NSLocalizedString("settings.startup.hideOnLaunch.hint", comment: ""))
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - 更新

private struct UpdatesPane: View {
    @State private var automaticallyChecksForUpdates = true
    @State private var automaticallyDownloadsUpdates = false

    private var updater: SPUUpdater? {
        (NSApp.delegate as? AppDelegate)?.updaterControllerForSettings?.updater
    }

    var body: some View {
        Section {
            HStack {
                Text(NSLocalizedString("settings.updates.currentVersion", comment: ""))
                Spacer()
                Text(currentVersionString)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }

        Section {
            Toggle(NSLocalizedString("settings.updates.autoCheck", comment: ""), isOn: $automaticallyChecksForUpdates)
                .font(.system(size: 13))
                .onChange(of: automaticallyChecksForUpdates) { updater?.automaticallyChecksForUpdates = $0 }

            Toggle(NSLocalizedString("settings.updates.autoDownload", comment: ""), isOn: $automaticallyDownloadsUpdates)
                .font(.system(size: 13))
                .onChange(of: automaticallyDownloadsUpdates) { updater?.automaticallyDownloadsUpdates = $0 }

            Text(NSLocalizedString("settings.updates.note", comment: ""))
                .font(.system(size: 11))
                .foregroundColor(.secondary)
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
}
