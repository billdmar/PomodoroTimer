# Architecture

This document describes how the Pomodoro Timer app is structured and how its
pieces fit together. Every claim below is grounded in the Swift source under
[`pomadoro2/`](../pomadoro2) and [`PomodoroWidget/`](../PomodoroWidget). It is
meant as an orientation guide for anyone reading or extending the code.

## Overview

The app is a SwiftUI iOS application following an MVVM-ish shape: SwiftUI
`View`s observe a single `@MainActor` `ObservableObject` facade
(`TimerManager`) that holds the user-facing mutable state. The interesting
design choices are:

- **The wall clock is the source of truth.** The countdown is *deadline-based*:
  a running session stores its `endDate`, and `timeRemaining` / `isRunning` are
  *derived* from an explicit `TimerState` enum. A lightweight async refresh loop
  drives the UI only — it is not the clock — which is what makes the timer
  immune to background suspension and tick drift. This clock is encapsulated in
  **`SessionEngine`** (a small `@MainActor` type that owns the `TimerState` + the
  tick and reports via `onTick` / `onFinished`); `TimerManager` orchestrates
  around it but no longer contains the timing machinery, so the safety-critical
  countdown logic is small and independently testable.
- **Pure logic and persistence are split out of the facade.** All deterministic
  rules (time math, streaks, stats accumulation, break cadence, achievements,
  goals, history aggregation) live in side-effect-free `enum`/`struct` types,
  and all persistence lives in small stores that take an *injected*
  `UserDefaults`. `TimerManager` itself takes dependency injection (a
  `StatsBackend`, a `UserDefaults`, and an `enableExternalServices` flag), so
  its state machine is unit-testable without touching Firebase, notifications,
  or Live Activities.
- **Out-of-process surfaces talk to the app through a shared App Group.** App
  Intents / Siri, the Control Center control, the widget, and the Live Activity
  run in separate processes and communicate via the App Group suite
  (`PendingCommandStore` for commands in, `SharedSessionState` for state out).

| Layer | Types | Responsibility |
| --- | --- | --- |
| App entry | `pomadoro2App`, `AppDelegate` | Configure Firebase, register notification actions, host the root view |
| Views | `ContentView`, `SettingsView`, `StatsView`, `LeaderboardView`, `WelcomeView`, plus extracted components (`ProgressRingView`, `DynamicBackgroundView`, `TimerComponents`, `HistoryChartView`, `AchievementOverlay`, `TomatoButton`, `StarParticlesView`) | Presentation, animation, user input |
| Facade / view model | `TimerManager` (`@MainActor`), `FirebaseManager`, `EnhancedAppLockManager` (aliased `AppLockManager`) | Orchestration, OS integration, networking |
| Timer engine | `SessionEngine` (`@MainActor`) | Owns the `TimerState` machine + UI tick; reports via `onTick` / `onFinished` |
| Pure logic | `TimerMath`, `StreakCalculator`, `StatsCalculator`, `BreakPolicy`, `AchievementEvaluator`, `GoalMath`, `HistoryAggregator`, `SessionRecovery` | Deterministic, unit-tested helpers |
| State model | `TimerState` (+ `TimerConstants`), `StatsState`, `SessionSnapshot`, `SharedSessionState`, `PendingCommand` | Value types the logic and stores operate on |
| Persistence | `SettingsStore`, `SessionStore`, `StatsPersistence`, `GoalStore`, `DailyHistoryStore`, `AppearanceSettingsStore`, `SharedSessionStore`, `PendingCommandStore` | Load/save to injectable `UserDefaults` (some via the App Group suite) |
| OS surfaces | `LiveActivityController`, `ScreenTimeController`, `NotificationActions`, `PomodoroIntents` | Live Activity, Screen Time shielding, interactive notifications, App Intents |
| Design system | `DesignTokens`, `CardModifiers` (`.cardStyle()`) | Centralized palette/typography/spacing/radius/shadow/animation |
| Widget extension | `PomodoroWidget`, `PomodoroLiveActivity`, `PomodoroControl`, `PomodoroWidgetBundle` | Home/Lock-screen widget, Live Activity UI, Control Center control |
| Utility | `Log`, `Haptics`, `MotivationalContent` | Debug-only logging, haptics, copy |
| Backend | Firestore + `firestore.rules` | Persisted stats, focus-session log, global leaderboard |

## Component & data-flow diagram

```
                         ┌───────────────────────────────────┐
                         │            pomadoro2App            │
                         │  @UIApplicationDelegateAdaptor      │
                         │  AppDelegate.didFinishLaunching:     │
                         │   FirebaseApp.configure()           │
                         │   NotificationActions.register…     │
                         └────────────────┬────────────────────┘
                                          │ hosts
                                          ▼
                         ┌───────────────────────────────────┐
                         │             ContentView             │
                         │  @StateObject TimerManager           │
                         │  Welcome → main ↔ full-screen        │
                         │  .onChange(scenePhase) → recompute    │
                         └──┬──────────────┬───────────────┬───┘
        .sheet              │              │               │  reads progress / time / mode
   ┌────────────────────────┘              │               └────────────────┐
   ▼                                        ▼                                 ▼
┌───────────────┐   ┌────────────────────────────────────────┐    ┌────────────────────┐
│ SettingsView  │   │           TimerManager (@MainActor)      │    │ AppLockOverlay /    │
│ durations,    │──▶│  facade — DI: StatsBackend, UserDefaults, │◀──▶│ EnhancedAppLock     │
│ emoji, theme, │   │  enableExternalServices                   │lock│ Manager + ScreenTime│
│ sound, goal   │   │  @Published isRunning, timeRemaining …    │    │ (nudges + shielding)│
├───────────────┤   │                                            │    └────────────────────┘
│  StatsView    │◀──│  private let engine: SessionEngine ───────┐│
│ goal ring,    │   │   owns TimerState .idle/.running/.paused  ││
│ streak cal,   │   │   + tick (0.25s) → onTick / onFinished    ◀┘│
│ achievements, │   │  delegates to pure logic + stores …        │
│ history chart │   └───┬──────────┬──────────┬──────────┬───────┘
├───────────────┤       │          │          │          │
│LeaderboardView│◀──────┘ logic    │ stores   │ OS        │ App Group
└──────┬────────┘  StatsCalculator │ Settings │ Live      │ PendingCommandStore (in)
       │           StreakCalc      │ Session  │ Activity  │ SharedSessionStore  (out)
       │ leaderboard()             │ Stats    │ ScreenTime │        ▲          │
       ▼                           │ Goal     │ Notif.     │        │          ▼
┌───────────────────────────┐      │ History  │            │   ┌─────────────────────────┐
│  FirebaseManager           │      │ Appearance            │   │ App Intents / Siri /     │
│  : StatsBackend (async)    │      └──────────┘            │   │ Control Center / Widget  │
│  Auth (anon), Firestore,   │                              │   │ + Live Activity render   │
│  NWPathMonitor (isOnline)  │                              │   └─────────────────────────┘
└────────────┬───────────────┘
             │ read / write
             ▼
┌───────────────────────────────┐
│   Firebase Cloud Firestore     │
│  userStats/{uid}  (public read)│
│  focusSessions/* (create-only) │
│   guarded by firestore.rules   │
└───────────────────────────────┘
```

## App entry & structure

`pomadoro2App` ([`pomadoro2App.swift`](../pomadoro2/pomadoro2App.swift)) is the
`@main` SwiftUI `App`. It registers an `AppDelegate` via
`@UIApplicationDelegateAdaptor`; the delegate's
`application(_:didFinishLaunchingWithOptions:)` calls `FirebaseApp.configure()`,
installs `NotificationActionHandler.shared` as the notification-center delegate,
and registers the interactive completion category (`NotificationActions
.registerCategories()`). The single `WindowGroup` hosts `ContentView`.

`ContentView` ([`ContentView.swift`](../pomadoro2/ContentView.swift)) owns the
app's only `@StateObject TimerManager` and drives top-level UI state. It renders
one of several states:

- A multi-step **`WelcomeView`** onboarding flow on first appearance, skipped
  when launched with the `-skipWelcome` argument (used by UI tests to land
  deterministically on the timer).
- The **`mainTimerView`** (idle/paused): header, three `QuickStatCard`s, the
  `ProgressRingView`, and a row of `ControlButton`s (reset, skip/switch,
  leaderboard, settings).
- The **`fullScreenTimerView`** (running): an immersive view over
  `DynamicBackgroundView`, with an encouraging message, large monospaced time,
  the progress ring around the current emoji, mode indicator, and floating
  Restart/Skip buttons.

It wires `.sheet`s for `SettingsView`, `StatsView`, and `LeaderboardView`, a
`-screen settings|leaderboard|stats` deep-link launch argument (for
deterministic screenshots/tests), and — importantly — an
`.onChange(of: scenePhase)` that forwards the new phase to
`TimerManager.handleScenePhase(_:)` (the foreground recompute / background
snapshot hook described below). A `#if DEBUG` overlay exposes a "🐛" panel that
calls the `TimerManager` debug methods.

`ContentView` renders the tomato/emoji inline and starts the timer by tapping
the ring. `TomatoButton` ([`TomatoButton.swift`](../pomadoro2/TomatoButton.swift))
and `StarParticlesView` are fully implemented, reusable components but are not
the live tap target in the current screen composition.

## Timer engine: deadline-based state machine

This is the core of the app and the part that changed most. The countdown is
modeled as an explicit state machine in
[`TimerState.swift`](../pomadoro2/TimerState.swift):

```swift
enum TimerState: Equatable {
    case idle(remaining: TimeInterval)   // stopped, ready to start
    case running(endDate: Date)          // counting down toward a wall-clock deadline
    case paused(remaining: TimeInterval) // frozen mid-session
}
```

The previous design combined an `endDate: Date?` with a separate `isRunning`
flag, which allowed contradictory states. The enum makes illegal states
unrepresentable, and crucially **a running session stores only its `endDate`**.
Everything visible is derived from it:

- `state.remaining(now:)` computes seconds left from the wall clock when
  running (delegating to `TimerMath.remaining(until:now:)`), or returns the
  stored value when idle/paused.
- `state.hasCompleted(now:)` is simply `now >= endDate`
  (`TimerMath.hasCompleted(endDate:now:)`).

**`SessionEngine`** ([`SessionEngine.swift`](../pomadoro2/SessionEngine.swift))
owns `state: TimerState` and the tick. `TimerManager` holds the engine and
mirrors its reports into the `@Published var timeRemaining` / `isRunning` the
views bind to — those are recomputed from the deadline, never decremented.

### Why this is background-safe

The engine's tick — a single `Task` sleeping `TimerConstants.tickInterval`
(0.25s) between iterations — only calls `recompute()` to refresh `timeRemaining`
for a smooth ring. It is explicitly **not** the clock. Because completion is
decided by `Date >= endDate`, a delayed, throttled, or entirely skipped tick
(e.g. while the app is suspended in the background) never loses or gains time:

- `SessionEngine.recompute()` recomputes remaining from `state` and, if the
  deadline has passed, leaves the running state and fires `onFinished`, which
  `TimerManager` handles in `timerCompleted()`. It is the single completion
  path, shared by the tick and by foreground/recovery.
- `TimerManager.handleScenePhase(_:)` calls `recompute()` on `.active`
  (recovering any time that elapsed while suspended, completing the session if
  its deadline passed) and persists a `SessionSnapshot` on `.background`.

`TimerConstants` ([`TimerState.swift`](../pomadoro2/TimerState.swift)) names the
tunables (default focus 25m / break 5m / long break 15m, the 0.25s tick, the
completion-notification id) rather than scattering magic numbers.

### Lifecycle operations

- **`startTimer()`** anchors `endDate = now + timeRemaining`, sets
  `state = .running(endDate:)`, locks the app during focus mode (and lazily
  requests Screen Time authorization), snapshots the session, publishes shared
  state to the App Group, schedules a completion notification, starts the Live
  Activity, and starts the tick.
- **`pauseTimer()`** freezes `timeRemaining` from `state` directly (not via
  `recompute()`, so pausing never accidentally triggers completion), moves to
  `.paused`, stops the tick, unlocks, snapshots, and cancels the notification /
  ends the Live Activity.
- **`timerCompleted()`** pauses, plays the chosen completion sound + haptic,
  unlocks, and — only for a completed *focus* session — records stats, appends
  to the daily history, decides whether the next break is long
  (`BreakPolicy`), and logs the session to the backend. It then flips
  `isFocusMode` and moves to `.idle` with the next mode's duration.
- **`resetTimer()` / `restartCurrentTimer()` / `switchMode()` / `skipTimer()`**
  behave as their names suggest, always re-deriving the idle remaining from the
  active mode's duration.
- **`extend(byMinutes:)`** adds time to a running, paused, or idle session
  (re-anchoring the deadline and rescheduling the notification / Live Activity
  when running). It is wired to the notification's "Extend +5 min" action via
  `NotificationActions.extendRequested`.

`TimerMath` ([`TimerMath.swift`](../pomadoro2/TimerMath.swift)) holds the pure
helpers: `formattedTime` (`mm:ss`, **rounds up** so a deadline countdown shows a
whole `25:00` at the start rather than flashing `24:59`), `progress`,
`normalizedEmoji`, and the `remaining`/`hasCompleted` deadline primitives.

### Customizable settings

`SettingsView` ([`SettingsView.swift`](../pomadoro2/SettingsView.swift)) exposes
focus/break/long-break durations, focus/break emoji editors, accent **theme**,
**appearance mode** (light/dark/system), and **completion sound**.
Duration/emoji changes go through
`TimerManager.updateSettings(focusMinutes:breakMinutes:focusEmoji:breakEmoji:longBreakMinutes:)`,
which persists via `SettingsStore` and live-updates the idle remaining when the
timer isn't running. Theme/appearance/sound go through `updateAppearance(...)`
(persisted via `AppearanceSettingsStore`); the daily goal is set from
`StatsView` via `setDailyGoal(minutes:)` (persisted via `GoalStore`).

## Dependency injection & testability

`TimerManager` is an `@MainActor ObservableObject`. Its designated initializer is

```swift
init(firebaseManager: FirebaseManager = FirebaseManager(),
     backend: StatsBackend? = nil,
     defaults: UserDefaults = .standard,
     enableExternalServices: Bool = true)
```

All dependencies default to production, so `TimerManager()` just works for the
app. Tests inject a **mock `StatsBackend`**, an **isolated `UserDefaults`
suite**, and `enableExternalServices: false`. When external services are
disabled, Firebase auth/sync, notification-permission prompts, and Live Activity
calls are skipped, so the state machine runs in pure isolation and its
transitions can be asserted deterministically.

Internally `TimerManager` constructs the persistence stores from the injected
`defaults` and delegates all rules to the pure logic types — it is a facade, not
a monolith.

## Pure logic + persistence split

**Pure logic** (no UIKit, no persistence; `now`/`calendar` are injected for
deterministic tests):

- `TimerMath` — time formatting, progress, deadline math.
- `StreakCalculator` ([`StreakCalculator.swift`](../pomadoro2/StreakCalculator.swift)) —
  day-boundary streak rules + `isActiveDay(...)` for the streak calendar.
- `StatsCalculator` (in [`StatsStore.swift`](../pomadoro2/StatsStore.swift)) —
  new-day reset, applying a completion, and multi-device `merging` (field-wise
  `max`, with the later `lastCompletionDate` winning).
- `BreakPolicy` ([`BreakPolicy.swift`](../pomadoro2/BreakPolicy.swift)) —
  long break every Nth focus session (default 4).
- `AchievementEvaluator` ([`Achievements.swift`](../pomadoro2/Achievements.swift)) —
  the badge catalog + `evaluate` / `newlyUnlocked` from a `StatsState`.
- `GoalMath` (in [`GoalStore.swift`](../pomadoro2/GoalStore.swift)) — daily-goal
  progress fraction + `isMet`.
- `HistoryAggregator` (in [`DailyHistoryStore.swift`](../pomadoro2/DailyHistoryStore.swift)) —
  windowed per-day focus totals for the charts.
- `SessionRecovery` (in [`SessionStore.swift`](../pomadoro2/SessionStore.swift)) —
  decides resume/expired/none for an interrupted session from elapsed wall time.

**Persistence stores** (each takes an injectable `UserDefaults`):

- `SettingsStore` — durations + emoji + long-break length.
- `SessionStore` — `SessionSnapshot` for crash/quit recovery.
- `StatsPersistence` — the `StatsState` fields.
- `GoalStore` — daily goal minutes.
- `DailyHistoryStore` — JSON day→minutes map for the history charts.
- `AppearanceSettingsStore` — accent / appearance / sound.
- `SharedSessionStore` and `PendingCommandStore` — write to the **App Group**
  suite (`SharedConfig.defaults`, falling back to `.standard` until the App
  Group is configured) so the widget and out-of-process intents can see them.

`StatsState` is the value model `StatsCalculator` / `StatsPersistence` operate
on; `TimerManager` exposes it via a private `statsState` get/set that bridges
the individual `@Published` fields the views bind to.

## Backend

`FirebaseManager` ([`FirebaseManager.swift`](../pomadoro2/FirebaseManager.swift))
is the only networking layer and now conforms to a `StatsBackend` protocol:

```swift
protocol StatsBackend: AnyObject {
    func saveUserStats(focusMinutes: Int, totalMinutes: Int, streak: Int) async
    func loadUserStats() async -> StatsState?
    func leaderboard(limit: Int) async -> [LeaderboardEntry]
    func logFocusSession(duration: Int, completedAt: Date) async
}
```

The protocol is `async/await` throughout, so `TimerManager` depends on the
abstraction and tests can substitute an in-memory mock. `FirebaseManager` wraps
Firebase Auth and Firestore, tracks connectivity with `NWPathMonitor`
(`isOnline`), and short-circuits all reads/writes when offline. Authentication
is **anonymous**: `setupFirebase()` signs in silently at launch and re-syncs on
auth change; `LeaderboardView`'s "Join Anonymously" button signs in with
`userInitiated: true` so failures surface a friendly message.

### Data model (Firestore)

- **`userStats/{uid}`** — one document per user. Fields: `userId`,
  `todayFocusMinutes`, `totalFocusMinutes`, `currentStreak`, `lastUpdated`
  (`serverTimestamp`), `lastCompletionDate`. Written with `merge: true`.
- **`focusSessions/*`** — append-only log, one document per completed focus
  session: `userId`, `duration` (minutes), `completedAt`, `timestamp`. The
  client only ever *writes* this collection.

### Multi-device sync

On completion, `TimerManager` calls `logFocusSession(...)` then `syncWithFirebase()`,
which `saveUserStats(...)` (upsert), `loadUserStats(...)` (pull), and reconciles
local vs. remote via `StatsCalculator.merging(...)` — **field-wise `max` plus the
latest completion date** — so the streak math never recalculates against a stale
local date.

`getLeaderboard` / `leaderboard(limit:)` queries `userStats` ordered by
`totalFocusMinutes` descending, mapping each document into a `LeaderboardEntry`
(which derives an anonymous `displayName` and a human `formattedMinutes`).
`LeaderboardView` ([`LeaderboardView.swift`](../pomadoro2/LeaderboardView.swift))
renders ranked rows with pull-to-refresh, prompting to join when unauthenticated.

### Security rules

[`firestore.rules`](../firestore.rules) is the real access-control boundary (not
the bundled client config) and enforces least privilege:

- `userStats/{userId}`: **public read** (so any client can render the board);
  **write only by the authenticated owner** (`request.auth.uid == userId`) and
  only when the numeric fields validate as non-negative ints.
- `focusSessions/{sessionId}`: **create-only** by the authenticated owner, with
  `duration` validated as an int in `0...1440`; **no read/update/delete** — this
  is why the history charts read from the local `DailyHistoryStore` rather than
  querying the collection back.
- A catch-all `match /{document=**}` denies everything else.

## Feature subsystems

- **Long-break cadence** — `BreakPolicy` decides a long break after every Nth
  focus session (default 4), using today's completed-session count. The next
  break's length is `longBreakDuration` vs. `breakDuration` accordingly.
- **Achievements** — `AchievementEvaluator.catalog` defines milestone badges
  (first session, 5/day, 7- and 30-day streaks, 100 sessions, 1000 minutes)
  with conditions over `StatsState`; `StatsView` renders `evaluate(...)`.
- **Daily goal + history charts** — `GoalStore`/`GoalMath` drive the goal ring;
  `DailyHistoryStore`/`HistoryAggregator` feed a Swift Charts bar chart
  (`HistoryChartView`, `import Charts`) for the recent-days view. `StatsView`
  also shows the Duolingo-style streak calendar (`CompactStreakCalendarView`)
  shaded via `StreakCalculator.isActiveDay`, so the calendar and the streak
  badge can never disagree.
- **Themes & sound** — `AppearanceSettings` defines `AccentTheme`,
  `AppearanceMode`, and `CompletionSound` (each mapping to a system sound id or
  silent), persisted via `AppearanceSettingsStore`.
- **Out-of-process surfaces** — App Intents / Siri (`PomodoroIntents`:
  `StartFocusSessionIntent`, `CheckStreakIntent`, `PomodoroShortcuts`) and the
  iOS 18 Control Center control (`PomodoroControl`) run in separate processes,
  so they **post a `PendingCommand`** into the App Group mailbox and open the
  app; `TimerManager.consumePendingCommand()` applies it on activation. The
  query intent reads the shared state / stats directly so it can answer without
  launching. Live state flows outward through `SharedSessionState` /
  `SharedSessionStore`, and `publishSharedState()` reloads the widget timelines.
- **Live Activity** — `LiveActivityController` starts/updates/ends a
  `TimerActivityAttributes` activity; all ActivityKit calls are gated on iOS
  16.1+ and on activities being enabled, so it is a safe no-op otherwise. The
  widget extension renders it (`PomodoroLiveActivity`), including the Dynamic
  Island, which only appears on devices that have it.
- **Focus-mode lock + Screen Time** — `EnhancedAppLockManager` (aliased
  `AppLockManager`) provides the in-app retention nudge (escalating "return to
  focus" notifications, idle-timer disable, the `AppLockOverlay`). For *real*
  system-level blocking it delegates to `ScreenTimeController`
  (`FamilyControls`/`ManagedSettings`). **This is entitlement-gated:** the
  frameworks compile and link without the `com.apple.developer.family-controls`
  entitlement, but authorization only succeeds at runtime on a device that has
  the Apple-approved entitlement — otherwise it degrades gracefully to the
  motivational nudges only (`NoopScreenTimeController`).

## Design system

`DesignTokens` ([`DesignTokens.swift`](../pomadoro2/DesignTokens.swift))
centralizes the palette (focus/break gradients), typography scale, spacing,
corner radii, shadow, and animation timings that were previously hardcoded
inline (the gradient RGB tuples alone were repeated six times). `CardModifiers`
([`CardModifiers.swift`](../pomadoro2/CardModifiers.swift)) defines the standard
card surface once as a `.cardStyle()` view modifier. The old ~1030-line
`ContentView` has been decomposed: `ProgressRingView`, `DynamicBackgroundView`,
the `QuickStatCard`/`ControlButton`/`FloatingButton` components in
`TimerComponents`, `WelcomeView`, and `HistoryChartView` are all extracted, so
`ContentView` focuses on layout/state orchestration.

## Build, test & tooling

- **Unit tests** (`pomadoro2Tests`, 100+ [Swift Testing](https://developer.apple.com/documentation/testing)
  `@Test` cases across `TimerStateTests`, `TimerManagerTests`, `StatsStoreTests`,
  `SessionRecoveryTests`, `SettingsStoreTests`, `AchievementsAndBreaksTests`,
  `GoalsAndHistoryTests`, `AppearanceSettingsTests`, `PendingCommandStoreTests`,
  `SharedSessionStateTests`, `StatsBackendTests`, and `pomadoro2Tests`) cover the
  pure logic and the `TimerManager` state machine via DI + a mock backend — no
  Firebase, notifications, or Live Activities are constructed.
- **UI tests** (`pomadoro2UITests`) are launch/smoke tests driven by the
  `-skipWelcome` / `-screen` launch arguments. They run locally (⌘U) but are
  excluded from CI, where headless simulators flakily fail to acquire UI
  background assertions.
- **Coverage gate** — [`scripts/check-coverage.sh`](../scripts/check-coverage.sh)
  enforces an 80% line-coverage floor on the *logic* files only. It
  **auto-discovers** gated files by naming convention (suffixes like `Math`,
  `Calculator`, `Store`, `State`, `Policy`, `Evaluator`, `Recovery`,
  `Achievements`, `Settings`, `Content`), so a new logic file can't silently
  bypass the gate; a file opts out with a `// coverage:ignore-file` marker. A
  discovered logic file with no coverage rows fails the gate.
- **CI** ([`.github/workflows/ci.yml`](../.github/workflows/ci.yml)) runs two
  jobs on `macos-15`: a **SwiftLint** job (errors block, warnings are a signal)
  and a **build-and-test** job that builds + runs `pomadoro2Tests` on an iOS
  Simulator with code coverage, then runs the coverage gate. Screen Time
  compiles fine here because the entitlement is only checked at runtime.
- `Log` ([`Logging.swift`](../pomadoro2/Logging.swift)) forwards to `print` in
  DEBUG and compiles to nothing in Release.
