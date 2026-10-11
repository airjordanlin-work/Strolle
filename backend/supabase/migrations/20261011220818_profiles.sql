-- M2: the per-user profile the onboarding flow writes — username, the
-- two section score targets, an optional test date, the daily question
-- goal, and the cohort label retention instrumentation groups by.
--
-- Unlike review_items/pass_state/attempts, this is client-owned data, so
-- it is the one table where RLS has to cover insert and update as well
-- as select. Two things stay out of the client's reach:
--
--   * cohort is assigned server-side (migrations and Edge Functions
--     running as the service role). RLS can only say "this row is
--     yours", not "this column is not yours", so the guard trigger
--     below strips cohort out of client writes instead. Without it the
--     three owner-scoped policies would happily let a user pick their
--     own experiment bucket and poison the cohort numbers.
--   * there is no delete policy. Account deletion runs through
--     auth.users and the on delete cascade removes the profile with it,
--     which keeps deletion in one place instead of two.
--
-- Signup needs to check whether a username is free before the user has
-- a session, and "read own profile" deliberately cannot answer that.
-- is_username_available() closes that gap with a security definer
-- function that returns a bare boolean, so no policy has to be widened
-- into a read-other-profiles hole.

create table public.profiles (
  user_id        uuid primary key references auth.users(id) on delete cascade,
  username       text unique not null check (username ~ '^[a-z0-9_]{3,20}$'),
  target_english int  not null check (target_english between 200 and 800 and target_english % 10 = 0),
  target_math    int  not null check (target_math    between 200 and 800 and target_math    % 10 = 0),
  test_date      date,
  daily_goal     int  not null default 10 check (daily_goal between 1 and 100),
  cohort         text,
  created_at     timestamptz not null default now()
);

alter table public.profiles enable row level security;

-- Owner-scoped read/insert/update. No delete policy: see the header.
create policy "read own profile"   on public.profiles for select using (auth.uid() = user_id);
create policy "insert own profile" on public.profiles for insert with check (auth.uid() = user_id);
create policy "update own profile" on public.profiles for update
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Column-level enforcement for cohort, which the policies above cannot
-- express. Client writes are coerced rather than rejected so a legitimate
-- profile update does not fail just because the client echoed back the
-- cohort it read; the service role and the migration owner are left alone
-- so Edge Functions can still assign buckets.
--
-- The writer is treated as a client when either the JWT role claim says
-- so (auth.role(), how PostgREST traffic arrives) or the actual Postgres
-- role says so (current_user, how `set local role authenticated` and the
-- pgTAP suite model a client). Checking both means a service connection
-- that is carrying an end-user JWT is also held to the client rule.
-- security invoker is required here: the current_user check only means
-- anything if the function runs as its caller.
create function public.profiles_force_server_cohort()
returns trigger
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  writer_is_client boolean :=
    coalesce(auth.role(), '') in ('anon', 'authenticated')
    or current_user::text in ('anon', 'authenticated');
begin
  if writer_is_client then
    if tg_op = 'INSERT' then
      new.cohort := null;
    else
      new.cohort := old.cohort;
    end if;
  end if;

  return new;
end;
$$;

create trigger profiles_cohort_is_server_assigned
  before insert or update on public.profiles
  for each row execute function public.profiles_force_server_cohort();

-- Signup-time availability check. Returns only true/false, never row
-- data, so it is safe to expose pre-auth. security definer to see past
-- "read own profile"; search_path is pinned because a security definer
-- function that resolves `profiles` through the caller's search_path can
-- be pointed at an attacker-owned table of the same name.
create function public.is_username_available(candidate text)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select not exists (
    select 1 from public.profiles where username = candidate
  );
$$;

-- Username checks happen before the user has a session, so anon needs it
-- too. PUBLIC is revoked first: create function grants execute to PUBLIC
-- by default, which would hand it to every present and future role.
revoke all on function public.is_username_available(text) from public;
grant execute on function public.is_username_available(text) to anon, authenticated, service_role;
