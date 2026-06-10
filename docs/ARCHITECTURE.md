# Architecture

This document describes how the Pomodoro Timer app is structured and how its
pieces fit together. Every claim below is grounded in the Swift source under
[`pomadoro2/`](../pomadoro2). It is meant as an orientation guide for anyone
reading or extending the code.

## Overview

The app is a single-screen SwiftUI iOS application following an MVVM-ish shape:
SwiftUI `View`s observe a small set of `ObservableObject` "managers" that hold
all mutable state and side effects. Pure, side-effect-free logic (time
formatting, progress fraction, streak math) is factored out into plain `enum`
namespaces so it can be unit-tested without constructing the Firebase-backed
managers.

| Layer | Types | Responsibility |
| --- | --- | --- |
| App entry | `pomadoro2App`, `AppDelegate` | Configure Firebase, host the root view |
| Views | `ContentView`, `SettingsView`, `StatsView`, `LeaderboardView`, `TomatoButton`, `StarParticlesView` | Presentation, animation, user input |
| View models / managers | `TimerManager`, `EnhancedAppLockManager` (aliased `AppLockManager`), `FirebaseManager` | Mutable state, timers, OS integration, networking |
| Pure logic | `TimerMath`, `StreakCalculator` | Deterministic, unit-tested helpers |
| Utility | `Log` | Debug-only logging that compiles out of Release |
| Backend | Firestore + `firestore.rules` | Persisted stats, focus-session log, global leaderboard |

## Component & data-flow diagram

```
                         ┌──────────────────────────────┐
                         │        pomadoro2App           │
                         │  @UIApplicationDelegateAdaptor │
                         │  AppDelegate.didFinishLaunching│
                         │   → FirebaseApp.configure()    │
                         └───────────────┬───────────────┘
                                         │ hosts
                                         ▼
                         ┌──────────────────────────────┐
                         │          ContentView          │
                         │  @StateObject TimerManager     │
                         │  Welcome → main ↔ full-screen  │
                         └───┬───────────┬───────────┬───┘
            .sheet           │           │           │  reads progress / time / mode
        ┌────────────────────┘           │           └───────────────┐
        ▼                                ▼                            ▼
┌───────────────┐   ┌──────────────────────────────┐      ┌────────────────────┐
│ SettingsView  │   │         TimerManager          │      │ AppLockOverlay /    │
│ 1–60 / 1–30   │──▶│  @Published isRunning,         │◀────▶│ EnhancedAppLock     │
│ sliders,emoji │   │  timeRemaining, isFocusMode,   │ lock │ Manager             │
└───────────────┘   │  durations, local stats        │      │ (bg/fg observers,   │
┌───────────────┐   │  Timer (1 Hz) ─ TimerMath      │      │  return notifs)     │
│  StatsView    │◀──│  StreakCalculator (streak)     │      └────────────────────┘
│ streak cal.   │   └───────────────┬───────────────┘
└───────────────┘                   │ on focus-session complete
┌───────────────┐                   ▼
│LeaderboardView│         ┌──────────────────────────────┐
│ top-N board   │◀───────▶│        FirebaseManager        │
└───────────────┘ getLB   │  Auth (anon), Firestore I/O,   │
                          │  NWPathMonitor (online state)  │
                          └───────────────┬───────────────┘
                                          │ read / write
                                          ▼
                          ┌──────────────────────────────┐
                          │   Firebase Cloud Firestore     │
                          │  userStats/{uid}  (public read)│
                          │  focusSessions/* (append-only) │
                          │   guarded by firestore.rules   │
                          └──────────────────────────────┘
```

## App entry & structure

`pomadoro2App` ([`pomadoro2App.swift`](../pomadoro2/pomadoro2App.swift)) is the
`@main` SwiftUI `App`. It registers an `AppDelegate` via
`@UIApplicationDelegateAdaptor`; the delegate's
`application(_:didFinishLaunchingWithOptions:)` calls
`FirebaseApp.configure()` so Firebase is initialized before any view appears.
The single `WindowGroup` hosts `ContentView`.

`ContentView` ([`ContentView.swift`](../pomadoro2/ContentView.swift)) owns the
app's only `@StateObject TimerManager` and drives all top-level UI state. It
renders one of several states:

- A multi-step **`WelcomeView`** onboarding flow shown on first appearance.
  It is skipped when the process is launched with the `-skipWelcome` argument,
  which the UI tests use to land deterministically on the timer screen.
- The **`mainTimerView`** (idle/paused state): header, three `QuickStatCard`s
  (today's focus, day streak, total minutes), the progress-ring timer, and a
  row of `ControlButton`s (reset, skip/switch, leaderboard, settings).
- The **`fullScreenTimerView`** (running state): an immersive view with an
  encouraging message, large monospaced time, the progress ring around the
  current emoji, mode indicator, and floating Restart/Skip buttons.

`ContentView` also wires up `.sheet`s for `SettingsView`, `StatsView`, and
`LeaderboardView`, and a `.onAppear` deep-link handler: a `-screen
settings|leaderboard|stats` launch argument opens the corresponding sheet
(used for deterministic screenshots/tests). A `#if DEBUG` overlay exposes a
"🐛" debug panel with buttons that call the `TimerManager` debug methods.

Note: `TomatoButton` ([`TomatoButton.swift`](../pomadoro2/TomatoButton.swift))
exists and is fully implemented (button + star burst on tap), but the live
`ContentView` renders the tomato/emoji inline rather than embedding
`TomatoButton`. `TomatoButton` is effectively a standalone/alternate component
in the current screen composition — see "Interactive tomato & particles" below.

## Timer state machine

All timer state lives in `TimerManager`
([`TimerManager.swift`](../pomadoro2/TimerManager.swift)), an `ObservableObject`.
Key `@Published` state: `isRunning`, `timeRemaining` (`TimeInterval`),
`isFocusMode`, `isLocked`, plus the configurable `focusDuration` (default
`25 * 60`) and `breakDuration` (default `5 * 60`).

The session is a two-state machine — **focus** and **break** — tracked by the
`isFocusMode` boolean:

- **`startTimer()`** invalidates any existing timer, sets `isRunning = true`
  and `isLocked = true`, picks a random encouraging message, and — only when
  `isFocusMode` is true — calls `appLockManager.lockApp()`. It then schedules a
  repeating 1-second `Timer` that decrements `timeRemaining`; when it reaches 0
  it calls `timerCompleted()`.
- **`pauseTimer()`** clears `isRunning`/`isLocked`, invalidates the timer, and
  calls `appLockManager.unlockApp()`.
- **`timerCompleted()`** pauses, builds a completion message, plays a system
  sound (`AudioServicesPlaySystemSound(1005)`), sends a local notification,
  unlocks the app, and — **only if the completed session was a focus session** —
  records stats locally and logs the session to Firebase. It then flips
  `isFocusMode` and sets `timeRemaining` to the next mode's duration. This is
  the focus ↔ break transition.
- **`switchMode()`** pauses, toggles `isFocusMode`, and resets `timeRemaining`
  to the new mode's duration (no auto-start).
- **`skipTimer()`**: if running, pauses, toggles mode, resets the time, and
  immediately starts again; if not running, it calls `timerCompleted()`.
- **`resetTimer()`** pauses and resets `timeRemaining` to the current mode's
  full duration. **`restartCurrentTimer()`** pauses, resets, and restarts.

Derived values are delegated to the pure `TimerMath` enum
([`TimerMath.swift`](../pomadoro2/TimerMath.swift)):

- `formattedTime` → `TimerMath.formattedTime`, which renders `mm:ss` and clamps
  negatives to zero.
- `progress` → `TimerMath.progress(timeRemaining:total:)`, the elapsed fraction
  in `0...1`, guarded against division by zero.

### Customizable durations (1–60 / 1–30)

`SettingsView` ([`SettingsView.swift`](../pomadoro2/SettingsView.swift)) exposes
two sliders: **focus duration** with range `1...60` (step 1) and **break
duration** with range `1...30` (step 1), plus inline emoji editors capped at two
characters and quick-pick emoji rows. On any change it calls
`TimerManager.updateSettings(focusMinutes:breakMinutes:focusEmoji:breakEmoji:)`,
which multiplies the minute values by 60 into `focusDuration`/`breakDuration`,
normalizes the emoji via `TimerMath.normalizedEmoji` (falling back to 🍅 / 😌
when cleared), and — if the timer isn't currently running — updates
`timeRemaining` live so the displayed time reflects the new setting. "Cancel"
restores the manager's existing values.

## Animated progress ring

The progress ring is a SwiftUI `Circle().trim(from: 0, to: timerManager.progress)`
with a rounded-cap gradient stroke, rotated `-90°` so it fills from the top, and
animated with `.easeInOut`. It appears twice:

- In `mainTimerView`, layered with an outer radial glow and a shadowed
  background circle, with the `mm:ss` time and a mode capsule centered inside.
- In `fullScreenTimerView`, drawn around the central emoji as a white ring over
  a faint track, sized relative to the `GeometryProxy`.

The stroke colors are mode-aware (red/orange gradient for focus, green/mint for
break). The whole running screen also has an animated multi-layer gradient
background (`dynamicColorBackground`) whose gradient anchor points are driven by
a `colorShift` value advanced every 3 seconds via a `Timer.publish`.

## Focus-mode lock

The lock is implemented by `EnhancedAppLockManager`
([`AppLockManager.swift`](../pomadoro2/AppLockManager.swift)), exposed under the
`typealias AppLockManager`. `TimerManager` owns an instance and only locks
during **focus** sessions (`startTimer()` guards on `isFocusMode`).

`lockApp()` sets `isAppLocked`, records a start time, disables the idle timer
(`UIApplication.shared.isIdleTimerDisabled = true`) so the screen won't sleep,
and registers interactive notification categories. The manager observes
`didEnterBackgroundNotification` / `willEnterForegroundNotification`:

- On **background** while locked: it sends an immediate "return to focus"
  notification and schedules escalating follow-up reminders at 30s, 2m, 5m, and
  10m.
- On **foreground** while locked: if the user was away more than ~30 seconds it
  sets `showingUnlockAlert = true` (and increments `unlockAttempts`), then
  cancels pending notifications.

`ContentView` renders `AppLockOverlay` (a blurred "Focus Session Active" prompt
with a "Return to Focus" button) when `isAppLocked && showingUnlockAlert`.
`unlockApp()` clears the lock state, re-enables the idle timer, and removes
pending notifications.

This is an in-app retention/nudge mechanism — it does **not** block other apps
at the OS level. The manager honestly acknowledges this: it also carries some
auxiliary, currently-unsurfaced helpers — a `distractingApps`/`blockedApps`
list with add/remove + `UserDefaults` persistence, a `suggestScreenTimeSetup()`
string pointing users at iOS Screen Time for true system-wide blocking, and
`getMotivationalMessage()` — that are defined but not wired into the live UI.

## Interactive tomato & particle effects

`TomatoButton` ([`TomatoButton.swift`](../pomadoro2/TomatoButton.swift)) is a
tappable tomato/emoji button: on press it scales down slightly, calls
`StarParticlesView`, and starts the timer; stars are hidden again after ~2s.
`StarParticlesView`
([`StarParticlesView.swift`](../pomadoro2/StarParticlesView.swift)) lays out 12
emoji (✨ / ⭐ / 💫) in a ring using trig-based offsets and animates them
outward with scale, opacity, and a 360° rotation, staggered by index.

In the current `ContentView`, the tomato/emoji is rendered inline (a large
`Text(timerManager.currentEmoji)` with spring/scale animation) and the timer is
started by tapping the timer ring; in the running full-screen view, tapping the
emoji pauses, and a long-press toggles a small hover offset. `TomatoButton`
itself is implemented but not the live tap target — treat it as a reusable
component rather than the active button.

## Stats tracking

`TimerManager` keeps local stats: `todayFocusMinutes`, `totalFocusMinutes`,
`currentStreak`, and `lastCompletionDate`, persisted to `UserDefaults`
(`loadLocalStats()` / `saveLocalStats()`). On focus-session completion,
`updateStats(focusMinutesCompleted:)`:

- Resets or accumulates `todayFocusMinutes` depending on whether it's a new
  calendar day (`checkIfNewDay()`).
- Recomputes `currentStreak` via the pure `StreakCalculator.updatedStreak(...)`.
- Adds to `totalFocusMinutes`, stamps `lastCompletionDate`, saves locally, then
  syncs to Firebase.

`StreakCalculator` ([`StreakCalculator.swift`](../pomadoro2/StreakCalculator.swift))
holds the day-boundary logic, separated for testability:
first-ever completion → 1; same calendar day → unchanged; next calendar day →
+1; a gap of two+ days (or clock moving backward) → reset to 1. It also provides
`isActiveDay(...)`, which reconstructs which days are "lit" by treating the most
recent `currentStreak` days ending on `lastCompletion` as active.

`StatsView` ([`StatsView.swift`](../pomadoro2/StatsView.swift)) renders today's
stat cards, a Duolingo-style **streak calendar** (`CompactStreakCalendarView`)
that shades active days using `StreakCalculator.isActiveDay` — so the calendar
and the streak badge can never disagree — and a grid of achievement badges whose
unlock thresholds are derived from `totalFocusMinutes` / `todayFocusMinutes` /
`currentStreak`.

## Firebase Firestore leaderboard

`FirebaseManager` ([`FirebaseManager.swift`](../pomadoro2/FirebaseManager.swift))
is the only networking layer. It wraps Firebase Auth and Firestore and tracks
connectivity with `NWPathMonitor` (`isOnline`); all writes/reads short-circuit
when offline. Authentication is **anonymous**: `TimerManager.setupFirebase()`
calls `signInAnonymously()` at launch (silently — launch failures aren't shown),
while `LeaderboardView`'s "Join Anonymously" button calls it with
`userInitiated: true` so failures surface as a friendly message.

### Data model (Firestore)

- **`userStats/{uid}`** — one document per user, keyed by auth uid. Fields:
  `userId`, `todayFocusMinutes`, `totalFocusMinutes`, `currentStreak`,
  `lastUpdated` (`serverTimestamp`), `lastCompletionDate`. Written with
  `merge: true` by `saveUserStats(...)` and read by `loadUserStats(...)`.
- **`focusSessions/*`** — append-only log, one document per completed focus
  session: `userId`, `duration` (minutes), `completedAt`, `timestamp`
  (`serverTimestamp`). Written by `logFocusSession(duration:completedAt:)`.

### How scores are written and read

- **Write:** on focus-session completion, `TimerManager` calls
  `firebaseManager.logFocusSession(...)` and then `syncWithFirebase()`, which
  calls `saveUserStats(...)` to upsert the user's aggregate `userStats` document.
- **Read (own stats):** `syncWithFirebase()` also calls `loadUserStats(...)` and
  merges remote values via `max(...)` to handle multi-device sync.
- **Read (leaderboard):** `getLeaderboard(limit:)` queries the `userStats`
  collection ordered by `totalFocusMinutes` descending, limited to top-N
  (default 10), mapping each document into a `LeaderboardEntry`
  (`userId`, `totalMinutes`, `streak`, `lastActive`). `LeaderboardEntry`
  derives a `displayName` ("Pomodoro Master " + first 6 chars of the uid, since
  users are anonymous) and a human `formattedMinutes`.

`LeaderboardView` ([`LeaderboardView.swift`](../pomadoro2/LeaderboardView.swift))
shows a "Join the Community!" prompt when unauthenticated, otherwise loads the
board, renders ranked `LeaderboardRow`s (🥇🥈🥉 for the top three, highlighting
the current user), and supports pull-to-refresh.

### Security rules

[`firestore.rules`](../firestore.rules) enforces least privilege and is the real
access-control boundary (not the bundled client config):

- `userStats/{userId}`: **public read** (so any client can render the board);
  **write only by the authenticated owner** (`request.auth.uid == userId`) and
  only when the numeric fields validate as non-negative ints
  (`isValidUserStats`).
- `focusSessions/{sessionId}`: **create-only** by the authenticated owner, with
  `duration` validated as an int in `0...1440`; **no read/update/delete**.
- A catch-all `match /{document=**}` denies everything else.

## Build, test & tooling

- **Unit tests** (`pomadoro2Tests`) target the pure `TimerMath` and
  `StreakCalculator` logic — they don't construct the Firebase-backed managers.
- **UI tests** (`pomadoro2UITests`) are launch/smoke tests that rely on the
  `-skipWelcome` / `-screen` launch arguments handled in `ContentView`.
- `Log` ([`Logging.swift`](../pomadoro2/Logging.swift)) forwards to `print` in
  DEBUG and compiles to nothing in Release, so diagnostics never reach a shipped
  console.
- CI builds and tests on an iOS Simulator on every push/PR
  (`.github/workflows/ci.yml`).
