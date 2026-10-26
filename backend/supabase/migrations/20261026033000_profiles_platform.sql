-- pass_state.platform is NOT NULL, and the Edge Functions that create
-- pass_state rows (register-entry, grade-attempt) need to know it
-- without trusting a per-request value. The profile is set once at
-- onboarding, so they read it from here when no pass_state row exists.
--
-- Nullable so existing profiles stay valid; the functions return 400
-- until the client has written it. Uses the device_platform enum from
-- 0001_init.sql. The existing owner-scoped insert/update policies
-- already cover this column.

alter table public.profiles
  add column platform device_platform;
