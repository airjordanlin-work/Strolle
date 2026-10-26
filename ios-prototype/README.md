# iOS prototype (Screen Time spike)

A standalone SwiftUI app that shields the apps you pick and lifts the
shield for a timed pass after you answer a gate question. It exists to
test the iOS Screen Time mechanics on a real device ahead of M3. It does
not replace the Flutter app and changes nothing outside this folder.

**Not compiled yet.** This was written without a Mac. Expect a first
round of small compile fixes in Xcode.

## How it works

```
shielded app → shield (ShieldConfiguration)
  "Answer a question" → ShieldAction writes a request to the App Group
                        and posts a local notification
  tap notification → Strolle opens, sees the request, shows GateView
  entry cost from the rolling hour: 1st free, then 1, 2, 3 questions
  answer → pass granted (correct or not; iOS floor is 5 min)
         → shield lifted, DeviceActivity monitoring restarted
shield returns when the first of these fires:
  - eventDidReachThreshold: gated apps used for the pass length
  - intervalDidEnd: wall clock, 15 min min (Apple's minimum interval)
  - Strolle comes to the foreground after expiry (reconcile)
```

Ported from the Dart reference so behaviour matches:
- `Shared/PassRules.swift` ← `lib/services/pass_service.dart` (escalation,
  2-second guess threshold, iOS 5-minute floor instead of the 90-second pass)
- `StrolleApp/ReviewQueue.swift` ← `lib/data/review_queue.dart` (x2.5,
  10-minute reset, one-week cap)
- Questions come straight from `app/assets/questions.json` (gate tier only).

## Run it

Requirements: macOS with Xcode 15+, a physical iPhone on iOS 16+ (Screen
Time does nothing in the Simulator), and a paid developer team. Family
Controls works for development builds on your own device; TestFlight
needs Apple's approval of the entitlement request.

1. `brew install xcodegen`, then `cd ios-prototype && xcodegen`.
2. Open `Strolle.xcodeproj`. In `project.yml` (or each target's Signing
   tab) set your team and a bundle prefix you own.
3. Replace `group.com.strolle.prototype` in **both** `Strolle.entitlements`
   and `Shared/AppGroup.swift` with your own App Group. They must match
   exactly or the shield silently won't apply.
4. Add the Family Controls and App Groups capabilities to all four
   targets if Xcode doesn't pick them up from the entitlements file.
5. Run on the device. Allow Screen Time access, allow notifications,
   choose apps, then open one of them.

## Gate rewards

The gate has haptics, a chime, an XP bar with levels, a combo multiplier,
a daily-streak flame and a "+N min unlocked" moment (`Rewards.swift`,
`Feedback.swift`, `RewardViews.swift`). They are cosmetic: XP and streak
live in UserDefaults until the backend stores them, XP scales with
difficulty and never with speed, and pass length is untouched. Asset
sources are in `ASSETS.md`. Unit tests: `StrolleTests/`.

## Known gaps

- **State is on-device.** CLAUDE.md requires server-authoritative pass
  state. Here `SharedState` stands in for `pass_state`; the next step is
  calling `register-entry` and `grade-attempt` from `AppModel` and caching
  the returned `pass_expires_at` in the App Group for the extensions.
- **The shield can't open the app.** There's no public API for it, so
  there's a notification hop. If notifications are denied, the user has
  to open Strolle themselves; the pending request is honoured for 10 min.
- **Pass expiry is usage-based, with a wall-clock backstop.** A user who
  leaves the gated app idle keeps the pass until the 15-minute interval
  ends or they open Strolle.
- **Early threshold fires** more than 30 s before the stored expiry are
  ignored as spurious.
- No streaks, progress view, or extended-pass quiz (M4).

## Moving into the Flutter app later

The three extensions and `Shared/` are UI-agnostic. For M3 they drop into
a Flutter `app/ios` runner unchanged; `AppModel`'s gate flow is replaced
by the existing `GateChannel` (`gateRequested` / `grantPass`) calling
`PassScheduler.grantPass` on the native side.
