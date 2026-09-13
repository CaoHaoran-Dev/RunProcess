//
//  SessionManager.swift
//  RunProcess
//
//  Created by Haoran on 2026/9/13.
//

internal import AppKit

/// 管理所有窗口会话
final class SessionManager {
    
    private var sessions: [Session] = []
    
    /// 最近活跃的会话（用于全局快捷键）
    private(set) weak var lastActiveSession: Session?
    
    // MARK: - 创建 / 销毁
    
    func newSession() -> Session {
        let session = Session(usesSessionMode: AppSettings.sessionModeEnabled)
        sessions.append(session)
        
        // ✅ 让 Session 自己绑定窗口通知
        session.observeWindow(manager: self)
        
        session.show()
        lastActiveSession = session
        
        return session
    }
    
    func removeSession(_ session: Session) {
        sessions.removeAll { $0 === session }
        
        // ✅ 无条件注销，避免泄漏
        SessionRegistry.shared.unregister(viewModel: session.viewModel)
        
        if lastActiveSession === session {
            lastActiveSession = sessions.last
        }
    }
    
    /// 由 Session 在窗口成为 key 时调用
    func markActive(_ session: Session) {
        lastActiveSession = session
    }
    
    func removeAll() {
        for session in sessions {
            session.persistentShell?.teardown()
            SessionRegistry.shared.unregister(viewModel: session.viewModel)
        }
        sessions.removeAll()
        lastActiveSession = nil
    }
    
    // MARK: - 查询
    
    var allSessions: [Session] {
        return sessions
    }
    
    /// 当前有 sudo 授权的窗口（用于菜单项）
    var authorizedSession: Session? {
        return sessions.first { $0.sudoAuth.isAuthorized }
    }
    
    /// 最近活跃会话（如果没有，返回最后一个）
    func activeSession() -> Session? {
        if let last = lastActiveSession, sessions.contains(where: { $0 === last }) {
            return last
        }
        return sessions.last
    }
}
