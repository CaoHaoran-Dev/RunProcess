//
//  SettingsView.swift
//  RunProcess
//
//  Created by Haoran on 2026/9/13.
//

import SwiftUI
internal import AppKit
import KeyboardShortcuts

struct SettingsView: View {
    @State private var sessionModeEnabled: Bool = AppSettings.sessionModeEnabled
    @State private var workingDirectoryDisplay: String = AppSettings.displayWorkingDirectory
    @State private var workingDirectoryIsValid: Bool = AppSettings.isWorkingDirectoryValid
    @State private var appearanceStyle: AppearanceStyle = AppSettings.appearanceStyleRaw
    @State private var hideOnDeactivate: Bool = AppSettings.hideOnDeactivate
    
    var body: some View {
        Form {
            Section(NSLocalizedString("settings.section.shortcut", comment: "Shortcut section")) {
                KeyboardShortcuts.Recorder(
                    NSLocalizedString("shortcut.toggle.window.label", comment: "Toggle window shortcut label"),
                    name: .toggleWindow
                )
            }
            
            // ✅ 语言区块，仅 macOS 13+ 显示
            if #available(macOS 13.0, *) {
                Section(NSLocalizedString("settings.section.language", comment: "Language section")) {
                    Text(NSLocalizedString("settings.language.hint", comment: "Language hint"))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            Section(NSLocalizedString("settings.section.window", comment: "Window section")) {
                Toggle(isOn: $hideOnDeactivate) {
                    Text(NSLocalizedString("settings.window.hideOnDeactivate", comment: "Hide on deactivate toggle"))
                }
                .onChange(of: hideOnDeactivate) { newValue in
                    AppSettings.hideOnDeactivate = newValue
                }
            }
            
            Section(NSLocalizedString("settings.section.appearance", comment: "Appearance section")) {
                Picker(
                    NSLocalizedString("settings.appearance.style", comment: "Appearance style label"),
                    selection: $appearanceStyle
                ) {
                    ForEach(AppearanceStyle.allCases.filter { $0.isSupported }, id: \.self) { style in
                        Text(NSLocalizedString(style.displayNameKey, comment: "Appearance style"))
                            .tag(style)
                    }
                }
                .pickerStyle(.radioGroup)
                .onChange(of: appearanceStyle) { newValue in
                    AppSettings.appearanceStyleRaw = newValue
                }
            }
            
            Section(NSLocalizedString("settings.section.session", comment: "Session section")) {
                Toggle(isOn: $sessionModeEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(NSLocalizedString("settings.session.enabled", comment: "Session mode toggle"))
                        Text(NSLocalizedString("settings.session.description", comment: "Session mode description"))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                .onChange(of: sessionModeEnabled) { newValue in
                    AppSettings.sessionModeEnabled = newValue
                }
                
                Text(NSLocalizedString("settings.session.new.window.hint", comment: "Only affects new windows"))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            Section(NSLocalizedString("settings.section.workingDirectory", comment: "Working directory section")) {
                workingDirectoryRow
                
                if !workingDirectoryIsValid {
                    Text(NSLocalizedString("settings.workingDirectory.invalid", comment: "Invalid path warning"))
                        .font(.system(size: 11))
                        .foregroundColor(.red)
                }
                
                Text(NSLocalizedString("settings.workingDirectory.new.window.hint", comment: "Only affects new windows"))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            Section(NSLocalizedString("settings.section.sudo", comment: "Sudo section")) {
                Text(NSLocalizedString("settings.sudo.hint", comment: "Sudo hint"))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding(20)
        .frame(width: 460, height: 680)
    }
    
    // MARK: - 工作目录行
    
    private var workingDirectoryRow: some View {
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
                        .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
                )
            
            Button(NSLocalizedString("settings.workingDirectory.choose", comment: "Choose button")) {
                chooseWorkingDirectory()
            }
            .controlSize(.small)
            
            Button(NSLocalizedString("settings.workingDirectory.reset", comment: "Reset button")) {
                resetWorkingDirectory()
            }
            .controlSize(.small)
            .disabled(workingDirectoryDisplay.isEmpty)
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
        panel.prompt = NSLocalizedString("settings.workingDirectory.panel.prompt", comment: "Open panel prompt")
        
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
