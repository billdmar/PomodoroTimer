//
//  AppLockManager.swift
//  pomadoro2
//
//  Enhanced app lock with better user retention strategies
//

import SwiftUI
import UIKit
import UserNotifications

// Create a type alias to use the enhanced version
typealias AppLockManager = EnhancedAppLockManager

class EnhancedAppLockManager: ObservableObject {
    @Published var isAppLocked = false
    @Published var showingUnlockAlert = false
    @Published var unlockAttempts = 0
    @Published var showingAppSuggestions = false
    @Published var blockedApps: Set<String> = []

    // User-defined apps they want to avoid
    @Published var distractingApps: [String] = [
        "Social Media", "Instagram", "TikTok", "Twitter", "Facebook",
        "Games", "YouTube", "Netflix", "Shopping Apps"
    ]

    private var lockStartTime: Date?
    private var backgroundTime: Date?
    private var backgroundObserver: NSObjectProtocol?
    private var foregroundObserver: NSObjectProtocol?
    private let userDefaults = UserDefaults.standard

    init() {
        setupAppStateObservers()
        loadBlockedApps()
    }

    deinit {
        removeAppStateObservers()
    }

    // MARK: - App State Monitoring

    private func setupAppStateObservers() {
        backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleAppDidEnterBackground()
        }

        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleAppWillEnterForeground()
        }
    }

    private func removeAppStateObservers() {
        if let backgroundObserver = backgroundObserver {
            NotificationCenter.default.removeObserver(backgroundObserver)
        }
        if let foregroundObserver = foregroundObserver {
            NotificationCenter.default.removeObserver(foregroundObserver)
        }
    }

    private func handleAppDidEnterBackground() {
        if isAppLocked {
            backgroundTime = Date()
            // Send immediate notification when user leaves during focus
            sendImmediateReturnNotification()
            // Schedule follow-up notifications
            scheduleReturnNotifications()
        }
    }

    private func handleAppWillEnterForeground() {
        if isAppLocked {
            // Calculate time away
            let timeAway = backgroundTime?.timeIntervalSinceNow ?? 0

            // Show different alerts based on time away
            if abs(timeAway) > 30 { // More than 30 seconds away
                showingUnlockAlert = true
                unlockAttempts += 1
            }

            // Cancel pending notifications since they're back
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        }
    }

    // MARK: - Enhanced Notifications

    private func sendImmediateReturnNotification() {
        let content = UNMutableNotificationContent()
        content.title = "🎯 Focus Session Active!"
        content.body = "You left your focus session. Return to stay on track with your goals!"
        content.sound = UNNotificationSound.default
        content.categoryIdentifier = "FOCUS_REMINDER"

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "immediate-return", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request)
    }

    private func scheduleReturnNotifications() {
        let reminders = [
            (delay: 30.0, title: "🍅 Quick Reminder", body: "Your Pomodoro timer is still running! Come back to complete your session."),
            (delay: 120.0, title: "🔥 Don't Break Your Streak!", body: "You've been away for 2 minutes. Your focus session is waiting for you!"),
            (delay: 300.0, title: "💪 Stay Strong!", body: "5 minutes away - your goals are worth the focus. Return to finish strong!"),
            (delay: 600.0, title: "🎯 Final Call", body: "Your focus session is still active. Every minute of focus counts toward your success!")
        ]

        for (index, reminder) in reminders.enumerated() {
            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.body = reminder.body
            content.sound = UNNotificationSound.default
            content.categoryIdentifier = "FOCUS_REMINDER"

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: reminder.delay, repeats: false)
            let request = UNNotificationRequest(identifier: "return-reminder-\(index)", content: content, trigger: trigger)

            UNUserNotificationCenter.current().add(request)
        }
    }

    // MARK: - App Management

    func lockApp() {
        isAppLocked = true
        lockStartTime = Date()
        unlockAttempts = 0

        // Disable idle timer to prevent screen from sleeping
        UIApplication.shared.isIdleTimerDisabled = true

        // Set up notification categories for interactive notifications
        setupNotificationCategories()

        Log.debug("Enhanced app lock activated")
    }

    func unlockApp() {
        isAppLocked = false
        lockStartTime = nil
        unlockAttempts = 0
        showingUnlockAlert = false
        backgroundTime = nil

        // Re-enable normal functionality
        UIApplication.shared.isIdleTimerDisabled = false

        // Cancel all pending return notifications
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()

        Log.debug("Enhanced app lock deactivated")
    }

    private func setupNotificationCategories() {
        let returnAction = UNNotificationAction(
            identifier: "RETURN_ACTION",
            title: "Return to Focus",
            options: [.foreground]
        )

        let motivateAction = UNNotificationAction(
            identifier: "MOTIVATE_ACTION",
            title: "Send Motivation",
            options: []
        )

        let category = UNNotificationCategory(
            identifier: "FOCUS_REMINDER",
            actions: [returnAction, motivateAction],
            intentIdentifiers: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    // MARK: - Blocked Apps Management

    func addBlockedApp(_ appName: String) {
        blockedApps.insert(appName)
        saveBlockedApps()
    }

    func removeBlockedApp(_ appName: String) {
        blockedApps.remove(appName)
        saveBlockedApps()
    }

    private func saveBlockedApps() {
        userDefaults.set(Array(blockedApps), forKey: "blockedApps")
    }

    private func loadBlockedApps() {
        if let saved = userDefaults.array(forKey: "blockedApps") as? [String] {
            blockedApps = Set(saved)
        }
    }

    // MARK: - Screen Time Integration Suggestion

    func suggestScreenTimeSetup() -> String {
        return """
        💡 Pro Tip: For true app blocking, set up Screen Time:

        1. Go to Settings > Screen Time
        2. Tap "App Limits"
        3. Add limits for distracting apps
        4. Set "Downtime" during your focus sessions
        5. Enable "Block at End of Limit"

        This works system-wide and can't be easily bypassed!
        """
    }

    // MARK: - Motivational Features

    func getMotivationalMessage() -> String {
        let messages = [
            "🎯 Every moment of focus builds your future!",
            "💪 Resistance makes you stronger - stay focused!",
            "🌟 Your goals are worth more than momentary distractions!",
            "🔥 Channel that urge to check apps into laser focus!",
            "⚡ This is where champions are made - in the focused moments!",
            "🧠 Your brain is training for excellence right now!",
            "🚀 Each focused minute launches you closer to success!",
            "💎 Polish your skills with uninterrupted concentration!"
        ]
        return messages.randomElement() ?? "Stay focused! You've got this! 🍅"
    }

    func getRemainingLockTime() -> TimeInterval? {
        guard let lockStart = lockStartTime else { return nil }
        return Date().timeIntervalSince(lockStart)
    }

    func getTimeAwayFromApp() -> TimeInterval? {
        guard let backgroundStart = backgroundTime else { return nil }
        return abs(backgroundStart.timeIntervalSinceNow)
    }
}
