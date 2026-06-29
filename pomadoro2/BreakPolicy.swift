//
//  BreakPolicy.swift
//  pomadoro2
//
//  Decides whether the break after a focus session should be a normal short
//  break or a longer one (the classic Pomodoro "long break every N sessions").
//  Pure and fully unit-testable.
//

import Foundation

enum BreakKind: Equatable {
    case short
    case long
}

enum BreakPolicy {
    /// Default cadence: a long break after every 4th focus session.
    static let defaultSessionsBeforeLongBreak = 4

    /// Given the number of focus sessions completed *today* (after the one that
    /// just finished), decides the break kind. Every `cadence`-th session earns
    /// a long break.
    static func breakKind(
        completedTodaySessions: Int,
        cadence: Int = defaultSessionsBeforeLongBreak
    ) -> BreakKind {
        guard cadence > 0, completedTodaySessions > 0 else { return .short }
        return completedTodaySessions % cadence == 0 ? .long : .short
    }
}
