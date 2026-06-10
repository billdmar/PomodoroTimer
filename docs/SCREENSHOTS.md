# Capturing screenshots for the README

The README's Screenshots tables expect these PNGs in this `docs/` folder:
`home.png`, `timer.png`, `break.png`, `settings.png`, `stats.png`,
`leaderboard.png`, and `skip.png`. Here's how to produce them.

## 1. Install an iOS simulator (one time)
Xcode ▸ **Settings… ▸ Components** (older Xcode: **Platforms**) ▸ download an
**iOS** simulator runtime (~7 GB). Wait for it to finish.

## 2. Run the app
1. Open `pomadoro2.xcodeproj` in Xcode.
2. Pick an **iPhone 16 Pro** simulator in the scheme/destination dropdown
   (a Pro model gives a clean, modern frame).
3. Press **⌘R** to build & run. The timer UI works with no API keys.
   *(The leaderboard needs your Firebase `GoogleService-Info.plist`; if it's
   present the leaderboard populates, otherwise it shows an empty state.)*

## 3. Capture each screen
With the simulator focused, press **⌘S** (File ▸ Save Screen) — it saves a clean,
device-framed PNG to your Desktop. Capture:

| Filename | What to show |
| --- | --- |
| `home.png` | The home screen — stats row, tomato, and the 25:00 timer |
| `timer.png` | A running focus session — the animated progress ring + tomato button |
| `break.png` | A running break session (blue mode) |
| `settings.png` | The settings screen with the duration controls visible |
| `stats.png` | The progress view — today's stats and the streak calendar |
| `leaderboard.png` | The leaderboard view (populated if Firebase is configured) |
| `skip.png` | The focus-mode lock with the "skip session" confirmation |

## 4. Drop them in and push
```bash
# rename the captured PNGs to the names above, then:
cp ~/Desktop/timer.png ~/Desktop/settings.png ~/Desktop/leaderboard.png docs/
git add docs/*.png
git commit -m "docs: add app screenshots"
git push
```
The README table will render them automatically.

> Tip: keep the three images a consistent size/orientation (all portrait) so the
> table row looks even.
