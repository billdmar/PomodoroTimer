//
//  AppearanceSettingsTests.swift
//  pomadoro2Tests
//
//  Covers persistence + mapping of the theme / appearance / completion-sound
//  preferences.
//

import Testing
import Foundation
@testable import pomadoro2

struct AppearanceSettingsTests {

    private func defaults() -> UserDefaults {
        let suite = "AppearanceSettingsTests.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: suite)!
        d.removePersistentDomain(forName: suite)
        return d
    }

    @Test func freshStoreReturnsDefaults() {
        let values = AppearanceSettingsStore(defaults: defaults()).load()
        #expect(values == AppearanceSettingsStore.Values())
        #expect(values.accent == .tomato)
        #expect(values.appearance == .system)
        #expect(values.completionSound == .classic)
    }

    @Test func choicesRoundTrip() {
        let d = defaults()
        let custom = AppearanceSettingsStore.Values(
            accent: .grape, appearance: .dark, completionSound: .bell
        )
        AppearanceSettingsStore(defaults: d).save(custom)
        #expect(AppearanceSettingsStore(defaults: d).load() == custom)
    }

    @Test func appearanceModeMapsToColorScheme() {
        #expect(AppearanceMode.system.colorScheme == nil)
        #expect(AppearanceMode.light.colorScheme == .light)
        #expect(AppearanceMode.dark.colorScheme == .dark)
    }

    @Test func silentSoundHasNoSystemID() {
        #expect(CompletionSound.silent.systemSoundID == nil)
        #expect(CompletionSound.classic.systemSoundID != nil)
    }
}
