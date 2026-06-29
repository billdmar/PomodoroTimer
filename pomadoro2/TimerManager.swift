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

    private let userDefaults = UserDefaults.standard
    private let settingsStore = SettingsStore()
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()

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
        setupFirebase()
    }

    private func loadSettings() {
        let values = settingsStore.load()
        focusDuration = values.focusDuration
        breakDuration = values.breakDuration
        focusEmoji = values.focusEmoji
        breakEmoji = values.breakEmoji
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
        timer?.invalidate()
        timer = nil

        isRunning = true
        isLocked = true
        selectRandomMessage()

        // Lock app only during focus mode
        if isFocusMode {
            appLockManager.lockApp()
        }

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if self.timeRemaining > 0 {
                    self.timeRemaining -= 1
                } else {
                    self.timerCompleted()
                }
            }
        }
    }

    func pauseTimer() {
        isRunning = false
        isLocked = false
        timer?.invalidate()
        timer = nil

        // Unlock app when pausing
        appLockManager.unlockApp()
    }

    func restartCurrentTimer() {
        pauseTimer()
        timeRemaining = isFocusMode ? focusDuration : breakDuration
        startTimer()
    }

    deinit {
        timer?.invalidate()
        timer = nil
    }

    func resetTimer() {
        pauseTimer()
        timeRemaining = isFocusMode ? focusDuration : breakDuration
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

        AudioServicesPlaySystemSound(1005)
        sendCompletionNotification(completedMode: completedMode, nextMode: nextMode)

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
    }

    private func loadLocalStats() {
        todayFocusMinutes = userDefaults.integer(forKey: "todayFocusMinutes")
        totalFocusMinutes = userDefaults.integer(forKey: "totalFocusMinutes")
        currentStreak = userDefaults.integer(forKey: "currentStreak")

        if let lastDate = userDefaults.object(forKey: "lastCompletionDate") as? Date {
            lastCompletionDate = lastDate
        }

        // Reset today's minutes if it's a new day
        if checkIfNewDay() {
            todayFocusMinutes = 0
            userDefaults.set(todayFocusMinutes, forKey: "todayFocusMinutes")
        }
    }

    private func updateStats(focusMinutesCompleted: Int) {
        let now = Date()
        let isNewDay = checkIfNewDay()

        if isNewDay {
            todayFocusMinutes = focusMinutesCompleted
        } else {
            todayFocusMinutes += focusMinutesCompleted
        }

        // Streak math lives in StreakCalculator so a multi-day gap correctly
        // resets the streak instead of simply incrementing on any new day.
        currentStreak = StreakCalculator.updatedStreak(
            previousStreak: currentStreak,
            lastCompletion: lastCompletionDate,
            now: now
        )

        totalFocusMinutes += focusMinutesCompleted
        lastCompletionDate = now

        // Save locally
        saveLocalStats()

        // Save to Firebase
        syncWithFirebase()
    }

    private func saveLocalStats() {
        userDefaults.set(todayFocusMinutes, forKey: "todayFocusMinutes")
        userDefaults.set(totalFocusMinutes, forKey: "totalFocusMinutes")
        userDefaults.set(currentStreak, forKey: "currentStreak")
        userDefaults.set(lastCompletionDate, forKey: "lastCompletionDate")
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
                // Use the maximum values to handle multi-device sync
                self?.todayFocusMinutes = max(self?.todayFocusMinutes ?? 0, todayMinutes)
                self?.totalFocusMinutes = max(self?.totalFocusMinutes ?? 0, totalMinutes)
                self?.currentStreak = max(self?.currentStreak ?? 0, streak)

                // Save the updated values locally
                self?.saveLocalStats()
            }
        }
    }

    private func checkIfNewDay() -> Bool {
        guard let lastDate = lastCompletionDate else {
            return true
        }

        let calendar = Calendar.current
        let today = Date()

        return !calendar.isDate(lastDate, inSameDayAs: today)
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, error in
            if let error = error {
                Log.debug("Notification permission error: \(error)")
            }
        }
    }

    private func sendCompletionNotification(completedMode: String, nextMode: String) {
        let content = UNMutableNotificationContent()
        content.title = "Pomodoro Timer Complete! 🍅"
        content.body = "\(completedMode) session finished! Ready for \(nextMode.lowercased()) time?"
        content.sound = UNNotificationSound.default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let request = UNNotificationRequest(identifier: "timer-complete", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                Log.debug("Notification error: \(error)")
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
        saveLocalStats()
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

        saveLocalStats()
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
