//
//  GeneralPane.swift
//  RunProcess
//
//  Created by Haoran on 2026/10/18.
//

import SwiftUI
import KeyboardShortcuts

struct GeneralPane: View {
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
