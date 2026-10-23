//
//  PathsPane.swift
//  RunProcess
//
//  Created by Haoran on 2026/10/18.
//

import SwiftUI
internal import AppKit

struct PathsPane: View {
    @State private var workingDirectoryDisplay = AppSettings.displayWorkingDirectory
    @State private var workingDirectoryIsValid = AppSettings.isWorkingDirectoryValid
    @State private var paths: [String] = PathStore.shared.paths

    #if BETA
    @State private var customPathEnabled = AppSettings.customPathEnabled
    @State private var isZsh = AppSettings.isZshShell
    #endif

    var body: some View {
        // Section 1: 默认工作目录
        Section {
            HStack(spacing: 8) {
                Text(displayPath)
                    .font(.system(size: 12, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button(NSLocalizedString("settings.workingDirectory.choose", comment: "")) {
                    chooseWorkingDirectory()
                }
                .controlSize(.small)

                Button(NSLocalizedString("settings.workingDirectory.reset", comment: "")) {
                    resetWorkingDirectory()
                }
                .controlSize(.small)
                .disabled(workingDirectoryDisplay.isEmpty)
            }

            if !workingDirectoryIsValid {
                Text(NSLocalizedString("settings.workingDirectory.invalid", comment: ""))
                    .font(.system(size: 11))
                    .foregroundColor(.red)
            }

            Text(NSLocalizedString("settings.workingDirectory.new.window.hint", comment: ""))
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        } header: {
            Text(NSLocalizedString("settings.workingDirectory.title", comment: ""))
        }

        // Section 2: 自定义路径列表
        Section {
            #if BETA
            // 👇 Beta 专属：PATH 注入开关
            Toggle(NSLocalizedString("settings.paths.injectEnabled", comment: ""), isOn: $customPathEnabled)
                .font(.system(size: 13))
                .disabled(!isZsh)
                .onChange(of: customPathEnabled) { AppSettings.customPathEnabled = $0 }

            if !isZsh {
                Text(NSLocalizedString("settings.paths.requiresZsh", comment: ""))
                    .font(.system(size: 11))
                    .foregroundColor(.orange)
            }
            #endif

            if paths.isEmpty {
                Text(NSLocalizedString("settings.paths.empty", comment: ""))
                    .foregroundColor(.secondary)
            } else {
                ForEach(Array(paths.enumerated()), id: \.offset) { idx, path in
                    PathRow(
                        path: path,
                        isFirst: idx == 0,
                        isLast: idx == paths.count - 1,
                        onDelete: {
                            PathStore.shared.remove(path)
                            reload()
                        },
                        onMoveUp: {
                            PathStore.shared.move(from: idx, to: idx - 1)
                            reload()
                        },
                        onMoveDown: {
                            PathStore.shared.move(from: idx, to: idx + 1)
                            reload()
                        }
                    )
                }
            }

            Button(NSLocalizedString("settings.paths.add", comment: "")) {
                choosePath()
            }
            #if BETA
            .disabled(!isZsh && customPathEnabled)
            #endif

            Text(NSLocalizedString("settings.paths.hint", comment: ""))
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        } header: {
            Text(NSLocalizedString("settings.paths.title", comment: ""))
        }
        .onAppear {
            PathStore.shared.reload()
            paths = PathStore.shared.paths
            #if BETA
            isZsh = AppSettings.isZshShell
            if !isZsh { customPathEnabled = false }
            #endif
        }
    }

    private var displayPath: String {
        if workingDirectoryDisplay.isEmpty {
            let home = FileManager.default.homeDirectoryForCurrentUser.path
            return (home as NSString).abbreviatingWithTildeInPath
        }
        return workingDirectoryDisplay
    }

    private func chooseWorkingDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = NSLocalizedString("settings.workingDirectory.panel.prompt", comment: "")

        if !workingDirectoryDisplay.isEmpty {
            let expanded = (workingDirectoryDisplay as NSString).expandingTildeInPath
            if FileManager.default.fileExists(atPath: expanded) {
                panel.directoryURL = URL(fileURLWithPath: expanded)
            }
        }

        if panel.runModal() == .OK, let url = panel.url {
            AppSettings.defaultWorkingDirectoryRaw = url.path
            workingDirectoryDisplay = (url.path as NSString).abbreviatingWithTildeInPath
            workingDirectoryIsValid = true
        }
    }

    private func resetWorkingDirectory() {
        AppSettings.defaultWorkingDirectoryRaw = ""
        workingDirectoryDisplay = ""
        workingDirectoryIsValid = true
    }

    private func choosePath() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = NSLocalizedString("settings.paths.panel.prompt", comment: "")

        if panel.runModal() == .OK, let url = panel.url {
            PathStore.shared.add(url.path)
            reload()
        }
    }

    private func reload() {
        paths = PathStore.shared.paths
    }
}

// MARK: - 路径行

struct PathRow: View {
    let path: String
    let isFirst: Bool
    let isLast: Bool
    let onDelete: () -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 8) {
            Text(path)
                .font(.system(size: 12, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundColor(isValid ? .primary : .red)

            Spacer(minLength: 0)

            if isHovering {
                HStack(spacing: 4) {
                    Button(action: onMoveUp) {
                        Image(systemName: "chevron.up").font(.system(size: 10))
                    }
                    .buttonStyle(.borderless)
                    .disabled(isFirst)

                    Button(action: onMoveDown) {
                        Image(systemName: "chevron.down").font(.system(size: 10))
                    }
                    .buttonStyle(.borderless)
                    .disabled(isLast)

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 10))
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
    }

    private var isValid: Bool {
        PathStore.shared.isValid(path)
    }
}
