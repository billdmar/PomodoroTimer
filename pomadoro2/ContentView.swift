//
//  ContentView.swift
//  pomadoro2
//
//  Enhanced with smooth transitions between timer states
//

import SwiftUI
import Foundation

struct ContentView: View {
    @StateObject private var timerManager = TimerManager()
    @State private var showingSettings = false
    @State private var showDebugPanel = false
    // Skipped during UI tests so they can start on the main screen deterministically.
    @State private var showingWelcome = !ProcessInfo.processInfo.arguments.contains("-skipWelcome")
    @State private var showingStats = false
    @State private var showingLeaderboard = false
    @State private var colorShift: CGFloat = 0
    @State private var emojiHovered = false
    @State private var showingSkipConfirmation = false

    // Animation state for smooth transitions
    @State private var isTransitioning = false
    @State private var scaleEffect: CGFloat = 1.0
    @State private var backgroundOpacity: Double = 1.0

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background layers with smooth transitions
                backgroundView

                // Main content with transition animations
                if showingWelcome {
                    WelcomeView(showingWelcome: $showingWelcome)
                        .transition(.opacity.combined(with: .scale))
                } else {
                    ZStack {
                        // Main timer view (always present but can be hidden)
                        mainTimerView
                            .opacity(timerManager.isRunning ? 0 : 1)
                            .scaleEffect(timerManager.isRunning ? 0.95 : 1)
                            .animation(.easeInOut(duration: 0.6), value: timerManager.isRunning)

                        // Full screen timer view (overlays when running)
                        if timerManager.isRunning {
                            fullScreenTimerView(geometry: geometry)
                                .transition(.opacity.combined(with: .scale(scale: 0.9)))
                                .animation(.easeInOut(duration: 0.6), value: timerManager.isRunning)
                        }
                    }
                }

                // App lock overlay - only show when trying to leave app, not during normal use
                if timerManager.appLockManager.isAppLocked && timerManager.appLockManager.showingUnlockAlert {
                    AppLockOverlay(appLockManager: timerManager.appLockManager)
                        .transition(.opacity.combined(with: .scale))
                }
            }
        }
        .onAppear {
            // Deep-link launch arguments used for deterministic screenshots/tests.
            let args = ProcessInfo.processInfo.arguments
            if let i = args.firstIndex(of: "-screen"), i + 1 < args.count {
                switch args[i + 1] {
                case "settings": showingSettings = true
                case "leaderboard": showingLeaderboard = true
                case "stats": showingStats = true
                default: break
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(timerManager: timerManager)
        }
        .sheet(isPresented: $showingStats) {
            StatsView(timerManager: timerManager)
        }
        .sheet(isPresented: $showingLeaderboard) {
            LeaderboardView(firebaseManager: timerManager.firebaseManagerPublished)
        }
        .alert("Timer Complete! 🎉", isPresented: $timerManager.showingCompletionAlert) {
            Button("Start \(timerManager.isFocusMode ? "Focus" : "Break")") {
                withAnimation(.easeInOut(duration: 0.5)) {
                    timerManager.startTimer()
                }
            }
            Button("Not Now", role: .cancel) { }
        } message: {
            Text(timerManager.completionMessage)
        }
        .alert("Skip Focus Session? 🤔", isPresented: $showingSkipConfirmation) {
            Button("Keep Going!", role: .cancel) { }
            Button("Skip", role: .destructive) {
                withAnimation(.easeInOut(duration: 0.5)) {
                    timerManager.skipTimer()
                }
            }
        } message: {
            VStack {
                Text("Are you sure you want to skip this focus session?")
                Text(timerManager.currentMotivationalQuote)
                    .font(.caption)
                    .italic()
            }
        }
        .onDisappear {
            timerManager.pauseTimer()
        }
        .onReceive(Timer.publish(every: 3.0, on: .main, in: .common).autoconnect()) { _ in
            if timerManager.isRunning {
                withAnimation(.easeInOut(duration: 3.0)) {
                    colorShift += 50
                }
            }
        }
        // Animation when timer state changes
        .onChange(of: timerManager.isRunning) { _, newValue in
            withAnimation(.easeInOut(duration: 0.6)) {
                isTransitioning = true
                scaleEffect = newValue ? 1.1 : 1.0
                backgroundOpacity = newValue ? 0.8 : 1.0
            }

            // Reset transition state
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isTransitioning = false
                }
            }
        }
#if DEBUG
.overlay(
    // Debug panel - only shows in debug builds
    VStack {
        if showDebugPanel {
            ScrollView {
                VStack(spacing: 8) {
                    Text("🐛 DEBUG PANEL")
                        .font(.caption)
                        .fontWeight(.bold)

                    // Auth & User Info
                    VStack(spacing: 4) {
                        Text("AUTH STATUS")
                            .font(.caption2)
                            .fontWeight(.semibold)

                        HStack(spacing: 8) {
                            Button("Check User") {
                                timerManager.debugPrintCurrentUser()
                            }
                            .debugButtonStyle(.blue)

                            Button("Timer Status") {
                                timerManager.debugPrintTimerStatus()
                            }
                            .debugButtonStyle(.cyan)

                            Button("Sign Out") {
                                timerManager.firebaseManagerPublished.signOut()
                            }
                            .debugButtonStyle(.orange)
                        }
                    }

                    // Stats Testing
                    VStack(spacing: 4) {
                        Text("STATS TESTING")
                            .font(.caption2)
                            .fontWeight(.semibold)

                        HStack(spacing: 8) {
                            Button("Full Session") {
                                timerManager.debugCompleteSession()
                            }
                            .debugButtonStyle(.green)

                            Button("Partial Session") {
                                timerManager.debugCompletePartialSession()
                            }
                            .debugButtonStyle(.mint)

                            Button("+5 Min") {
                                timerManager.debugAdd5Minutes()
                            }
                            .debugButtonStyle(.teal)
                        }

                        HStack(spacing: 8) {
                            Button("Reset Stats") {
                                timerManager.debugResetStats()
                            }
                            .debugButtonStyle(.red)
                        }
                    }

                    // Leaderboard Testing
                    VStack(spacing: 4) {
                        Text("LEADERBOARD TESTING")
                            .font(.caption2)
                            .fontWeight(.semibold)

                        HStack(spacing: 8) {
                            Button("Create Test Data") {
                                timerManager.createTestLeaderboardData()
                            }
                            .debugButtonStyle(.purple)

                            Button("Clear Test Data") {
                                timerManager.clearTestData()
                            }
                            .debugButtonStyle(.gray)
                        }
                    }

                    // Current Stats Display
                    VStack(spacing: 2) {
                        Text("CURRENT STATS")
                            .font(.caption2)
                            .fontWeight(.semibold)

                        Text("Today: \(timerManager.todayFocusMinutes) | Total: \(timerManager.totalFocusMinutes) | Streak: \(timerManager.currentStreak)")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        Text("Auth: \(timerManager.firebaseManagerPublished.isAuthenticated ? "✅" : "❌") | Online: \(timerManager.firebaseManagerPublished.isOnline ? "🟢" : "🔴")")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(8)
            }
            .frame(maxHeight: 200)
            .background(Color.black.opacity(0.8))
            .foregroundColor(.white)
            .cornerRadius(8)
            .padding()
        }

        Spacer()

        HStack {
            Spacer()
            Button(action: {
                showDebugPanel.toggle()
            }) {
                Text("🐛")
                    .font(.title2)
            }
            .padding()
        }
    }
)
#endif
    }

    // MARK: - Background View with Smooth Transitions

    private var backgroundView: some View {
        ZStack {
            if timerManager.isRunning {
                // Dynamic background for running state
                dynamicColorBackground
                    .transition(.opacity)
            } else {
                // Clean background for stopped state
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(.systemBackground),
                        Color(.systemGray6).opacity(0.3)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.8), value: timerManager.isRunning)
    }

    private var dynamicColorBackground: some View {
        ZStack {
            if timerManager.isFocusMode {
                // Focus mode gradient (coral to orange)
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 1.0, green: 0.373, blue: 0.427), // #FF5F6D
                        Color(red: 1.0, green: 0.765, blue: 0.443)  // #FFC371
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .ignoresSafeArea()
            } else {
                // Break mode gradient (blue)
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.2, green: 0.3, blue: 0.8),   // Deep blue
                        Color(red: 0.0, green: 0.8, blue: 1.0)    // Cyan blue
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .ignoresSafeArea()
            }

            // Shifting overlay that moves the gradient around
            LinearGradient(
                gradient: Gradient(colors: timerManager.isFocusMode ? [
                    Color(red: 1.0, green: 0.373, blue: 0.427).opacity(0.8), // #FF5F6D
                    Color(red: 1.0, green: 0.765, blue: 0.443).opacity(0.8)  // #FFC371
                ] : [
                    Color(red: 0.2, green: 0.3, blue: 0.8).opacity(0.8),
                    Color(red: 0.0, green: 0.8, blue: 1.0).opacity(0.8)
                ]),
                startPoint: UnitPoint(
                    x: 0.0 + sin(Double(colorShift) * 0.01) * 0.5,
                    y: 0.0 + cos(Double(colorShift) * 0.008) * 0.3
                ),
                endPoint: UnitPoint(
                    x: 1.0 + cos(Double(colorShift) * 0.012) * 0.5,
                    y: 1.0 + sin(Double(colorShift) * 0.009) * 0.3
                )
            )
            .ignoresSafeArea()
            .blendMode(.overlay)

            // Second shifting layer for more movement
            RadialGradient(
                gradient: Gradient(colors: timerManager.isFocusMode ? [
                    Color(red: 1.0, green: 0.373, blue: 0.427).opacity(0.3), // #FF5F6D
                    Color.clear,
                    Color(red: 1.0, green: 0.765, blue: 0.443).opacity(0.3)  // #FFC371
                ] : [
                    Color(red: 0.2, green: 0.3, blue: 0.8).opacity(0.3),
                    Color.clear,
                    Color(red: 0.0, green: 0.8, blue: 1.0).opacity(0.3)
                ]),
                center: UnitPoint(
                    x: 0.5 + sin(Double(colorShift) * 0.006) * 0.4,
                    y: 0.5 + cos(Double(colorShift) * 0.007) * 0.4
                ),
                startRadius: 100 + sin(Double(colorShift) * 0.015) * 50,
                endRadius: 600 + cos(Double(colorShift) * 0.011) * 200
            )
            .ignoresSafeArea()
            .blendMode(.multiply)
        }
        .animation(.easeInOut(duration: 1.0), value: timerManager.isRunning)
        .animation(.easeInOut(duration: 0.8), value: timerManager.isFocusMode)
    }

    // MARK: - Main Timer View

    private var mainTimerView: some View {
        VStack(spacing: 0) {
            // Header with stats button in top right
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("🍅 Pomodoro")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)

                    Text(timerManager.isFocusMode ? "Focus Time" : "Break Time")
                        .font(.title3)
                        .foregroundColor(timerManager.isFocusMode ? .red : .green)
                        .fontWeight(.medium)
                }

                Spacer()

                // Stats button in top right
                Button(action: {
                    showingStats = true
                }) {
                    Image(systemName: "calendar")
                        .font(.title2)
                        .foregroundColor(timerManager.isRunning ? .gray : .primary)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(Color(.systemGray5))
                                .opacity(timerManager.isRunning ? 0.5 : 1.0)
                        )
                }
                .disabled(timerManager.isRunning)
                .accessibilityLabel("Stats and streak calendar")
            }
            .padding(.horizontal, 30)
            .padding(.top, 10)
            .frame(height: 80)

            // Today's quick stats section
            HStack(spacing: 20) {
                QuickStatCard(
                    icon: "brain.head.profile",
                    value: "\(timerManager.todayFocusMinutes)",
                    label: "Today's Focus",
                    color: .red
                )

                QuickStatCard(
                    icon: "flame.fill",
                    value: "\(timerManager.currentStreak)",
                    label: "Day Streak",
                    color: .orange
                )

                QuickStatCard(
                    icon: "clock.fill",
                    value: "\(timerManager.totalFocusMinutes)",
                    label: "Total Minutes",
                    color: .blue
                )
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 20)

            // Main timer section
            VStack(spacing: 20) {
                // Emoji section - moved up
                VStack(spacing: 16) {
                    Text(timerManager.currentEmoji)
                        .font(.system(size: 80))
                        .scaleEffect(scaleEffect)
                        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: timerManager.currentEmoji)
                        .animation(.easeInOut(duration: 0.3), value: scaleEffect)

                    // Helper text
                    if !timerManager.isRunning {
                        Text("Tap timer to start \(timerManager.isFocusMode ? "focus" : "break") session")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .opacity(backgroundOpacity)
                            .animation(.easeInOut(duration: 0.3), value: timerManager.isFocusMode)
                            .animation(.easeInOut(duration: 0.3), value: backgroundOpacity)
                    }
                }
                .frame(maxWidth: .infinity)

                // Timer display with modern design
                ZStack {
                    // Outer glow effect
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    (timerManager.isFocusMode ? Color.red : Color.green).opacity(0.1),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 100,
                                endRadius: 140
                            )
                        )
                        .frame(width: 280, height: 280)
                        .scaleEffect(scaleEffect)
                        .animation(.easeInOut(duration: 0.3), value: scaleEffect)

                    // Background circle with subtle shadow
                    Circle()
                        .fill(Color(.systemBackground))
                        .frame(width: 260, height: 260)
                        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                        .scaleEffect(scaleEffect)
                        .animation(.easeInOut(duration: 0.3), value: scaleEffect)

                    // Progress circle
                    Circle()
                        .trim(from: 0, to: timerManager.progress)
                        .stroke(
                            LinearGradient(
                                colors: timerManager.isFocusMode ?
                                    [Color.red.opacity(0.7), Color.red, Color.orange.opacity(0.8)] :
                                    [Color.green.opacity(0.7), Color.green, Color.mint.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .frame(width: 260, height: 260)
                        .rotationEffect(.degrees(-90))
                        .scaleEffect(scaleEffect)
                        .animation(.easeInOut(duration: 0.5), value: timerManager.progress)
                        .animation(.easeInOut(duration: 0.3), value: scaleEffect)

                    // Time display
                    VStack(spacing: 8) {
                        Text(timerManager.formattedTime)
                            .font(.system(size: 48, weight: .ultraLight, design: .monospaced))
                            .foregroundColor(.primary)
                            .opacity(backgroundOpacity)
                            .animation(.easeInOut(duration: 0.3), value: backgroundOpacity)

                        Text(timerManager.isFocusMode ? "Focus" : "Break")
                            .font(.callout)
                            .foregroundColor(.secondary)
                            .fontWeight(.medium)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color(.systemGray6))
                            )
                            .opacity(backgroundOpacity)
                            .animation(.easeInOut(duration: 0.3), value: backgroundOpacity)
                    }
                }
                .frame(maxWidth: .infinity)
                .onTapGesture {
                    if !timerManager.isRunning {
                        withAnimation(.easeInOut(duration: 0.6)) {
                            timerManager.startTimer()
                        }
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(timerManager.isFocusMode ? "Focus timer" : "Break timer")
                .accessibilityValue("\(timerManager.formattedTime) remaining")
                .accessibilityHint(timerManager.isRunning ? "" : "Double tap to start the session")
                .accessibilityAddTraits(.isButton)

                // Modern control buttons
                HStack(spacing: 30) {
                    // Reset button
                    ControlButton(
                        icon: "arrow.clockwise",
                        action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                timerManager.resetTimer()
                            }
                        },
                        disabled: timerManager.isRunning,
                        color: .gray,
                        accessibilityLabel: "Reset timer"
                    )

                    // Skip/Mode Switch button
                    ControlButton(
                        icon: "forward.fill",
                        action: {
                            if timerManager.isRunning && timerManager.isFocusMode {
                                timerManager.generateRandomMotivationalQuote()
                                showingSkipConfirmation = true
                            } else {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    timerManager.switchMode()
                                }
                            }
                        },
                        disabled: false,
                        color: .blue,
                        accessibilityLabel: timerManager.isFocusMode ? "Skip focus session" : "Switch mode"
                    )

                    // Leaderboard button
                    ControlButton(
                        icon: "trophy.fill",
                        action: { showingLeaderboard = true },
                        disabled: timerManager.isRunning,
                        color: .yellow,
                        accessibilityLabel: "Leaderboard"
                    )

                    // Settings button
                    ControlButton(
                        icon: "gearshape.fill",
                        action: { showingSettings = true },
                        disabled: timerManager.isRunning,
                        color: .purple,
                        accessibilityLabel: "Settings"
                    )
                }
                .frame(maxWidth: .infinity)
                .opacity(backgroundOpacity)
                .animation(.easeInOut(duration: 0.3), value: backgroundOpacity)

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.vertical, 20)

            // Bottom status area
            VStack {
                if timerManager.isLocked {
                    HStack(spacing: 8) {
                        Image(systemName: "lock.fill")
                            .foregroundColor(.red)
                            .font(.caption)

                        Text("Stay focused - don't leave this screen!")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.red.opacity(0.1))
                            .overlay(
                                Capsule()
                                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
                            )
                    )
                    .animation(.easeInOut(duration: 0.3), value: timerManager.isLocked)
                }
            }
            .frame(height: 40)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Full Screen Timer View

    private func fullScreenTimerView(geometry: GeometryProxy) -> some View {
        ZStack {
            VStack(spacing: 0) {
                // Top section with message
                VStack {
                    Spacer()
                    Text(timerManager.currentEncouragingMessage)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                        .opacity(timerManager.isRunning ? 1 : 0)
                        .animation(.easeInOut(duration: 1.0).delay(0.6), value: timerManager.isRunning)
                    Spacer()
                }
                .frame(height: geometry.size.height * 0.25)

                // Center section with timer and emoji
                VStack(spacing: 20) {
                    // Timer display above emoji
                    Text(timerManager.formattedTime)
                        .font(.system(size: 56, weight: .thin, design: .monospaced))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 2)
                        .opacity(timerManager.isRunning ? 1 : 0)
                        .animation(.easeInOut(duration: 1.0).delay(0.8), value: timerManager.isRunning)
                        .accessibilityLabel(timerManager.isFocusMode ? "Focus time remaining" : "Break time remaining")
                        .accessibilityValue(timerManager.formattedTime)

                    // Emoji with timer ring border
                    ZStack {
                        // Timer progress ring around the emoji
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 12)
                            .frame(width: min(geometry.size.width * 0.7, geometry.size.height * 0.35))
                            .opacity(timerManager.isRunning ? 1 : 0)
                            .animation(.easeInOut(duration: 1.0).delay(1.0), value: timerManager.isRunning)

                        Circle()
                            .trim(from: 0, to: timerManager.progress)
                            .stroke(
                                Color.white,
                                style: StrokeStyle(lineWidth: 12, lineCap: .round)
                            )
                            .frame(width: min(geometry.size.width * 0.7, geometry.size.height * 0.35))
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.5), value: timerManager.progress)
                            .opacity(timerManager.isRunning ? 1 : 0)
                            .animation(.easeInOut(duration: 1.0).delay(1.0), value: timerManager.isRunning)

                        // Centered emoji with hover effect
                        Text(timerManager.currentEmoji)
                            .font(.system(size: 80))
                            .scaleEffect(timerManager.isRunning ? 1.3 : 1.0)
                            .offset(y: emojiHovered ? -4 : 0)
                            .animation(.easeInOut(duration: 0.2), value: emojiHovered)
                            .animation(.easeInOut(duration: 1.0), value: timerManager.isRunning)
                            .onTapGesture {
                                if timerManager.isRunning {
                                    withAnimation(.easeInOut(duration: 0.6)) {
                                        timerManager.pauseTimer()
                                    }
                                }
                            }
                            .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity) { isPressing in
                                emojiHovered = isPressing
                            } perform: {}
                    }

                    // Helper text under emoji when running
                    if timerManager.isRunning {
                        Text("Tap emoji to pause and exit \(timerManager.isFocusMode ? "focus" : "break") mode")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                            .opacity(timerManager.isRunning ? 1 : 0)
                            .animation(.easeInOut(duration: 1.0).delay(1.6), value: timerManager.isRunning)
                    }
                }
                .frame(height: geometry.size.height * 0.5)
                .frame(maxWidth: .infinity)

                // Bottom section with mode indicator
                VStack {
                    Text(timerManager.isFocusMode ? "Focus Mode" : "Break Mode")
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.9))
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                        .opacity(timerManager.isRunning ? 1 : 0)
                        .animation(.easeInOut(duration: 1.0).delay(1.2), value: timerManager.isRunning)
                        .padding(.top, 20)

                    Spacer()
                }
                .frame(height: geometry.size.height * 0.25)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Floating control buttons
            VStack {
                Spacer()

                HStack(spacing: 60) {
                    // Restart button
                    FloatingButton(
                        icon: "arrow.clockwise",
                        label: "Restart",
                        action: {
                            withAnimation(.easeInOut(duration: 0.5)) {
                                timerManager.restartCurrentTimer()
                            }
                        }
                    )

                    // Skip button
                    FloatingButton(
                        icon: "forward.fill",
                        label: "Skip",
                        action: {
                            if timerManager.isFocusMode {
                                timerManager.generateRandomMotivationalQuote()
                                showingSkipConfirmation = true
                            } else {
                                withAnimation(.easeInOut(duration: 0.5)) {
                                    timerManager.skipTimer()
                                }
                            }
                        }
                    )
                }
                .opacity(timerManager.isRunning ? 1 : 0)
                .animation(.easeInOut(duration: 1.0).delay(1.4), value: timerManager.isRunning)
                .padding(.bottom, 60)
            }
        }
    }
}

// MARK: - Custom UI Components

struct QuickStatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)

            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)

            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
}

struct ControlButton: View {
    let icon: String
    let action: () -> Void
    let disabled: Bool
    let color: Color
    var accessibilityLabel: String = ""

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(disabled ? .gray : .white)
                .frame(width: 50, height: 50)
                .background(
                    Circle()
                        .fill(disabled ? Color.gray.opacity(0.3) : color)
                        .shadow(color: disabled ? .clear : color.opacity(0.3), radius: 8, x: 0, y: 4)
                )
        }
        .disabled(disabled)
        .scaleEffect(disabled ? 0.9 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: disabled)
        .accessibilityLabel(accessibilityLabel)
    }
}

struct FloatingButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.white)

                Text(label)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.9))
            }
            .frame(width: 80, height: 60)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

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
                    .font(.system(size: 80))
                    .scaleEffect(1.0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: currentStep)

                VStack(spacing: 16) {
                    Text(welcomeSteps[currentStep].title)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
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
                    .font(.system(size: 50))
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
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.orange)
                )
                .padding(.horizontal, 40)
            }
        }
    }
}

// Add this extension for consistent button styling
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

#Preview {
    ContentView()
}
