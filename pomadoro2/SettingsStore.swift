//
//  SettingsStore.swift
//  pomadoro2
//
//  Persists the user's timer preferences (focus/break durations + emojis) so
//  they survive app relaunches. Previously these lived only in memory on
//  TimerManager and reset to defaults on every launch.
//

import Foundation

/// Loads and saves the user's timer preferences.
///
/// `UserDefaults` is injected so the persistence can be unit-tested against an
/// isolated suite, and so the production accessor can later be swapped for an
/// App Group suite (shared with the widget extension) in a single place.
struct SettingsStore {

    /// The persisted preference values.
    struct Values: Equatable {
        var focusDuration: TimeInterval
        var breakDuration: TimeInterval
        var focusEmoji: String
        var breakEmoji: String

        /// First-launch defaults (25 min focus / 5 min break).
        static let defaults = Values(
            focusDuration: 25 * 60,
            breakDuration: 5 * 60,
            focusEmoji: "🍅",
            breakEmoji: "😌"
        )
    }

    private enum Key {
        static let focusDuration = "settings.focusDuration"
        static let breakDuration = "settings.breakDuration"
        static let focusEmoji = "settings.focusEmoji"
        static let breakEmoji = "settings.breakEmoji"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Returns the saved values, falling back to `Values.defaults` for any key
    /// that has never been written (so a fresh install gets the defaults).
    func load() -> Values {
        var values = Values.defaults

        // `object(forKey:)` distinguishes "never saved" from a saved 0.
        if defaults.object(forKey: Key.focusDuration) != nil {
            values.focusDuration = defaults.double(forKey: Key.focusDuration)
        }
        if defaults.object(forKey: Key.breakDuration) != nil {
            values.breakDuration = defaults.double(forKey: Key.breakDuration)
        }
        if let emoji = defaults.string(forKey: Key.focusEmoji) {
            values.focusEmoji = emoji
        }
        if let emoji = defaults.string(forKey: Key.breakEmoji) {
            values.breakEmoji = emoji
        }

        return values
    }

    /// Persists the given values.
    func save(_ values: Values) {
        defaults.set(values.focusDuration, forKey: Key.focusDuration)
        defaults.set(values.breakDuration, forKey: Key.breakDuration)
        defaults.set(values.focusEmoji, forKey: Key.focusEmoji)
        defaults.set(values.breakEmoji, forKey: Key.breakEmoji)
    }
}
