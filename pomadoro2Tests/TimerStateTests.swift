//
//  TimerStateTests.swift
//  pomadoro2Tests
//
//  Verifies the explicit timer state machine: remaining-time derivation and
//  completion detection across idle / running / paused.
//

import Testing
import Foundation
@testable import pomadoro2

struct TimerStateTests {

    private let base = Date(timeIntervalSince1970: 10_000)

    @Test func idleReportsItsRemainingAndIsNotRunning() {
        let state = TimerState.idle(remaining: 1500)
        #expect(!state.isRunning)
        #expect(state.endDate == nil)
        #expect(state.remaining(now: base) == 1500)
        #expect(!state.hasCompleted(now: base))
    }

    @Test func pausedReportsItsRemainingAndIsNotRunning() {
        let state = TimerState.paused(remaining: 300)
        #expect(!state.isRunning)
        #expect(state.endDate == nil)
        // Time doesn't drain while paused, regardless of `now`.
        #expect(state.remaining(now: base.addingTimeInterval(99_999)) == 300)
    }

    @Test func runningDerivesRemainingFromWallClock() {
        let state = TimerState.running(endDate: base.addingTimeInterval(300))
        #expect(state.isRunning)
        #expect(state.endDate == base.addingTimeInterval(300))
        #expect(state.remaining(now: base) == 300)
        #expect(state.remaining(now: base.addingTimeInterval(100)) == 200)
    }

    @Test func runningClampsRemainingToZeroPastDeadline() {
        let state = TimerState.running(endDate: base.addingTimeInterval(60))
        #expect(state.remaining(now: base.addingTimeInterval(120)) == 0)
    }

    @Test func hasCompletedOnlyAtOrPastDeadlineWhileRunning() {
        let state = TimerState.running(endDate: base.addingTimeInterval(60))
        #expect(!state.hasCompleted(now: base))
        #expect(state.hasCompleted(now: base.addingTimeInterval(60)))
        #expect(state.hasCompleted(now: base.addingTimeInterval(61)))
    }
}
