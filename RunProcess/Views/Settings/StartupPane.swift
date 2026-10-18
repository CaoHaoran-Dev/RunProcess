//
//  StartupPane.swift
//  RunProcess
//
//  Created by Haoran on 2026/10/18.
//

import SwiftUI

struct StartupPane: View {
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
