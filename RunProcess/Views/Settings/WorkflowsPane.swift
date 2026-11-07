//
//  WorkflowsPane.swift
//  RunProcess
//

#if BETA

import SwiftUI

struct WorkflowsPane: View {
    @State private var workflows: [Workflow] = WorkflowStore.shared.workflows
    @State private var editing: Workflow? = nil
    @State private var pendingDelete: Workflow? = nil
    @State private var showDeleteConfirm = false

    var body: some View {
        Section {
            if workflows.isEmpty {
                Text(NSLocalizedString("settings.workflows.empty", comment: ""))
                    .foregroundColor(.secondary)
            } else {
                ForEach(workflows) { wf in
                    HStack(spacing: 10) {
                        Image(systemName: "doc.text.fill")
                            .foregroundColor(.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(wf.name)
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                            if !wf.description.isEmpty {
                                Text(wf.description)
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        Button {
                            editing = wf
                        } label: {
                            Image(systemName: "pencil")
                        }
                        .buttonStyle(.borderless)
                        Button {
                            pendingDelete = wf
                            showDeleteConfirm = true
                        } label: {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.vertical, 2)
                }
            }

            Button(NSLocalizedString("settings.workflows.add", comment: "")) {
                editing = Workflow(name: "", commands: "", description: "")
            }

            Text(NSLocalizedString("settings.workflows.hint", comment: ""))
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .sheet(item: $editing) { item in
            WorkflowEditorSheet(
                workflow: item,
                existingNames: workflows.map { $0.name },
                onSave: { newWf in
                    saveWorkflow(newWf, original: item)
                    editing = nil
                },
                onCancel: { editing = nil }
            )
        }
        .alert(
            NSLocalizedString("settings.workflows.delete.title", comment: ""),
            isPresented: $showDeleteConfirm,
            presenting: pendingDelete
        ) { wf in
            Button(NSLocalizedString("button.cancel", comment: ""), role: .cancel) {}
            Button(NSLocalizedString("button.delete", comment: ""), role: .destructive) {
                deleteWorkflow(wf)
            }
        } message: { wf in
            Text(String(format: NSLocalizedString("settings.workflows.delete.message", comment: ""), wf.name))
        }
    }

    private func saveWorkflow(_ wf: Workflow, original: Workflow) {
        if original.name != wf.name, !original.name.isEmpty {
            WorkflowStore.shared.remove(name: original.name)
        }
        WorkflowStore.shared.add(wf)
        reload()
    }

    private func deleteWorkflow(_ wf: Workflow) {
        WorkflowStore.shared.remove(name: wf.name)
        reload()
    }

    private func reload() {
        workflows = WorkflowStore.shared.workflows
    }
}

// MARK: - Workflow 编辑 Sheet

struct WorkflowEditorSheet: View {
    let workflow: Workflow
    let existingNames: [String]
    let onSave: (Workflow) -> Void
    let onCancel: () -> Void

    @State private var name: String
    @State private var description: String
    @State private var commands: String
    @FocusState private var nameFocused: Bool

    init(workflow: Workflow, existingNames: [String], onSave: @escaping (Workflow) -> Void, onCancel: @escaping () -> Void) {
        self.workflow = workflow
        self.existingNames = existingNames
        self.onSave = onSave
        self.onCancel = onCancel
        _name = State(initialValue: workflow.name)
        _description = State(initialValue: workflow.description)
        _commands = State(initialValue: workflow.commands)
    }

    private var isEditing: Bool { !workflow.name.isEmpty }
    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }
    private var trimmedCommands: String { commands.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var nameError: String? {
        if trimmedName.isEmpty { return NSLocalizedString("settings.workflows.error.empty", comment: "") }
        if trimmedName.contains(" ") { return NSLocalizedString("settings.workflows.error.space", comment: "") }
        if trimmedName != workflow.name, existingNames.contains(trimmedName) {
            return NSLocalizedString("settings.workflows.error.duplicate", comment: "")
        }
        return nil
    }

    private var canSave: Bool { nameError == nil && !trimmedCommands.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.blue)
                Text(isEditing
                     ? NSLocalizedString("settings.workflows.edit.title", comment: "")
                     : NSLocalizedString("settings.workflows.add.title", comment: ""))
                    .font(.headline)
                Spacer()
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(NSLocalizedString("settings.workflows.field.name", comment: ""))
                        .font(.system(size: 12, weight: .medium))
                    TextField("deploy", text: $name)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13, design: .monospaced))
                        .focused($nameFocused)
                        .onAppear { nameFocused = true }
                }
                .frame(width: 140)

                VStack(alignment: .leading, spacing: 6) {
                    Text(NSLocalizedString("settings.workflows.field.description", comment: ""))
                        .font(.system(size: 12, weight: .medium))
                    TextField(NSLocalizedString("settings.workflows.field.description.placeholder", comment: ""), text: $description)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13))
                }
            }

            if let error = nameError, !name.isEmpty {
                Text(error).font(.system(size: 11)).foregroundColor(.red)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(NSLocalizedString("settings.workflows.field.commands", comment: ""))
                    .font(.system(size: 12, weight: .medium))
                TextEditor(text: $commands)
                    .font(.system(size: 12, design: .monospaced))
                    .frame(height: 160)
                    .padding(4)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    )
            }

            Text(NSLocalizedString("settings.workflows.editor.hint", comment: ""))
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                Spacer()
                Button(NSLocalizedString("button.cancel", comment: "")) { onCancel() }
                    .keyboardShortcut(.escape)
                Button(NSLocalizedString("button.save", comment: "")) {
                    onSave(Workflow(name: trimmedName, commands: trimmedCommands, description: description.trimmingCharacters(in: .whitespaces)))
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(!canSave)
            }
        }
        .padding(20)
        .frame(width: 480)
    }
}

#endif
