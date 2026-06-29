//
//  PomodoroIntents.swift
//  pomadoro2
//
//  App Intents for Siri / Shortcuts. Mutating intents drop a command in the
//  shared mailbox and open the app (which consumes it on activation); the
//  query intent reads the shared session/stats and answers inline.
//

import AppIntents
import Foundation

@available(iOS 16.0, *)
struct StartFocusSessionIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Focus Session"
    static var description = IntentDescription("Starts a Pomodoro focus session.")
    /// Bring the app forward so the running timer (and its lock) is visible.
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        PendingCommandStore().post(.startFocus)
        return .result(dialog: "Starting your focus session. Stay focused! 🍅")
    }
}

@available(iOS 16.0, *)
struct CheckStreakIntent: AppIntent {
    static var title: LocalizedStringResource = "Check Focus Streak"
    static var description = IntentDescription("Tells you your current focus streak and minutes today.")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let state = SharedSessionStore().load()
        // Streak/minutes are persisted by StatsPersistence in the standard
        // suite; read them directly so this works without launching the app.
        let stats = StatsPersistence().load()
        let streakText = stats.currentStreak == 1 ? "1 day" : "\(stats.currentStreak) days"
        let session = state.isRunning ? " A \(state.isFocusMode ? "focus" : "break") session is running." : ""
        return .result(dialog: "You're on a \(streakText) streak with \(stats.todayFocusMinutes) minutes focused today.\(session)")
    }
}

@available(iOS 16.0, *)
struct PomodoroShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartFocusSessionIntent(),
            phrases: [
                "Start a focus session in \(.applicationName)",
                "Start \(.applicationName)",
                "Begin focusing with \(.applicationName)"
            ],
            shortTitle: "Start Focus",
            systemImageName: "play.circle.fill"
        )
        AppShortcut(
            intent: CheckStreakIntent(),
            phrases: [
                "Check my streak in \(.applicationName)",
                "What's my \(.applicationName) streak"
            ],
            shortTitle: "Check Streak",
            systemImageName: "flame.fill"
        )
    }
}
