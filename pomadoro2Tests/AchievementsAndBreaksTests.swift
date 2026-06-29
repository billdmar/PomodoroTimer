//
//  AchievementsAndBreaksTests.swift
//  pomadoro2Tests
//
//  Covers the long-break cadence and the achievement unlock logic, plus the
//  new session-counter fields on StatsState.
//

import Testing
import Foundation
@testable import pomadoro2

struct BreakPolicyTests {

    @Test func shortBreakBeforeTheCadence() {
        #expect(BreakPolicy.breakKind(completedTodaySessions: 1, cadence: 4) == .short)
        #expect(BreakPolicy.breakKind(completedTodaySessions: 3, cadence: 4) == .short)
    }

    @Test func longBreakOnEveryNthSession() {
        #expect(BreakPolicy.breakKind(completedTodaySessions: 4, cadence: 4) == .long)
        #expect(BreakPolicy.breakKind(completedTodaySessions: 8, cadence: 4) == .long)
    }

    @Test func zeroSessionsOrCadenceIsAlwaysShort() {
        #expect(BreakPolicy.breakKind(completedTodaySessions: 0, cadence: 4) == .short)
        #expect(BreakPolicy.breakKind(completedTodaySessions: 4, cadence: 0) == .short)
    }
}

struct AchievementEvaluatorTests {

    @Test func freshStateUnlocksNothing() {
        let unlocked = AchievementEvaluator.evaluate(StatsState()).filter(\.unlocked)
        #expect(unlocked.isEmpty)
    }

    @Test func firstSessionUnlocksOnFirstCompletion() {
        let state = StatsState(totalSessions: 1)
        let map = Dictionary(uniqueKeysWithValues:
            AchievementEvaluator.evaluate(state).map { ($0.achievement.id, $0.unlocked) })
        #expect(map["first_session"] == true)
        #expect(map["sessions_100"] == false)
    }

    @Test func thresholdsUnlockTheRightBadges() {
        let state = StatsState(totalFocusMinutes: 1000, currentStreak: 30,
                               todaySessions: 5, totalSessions: 100)
        let unlockedIDs = Set(AchievementEvaluator.evaluate(state).filter(\.unlocked).map(\.achievement.id))
        #expect(unlockedIDs.contains("minutes_1000"))
        #expect(unlockedIDs.contains("streak_30"))
        #expect(unlockedIDs.contains("streak_7")) // 30 >= 7
        #expect(unlockedIDs.contains("five_today"))
        #expect(unlockedIDs.contains("sessions_100"))
    }

    @Test func newlyUnlockedReportsOnlyTheTransition() {
        let before = StatsState(currentStreak: 6)
        let after = StatsState(currentStreak: 7)
        #expect(AchievementEvaluator.newlyUnlocked(from: before, to: after) == ["streak_7"])
        // No change → nothing newly unlocked.
        #expect(AchievementEvaluator.newlyUnlocked(from: after, to: after).isEmpty)
    }
}

struct StatsSessionCounterTests {

    private let cal = Calendar(identifier: .gregorian)
    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        DateComponents(calendar: cal, year: y, month: m, day: d).date!
    }

    @Test func completionIncrementsBothSessionCounters() {
        let s0 = StatsState(lastCompletionDate: day(2026, 6, 29))
        let s1 = StatsCalculator.applyingCompletion(s0, focusMinutes: 25,
                                                    now: day(2026, 6, 29).addingTimeInterval(3600),
                                                    calendar: cal)
        #expect(s1.todaySessions == 1)
        #expect(s1.totalSessions == 1)
        let s2 = StatsCalculator.applyingCompletion(s1, focusMinutes: 25,
                                                    now: day(2026, 6, 29).addingTimeInterval(7200),
                                                    calendar: cal)
        #expect(s2.todaySessions == 2)
        #expect(s2.totalSessions == 2)
    }

    @Test func newDayResetsTodaySessionsButNotTotal() {
        let s0 = StatsState(lastCompletionDate: day(2026, 6, 28), todaySessions: 3, totalSessions: 10)
        let s1 = StatsCalculator.applyingCompletion(s0, focusMinutes: 25,
                                                    now: day(2026, 6, 29), calendar: cal)
        #expect(s1.todaySessions == 1)   // reset then +1
        #expect(s1.totalSessions == 11)  // always accumulates
    }
}
