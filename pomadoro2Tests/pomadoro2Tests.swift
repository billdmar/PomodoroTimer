//
//  pomadoro2Tests.swift
//  pomadoro2Tests
//
//  Unit tests for the app's pure timer and streak logic.
//

import Testing
import Foundation
@testable import pomadoro2

struct TimerMathTests {

    // MARK: - formattedTime

    @Test func formatsWholeMinutes() {
        #expect(TimerMath.formattedTime(25 * 60) == "25:00")
    }

    @Test func formatsSubMinute() {
        #expect(TimerMath.formattedTime(5) == "00:05")
    }

    @Test func formatsMixedMinutesAndSeconds() {
        #expect(TimerMath.formattedTime(90) == "01:30")
    }

    @Test func formatsZero() {
        #expect(TimerMath.formattedTime(0) == "00:00")
    }

    @Test func clampsNegativeToZero() {
        #expect(TimerMath.formattedTime(-10) == "00:00")
    }

    // MARK: - progress

    @Test func progressAtStartIsZero() {
        #expect(TimerMath.progress(timeRemaining: 1500, total: 1500) == 0)
    }

    @Test func progressAtHalfway() {
        #expect(TimerMath.progress(timeRemaining: 750, total: 1500) == 0.5)
    }

    @Test func progressAtEndIsOne() {
        #expect(TimerMath.progress(timeRemaining: 0, total: 1500) == 1)
    }

    @Test func progressGuardsAgainstZeroTotal() {
        #expect(TimerMath.progress(timeRemaining: 0, total: 0) == 0)
    }

    @Test func progressIsClampedToUnitRange() {
        // Over-run (negative remaining) should not exceed 1.
        #expect(TimerMath.progress(timeRemaining: -30, total: 1500) == 1)
    }

    // MARK: - normalizedEmoji

    @Test func keepsNonEmptyEmoji() {
        #expect(TimerMath.normalizedEmoji("🔥", default: "🍅") == "🔥")
    }

    @Test func fallsBackOnEmptyEmoji() {
        #expect(TimerMath.normalizedEmoji("", default: "🍅") == "🍅")
    }
}

struct StreakCalculatorTests {

    private let calendar = Calendar(identifier: .gregorian)

    private func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        return Calendar(identifier: .gregorian).date(from: components)!
    }

    // MARK: - updatedStreak

    @Test func firstCompletionStartsAtOne() {
        let streak = StreakCalculator.updatedStreak(
            previousStreak: 0,
            lastCompletion: nil,
            now: day(2026, 6, 8),
            calendar: calendar
        )
        #expect(streak == 1)
    }

    @Test func sameDayDoesNotIncrement() {
        let lastCompletion = day(2026, 6, 8)
        let laterSameDay = calendar.date(byAdding: .hour, value: 3, to: lastCompletion)!
        let streak = StreakCalculator.updatedStreak(
            previousStreak: 4,
            lastCompletion: lastCompletion,
            now: laterSameDay,
            calendar: calendar
        )
        #expect(streak == 4)
    }

    @Test func consecutiveDayIncrements() {
        let streak = StreakCalculator.updatedStreak(
            previousStreak: 4,
            lastCompletion: day(2026, 6, 7),
            now: day(2026, 6, 8),
            calendar: calendar
        )
        #expect(streak == 5)
    }

    @Test func multiDayGapResetsToOne() {
        // Three days later — the streak is broken.
        let streak = StreakCalculator.updatedStreak(
            previousStreak: 12,
            lastCompletion: day(2026, 6, 5),
            now: day(2026, 6, 8),
            calendar: calendar
        )
        #expect(streak == 1)
    }

    @Test func exactlyOneDayGapStillCounts() {
        let streak = StreakCalculator.updatedStreak(
            previousStreak: 1,
            lastCompletion: day(2026, 6, 7),
            now: day(2026, 6, 8),
            calendar: calendar
        )
        #expect(streak == 2)
    }

    // MARK: - isActiveDay

    @Test func lastCompletionDayIsActive() {
        let last = day(2026, 6, 8)
        #expect(StreakCalculator.isActiveDay(last, currentStreak: 3, lastCompletion: last, calendar: calendar))
    }

    @Test func daysWithinStreakWindowAreActive() {
        let last = day(2026, 6, 8)
        // streak of 3 covers Jun 6, 7, 8.
        #expect(StreakCalculator.isActiveDay(day(2026, 6, 6), currentStreak: 3, lastCompletion: last, calendar: calendar))
    }

    @Test func dayBeforeStreakWindowIsInactive() {
        let last = day(2026, 6, 8)
        // streak of 3 covers Jun 6, 7, 8 — Jun 5 is outside.
        #expect(!StreakCalculator.isActiveDay(day(2026, 6, 5), currentStreak: 3, lastCompletion: last, calendar: calendar))
    }

    @Test func futureDayIsInactive() {
        let last = day(2026, 6, 8)
        #expect(!StreakCalculator.isActiveDay(day(2026, 6, 9), currentStreak: 3, lastCompletion: last, calendar: calendar))
    }

    @Test func noStreakMeansNoActiveDays() {
        let last = day(2026, 6, 8)
        #expect(!StreakCalculator.isActiveDay(last, currentStreak: 0, lastCompletion: last, calendar: calendar))
    }

    @Test func noCompletionMeansNoActiveDays() {
        #expect(!StreakCalculator.isActiveDay(day(2026, 6, 8), currentStreak: 5, lastCompletion: nil, calendar: calendar))
    }
}
