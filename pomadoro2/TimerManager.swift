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
    @Published var todaySessions: Int = 0
    @Published var totalSessions: Int = 0

    /// True while the current/just-started break is a long break (set when a
    /// focus session that hits the long-break cadence completes).
    @Published var isLongBreak = false

    /// Long break length (used every Nth break). Persisted with the other
    /// settings.
    @Published var longBreakDuration: TimeInterval = TimerConstants.defaultLongBreakDuration

    /// Daily focus goal in minutes (drives the goal ring).
    @Published var dailyGoalMinutes: Int = GoalStore.defaultGoalMinutes

    // Appearance + sound preferences.
    @Published var accentTheme: AccentTheme = .tomato
    @Published var appearanceMode: AppearanceMode = .system
    @Published var completionSound: CompletionSound = .classic

    /// 0...1 progress toward today's goal.
    var goalProgress: Double {
        GoalMath.progress(focusMinutesToday: todayFocusMinutes, goalMinutes: dailyGoalMinutes)
    }

    /// Recent per-day focus totals (oldest first) for the history chart.
    func recentHistory(days: Int) -> [DailyFocus] {
        HistoryAggregator.recentDays(historyStore.loadTotals(), days: days, now: Date())
    }

    // Firebase integration
    private let firebaseManager: FirebaseManager

    /// Focus-mode lock + Screen Time shielding. A dependency, not observable
    /// state owned by the timer — exposed read-only for views that present its
    /// alerts.
    let appLockManager = AppLockManager()

    /// Backend used for stats sync / session logging — injectable for tests.
    /// Defaults to `firebaseManager`.
    private let backend: StatsBackend
    private let settingsStore: SettingsStore
    private let sessionStore: SessionStore
    private let statsPersistence: StatsPersistence
    private let sharedSessionStore: SharedSessionStore
    private let goalStore: GoalStore
    private let historyStore: DailyHistoryStore
    private let appearanceStore: AppearanceSettingsStore
    private let pendingCommandStore: PendingCommandStore
    // Min deployment is iOS 18.5, so the 16.1-gated controller is always usable.
    private let liveActivity = LiveActivityController()
    /// When false (tests), Firebase auth/sync, notification permission prompts,
    /// and Live Activity calls are skipped so the state machine runs in
    /// isolation.
    private let externalServicesEnabled: Bool
    private var cancellables = Set<AnyCancellable>()

    /// The countdown clock. TimerManager orchestrates around it (notifications,
    /// stats, app lock, Live Activity); the engine owns the TimerState + tick.
    private let engine: SessionEngine

    /// Designated initializer. All dependencies default to production, so
    /// `TimerManager()` works for the app; tests inject a mock backend, an
    /// isolated `UserDefaults`, and `enableExternalServices: false`.
    init(
        firebaseManager: FirebaseManager = FirebaseManager(),
        backend: StatsBackend? = nil,
        defaults: UserDefaults = .standard,
        enableExternalServices: Bool = true
    ) {
        self.firebaseManager = firebaseManager
        self.backend = backend ?? firebaseManager
        self.settingsStore = SettingsStore(defaults: defaults)
        self.sessionStore = SessionStore(defaults: defaults)
        self.statsPersistence = StatsPersistence(defaults: defaults)
        self.sharedSessionStore = SharedSessionStore(defaults: defaults)
        self.goalStore = GoalStore(defaults: defaults)
        self.historyStore = DailyHistoryStore(defaults: defaults)
        self.appearanceStore = AppearanceSettingsStore(defaults: defaults)
        self.pendingCommandStore = PendingCommandStore(defaults: defaults)
        self.externalServicesEnabled = enableExternalServices
        self.engine = SessionEngine(initialRemaining: TimerConstants.defaultFocusDuration)

        loadSettings()
        engine.reset(to: focusDuration)
        timeRemaining = focusDuration
        // Mirror the engine's clock into the @Published surface the views read.
        engine.onTick = { [weak self] remaining in
            self?.timeRemaining = remaining
        }
        engine.onFinished = { [weak self] in
            self?.timerCompleted()
        }
        selectRandomMessage()
        generateRandomMotivationalQuote()
        loadLocalStats()
        recoverSession()
        if enableExternalServices {
            requestNotificationPermission()
            setupFirebase()
            observeExtendRequests()
        }
    }

    /// Derived from the engine's state; kept as a stored @Published mirror so
    /// SwiftUI re-renders. Updated by the engine callbacks + transitions below.
    private func syncRunningFlag() {
        isRunning = engine.isRunning
    }

    private func loadSettings() {
        let values = settingsStore.load()
        focusDuration = values.focusDuration
        breakDuration = values.breakDuration
        focusEmoji = values.focusEmoji
        breakEmoji = values.breakEmoji
        longBreakDuration = values.longBreakDuration
        dailyGoalMinutes = goalStore.loadGoalMinutes()

        let appearance = appearanceStore.load()
        accentTheme = appearance.accent
        appearanceMode = appearance.appearance
        completionSound = appearance.completionSound
    }

    /// Updates and persists the daily focus goal.
    func setDailyGoal(minutes: Int) {
        dailyGoalMinutes = max(0, minutes)
        goalStore.save(goalMinutes: dailyGoalMinutes)
    }

    /// Updates and persists appearance + sound preferences.
    func updateAppearance(accent: AccentTheme, appearance: AppearanceMode, sound: CompletionSound) {
        accentTheme = accent
        appearanceMode = appearance
        completionSound = sound
        appearanceStore.save(AppearanceSettingsStore.Values(
            accent: accent, appearance: appearance, completionSound: sound
        ))
    }

    /// Adds time to a running (or paused) session — wired to the notification's
    /// "Extend +5 min" action and usable from the UI.
    func extend(byMinutes minutes: Int = 5) {
        let newEnd = engine.extend(by: TimeInterval(minutes * 60))
        timeRemaining = engine.remaining()
        if let newEnd {
            // Running: re-anchor the deadline-driven side effects.
            saveSession()
            publishSharedState()
            if externalServicesEnabled {
                cancelCompletionNotification()
                scheduleCompletionNotification(endDate: newEnd)
                liveActivity.update(endDate: newEnd, isFocusMode: isFocusMode, emoji: currentEmoji)
            }
        }
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
            engine.restorePaused(remaining: remaining)
            timeRemaining = remaining
            isLocked = false
        case let .expired(focusMode):
            isFocusMode = focusMode
            let remaining = focusMode ? focusDuration : breakDuration
            engine.reset(to: remaining)
            timeRemaining = remaining
        }
        syncRunningFlag()
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
            endDate: engine.endDate,
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

    /// Subscribes to the "Extend +5 min" notification action.
    private func observeExtendRequests() {
        NotificationCenter.default.publisher(for: NotificationActions.extendRequested)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.extend(byMinutes: 5)
            }
            .store(in: &cancellables)
    }

    func startTimer() {
        // The engine anchors the deadline to the wall clock so the countdown
        // stays correct even if the app is backgrounded or the tick is delayed.
        let endDate = engine.start(duration: timeRemaining)
        syncRunningFlag()

        isLocked = true
        selectRandomMessage()

        // Lock app only during focus mode
        if isFocusMode {
            // Request Screen Time authorization once so real shielding can take
            // effect; falls back to motivational nudges if unauthorized.
            if externalServicesEnabled, !appLockManager.screenTimeAuthorized {
                Task { await appLockManager.requestScreenTimeAuthorization() }
            }
            appLockManager.lockApp()
        }

        saveSession()
        publishSharedState()
        if externalServicesEnabled {
            scheduleCompletionNotification(endDate: endDate)
            liveActivity.start(endDate: endDate, isFocusMode: isFocusMode, emoji: currentEmoji)
        }
        Haptics.medium()
    }

    func pauseTimer() {
        engine.pause()
        timeRemaining = engine.remaining()
        syncRunningFlag()
        isLocked = false

        // Unlock app when pausing
        appLockManager.unlockApp()

        // Persist the paused state so it survives a quit.
        saveSession()
        publishSharedState()
        if externalServicesEnabled {
            cancelCompletionNotification()
            liveActivity.end()
        }
    }

    /// Recomputes remaining from the wall clock and completes if the deadline
    /// passed. Delegates to the engine; used by the scene-phase recovery path.
    func recompute() {
        engine.recompute()
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
        // Enables the "Extend +5 min" action (handled by NotificationActionHandler).
        content.categoryIdentifier = NotificationActions.completionCategoryID

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
            consumePendingCommand()
        case .background:
            if isRunning { saveSession() }
        default:
            break
        }
    }

    /// Applies a command queued by an App Intent / Siri / Control Center while
    /// the app was backgrounded.
    private func consumePendingCommand() {
        switch pendingCommandStore.consume() {
        case .startFocus:
            // Start a fresh focus session if one isn't already running.
            if !isRunning {
                if !isFocusMode { switchMode() }
                startTimer()
            }
        case .togglePause:
            isRunning ? pauseTimer() : startTimer()
        case .none:
            break
        }
    }

    func restartCurrentTimer() {
        pauseTimer()
        timeRemaining = isFocusMode ? focusDuration : breakDuration
        startTimer()
    }

    func resetTimer() {
        pauseTimer()
        let remaining = isFocusMode ? focusDuration : breakDuration
        engine.reset(to: remaining)
        syncRunningFlag()
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
        engine.reset(to: remaining)
        syncRunningFlag()
        timeRemaining = remaining
    }

    private func timerCompleted() {
        pauseTimer()

        let completedMode = isFocusMode ? "Focus" : "Break"

        // In-app feedback. The scheduled completion notification (set at start)
        // covers the case where the app is backgrounded/suspended at the
        // deadline; pauseTimer() above cancels it so we never double-notify.
        if let soundID = completionSound.systemSoundID {
            AudioServicesPlaySystemSound(soundID)
        }
        Haptics.success()

        // Unlock app when session completes
        appLockManager.unlockApp()

        // Update stats if it was a focus session. Decide the upcoming break
        // kind from how many focus sessions have been completed today (long
        // break every Nth — the classic Pomodoro cadence).
        var nextBreakIsLong = false
        if isFocusMode {
            let focusMinutes = Int(focusDuration / 60)
            updateStats(focusMinutesCompleted: focusMinutes)
            historyStore.add(minutes: focusMinutes, on: Date())
            nextBreakIsLong = BreakPolicy.breakKind(completedTodaySessions: todaySessions) == .long
            isLongBreak = nextBreakIsLong

            // Log session to the backend
            let minutes = focusMinutes
            Task { await backend.logFocusSession(duration: minutes, completedAt: Date()) }
        }

        // Announce what's next (a long break is the reward for completing the
        // Nth focus session).
        let nextLabel = isFocusMode ? (nextBreakIsLong ? "long break" : "break") : "focus session"
        completionMessage = "\(completedMode) session complete! Time for a \(nextLabel) 🎉"
        showingCompletionAlert = true

        isFocusMode.toggle()
        let remaining: TimeInterval
        if isFocusMode {
            remaining = focusDuration
        } else {
            remaining = nextBreakIsLong ? longBreakDuration : breakDuration
        }
        engine.reset(to: remaining)
        syncRunningFlag()
        timeRemaining = remaining

        // The completed session shouldn't be recovered on next launch; the
        // pauseTimer() above persisted a snapshot, so clear it here.
        sessionStore.clear()
        publishSharedState()
    }

    // MARK: - Stats

    /// Read-only snapshot of the current stats for views (e.g. achievement
    /// evaluation) that want the value model rather than the individual
    /// @Published fields.
    var statsSnapshot: StatsState { statsState }

    /// Bridges the view-facing @Published stats to the value model that the
    /// pure StatsCalculator / StatsPersistence operate on.
    private var statsState: StatsState {
        get {
            StatsState(
                todayFocusMinutes: todayFocusMinutes,
                totalFocusMinutes: totalFocusMinutes,
                currentStreak: currentStreak,
                lastCompletionDate: lastCompletionDate,
                todaySessions: todaySessions,
                totalSessions: totalSessions
            )
        }
        set {
            todayFocusMinutes = newValue.todayFocusMinutes
            totalFocusMinutes = newValue.totalFocusMinutes
            currentStreak = newValue.currentStreak
            lastCompletionDate = newValue.lastCompletionDate
            todaySessions = newValue.todaySessions
            totalSessions = newValue.totalSessions
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
        guard externalServicesEnabled else { return }
        Task { [weak self] in
            guard let self else { return }
            // Save current stats to the backend.
            await backend.saveUserStats(
                focusMinutes: todayFocusMinutes,
                totalMinutes: totalFocusMinutes,
                streak: currentStreak
            )

            // Load stats from the backend (in case the user has data from other
            // devices) and reconcile. Field-wise max + latest completion date.
            if let remote = await backend.loadUserStats() {
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

    func updateSettings(
        focusMinutes: Double,
        breakMinutes: Double,
        focusEmoji: String,
        breakEmoji: String,
        longBreakMinutes: Double? = nil
    ) {
        focusDuration = focusMinutes * 60
        breakDuration = breakMinutes * 60
        if let longBreakMinutes { longBreakDuration = longBreakMinutes * 60 }
        self.focusEmoji = TimerMath.normalizedEmoji(focusEmoji, default: "🍅")
        self.breakEmoji = TimerMath.normalizedEmoji(breakEmoji, default: "😌")

        // Persist so the preferences survive relaunch.
        settingsStore.save(SettingsStore.Values(
            focusDuration: focusDuration,
            breakDuration: breakDuration,
            focusEmoji: self.focusEmoji,
            breakEmoji: self.breakEmoji,
            longBreakDuration: longBreakDuration
        ))

        if !isRunning {
            let remaining = isFocusMode ? focusDuration : breakDuration
            engine.reset(to: remaining)
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
