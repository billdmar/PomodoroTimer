# Capturing screenshots for the README

The README's Screenshots table expects three PNGs in this `docs/` folder:
`timer.png`, `settings.png`, `leaderboard.png`. Here's how to produce them.

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
| `timer.png` | A running focus session — the animated progress ring + tomato button |
| `settings.png` | The settings screen with the duration controls visible |
| `leaderboard.png` | The leaderboard view (populated if Firebase is configured) |

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
