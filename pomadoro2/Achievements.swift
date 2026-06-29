//
//  Achievements.swift
//  pomadoro2
//
//  Milestone badges and the pure logic that decides which are unlocked from a
//  StatsState. The view layer (StatsView) just renders `AchievementEvaluator
//  .evaluate(...)`; previously the badge unlock conditions were inline magic
//  comparisons scattered in the view.
//

import Foundation

struct Achievement: Identifiable, Equatable {
    let id: String
    let icon: String
    let title: String
    let subtitle: String
    /// Returns true when this achievement is earned for the given stats.
    let isUnlocked: (StatsState) -> Bool

    static func == (lhs: Achievement, rhs: Achievement) -> Bool { lhs.id == rhs.id }
}

enum AchievementEvaluator {

    /// The full catalog, in display order. Conditions read from StatsState so
    /// they're trivially testable.
    static let catalog: [Achievement] = [
        Achievement(id: "first_session", icon: "🎯", title: "First Session",
                    subtitle: "Complete 1 session") { $0.totalSessions >= 1 },
        Achievement(id: "five_today", icon: "⚡", title: "Speed Learner",
                    subtitle: "5 sessions in a day") { $0.todaySessions >= 5 },
        Achievement(id: "streak_7", icon: "🔥", title: "On Fire",
                    subtitle: "7 day streak") { $0.currentStreak >= 7 },
        Achievement(id: "streak_30", icon: "💎", title: "Diamond Focus",
                    subtitle: "30 day streak") { $0.currentStreak >= 30 },
        Achievement(id: "sessions_100", icon: "🏆", title: "Century Club",
                    subtitle: "100 sessions") { $0.totalSessions >= 100 },
        Achievement(id: "minutes_1000", icon: "🎖️", title: "Master",
                    subtitle: "1000 minutes") { $0.totalFocusMinutes >= 1000 }
    ]

    /// Pairs each achievement with whether it's currently unlocked.
    static func evaluate(_ state: StatsState) -> [(achievement: Achievement, unlocked: Bool)] {
        catalog.map { ($0, $0.isUnlocked(state)) }
    }

    /// IDs newly unlocked when moving from `old` to `new` — useful for firing a
    /// celebration exactly once.
    static func newlyUnlocked(from old: StatsState, to new: StatsState) -> [String] {
        catalog
            .filter { !$0.isUnlocked(old) && $0.isUnlocked(new) }
            .map(\.id)
    }
}
