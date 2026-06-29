//
//  MotivationalContent.swift
//  pomadoro2
//
//  The encouraging messages and motivational quotes shown during sessions.
//  Lifted out of TimerManager (where ~55 lines of string literals bloated the
//  class) into a dedicated content provider — easier to scan, extend, and one
//  day localize.
//
//  coverage:ignore-file — this is static content plus two trivial random
//  accessors; the only uncovered lines are the `?? fallback` branches, which are
//  unreachable while the arrays are non-empty (asserted in MotivationalContentTests).
//

import Foundation

enum MotivationalContent {

    /// Short, upbeat lines shown when a session starts.
    static let encouragingMessages = [
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

    /// Longer quotes shown in the skip-confirmation prompt.
    static let motivationalQuotes = [
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

    /// A random encouraging message (with a sensible fallback).
    static func randomEncouragement() -> String {
        encouragingMessages.randomElement() ?? "🍅 Stay focused and keep going!"
    }

    /// A random motivational quote (with a sensible fallback).
    static func randomQuote() -> String {
        motivationalQuotes.randomElement() ?? "You've got this!"
    }
}
