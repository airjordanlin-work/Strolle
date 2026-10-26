# Assets

Every sound, haptic and animation in the gate, with where it comes from.
There are no third-party files in the repo.

| Item | Source | License |
| --- | --- | --- |
| Correct, level-up and "not quite" tones | Generated in code (`Feedback.swift`): sine notes with a short attack and decay, built as an in-memory WAV | Self-made, same license as the repo |
| Haptics (success, soft and medium impact) | `UINotificationFeedbackGenerator` / `UIImpactFeedbackGenerator` (UIKit system API) | Part of iOS, nothing bundled |
| Streak flame, lock-open, checkmark icons | SF Symbols, used at runtime through `Image(systemName:)` | Apple's SF Symbols license: usable inside apps that run on Apple platforms; never export or modify the glyphs |
| Confetti burst, XP pop, bar fill, number count-up | Native SwiftUI animation (`ConfettiBurst`, `XPPop`, `XPBar`, `UnlockedMoment` in `RewardViews.swift`) | Self-made |

## If you want richer assets later

Record each one here (file, source URL, license, date) in the same PR that adds it.

- Sounds: [Kenney](https://kenney.nl/assets?q=audio) packs are CC0; [freesound.org](https://freesound.org) has CC0 clips if you filter by license (skip CC-BY-NC, which bars commercial use, and CC-BY unless you will credit).
- Animations: [LottieFiles](https://lottiefiles.com/free-animations) has a Free license for many files, but terms vary per file, so check each one; the [lottie-ios](https://github.com/airbnb/lottie-ios) player is Apache 2.0.
