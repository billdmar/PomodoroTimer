//
//  SettingsView.swift
//  pomadoro2
//
//  Enhanced with live timer updates and cleaned up status section
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var timerManager: TimerManager
    @Environment(\.dismiss) private var dismiss
    @State private var focusMinutes: Double = 25
    @State private var breakMinutes: Double = 5
    @State private var focusEmojiText: String = "🍅"
    @State private var breakEmojiText: String = "😌"
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 16) {
                        Text(timerManager.currentEmoji)
                            .font(.system(size: 50))
                        
                        Text("Timer Settings")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                    }
                    .padding(.top, 30)
                    .padding(.bottom, 40)
                    
                    // Settings content
                    VStack(spacing: 30) {
                        // Focus duration setting
                        VStack(alignment: .leading, spacing: 16) {
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
                                    .onChange(of: focusEmojiText) { oldValue, newValue in
                                        if newValue.count > 2 {
                                            focusEmojiText = String(newValue.prefix(2))
                                        }
                                        // Update timer manager immediately
                                        updateTimerSettings()
                                    }
                                
                                Text("\(Int(focusMinutes)) min")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.red)
                            }
                            
                            Slider(value: $focusMinutes, in: 1...60, step: 1)
                                .accentColor(.red)
                                .onChange(of: focusMinutes) { oldValue, newValue in
                                    // Update timer manager immediately when slider changes
                                    updateTimerSettings()
                                }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 20)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.gray.opacity(0.1))
                        )
                        
                        // Break duration setting
                        VStack(alignment: .leading, spacing: 16) {
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
                                    .onChange(of: breakEmojiText) { oldValue, newValue in
                                        if newValue.count > 2 {
                                            breakEmojiText = String(newValue.prefix(2))
                                        }
                                        // Update timer manager immediately
                                        updateTimerSettings()
                                    }
                                
                                Text("\(Int(breakMinutes)) min")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.green)
                            }
                            
                            Slider(value: $breakMinutes, in: 1...30, step: 1)
                                .accentColor(.green)
                                .onChange(of: breakMinutes) { oldValue, newValue in
                                    // Update timer manager immediately when slider changes
                                    updateTimerSettings()
                                }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 20)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.gray.opacity(0.1))
                        )
                        
                        // Quick emoji suggestions
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Quick Emojis")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            HStack(spacing: 12) {
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
                                    }
                                }
                                
                                Spacer()
                            }
                            
                            HStack(spacing: 12) {
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
                                    }
                                }
                                
                                Spacer()
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.gray.opacity(0.05))
                        )
                        
                        // Current mode (simplified from previous status section)
                        VStack(spacing: 16) {
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
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 20)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.gray.opacity(0.1))
                        )
                    }
                    .padding(.horizontal, 20)
                    
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
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.blue)
                            )
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
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
        focusEmojiText = timerManager.focusEmoji
        breakEmojiText = timerManager.breakEmoji
    }
    
    private func updateTimerSettings() {
        // Update timer manager immediately with current slider values
        timerManager.updateSettings(
            focusMinutes: focusMinutes,
            breakMinutes: breakMinutes,
            focusEmoji: focusEmojiText,
            breakEmoji: breakEmojiText
        )
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
