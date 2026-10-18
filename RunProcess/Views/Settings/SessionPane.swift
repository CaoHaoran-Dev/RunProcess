//
//  SessionPane.swift
//  RunProcess
//
//  Created by Haoran on 2026/10/18.
//

import SwiftUI

struct SessionPane: View {
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
