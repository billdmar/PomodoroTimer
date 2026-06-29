//
//  SettingsView.swift
//  pomadoro2
//
//  Enhanced with live timer updates and cleaned up status section
//

import SwiftUI
import AudioToolbox

struct SettingsView: View {
    @ObservedObject var timerManager: TimerManager
    @Environment(\.dismiss) private var dismiss
    @State private var focusMinutes: Double = 25
    @State private var breakMinutes: Double = 5
    @State private var longBreakMinutes: Double = 15
    @State private var focusEmojiText: String = "🍅"
    @State private var breakEmojiText: String = "😌"
    @State private var accent: AccentTheme = .tomato
    @State private var appearance: AppearanceMode = .system
    @State private var sound: CompletionSound = .classic

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: DesignTokens.Spacing.md) {
                        Text(timerManager.currentEmoji)
                            .font(.system(size: DesignTokens.Typography.emojiSize))
                            .accessibilityHidden(true)

                        Text("Timer Settings")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                    }
                    .padding(.top, DesignTokens.Spacing.xxl)
                    .padding(.bottom, 40)

                    // Settings content
                    VStack(spacing: DesignTokens.Spacing.xxl) {
                        // Focus duration setting
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                            HStack {
                                Image(systemName: "brain.head.profile")
                                    .foregroundColor(.red)
                                    .font(.title3)

                                Text("Focus Duration")
                                    .font(.headline)
                                    .foregroundColor(.primary)

                                Spacer()

                                // Small emoji editor inline
                                TextField("", text: $focusEmojiText)
                                    .font(.title3)
                                    .multilineTextAlignment(.center)
                                    .frame(width: 35)
                                    .onChange(of: focusEmojiText) { _, newValue in
                                        if newValue.count > 2 {
                                            focusEmojiText = String(newValue.prefix(2))
                                        }
                                        // Update timer manager immediately
                                        updateTimerSettings()
                                    }
                                    .accessibilityLabel("Focus session emoji")

                                Text("\(Int(focusMinutes)) min")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.red)
                            }

                            Slider(value: $focusMinutes, in: 1...60, step: 1)
                                .accentColor(.red)
                                .onChange(of: focusMinutes) { _, _ in
                                    // Update timer manager immediately when slider changes
                                    updateTimerSettings()
                                }
                                .accessibilityLabel("Focus duration")
                                .accessibilityValue("\(Int(focusMinutes)) minutes")
                        }
                        .padding(.horizontal, DesignTokens.Spacing.xl)
                        .padding(.vertical, DesignTokens.Spacing.lg)
                        .background(
                            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.section)
                                .fill(Color.gray.opacity(0.1))
                        )

                        // Break duration setting
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                            HStack {
                                Image(systemName: "cup.and.saucer")
                                    .foregroundColor(.green)
                                    .font(.title3)

                                Text("Break Duration")
                                    .font(.headline)
                                    .foregroundColor(.primary)

                                Spacer()

                                // Small emoji editor inline
                                TextField("", text: $breakEmojiText)
                                    .font(.title3)
                                    .multilineTextAlignment(.center)
                                    .frame(width: 35)
                                    .onChange(of: breakEmojiText) { _, newValue in
                                        if newValue.count > 2 {
                                            breakEmojiText = String(newValue.prefix(2))
                                        }
                                        // Update timer manager immediately
                                        updateTimerSettings()
                                    }
                                    .accessibilityLabel("Break session emoji")

                                Text("\(Int(breakMinutes)) min")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.green)
                            }

                            Slider(value: $breakMinutes, in: 1...30, step: 1)
                                .accentColor(.green)
                                .onChange(of: breakMinutes) { _, _ in
                                    // Update timer manager immediately when slider changes
                                    updateTimerSettings()
                                }
                                .accessibilityLabel("Break duration")
                                .accessibilityValue("\(Int(breakMinutes)) minutes")
                        }
                        .padding(.horizontal, DesignTokens.Spacing.xl)
                        .padding(.vertical, DesignTokens.Spacing.lg)
                        .background(
                            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.section)
                                .fill(Color.gray.opacity(0.1))
                        )

                        // Quick emoji suggestions
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                            Text("Quick Emojis")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            HStack(spacing: DesignTokens.Spacing.sm) {
                                Text("Focus:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                HStack(spacing: 6) {
                                    ForEach(["🍅", "🔥", "🎯", "💪", "🧠", "🚀"], id: \.self) { emoji in
                                        Button(action: {
                                            focusEmojiText = emoji
                                            updateTimerSettings()
                                        }) {
                                            Text(emoji)
                                                .font(.body)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        .accessibilityLabel("Use \(emoji)")
                                    }
                                }

                                Spacer()
                            }

                            HStack(spacing: DesignTokens.Spacing.sm) {
                                Text("Break:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                HStack(spacing: 6) {
                                    ForEach(["😌", "☕", "🌱", "🎵", "🍃", "🌟"], id: \.self) { emoji in
                                        Button(action: {
                                            breakEmojiText = emoji
                                            updateTimerSettings()
                                        }) {
                                            Text(emoji)
                                                .font(.body)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        .accessibilityLabel("Use \(emoji)")
                                    }
                                }

                                Spacer()
                            }
                        }
                        .padding(.horizontal, DesignTokens.Spacing.xl)
                        .padding(.vertical, DesignTokens.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.section)
                                .fill(Color.gray.opacity(0.05))
                        )

                        // Long break duration
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                            HStack {
                                Image(systemName: "moon.zzz.fill")
                                    .foregroundColor(.indigo)
                                    .font(.title3)
                                Text("Long Break")
                                    .font(.headline)
                                Spacer()
                                Text("\(Int(longBreakMinutes)) min")
                                    .font(.title3).fontWeight(.bold).foregroundColor(.indigo)
                            }
                            Text("Used after every \(BreakPolicy.defaultSessionsBeforeLongBreak) focus sessions.")
                                .font(.caption).foregroundColor(.secondary)
                            Slider(value: $longBreakMinutes, in: 10...45, step: 5)
                                .tint(.indigo)
                                .onChange(of: longBreakMinutes) { _, _ in updateTimerSettings() }
                                .accessibilityLabel("Long break duration")
                                .accessibilityValue("\(Int(longBreakMinutes)) minutes")
                        }
                        .padding(.horizontal, DesignTokens.Spacing.xl)
                        .padding(.vertical, DesignTokens.Spacing.lg)
                        .background(
                            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.section)
                                .fill(Color.gray.opacity(0.1))
                        )

                        // Appearance & sound
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                            Text("Appearance & Sound")
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Picker("Theme", selection: $accent) {
                                ForEach(AccentTheme.allCases) { theme in
                                    Text(theme.label).tag(theme)
                                }
                            }
                            .pickerStyle(.menu)
                            .onChange(of: accent) { _, _ in updateAppearance() }
                            .accessibilityLabel("Accent theme")

                            Picker("Appearance", selection: $appearance) {
                                ForEach(AppearanceMode.allCases) { mode in
                                    Text(mode.label).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                            .onChange(of: appearance) { _, _ in updateAppearance() }
                            .accessibilityLabel("Appearance mode")

                            Picker("Completion Sound", selection: $sound) {
                                ForEach(CompletionSound.allCases) { option in
                                    Text(option.label).tag(option)
                                }
                            }
                            .pickerStyle(.menu)
                            .onChange(of: sound) { _, newValue in
                                if let id = newValue.systemSoundID { AudioServicesPlaySystemSound(id) }
                                updateAppearance()
                            }
                            .accessibilityLabel("Completion sound")
                        }
                        .padding(.horizontal, DesignTokens.Spacing.xl)
                        .padding(.vertical, DesignTokens.Spacing.lg)
                        .background(
                            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.section)
                                .fill(Color.gray.opacity(0.1))
                        )

                        // Current mode (simplified from previous status section)
                        VStack(spacing: DesignTokens.Spacing.md) {
                            Text("Current Mode")
                                .font(.headline)
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Mode")
                                        .font(.caption)
                                        .foregroundColor(.secondary)

                                    Text(timerManager.isFocusMode ? "Focus" : "Break")
                                        .font(.headline)
                                        .foregroundColor(timerManager.isFocusMode ? .red : .green)
                                        .fontWeight(.bold)
                                }
                                .accessibilityElement(children: .combine)

                                Spacer()

                                // Show current timer value based on mode
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("Timer Set To")
                                        .font(.caption)
                                        .foregroundColor(.secondary)

                                    Text(timerManager.formattedTime)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                        .fontWeight(.bold)
                                        .font(.system(.headline, design: .monospaced))
                                }
                                .accessibilityElement(children: .combine)
                            }
                        }
                        .padding(.horizontal, DesignTokens.Spacing.xl)
                        .padding(.vertical, DesignTokens.Spacing.lg)
                        .background(
                            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.section)
                                .fill(Color.gray.opacity(0.1))
                        )
                    }
                    .padding(.horizontal, DesignTokens.Spacing.lg)

                    Spacer()

                    Button(action: {
                        // Final update to ensure everything is saved
                        updateTimerSettings()
                        dismiss()
                    }) {
                        Text("Done")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DesignTokens.Spacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.card)
                                    .fill(Color.blue)
                            )
                    }
                    .padding(.horizontal, DesignTokens.Spacing.lg)
                    .padding(.bottom, DesignTokens.Spacing.xxl)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        // Reset to original values when canceling
                        resetToOriginalValues()
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }
            }
        }
        .onAppear {
            loadCurrentValues()
        }
    }

    // MARK: - Helper Methods

    private func loadCurrentValues() {
        focusMinutes = timerManager.focusDuration / 60
        breakMinutes = timerManager.breakDuration / 60
        longBreakMinutes = timerManager.longBreakDuration / 60
        focusEmojiText = timerManager.focusEmoji
        breakEmojiText = timerManager.breakEmoji
        accent = timerManager.accentTheme
        appearance = timerManager.appearanceMode
        sound = timerManager.completionSound
    }

    private func updateTimerSettings() {
        // Update timer manager immediately with current slider values
        timerManager.updateSettings(
            focusMinutes: focusMinutes,
            breakMinutes: breakMinutes,
            focusEmoji: focusEmojiText,
            breakEmoji: breakEmojiText,
            longBreakMinutes: longBreakMinutes
        )
    }

    private func updateAppearance() {
        timerManager.updateAppearance(accent: accent, appearance: appearance, sound: sound)
    }

    private func resetToOriginalValues() {
        // Reset timer to original values if user cancels
        timerManager.updateSettings(
            focusMinutes: timerManager.focusDuration / 60,
            breakMinutes: timerManager.breakDuration / 60,
            focusEmoji: timerManager.focusEmoji,
            breakEmoji: timerManager.breakEmoji
        )
    }
}

#Preview {
    SettingsView(timerManager: TimerManager())
}
