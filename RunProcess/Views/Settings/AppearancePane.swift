//
//  AppearancePane.swift
//  RunProcess
//
//  Created by Haoran on 2026/10/18.
//

import SwiftUI

struct AppearancePane: View {
    @State private var appearanceStyle = AppSettings.appearanceStyleRaw
    @State private var outputColorsEnabled = AppSettings.outputColorsEnabled
    @State private var outputColorScheme = AppSettings.outputColorScheme
    
    @State private var uiMode = AppSettings.mainUIMode

    var body: some View {
        #if BETA
        Section {
            Picker(NSLocalizedString("settings.appearance.uiMode", comment: ""), selection: $uiMode) {
                ForEach(MainUIMode.allCases, id: \.self) { mode in
                    Text(NSLocalizedString(mode.displayNameKey, comment: "")).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: uiMode) { AppSettings.mainUIMode = $0 }
            
            // 👇 增加提示，告诉用户新建窗口后生效
            Text(NSLocalizedString("settings.appearance.uiMode.restartHint", comment: ""))
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        } header: {
            Text(NSLocalizedString("settings.appearance.uiMode.header", comment: ""))
        }
        #endif

        Section {
            Picker("", selection: $appearanceStyle) {
                ForEach(AppearanceStyle.allCases.filter { $0.isSupported }, id: \.self) { style in
                    Text(NSLocalizedString(style.displayNameKey, comment: "")).tag(style)
                }
            }
            .pickerStyle(.radioGroup)
            .labelsHidden()
            .onChange(of: appearanceStyle) { AppSettings.appearanceStyleRaw = $0 }

            Text(NSLocalizedString("settings.appearance.hint", comment: ""))
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        } header: {
            Text(NSLocalizedString("settings.appearance.style", comment: ""))
        }

        Section {
            Toggle(NSLocalizedString("settings.output.colors.enabled", comment: ""), isOn: $outputColorsEnabled)
                .font(.system(size: 13))
                .onChange(of: outputColorsEnabled) { AppSettings.outputColorsEnabled = $0 }

            Picker(NSLocalizedString("settings.output.colors.scheme", comment: ""), selection: $outputColorScheme) {
                ForEach(AppSettings.OutputColorScheme.allCases, id: \.self) { scheme in
                    Text(NSLocalizedString(scheme.displayNameKey, comment: "")).tag(scheme)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: outputColorScheme) { AppSettings.outputColorScheme = $0 }
            .disabled(!outputColorsEnabled)
        }
    }
}
