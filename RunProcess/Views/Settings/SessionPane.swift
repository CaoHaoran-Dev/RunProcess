//
//  SessionPane.swift
//  RunProcess
//
//  Created by Haoran on 2026/10/18.
//

import SwiftUI

struct SessionPane: View {
    @State private var sessionModeEnabled = AppSettings.sessionModeEnabled
    @State private var isZsh = AppSettings.isZshShell

    var body: some View {
        Section {
            Toggle(NSLocalizedString("settings.session.enabled", comment: ""), isOn: $sessionModeEnabled)
                .font(.system(size: 13))
                .disabled(!isZsh)
                .onChange(of: sessionModeEnabled) { AppSettings.sessionModeEnabled = $0 }

            Text(NSLocalizedString("settings.session.description", comment: ""))
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            if !isZsh {
                Text(NSLocalizedString("settings.session.requiresZsh", comment: ""))
                    .font(.system(size: 11))
                    .foregroundColor(.orange)
            }

            Text(NSLocalizedString("settings.session.new.window.hint", comment: ""))
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .onAppear {
            isZsh = AppSettings.isZshShell
            if !isZsh { sessionModeEnabled = false }
        }
        .onReceive(NotificationCenter.default.publisher(for: .runProcessShellDidChange)) { _ in
            isZsh = AppSettings.isZshShell
            if !isZsh { sessionModeEnabled = false }
        }
    }
}
