//
//  TimerManagerTests.swift
//  pomadoro2Tests
//
//  Orchestration tests for the TimerManager state machine, made possible by the
//  dependency-injection initializer (mock backend + isolated UserDefaults +
//  external services disabled so no Firebase / notifications / Live Activity
//  fire during tests).
//

import Testing
import Foundation
@testable import pomadoro2

@MainActor
struct TimerManagerTests {

    /// Builds a manager isolated from Firebase/notifications/Live Activity, with
    /// a fresh UserDefaults suite and a recording backend.
    private func makeManager() -> (TimerManager, MockStatsBackend, UserDefaults) {
        let suite = "TimerManagerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let backend = MockStatsBackend()
        let manager = TimerManager(
            backend: backend,
            defaults: defaults,
            enableExternalServices: false
        )
        return (manager, backend, defaults)
    }

    @Test func startsRunningAndStopsOnPause() {
        let (m, _, _) = makeManager()
        #expect(!m.isRunning)
        m.startTimer()
        #expect(m.isRunning)
        m.pauseTimer()
        #expect(!m.isRunning)
        // Paused mid-session keeps (roughly) the remaining time, not a reset.
        #expect(m.timeRemaining <= m.focusDuration)
        #expect(m.timeRemaining > 0)
    }

    @Test func resetReturnsToFullDurationAndIdle() {
        let (m, _, _) = makeManager()
        m.startTimer()
        m.resetTimer()
        #expect(!m.isRunning)
        #expect(m.timeRemaining == m.focusDuration)
    }

    @Test func skipWhileRunningTogglesModeAndKeepsRunning() {
        let (m, _, _) = makeManager()
        #expect(m.isFocusMode)
        m.startTimer()
        m.skipTimer()
        #expect(!m.isFocusMode)      // now on a break
        #expect(m.isRunning)         // skip restarts immediately
    }

    @Test func switchModeFlipsModeAndStaysStopped() {
        let (m, _, _) = makeManager()
        m.switchMode()
        #expect(!m.isFocusMode)
        #expect(!m.isRunning)
        #expect(m.timeRemaining == m.breakDuration)
    }

    @Test func extendAddsTimeWhilePaused() {
        let (m, _, _) = makeManager()
        m.switchMode()                 // idle on break
        let before = m.timeRemaining
        m.extend(byMinutes: 5)
        #expect(m.timeRemaining == before + 5 * 60)
    }

    @Test func updateSettingsPersistsAndAppliesWhenIdle() {
        let (m, _, defaults) = makeManager()
        m.updateSettings(focusMinutes: 50, breakMinutes: 10,
                         focusEmoji: "🔥", breakEmoji: "☕", longBreakMinutes: 20)
        #expect(m.focusDuration == 50 * 60)
        #expect(m.timeRemaining == 50 * 60) // applied because idle

        // A brand-new manager over the same defaults sees the persisted values.
        let reloaded = TimerManager(backend: MockStatsBackend(), defaults: defaults,
                                    enableExternalServices: false)
        #expect(reloaded.focusDuration == 50 * 60)
        #expect(reloaded.longBreakDuration == 20 * 60)
        #expect(reloaded.focusEmoji == "🔥")
    }

    @Test func dailyGoalPersists() {
        let (m, _, defaults) = makeManager()
        m.setDailyGoal(minutes: 90)
        #expect(m.dailyGoalMinutes == 90)
        let reloaded = TimerManager(backend: MockStatsBackend(), defaults: defaults,
                                    enableExternalServices: false)
        #expect(reloaded.dailyGoalMinutes == 90)
    }

    @Test func appearanceChoicesPersist() {
        let (m, _, defaults) = makeManager()
        m.updateAppearance(accent: .grape, appearance: .dark, sound: .bell)
        let reloaded = TimerManager(backend: MockStatsBackend(), defaults: defaults,
                                    enableExternalServices: false)
        #expect(reloaded.accentTheme == .grape)
        #expect(reloaded.appearanceMode == .dark)
        #expect(reloaded.completionSound == .bell)
    }

    @Test func crashRecoveryRestoresAPausedSession() {
        let suite = "TimerManagerTests.recovery.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        // Simulate a session that was running when the app died: snapshot it
        // directly via the same store the manager uses.
        SessionStore(defaults: defaults).save(SessionSnapshot(
            savedAt: Date(),
            timeRemaining: 600,
            isFocusMode: true,
            wasRunning: true
        ))

        let recovered = TimerManager(backend: MockStatsBackend(), defaults: defaults,
                                     enableExternalServices: false)
        // Restored paused (the user resumes explicitly), near the saved time.
        #expect(!recovered.isRunning)
        #expect(recovered.timeRemaining <= 600)
        #expect(recovered.timeRemaining > 0)
    }
}
