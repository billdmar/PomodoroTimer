# Pomodoro Timer

**Focus, one tomato at a time.** 🍅

A polished Pomodoro focus-timer for iOS. Run customizable focus and break sessions, stay accountable with a focus-mode lock, track your productivity over time, and compete on a global leaderboard. Built with SwiftUI and Firebase.

![Swift](https://img.shields.io/badge/Swift-5-orange?logo=swift&logoColor=white)
![iOS](https://img.shields.io/badge/iOS-15%2B-000000?logo=apple&logoColor=white)
![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-0071e3)
![Firebase](https://img.shields.io/badge/Firebase-Firestore-FFCA28?logo=firebase&logoColor=black)
![License](https://img.shields.io/badge/License-MIT-green)

---

## Features

- **Focus & break sessions** — 25-minute focus and 5-minute break sessions by default, each fully customizable (1–60 min focus, 1–30 min break).
- **Animated progress ring** — A visual progress circle and color-coded modes (red for focus, green for break) make your session state obvious at a glance.
- **Focus-mode lock** — Locks you into a session to discourage task-switching, with reset and skip controls.
- **Interactive tomato button** — Shake animation and star-particle bursts for a bit of delight.
- **Stats** — Track sessions completed and time focused over time.
- **Global leaderboard** — Compete with other users, backed by Firebase Cloud Firestore.

## Tech stack

| Area | Technology |
| --- | --- |
| UI | SwiftUI (iOS 15+) |
| Language | Swift 5 |
| Architecture | MVVM with `ObservableObject` |
| Backend | Firebase Cloud Firestore (leaderboard) |
| Timer | Foundation `Timer` |

## Screenshots

<!--
  Add screenshots here. Drop your images into a `docs/` folder and reference them, e.g.:

  | Focus session | Settings | Leaderboard |
  | :--: | :--: | :--: |
  | ![Timer](docs/timer.png) | ![Settings](docs/settings.png) | ![Leaderboard](docs/leaderboard.png) |

  In the iOS Simulator: File ▸ Save Screen (⌘S) saves a clean device-framed PNG.
-->

_Screenshots coming soon — run the app in the iOS Simulator and capture the timer, settings, and leaderboard screens._

## Project structure

```
pomadoro2/
├── pomadoro2App.swift       # App entry point
├── ContentView.swift        # Main timer screen and controls
├── TimerManager.swift       # Timer logic and session state
├── AppLockManager.swift     # Focus-mode locking
├── TomatoButton.swift       # Interactive tomato button + animations
├── StarParticlesView.swift  # Particle-effect celebrations
├── SettingsView.swift       # Duration customization
├── StatsView.swift          # Productivity stats
├── LeaderboardView.swift    # Global leaderboard UI
└── FirebaseManager.swift    # Firestore integration
```

## Getting started

1. Open `pomadoro2.xcodeproj` in Xcode.
2. The project uses Firebase for the leaderboard. To run with your own backend, create a Firebase project and replace `pomadoro2/GoogleService-Info.plist` with your own config.
3. Build and run on a simulator or device.

> The bundled `GoogleService-Info.plist` holds Firebase **client** configuration, which Google designs to ship inside apps — access is controlled by Firestore security rules, not by keeping this file secret.

## About the Pomodoro Technique

The Pomodoro Technique, developed by Francesco Cirillo in the late 1980s, breaks work into focused intervals (traditionally 25 minutes) separated by short breaks — improving focus, reducing fatigue, and making time management more sustainable.

## License

[MIT](LICENSE) © William Mar
