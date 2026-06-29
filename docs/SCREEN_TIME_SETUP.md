# Screen Time (real app blocking) — entitlement setup

The focus lock can apply **real** system app shields via Apple's Screen Time
frameworks (`FamilyControls` / `ManagedSettings`). The code ships in
`pomadoro2/ScreenTimeController.swift` and is wired into the focus session, but
actual shielding only takes effect once the app has the **Family Controls**
entitlement and the user grants authorization.

## Why it builds without the entitlement
`FamilyControls` / `ManagedSettings` compile and link with no entitlement — the
`com.apple.developer.family-controls` entitlement is only checked at **runtime**
when authorization is requested. So:
- CI (`CODE_SIGNING_ALLOWED=NO`) builds fine.
- On a device without the entitlement, `requestAuthorization()` fails and the
  app **degrades gracefully** to the existing motivational nudges
  (`screenTimeAuthorized` stays `false`).
- `ManagedSettingsStore` / `FamilyActivitySelection` are created **lazily** so
  merely launching the app (before authorization) never traps.

## To enable real shielding
1. Request the **Family Controls (Distribution)** entitlement from Apple:
   https://developer.apple.com/contact/request/family-controls-distribution
2. Once granted, in Xcode add the **Family Controls** capability to the
   `pomadoro2` target (this adds `com.apple.developer.family-controls` to the
   entitlements file, currently empty).
3. Provide a way for the user to pick which apps/categories to block via
   `FamilyActivityPicker`, storing the result into
   `FamilyControlsScreenTimeController.selection`. (The picker UI is left as a
   follow-up; the controller already applies the selection when shielding.)
4. Run on a **physical device** (Family Controls can't be authorized in the
   simulator): start a focus session → grant the authorization prompt → the
   chosen apps are shielded until the session ends.

Until step 1–2 are done, the feature is a safe no-op + the motivational lock.
