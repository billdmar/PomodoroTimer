//
//  AppearanceSettings.swift
//  pomadoro2
//
//  User-selectable theme (accent color + light/dark/system) and completion
//  sound, with persistence. Pure value types + an injectable store so the
//  choices are unit-testable.
//

import SwiftUI

/// Accent color options offered in Settings.
enum AccentTheme: String, CaseIterable, Identifiable {
    case tomato, ocean, forest, grape, sunset
    var id: String { rawValue }

    var color: Color {
        switch self {
        case .tomato: return DesignTokens.Palette.focusStart
        case .ocean: return DesignTokens.Palette.breakEnd
        case .forest: return .green
        case .grape: return .purple
        case .sunset: return .orange
        }
    }

    var label: String { rawValue.capitalized }
}

/// Light / dark / follow-system.
enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var label: String { rawValue.capitalized }
}

/// Completion chime options.
enum CompletionSound: String, CaseIterable, Identifiable {
    case classic, chime, bell, silent
    var id: String { rawValue }

    /// `AudioServicesPlaySystemSound` id, or nil for silent.
    var systemSoundID: UInt32? {
        switch self {
        case .classic: return 1005
        case .chime: return 1013
        case .bell: return 1009
        case .silent: return nil
        }
    }

    var label: String { rawValue.capitalized }
}

/// Persists appearance + sound choices to injectable UserDefaults.
struct AppearanceSettingsStore {
    struct Values: Equatable {
        var accent: AccentTheme = .tomato
        var appearance: AppearanceMode = .system
        var completionSound: CompletionSound = .classic
    }

    private enum Key {
        static let accent = "settings.accentTheme"
        static let appearance = "settings.appearanceMode"
        static let sound = "settings.completionSound"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> Values {
        var values = Values()
        if let raw = defaults.string(forKey: Key.accent), let accent = AccentTheme(rawValue: raw) {
            values.accent = accent
        }
        if let raw = defaults.string(forKey: Key.appearance), let mode = AppearanceMode(rawValue: raw) {
            values.appearance = mode
        }
        if let raw = defaults.string(forKey: Key.sound), let sound = CompletionSound(rawValue: raw) {
            values.completionSound = sound
        }
        return values
    }

    func save(_ values: Values) {
        defaults.set(values.accent.rawValue, forKey: Key.accent)
        defaults.set(values.appearance.rawValue, forKey: Key.appearance)
        defaults.set(values.completionSound.rawValue, forKey: Key.sound)
    }
}
