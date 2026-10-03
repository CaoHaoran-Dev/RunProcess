//
//  SessionManager.swift
//  RunProcess
//
//  Created by Haoran on 2026/9/13.
//

internal import AppKit

final class SessionManager {

    private var sessions: [Session] = []
    private(set) weak var lastActiveSession: Session?

    func newSession() -> Session {
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
        session.show()
        lastActiveSession = session
        return session
    }

    func removeSession(_ session: Session) {
        sessions.removeAll { $0 === session }
        if lastActiveSession === session { lastActiveSession = sessions.last }
    }

    func markActive(_ session: Session) { lastActiveSession = session }

    func removeAll() {
        for session in sessions { session.persistentShell?.teardown() }
        sessions.removeAll()
        lastActiveSession = nil
    }

    var allSessions: [Session] { sessions }

    func activeSession() -> Session? {
        if let last = lastActiveSession, sessions.contains(where: { $0 === last }) { return last }
        return sessions.last
    }
}
