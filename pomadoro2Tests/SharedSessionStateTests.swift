//
//  SharedSessionStateTests.swift
//  pomadoro2Tests
//
//  Covers the App-Group-backed shared session snapshot the widget reads, and
//  the motivational content provider.
//

import Testing
import Foundation
@testable import pomadoro2

struct SharedSessionStoreTests {

    private func makeIsolatedDefaults() -> UserDefaults {
        let suite = "SharedSessionStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    @Test func loadsIdleWhenEmpty() {
        let store = SharedSessionStore(defaults: makeIsolatedDefaults())
        #expect(store.load() == .idle)
    }

    @Test func roundTripsARunningSession() {
        let defaults = makeIsolatedDefaults()
        let store = SharedSessionStore(defaults: defaults)
        let state = SharedSessionState(
            isRunning: true,
            isFocusMode: true,
            emoji: "🍅",
            endDate: Date(timeIntervalSince1970: 5_000),
            timeRemaining: 1500
        )
        store.save(state)
        #expect(SharedSessionStore(defaults: defaults).load() == state)
    }

    @Test func idleConstantIsStopped() {
        #expect(!SharedSessionState.idle.isRunning)
        #expect(SharedSessionState.idle.endDate == nil)
        #expect(SharedSessionState.idle.timeRemaining == 25 * 60)
        #expect(SharedSessionState.idle.emoji == "🍅")
    }

    @Test func sharedConfigExposesTheAppGroupAndAUsableStore() {
        // Exercises SharedConfig (App Group id + the defaults accessor), which
        // backs the widget's reads in production.
        #expect(SharedConfig.appGroupID == "group.com.billdmar.pomadoro2")
        // The accessor returns a usable UserDefaults (App Group or .standard
        // fallback) — round-trip a throwaway key to prove it works.
        let defaults = SharedConfig.defaults
        let probeKey = "sharedConfig.probe.\(UUID().uuidString)"
        defaults.set(7, forKey: probeKey)
        #expect(defaults.integer(forKey: probeKey) == 7)
        defaults.removeObject(forKey: probeKey)
    }
}

struct MotivationalContentTests {

    @Test func encouragementsAndQuotesAreNonEmpty() {
        #expect(!MotivationalContent.encouragingMessages.isEmpty)
        #expect(!MotivationalContent.motivationalQuotes.isEmpty)
    }

    @Test func randomHelpersReturnAMemberOfTheList() {
        let message = MotivationalContent.randomEncouragement()
        #expect(MotivationalContent.encouragingMessages.contains(message))

        let quote = MotivationalContent.randomQuote()
        #expect(MotivationalContent.motivationalQuotes.contains(quote))
    }
}
