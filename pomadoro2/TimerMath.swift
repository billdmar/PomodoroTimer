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
    static func formattedTime(_ timeRemaining: TimeInterval) -> String {
        let clamped = max(0, timeRemaining)
        let totalSeconds = Int(clamped)
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
}
