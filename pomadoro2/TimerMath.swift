//
//  TimerMath.swift
//  pomadoro2
//
//  Pure, side-effect-free timer helpers. Kept separate from TimerManager so
//  they can be unit-tested without constructing the (Firebase-backed) manager.
//

import Foundation

enum TimerMath {
    /// Formats a remaining duration as `mm:ss`, clamping negatives to zero.
    ///
    /// Rounds up so a deadline-based countdown shows a whole "25:00" at the
    /// start and counts down to "00:01" → "00:00" at completion, rather than
    /// flashing "24:59" immediately or sitting on "00:00" for the last second
    /// (which fractional `timeRemaining` from the wall-clock engine would cause
    /// with truncation).
    static func formattedTime(_ timeRemaining: TimeInterval) -> String {
        let clamped = max(0, timeRemaining)
        let totalSeconds = Int(clamped.rounded(.up))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    /// Fraction of the session elapsed, in the range 0...1.
    /// Returns 0 for a non-positive total to avoid division by zero.
    static func progress(timeRemaining: TimeInterval, total: TimeInterval) -> Double {
        guard total > 0 else { return 0 }
        let elapsedFraction = 1 - (timeRemaining / total)
        return min(1, max(0, elapsedFraction))
    }

    /// Falls back to a default emoji when the user clears the field.
    static func normalizedEmoji(_ value: String, default fallback: String) -> String {
        value.isEmpty ? fallback : value
    }

    /// Seconds left until `endDate` relative to `now`, clamped to zero.
    /// This is the deadline-based countdown: the wall clock is the source of
    /// truth, so the value is correct regardless of when it's sampled (e.g.
    /// after the app was suspended in the background).
    static func remaining(until endDate: Date, now: Date) -> TimeInterval {
        max(0, endDate.timeIntervalSince(now))
    }

    /// Whether a deadline-based session has reached completion at `now`.
    static func hasCompleted(endDate: Date, now: Date) -> Bool {
        now >= endDate
    }
}
