//
//  RemoteHost.swift
//  RunProcess
//

#if BETA

import Foundation
import Yams

nonisolated struct RemoteHost: Codable, Identifiable, Equatable {
    var id: String { "\(host):\(port)" }
    var name: String
    var host: String
    var port: Int
    
    init(name: String, host: String, port: Int = 52731) {
        self.name = name
        self.host = host
        self.port = port
    }
}

private nonisolated struct RemoteHostFile: Codable {
    var hosts: [RemoteHost]
}

final class RemoteHostStore {
    static let shared = RemoteHostStore()
    
    private(set) var hosts: [RemoteHost] = []
    private let fileURL: URL
    private let queue = DispatchQueue(label: "com.runprocess.remotehosts", qos: .background)
    
    private init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent(AppEnvironment.appSupportFolderName)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("remote_hosts.yml")
        load()
    }
    
    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let text = try String(contentsOf: fileURL, encoding: .utf8)
            let file = try YAMLDecoder().decode(RemoteHostFile.self, from: text)
            hosts = file.hosts
        } catch {
            print("⚠️ 加载 RemoteHost 失败: \(error)")
            hosts = []
        }
    }
    
    private func save() {
        let file = RemoteHostFile(hosts: hosts)
        let url = fileURL
        queue.async {
            do {
                let encoder = YAMLEncoder()
                encoder.options.indent = 2
                let yaml = try encoder.encode(file)
                
                let header = """
                # RunProcess Remote Hosts

                """
                try (header + yaml).write(to: url, atomically: true, encoding: .utf8)
            } catch {
                print("⚠️ 保存 RemoteHost 失败: \(error)")
            }
        }
    }
    
    func add(_ host: RemoteHost) {
        if let idx = hosts.firstIndex(where: { $0.id == host.id }) {
            hosts[idx] = host
        } else {
            hosts.append(host)
        }
        save()
    }
    
    func remove(id: String) {
        hosts.removeAll { $0.id == id }
        KeychainHelper.shared.deleteToken(for: id)
        save()
    }
    
    func get(id: String) -> RemoteHost? {
        hosts.first { $0.id == id }
    }
}

#endif
