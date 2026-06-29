//
//  TomatoButton.swift
//  pomadoro2
//
//  Created by Bill Mar on 7/30/25.
//

import SwiftUI

struct TomatoButton: View {
    @ObservedObject var timerManager: TimerManager
    @State private var isPressed = false
    @State private var showStars = false

    var body: some View {
        ZStack {
            // Star particles
            if showStars {
                StarParticlesView()
                    .allowsHitTesting(false)
            }

            // Only show button when timer is NOT running and emoji is at bottom (scale = 1.0)
            if !timerManager.isRunning {
                Button(action: {
                    startPomodoro()
                }) {
                    ZStack {
                        // Shadow/background circle
                        Circle()
                            .fill(Color.black.opacity(0.1))
                            .frame(width: 160, height: 160)
                            .offset(y: 4)

                        // Main button background
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [Color.red.opacity(0.1), Color.red.opacity(0.05)],
                                    center: .center,
                                    startRadius: 10,
                                    endRadius: 80
                                )
                            )
                            .frame(width: 160, height: 160)

                        // Emoji - only show when not transitioning
                        Text(timerManager.currentEmoji)
                            .font(.system(size: 80))
                    }
                }
                .onTapGesture {
                    startPomodoro()
                }
                .scaleEffect(isPressed ? 0.95 : 1.0)
                .animation(.easeInOut(duration: 0.1), value: isPressed)
                .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = pressing
                    }
                }, perform: {
                    // This won't be called since minimumDuration is 0
                })
                .accessibilityLabel(timerManager.isFocusMode ? "Start focus session" : "Start break")
                .accessibilityHint("Double tap to begin the timer")
            }
        }
    }

    private func startPomodoro() {
        // Show stars
        withAnimation {
            showStars = true
        }

        // Start timer immediately to trigger the moving animation
        timerManager.startTimer()

        // Hide stars after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation {
                showStars = false
            }
        }
    }
}
