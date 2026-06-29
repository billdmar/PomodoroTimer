//
//  SharedSessionState.swift
//  pomadoro2
//
//  A tiny snapshot of the live timer that the app writes to a shared App Group
//  suite so the Home/Lock-screen widget (a separate process) can render the
//  current session. Kept deliberately small — just what the widget draws.
//

import Foundation

/// Identifiers shared between the app and its widget extension.
enum SharedConfig {
    /// App Group suite shared by the app and the widget target. Both targets
    /// must enable this App Group capability in Xcode (see WIDGET_SETUP.md).
    static let appGroupID = "group.com.billdmar.pomadoro2"

    /// Falls back to `.standard` so the app still runs before the App Group is
    /// configured (the widget simply won't see updates until it's set up).
    static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }
}

/// What the widget needs to draw the current session.
struct SharedSessionState: Codable, Equatable {
    var isRunning: Bool
    var isFocusMode: Bool
    var emoji: String
    /// Deadline for a running session; nil when idle/paused.
    var endDate: Date?
    /// Remaining seconds captured at write time (for the paused/idle display).
    var timeRemaining: TimeInterval

    static let idle = SharedSessionState(
        isRunning: false, isFocusMode: true, emoji: "🍅",
        endDate: nil, timeRemaining: 25 * 60
    )
}

/// Reads/writes `SharedSessionState` to the shared App Group suite.
struct SharedSessionStore {
    private static let key = "shared.session"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = SharedConfig.defaults) {
        self.defaults = defaults
    }

    func save(_ state: SharedSessionState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: Self.key)
    }

    func load() -> SharedSessionState {
        guard let data = defaults.data(forKey: Self.key),
              let state = try? JSONDecoder().decode(SharedSessionState.self, from: data)
        else { return .idle }
        return state
    }
}
