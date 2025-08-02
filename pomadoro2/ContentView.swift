//
//  ContentView.swift
//  pomadoro2
//
//  Created by Bill Mar on 7/30/25.
//

import SwiftUI
import Foundation

struct ContentView: View {
    @StateObject private var timerManager = TimerManager()
    @State private var showingSettings = false
    @State private var showingWelcome = true
    @State private var colorShift: CGFloat = 0
    @State private var emojiHovered = false
    @State private var showingSkipConfirmation = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if timerManager.isRunning {
                    // Dynamic background
                    dynamicColorBackground
                    
                    // Full screen timer view
                    fullScreenTimerView
                } else {
                    // Clean background
                    Color.white
                        .ignoresSafeArea()
                    
                    if showingWelcome {
                        WelcomeView(showingWelcome: $showingWelcome)
                    } else {
                        mainTimerView
                    }
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(timerManager: timerManager)
        }
        .alert("Timer Complete! 🎉", isPresented: $timerManager.showingCompletionAlert) {
            Button("Start \(timerManager.isFocusMode ? "Focus" : "Break")") {
                timerManager.startTimer()
            }
            Button("Not Now", role: .cancel) { }
        } message: {
            Text(timerManager.completionMessage)
        }
        .alert("Skip Focus Session? 🤔", isPresented: $showingSkipConfirmation) {
            Button("Keep Going!", role: .cancel) { }
            Button("Skip", role: .destructive) {
                timerManager.skipTimer()
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
                    x: 0.0 + Foundation.sin(Double(colorShift) * 0.01) * 0.5,
                    y: 0.0 + Foundation.cos(Double(colorShift) * 0.008) * 0.3
                ),
                endPoint: UnitPoint(
                    x: 1.0 + Foundation.cos(Double(colorShift) * 0.012) * 0.5,
                    y: 1.0 + Foundation.sin(Double(colorShift) * 0.009) * 0.3
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
                    x: 0.5 + Foundation.sin(Double(colorShift) * 0.006) * 0.4,
                    y: 0.5 + Foundation.cos(Double(colorShift) * 0.007) * 0.4
                ),
                startRadius: 100 + Foundation.sin(Double(colorShift) * 0.015) * 50,
                endRadius: 600 + Foundation.cos(Double(colorShift) * 0.011) * 200
            )
            .ignoresSafeArea()
            .blendMode(.multiply)
        }
        .animation(.easeInOut(duration: 1.0), value: timerManager.isRunning)
        .animation(.easeInOut(duration: 0.8), value: timerManager.isFocusMode)
    }
    
    private var mainTimerView: some View {
        VStack(spacing: 0) {
            // Fixed header at top
            VStack(spacing: 8) {
                Text("🍅 Pomodoro")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text(timerManager.isFocusMode ? "Focus Time" : "Break Time")
                    .font(.title3)
                    .foregroundColor(timerManager.isFocusMode ? .red : .green)
                    .fontWeight(.medium)
            }
            .frame(height: 80)
            .frame(maxWidth: .infinity)
            .padding(.top, 10)
            
            // Main content area - centered
            VStack(spacing: 25) {
                Spacer()
                
                // Timer display - perfectly centered
                ZStack {
                    // Subtle background circle
                    Circle()
                        .stroke(Color.gray.opacity(0.1), lineWidth: 8)
                        .frame(width: 250, height: 250)
                    
                    // Progress circle
                    Circle()
                        .trim(from: 0, to: timerManager.progress)
                        .stroke(
                            timerManager.isFocusMode ?
                                LinearGradient(colors: [.red.opacity(0.8), .red], startPoint: .topLeading, endPoint: .bottomTrailing) :
                                LinearGradient(colors: [.green.opacity(0.8), .green], startPoint: .topLeading, endPoint: .bottomTrailing),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 250, height: 250)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.5), value: timerManager.progress)
                    
                    // Clean time display
                    VStack(spacing: 8) {
                        Text(timerManager.formattedTime)
                            .font(.system(size: 44, weight: .thin, design: .monospaced))
                            .foregroundColor(.primary)
                        
                        Text(timerManager.isFocusMode ? "Focus" : "Break")
                            .font(.callout)
                            .foregroundColor(.secondary)
                            .fontWeight(.medium)
                    }
                }
                .frame(maxWidth: .infinity)
                
                Spacer()
                
                // Enhanced tomato button - centered
                VStack(spacing: 12) {
                    TomatoButton(timerManager: timerManager)
                    
                    // Helper text under button
                    if !timerManager.isRunning {
                        Text("Press me to start \(timerManager.isFocusMode ? "focus" : "break") mode")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .animation(.easeInOut(duration: 0.3), value: timerManager.isFocusMode)
                    } else {
                        Text("Press me to pause and exit \(timerManager.isFocusMode ? "focus" : "break") mode")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .animation(.easeInOut(duration: 0.3), value: timerManager.isFocusMode)
                    }
                }
                .frame(maxWidth: .infinity)
                
                Spacer()
                
                // Control buttons - centered
                HStack(spacing: 30) {
                    // Reset button
                    Button(action: {
                        timerManager.resetTimer()
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.title2)
                            .foregroundColor(timerManager.isRunning ? .gray : .primary)
                            .frame(width: 50, height: 50)
                            .background(
                                Circle()
                                    .fill(Color.gray.opacity(0.2))
                                    .opacity(timerManager.isRunning ? 0.5 : 1.0)
                            )
                    }
                    .disabled(timerManager.isRunning)
                    
                    // Skip/Mode Switch button
                    Button(action: {
                        if timerManager.isRunning && timerManager.isFocusMode {
                            // Show confirmation dialog for focus mode
                            timerManager.generateRandomMotivationalQuote()
                            showingSkipConfirmation = true
                        } else {
                            timerManager.switchMode()
                        }
                    }) {
                        Image(systemName: "forward.fill")
                            .font(.title2)
                            .foregroundColor(.primary)
                            .frame(width: 50, height: 50)
                            .background(
                                Circle()
                                    .fill(Color.gray.opacity(0.2))
                            )
                    }
                    
                    // Settings button
                    Button(action: {
                        showingSettings = true
                    }) {
                        Image(systemName: "gearshape")
                            .font(.title2)
                            .foregroundColor(timerManager.isRunning ? .gray : .primary)
                            .frame(width: 50, height: 50)
                            .background(
                                Circle()
                                    .fill(Color.gray.opacity(0.2))
                                    .opacity(timerManager.isRunning ? 0.5 : 1.0)
                            )
                    }
                    .disabled(timerManager.isRunning)
                }
                .frame(maxWidth: .infinity)
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.vertical, 20)
            
            // Bottom status area - centered
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
                    )
                }
            }
            .frame(height: 40)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 30)
    }
    
    private var fullScreenTimerView: some View {
        GeometryReader { geometry in
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
                        
                        // Emoji with timer ring border - perfectly centered
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
                                        timerManager.pauseTimer()
                                    }
                                }
                                .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity) { isPressing in
                                    emojiHovered = isPressing
                                } perform: {
                                    // This won't be called since minimumDuration is 0
                                }
                        }
                        
                        // Helper text under emoji when running
                        if timerManager.isRunning {
                            Text("Press me to pause and exit \(timerManager.isFocusMode ? "focus" : "break") mode")
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
                
                // Floating control buttons - only visible when timer is running
                VStack {
                    Spacer()
                    
                    HStack(spacing: 60) {
                        // Restart/Redo button
                        Button(action: {
                            timerManager.restartCurrentTimer()
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                
                                Text("Restart")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            .frame(width: 70, height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.black.opacity(0.3))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Skip button
                        Button(action: {
                            if timerManager.isFocusMode {
                                // Show confirmation dialog for focus mode
                                timerManager.generateRandomMotivationalQuote()
                                showingSkipConfirmation = true
                            } else {
                                timerManager.skipTimer()
                            }
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: "forward.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                
                                Text("Skip")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            .frame(width: 70, height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.black.opacity(0.3))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .opacity(timerManager.isRunning ? 1 : 0)
                    .animation(.easeInOut(duration: 1.0).delay(1.4), value: timerManager.isRunning)
                    .padding(.bottom, 60)
                }
            }
        }
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

#Preview {
    ContentView()
}
