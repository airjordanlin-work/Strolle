-- One row per gate question served. start-attempt stamps served_at and
-- grade-attempt stamps graded_at, both from the server clock, so the guess
-- threshold is measured on the server instead of trusted from the client.
-- A row can be graded once, which also stops an answer being replayed.
-- Doubles as the per-answer log for retention and cohort analysis.

create table gate_serves (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users on delete cascade,
  question_id text not null references questions (slug),
  served_at   timestamptz not null default now(),
  graded_at   timestamptz,
  outcome     text check (outcome in ('correct', 'incorrect', 'too_fast'))
);

create index on gate_serves (user_id, served_at);

alter table gate_serves enable row level security;

-- Deliberately select-only. Only start-attempt and grade-attempt write.
create policy own_gate_serves on gate_serves
  for select using (auth.uid() = user_id);
