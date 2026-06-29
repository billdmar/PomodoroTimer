//
//  PendingCommandStore.swift
//  pomadoro2
//
//  A one-slot mailbox in the shared App Group suite. App Intents, Siri, and the
//  Control Center control run out-of-process and can't touch the app's
//  @MainActor TimerManager directly, so they drop a command here and open the
//  app; the app consumes it on activation. Must be a member of BOTH the app and
//  widget targets (see docs/WIDGET_SETUP.md).
//

import Foundation

/// Actions an out-of-process surface can request.
enum PendingCommand: String {
    case startFocus
    case togglePause
}

struct PendingCommandStore {
    private static let key = "shared.pendingCommand"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = SharedConfig.defaults) {
        self.defaults = defaults
    }

    func post(_ command: PendingCommand) {
        defaults.set(command.rawValue, forKey: Self.key)
    }

    /// Returns and clears the pending command (consume-once semantics).
    func consume() -> PendingCommand? {
        guard let raw = defaults.string(forKey: Self.key) else { return nil }
        defaults.removeObject(forKey: Self.key)
        return PendingCommand(rawValue: raw)
    }
}
