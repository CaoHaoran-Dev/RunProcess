//
//  GeneralPane.swift
//  RunProcess
//
//  Created by Haoran on 2026/10/18.
//

import SwiftUI
import KeyboardShortcuts
internal import AppKit

struct GeneralPane: View {
    @State private var hideOnDeactivate = AppSettings.hideOnDeactivate

    @State private var shells: [ShellStore.Entry] = ShellStore.shared.availableShells()
    @State private var selectedShell: String = AppSettings.resolvedShellPath

    /// 由 selectedShell 派生，切换时 body 自动重算
    private var isZsh: Bool {
        (selectedShell as NSString).lastPathComponent == "zsh"
    }

    var body: some View {
        Group {
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

            // Shell 选择
            Section {
                Picker(NSLocalizedString("settings.shell.select", comment: ""), selection: $selectedShell) {
                    ForEach(shells) { entry in
                        Text(entry.path).tag(entry.path)
                    }
                    if !shells.contains(where: { $0.path == selectedShell }) {
                        Text(selectedShell).tag(selectedShell)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: selectedShell) { newValue in
                    ShellStore.shared.selectShell(path: newValue)
                    selectedShell = AppSettings.resolvedShellPath
                    NotificationCenter.default.post(name: .runProcessShellDidChange, object: nil)
                }

                Button(NSLocalizedString("settings.shell.add", comment: "")) {
                    addCustomShell()
                }
                .controlSize(.small)

                if !isZsh {
                    Text(NSLocalizedString("settings.shell.nonZshHint", comment: ""))
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                }
            } header: {
                Text(NSLocalizedString("settings.shell.header", comment: ""))
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
        .onAppear {
            refreshShells()
        }
    }

    private func refreshShells() {
        shells = ShellStore.shared.availableShells()
        selectedShell = AppSettings.resolvedShellPath
        if !shells.contains(where: { $0.path == selectedShell }) {
            shells.append(ShellStore.Entry(path: selectedShell))
        }
    }

    private func addCustomShell() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = NSLocalizedString("settings.shell.add.prompt", comment: "")
        panel.directoryURL = URL(fileURLWithPath: "/bin")

        if panel.runModal() == .OK, let url = panel.url {
            ShellStore.shared.addCustomShell(path: url.path)
            refreshShells()
            NotificationCenter.default.post(name: .runProcessShellDidChange, object: nil)
        }
    }
}
