//
//  DailyHistoryStore.swift
//  pomadoro2
//
//  A local, offline log of focus minutes per calendar day, used to draw the
//  weekly/monthly history charts. The Firestore `focusSessions` collection is
//  write-only from the client (rules deny reads), so charts read from here.
//

import Foundation

/// One day's total focus minutes.
struct DailyFocus: Identifiable, Equatable {
    var date: Date          // start of day
    var minutes: Int
    var id: Date { date }
}

/// Pure aggregation helpers over a day→minutes map.
enum HistoryAggregator {
    /// The `days`-day window ending today (inclusive), oldest first, with 0 for
    /// days that have no recorded focus. Stable output makes charts predictable.
    static func recentDays(
        _ totals: [Date: Int],
        days: Int,
        now: Date,
        calendar: Calendar = .current
    ) -> [DailyFocus] {
        let today = calendar.startOfDay(for: now)
        return (0..<max(0, days)).reversed().compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return DailyFocus(date: date, minutes: totals[date] ?? 0)
        }
    }

    /// Sum of focus minutes over the given window (ending today).
    static func total(_ totals: [Date: Int], days: Int, now: Date, calendar: Calendar = .current) -> Int {
        recentDays(totals, days: days, now: now, calendar: calendar).reduce(0) { $0 + $1.minutes }
    }
}

/// Persists the day→minutes map (JSON in UserDefaults). Keyed by start-of-day.
struct DailyHistoryStore {
    private static let key = "history.dailyFocusMinutes"
    private let defaults: UserDefaults
    private let calendar: Calendar

    init(defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.defaults = defaults
        self.calendar = calendar
    }

    /// Adds `minutes` to the total for the day containing `date`.
    func add(minutes: Int, on date: Date) {
        var totals = loadTotals()
        let day = calendar.startOfDay(for: date)
        totals[day, default: 0] += minutes
        save(totals)
    }

    /// The recorded day→minutes map.
    func loadTotals() -> [Date: Int] {
        guard let data = defaults.data(forKey: Self.key),
              let raw = try? JSONDecoder().decode([String: Int].self, from: data)
        else { return [:] }
        var result: [Date: Int] = [:]
        for (key, minutes) in raw {
            if let interval = TimeInterval(key) {
                result[Date(timeIntervalSince1970: interval)] = minutes
            }
        }
        return result
    }

    private func save(_ totals: [Date: Int]) {
        let raw = Dictionary(uniqueKeysWithValues:
            totals.map { (String($0.key.timeIntervalSince1970), $0.value) })
        if let data = try? JSONEncoder().encode(raw) {
            defaults.set(data, forKey: Self.key)
        }
    }
}
