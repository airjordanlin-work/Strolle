begin;

create extension if not exists pgtap with schema extensions;

select extensions.plan(112);

-- Enum values are API contracts shared with the Flutter client.
select extensions.enum_has_labels(
  'public', 'answer_result', array['correct', 'incorrect', 'too_fast'],
  'answer_result exposes exactly the supported grading outcomes'
);

select extensions.enum_has_labels(
  'public', 'device_platform', array['ios', 'android'],
  'device_platform rejects unsupported pass-length strategies'
);

select extensions.has_table('public', 'review_items', 'the migration creates review_items');
select extensions.has_table('public', 'pass_state', 'the migration creates pass_state');
select extensions.has_table('public', 'attempts', 'the migration creates attempts');

-- Keep each table's full shape as one assertion per column/fact so an
-- accidental rename, type change, nullable field, or default is caught.
select extensions.has_column('public', 'review_items', 'user_id', 'review_items has user_id');
select extensions.col_type_is('public', 'review_items', 'user_id', 'uuid', 'review_items.user_id is uuid');
select extensions.col_not_null('public', 'review_items', 'user_id', 'review_items.user_id is required');

select extensions.has_column('public', 'review_items', 'question_id', 'review_items has question_id');
select extensions.col_type_is('public', 'review_items', 'question_id', 'text', 'review_items.question_id is text');
select extensions.col_not_null('public', 'review_items', 'question_id', 'review_items.question_id is required');

select extensions.has_column('public', 'review_items', 'due_at', 'review_items has due_at');
select extensions.col_type_is('public', 'review_items', 'due_at', 'timestamp with time zone', 'review_items.due_at is timestamptz');
select extensions.col_not_null('public', 'review_items', 'due_at', 'review_items.due_at is required');

select extensions.has_column('public', 'review_items', 'interval_minutes', 'review_items has interval_minutes');
select extensions.col_type_is('public', 'review_items', 'interval_minutes', 'integer', 'review_items.interval_minutes is integer');
select extensions.col_not_null('public', 'review_items', 'interval_minutes', 'review_items.interval_minutes is required');
select extensions.col_default_is('public', 'review_items', 'interval_minutes', 10, 'review_items.interval_minutes defaults to 10');

select extensions.has_column('public', 'review_items', 'consecutive_correct', 'review_items has consecutive_correct');
select extensions.col_type_is('public', 'review_items', 'consecutive_correct', 'integer', 'review_items.consecutive_correct is integer');
select extensions.col_not_null('public', 'review_items', 'consecutive_correct', 'review_items.consecutive_correct is required');
select extensions.col_default_is('public', 'review_items', 'consecutive_correct', 0, 'review_items.consecutive_correct defaults to 0');

select extensions.has_column('public', 'pass_state', 'user_id', 'pass_state has user_id');
select extensions.col_type_is('public', 'pass_state', 'user_id', 'uuid', 'pass_state.user_id is uuid');
select extensions.col_not_null('public', 'pass_state', 'user_id', 'pass_state.user_id is required');

select extensions.has_column('public', 'pass_state', 'platform', 'pass_state has platform');
select extensions.col_type_is('public', 'pass_state', 'platform', 'device_platform', 'pass_state.platform is device_platform');
select extensions.col_not_null('public', 'pass_state', 'platform', 'pass_state.platform is required');

select extensions.has_column('public', 'pass_state', 'pass_expires_at', 'pass_state has pass_expires_at');
select extensions.col_type_is('public', 'pass_state', 'pass_expires_at', 'timestamp with time zone', 'pass_state.pass_expires_at is timestamptz');

select extensions.has_column('public', 'pass_state', 'window_started_at', 'pass_state has window_started_at');
select extensions.col_type_is('public', 'pass_state', 'window_started_at', 'timestamp with time zone', 'pass_state.window_started_at is timestamptz');
select extensions.col_not_null('public', 'pass_state', 'window_started_at', 'pass_state.window_started_at is required');
select extensions.col_default_is('public', 'pass_state', 'window_started_at', 'now()', 'pass_state.window_started_at defaults to now()');

select extensions.has_column('public', 'pass_state', 'entries_this_window', 'pass_state has entries_this_window');
select extensions.col_type_is('public', 'pass_state', 'entries_this_window', 'integer', 'pass_state.entries_this_window is integer');
select extensions.col_not_null('public', 'pass_state', 'entries_this_window', 'pass_state.entries_this_window is required');
select extensions.col_default_is('public', 'pass_state', 'entries_this_window', 0, 'pass_state.entries_this_window defaults to 0');

select extensions.has_column('public', 'pass_state', 'updated_at', 'pass_state has updated_at');
select extensions.col_type_is('public', 'pass_state', 'updated_at', 'timestamp with time zone', 'pass_state.updated_at is timestamptz');
select extensions.col_not_null('public', 'pass_state', 'updated_at', 'pass_state.updated_at is required');
select extensions.col_default_is('public', 'pass_state', 'updated_at', 'now()', 'pass_state.updated_at defaults to now()');

select extensions.has_column('public', 'attempts', 'id', 'attempts has id');
select extensions.col_type_is('public', 'attempts', 'id', 'uuid', 'attempts.id is uuid');
select extensions.col_not_null('public', 'attempts', 'id', 'attempts.id is required');
select extensions.col_default_is('public', 'attempts', 'id', 'gen_random_uuid()', 'attempts.id defaults to gen_random_uuid()');

select extensions.has_column('public', 'attempts', 'user_id', 'attempts has user_id');
select extensions.col_type_is('public', 'attempts', 'user_id', 'uuid', 'attempts.user_id is uuid');
select extensions.col_not_null('public', 'attempts', 'user_id', 'attempts.user_id is required');

select extensions.has_column('public', 'attempts', 'question_id', 'attempts has question_id');
select extensions.col_type_is('public', 'attempts', 'question_id', 'text', 'attempts.question_id is text');
select extensions.col_not_null('public', 'attempts', 'question_id', 'attempts.question_id is required');

select extensions.has_column('public', 'attempts', 'started_at', 'attempts has started_at');
select extensions.col_type_is('public', 'attempts', 'started_at', 'timestamp with time zone', 'attempts.started_at is timestamptz');
select extensions.col_not_null('public', 'attempts', 'started_at', 'attempts.started_at is required');
select extensions.col_default_is('public', 'attempts', 'started_at', 'now()', 'attempts.started_at defaults to now()');

select extensions.has_column('public', 'attempts', 'answered_at', 'attempts has answered_at');
select extensions.col_type_is('public', 'attempts', 'answered_at', 'timestamp with time zone', 'attempts.answered_at is timestamptz');

select extensions.has_column('public', 'attempts', 'result', 'attempts has result');
select extensions.col_type_is('public', 'attempts', 'result', 'answer_result', 'attempts.result is answer_result');

select extensions.has_column('public', 'attempts', 'response_time_ms', 'attempts has response_time_ms');
select extensions.col_type_is('public', 'attempts', 'response_time_ms', 'integer', 'attempts.response_time_ms is integer');

-- Primary keys enforce one pass state and one review item per user/question.
select extensions.col_is_pk('public', 'review_items', array['user_id', 'question_id'], 'review_items keys on (user_id, question_id)');
select extensions.col_is_pk('public', 'pass_state', 'user_id', 'pass_state keys on user_id');
select extensions.col_is_pk('public', 'attempts', 'id', 'attempts keys on id');

-- Every user-scoped row cascades when its auth user is removed.
select extensions.fk_ok('public', 'review_items', 'user_id', 'auth', 'users', 'id', 'review_items.user_id references auth.users');
select extensions.is(
  (select confdeltype from pg_catalog.pg_constraint where conrelid = 'public.review_items'::regclass and contype = 'f'),
  'c', 'review_items.user_id cascades on delete'
);

select extensions.fk_ok('public', 'pass_state', 'user_id', 'auth', 'users', 'id', 'pass_state.user_id references auth.users');
select extensions.is(
  (select confdeltype from pg_catalog.pg_constraint where conrelid = 'public.pass_state'::regclass and contype = 'f'),
  'c', 'pass_state.user_id cascades on delete'
);

select extensions.fk_ok('public', 'attempts', 'user_id', 'auth', 'users', 'id', 'attempts.user_id references auth.users');
select extensions.is(
  (select confdeltype from pg_catalog.pg_constraint where conrelid = 'public.attempts'::regclass and contype = 'f'),
  'c', 'attempts.user_id cascades on delete'
);

-- Lookup indexes support per-user chronological queue and attempt reads.
select extensions.indexes_are(
  'public', 'review_items', array['review_items_pkey', 'review_items_user_id_due_at_idx'],
  'review_items has only its primary key and the due_at lookup index'
);
select extensions.indexes_are(
  'public', 'pass_state', array['pass_state_pkey'],
  'pass_state has only its primary key'
);
select extensions.indexes_are(
  'public', 'attempts', array['attempts_pkey', 'attempts_user_id_started_at_idx'],
  'attempts has only its primary key and the started_at lookup index'
);

-- RLS is enabled on every user-scoped table.
select extensions.ok(
  (select relrowsecurity from pg_catalog.pg_class c join pg_catalog.pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relname = 'review_items'),
  'RLS is enabled on review_items'
);
select extensions.ok(
  (select relrowsecurity from pg_catalog.pg_class c join pg_catalog.pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relname = 'pass_state'),
  'RLS is enabled on pass_state'
);
select extensions.ok(
  (select relrowsecurity from pg_catalog.pg_class c join pg_catalog.pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relname = 'attempts'),
  'RLS is enabled on attempts'
);

-- Clients receive only owner-scoped select policies, nothing wider.
select extensions.policies_are('public', 'review_items', array['own_review_items'], 'review_items exposes exactly one policy');
select extensions.policy_cmd_is('public', 'review_items', 'own_review_items', 'SELECT', 'own_review_items is select-only');
select extensions.is(
  (select roles from pg_catalog.pg_policies where schemaname = 'public' and tablename = 'review_items' and policyname = 'own_review_items'),
  '{public}'::name[], 'own_review_items applies to public'
);
select extensions.is(
  (select qual from pg_catalog.pg_policies where schemaname = 'public' and tablename = 'review_items' and policyname = 'own_review_items'),
  '(auth.uid() = user_id)', 'own_review_items scopes rows to their owner'
);
select extensions.is(
  (select with_check from pg_catalog.pg_policies where schemaname = 'public' and tablename = 'review_items' and policyname = 'own_review_items'),
  null, 'own_review_items has no write check, since it grants no write'
);

select extensions.policies_are('public', 'pass_state', array['own_pass_state'], 'pass_state exposes exactly one policy');
select extensions.policy_cmd_is('public', 'pass_state', 'own_pass_state', 'SELECT', 'own_pass_state is select-only');
select extensions.is(
  (select roles from pg_catalog.pg_policies where schemaname = 'public' and tablename = 'pass_state' and policyname = 'own_pass_state'),
  '{public}'::name[], 'own_pass_state applies to public'
);
select extensions.is(
  (select qual from pg_catalog.pg_policies where schemaname = 'public' and tablename = 'pass_state' and policyname = 'own_pass_state'),
  '(auth.uid() = user_id)', 'own_pass_state scopes rows to their owner'
);
select extensions.is(
  (select with_check from pg_catalog.pg_policies where schemaname = 'public' and tablename = 'pass_state' and policyname = 'own_pass_state'),
  null, 'own_pass_state has no write check, since it grants no write'
);

select extensions.policies_are('public', 'attempts', array['own_attempts'], 'attempts exposes exactly one policy');
select extensions.policy_cmd_is('public', 'attempts', 'own_attempts', 'SELECT', 'own_attempts is select-only');
select extensions.is(
  (select roles from pg_catalog.pg_policies where schemaname = 'public' and tablename = 'attempts' and policyname = 'own_attempts'),
  '{public}'::name[], 'own_attempts applies to public'
);
select extensions.is(
  (select qual from pg_catalog.pg_policies where schemaname = 'public' and tablename = 'attempts' and policyname = 'own_attempts'),
  '(auth.uid() = user_id)', 'own_attempts scopes rows to their owner'
);
select extensions.is(
  (select with_check from pg_catalog.pg_policies where schemaname = 'public' and tablename = 'attempts' and policyname = 'own_attempts'),
  null, 'own_attempts has no write check, since it grants no write'
);

select extensions.is(
  (
    select count(*)::bigint
    from pg_catalog.pg_policies
    where schemaname = 'public'
      and tablename in ('review_items', 'pass_state', 'attempts')
      and cmd <> 'SELECT'
  ),
  0::bigint,
  'no client write policy can bypass the grading function'
);

-- Seed through the migration-owner role, which models server/service-role writes.
insert into auth.users (id, email)
values
  ('00000000-0000-0000-0000-0000000000a1', 'schema-a@example.test'),
  ('00000000-0000-0000-0000-0000000000b2', 'schema-b@example.test'),
  ('00000000-0000-0000-0000-0000000000c3', 'schema-c@example.test');

insert into public.review_items (user_id, question_id, due_at)
values
  ('00000000-0000-0000-0000-0000000000a1', 'shared-question', '2030-01-01 00:00:00+00'),
  ('00000000-0000-0000-0000-0000000000a1', 'reading:craft-and-structure:1', '2030-01-02 00:00:00+00'),
  ('00000000-0000-0000-0000-0000000000b2', 'shared-question', '2030-01-03 00:00:00+00'),
  ('00000000-0000-0000-0000-0000000000c3', 'cascade-question', '2030-01-04 00:00:00+00');

insert into public.pass_state (user_id, platform)
values
  ('00000000-0000-0000-0000-0000000000a1', 'ios'),
  ('00000000-0000-0000-0000-0000000000b2', 'android'),
  ('00000000-0000-0000-0000-0000000000c3', 'ios');

insert into public.attempts (user_id, question_id)
values
  ('00000000-0000-0000-0000-0000000000a1', 'shared-question'),
  ('00000000-0000-0000-0000-0000000000b2', 'shared-question'),
  ('00000000-0000-0000-0000-0000000000c3', 'cascade-question');

select extensions.results_eq(
  $$
    select question_id, interval_minutes, consecutive_correct
    from public.review_items
    where user_id = '00000000-0000-0000-0000-0000000000a1'
      and question_id = 'reading:craft-and-structure:1'
  $$,
  $$values ('reading:craft-and-structure:1'::text, 10, 0)$$,
  'review items preserve non-UUID question IDs and scheduling defaults'
);

select extensions.ok(
  (
    select
      pass_expires_at is null
      and window_started_at is not null
      and entries_this_window = 0
      and updated_at is not null
    from public.pass_state
    where user_id = '00000000-0000-0000-0000-0000000000a1'
  ),
  'new pass state starts expired with an empty initialized window'
);

select extensions.ok(
  (
    select
      id is not null
      and started_at is not null
      and answered_at is null
      and result is null
      and response_time_ms is null
    from public.attempts
    where user_id = '00000000-0000-0000-0000-0000000000a1'
  ),
  'a started attempt is valid before grading fields are populated'
);

select extensions.throws_ok(
  $$
    insert into public.review_items (user_id, question_id, due_at)
    values (
      '00000000-0000-0000-0000-0000000000a1',
      'shared-question',
      '2031-01-01 00:00:00+00'
    )
  $$,
  '23505',
  null,
  'one user cannot have duplicate review rows for the same question'
);

select extensions.lives_ok(
  $$
    insert into public.attempts (user_id, question_id)
    values ('00000000-0000-0000-0000-0000000000a1', 'shared-question')
  $$,
  'repeated attempts for the same question remain valid history'
);

select extensions.is(
  (
    select count(*)::bigint
    from public.attempts
    where user_id = '00000000-0000-0000-0000-0000000000a1'
      and question_id = 'shared-question'
  ),
  2::bigint,
  'each repeated attempt receives its own row'
);

select extensions.throws_ok(
  $$
    insert into public.pass_state (user_id, platform)
    values ('00000000-0000-0000-0000-0000000000c3', 'web')
  $$,
  '22P02',
  null,
  'unsupported device platforms are rejected'
);

select extensions.throws_ok(
  $$
    update public.attempts
    set result = 'skipped'
    where user_id = '00000000-0000-0000-0000-0000000000a1'
  $$,
  '22P02',
  null,
  'unsupported answer outcomes are rejected'
);

select extensions.throws_ok(
  $$
    insert into public.attempts (user_id, question_id)
    values ('00000000-0000-0000-0000-000000000099', 'missing-user')
  $$,
  '23503',
  null,
  'attempts cannot outlive or bypass auth users'
);

update public.attempts
set
  answered_at = started_at + interval '1500 milliseconds',
  result = 'too_fast',
  response_time_ms = 1500
where user_id = '00000000-0000-0000-0000-0000000000b2';

select extensions.results_eq(
  $$
    select result::text, response_time_ms, answered_at > started_at
    from public.attempts
    where user_id = '00000000-0000-0000-0000-0000000000b2'
  $$,
  $$values ('too_fast'::text, 1500, true)$$,
  'the service role can complete attempts with too-fast timing data'
);

delete from auth.users where id = '00000000-0000-0000-0000-0000000000c3';

select extensions.results_eq(
  $$
    select relation_name, remaining_rows
    from (
      select 'attempts'::text as relation_name, count(*)::bigint as remaining_rows
      from public.attempts
      where user_id = '00000000-0000-0000-0000-0000000000c3'
      union all
      select 'pass_state'::text, count(*)::bigint
      from public.pass_state
      where user_id = '00000000-0000-0000-0000-0000000000c3'
      union all
      select 'review_items'::text, count(*)::bigint
      from public.review_items
      where user_id = '00000000-0000-0000-0000-0000000000c3'
    ) cascaded_rows
    order by relation_name
  $$,
  $$
    values
      ('attempts'::text, 0::bigint),
      ('pass_state'::text, 0::bigint),
      ('review_items'::text, 0::bigint)
  $$,
  'deleting an auth user cascades through every user-scoped table'
);

-- Exercise policy behavior as real client roles, not only through catalogs.
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000a1';

select extensions.results_eq(
  $$
    select relation_name, visible_rows
    from (
      select 'attempts'::text as relation_name, count(*)::bigint as visible_rows from public.attempts
      union all
      select 'pass_state'::text, count(*)::bigint from public.pass_state
      union all
      select 'review_items'::text, count(*)::bigint from public.review_items
    ) visible
    order by relation_name
  $$,
  $$
    values
      ('attempts'::text, 2::bigint),
      ('pass_state'::text, 1::bigint),
      ('review_items'::text, 2::bigint)
  $$,
  'an authenticated user sees only their own server state'
);

set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000b2';

select extensions.results_eq(
  $$
    select relation_name, visible_rows
    from (
      select 'attempts'::text as relation_name, count(*)::bigint as visible_rows from public.attempts
      union all
      select 'pass_state'::text, count(*)::bigint from public.pass_state
      union all
      select 'review_items'::text, count(*)::bigint from public.review_items
    ) visible
    order by relation_name
  $$,
  $$
    values
      ('attempts'::text, 1::bigint),
      ('pass_state'::text, 1::bigint),
      ('review_items'::text, 1::bigint)
  $$,
  'switching JWT identity cannot leak another user''s rows'
);

select extensions.throws_ok(
  $$
    insert into public.review_items (user_id, question_id, due_at)
    values (
      '00000000-0000-0000-0000-0000000000b2',
      'client-write',
      '2030-01-01 00:00:00+00'
    )
  $$,
  '42501',
  null,
  'authenticated clients cannot insert review items'
);

select extensions.throws_ok(
  $$
    insert into public.pass_state (user_id, platform)
    values ('00000000-0000-0000-0000-0000000000c3', 'android')
  $$,
  '42501',
  null,
  'authenticated clients cannot insert pass state'
);

select extensions.throws_ok(
  $$
    insert into public.attempts (user_id, question_id)
    values ('00000000-0000-0000-0000-0000000000b2', 'client-write')
  $$,
  '42501',
  null,
  'authenticated clients cannot insert attempts'
);

select extensions.results_eq(
  $$
    with changed_review as (
      update public.review_items
      set consecutive_correct = 99
      returning 'review_items'::text as relation_name
    ), changed_pass as (
      update public.pass_state
      set entries_this_window = 99
      returning 'pass_state'::text as relation_name
    ), changed_attempt as (
      update public.attempts
      set response_time_ms = 99
      returning 'attempts'::text as relation_name
    )
    select relation_name from changed_review
    union all select relation_name from changed_pass
    union all select relation_name from changed_attempt
  $$,
  $$select null::text where false$$,
  'authenticated clients cannot update even their own rows'
);

select extensions.results_eq(
  $$
    with deleted_review as (
      delete from public.review_items returning 'review_items'::text as relation_name
    ), deleted_pass as (
      delete from public.pass_state returning 'pass_state'::text as relation_name
    ), deleted_attempt as (
      delete from public.attempts returning 'attempts'::text as relation_name
    )
    select relation_name from deleted_review
    union all select relation_name from deleted_pass
    union all select relation_name from deleted_attempt
  $$,
  $$select null::text where false$$,
  'authenticated clients cannot delete even their own rows'
);

reset role;
set local role anon;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000099';

select extensions.results_eq(
  $$
    select relation_name, visible_rows
    from (
      select 'attempts'::text as relation_name, count(*)::bigint as visible_rows from public.attempts
      union all
      select 'pass_state'::text, count(*)::bigint from public.pass_state
      union all
      select 'review_items'::text, count(*)::bigint from public.review_items
    ) visible
    order by relation_name
  $$,
  $$
    values
      ('attempts'::text, 0::bigint),
      ('pass_state'::text, 0::bigint),
      ('review_items'::text, 0::bigint)
  $$,
  'anonymous clients cannot read user-scoped state'
);

reset role;

select * from extensions.finish();
rollback;
