//
//  WelcomeView.swift
//  pomadoro2
//
//  First-run onboarding flow and the focus-session lock overlay. Extracted from
//  ContentView so that file stays focused on the timer layout.
//

import SwiftUI

/// A short, paged introduction to the Pomodoro technique shown on first launch.
struct WelcomeView: View {
    @Binding var showingWelcome: Bool
    @State private var currentStep = 0

    private let welcomeSteps = [
        WelcomeStep(
            emoji: "🍅",
            title: "Welcome to Pomodoro Timer",
            description: "Boost your productivity with the time-tested Pomodoro Technique!"
        ),
        WelcomeStep(
            emoji: "🕐",
            title: "The Method",
            description: "Work for 25 minutes, then take a 5-minute break. This simple rhythm helps maintain focus and prevents burnout."
        ),
        WelcomeStep(
            emoji: "🧠",
            title: "The Science",
            description: "Created by Francesco Cirillo in the 1980s, this technique leverages your brain's natural attention cycles for maximum productivity."
        ),
        WelcomeStep(
            emoji: "🚀",
            title: "Ready to Focus?",
            description: "Tap the tomato to start your first Pomodoro session. Your productive journey begins now!"
        )
    ]

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            // Progress dots
            HStack(spacing: 8) {
                ForEach(0..<welcomeSteps.count, id: \.self) { index in
                    Circle()
                        .fill(index <= currentStep ? Color.red : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .animation(.easeInOut(duration: 0.3), value: currentStep)
                }
            }
            .padding(.top, 20)

            Spacer()

            // Welcome content
            VStack(spacing: 30) {
                Text(welcomeSteps[currentStep].emoji)
                    .font(.system(size: DesignTokens.Typography.displaySize))
                    .scaleEffect(1.0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: currentStep)

                VStack(spacing: 16) {
                    Text(welcomeSteps[currentStep].title)
                        .font(DesignTokens.Typography.screenTitle)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)

                    Text(welcomeSteps[currentStep].description)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 30)
            }

            Spacer()

            // Navigation buttons
            HStack(spacing: 20) {
                if currentStep > 0 {
                    Button("Back") {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentStep -= 1
                        }
                    }
                    .foregroundColor(.secondary)
                }

                Spacer()

                Button(currentStep == welcomeSteps.count - 1 ? "Get Started!" : "Next") {
                    if currentStep == welcomeSteps.count - 1 {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            showingWelcome = false
                        }
                    } else {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentStep += 1
                        }
                    }
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 30)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(currentStep == welcomeSteps.count - 1 ? Color.green : Color.red)
                )
            }
            .padding(.horizontal, 30)

            Spacer().frame(height: 50)
        }
    }
}

struct WelcomeStep {
    let emoji: String
    let title: String
    let description: String
}

/// Shown when the user leaves mid-focus-session, nudging them back.
struct AppLockOverlay: View {
    @ObservedObject var appLockManager: AppLockManager

    var body: some View {
        ZStack {
            // Semi-transparent overlay
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: 30) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: DesignTokens.Typography.emojiSize))
                    .foregroundColor(.orange)

                VStack(spacing: 16) {
                    Text("Focus Session Active")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)

                    Text("You left during a focus session. Return to your timer to stay on track!")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }

                Button("Return to Focus") {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        appLockManager.showingUnlockAlert = false
                    }
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.card)
                        .fill(Color.orange)
                )
                .padding(.horizontal, 40)
            }
        }
    }
}

// Consistent styling for the in-app debug controls.
#if DEBUG
extension View {
    func debugButtonStyle(_ color: Color) -> some View {
        self
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color)
            .foregroundColor(.white)
            .cornerRadius(4)
    }
}
#endif
