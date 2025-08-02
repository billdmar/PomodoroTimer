//
//  TimerManager.swift
//  pomadoro2
//
//  Created by Bill Mar on 7/30/25.
//

import Foundation
import SwiftUI
import UserNotifications
import AudioToolbox

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
    
    private var timer: Timer?
    
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
        timeRemaining = focusDuration
        selectRandomMessage()
        generateRandomMotivationalQuote()
        requestNotificationPermission()
    }
    
    var currentEmoji: String {
        return isFocusMode ? focusEmoji : breakEmoji
    }
    
    func startTimer() {
        // Invalidate any existing timer first
        timer?.invalidate()
        timer = nil
        
        isRunning = true
        isLocked = true
        selectRandomMessage() // Get a new encouraging message
        
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
    }
    
    func restartCurrentTimer() {
        // Reset the current timer to its full duration and restart
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
            // If timer is running, immediately switch to the other mode and start it
            pauseTimer()
            isFocusMode.toggle()
            timeRemaining = isFocusMode ? focusDuration : breakDuration
            startTimer()
        } else {
            // If timer is not running, just complete normally
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
        
        // Show completion notification and alert
        let completedMode = isFocusMode ? "Focus" : "Break"
        let nextMode = isFocusMode ? "Break" : "Focus"
        
        completionMessage = "\(completedMode) session complete! Time for a \(nextMode.lowercased()) 🎉"
        showingCompletionAlert = true
        
        // Play system sound (removed haptic feedback to avoid compilation issues)
        AudioServicesPlaySystemSound(1005) // System notification sound
        
        // Send local notification
        sendCompletionNotification(completedMode: completedMode, nextMode: nextMode)
        
        if isFocusMode {
            // Switch to break mode
            isFocusMode = false
            timeRemaining = breakDuration
        } else {
            // Switch to focus mode
            isFocusMode = true
            timeRemaining = focusDuration
        }
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
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
                print("Notification error: \(error)")
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
        self.focusEmoji = focusEmoji.isEmpty ? "🍅" : focusEmoji
        self.breakEmoji = breakEmoji.isEmpty ? "😌" : breakEmoji
        
        // Update current timer if not running
        if !isRunning {
            timeRemaining = isFocusMode ? focusDuration : breakDuration
        }
    }
    
    var formattedTime: String {
        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var progress: Double {
        let totalTime = isFocusMode ? focusDuration : breakDuration
        return 1 - (timeRemaining / totalTime)
    }
}
