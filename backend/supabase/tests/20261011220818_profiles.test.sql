begin;

create extension if not exists pgtap with schema extensions;

select extensions.plan(96);

-- Keep the table's full shape as one assertion per column/fact so an
-- accidental rename, type change, nullable field, or default is caught.
select extensions.has_column('public', 'profiles', 'user_id', 'profiles has user_id');
select extensions.col_type_is('public', 'profiles', 'user_id', 'uuid', 'profiles.user_id is uuid');
select extensions.col_not_null('public', 'profiles', 'user_id', 'profiles.user_id is required');

select extensions.has_column('public', 'profiles', 'username', 'profiles has username');
select extensions.col_type_is('public', 'profiles', 'username', 'text', 'profiles.username is text');
select extensions.col_not_null('public', 'profiles', 'username', 'profiles.username is required');

select extensions.has_column('public', 'profiles', 'target_english', 'profiles has target_english');
select extensions.col_type_is('public', 'profiles', 'target_english', 'integer', 'profiles.target_english is integer');
select extensions.col_not_null('public', 'profiles', 'target_english', 'profiles.target_english is required');

select extensions.has_column('public', 'profiles', 'target_math', 'profiles has target_math');
select extensions.col_type_is('public', 'profiles', 'target_math', 'integer', 'profiles.target_math is integer');
select extensions.col_not_null('public', 'profiles', 'target_math', 'profiles.target_math is required');

select extensions.has_column('public', 'profiles', 'test_date', 'profiles has test_date');
select extensions.col_type_is('public', 'profiles', 'test_date', 'date', 'profiles.test_date is date');

select extensions.has_column('public', 'profiles', 'daily_goal', 'profiles has daily_goal');
select extensions.col_type_is('public', 'profiles', 'daily_goal', 'integer', 'profiles.daily_goal is integer');
select extensions.col_not_null('public', 'profiles', 'daily_goal', 'profiles.daily_goal is required');
select extensions.col_default_is('public', 'profiles', 'daily_goal', 10, 'profiles.daily_goal defaults to 10');

select extensions.has_column('public', 'profiles', 'cohort', 'profiles has cohort');
select extensions.col_type_is('public', 'profiles', 'cohort', 'text', 'profiles.cohort is text');

select extensions.has_column('public', 'profiles', 'created_at', 'profiles has created_at');
select extensions.col_type_is('public', 'profiles', 'created_at', 'timestamp with time zone', 'profiles.created_at is timestamptz');
select extensions.col_not_null('public', 'profiles', 'created_at', 'profiles.created_at is required');
select extensions.col_default_is('public', 'profiles', 'created_at', 'now()', 'profiles.created_at defaults to now()');

-- One profile per auth user, and usernames are globally unique.
select extensions.col_is_pk('public', 'profiles', 'user_id', 'profiles keys on user_id');
select extensions.col_is_unique('public', 'profiles', 'username', 'usernames are unique');

-- The profile cascades away with its auth user, which is what replaces a delete policy.
select extensions.fk_ok('public', 'profiles', 'user_id', 'auth', 'users', 'id', 'profiles.user_id references auth.users');
select extensions.is(
  (select confdeltype from pg_catalog.pg_constraint where conrelid = 'public.profiles'::regclass and contype = 'f'),
  'c', 'profiles.user_id cascades on delete'
);

select extensions.indexes_are(
  'public', 'profiles', array['profiles_pkey', 'profiles_username_key'],
  'profiles has only its primary key and the username uniqueness index'
);

-- RLS is enabled on profiles.
select extensions.ok(
  (
    select relrowsecurity
    from pg_catalog.pg_class table_class
    join pg_catalog.pg_namespace table_namespace on table_namespace.oid = table_class.relnamespace
    where table_namespace.nspname = 'public' and table_class.relname = 'profiles'
  ),
  'RLS is enabled on profiles'
);

-- profiles exposes owner-scoped read, insert and update policies and nothing wider.
select extensions.policies_are(
  'public', 'profiles', array['insert own profile', 'read own profile', 'update own profile'],
  'profiles exposes exactly three policies'
);

select extensions.policy_cmd_is('public', 'profiles', 'read own profile', 'SELECT', 'read own profile is select-only');
select extensions.is(
  (select roles from pg_catalog.pg_policies where schemaname = 'public' and tablename = 'profiles' and policyname = 'read own profile'),
  '{public}'::name[], 'read own profile applies to public'
);
select extensions.is(
  (select qual from pg_catalog.pg_policies where schemaname = 'public' and tablename = 'profiles' and policyname = 'read own profile'),
  '(auth.uid() = user_id)', 'read own profile scopes rows to their owner'
);
select extensions.is(
  (select with_check from pg_catalog.pg_policies where schemaname = 'public' and tablename = 'profiles' and policyname = 'read own profile'),
  null, 'read own profile has no write check, since it grants no write'
);

select extensions.policy_cmd_is('public', 'profiles', 'insert own profile', 'INSERT', 'insert own profile is insert-only');
select extensions.is(
  (select roles from pg_catalog.pg_policies where schemaname = 'public' and tablename = 'profiles' and policyname = 'insert own profile'),
  '{public}'::name[], 'insert own profile applies to public'
);
select extensions.is(
  (select qual from pg_catalog.pg_policies where schemaname = 'public' and tablename = 'profiles' and policyname = 'insert own profile'),
  null, 'insert own profile has no using clause, since insert policies cannot have one'
);
select extensions.is(
  (select with_check from pg_catalog.pg_policies where schemaname = 'public' and tablename = 'profiles' and policyname = 'insert own profile'),
  '(auth.uid() = user_id)', 'insert own profile only allows inserting your own row'
);

select extensions.policy_cmd_is('public', 'profiles', 'update own profile', 'UPDATE', 'update own profile is update-only');
select extensions.is(
  (select roles from pg_catalog.pg_policies where schemaname = 'public' and tablename = 'profiles' and policyname = 'update own profile'),
  '{public}'::name[], 'update own profile applies to public'
);
select extensions.is(
  (select qual from pg_catalog.pg_policies where schemaname = 'public' and tablename = 'profiles' and policyname = 'update own profile'),
  '(auth.uid() = user_id)', 'update own profile only sees your own row'
);
select extensions.is(
  (select with_check from pg_catalog.pg_policies where schemaname = 'public' and tablename = 'profiles' and policyname = 'update own profile'),
  '(auth.uid() = user_id)', 'update own profile only lets you keep owning the row'
);

select extensions.is(
  (
    select count(*)::bigint
    from pg_catalog.pg_policies
    where schemaname = 'public'
      and tablename = 'profiles'
      and cmd in ('DELETE', 'ALL')
  ),
  0::bigint,
  'no delete policy exists: account deletion goes through the auth.users cascade'
);

-- A security definer function without a pinned search_path can be aimed
-- at an attacker-owned table of the same name, so the pin is part of the
-- contract, not a style preference.
select extensions.has_function('public', 'is_username_available', array['text'], 'is_username_available exists');
select extensions.function_returns('public', 'is_username_available', array['text'], 'boolean', 'is_username_available returns a bare boolean');
select extensions.is_definer('public', 'is_username_available', array['text'], 'is_username_available is security definer');
select extensions.volatility_is('public', 'is_username_available', array['text'], 'stable', 'is_username_available is stable');
select extensions.is(
  (
    select coalesce(array_to_string(proconfig, ' '), '') like 'search_path=%'
    from pg_catalog.pg_proc routine_proc
    join pg_catalog.pg_namespace routine_namespace on routine_namespace.oid = routine_proc.pronamespace
    where routine_namespace.nspname = 'public' and routine_proc.proname = 'is_username_available'
  ),
  true, 'is_username_available pins its search_path'
);

select extensions.has_trigger('public', 'profiles', 'profiles_cohort_is_server_assigned', 'the cohort guard trigger exists');

-- Signup can check availability as anon or authenticated, and PUBLIC holds no grant.
select extensions.function_privs_are('public', 'is_username_available', array['text'], 'anon', array['EXECUTE'], 'anon can call is_username_available');
select extensions.function_privs_are('public', 'is_username_available', array['text'], 'authenticated', array['EXECUTE'], 'authenticated can call is_username_available');
select extensions.is(
  (
    exists (
      select 1
      from pg_catalog.pg_proc routine_proc
      join pg_catalog.pg_namespace routine_namespace on routine_namespace.oid = routine_proc.pronamespace,
      unnest(coalesce(routine_proc.proacl, '{}'::aclitem[])) as acl_entry
      where routine_namespace.nspname = 'public'
        and routine_proc.proname = 'is_username_available'
        and acl_entry::text like '=%'
    )
  ),
  false, 'create function''s default PUBLIC grant was revoked'
);

-- Seed through the migration-owner role, which models service-role writes.
insert into auth.users (id, email)
values
  ('00000000-0000-0000-0000-0000000000a1', 'profile-a@example.test'),
  ('00000000-0000-0000-0000-0000000000b2', 'profile-b@example.test'),
  ('00000000-0000-0000-0000-0000000000c3', 'profile-c@example.test'),
  ('00000000-0000-0000-0000-0000000000d4', 'profile-d@example.test');

insert into public.profiles
  (user_id, username, target_english, target_math, test_date, daily_goal, cohort)
values
  ('00000000-0000-0000-0000-0000000000b2', 'bob', 650, 700, '2027-03-13', 15, 'control'),
  ('00000000-0000-0000-0000-0000000000c3', 'carol', 700, 760, null, 20, 'experiment');

select extensions.results_eq(
  $$
    select username, cohort
    from public.profiles
    order by username
  $$,
  $$
    values
      ('bob'::text, 'control'::text),
      ('carol'::text, 'experiment'::text)
  $$,
  'the service role assigns cohort freely on insert'
);

select extensions.throws_ok(
  $$
    insert into public.profiles (user_id, username, target_english, target_math)
    values ('00000000-0000-0000-0000-0000000000d4', 'danny', 190, 600)
  $$,
  '23514',
  null,
  'an english target below the 200 floor is rejected'
);

select extensions.throws_ok(
  $$
    insert into public.profiles (user_id, username, target_english, target_math)
    values ('00000000-0000-0000-0000-0000000000d4', 'danny', 810, 600)
  $$,
  '23514',
  null,
  'an english target above the 800 ceiling is rejected'
);

select extensions.throws_ok(
  $$
    insert into public.profiles (user_id, username, target_english, target_math)
    values ('00000000-0000-0000-0000-0000000000d4', 'danny', 755, 600)
  $$,
  '23514',
  null,
  'an english target off the 10-point scoring grid is rejected'
);

select extensions.throws_ok(
  $$
    insert into public.profiles (user_id, username, target_english, target_math)
    values ('00000000-0000-0000-0000-0000000000d4', 'danny', 600, 810)
  $$,
  '23514',
  null,
  'a math target above the 800 ceiling is rejected'
);

select extensions.throws_ok(
  $$
    insert into public.profiles (user_id, username, target_english, target_math)
    values ('00000000-0000-0000-0000-0000000000d4', 'danny', 600, 755)
  $$,
  '23514',
  null,
  'a math target off the 10-point scoring grid is rejected'
);

select extensions.throws_ok(
  $$
    insert into public.profiles (user_id, username, target_english, target_math, daily_goal)
    values ('00000000-0000-0000-0000-0000000000d4', 'danny', 600, 600, 0)
  $$,
  '23514',
  null,
  'a daily goal of zero questions is rejected'
);

select extensions.throws_ok(
  $$
    insert into public.profiles (user_id, username, target_english, target_math, daily_goal)
    values ('00000000-0000-0000-0000-0000000000d4', 'danny', 600, 600, 101)
  $$,
  '23514',
  null,
  'a daily goal past 100 questions is rejected'
);

select extensions.throws_ok(
  $$
    insert into public.profiles (user_id, username, target_english, target_math)
    values ('00000000-0000-0000-0000-0000000000d4', 'ab', 600, 600)
  $$,
  '23514',
  null,
  'a username under three characters is rejected'
);

select extensions.throws_ok(
  $$
    insert into public.profiles (user_id, username, target_english, target_math)
    values ('00000000-0000-0000-0000-0000000000d4', 'dannydannydannydannyd', 600, 600)
  $$,
  '23514',
  null,
  'a username over twenty characters is rejected'
);

select extensions.throws_ok(
  $$
    insert into public.profiles (user_id, username, target_english, target_math)
    values ('00000000-0000-0000-0000-0000000000d4', 'Danny', 600, 600)
  $$,
  '23514',
  null,
  'an uppercase username is rejected rather than silently folded'
);

select extensions.throws_ok(
  $$
    insert into public.profiles (user_id, username, target_english, target_math)
    values ('00000000-0000-0000-0000-0000000000d4', 'dan-ny', 600, 600)
  $$,
  '23514',
  null,
  'a username outside [a-z0-9_] is rejected'
);

select extensions.throws_ok(
  $$
    insert into public.profiles (user_id, username, target_english, target_math)
    values ('00000000-0000-0000-0000-0000000000d4', 'bob', 600, 600)
  $$,
  '23505',
  null,
  'two users cannot hold the same username'
);

select extensions.throws_ok(
  $$
    insert into public.profiles (user_id, username, target_english, target_math)
    values ('00000000-0000-0000-0000-000000000099', 'ghost', 600, 600)
  $$,
  '23503',
  null,
  'a profile cannot outlive or bypass auth users'
);

select extensions.lives_ok(
  $$
    insert into public.profiles (user_id, username, target_english, target_math, daily_goal)
    values ('00000000-0000-0000-0000-0000000000d4', 'd_4', 200, 800, 1)
  $$,
  'the boundary values of every range are accepted'
);

select extensions.results_eq(
  $$
    select username, target_english, target_math, daily_goal, test_date, cohort
    from public.profiles
    where user_id = '00000000-0000-0000-0000-0000000000d4'
  $$,
  $$values ('d_4'::text, 200, 800, 1, null::date, null::text)$$,
  'test_date and cohort stay null when nobody supplies them'
);

-- Exercise policy behavior as real client roles, not only through catalogs.
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000a1';

select extensions.lives_ok(
  $$
    insert into public.profiles
      (user_id, username, target_english, target_math, test_date, daily_goal, cohort)
    values (
      '00000000-0000-0000-0000-0000000000a1',
      'alice',
      600,
      780,
      '2027-05-01',
      25,
      'self-assigned'
    )
  $$,
  'a user can create their own profile'
);

select extensions.results_eq(
  $$
    select username, target_english, target_math, test_date, daily_goal, cohort
    from public.profiles
    where user_id = '00000000-0000-0000-0000-0000000000a1'
  $$,
  $$values ('alice'::text, 600, 780, '2027-05-01'::date, 25, null::text)$$,
  'the new profile keeps the submitted answers but never a client-supplied cohort'
);

select extensions.throws_ok(
  $$
    insert into public.profiles (user_id, username, target_english, target_math)
    values ('00000000-0000-0000-0000-0000000000b2', 'imposter', 600, 600)
  $$,
  '42501',
  null,
  'a user cannot create a profile owned by somebody else'
);

select extensions.results_eq(
  $$select user_id::text, username from public.profiles$$,
  $$values ('00000000-0000-0000-0000-0000000000a1'::text, 'alice'::text)$$,
  'a user reads only their own profile row'
);

select extensions.is(
  (
    select count(*)::bigint
    from public.profiles
    where user_id = '00000000-0000-0000-0000-0000000000b2'
  ),
  0::bigint,
  'another user''s profile stays invisible even when asked for by id'
);

update public.profiles
set daily_goal = 40, target_math = 800, test_date = '2027-06-05'
where user_id = '00000000-0000-0000-0000-0000000000a1';

select extensions.results_eq(
  $$
    select daily_goal, target_math, test_date
    from public.profiles
    where user_id = '00000000-0000-0000-0000-0000000000a1'
  $$,
  $$values (40, 800, '2027-06-05'::date)$$,
  'a user can update their own profile'
);

select extensions.results_eq(
  $$
    with attempted_update as (
      update public.profiles
      set daily_goal = 99, username = 'stolen'
      where user_id = '00000000-0000-0000-0000-0000000000b2'
      returning user_id::text
    )
    select user_id from attempted_update
  $$,
  $$select null::text where false$$,
  'a user''s update cannot reach another user''s profile'
);

select extensions.results_eq(
  $$
    with attempted_delete as (
      delete from public.profiles
      where user_id = '00000000-0000-0000-0000-0000000000a1'
      returning user_id::text
    )
    select user_id from attempted_delete
  $$,
  $$select null::text where false$$,
  'with no delete policy a user cannot delete even their own profile'
);

select extensions.is(
  (select count(*)::bigint from public.profiles),
  1::bigint,
  'the profile survives the delete attempt'
);

-- Back to the migration owner, standing in for an Edge Function running
-- as the service role, to assign the cohort the client could not.
reset role;

update public.profiles
set cohort = 'ios-launch'
where user_id = '00000000-0000-0000-0000-0000000000a1';

select extensions.results_eq(
  $$
    select cohort
    from public.profiles
    where user_id = '00000000-0000-0000-0000-0000000000a1'
  $$,
  $$values ('ios-launch'::text)$$,
  'the service role can still change cohort on update'
);

set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000a1';

select extensions.lives_ok(
  $$
    update public.profiles
    set cohort = 'hand-picked', daily_goal = 45
    where user_id = '00000000-0000-0000-0000-0000000000a1'
  $$,
  'a client cohort write is dropped rather than failing the whole update'
);

select extensions.results_eq(
  $$
    select cohort, daily_goal
    from public.profiles
    where user_id = '00000000-0000-0000-0000-0000000000a1'
  $$,
  $$values ('ios-launch'::text, 45)$$,
  'the server-assigned cohort survives a client update that tried to change it'
);

-- Same guard, reached through the JWT role claim instead of the database
-- role: a privileged connection carrying an end-user JWT is still a
-- client write as far as cohort is concerned.
reset role;
set local request.jwt.claim.role = 'authenticated';

select extensions.lives_ok(
  $$
    update public.profiles
    set cohort = 'jwt-claimed'
    where user_id = '00000000-0000-0000-0000-0000000000a1'
  $$,
  'a write carrying an authenticated JWT role claim is accepted'
);

select extensions.results_eq(
  $$
    select cohort
    from public.profiles
    where user_id = '00000000-0000-0000-0000-0000000000a1'
  $$,
  $$values ('ios-launch'::text)$$,
  'the cohort guard keys off the JWT role claim, not only the database role'
);

set local request.jwt.claim.role = '';

select extensions.results_eq(
  $$
    select username, daily_goal, cohort
    from public.profiles
    where user_id = '00000000-0000-0000-0000-0000000000b2'
  $$,
  $$values ('bob'::text, 15, 'control'::text)$$,
  'user B''s profile is byte-for-byte untouched by user A''s write attempts'
);

reset role;
set local role anon;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000099';

select extensions.is(
  (select count(*)::bigint from public.profiles),
  0::bigint,
  'an anonymous client reads nothing from profiles'
);

select extensions.throws_ok(
  $$
    insert into public.profiles (user_id, username, target_english, target_math)
    values ('00000000-0000-0000-0000-0000000000a1', 'anon_grab', 600, 600)
  $$,
  '42501',
  null,
  'an anonymous client cannot create a profile'
);

select extensions.ok(
  public.is_username_available('free_name'),
  'an unclaimed username is reported available pre-auth'
);

select extensions.ok(
  not public.is_username_available('bob'),
  'a seeded username is reported unavailable pre-auth'
);

select extensions.ok(
  not public.is_username_available('alice'),
  'a username claimed during signup becomes unavailable immediately'
);

select extensions.is(
  pg_typeof(public.is_username_available('bob'))::text,
  'boolean'::text,
  'the availability check hands back a bare boolean, not a row'
);

select extensions.is(
  (
    select count(*)::bigint
    from public.profiles
    where username in ('bob', 'alice')
  ),
  0::bigint,
  'the availability check leaks nothing: those profiles stay unreadable to anon'
);

reset role;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000b2';

select extensions.ok(
  not public.is_username_available('alice'),
  'another user''s username is reported unavailable to a signed-in user'
);

select extensions.is(
  (select count(*)::bigint from public.profiles where username = 'alice'),
  0::bigint,
  'the availability check does not widen what user B can read'
);

select extensions.results_eq(
  $$select username from public.profiles$$,
  $$values ('bob'::text)$$,
  'user B still sees only their own profile after calling the availability check'
);

reset role;

delete from auth.users where id = '00000000-0000-0000-0000-0000000000c3';

select extensions.is(
  (
    select count(*)::bigint
    from public.profiles
    where user_id = '00000000-0000-0000-0000-0000000000c3'
  ),
  0::bigint,
  'deleting the auth user removes the profile, so no delete policy is needed'
);

select extensions.ok(
  public.is_username_available('carol'),
  'a username frees up once its auth user is deleted'
);

select * from extensions.finish();
rollback;
