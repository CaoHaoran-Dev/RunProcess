//
//  SessionRegistry.swift
//  RunProcess
//
//  Created by Haoran on 2026/9/13.
//

import Foundation

/// viewModel → Session 的映射，用于 ContentView 拿到当前 Session
final class SessionRegistry {
    static let shared = SessionRegistry()
    
    private var map: [ObjectIdentifier: Session] = [:]
    private let lock = NSLock()
    
    private init() {}
    
    func register(viewModel: CommandViewModel, session: Session) {
        lock.lock()
        map[ObjectIdentifier(viewModel)] = session
        lock.unlock()
    }
    
    func unregister(viewModel: CommandViewModel) {
        lock.lock()
        map.removeValue(forKey: ObjectIdentifier(viewModel))
        lock.unlock()
    }
    
    func session(for viewModel: CommandViewModel) -> Session? {
        lock.lock()
        let s = map[ObjectIdentifier(viewModel)]
        lock.unlock()
        return s
    }
}
