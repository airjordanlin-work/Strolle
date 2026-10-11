# Testing the backend

Run every command from `backend/` unless noted. You need Docker Desktop
running, the Supabase CLI, and Deno 2.

## 1. Unit tests (no Docker)

```bash
deno test --node-modules-dir=none supabase/functions/
```

This covers the grading rules (`grade-attempt/grading_test.ts`), the
entry cost (`register-entry/cost_test.ts`) and the adaptive selector
(`_shared/adaptive_test.ts`).

From the repo root, check the question bank and its copies:

```bash
python3 content/question_bank/validate.py
python3 content/question_bank/sync.py --check
```

## 2. Start the local stack

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

```bash
deno test --node-modules-dir=none --allow-net --allow-env --allow-read tests/
```

Each test creates its own user, so there's no need to reset between
runs. If the stack isn't running, the tests are skipped instead of
failing.

## 4. By hand with curl

Mint a test user and token:

```bash
deno run --node-modules-dir=none --allow-net --allow-env --allow-read scripts/seed-grade-attempt-test.ts
```

Copy the `access_token` it prints into a shell variable:

```bash
export TOKEN=paste-the-access-token-here
```

**Open the gate.** The first call in an hour owes 0 questions; repeat
it to see 1, 2, 3, 3.

```bash
curl -s -X POST http://127.0.0.1:54321/functions/v1/register-entry -H "Authorization: Bearer $TOKEN"
```

**Answer a question.** `seed-001` has answer key 0. Change
`choice_index` to get a wrong answer, `platform` to `android` to see the
90-second pass, or `elapsed_ms` under 2000 to see an answer discarded.

```bash
curl -s http://127.0.0.1:54321/functions/v1/grade-attempt -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d '{"question_id":"seed-001","choice_index":0,"platform":"ios","elapsed_ms":4000}'
```

What to expect:

| Situation | Response |
| --- | --- |
| Correct, nothing else owed | `pass_expires_at` 5 minutes out, `questions_remaining: 0` |
| Wrong on iOS | Also 5 minutes (the iOS floor) |
| Wrong on Android | 90 seconds |
| More questions owed | `pass_expires_at: null`, `questions_remaining` counts down |
| `elapsed_ms` under 2000 | `{"scored": false, "too_fast": true}`, nothing saved |
| Session item, unknown id, bad choice | 400 or 404 |

**Look at the rows** in Studio at http://127.0.0.1:54323 (tables
`pass_state` and `review_items`), or with psql:

```bash
psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -c "select * from pass_state; select * from review_items;"
```

## 5. Stop

```bash
supabase stop
```
