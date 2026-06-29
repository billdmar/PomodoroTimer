//
//  StatsBackendTests.swift
//  pomadoro2Tests
//
//  Demonstrates that the StatsBackend protocol seam makes the backend mockable
//  without Firebase: a fake backend records calls and returns canned data, so
//  consumer logic can be exercised in a plain unit test.
//

import Testing
import Foundation
@testable import pomadoro2

/// An in-memory StatsBackend for tests — no network, no Firebase.
final class MockStatsBackend: StatsBackend {
    private(set) var savedStats: (focus: Int, total: Int, streak: Int)?
    private(set) var loggedSessions: [(duration: Int, at: Date)] = []
    var stubbedStats: StatsState?
    var stubbedLeaderboard: [LeaderboardEntry] = []

    func saveUserStats(focusMinutes: Int, totalMinutes: Int, streak: Int) async {
        savedStats = (focusMinutes, totalMinutes, streak)
    }

    func loadUserStats() async -> StatsState? { stubbedStats }

    func leaderboard(limit: Int) async -> [LeaderboardEntry] {
        Array(stubbedLeaderboard.prefix(limit))
    }

    func logFocusSession(duration: Int, completedAt: Date) async {
        loggedSessions.append((duration, completedAt))
    }
}

struct StatsBackendTests {

    @Test func saveAndReloadRoundTripThroughTheProtocol() async {
        let mock = MockStatsBackend()
        // Exercise via the protocol type to prove the seam works.
        let backend: StatsBackend = mock
        await backend.saveUserStats(focusMinutes: 25, totalMinutes: 100, streak: 4)
        #expect(mock.savedStats?.total == 100)

        // …and load returns whatever was stubbed.
        mock.stubbedStats = StatsState(todayFocusMinutes: 25, totalFocusMinutes: 100,
                                       currentStreak: 4, lastCompletionDate: nil)
        let loaded = await backend.loadUserStats()
        #expect(loaded?.currentStreak == 4)
    }

    @Test func leaderboardRespectsLimit() async {
        let mock = MockStatsBackend()
        mock.stubbedLeaderboard = (0..<20).map {
            LeaderboardEntry(userId: "u\($0)", totalMinutes: $0, streak: 0, lastActive: Date(timeIntervalSince1970: 0))
        }
        let top = await mock.leaderboard(limit: 5)
        #expect(top.count == 5)
    }

    @Test func logFocusSessionIsRecorded() async {
        let mock = MockStatsBackend()
        await mock.logFocusSession(duration: 25, completedAt: Date(timeIntervalSince1970: 0))
        #expect(mock.loggedSessions.count == 1)
        #expect(mock.loggedSessions.first?.duration == 25)
    }
}
