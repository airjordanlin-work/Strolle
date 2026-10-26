begin;

create extension if not exists pgtap with schema extensions;

select extensions.plan(17);

select extensions.has_function('public', 'profiles_lock_platform', 'the platform guard function exists');
select extensions.has_trigger('public', 'profiles', 'profiles_platform_is_write_once', 'the platform guard trigger exists');

-- Seed through the migration-owner role, which models service-role writes.
-- Carol's profile predates the platform column, so hers starts null.
insert into auth.users (id, email)
values
  ('00000000-0000-0000-0000-0000000000e1', 'platform-a@example.test'),
  ('00000000-0000-0000-0000-0000000000e3', 'platform-c@example.test');

insert into public.profiles (user_id, username, target_english, target_math)
values ('00000000-0000-0000-0000-0000000000e3', 'carol_p', 700, 760);

set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000e1';

select extensions.lives_ok(
  $$
    insert into public.profiles (user_id, username, target_english, target_math, platform)
    values ('00000000-0000-0000-0000-0000000000e1', 'alice_p', 600, 780, 'ios')
  $$,
  'a user can set platform when creating their profile'
);

select extensions.results_eq(
  $$select platform::text from public.profiles where user_id = '00000000-0000-0000-0000-0000000000e1'$$,
  $$values ('ios'::text)$$,
  'the platform written at onboarding is kept'
);

select extensions.lives_ok(
  $$
    update public.profiles
    set platform = 'android', daily_goal = 30
    where user_id = '00000000-0000-0000-0000-0000000000e1'
  $$,
  'a client platform change is dropped rather than failing the whole update'
);

select extensions.results_eq(
  $$select platform::text, daily_goal from public.profiles where user_id = '00000000-0000-0000-0000-0000000000e1'$$,
  $$values ('ios'::text, 30)$$,
  'platform stays put while the rest of the update still applies'
);

select extensions.lives_ok(
  $$
    update public.profiles set platform = 'ios'
    where user_id = '00000000-0000-0000-0000-0000000000e1'
  $$,
  'echoing the current platform back is accepted'
);

select extensions.lives_ok(
  $$
    update public.profiles set platform = null
    where user_id = '00000000-0000-0000-0000-0000000000e1'
  $$,
  'a client cannot null platform out to re-open it'
);

select extensions.results_eq(
  $$select platform::text from public.profiles where user_id = '00000000-0000-0000-0000-0000000000e1'$$,
  $$values ('ios'::text)$$,
  'platform survives both the echo and the null write'
);

-- Same guard, reached through the JWT role claim instead of the database role.
reset role;
set local request.jwt.claim.role = 'authenticated';

select extensions.lives_ok(
  $$
    update public.profiles set platform = 'android'
    where user_id = '00000000-0000-0000-0000-0000000000e1'
  $$,
  'a write carrying an authenticated JWT role claim is accepted'
);

select extensions.results_eq(
  $$select platform::text from public.profiles where user_id = '00000000-0000-0000-0000-0000000000e1'$$,
  $$values ('ios'::text)$$,
  'the platform guard keys off the JWT role claim, not only the database role'
);

set local request.jwt.claim.role = '';

-- The migration owner, standing in for the service role, can still correct it.
select extensions.lives_ok(
  $$
    update public.profiles set platform = 'android'
    where user_id = '00000000-0000-0000-0000-0000000000e1'
  $$,
  'the service role can change platform'
);

select extensions.results_eq(
  $$select platform::text from public.profiles where user_id = '00000000-0000-0000-0000-0000000000e1'$$,
  $$values ('android'::text)$$,
  'the service role change sticks'
);

-- A profile whose platform is still null can be given one by its owner, once.
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000e3';

select extensions.lives_ok(
  $$
    update public.profiles set platform = 'android'
    where user_id = '00000000-0000-0000-0000-0000000000e3'
  $$,
  'a user can set platform while it is still null'
);

select extensions.results_eq(
  $$select platform::text from public.profiles where user_id = '00000000-0000-0000-0000-0000000000e3'$$,
  $$values ('android'::text)$$,
  'the first platform write on a null profile is kept'
);

select extensions.lives_ok(
  $$
    update public.profiles set platform = 'ios'
    where user_id = '00000000-0000-0000-0000-0000000000e3'
  $$,
  'a second client platform write is accepted but ignored'
);

select extensions.results_eq(
  $$select platform::text from public.profiles where user_id = '00000000-0000-0000-0000-0000000000e3'$$,
  $$values ('android'::text)$$,
  'platform is frozen once it has been set'
);

select * from extensions.finish();
rollback;
