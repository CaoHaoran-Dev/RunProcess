//
//  SudoPane.swift
//  RunProcess
//
//  Created by Haoran on 2026/10/18.
//

import SwiftUI

struct SudoPane: View {
    @State private var defaultSudo = AppSettings.defaultSudo

    var body: some View {
        Section {
            Toggle(NSLocalizedString("settings.sudo.default", comment: ""), isOn: $defaultSudo)
                .font(.system(size: 13))
                .onChange(of: defaultSudo) { AppSettings.defaultSudo = $0 }

            Text(NSLocalizedString("settings.sudo.default.hint", comment: ""))
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }

        Section {
            Text(NSLocalizedString("settings.sudo.hint", comment: ""))
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
    }
}
