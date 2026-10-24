//
//  UpdatesPane.swift
//  RunProcess
//
//  Created by Haoran on 2026/10/18.
//

import SwiftUI
internal import AppKit
import Sparkle

struct UpdatesPane: View {
    @State private var automaticallyChecksForUpdates = true
    @State private var automaticallyDownloadsUpdates = false

    // 显式指定类型
    @State private var updateChannel: AppSettings.UpdateChannel = AppSettings.updateChannel
    @State private var customURL: String = AppSettings.customUpdateURL

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
            Picker(NSLocalizedString("settings.updates.channel", comment: ""), selection: $updateChannel) {
                ForEach(AppSettings.UpdateChannel.allCases, id: \.self) { channel in
                    Text(NSLocalizedString(channel.displayNameKey, comment: "")).tag(channel)
                }
            }
            .onChange(of: updateChannel) { newValue in
                AppSettings.updateChannel = newValue
                refreshSource()
            }

            if updateChannel == .custom {
                TextField(NSLocalizedString("settings.updates.custom.url.placeholder", comment: ""), text: $customURL)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { refreshSource() }
            }
        } header: {
            Text(NSLocalizedString("settings.updates.channel", comment: ""))
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

    private func refreshSource() {
        AppSettings.updateChannel = updateChannel
        AppSettings.customUpdateURL = customURL
        (NSApp.delegate as? AppDelegate)?.updateFeedURLPreference()
    }

    private var currentVersionString: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(v) (\(b))"
    }
}
