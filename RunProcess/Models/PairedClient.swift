//
//  PairedClient.swift
//  RunProcess
//
//  Created by Haoran on 2026/11/7.
//

#if BETA

import Foundation
import Yams

nonisolated struct PairedClient: Codable, Identifiable, Equatable {
    var id: String { "\(deviceName)_\(tokenHash.prefix(8))" }
    let deviceName: String
    let tokenHash: String
    let pairedAt: Date
    
    init(deviceName: String, tokenHash: String, pairedAt: Date = Date()) {
        self.deviceName = deviceName
        self.tokenHash = tokenHash
        self.pairedAt = pairedAt
    }
}

private nonisolated struct PairedClientFile: Codable {
    var clients: [PairedClient]
}

final class PairedClientStore {
    static let shared = PairedClientStore()
    
    private(set) var clients: [PairedClient] = []
    private let fileURL: URL
    private let queue = DispatchQueue(label: "com.runprocess.pairedclients", qos: .background)
    
    private init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent(AppEnvironment.appSupportFolderName)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("paired_clients.yml")
        load()
    }
    
    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let text = try String(contentsOf: fileURL, encoding: .utf8)
            let file = try YAMLDecoder().decode(PairedClientFile.self, from: text)
            clients = file.clients
        } catch {
            print("⚠️ 加载 PairedClient 失败: \(error)")
            clients = []
        }
    }
    
    private func save() {
        let file = PairedClientFile(clients: clients)
        let url = fileURL
        queue.async {
            do {
                let encoder = YAMLEncoder()
                encoder.options.indent = 2
                let yaml = try encoder.encode(file)
                
                let header = """
                # RunProcess Paired Clients
                # 记录连接到当前主机的客户端

                """
                try (header + yaml).write(to: url, atomically: true, encoding: .utf8)
            } catch {
                print("⚠️ 保存 PairedClient 失败: \(error)")
            }
        }
    }
    
    func add(_ client: PairedClient) {
        if let idx = clients.firstIndex(where: { $0.deviceName == client.deviceName && $0.tokenHash == client.tokenHash }) {
            clients[idx] = client
        } else {
            clients.append(client)
        }
        save()
    }
    
    func remove(id: String) {
        clients.removeAll { $0.id == id }
        save()
    }
    
    func verify(tokenHash: String) -> PairedClient? {
        clients.first { $0.tokenHash == tokenHash }
    }
}

#endif
