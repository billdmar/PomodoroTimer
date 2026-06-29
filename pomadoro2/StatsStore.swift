//
//  StatsStore.swift
//  pomadoro2
//
//  The focus-stats domain, extracted from TimerManager: the value model, the
//  pure day/streak/accumulation math, and local persistence. TimerManager keeps
//  the @Published mirror the views bind to and delegates the logic here, so the
//  rules are unit-testable without constructing the Firebase-backed manager.
//

import Foundation

/// The user's focus statistics at a point in time.
struct StatsState: Equatable {
    var todayFocusMinutes: Int = 0
    var totalFocusMinutes: Int = 0
    var currentStreak: Int = 0
    var lastCompletionDate: Date?
}

/// Pure stats transitions. No persistence, no UIKit — fully testable with an
/// injected `now` / `calendar`.
enum StatsCalculator {

    /// Zeroes today's minutes when `now` is a different calendar day than the
    /// last completion (a fresh day starts a new "today" total). Other fields
    /// are untouched.
    static func resettingForNewDay(
        _ state: StatsState,
        now: Date,
        calendar: Calendar = .current
    ) -> StatsState {
        guard isNewDay(lastCompletion: state.lastCompletionDate, now: now, calendar: calendar) else {
            return state
        }
        var updated = state
        updated.todayFocusMinutes = 0
        return updated
    }

    /// Applies a completed focus session: accumulates today's + total minutes
    /// (resetting today's on a new day) and advances the streak via
    /// `StreakCalculator` so a multi-day gap resets rather than increments.
    static func applyingCompletion(
        _ state: StatsState,
        focusMinutes: Int,
        now: Date,
        calendar: Calendar = .current
    ) -> StatsState {
        var updated = state
        let newDay = isNewDay(lastCompletion: state.lastCompletionDate, now: now, calendar: calendar)

        updated.todayFocusMinutes = newDay ? focusMinutes : state.todayFocusMinutes + focusMinutes
        updated.currentStreak = StreakCalculator.updatedStreak(
            previousStreak: state.currentStreak,
            lastCompletion: state.lastCompletionDate,
            now: now
        )
        updated.totalFocusMinutes = state.totalFocusMinutes + focusMinutes
        updated.lastCompletionDate = now
        return updated
    }

    /// Field-wise maximum, used to reconcile local stats with values pulled
    /// from another device (matches the app's existing multi-device policy).
    static func merging(_ state: StatsState, remote: StatsState) -> StatsState {
        StatsState(
            todayFocusMinutes: max(state.todayFocusMinutes, remote.todayFocusMinutes),
            totalFocusMinutes: max(state.totalFocusMinutes, remote.totalFocusMinutes),
            currentStreak: max(state.currentStreak, remote.currentStreak),
            lastCompletionDate: state.lastCompletionDate
        )
    }

    static func isNewDay(lastCompletion: Date?, now: Date, calendar: Calendar = .current) -> Bool {
        guard let lastCompletion else { return true }
        return !calendar.isDate(lastCompletion, inSameDayAs: now)
    }
}

/// Loads/saves `StatsState` to injectable `UserDefaults`.
struct StatsPersistence {
    private enum Key {
        static let today = "todayFocusMinutes"
        static let total = "totalFocusMinutes"
        static let streak = "currentStreak"
        static let lastCompletion = "lastCompletionDate"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> StatsState {
        StatsState(
            todayFocusMinutes: defaults.integer(forKey: Key.today),
            totalFocusMinutes: defaults.integer(forKey: Key.total),
            currentStreak: defaults.integer(forKey: Key.streak),
            lastCompletionDate: defaults.object(forKey: Key.lastCompletion) as? Date
        )
    }

    func save(_ state: StatsState) {
        defaults.set(state.todayFocusMinutes, forKey: Key.today)
        defaults.set(state.totalFocusMinutes, forKey: Key.total)
        defaults.set(state.currentStreak, forKey: Key.streak)
        defaults.set(state.lastCompletionDate, forKey: Key.lastCompletion)
    }
}
