//
//  PendingCommandStoreTests.swift
//  pomadoro2Tests
//
//  Verifies the out-of-process command mailbox used by App Intents / Siri /
//  Control Center: consume-once semantics and round-tripping.
//

import Testing
import Foundation
@testable import pomadoro2

struct PendingCommandStoreTests {

    private func defaults() -> UserDefaults {
        let suite = "PendingCommandStoreTests.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: suite)!
        d.removePersistentDomain(forName: suite)
        return d
    }

    @Test func emptyMailboxConsumesNil() {
        #expect(PendingCommandStore(defaults: defaults()).consume() == nil)
    }

    @Test func postedCommandIsConsumedExactlyOnce() {
        let d = defaults()
        let store = PendingCommandStore(defaults: d)
        store.post(.startFocus)
        #expect(store.consume() == .startFocus)
        // Consume-once: the second read is empty.
        #expect(store.consume() == nil)
    }

    @Test func latestPostWins() {
        let d = defaults()
        let store = PendingCommandStore(defaults: d)
        store.post(.startFocus)
        store.post(.togglePause)
        #expect(store.consume() == .togglePause)
    }
}
