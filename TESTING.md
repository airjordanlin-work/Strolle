# Testing Strolle

What you can test today, and how:

| What | How | Needs |
| --- | --- | --- |
| Grading rules, cost, adaptive selector | Deno unit tests (step 1) | Deno |
| Question bank and its copies | `validate.py`, `sync.py --check` (step 1) | Python 3 |
| Flutter logic | `flutter test` (step 1) | Flutter |
| Edge Functions + database + RLS | Integration tests (step 3) | Docker, Supabase CLI |
| The full gate flow, visually | Gate playground page (step 4) | Same as step 3, plus a browser |
| Single calls by hand | curl (step 5) | Same as step 3 |
| The Flutter app's screens | iOS Simulator or Android emulator (step 6) | Xcode or Android Studio |
| The real Screen Time shield | `ios-prototype/` on an iPhone (step 7) | Mac, iPhone, paid developer team |

The Flutter app doesn't call the backend yet: its gate runs on in-memory
logic. Until the client is wired to Supabase (after the auth work lands),
the gate playground in step 4 is the visual way to exercise the server
flow.

## 1. Unit tests (no Docker)

From `backend/`:

```bash
deno test --node-modules-dir=none supabase/functions/
```

This covers the grading rules (`_shared/grading_test.ts`), the entry cost
(`register-entry/cost_test.ts`) and the adaptive selector
(`_shared/adaptive_test.ts`).

From the repo root, check the question bank and its copies:

```bash
python3 content/question_bank/validate.py
python3 content/question_bank/sync.py --check
```

From `app/`:

```bash
flutter analyze && flutter test
```

## 2. Start the local stack

From `backend/`, with Docker Desktop running:

```bash
supabase start
```

This applies `migrations/` and loads `supabase/seed.sql`, which holds the
skills and questions generated from `content/question_bank/`. To start
over from an empty database, run `supabase db reset`.

In a second terminal, serve the functions and leave it running:

```bash
supabase functions serve
```

## 3. Integration tests

From `backend/`:

```bash
deno test --node-modules-dir=none --allow-net --allow-env --allow-read tests/
```

Each test creates its own user, so there's no need to reset between
runs. If the stack isn't running, the tests are skipped instead of
failing.

## 4. Gate playground (visual)

A local page that makes the same calls the app will: register an entry,
serve a question, grade it, and show the server's pass state with a live
countdown. From `backend/`:

```bash
python3 -m http.server 8787
```

Open http://localhost:8787/tools/gate-playground.html, then:

1. **Sign in as a new test user.** It signs up a throwaway user on your
   local stack.
2. **Open a gated app.** The first entry in an hour is free, and the pass
   appears on the right straight away.
3. **Open a gated app** again. Now one question is owed (then 2, then 3).
   Answer it and the pass resets.
4. Answer within 2 seconds of the question appearing to see it rejected
   as too fast. Switch the platform to `android` and answer wrong to see
   the 90-second pass.

The "Last response" box shows each function's raw JSON.

## 5. By hand with curl

From `backend/`, mint a test user and token:

```bash
deno run --node-modules-dir=none --allow-net --allow-env --allow-read scripts/seed-grade-attempt-test.ts
```

Copy the `access_token` it prints into a shell variable:

```bash
export TOKEN=paste-the-access-token-here
```

**Open the gate.** The first call in an hour owes 0 questions and returns
a pass; repeat it to see 1, 2, 3, 3 owed.

```bash
curl -s -X POST http://127.0.0.1:54321/functions/v1/register-entry -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d '{"platform":"ios"}'
```

**Serve a question.** This returns an `attempt_id`, and the server
starts timing.

```bash
curl -s http://127.0.0.1:54321/functions/v1/start-attempt -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d '{"question_id":"seed-001"}'
```

**Answer it**, at least 2 seconds later. `seed-001` has answer key 0.

```bash
curl -s http://127.0.0.1:54321/functions/v1/grade-attempt -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d '{"attempt_id":"paste-the-attempt-id","choice_index":0,"platform":"ios"}'
```

What to expect:

| Situation | Response |
| --- | --- |
| Free entry (first in the hour) | `questions_owed: 0` with `pass_expires_at` 5 minutes out |
| Correct, nothing else owed | `pass_expires_at` 5 minutes out, `questions_remaining: 0` |
| Wrong on iOS | Also 5 minutes (the iOS floor) |
| Wrong on Android | 90 seconds |
| More questions owed | `pass_expires_at: null`, `questions_remaining` counts down |
| Answered under 2 s after start-attempt | `{"scored": false, "too_fast": true}`, no pass |
| Same `attempt_id` graded twice | 409 |
| Session item, unknown id, bad choice | 400 or 404 |

**Look at the rows** in Studio at http://127.0.0.1:54323 (tables
`pass_state`, `review_items`, `gate_serves`), or with psql:

```bash
psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -c "select * from pass_state; select * from gate_serves;"
```

## 6. The Flutter app in a simulator

The app has no `ios/` folder yet, so generate one locally first (the
`app/` owner decides whether to commit it). From `app/`:

```bash
flutter create --platforms=ios --org com.strolle.dev .
```

Then boot a simulator and run:

```bash
open -a Simulator
```

```bash
flutter run
```

What you'll see: the home screen and review queue. The gate screen only
opens when the native side sends `gateRequested`, which the iOS runner
doesn't do yet, so you can't reach the gate in a simulator today.

If `flutter run` reports "Found no destinations for the scheme 'Runner'",
Xcode is missing the iOS platform that matches its SDK. Install it once:

```bash
xcodebuild -downloadPlatform iOS
```

## 7. The iOS prototype (Screen Time)

Follow `ios-prototype/README.md`. In short: `brew install xcodegen`, then
`cd ios-prototype && xcodegen`, set your team and App Group, and run on
a physical iPhone.

What a simulator can and can't check:

| Check | Simulator | iPhone |
| --- | --- | --- |
| It compiles; the SwiftUI screens lay out | Yes | Yes |
| GateView questions, answer feedback, entry cost | Yes, if you open GateView directly from a preview or a debug button | Yes |
| Screen Time permission prompt | No | Yes |
| Shield appears on a picked app | No | Yes |
| Shield button, then notification, then gate | No | Yes |
| Pass lifts the shield, and it returns on expiry | No | Yes |

The prototype keeps pass state on the device for now; calling
register-entry, start-attempt and grade-attempt from `AppModel` is the
next step there.

## 8. Stop

From `backend/`:

```bash
supabase stop
```
