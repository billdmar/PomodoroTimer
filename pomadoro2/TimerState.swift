//
//  TimerState.swift
//  pomadoro2
//
//  Explicit state machine for the countdown, replacing the previous implicit
//  combination of `endDate: Date?` + an `isRunning` flag (which allowed
//  illegal/contradictory states). The wall clock is still the source of truth:
//  a running state carries its `endDate`, and remaining time is always derived.
//

import Foundation

enum TimerState: Equatable {
    /// Stopped, showing a full duration ready to start.
    case idle(remaining: TimeInterval)
    /// Counting down toward `endDate`.
    case running(endDate: Date)
    /// Frozen mid-session at `remaining`.
    case paused(remaining: TimeInterval)

    var isRunning: Bool {
        if case .running = self { return true }
        return false
    }

    /// The deadline if running, else nil (used for notifications / widgets /
    /// Live Activity).
    var endDate: Date? {
        if case let .running(endDate) = self { return endDate }
        return nil
    }

    /// Seconds left, derived from the wall clock when running.
    func remaining(now: Date) -> TimeInterval {
        switch self {
        case let .idle(remaining), let .paused(remaining):
            return remaining
        case let .running(endDate):
            return TimerMath.remaining(until: endDate, now: now)
        }
    }

    /// Whether a running session has reached its deadline at `now`.
    func hasCompleted(now: Date) -> Bool {
        guard case let .running(endDate) = self else { return false }
        return TimerMath.hasCompleted(endDate: endDate, now: now)
    }
}

/// Tunable constants for the timer, named rather than scattered as magic
/// numbers through TimerManager.
enum TimerConstants {
    static let defaultFocusDuration: TimeInterval = 25 * 60
    static let defaultBreakDuration: TimeInterval = 5 * 60
    static let defaultLongBreakDuration: TimeInterval = 15 * 60
    /// UI refresh cadence — fast enough for a smooth ring, light on CPU.
    static let tickInterval: TimeInterval = 0.25
    /// `AudioServicesPlaySystemSound` id for the completion chime.
    static let completionSoundID: UInt32 = 1005
    static let completionNotificationID = "timer.completion"
}
