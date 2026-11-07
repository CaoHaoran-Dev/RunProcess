//
//  Workflow.swift
//  RunProcess
//
//  Created by Haoran on 2026/11/7.
//

#if BETA

import Foundation
import Yams

nonisolated struct Workflow: Codable, Identifiable, Equatable {
    var id: String { name }
    let name: String
    let commands: String
    let description: String

    init(name: String, commands: String, description: String = "") {
        self.name = name
        self.commands = commands
        self.description = description
    }
}

private nonisolated struct WorkflowFile: Codable {
    var workflows: [Workflow]
}

final class WorkflowStore {
    static let shared = WorkflowStore()

    private(set) var workflows: [Workflow] = []
    private let fileURL: URL
    private let queue = DispatchQueue(label: "com.runprocess.workflows", qos: .background)

    private init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent(AppEnvironment.appSupportFolderName)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("workflows.yml")
        load()
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let text = try String(contentsOf: fileURL, encoding: .utf8)
            let file = try YAMLDecoder().decode(WorkflowFile.self, from: text)
            workflows = file.workflows
        } catch {
            print("⚠️ 加载 Workflow 失败: \(error)")
            workflows = []
        }
    }

    private func save() {
        let file = WorkflowFile(workflows: workflows)
        let url = fileURL
        queue.async {
            do {
                let encoder = YAMLEncoder()
                encoder.options.indent = 2
                let yaml = try encoder.encode(file)

                let header = """
                # RunProcess workflows
                #
                # 格式:
                #   workflows:
                #     - name: deploy
                #       description: Deploy to production
                #       commands: |
                #         git pull
                #         npm run build
                #
                # 修改后立即生效。

                """
                try (header + yaml).write(to: url, atomically: true, encoding: .utf8)
            } catch {
                print("⚠️ 保存 Workflow 失败: \(error)")
            }
        }
    }

    // MARK: - CRUD

    func add(_ workflow: Workflow) {
        if let idx = workflows.firstIndex(where: { $0.name == workflow.name }) {
            workflows[idx] = workflow
        } else {
            workflows.append(workflow)
        }
        save()
    }

    func remove(name: String) {
        workflows.removeAll { $0.name == name }
        save()
    }

    func replaceAll(_ newWorkflows: [Workflow]) {
        workflows = newWorkflows
        save()
    }

    func match(prefix: String) -> [Workflow] {
        guard !prefix.isEmpty else { return [] }
        return workflows.filter { $0.name.hasPrefix(prefix) }
    }

    func get(name: String) -> Workflow? {
        workflows.first { $0.name == name }
    }

    func expandWorkflow(in command: String) -> String {
        let parts = command.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: false)
        guard let first = parts.first, !first.isEmpty else { return command }
        let name = String(first)
        
        guard let workflow = get(name: name) else { return command }
        
        return workflow.commands
    }
}

#endif
