# Status

Where things stand on `feat/ios-prototype-question-bank`, and who owns
what so two people don't edit the same files. Read `CLAUDE.md` first; its
decisions still hold.

## Done

- **Flutter app** (`app/`): gate and home screens, in-memory `ReviewQueue`
  and `PassService` (the reference logic for everything else).
- **Schema** (`backend/supabase/migrations/0001_init.sql`): questions,
  attempts, pass_state, review_items, profiles, all with RLS.
- **grade-attempt** Edge Function: server-side grading, review interval
  update, writes `pass_expires_at`.
- **register-entry** Edge Function: escalating entry cost, and it records
  how many questions are owed.
- **grade-attempt fixes** (migration 0003): uses the real `streak` column,
  keys review items by question slug, enforces the iOS 5-minute pass
  floor, discards answers under 2 seconds, and only grants the pass once
  every owed question is answered.
- **Server-side timing and free-entry pass** (migration 0004):
  `start-attempt` records each served question in `gate_serves`, and
  grade-attempt measures the 2-second guess threshold from it. A free
  entry gets its pass from register-entry. See `TESTING.md` for unit,
  integration, visual and manual tests.
- **Question bank** (`content/question_bank/`): 56 original SAT-style items
  (31 math, 25 reading/writing) tagged by skill and 4D, a skill taxonomy, and
  `validate.py`. All items are `reviewed: false`.
- **Migration 0002** (`0002_question_bank.sql`): 4D enum, `skills`,
  `skill_ability`, new question columns.
- **Adaptive selector** (`backend/supabase/functions/_shared/adaptive.ts`,
  tested in `adaptive_test.ts`): due review first, then an Elo-style pick by
  skill, then the soonest review.
- **iOS prototype** (`ios-prototype/`): standalone SwiftUI Screen Time spike
  with the shield, shield action and DeviceActivity extensions. Not compiled
  yet; needs a Mac, a real iPhone and a paid developer team.
- **System design doc**: "Strolle System Design" in the Claude project
  (latency budget, scaling plan, roadmap).

## Open or in progress

- **The Flutter app doesn't call the backend yet.** Its gate still runs on
  in-memory logic; wiring it to Supabase waits on the auth work.
- **Question choice is still the client's.** `start-attempt` records what
  the client serves; moving selection onto `_shared/adaptive.ts` is next.
- **Pass state on iOS is on-device only.** `ios-prototype` still has to call
  `register-entry` and `grade-attempt` and cache `pass_expires_at`.
- **No question is reviewed yet.** Nothing should be served until a person
  sets `reviewed: true`.
- **questions.json exists in three places**: `content/question_bank/`
  (the source), plus copies in `app/assets/` and `backend/supabase/functions/_shared/` and the
  generated `backend/supabase/seed.sql`. Edit the source, then run
  `python3 content/question_bank/sync.py`; CI fails if a copy drifts.
- **Open questions from the design doc** (Jordan to decide):
  - Offline: grant a provisional floor pass, or no pass until the server answers?
  - iOS pass end: treat server wall-clock time as the authority?
  - 4Ds: is the study-habit reading what you intended?
  - Is it OK to ask users for practice-test scores during onboarding?
  - Merge register-entry and grade-attempt into one `/gate-answer` call?

## Ownership (to avoid editing the same files)

| Area | Paths | Owner |
| --- | --- | --- |
| Backend and schema | `backend/**`, `CLAUDE.md` | Jordan |
| iOS prototype | `ios-prototype/**` | Collaborator |
| Flutter app | `app/**` (except `app/assets/questions.json`) | Collaborator |
| Question bank | `content/question_bank/**` and its two copies | Jordan; send changes as a PR |
| This file | `STATUS.md` | Whoever finishes something; keep edits small |

Swap these if you prefer, but give each area exactly one owner.

## Working together

1. Branch off `feat/ios-prototype-question-bank`, e.g.
   `git fetch origin && git switch -c feat/<your-thing> origin/feat/ios-prototype-question-bank`.
2. Stay inside the paths you own. If you need a change in someone else's
   area, open an issue or ask them first.
3. One PR per migration or function, as `CLAUDE.md` says. CI
   (`flutter analyze` + `flutter test`) has to pass.
