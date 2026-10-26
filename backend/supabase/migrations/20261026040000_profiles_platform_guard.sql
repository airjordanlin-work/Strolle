-- profiles.platform feeds pass_state.platform (NOT NULL), which
-- register-entry copies from here on a user's first entry. The owner-
-- scoped update policy lets a client rewrite any column of their own
-- row, so without a guard a user could flip platform after onboarding
-- and have it propagate into new pass_state rows.
--
-- Same shape as profiles_force_server_cohort() in
-- 20261011220818_profiles.sql: client writes are coerced rather than
-- rejected, so a profile update that echoes back or nulls platform does
-- not fail the whole statement. The difference is that platform is
-- client-set once rather than server-assigned: a client may write it
-- on insert, or on update while it is still null (profiles that predate
-- the column), and after that it is frozen. The service role and the
-- migration owner are left alone so a wrong value can still be fixed.
--
-- A writer is treated as a client when either the JWT role claim says
-- so (auth.role()) or the Postgres role does (current_user); security
-- invoker is required for the current_user check to mean anything.
create function public.profiles_lock_platform()
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
  if writer_is_client and tg_op = 'UPDATE' and old.platform is not null then
    new.platform := old.platform;
  end if;

  return new;
end;
$$;

create trigger profiles_platform_is_write_once
  before update on public.profiles
  for each row execute function public.profiles_lock_platform();
