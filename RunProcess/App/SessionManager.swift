//
//  SessionManager.swift
//  RunProcess
//
//  Created by Haoran on 2026/9/13.
//

internal import AppKit

final class SessionManager {

    /// 强引用数组。Session 只要在这里面，就不会被释放。
    private var sessions: [Session] = []

    private(set) weak var lastActiveSession: Session?

    // MARK: - 创建 / 销毁

    /// 新建会话并显示窗口
    func newSession() -> Session {
        let session = makeSession()
        session.show()
        lastActiveSession = session
        return session
    }

    /// 新建会话但不显示窗口（用于启动后隐藏）
    func newSessionWithoutShowing() -> Session {
        let session = makeSession()
        lastActiveSession = session
        return session
    }

    /// 内部：创建 Session 并绑定回调，加入数组，注册窗口通知
    private func makeSession() -> Session {
        let session = Session(usesSessionMode: AppSettings.sessionModeEnabled)

        session.onClose = { [weak self, weak session] in
            guard let self = self, let session = session else { return }
            self.removeSession(session)
        }

        session.onBecomeKey = { [weak self, weak session] in
            guard let self = self, let session = session else { return }
            self.lastActiveSession = session
        }

        sessions.append(session)
        session.observeWindow(manager: self)
        return session
    }

    func removeSession(_ session: Session) {
        sessions.removeAll { $0 === session }
        if lastActiveSession === session {
            lastActiveSession = sessions.last
        }
    }

    func markActive(_ session: Session) {
        lastActiveSession = session
    }

    func removeAll() {
        for session in sessions {
            session.persistentShell?.teardown()
        }
        sessions.removeAll()
        lastActiveSession = nil
    }

    // MARK: - 查询

    var allSessions: [Session] {
        sessions
    }

    func activeSession() -> Session? {
        if let last = lastActiveSession, sessions.contains(where: { $0 === last }) {
            return last
        }
        return sessions.last
    }
}
