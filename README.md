# Pomodoro Timer

**Focus, one tomato at a time.** 🍅

A polished Pomodoro focus-timer for iOS. Run customizable focus, short-break, and long-break cycles with a background-safe timer; see the session on the Lock screen and Dynamic Island; stay accountable with real Screen Time app blocking; hit a daily focus goal; earn achievement badges; review your history in charts; and compete on a global leaderboard. Start a session hands-free with Siri, Shortcuts, or a Control Center button. Built with SwiftUI, Swift Charts, App Intents, and Firebase.

[![CI](https://github.com/billdmar/PomodoroTimer/actions/workflows/ci.yml/badge.svg)](https://github.com/billdmar/PomodoroTimer/actions/workflows/ci.yml)
![Swift](https://img.shields.io/badge/Swift-5-orange?logo=swift&logoColor=white)
![iOS](https://img.shields.io/badge/iOS-18.5%2B-000000?logo=apple&logoColor=white)
![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-0071e3)
![Firebase](https://img.shields.io/badge/Firebase-Firestore-FFCA28?logo=firebase&logoColor=black)
![License](https://img.shields.io/badge/License-MIT-green)

---

## Features

- **Background-safe timer** — A deadline-based engine (the wall clock is the source of truth, not a per-second tick), so the countdown stays accurate when the app is backgrounded or suspended, and completes — with a notification — even while you're in another app.
- **Focus, short-break & long-break cycles** — 25-minute focus and 5-minute break sessions by default, each fully customizable. A longer break automatically follows every 4th focus session, with its own configurable duration.
- **Crash & quit recovery** — An interrupted session is snapshotted and restored on relaunch at the correct remaining time; settings persist across launches.
- **Daily focus goal** — Set a daily minutes target and watch a progress ring fill as you complete sessions.
- **Achievements** — Earn milestone badges (first session, five sessions in a day, 7- and 30-day streaks, 100 sessions, 1000 focus minutes) surfaced in the Stats screen.
- **Focus history charts** — Weekly and monthly bar charts (built with Swift Charts) visualize your focus minutes over time, backed by a local daily-history store.
- **Live Activity, widget & Control Center** — A Dynamic Island / Lock-screen Live Activity and a Home/Lock-screen WidgetKit widget show the running session at a glance, plus an iOS 18 Control Center "Start Focus" control.
- **Siri & Shortcuts** — App Intents expose "Start Focus" and "Check Streak" to Siri, Spotlight, and the Shortcuts app.
- **Real focus enforcement** — Optional real app blocking via Screen Time during focus sessions (requires the Family Controls entitlement), with a graceful motivational fallback when unauthorized.
- **Themes & appearance** — Five accent themes plus light / dark / system appearance, applied app-wide.
- **Sounds & notification actions** — Choose a completion sound (classic, chime, bell, or silent), and extend a session by 5 minutes straight from the completion notification.
- **Animated progress ring** — A visual progress circle and color-coded modes make your session state obvious at a glance.
- **Polished feel** — Haptic feedback on key actions, Reduce Motion support, and VoiceOver labels; star-particle bursts for a bit of delight.
- **Stats & global leaderboard** — Track focus minutes and streaks over time, and compete with others, backed by Firebase Cloud Firestore.

## Tech stack

| Area | Technology |
| --- | --- |
| UI | SwiftUI (iOS 18.5+) |
| Language | Swift 5 |
| Architecture | MVVM with `ObservableObject`; pure, unit-tested logic types; dependency injection (protocol-backed mock backend) for a fully testable timer engine |
| Timer | Deadline/`Date`-based engine with an async `Task` display tick |
| Charts | Swift Charts (weekly / monthly focus history) |
| Widgets | WidgetKit + ActivityKit (Live Activity / Dynamic Island) |
| Siri & automation | App Intents (Siri / Shortcuts) + a Control Center control (iOS 18) |
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
│
│   # ── Views & UI ──────────────────────────────────────────────
├── pomadoro2App.swift          # App entry point + scene-phase wiring
├── ContentView.swift           # Main timer screen and controls
├── TimerComponents.swift       # Reusable timer UI components
├── ProgressRingView.swift      # Animated circular progress / goal ring
├── TomatoButton.swift          # Interactive tomato button + animations
├── StarParticlesView.swift     # Particle-effect celebrations
├── DynamicBackgroundView.swift # Animated, mode-aware gradient background
├── CardModifiers.swift         # Shared card / surface styling
├── DesignTokens.swift          # Centralized colors / spacing / animation
├── WelcomeView.swift           # Onboarding flow + focus-lock overlay
├── SettingsView.swift          # Durations, goal, theme & sound customization
├── StatsView.swift             # Stats, streak calendar & achievement badges
├── HistoryChartView.swift      # Weekly / monthly focus charts (Swift Charts)
├── LeaderboardView.swift       # Global leaderboard UI
│
│   # ── Timer engine ────────────────────────────────────────────
├── TimerManager.swift          # Timer engine + session orchestration (facade); DI-testable
├── TimerMath.swift             # Pure timer helpers (formatting, progress, deadline) — unit-tested
├── TimerState.swift            # Timer state machine (modes / transitions) — unit-tested
├── BreakPolicy.swift           # Short- vs. long-break cycle logic (every 4th focus) — unit-tested
│
│   # ── Stores & logic ──────────────────────────────────────────
├── StatsStore.swift            # Stats model + pure calculator + persistence — unit-tested
├── StreakCalculator.swift      # Pure streak math — unit-tested
├── Achievements.swift          # Milestone badges + AchievementEvaluator — unit-tested
├── GoalStore.swift             # Daily focus goal + GoalMath progress — unit-tested
├── DailyHistoryStore.swift     # Local per-day focus-minutes history — unit-tested
├── SettingsStore.swift         # Persisted timer preferences — unit-tested
├── AppearanceSettings.swift    # Accent themes + light/dark/system appearance — unit-tested
├── SessionStore.swift          # Crash/quit session recovery — unit-tested
├── PendingCommandStore.swift   # Queues widget/intent commands for the app — unit-tested
├── MotivationalContent.swift   # Motivational copy for the focus-lock fallback — unit-tested
├── SharedSessionState.swift    # App-Group state shared with the widget — unit-tested
├── AppLockManager.swift        # Focus-mode locking (motivational + Screen Time)
├── ScreenTimeController.swift  # Real FamilyControls shielding, entitlement-gated
├── NotificationActions.swift   # Completion-notification actions (e.g. "Extend +5 min")
├── PomodoroIntents.swift       # App Intents: Start Focus / Check Streak (Siri & Shortcuts)
├── Haptics.swift               # Haptic feedback helper
├── Logging.swift               # Debug logging that compiles out of Release builds
│
│   # ── Live Activity & backend ─────────────────────────────────
├── TimerActivityAttributes.swift # Live Activity attributes (shared)
├── LiveActivityController.swift  # Starts/updates/ends the Live Activity
└── FirebaseManager.swift         # Firestore integration (leaderboard backend)

PomodoroWidget/                 # Separate target (WidgetKit + ActivityKit)
├── PomodoroWidgetBundle.swift  # Widget bundle entry point
├── PomodoroWidget.swift        # Home/Lock-screen WidgetKit widget
├── PomodoroLiveActivity.swift  # Live Activity / Dynamic Island UI
└── PomodoroControl.swift       # Control Center "Start Focus" control (iOS 18)

pomadoro2Tests/                 # Swift Testing unit tests (~95 cases)
pomadoro2UITests/               # XCUITest smoke tests
scripts/check-coverage.sh       # Coverage gate for the pure-logic files
firestore.rules                 # Least-privilege Firestore security rules
.github/workflows/ci.yml        # SwiftLint + build + test + coverage on every push / PR
```

## Getting started

1. Open `pomadoro2.xcodeproj` in Xcode.
2. The project uses Firebase for the leaderboard. To run with your own backend, create a Firebase project and replace `pomadoro2/GoogleService-Info.plist` with your own config.
3. Build and run on a simulator or device.

> The core timer, stats, goals, achievements, history charts, themes, and leaderboard run out of the box. The **widget, Live Activity, Control Center control, Siri/Shortcuts intents, and Screen Time blocking** each need a one-time Xcode target and entitlement step — see [docs/WIDGET_SETUP.md](docs/WIDGET_SETUP.md) (widget / Live Activity / Control Center / App Intents) and [docs/SCREEN_TIME_SETUP.md](docs/SCREEN_TIME_SETUP.md) (Family Controls).

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

- **Unit tests** ([`pomadoro2Tests`](pomadoro2Tests)) — ~95 cases with the [Swift Testing](https://developer.apple.com/documentation/testing) framework cover the business logic: timer formatting/progress and the deadline countdown (`TimerMath`), the timer **state machine** (`TimerState`), short-/long-break cycles (`BreakPolicy`), streak transitions (`StreakCalculator`), stats accumulation/merge (`StatsStore`), settings persistence (`SettingsStore`), theme/appearance (`AppearanceSettings`), daily goals (`GoalStore`), focus-history aggregation (`DailyHistoryStore`), achievement evaluation (`Achievements`), pending widget/intent commands (`PendingCommandStore`), shared widget state (`SharedSessionState`), and crash/quit recovery (`SessionStore`). All time-dependent logic takes an injected clock so tests are deterministic.
- **Testable timer engine** — `TimerManager` itself is exercised by tests via **dependency injection**: it accepts a protocol-backed backend, so a mock stands in for Firebase and the full session-orchestration flow can be asserted without a network or device.
- **UI smoke tests** ([`pomadoro2UITests`](pomadoro2UITests)) verify the app launches to the timer screen and that starting a session shows the running timer.
- Every push and pull request runs **SwiftLint**, the build, the unit suite, and a **code-coverage gate** (on the pure-logic files, discovered by naming convention) on an iOS Simulator via [GitHub Actions](.github/workflows/ci.yml).

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
