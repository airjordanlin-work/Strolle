-- Question bank: 4D tags, skill taxonomy, adaptive ability ratings.
-- Content source is content/question_bank/ (questions.json, skills.json).
-- Selection logic lives in functions/_shared/adaptive.ts.

create type four_d as enum ('delegation', 'description', 'discernment', 'diligence');

-- Published digital SAT skill taxonomy. sat_weight is the skill's
-- approximate share of its section; the selector favors heavier skills.
create table skills (
  slug       text primary key,
  section    text not null check (section in ('math', 'reading', 'writing')),
  domain     text not null,
  sat_weight real not null check (sat_weight >= 0)
);

-- The questions table itself. 0001 no longer creates it (e111db7 removed
-- it when the schema moved to text question ids), so the bank migration
-- owns it. Definition is the original from 2767237; the alter below adds
-- the bank columns on top.
create type question_tier as enum ('gate', 'session');

create table questions (
  id            uuid primary key default gen_random_uuid(),
  section       text not null,
  skill         text not null,
  difficulty    int  not null check (difficulty between 1 and 5),
  tier          question_tier not null,
  stem          text not null,
  choices       jsonb not null,
  correct_index int  not null,
  explanation   text not null,
  reviewed      bool not null default false,
  created_at    timestamptz not null default now()
);

-- Nothing circulates until a human approves it.
create index on questions (tier, reviewed) where reviewed;

alter table questions enable row level security;

create policy reviewed_questions_readable on questions
  for select using (reviewed = true);

alter table questions
  -- Stable content id (e.g. 'm-001') so bank files and review history
  -- can refer to the same item across reseeds.
  add column slug                text unique,
  add column four_d              four_d,
  -- Session items only. The gate never shows a passage.
  add column passage             text,
  add column time_target_seconds int check (time_target_seconds > 0),
  -- Calibrated difficulty on the ability scale. Null until enough
  -- answers exist; the selector falls back to (difficulty - 3) * 0.8.
  add column rating              real,
  add constraint questions_skill_fk foreign key (skill) references skills (slug),
  add constraint gate_has_no_passage check (tier = 'session' or passage is null);

-- One Elo-style rating per user per skill. Written only by the grading
-- function, same as review_items.
create table skill_ability (
  user_id    uuid not null references auth.users on delete cascade,
  skill      text not null references skills (slug),
  rating     real not null default 0,
  attempts   int  not null default 0,
  updated_at timestamptz not null default now(),
  primary key (user_id, skill)
);

alter table skills        enable row level security;
alter table skill_ability enable row level security;

create policy skills_readable on skills
  for select using (true);

-- Deliberately select-only. Only the grading function writes these.
create policy own_skill_ability on skill_ability
  for select using (auth.uid() = user_id);
