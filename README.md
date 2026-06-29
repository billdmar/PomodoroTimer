# Pomodoro Timer

**Focus, one tomato at a time.** 🍅

A polished Pomodoro focus-timer for iOS. Run customizable focus and break sessions with a background-safe timer, see the session on the Lock screen and Dynamic Island, stay accountable with real Screen Time app blocking, track your productivity, and compete on a global leaderboard. Built with SwiftUI and Firebase.

[![CI](https://github.com/billdmar/PomodoroTimer/actions/workflows/ci.yml/badge.svg)](https://github.com/billdmar/PomodoroTimer/actions/workflows/ci.yml)
![Swift](https://img.shields.io/badge/Swift-5-orange?logo=swift&logoColor=white)
![iOS](https://img.shields.io/badge/iOS-18.5%2B-000000?logo=apple&logoColor=white)
![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-0071e3)
![Firebase](https://img.shields.io/badge/Firebase-Firestore-FFCA28?logo=firebase&logoColor=black)
![License](https://img.shields.io/badge/License-MIT-green)

---

## Features

- **Background-safe timer** — A deadline-based engine (the wall clock is the source of truth, not a per-second tick), so the countdown stays accurate when the app is backgrounded or suspended, and completes — with a notification — even while you're in another app.
- **Crash & quit recovery** — An interrupted session is snapshotted and restored on relaunch at the correct remaining time; settings persist across launches.
- **Focus & break sessions** — 25-minute focus and 5-minute break sessions by default, each fully customizable (1–60 min focus, 1–30 min break).
- **Live Activity & widget** — A Dynamic Island / Lock-screen Live Activity and a Home/Lock-screen WidgetKit widget show the running session at a glance.
- **Real focus enforcement** — Optional Screen Time (Family Controls) app shielding during focus sessions, with a graceful motivational fallback when unauthorized.
- **Animated progress ring** — A visual progress circle and color-coded modes make your session state obvious at a glance.
- **Polished feel** — Haptic feedback on key actions, Reduce Motion support, and VoiceOver labels; star-particle bursts for a bit of delight.
- **Stats & global leaderboard** — Track focus minutes and streaks over time, and compete with others, backed by Firebase Cloud Firestore.

## Tech stack

| Area | Technology |
| --- | --- |
| UI | SwiftUI (iOS 18.5+) |
| Language | Swift 5 |
| Architecture | MVVM with `ObservableObject`; pure, unit-tested logic types |
| Timer | Deadline/`Date`-based engine with an async `Task` display tick |
| Widgets | WidgetKit + ActivityKit (Live Activity / Dynamic Island) |
| Focus lock | FamilyControls / ManagedSettings (Screen Time), entitlement-gated |
| Backend | Firebase Cloud Firestore (leaderboard) |
| Quality | SwiftLint + code-coverage gate in CI |

For a deeper walkthrough of the timer engine, focus-mode lock, and Firestore leaderboard, see [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md). Widget and Screen Time setup are documented in [docs/WIDGET_SETUP.md](docs/WIDGET_SETUP.md) and [docs/SCREEN_TIME_SETUP.md](docs/SCREEN_TIME_SETUP.md).

## Screenshots

| Home | Focus session | Break |
| :--: | :--: | :--: |
| ![Home](docs/home.png) | ![Focus session](docs/timer.png) | ![Break](docs/break.png) |

| Settings | Progress & streak | Leaderboard |
| :--: | :--: | :--: |
| ![Settings](docs/settings.png) | ![Progress](docs/stats.png) | ![Leaderboard](docs/leaderboard.png) |

| Focus-mode lock | | |
| :--: | :--: | :--: |
| ![Skip focus prompt](docs/skip.png) | | |

## Project structure

```
pomadoro2/
├── pomadoro2App.swift          # App entry point + scene-phase wiring
├── ContentView.swift           # Main timer screen and controls
├── TimerComponents.swift       # Reusable timer UI components
├── WelcomeView.swift           # Onboarding flow + focus-lock overlay
├── DesignTokens.swift          # Centralized colors / spacing / animation
├── TimerManager.swift          # Timer engine + session orchestration (facade)
├── TimerMath.swift             # Pure timer helpers (formatting, progress, deadline) — unit-tested
├── StreakCalculator.swift      # Pure streak math — unit-tested
├── StatsStore.swift            # Stats model + pure calculator + persistence — unit-tested
├── SettingsStore.swift         # Persisted timer preferences — unit-tested
├── SessionStore.swift          # Crash/quit session recovery — unit-tested
├── SharedSessionState.swift    # App-Group state shared with the widget
├── TimerActivityAttributes.swift # Live Activity attributes (shared)
├── LiveActivityController.swift  # Starts/updates/ends the Live Activity
├── AppLockManager.swift        # Focus-mode locking (motivational + Screen Time)
├── ScreenTimeController.swift  # Real FamilyControls shielding, entitlement-gated
├── Haptics.swift               # Haptic feedback helper
├── Logging.swift               # Debug logging that compiles out of Release builds
├── TomatoButton.swift          # Interactive tomato button + animations
├── StarParticlesView.swift     # Particle-effect celebrations
├── SettingsView.swift          # Duration customization
├── StatsView.swift             # Productivity stats and streak calendar
├── LeaderboardView.swift       # Global leaderboard UI
└── FirebaseManager.swift       # Firestore integration

PomodoroWidget/                 # WidgetKit widget + Live Activity UI (separate target)
pomadoro2Tests/                 # Swift Testing unit tests (timer, streak, stats, settings, session)
pomadoro2UITests/               # XCUITest smoke tests
scripts/check-coverage.sh       # Coverage gate for the pure-logic files
firestore.rules                 # Least-privilege Firestore security rules
.github/workflows/ci.yml        # SwiftLint + build + test + coverage on every push / PR
```

## Getting started

1. Open `pomadoro2.xcodeproj` in Xcode.
2. The project uses Firebase for the leaderboard. To run with your own backend, create a Firebase project and replace `pomadoro2/GoogleService-Info.plist` with your own config.
3. Build and run on a simulator or device.

> The bundled `GoogleService-Info.plist` holds Firebase **client** configuration, which Google designs to ship inside apps — access is controlled by Firestore security rules, not by keeping this file secret.

## Testing

```bash
xcodebuild test \
  -project pomadoro2.xcodeproj \
  -scheme pomadoro2 \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  CODE_SIGNING_ALLOWED=NO
```

- **Unit tests** ([`pomadoro2Tests`](pomadoro2Tests)) cover the pure logic with the [Swift Testing](https://developer.apple.com/documentation/testing) framework: timer formatting/progress and the deadline countdown (`TimerMath`), streak transitions (`StreakCalculator`), stats accumulation/merge (`StatsStore`), settings persistence (`SettingsStore`), and crash/quit recovery (`SessionStore`). All time-dependent logic takes an injected clock so tests are deterministic.
- **UI smoke tests** ([`pomadoro2UITests`](pomadoro2UITests)) verify the app launches to the timer screen and that starting a session shows the running timer.
- Every push and pull request runs **SwiftLint**, the build, the unit suite, and a **code-coverage gate** (on the pure-logic files) on an iOS Simulator via [GitHub Actions](.github/workflows/ci.yml).

## Backend security

The leaderboard runs on Firebase Cloud Firestore. The repository ships [`firestore.rules`](firestore.rules), which enforces least privilege:

- `userStats/{uid}` is **publicly readable** (so any client can render the leaderboard) but **writable only by the authenticated owner**, with field/type validation on the numeric stats.
- `focusSessions` is **append-only** for the authenticated owner — no client reads, edits, or deletes.

Deploy the rules with:

```bash
firebase deploy --only firestore:rules
```

For defense in depth, also add an [API-key application restriction](https://cloud.google.com/docs/authentication/api-keys#api_key_restrictions) in the Google Cloud console, limiting the iOS key to the app's bundle identifier (`dh.pomadoro2`).

## About the Pomodoro Technique

The Pomodoro Technique, developed by Francesco Cirillo in the late 1980s, breaks work into focused intervals (traditionally 25 minutes) separated by short breaks — improving focus, reducing fatigue, and making time management more sustainable.

## License

[MIT](LICENSE) © William Mar
