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

class TimerManager: ObservableObject {
    @Published var isRunning = false
    @Published var timeRemaining: TimeInterval = 25 * 60 // 25 minutes in seconds
    @Published var isFocusMode = true
    @Published var isLocked = false
    @Published var currentEncouragingMessage = ""
    @Published var showingCompletionAlert = false
    @Published var completionMessage = ""
    @Published var currentMotivationalQuote = ""

    // Settings
    @Published var focusDuration: TimeInterval = 25 * 60
    @Published var breakDuration: TimeInterval = 5 * 60
    @Published var focusEmoji = "🍅"
    @Published var breakEmoji = "😌"

    // Local stats tracking
    @Published var todayFocusMinutes: Int = 0
    @Published var totalFocusMinutes: Int = 0
    @Published var currentStreak: Int = 0
    @Published var lastCompletionDate: Date?

    // Firebase integration
    private let firebaseManager = FirebaseManager()

    // App lock manager - Initialize it properly
    @Published var appLockManager = AppLockManager()

    private let settingsStore = SettingsStore()
    private let sessionStore = SessionStore()
    private let statsPersistence = StatsPersistence()
    private var cancellables = Set<AnyCancellable>()

    // Deadline-based timing: while running, `endDate` is the source of truth and
    // `timeRemaining` is derived from the wall clock. This makes the countdown
    // immune to background suspension and main-thread drift — the old approach
    // decremented `timeRemaining` on a 1 Hz Timer that froze when the app was
    // backgrounded. The `tickTask` only refreshes the UI; it is not the clock.
    private var endDate: Date?
    private var tickTask: Task<Void, Never>?
    private static let completionNotificationID = "timer.completion"

    private let encouragingMessages = [
        "🔥 You're crushing it! Stay focused!",
        "🌟 Every minute counts towards your goals!",
        "💪 Your future self will thank you!",
        "🎯 Focus is your superpower!",
        "✨ Great things happen when you concentrate!",
        "🚀 You're building momentum!",
        "🧠 Your brain is getting stronger!",
        "⭐ Excellence is built one session at a time!",
        "🏆 Champions are made in moments like these!",
        "💎 Polish your skills with deep focus!",
        "🌱 You're growing with every focused minute!",
        "🔮 The magic happens in the focused zone!",
        "⚡ Channel your energy into this moment!",
        "🎨 Create something amazing right now!",
        "🌈 Your concentration is painting success!",
        "🏃‍♂️ Keep the momentum going strong!",
        "🎪 This is your time to shine!",
        "🔥 Turn up the focus and burn bright!",
        "🌟 You're exactly where you need to be!",
        "💫 Transform this time into progress!"
    ]

    private let motivationalQuotes = [
        "Success is the sum of small efforts repeated day in and day out.",
        "The expert in anything was once a beginner who refused to give up.",
        "You don't have to be great to get started, but you have to get started to be great.",
        "Every master was once a disaster who refused to quit.",
        "Progress, not perfection, is the goal.",
        "The only impossible journey is the one you never begin.",
        "Small steps daily lead to big results yearly.",
        "Your focus determines your reality.",
        "Discipline is choosing between what you want now and what you want most.",
        "The pain of discipline weighs ounces, but the pain of regret weighs tons.",
        "Success isn't just about what you accomplish, but what you inspire others to do.",
        "Don't watch the clock; do what it does. Keep going.",
        "The future depends on what you do today.",
        "You are capable of more than you know.",
        "Great things never come from comfort zones.",
        "The difference between ordinary and extraordinary is that little 'extra'.",
        "Champions train, losers complain.",
        "Your potential is endless.",
        "Excellence is not a skill, it's an attitude.",
        "The best time to plant a tree was 20 years ago. The second best time is now.",
        "Believe you can and you're halfway there.",
        "Success is not final, failure is not fatal: it is the courage to continue that counts.",
        "What lies behind us and what lies before us are tiny matters compared to what lies within us.",
        "The only way to do great work is to love what you do.",
        "Innovation distinguishes between a leader and a follower.",
        "Stay hungry, stay foolish.",
        "The journey of a thousand miles begins with one step.",
        "It always seems impossible until it's done.",
        "Strive not to be a success, but rather to be of value.",
        "The only person you are destined to become is the person you decide to be."
    ]

    init() {
        loadSettings()
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
            timeRemaining = remaining
            // Restored as paused: the user explicitly resumes.
            isRunning = false
            isLocked = false
        case let .expired(focusMode):
            isFocusMode = focusMode
            timeRemaining = focusMode ? focusDuration : breakDuration
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
        endDate = Date().addingTimeInterval(timeRemaining)

        isRunning = true
        isLocked = true
        selectRandomMessage()

        // Lock app only during focus mode
        if isFocusMode {
            appLockManager.lockApp()
        }

        scheduleCompletionNotification()
        saveSession()
        startTick()
        Haptics.medium()
    }

    func pauseTimer() {
        // Freeze the derived remaining time before discarding the deadline.
        // Computed inline (not via recompute()) so pausing never triggers
        // completion — completion flows only through the tick/recompute path,
        // which avoids a pause↔complete recursion.
        if isRunning, let endDate {
            timeRemaining = TimerMath.remaining(until: endDate, now: Date())
        }
        isRunning = false
        isLocked = false
        endDate = nil
        stopTick()
        cancelCompletionNotification()

        // Unlock app when pausing
        appLockManager.unlockApp()

        // Persist the paused state so it survives a quit.
        saveSession()
    }

    // MARK: - Tick & deadline

    /// Drives UI refresh while running. The wall clock — not this loop — is the
    /// source of truth, so a delayed or skipped tick never loses time.
    private func startTick() {
        stopTick()
        tickTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self, self.isRunning else { return }
                self.recompute()
                try? await Task.sleep(nanoseconds: 250_000_000) // 0.25s
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
        guard isRunning, let endDate else { return }
        let now = Date()
        if TimerMath.hasCompleted(endDate: endDate, now: now) {
            timeRemaining = 0
            timerCompleted()
        } else {
            timeRemaining = TimerMath.remaining(until: endDate, now: now)
        }
    }

    private func scheduleCompletionNotification() {
        guard let endDate else { return }
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
            identifier: Self.completionNotificationID,
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
            withIdentifiers: [Self.completionNotificationID]
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
        timeRemaining = isFocusMode ? focusDuration : breakDuration
        // Back to a fresh idle state — nothing to recover.
        sessionStore.clear()
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
        timeRemaining = isFocusMode ? focusDuration : breakDuration
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
        AudioServicesPlaySystemSound(1005)
        Haptics.success()

        // Unlock app when session completes
        appLockManager.unlockApp()

        // Update stats if it was a focus session
        if isFocusMode {
            let focusMinutes = Int(focusDuration / 60)
            updateStats(focusMinutesCompleted: focusMinutes)

            // Log session to Firebase
            firebaseManager.logFocusSession(duration: focusMinutes)
        }

        if isFocusMode {
            isFocusMode = false
            timeRemaining = breakDuration
        } else {
            isFocusMode = true
            timeRemaining = focusDuration
        }

        // The completed session shouldn't be recovered on next launch; the
        // pauseTimer() above persisted a snapshot, so clear it here.
        sessionStore.clear()
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
        // Save current stats to Firebase
        firebaseManager.saveUserStats(
            focusMinutes: todayFocusMinutes,
            totalMinutes: totalFocusMinutes,
            streak: currentStreak
        )

        // Load stats from Firebase (in case user has data from other devices)
        firebaseManager.loadUserStats { [weak self] todayMinutes, totalMinutes, streak in
            DispatchQueue.main.async {
                guard let self else { return }
                let remote = StatsState(
                    todayFocusMinutes: todayMinutes,
                    totalFocusMinutes: totalMinutes,
                    currentStreak: streak
                )
                // Field-wise max reconciles values from other devices.
                let merged = StatsCalculator.merging(self.statsState, remote: remote)
                self.statsState = merged
                self.statsPersistence.save(merged)
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
        currentEncouragingMessage = encouragingMessages.randomElement() ?? "🍅 Stay focused and keep going!"
    }

    func generateRandomMotivationalQuote() {
        currentMotivationalQuote = motivationalQuotes.randomElement() ?? "You've got this!"
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
            timeRemaining = isFocusMode ? focusDuration : breakDuration
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
        firebaseManager.logFocusSession(duration: focusMinutes)
        print("Added \(focusMinutes) minutes to stats")
    }

    func debugCompletePartialSession() {
        print("DEBUG: Completing partial session (10 minutes)")
        updateStats(focusMinutesCompleted: 10)
        firebaseManager.logFocusSession(duration: 10)
        print("Added 10 minutes to stats")
    }

    func debugAdd5Minutes() {
        print("DEBUG: Adding 5 minutes to stats")
        updateStats(focusMinutesCompleted: 5)
        firebaseManager.logFocusSession(duration: 5)
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
            firebaseManager.logFocusSession(duration: session.duration, completedAt: sessionDate)
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
