//
//  CommandExecutor.swift
//  RunProcess
//
//  Created by Haoran on 2026/8/19.
//

import Foundation

class CommandExecutor {
    static let shared = CommandExecutor()
    
    private init() {}
    
    func execute(_ input: String, completion: @escaping (Result<String, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let task = Process()
            let pipe = Pipe()
            
            task.launchPath = "/bin/zsh"
            task.arguments = ["-c", input]
            task.standardOutput = pipe
            task.standardError = pipe
            
            do {
                try task.run()
                task.waitUntilExit()
                
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                let trimmed = output.trimmingCharacters(in: .newlines)
                
                if task.terminationStatus == 0 {
                    DispatchQueue.main.async {
                        completion(.success(trimmed))
                    }
                } else {
                    let errorMsg = trimmed.isEmpty ? "命令执行失败（退出码: \(task.terminationStatus)）" : trimmed
                    DispatchQueue.main.async {
                        completion(.failure(NSError(domain: "RunProcess", code: Int(task.terminationStatus), userInfo: [NSLocalizedDescriptionKey: errorMsg])))
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    func pathCompletions(for input: String) -> [String] {
        let path = (input as NSString).expandingTildeInPath
        let partial = (path as NSString).lastPathComponent
        let dir = (path as NSString).deletingLastPathComponent
        
        guard !dir.isEmpty,
              let files = try? FileManager.default.contentsOfDirectory(atPath: dir) else {
            return []
        }
        
        return files
            .filter { $0.hasPrefix(partial) }
            .prefix(20)
            .map { dir + "/" + $0 }
            .map { ($0 as NSString).abbreviatingWithTildeInPath }
            .map { $0.replacingOccurrences(of: " ", with: "\\ ") }
    }
}
