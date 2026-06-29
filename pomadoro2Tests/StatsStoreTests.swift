//
//  StatsStoreTests.swift
//  pomadoro2Tests
//
//  Covers the focus-stats domain extracted from TimerManager: new-day reset,
//  completion accumulation + streak advance, multi-device merge, and local
//  persistence round-trip.
//

import Testing
import Foundation
@testable import pomadoro2

struct StatsCalculatorTests {

    private let calendar = Calendar(identifier: .gregorian)

    private func day(_ year: Int, _ month: Int, _ dayOfMonth: Int) -> Date {
        DateComponents(calendar: calendar, year: year, month: month, day: dayOfMonth).date!
    }

    // MARK: - isNewDay

    @Test func newDayWhenNoPriorCompletion() {
        #expect(StatsCalculator.isNewDay(lastCompletion: nil, now: day(2026, 6, 29), calendar: calendar))
    }

    @Test func notNewDayWithinSameDay() {
        let morning = day(2026, 6, 29)
        let evening = morning.addingTimeInterval(8 * 3600)
        #expect(!StatsCalculator.isNewDay(lastCompletion: morning, now: evening, calendar: calendar))
    }

    // MARK: - resettingForNewDay

    @Test func resetZeroesTodayOnNewDay() {
        let state = StatsState(todayFocusMinutes: 50, totalFocusMinutes: 200,
                               currentStreak: 4, lastCompletionDate: day(2026, 6, 28))
        let reset = StatsCalculator.resettingForNewDay(state, now: day(2026, 6, 29), calendar: calendar)
        #expect(reset.todayFocusMinutes == 0)
        #expect(reset.totalFocusMinutes == 200) // untouched
        #expect(reset.currentStreak == 4)        // untouched
    }

    @Test func resetIsNoOpWithinSameDay() {
        let morning = day(2026, 6, 29)
        let state = StatsState(todayFocusMinutes: 50, totalFocusMinutes: 200,
                               currentStreak: 4, lastCompletionDate: morning)
        let reset = StatsCalculator.resettingForNewDay(
            state, now: morning.addingTimeInterval(3600), calendar: calendar)
        #expect(reset == state)
    }

    // MARK: - applyingCompletion

    @Test func completionAccumulatesWithinSameDay() {
        let morning = day(2026, 6, 29)
        let state = StatsState(todayFocusMinutes: 25, totalFocusMinutes: 100,
                               currentStreak: 2, lastCompletionDate: morning)
        let updated = StatsCalculator.applyingCompletion(
            state, focusMinutes: 25, now: morning.addingTimeInterval(3600), calendar: calendar)
        #expect(updated.todayFocusMinutes == 50)
        #expect(updated.totalFocusMinutes == 125)
        #expect(updated.currentStreak == 2) // same day → unchanged
    }

    @Test func completionResetsTodayAndAdvancesStreakNextDay() {
        let state = StatsState(todayFocusMinutes: 50, totalFocusMinutes: 100,
                               currentStreak: 3, lastCompletionDate: day(2026, 6, 28))
        let updated = StatsCalculator.applyingCompletion(
            state, focusMinutes: 25, now: day(2026, 6, 29), calendar: calendar)
        #expect(updated.todayFocusMinutes == 25)  // new day → reset to this session
        #expect(updated.totalFocusMinutes == 125) // total always accumulates
        #expect(updated.currentStreak == 4)       // consecutive day → +1
    }

    @Test func completionResetsStreakAfterGap() {
        let state = StatsState(todayFocusMinutes: 50, totalFocusMinutes: 100,
                               currentStreak: 5, lastCompletionDate: day(2026, 6, 25))
        let updated = StatsCalculator.applyingCompletion(
            state, focusMinutes: 25, now: day(2026, 6, 29), calendar: calendar)
        #expect(updated.currentStreak == 1) // multi-day gap → reset to 1
    }

    // MARK: - merging

    @Test func mergeTakesFieldWiseMax() {
        let local = StatsState(todayFocusMinutes: 30, totalFocusMinutes: 100, currentStreak: 2)
        let remote = StatsState(todayFocusMinutes: 10, totalFocusMinutes: 250, currentStreak: 7)
        let merged = StatsCalculator.merging(local, remote: remote)
        #expect(merged.todayFocusMinutes == 30)
        #expect(merged.totalFocusMinutes == 250)
        #expect(merged.currentStreak == 7)
    }

    @Test func mergeTakesLaterCompletionDate() {
        let earlier = Date(timeIntervalSince1970: 1_000)
        let later = Date(timeIntervalSince1970: 2_000)
        // Remote completed more recently than local.
        let local = StatsState(currentStreak: 3, lastCompletionDate: earlier)
        let remote = StatsState(currentStreak: 3, lastCompletionDate: later)
        #expect(StatsCalculator.merging(local, remote: remote).lastCompletionDate == later)
        // Symmetric: local later than remote.
        #expect(StatsCalculator.merging(remote, remote: local).lastCompletionDate == later)
    }

    @Test func mergeKeepsWhicheverDateExists() {
        let date = Date(timeIntervalSince1970: 1_000)
        let withDate = StatsState(lastCompletionDate: date)
        let noDate = StatsState(lastCompletionDate: nil)
        #expect(StatsCalculator.merging(noDate, remote: withDate).lastCompletionDate == date)
        #expect(StatsCalculator.merging(withDate, remote: noDate).lastCompletionDate == date)
        #expect(StatsCalculator.merging(noDate, remote: noDate).lastCompletionDate == nil)
    }
}

struct StatsPersistenceTests {

    private func makeIsolatedDefaults() -> UserDefaults {
        let suite = "StatsPersistenceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    @Test func roundTrips() {
        let defaults = makeIsolatedDefaults()
        let store = StatsPersistence(defaults: defaults)
        let state = StatsState(todayFocusMinutes: 40, totalFocusMinutes: 300,
                               currentStreak: 6,
                               lastCompletionDate: Date(timeIntervalSince1970: 5_000))
        store.save(state)
        #expect(StatsPersistence(defaults: defaults).load() == state)
    }

    @Test func freshLoadIsZeroed() {
        let loaded = StatsPersistence(defaults: makeIsolatedDefaults()).load()
        #expect(loaded == StatsState())
    }
}
