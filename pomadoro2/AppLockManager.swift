//
//  AppLockManager.swift
//  pomadoro2
//
//  App lock functionality for focus mode
//

import SwiftUI
import UIKit
import UserNotifications

class AppLockManager: ObservableObject {
    @Published var isAppLocked = false
    @Published var showingUnlockAlert = false
    @Published var unlockAttempts = 0
    
    private var lockStartTime: Date?
    let maxUnlockAttempts = 3
    private var backgroundObserver: NSObjectProtocol?
    private var foregroundObserver: NSObjectProtocol?
    
    init() {
        setupAppStateObservers()
    }
    
    deinit {
        removeAppStateObservers()
    }
    
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
            // Show motivational notification when user tries to leave during focus
            sendMotivationalNotification()
        }
    }
    
    private func handleAppWillEnterForeground() {
        if isAppLocked {
            // Show unlock alert when returning to app during locked session
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.showingUnlockAlert = true
            }
        }
    }
    
    private func sendMotivationalNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Stay Focused! 🎯"
        content.body = getMotivationalMessage()
        content.sound = UNNotificationSound.default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let request = UNNotificationRequest(identifier: "focus-motivation", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Notification error: \(error)")
            }
        }
    }
    
    func lockApp() {
        isAppLocked = true
        lockStartTime = Date()
        unlockAttempts = 0
        
        // Disable idle timer to prevent screen from sleeping
        UIApplication.shared.isIdleTimerDisabled = true
        
        print("App locked for focus mode")
    }
    
    func unlockApp() {
        isAppLocked = false
        lockStartTime = nil
        unlockAttempts = 0
        showingUnlockAlert = false
        
        // Re-enable normal functionality
        UIApplication.shared.isIdleTimerDisabled = false
        
        print("App unlocked")
    }
    
    func attemptUnlock(completion: @escaping (Bool) -> Void) {
        unlockAttempts += 1
        
        if unlockAttempts >= maxUnlockAttempts {
            // Force unlock after max attempts (safety measure)
            unlockApp()
            completion(true)
        } else {
            // Show motivational message instead of unlocking
            showingUnlockAlert = true
            completion(false)
        }
    }
    
    func getRemainingLockTime() -> TimeInterval? {
        guard let lockStart = lockStartTime else { return nil }
        return Date().timeIntervalSince(lockStart)
    }
    
    func getMotivationalMessage() -> String {
        let messages = [
            "🎯 Stay focused! You're building great habits!",
            "💪 Every minute of focus makes you stronger!",
            "🌟 Your future self will thank you for staying!",
            "🔥 The magic happens when you resist distractions!",
            "⚡ Champions are made in moments like these!",
            "🧠 Your brain is getting stronger with each second!",
            "🚀 You're closer to your goals than you think!",
            "💎 Diamonds are formed under pressure - keep going!"
        ]
        return messages.randomElement() ?? "Stay focused! You've got this! 🍅"
    }
}
