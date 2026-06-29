//
//  SessionEngineTests.swift
//  pomadoro2Tests
//
//  Direct tests for the extracted countdown clock: state transitions and the
//  onTick / onFinished callbacks, without TimerManager's orchestration.
//

import Testing
import Foundation
@testable import pomadoro2

@MainActor
struct SessionEngineTests {

    @Test func startsRunningWithADeadline() {
        let engine = SessionEngine(initialRemaining: 1500)
        #expect(!engine.isRunning)
        let end = engine.start(duration: 1500)
        #expect(engine.isRunning)
        #expect(engine.endDate == end)
        // Remaining is derived from the wall clock, so ~1500 right after start.
        #expect(engine.remaining() > 1499 && engine.remaining() <= 1500)
    }

    @Test func pauseFreezesRemainingAndStopsRunning() {
        let engine = SessionEngine(initialRemaining: 1500)
        engine.start(duration: 1500)
        engine.pause()
        #expect(!engine.isRunning)
        #expect(engine.endDate == nil)
        #expect(engine.remaining() > 0)
    }

    @Test func resetReturnsToIdleAtGivenRemaining() {
        let engine = SessionEngine(initialRemaining: 1500)
        engine.start(duration: 1500)
        engine.reset(to: 300)
        #expect(!engine.isRunning)
        #expect(engine.remaining() == 300)
    }

    @Test func restorePausedSetsRemainingWithoutRunning() {
        let engine = SessionEngine(initialRemaining: 1500)
        engine.restorePaused(remaining: 420)
        #expect(!engine.isRunning)
        #expect(engine.remaining() == 420)
    }

    @Test func extendWhilePausedAddsTimeAndReturnsNil() {
        let engine = SessionEngine(initialRemaining: 1500)
        engine.restorePaused(remaining: 300)
        let newEnd = engine.extend(by: 60)
        #expect(newEnd == nil)
        #expect(engine.remaining() == 360)
    }

    @Test func extendWhileRunningReanchorsAndReturnsDeadline() {
        let engine = SessionEngine(initialRemaining: 1500)
        engine.start(duration: 100)
        let newEnd = engine.extend(by: 60)
        #expect(newEnd != nil)
        // ~160s remaining after extending a ~100s session by 60s.
        #expect(engine.remaining() > 159 && engine.remaining() <= 160)
    }

    @Test func recomputeFiresFinishedOnceWhenDeadlinePassed() {
        let engine = SessionEngine(initialRemaining: 1)
        var ticks: [TimeInterval] = []
        var finishedCount = 0
        engine.onTick = { ticks.append($0) }
        engine.onFinished = { finishedCount += 1 }

        // Start with a deadline already in the past via a 0-second duration.
        engine.start(duration: 0)
        engine.recompute()

        #expect(finishedCount == 1)
        #expect(!engine.isRunning)
        #expect(ticks.last == 0)

        // A second recompute must NOT re-fire (engine already left running).
        engine.recompute()
        #expect(finishedCount == 1)
    }

    @Test func recomputeReportsRemainingWhileRunning() {
        let engine = SessionEngine(initialRemaining: 1500)
        var lastTick: TimeInterval?
        engine.onTick = { lastTick = $0 }
        engine.start(duration: 1500)
        engine.recompute()
        #expect(lastTick != nil)
        #expect((lastTick ?? 0) > 1499)
    }
}
