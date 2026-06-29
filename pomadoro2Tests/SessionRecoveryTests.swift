//
//  SessionRecoveryTests.swift
//  pomadoro2Tests
//
//  Verifies crash/quit session recovery: the snapshot round-trips through
//  storage, and the pure recovery logic resumes / expires correctly based on
//  real elapsed time.
//

import Testing
import Foundation
@testable import pomadoro2

struct SessionStoreTests {

    private func makeIsolatedDefaults() -> UserDefaults {
        let suite = "SessionStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    @Test func snapshotRoundTrips() {
        let defaults = makeIsolatedDefaults()
        let store = SessionStore(defaults: defaults)
        let snapshot = SessionSnapshot(
            savedAt: Date(timeIntervalSince1970: 1_000),
            timeRemaining: 600,
            isFocusMode: true,
            wasRunning: true
        )
        store.save(snapshot)
        #expect(SessionStore(defaults: defaults).load() == snapshot)
    }

    @Test func loadReturnsNilWhenEmpty() {
        #expect(SessionStore(defaults: makeIsolatedDefaults()).load() == nil)
    }

    @Test func clearRemovesSnapshot() {
        let defaults = makeIsolatedDefaults()
        let store = SessionStore(defaults: defaults)
        store.save(SessionSnapshot(savedAt: Date(), timeRemaining: 60,
                                   isFocusMode: false, wasRunning: false))
        store.clear()
        #expect(store.load() == nil)
    }
}

struct SessionRecoveryTests {

    private let base = Date(timeIntervalSince1970: 10_000)

    @Test func noSnapshotRecoversNothing() {
        #expect(SessionRecovery.recover(from: nil, now: base) == .none)
    }

    @Test func runningSessionResumesWithElapsedSubtracted() {
        let snapshot = SessionSnapshot(savedAt: base, timeRemaining: 600,
                                       isFocusMode: true, wasRunning: true)
        // 100s later → 500s should remain.
        let outcome = SessionRecovery.recover(from: snapshot,
                                              now: base.addingTimeInterval(100))
        #expect(outcome == .resume(timeRemaining: 500, isFocusMode: true))
    }

    @Test func runningSessionExpiresWhenDeadlinePassed() {
        let snapshot = SessionSnapshot(savedAt: base, timeRemaining: 60,
                                       isFocusMode: true, wasRunning: true)
        // 120s later → deadline passed.
        let outcome = SessionRecovery.recover(from: snapshot,
                                              now: base.addingTimeInterval(120))
        #expect(outcome == .expired(isFocusMode: true))
    }

    @Test func pausedSessionResumesUnchanged() {
        let snapshot = SessionSnapshot(savedAt: base, timeRemaining: 300,
                                       isFocusMode: false, wasRunning: false)
        // Even a long gap doesn't drain a paused session.
        let outcome = SessionRecovery.recover(from: snapshot,
                                              now: base.addingTimeInterval(99_999))
        #expect(outcome == .resume(timeRemaining: 300, isFocusMode: false))
    }

    @Test func runningSessionExactlyAtZeroExpires() {
        let snapshot = SessionSnapshot(savedAt: base, timeRemaining: 60,
                                       isFocusMode: true, wasRunning: true)
        let outcome = SessionRecovery.recover(from: snapshot,
                                              now: base.addingTimeInterval(60))
        #expect(outcome == .expired(isFocusMode: true))
    }
}
