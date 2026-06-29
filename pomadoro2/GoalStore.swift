//
//  GoalStore.swift
//  pomadoro2
//
//  The user's daily focus goal (in minutes) and the pure progress math behind
//  the goal ring. Persisted to injectable UserDefaults so it's unit-testable.
//

import Foundation

enum GoalMath {
    /// Fraction of the daily goal met, clamped to 0...1. A non-positive goal
    /// reads as already complete (avoids divide-by-zero and a goal of 0 showing
    /// an empty ring forever).
    static func progress(focusMinutesToday: Int, goalMinutes: Int) -> Double {
        guard goalMinutes > 0 else { return 1 }
        return min(1, max(0, Double(focusMinutesToday) / Double(goalMinutes)))
    }

    static func isMet(focusMinutesToday: Int, goalMinutes: Int) -> Bool {
        focusMinutesToday >= goalMinutes
    }
}

/// Loads/saves the daily focus goal.
struct GoalStore {
    static let defaultGoalMinutes = 120 // 2 hours

    private static let key = "settings.dailyGoalMinutes"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadGoalMinutes() -> Int {
        defaults.object(forKey: Self.key) != nil
            ? defaults.integer(forKey: Self.key)
            : Self.defaultGoalMinutes
    }

    func save(goalMinutes: Int) {
        defaults.set(goalMinutes, forKey: Self.key)
    }
}
