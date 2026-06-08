//
//  StreakCalculator.swift
//  pomadoro2
//
//  Pure streak math, separated from TimerManager for testability.
//

import Foundation

enum StreakCalculator {
    /// Computes the updated streak after completing a focus session.
    ///
    /// - Parameters:
    ///   - previousStreak: The streak before this completion.
    ///   - lastCompletion: When the previous focus session completed, if any.
    ///   - now: The completion time of the current session.
    ///   - calendar: Calendar used for day-boundary comparisons.
    /// - Returns: The new streak count.
    ///
    /// Rules:
    /// - First ever completion → streak of 1.
    /// - Another completion the same calendar day → streak unchanged.
    /// - Completion on the next calendar day → streak + 1.
    /// - A gap of two or more calendar days → streak resets to 1.
    static func updatedStreak(
        previousStreak: Int,
        lastCompletion: Date?,
        now: Date,
        calendar: Calendar = .current
    ) -> Int {
        guard let lastCompletion else { return 1 }

        let startOfLast = calendar.startOfDay(for: lastCompletion)
        let startOfNow = calendar.startOfDay(for: now)
        let dayGap = calendar.dateComponents([.day], from: startOfLast, to: startOfNow).day ?? 0

        switch dayGap {
        case 0:
            // Same day — already counted toward the streak.
            return max(previousStreak, 1)
        case 1:
            // Consecutive day — extend the streak.
            return previousStreak + 1
        default:
            // Missed a day (or clock moved backward) — start over.
            return 1
        }
    }

    /// Whether `date` falls on a calendar day the user completed a session,
    /// reconstructed from the current streak and the last completion date.
    ///
    /// The most recent `currentStreak` days ending on `lastCompletion` are
    /// considered active. Future days and days before the streak window are not.
    static func isActiveDay(
        _ date: Date,
        currentStreak: Int,
        lastCompletion: Date?,
        calendar: Calendar = .current
    ) -> Bool {
        guard currentStreak > 0, let lastCompletion else { return false }

        let startOfDate = calendar.startOfDay(for: date)
        let startOfLast = calendar.startOfDay(for: lastCompletion)
        let offset = calendar.dateComponents([.day], from: startOfDate, to: startOfLast).day ?? -1

        // offset == 0 is the last completion day; offset == streak-1 is the first.
        return offset >= 0 && offset < currentStreak
    }
}
