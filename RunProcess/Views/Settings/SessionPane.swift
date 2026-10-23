//
//  SessionPane.swift
//  RunProcess
//
//  Created by Haoran on 2026/10/18.
//

import SwiftUI

struct SessionPane: View {
    @State private var sessionModeEnabled = AppSettings.sessionModeEnabled

    #if BETA
    @State private var isZsh = AppSettings.isZshShell
    #endif

    var body: some View {
        Section {
            Toggle(NSLocalizedString("settings.session.enabled", comment: ""), isOn: $sessionModeEnabled)
                .font(.system(size: 13))
                #if BETA
                .disabled(!isZsh)
                #endif
                .onChange(of: sessionModeEnabled) { AppSettings.sessionModeEnabled = $0 }

            Text(NSLocalizedString("settings.session.description", comment: ""))
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            #if BETA
            if !isZsh {
                Text(NSLocalizedString("settings.session.requiresZsh", comment: ""))
                    .font(.system(size: 11))
                    .foregroundColor(.orange)
            }
            #endif

            Text(NSLocalizedString("settings.session.new.window.hint", comment: ""))
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        #if BETA
        .onAppear {
            isZsh = AppSettings.isZshShell
            if !isZsh { sessionModeEnabled = false }
        }
        #endif
    }
}
