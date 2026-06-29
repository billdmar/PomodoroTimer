//
//  SessionStore.swift
//  pomadoro2
//
//  Persists an in-progress timer session so it survives the app being quit or
//  crashing mid-session. Previously nothing was saved, so a force-quit lost the
//  running session entirely and the timer reappeared at full duration.
//

import Foundation

/// A point-in-time snapshot of the running/paused session.
///
/// `savedAt` lets recovery compute how much real time elapsed while the app was
/// gone, so a running session resumes at the correct remaining time rather than
/// where the (suspended) tick last left it.
struct SessionSnapshot: Codable, Equatable {
    var savedAt: Date
    var timeRemaining: TimeInterval
    var isFocusMode: Bool
    var wasRunning: Bool
}

/// Loads/saves/clears the session snapshot. `UserDefaults` is injected so the
/// behavior is unit-testable against an isolated suite.
struct SessionStore {
    private static let key = "session.snapshot"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func save(_ snapshot: SessionSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: Self.key)
    }

    func load() -> SessionSnapshot? {
        guard let data = defaults.data(forKey: Self.key) else { return nil }
        return try? JSONDecoder().decode(SessionSnapshot.self, from: data)
    }

    func clear() {
        defaults.removeObject(forKey: Self.key)
    }
}

/// Pure recovery logic — kept free of any UserDefaults/UIKit dependency so it
/// can be exhaustively unit-tested with an injected `now`.
enum SessionRecovery {

    enum Outcome: Equatable {
        /// No snapshot, or nothing to restore.
        case none
        /// Restore a session with this much time left (as paused).
        case resume(timeRemaining: TimeInterval, isFocusMode: Bool)
        /// The deadline passed while the app was away; the session is over.
        case expired(isFocusMode: Bool)
    }

    static func recover(from snapshot: SessionSnapshot?, now: Date) -> Outcome {
        guard let snapshot else { return .none }

        // A paused session doesn't count down — restore its remaining as-is.
        guard snapshot.wasRunning else {
            return .resume(timeRemaining: snapshot.timeRemaining,
                           isFocusMode: snapshot.isFocusMode)
        }

        let elapsed = now.timeIntervalSince(snapshot.savedAt)
        let remaining = snapshot.timeRemaining - elapsed

        if remaining > 0 {
            return .resume(timeRemaining: remaining, isFocusMode: snapshot.isFocusMode)
        } else {
            return .expired(isFocusMode: snapshot.isFocusMode)
        }
    }
}
