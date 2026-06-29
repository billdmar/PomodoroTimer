# Widget & Live Activity — one-time Xcode setup

The widget and Live Activity **code** is in the repo (`PomodoroWidget/`, plus
`pomadoro2/SharedSessionState.swift`), but a widget extension is a new build
**target**, which must be created in the Xcode GUI — it can't be added reliably
by editing `project.pbxproj` from the command line. These steps wire it up; you
do them once.

## 1. Create the Widget Extension target
1. **File ▸ New ▸ Target… ▸ Widget Extension.**
2. Product Name: **`PomodoroWidget`**. **Check "Include Live Activity"**
   (needed for Phase 8). Uncheck "Include Configuration App Intent."
3. Embed in the **`pomadoro2`** app. When prompted to activate the scheme, do.
4. Set the new target's **iOS Deployment Target to 18.5** (match the app).

Xcode generates a starter `PomodoroWidget` group. Because the project uses
synchronized folders, point the target's folder at the repo's existing
**`PomodoroWidget/`** directory (or move the generated files aside and let the
ones in this repo take over). You want these files compiled by the **widget**
target:
- `PomodoroWidget/PomodoroWidgetBundle.swift`  (the `@main`)
- `PomodoroWidget/PomodoroWidget.swift`
- `PomodoroWidget/PomodoroLiveActivity.swift`  (added in Phase 8)

Delete any duplicate `@main`/sample widget Xcode generated, or the build will
fail with two `@main`.

## 2. Share code with both targets
Add these files to **both** the `pomadoro2` and `PomodoroWidget` target
memberships (File Inspector ▸ Target Membership):
- `pomadoro2/SharedSessionState.swift`
- `pomadoro2/DesignTokens.swift`
- `pomadoro2/TimerActivityAttributes.swift`  (added in Phase 8)

## 3. Add the App Group to BOTH targets
For the `pomadoro2` target **and** the `PomodoroWidget` target:
1. **Signing & Capabilities ▸ + Capability ▸ App Groups.**
2. Add the group: **`group.com.billdmar.pomadoro2`**
   (must exactly match `SharedConfig.appGroupID`).

This writes the App Group into each target's entitlements. Until this is done
the app still runs (it falls back to `.standard` `UserDefaults`), but the widget
won't receive updates.

## 4. (Phase 8) Enable Live Activities
In the **app** target's Info settings add:
- `NSSupportsLiveActivities` = `YES`
  (Build Settings ▸ `INFOPLIST_KEY_NSSupportsLiveActivities = YES`, since the
  project generates its Info.plist).

## 5. Verify
- Build both schemes (`pomadoro2` and `PomodoroWidget`).
- Add the **Pomodoro** widget from the simulator/device gallery (Home screen and
  Lock screen). Start a session in the app → the widget shows the live countdown.
- Live Activity (Phase 8) is best verified on a **physical device** (Dynamic
  Island doesn't render in the simulator the same way).

## Scope note
Live Activities here update from the app while it's foregrounded and end on
completion/pause. Remote (APNs push) updates are out of scope and need an
additional Apple Push entitlement.
