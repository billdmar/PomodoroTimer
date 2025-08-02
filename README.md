# Pomodoro Timer App

A simple and elegant Pomodoro timer iOS app built with SwiftUI.

## Features

### 🍅 Tomato Timer
- **25-minute focus sessions** by default
- **5-minute break sessions** by default
- **Customizable durations** through settings
- **Visual progress circle** showing timer progress
- **Focus mode locking** to keep you on task

### 🎯 Interactive Tomato Button
- **Shake animation** when clicked
- **Star particle effects** bursting from all sides
- **Large, intuitive interface** for easy interaction
- **Disabled during timer** to prevent interruption

### ⚙️ Settings & Customization
- **Edit focus duration** (1-60 minutes)
- **Edit break duration** (1-30 minutes)
- **Real-time preview** of current settings
- **Save/cancel functionality**

### 🎨 Beautiful UI
- **Gradient background** for visual appeal
- **Color-coded modes** (red for focus, green for break)
- **Smooth animations** throughout the app
- **Modern iOS design** following Apple guidelines

### 🔧 Controls
- **Reset button** - Reset current timer
- **Skip button** - Skip to next session
- **Settings button** - Access customization options
- **Lock indicator** - Shows when in focus mode

## How to Use

1. **Start a Focus Session**: Tap the tomato button to begin a 25-minute focus session
2. **Stay Focused**: The app locks you in focus mode to prevent distractions
3. **Take a Break**: After 25 minutes, enjoy a 5-minute break
4. **Customize**: Use the settings button to adjust durations to your preference
5. **Control**: Use the control buttons to reset, skip, or access settings

## Technical Details

- **Built with**: SwiftUI
- **iOS Target**: iOS 15.0+
- **Architecture**: MVVM with ObservableObject
- **Animations**: SwiftUI animations for smooth interactions
- **Timer**: Foundation Timer for accurate countdown

## Files Structure

```
pomadoro2/
├── pomadoro2App.swift          # App entry point
├── ContentView.swift           # Main view with timer and controls
├── TimerManager.swift          # Timer logic and state management
├── TomatoButton.swift          # Interactive tomato button with animations
├── StarParticlesView.swift     # Star particle effects
├── SettingsView.swift          # Settings and customization
└── Assets.xcassets/           # App icons and colors
```

## Getting Started

1. Open the project in Xcode
2. Select your target device or simulator
3. Build and run the project
4. Start your first Pomodoro session!

## Pomodoro Technique

The Pomodoro Technique is a time management method developed by Francesco Cirillo in the late 1980s. It uses a timer to break work into intervals, traditionally 25 minutes in length, separated by short breaks. This app helps you implement this technique effectively.

**Benefits:**
- Improved focus and concentration
- Reduced mental fatigue
- Better time management
- Increased productivity
- Regular breaks for mental health 