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
