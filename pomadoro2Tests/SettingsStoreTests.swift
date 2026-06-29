//
//  SettingsStoreTests.swift
//  pomadoro2Tests
//
//  Verifies that timer preferences round-trip through persistence and that a
//  fresh store returns sensible defaults.
//

import Testing
import Foundation
@testable import pomadoro2

struct SettingsStoreTests {

    /// An isolated UserDefaults suite so tests never touch `.standard`.
    private func makeIsolatedDefaults() -> UserDefaults {
        // Vary the suite name per test by content; a fixed-but-unique name is
        // cleared at the start so each run is deterministic.
        let suite = "SettingsStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    @Test func freshStoreReturnsDefaults() {
        let store = SettingsStore(defaults: makeIsolatedDefaults())
        #expect(store.load() == SettingsStore.Values.defaults)
    }

    @Test func savedValuesRoundTrip() {
        let defaults = makeIsolatedDefaults()
        let store = SettingsStore(defaults: defaults)

        let custom = SettingsStore.Values(
            focusDuration: 50 * 60,
            breakDuration: 10 * 60,
            focusEmoji: "🔥",
            breakEmoji: "☕",
            longBreakDuration: 20 * 60
        )
        store.save(custom)

        // A fresh store over the same defaults sees the persisted values —
        // this is the relaunch scenario.
        let reloaded = SettingsStore(defaults: defaults).load()
        #expect(reloaded == custom)
    }

    @Test func partialSaveStillRoundTrips() {
        let defaults = makeIsolatedDefaults()
        let store = SettingsStore(defaults: defaults)

        var values = SettingsStore.Values.defaults
        values.focusDuration = 30 * 60
        store.save(values)

        let reloaded = store.load()
        #expect(reloaded.focusDuration == 30 * 60)
        #expect(reloaded.breakEmoji == SettingsStore.Values.defaults.breakEmoji)
    }
}
