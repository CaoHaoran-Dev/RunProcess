//
//  AliasesPane.swift
//  RunProcess
//
//  Created by Haoran on 2026/10/18.
//

import SwiftUI

struct AliasesPane: View {
    @State private var aliases: [CommandAlias] = AliasStore.shared.aliases
    @State private var editing: CommandAlias? = nil
    @State private var pendingDelete: CommandAlias? = nil
    @State private var showDeleteConfirm = false

    var body: some View {
        Section {
            if aliases.isEmpty {
                Text(NSLocalizedString("settings.aliases.empty", comment: ""))
                    .foregroundColor(.secondary)
            } else {
                ForEach(aliases) { alias in
                    HStack(spacing: 10) {
                        Text(alias.name)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .frame(width: 100, alignment: .leading)
                        Text("→")
                            .foregroundColor(.secondary)
                        Text(alias.expansion)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.secondary)
                        Spacer()
                        Button {
                            editing = alias
                        } label: {
                            Image(systemName: "pencil")
                        }
                        .buttonStyle(.borderless)
                        Button {
                            pendingDelete = alias
                            showDeleteConfirm = true
                        } label: {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }

            Button(NSLocalizedString("settings.aliases.add", comment: "")) {
                editing = CommandAlias(name: "", expansion: "")
            }

            Text(NSLocalizedString("settings.aliases.hint", comment: ""))
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .sheet(item: $editing) { item in
            AliasEditorSheet(
                alias: item,
                existingNames: aliases.map { $0.name },
                onSave: { newAlias in
                    saveAlias(newAlias, original: item)
                    editing = nil
                },
                onCancel: { editing = nil }
            )
        }
        .alert(
            NSLocalizedString("settings.aliases.delete.title", comment: ""),
            isPresented: $showDeleteConfirm,
            presenting: pendingDelete
        ) { alias in
            Button(NSLocalizedString("button.cancel", comment: ""), role: .cancel) {}
            Button(NSLocalizedString("button.delete", comment: ""), role: .destructive) {
                deleteAlias(alias)
            }
        } message: { alias in
            Text(String(format: NSLocalizedString("settings.aliases.delete.message", comment: ""), alias.name))
        }
    }

    private func saveAlias(_ alias: CommandAlias, original: CommandAlias) {
        if original.name != alias.name, !original.name.isEmpty {
            AliasStore.shared.remove(name: original.name)
        }
        AliasStore.shared.add(alias)
        reload()
    }

    private func deleteAlias(_ alias: CommandAlias) {
        AliasStore.shared.remove(name: alias.name)
        reload()
    }

    private func reload() {
        aliases = AliasStore.shared.aliases
    }
}

// MARK: - 别名编辑 Sheet

struct AliasEditorSheet: View {
    let alias: CommandAlias
    let existingNames: [String]
    let onSave: (CommandAlias) -> Void
    let onCancel: () -> Void

    @State private var name: String
    @State private var expansion: String
    @FocusState private var nameFocused: Bool

    init(alias: CommandAlias,
         existingNames: [String],
         onSave: @escaping (CommandAlias) -> Void,
         onCancel: @escaping () -> Void) {
        self.alias = alias
        self.existingNames = existingNames
        self.onSave = onSave
        self.onCancel = onCancel
        _name = State(initialValue: alias.name)
        _expansion = State(initialValue: alias.expansion)
    }

    private var isEditing: Bool { !alias.name.isEmpty }
    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }
    private var trimmedExpansion: String { expansion.trimmingCharacters(in: .whitespaces) }

    private var nameError: String? {
        if trimmedName.isEmpty { return NSLocalizedString("settings.aliases.error.empty", comment: "") }
        if trimmedName.contains(" ") { return NSLocalizedString("settings.aliases.error.space", comment: "") }
        if trimmedName != alias.name, existingNames.contains(trimmedName) {
            return NSLocalizedString("settings.aliases.error.duplicate", comment: "")
        }
        return nil
    }

    private var expansionError: String? {
        if trimmedExpansion.isEmpty { return NSLocalizedString("settings.aliases.error.empty", comment: "") }
        return nil
    }

    private var canSave: Bool { nameError == nil && expansionError == nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 16))
                    .foregroundColor(.accentColor)
                Text(isEditing
                     ? NSLocalizedString("settings.aliases.edit.title", comment: "")
                     : NSLocalizedString("settings.aliases.add.title", comment: ""))
                    .font(.headline)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(NSLocalizedString("settings.aliases.field.name", comment: ""))
                    .font(.system(size: 12, weight: .medium))
                TextField("gs", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13, design: .monospaced))
                    .focused($nameFocused)
                    .onAppear { nameFocused = true }
                if let error = nameError, !name.isEmpty {
                    Text(error).font(.system(size: 11)).foregroundColor(.red)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(NSLocalizedString("settings.aliases.field.expansion", comment: ""))
                    .font(.system(size: 12, weight: .medium))
                TextField("git status", text: $expansion)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13, design: .monospaced))
                if let error = expansionError, !expansion.isEmpty {
                    Text(error).font(.system(size: 11)).foregroundColor(.red)
                }
            }

            Text(NSLocalizedString("settings.aliases.editor.hint", comment: ""))
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                Spacer()
                Button(NSLocalizedString("button.cancel", comment: "")) { onCancel() }
                    .keyboardShortcut(.escape)
                Button(NSLocalizedString("button.save", comment: "")) {
                    onSave(CommandAlias(name: trimmedName, expansion: trimmedExpansion))
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(!canSave)
            }
        }
        .padding(20)
        .frame(width: 400)
    }
}
