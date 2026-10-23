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

    #if BETA
    @State private var shells: [ShellStore.Entry] = ShellStore.shared.availableShells()
    @State private var selectedShell: String = AppSettings.resolvedShellPath
    #endif

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

        #if BETA
        // 👇 Beta 专属：Shell 选择
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
            }

            Button(NSLocalizedString("settings.shell.add", comment: "")) {
                addCustomShell()
            }
            .controlSize(.small)

            if !AppSettings.isZshShell {
                Text(NSLocalizedString("settings.shell.nonZshHint", comment: ""))
                    .font(.system(size: 11))
                    .foregroundColor(.orange)
            }
        } header: {
            Text(NSLocalizedString("settings.shell.header", comment: ""))
        }
        #endif

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

    #if BETA
    private func addCustomShell() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = NSLocalizedString("settings.shell.add.prompt", comment: "")
        panel.directoryURL = URL(fileURLWithPath: "/bin")

        if panel.runModal() == .OK, let url = panel.url {
            ShellStore.shared.addCustomShell(path: url.path)
            shells = ShellStore.shared.availableShells()
            selectedShell = AppSettings.resolvedShellPath
        }
    }
    #endif
}
