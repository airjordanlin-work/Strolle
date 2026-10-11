# Strolle — context for Claude Code

SAT-prep app that shields social media apps behind a question. Flutter
frontend (mostly done), Supabase backend (not started — this is your job).

Read this fully before writing anything. Don't re-derive decisions
already made below; ask before deviating from them.

## Stack
Flutter/Dart (client), Supabase (Postgres + Auth + Edge Functions),
Kotlin (Android, separate scope), Swift (iOS, separate scope, blocked
on entitlement approval — not yet in progress).

## Where things stand
Client-side: `ReviewQueue` (spaced repetition) and `PassService`
(pass length + escalating cost) are implemented in Dart, in-memory only,
in `lib/data/review_queue.dart` and `lib/services/pass_service.dart`.
These are the reference implementation for the logic the backend needs
to reproduce server-side. Read them before writing SQL or Edge
Functions — don't reinvent the interval math, port it.

Backend: nothing exists yet. This is M2. Your job.

## Non-negotiable decisions (do not relitigate these)

- **Gate on engagement, not correctness.** A wrong answer still grants
  entry, at a shorter pass length, and shortens that item's review
  interval. There is no "locked out" state.
- **Escalating cost, not flat.** First entry in a rolling hour is free.
  Then 1, 2, 3 questions, plateauing at 3.
- **Server-authoritative pass state.** Clients read `pass_state`, never
  write it directly. Only Edge Functions set `pass_expires_at`:
  `grade-attempt` after the owed questions are answered, and
  `register-entry` for a free entry (nothing owed, so nothing to grade).
  This is the actual threat model: state must survive app
  reinstall/reboot, which means client-only state is not acceptable even
  for M1/M2 testing.
- **No day-long disable.** The "turn it off" path is a 10-question quiz
  at 70%+ granting a 2-hour extended pass, once per day. Never a
  full-day free pass — see docs/decisions/0001 if you want the reasoning.
- **RLS on every user-scoped table**, policy on `auth.uid()`. No
  exceptions, including tables that feel low-stakes.
- **Content**: official SAT practice material is never stored in the
  database or committed to the repo. Generated questions only. If you're
  touching anything content-related, stop and ask — this has copyright
  implications that are already worked out and shouldn't be re-decided
  ad hoc.

## Platform constraints that shape the schema
- iOS pass length floor is 5 minutes (DeviceActivityEvent thresholds
  under ~5 min are unreliable). Android can go shorter (90s wrong-answer
  pass). The schema needs a platform-aware pass length, not one constant.
- `eventDidReachThreshold` on iOS is unreliable — early/missed fires.
  The client will re-verify pass state on foreground; assume the backend
  is the source of truth, not a push from the OS.

## Scope: M2 only, right now
Build only what's needed for: Supabase schema, server-side grading
(`/register-entry`, `/start-attempt`, `/grade-attempt`, `/pass-status` Edge
Functions),
pass state persistence, retention/cohort instrumentation. Do not start
on iOS shield code, the content generation pipeline, or the social
features (accountability partner) — those are separate milestones and
explicitly not in scope yet. If a task feels like it's drifting into
one of those, stop and flag it rather than continuing.

## Workflow
`main` is protected — no direct pushes, PR required, CI (`flutter analyze`
+ `flutter test`) must pass, CodeRabbit reviews every PR. Work on a
branch: `feat/supabase-schema`, `feat/grade-attempt-function`, etc. Keep
PRs scoped to one migration or one function, not the whole backend at
once — easier to review, easier to revert if something's wrong.

## Style
Commit messages: conventional commits (`feat(backend): ...`,
`fix(schema): ...`), imperative mood, explain why in the body when the
change isn't obvious from the diff.