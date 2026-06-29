//
//  GoalsAndHistoryTests.swift
//  pomadoro2Tests
//
//  Covers the daily-goal progress math, the goal store, and the history
//  aggregation that feeds the charts.
//

import Testing
import Foundation
@testable import pomadoro2

struct GoalMathTests {

    @Test func progressIsTheRatioClampedToUnit() {
        #expect(GoalMath.progress(focusMinutesToday: 60, goalMinutes: 120) == 0.5)
        #expect(GoalMath.progress(focusMinutesToday: 0, goalMinutes: 120) == 0)
        #expect(GoalMath.progress(focusMinutesToday: 200, goalMinutes: 120) == 1) // clamps
    }

    @Test func nonPositiveGoalReadsAsComplete() {
        #expect(GoalMath.progress(focusMinutesToday: 0, goalMinutes: 0) == 1)
    }

    @Test func isMetAtOrAboveGoal() {
        #expect(GoalMath.isMet(focusMinutesToday: 120, goalMinutes: 120))
        #expect(GoalMath.isMet(focusMinutesToday: 121, goalMinutes: 120))
        #expect(!GoalMath.isMet(focusMinutesToday: 119, goalMinutes: 120))
    }
}

struct GoalStoreTests {
    private func defaults() -> UserDefaults {
        let suite = "GoalStoreTests.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: suite)!
        d.removePersistentDomain(forName: suite)
        return d
    }

    @Test func freshStoreReturnsDefaultGoal() {
        #expect(GoalStore(defaults: defaults()).loadGoalMinutes() == GoalStore.defaultGoalMinutes)
    }

    @Test func savedGoalRoundTrips() {
        let d = defaults()
        GoalStore(defaults: d).save(goalMinutes: 90)
        #expect(GoalStore(defaults: d).loadGoalMinutes() == 90)
    }
}

struct HistoryAggregatorTests {

    private let cal = Calendar(identifier: .gregorian)
    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        cal.startOfDay(for: DateComponents(calendar: cal, year: y, month: m, day: d).date!)
    }

    @Test func recentDaysFillsGapsWithZeroOldestFirst() {
        let now = day(2026, 6, 29)
        let totals: [Date: Int] = [day(2026, 6, 29): 50, day(2026, 6, 27): 25]
        let week = HistoryAggregator.recentDays(totals, days: 7, now: now, calendar: cal)
        #expect(week.count == 7)
        #expect(week.first?.date == day(2026, 6, 23)) // oldest first
        #expect(week.last?.date == day(2026, 6, 29))
        #expect(week.last?.minutes == 50)
        // Jun 28 had no focus → 0.
        #expect(week.first(where: { $0.date == day(2026, 6, 28) })?.minutes == 0)
        #expect(week.first(where: { $0.date == day(2026, 6, 27) })?.minutes == 25)
    }

    @Test func totalSumsTheWindow() {
        let now = day(2026, 6, 29)
        let totals = [day(2026, 6, 29): 50, day(2026, 6, 28): 25, day(2026, 6, 20): 999]
        // 20th is outside the 7-day window → excluded.
        #expect(HistoryAggregator.total(totals, days: 7, now: now, calendar: cal) == 75)
    }
}

struct DailyHistoryStoreTests {
    private func defaults() -> UserDefaults {
        let suite = "DailyHistoryStoreTests.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: suite)!
        d.removePersistentDomain(forName: suite)
        return d
    }

    @Test func accumulatesWithinADayAndPersists() {
        let cal = Calendar(identifier: .gregorian)
        let d = defaults()
        let store = DailyHistoryStore(defaults: d, calendar: cal)
        let date = DateComponents(calendar: cal, year: 2026, month: 6, day: 29, hour: 9).date!
        store.add(minutes: 25, on: date)
        store.add(minutes: 25, on: date.addingTimeInterval(3600)) // same day, later

        let totals = DailyHistoryStore(defaults: d, calendar: cal).loadTotals()
        #expect(totals[cal.startOfDay(for: date)] == 50)
    }
}
