//
//  AboutView.swift
//  RunProcess
//
//  Created by Haoran on 2026/9/13.
//

import SwiftUI

struct AboutView: View {
    @AppStorage(AppSettings.Keys.appearanceStyle) private var appearanceStyleRaw: String = AppSettings.appearanceStyleRaw.rawValue
    private var appearanceStyle: AppearanceStyle { AppSettings.resolvedAppearanceStyle }

    private var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 80, height: 80)

            VStack(spacing: 4) {
                Text("RunProcess").font(.title2.weight(.semibold))
                Text(NSLocalizedString("about.version", comment: "") + " " + version)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
            }

            Text(NSLocalizedString("about.description", comment: ""))
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            VStack(spacing: 8) {
                Link(destination: URL(string: "https://github.com/CaoHaoran-Dev/RunProcess")!) {
                    HStack(spacing: 6) {
                        Image(systemName: "link").font(.system(size: 11))
                        Text(NSLocalizedString("about.repository", comment: "")).font(.system(size: 12))
                    }
                }
                Link(destination: URL(string: "https://github.com/CaoHaoran-Dev/RunProcess/blob/main/LICENSE.md")!) {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.text").font(.system(size: 11))
                        Text(NSLocalizedString("about.license", comment: "")).font(.system(size: 12))
                    }
                }
            }
            .buttonStyle(.link)

            Text(NSLocalizedString("about.copyright", comment: ""))
                .font(.system(size: 10))
                .foregroundColor(.secondary.opacity(0.6))
                .padding(.top, 4)
        }
        .padding(28)
        .frame(width: 320)
        .fixedSize(horizontal: false, vertical: true)
        // ✅ 毛玻璃 / 液态玻璃 / 无
        .background(
            AdaptiveWindowBackground(
                style: appearanceStyle,
                material: .hudWindow,
                blendingMode: .behindWindow
            )
        )
    }
}
