-- Aligns the schema with what grade-attempt and register-entry actually
-- need. 0001 and 0002 are left as they were.

-- Questions owed for the current entry. register-entry sets it from the
-- escalation curve; grade-attempt counts it down and only grants the pass
-- once it reaches zero.
alter table pass_state
  add column questions_owed int not null default 0
    check (questions_owed >= 0),
  add column updated_at     timestamptz not null default now();

-- Review items are keyed by the bank's stable slug ('m-005'), the same id
-- the client and the bundled question file use. The uuid key could never
-- match those ids. The table is empty before any client ships, so the
-- type change is safe.
alter table review_items
  drop constraint review_items_question_id_fkey;
alter table review_items
  alter column question_id type text using question_id::text;
alter table review_items
  add constraint review_items_question_id_fkey
    foreign key (question_id) references questions (slug) on delete cascade;
