//
//  TimerManager.swift
//  pomadoro2
//
//  Enhanced with missing debug methods and app lock manager
//

import Foundation
import SwiftUI
import UserNotifications
import AudioToolbox
import Combine
import WidgetKit

@MainActor
class TimerManager: ObservableObject {
    @Published var isRunning = false
    @Published var timeRemaining: TimeInterval = TimerConstants.defaultFocusDuration
    @Published var isFocusMode = true
    @Published var isLocked = false
    @Published var currentEncouragingMessage = ""
    @Published var showingCompletionAlert = false
    @Published var completionMessage = ""
    @Published var currentMotivationalQuote = ""

    // Settings
    @Published var focusDuration: TimeInterval = TimerConstants.defaultFocusDuration
    @Published var breakDuration: TimeInterval = TimerConstants.defaultBreakDuration
    @Published var focusEmoji = "🍅"
    @Published var breakEmoji = "😌"

    // Local stats tracking
    @Published var todayFocusMinutes: Int = 0
    @Published var totalFocusMinutes: Int = 0
    @Published var currentStreak: Int = 0
    @Published var lastCompletionDate: Date?

    // Firebase integration
    private let firebaseManager = FirebaseManager()

    /// Focus-mode lock + Screen Time shielding. A dependency, not observable
    /// state owned by the timer — exposed read-only for views that present its
    /// alerts.
    let appLockManager = AppLockManager()

    private let settingsStore = SettingsStore()
    private let sessionStore = SessionStore()
    private let statsPersistence = StatsPersistence()
    private let sharedSessionStore = SharedSessionStore()
    // Min deployment is iOS 18.5, so the 16.1-gated controller is always usable.
    private let liveActivity = LiveActivityController()
    private var cancellables = Set<AnyCancellable>()

    // Explicit state machine (see TimerState). The wall clock remains the
    // source of truth — a running state carries its `endDate` and the visible
    // `timeRemaining`/`isRunning` are derived from `state`, so the countdown is
    // immune to background suspension and tick drift. `tickTask` only refreshes
    // the UI; it is not the clock.
    private var state: TimerState = .idle(remaining: TimerConstants.defaultFocusDuration) {
        didSet { isRunning = state.isRunning }
    }
    private var tickTask: Task<Void, Never>?

    init() {
        loadSettings()
        state = .idle(remaining: focusDuration)
        timeRemaining = focusDuration
        selectRandomMessage()
        generateRandomMotivationalQuote()
        requestNotificationPermission()
        loadLocalStats()
        recoverSession()
        setupFirebase()
    }

    private func loadSettings() {
        let values = settingsStore.load()
        focusDuration = values.focusDuration
        breakDuration = values.breakDuration
        focusEmoji = values.focusEmoji
        breakEmoji = values.breakEmoji
    }

    /// Restores an interrupted session (the app was quit/crashed mid-timer).
    /// A running session resumes — paused — at the time that's actually left
    /// after accounting for real elapsed time; an already-expired session is
    /// simply cleared so the user starts fresh.
    private func recoverSession() {
        switch SessionRecovery.recover(from: sessionStore.load(), now: Date()) {
        case .none:
            break
        case let .resume(remaining, focusMode):
            isFocusMode = focusMode
            // Restored as paused: the user explicitly resumes.
            state = .paused(remaining: remaining)
            timeRemaining = remaining
            isLocked = false
        case let .expired(focusMode):
            isFocusMode = focusMode
            let remaining = focusMode ? focusDuration : breakDuration
            state = .idle(remaining: remaining)
            timeRemaining = remaining
        }
        sessionStore.clear()
    }

    /// Snapshots the current session so it can be recovered after a quit/crash.
    private func saveSession() {
        sessionStore.save(SessionSnapshot(
            savedAt: Date(),
            timeRemaining: timeRemaining,
            isFocusMode: isFocusMode,
            wasRunning: isRunning
        ))
    }

    /// Mirrors the live session into the shared App Group suite and refreshes
    /// the widget so the Home/Lock screen reflects the current timer.
    private func publishSharedState() {
        sharedSessionStore.save(SharedSessionState(
            isRunning: isRunning,
            isFocusMode: isFocusMode,
            emoji: currentEmoji,
            endDate: state.endDate,
            timeRemaining: timeRemaining
        ))
        WidgetCenter.shared.reloadAllTimelines()
    }

    var currentEmoji: String {
        return isFocusMode ? focusEmoji : breakEmoji
    }

    var firebaseManagerPublished: FirebaseManager {
        return firebaseManager
    }

    private func setupFirebase() {
        // Auto sign-in anonymously if not authenticated
        if !firebaseManager.isAuthenticated {
            firebaseManager.signInAnonymously()
        }

        // Load stats from Firebase when authenticated
        firebaseManager.$isAuthenticated
            .sink { [weak self] isAuthenticated in
                if isAuthenticated {
                    self?.syncWithFirebase()
                }
            }
            .store(in: &cancellables)
    }

    func startTimer() {
        // Anchor the deadline to the wall clock so the countdown stays correct
        // even if the app is backgrounded or the tick is delayed.
        let endDate = Date().addingTimeInterval(timeRemaining)
        state = .running(endDate: endDate)

        isLocked = true
        selectRandomMessage()

        // Lock app only during focus mode
        if isFocusMode {
            // Request Screen Time authorization once so real shielding can take
            // effect; falls back to motivational nudges if unauthorized.
            if !appLockManager.screenTimeAuthorized {
                Task { await appLockManager.requestScreenTimeAuthorization() }
            }
            appLockManager.lockApp()
        }

        scheduleCompletionNotification(endDate: endDate)
        saveSession()
        publishSharedState()
        liveActivity.start(endDate: endDate, isFocusMode: isFocusMode, emoji: currentEmoji)
        startTick()
        Haptics.medium()
    }

    func pauseTimer() {
        // Freeze the derived remaining time before leaving the running state.
        // Computed directly from `state` (not via recompute()) so pausing never
        // triggers completion — completion flows only through the tick/recompute
        // path, which avoids a pause↔complete recursion.
        if state.isRunning {
            let remaining = state.remaining(now: Date())
            timeRemaining = remaining
            state = .paused(remaining: remaining)
        }
        isLocked = false
        stopTick()
        cancelCompletionNotification()

        // Unlock app when pausing
        appLockManager.unlockApp()

        // Persist the paused state so it survives a quit.
        saveSession()
        publishSharedState()
        liveActivity.end()
    }

    // MARK: - Tick & deadline

    /// Drives UI refresh while running. The wall clock — not this loop — is the
    /// source of truth, so a delayed or skipped tick never loses time.
    private func startTick() {
        stopTick()
        tickTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self, self.state.isRunning else { return }
                self.recompute()
                try? await Task.sleep(nanoseconds: UInt64(TimerConstants.tickInterval * 1_000_000_000))
            }
        }
    }

    private func stopTick() {
        tickTask?.cancel()
        tickTask = nil
    }

    /// Recomputes `timeRemaining` from the deadline and completes the session
    /// once the deadline has passed. Safe to call on foreground/recovery — it
    /// shares the single completion path with the normal tick.
    func recompute() {
        guard state.isRunning else { return }
        let now = Date()
        if state.hasCompleted(now: now) {
            timeRemaining = 0
            timerCompleted()
        } else {
            timeRemaining = state.remaining(now: now)
        }
    }

    private func scheduleCompletionNotification(endDate: Date) {
        let interval = endDate.timeIntervalSinceNow
        guard interval > 0 else { return }

        let content = UNMutableNotificationContent()
        let completedMode = isFocusMode ? "Focus" : "Break"
        let nextMode = isFocusMode ? "break" : "focus"
        content.title = "Pomodoro Timer Complete! 🍅"
        content.body = "\(completedMode) session finished! Ready for \(nextMode) time?"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(
            identifier: TimerConstants.completionNotificationID,
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                Log.debug("Completion notification error: \(error)")
            }
        }
    }

    private func cancelCompletionNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [TimerConstants.completionNotificationID]
        )
    }

    /// Drives background/foreground handling for a running session. On return
    /// to the foreground we recompute from the wall clock (recovering any time
    /// that passed while suspended, completing the session if its deadline
    /// passed); on backgrounding we persist a snapshot for crash recovery.
    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .active:
            recompute()
        case .background:
            if isRunning { saveSession() }
        default:
            break
        }
    }

    func restartCurrentTimer() {
        pauseTimer()
        timeRemaining = isFocusMode ? focusDuration : breakDuration
        startTimer()
    }

    deinit {
        tickTask?.cancel()
    }

    func resetTimer() {
        pauseTimer()
        let remaining = isFocusMode ? focusDuration : breakDuration
        state = .idle(remaining: remaining)
        timeRemaining = remaining
        // Back to a fresh idle state — nothing to recover.
        sessionStore.clear()
        publishSharedState()
        Haptics.light()
    }

    func skipTimer() {
        if isRunning {
            pauseTimer()
            isFocusMode.toggle()
            timeRemaining = isFocusMode ? focusDuration : breakDuration
            startTimer()
        } else {
            timerCompleted()
        }
    }

    func switchMode() {
        pauseTimer()
        isFocusMode.toggle()
        let remaining = isFocusMode ? focusDuration : breakDuration
        state = .idle(remaining: remaining)
        timeRemaining = remaining
    }

    private func timerCompleted() {
        pauseTimer()

        let completedMode = isFocusMode ? "Focus" : "Break"
        let nextMode = isFocusMode ? "Break" : "Focus"

        completionMessage = "\(completedMode) session complete! Time for a \(nextMode.lowercased()) 🎉"
        showingCompletionAlert = true

        // In-app feedback. The scheduled completion notification (set at start)
        // covers the case where the app is backgrounded/suspended at the
        // deadline; pauseTimer() above cancels it so we never double-notify.
        AudioServicesPlaySystemSound(TimerConstants.completionSoundID)
        Haptics.success()

        // Unlock app when session completes
        appLockManager.unlockApp()

        // Update stats if it was a focus session
        if isFocusMode {
            let focusMinutes = Int(focusDuration / 60)
            updateStats(focusMinutesCompleted: focusMinutes)

            // Log session to Firebase
            Task { await firebaseManager.logFocusSession(duration: focusMinutes) }
        }

        isFocusMode.toggle()
        let remaining = isFocusMode ? focusDuration : breakDuration
        state = .idle(remaining: remaining)
        timeRemaining = remaining

        // The completed session shouldn't be recovered on next launch; the
        // pauseTimer() above persisted a snapshot, so clear it here.
        sessionStore.clear()
        publishSharedState()
    }

    // MARK: - Stats

    /// Bridges the view-facing @Published stats to the value model that the
    /// pure StatsCalculator / StatsPersistence operate on.
    private var statsState: StatsState {
        get {
            StatsState(
                todayFocusMinutes: todayFocusMinutes,
                totalFocusMinutes: totalFocusMinutes,
                currentStreak: currentStreak,
                lastCompletionDate: lastCompletionDate
            )
        }
        set {
            todayFocusMinutes = newValue.todayFocusMinutes
            totalFocusMinutes = newValue.totalFocusMinutes
            currentStreak = newValue.currentStreak
            lastCompletionDate = newValue.lastCompletionDate
        }
    }

    private func loadLocalStats() {
        var state = statsPersistence.load()
        let reset = StatsCalculator.resettingForNewDay(state, now: Date())
        if reset != state {
            state = reset
            statsPersistence.save(state)
        }
        statsState = state
    }

    private func updateStats(focusMinutesCompleted: Int) {
        let updated = StatsCalculator.applyingCompletion(
            statsState,
            focusMinutes: focusMinutesCompleted,
            now: Date()
        )
        statsState = updated
        statsPersistence.save(updated)
        syncWithFirebase()
    }

    private func syncWithFirebase() {
        Task { [weak self] in
            guard let self else { return }
            // Save current stats to Firebase.
            await firebaseManager.saveUserStats(
                focusMinutes: todayFocusMinutes,
                totalMinutes: totalFocusMinutes,
                streak: currentStreak
            )

            // Load stats from Firebase (in case the user has data from other
            // devices) and reconcile. Field-wise max + latest completion date.
            if let remote = await firebaseManager.loadUserStats() {
                let merged = StatsCalculator.merging(statsState, remote: remote)
                statsState = merged
                statsPersistence.save(merged)
            }
        }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, error in
            if let error = error {
                Log.debug("Notification permission error: \(error)")
            }
        }
    }

    private func selectRandomMessage() {
        currentEncouragingMessage = MotivationalContent.randomEncouragement()
    }

    func generateRandomMotivationalQuote() {
        currentMotivationalQuote = MotivationalContent.randomQuote()
    }

    func updateSettings(focusMinutes: Double, breakMinutes: Double, focusEmoji: String, breakEmoji: String) {
        focusDuration = focusMinutes * 60
        breakDuration = breakMinutes * 60
        self.focusEmoji = TimerMath.normalizedEmoji(focusEmoji, default: "🍅")
        self.breakEmoji = TimerMath.normalizedEmoji(breakEmoji, default: "😌")

        // Persist so the preferences survive relaunch.
        settingsStore.save(SettingsStore.Values(
            focusDuration: focusDuration,
            breakDuration: breakDuration,
            focusEmoji: self.focusEmoji,
            breakEmoji: self.breakEmoji
        ))

        if !isRunning {
            let remaining = isFocusMode ? focusDuration : breakDuration
            state = .idle(remaining: remaining)
            timeRemaining = remaining
        }
    }

    var formattedTime: String {
        TimerMath.formattedTime(timeRemaining)
    }

    var progress: Double {
        let totalTime = isFocusMode ? focusDuration : breakDuration
        return TimerMath.progress(timeRemaining: timeRemaining, total: totalTime)
    }

    // MARK: - Debug Methods (only available in DEBUG builds)

    #if DEBUG
    func debugPrintCurrentUser() {
        print("=== DEBUG: Current User ===")
        if let user = firebaseManager.currentUser {
            print("User ID: \(user.uid)")
            print("Is Anonymous: \(user.isAnonymous)")
            print("Is Authenticated: \(firebaseManager.isAuthenticated)")
        } else {
            print("No user authenticated")
        }
        print("Is Online: \(firebaseManager.isOnline)")
        print("========================")
    }

    func debugPrintTimerStatus() {
        print("=== DEBUG: Timer Status ===")
        print("Is Running: \(isRunning)")
        print("Is Focus Mode: \(isFocusMode)")
        print("Time Remaining: \(formattedTime)")
        print("Progress: \(String(format: "%.1f", progress * 100))%")
        print("Is Locked: \(isLocked)")
        print("App Lock Active: \(appLockManager.isAppLocked)")
        print("=========================")
    }

    func debugCompleteSession() {
        print("DEBUG: Completing full session")
        let focusMinutes = Int(focusDuration / 60)
        updateStats(focusMinutesCompleted: focusMinutes)
        Task { await firebaseManager.logFocusSession(duration: focusMinutes) }
        print("Added \(focusMinutes) minutes to stats")
    }

    func debugCompletePartialSession() {
        print("DEBUG: Completing partial session (10 minutes)")
        updateStats(focusMinutesCompleted: 10)
        Task { await firebaseManager.logFocusSession(duration: 10) }
        print("Added 10 minutes to stats")
    }

    func debugAdd5Minutes() {
        print("DEBUG: Adding 5 minutes to stats")
        updateStats(focusMinutesCompleted: 5)
        Task { await firebaseManager.logFocusSession(duration: 5) }
        print("Added 5 minutes to stats")
    }

    func debugResetStats() {
        print("DEBUG: Resetting all stats")
        todayFocusMinutes = 0
        totalFocusMinutes = 0
        currentStreak = 0
        lastCompletionDate = nil
        statsPersistence.save(statsState)
        syncWithFirebase()
        print("All stats reset to 0")
    }

    func createTestLeaderboardData() {
        print("DEBUG: Creating test leaderboard data")

        // Create some sample sessions with different durations
        let testSessions = [
            (duration: 25, daysAgo: 0),
            (duration: 25, daysAgo: 1),
            (duration: 25, daysAgo: 2),
            (duration: 25, daysAgo: 3),
            (duration: 25, daysAgo: 4)
        ]

        for session in testSessions {
            let sessionDate = Calendar.current.date(byAdding: .day, value: -session.daysAgo, to: Date()) ?? Date()
            Task { await firebaseManager.logFocusSession(duration: session.duration, completedAt: sessionDate) }
        }

        // Update stats to reflect the test data
        todayFocusMinutes += 25
        totalFocusMinutes += 125 // 5 sessions x 25 minutes
        currentStreak = 5
        lastCompletionDate = Date()

        statsPersistence.save(statsState)
        syncWithFirebase()

        print("Created 5 test sessions totaling 125 minutes")
    }

    func clearTestData() {
        print("DEBUG: Clearing test data")
        debugResetStats()
        // Note: We can't easily delete Firebase documents from the client
        // but resetting local stats will help with testing
        print("Local test data cleared")
    }
    #endif
}
