// Called when the gate opens, before any question is shown. Advances
// pass_state's rolling-hour entry window and returns how many questions
// are owed for this entry. This is the only function allowed to write
// pass_state.entries_this_window / window_started_at — grade-attempt
// owns pass_expires_at and review_items, and this function never
// touches either.
//
// The schema stores one window-start timestamp plus a count, not a log
// of individual entry times, so this is a tumbling window (it resets
// once a full hour has elapsed since it opened) rather than a true
// sliding window. That's a property of the schema, not a shortcut taken
// here.
import { createClient } from "npm:@supabase/supabase-js@2";
import { costForEntry } from "./cost.ts";

const WINDOW_MS = 60 * 60 * 1000;

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return jsonResponse({ error: "method not allowed" }, 405);
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return jsonResponse({ error: "missing Authorization header" }, 401);
  }

  const authedClient = createClient(SUPABASE_URL, ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData, error: userError } = await authedClient.auth
    .getUser();
  if (userError || !userData.user) {
    return jsonResponse({ error: "invalid session" }, 401);
  }
  const userId = userData.user.id;

  // The body carries no fields today, so an empty body is fine. A body
  // that is present must still be a JSON object: a literal `null` parses
  // without error but is not usable, so it is rejected here as a 400
  // rather than left to fail later.
  const rawBody = await req.text();
  if (rawBody.trim() !== "") {
    let body: unknown;
    try {
      body = JSON.parse(rawBody);
    } catch {
      return jsonResponse({ error: "invalid JSON body" }, 400);
    }
    if (body === null || typeof body !== "object" || Array.isArray(body)) {
      return jsonResponse({ error: "body must be a JSON object" }, 400);
    }
  }

  const now = new Date();
  const db = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

  const { data: existing, error: fetchError } = await db
    .from("pass_state")
    .select("entries_this_window, window_started_at, platform")
    .eq("user_id", userId)
    .maybeSingle();
  if (fetchError) {
    return jsonResponse({ error: "failed to read pass state" }, 500);
  }

  // pass_state.platform is NOT NULL with no default, so a first-time
  // insert takes it from the profile. Existing rows keep theirs.
  let platform = existing?.platform;
  if (!platform) {
    const { data: profile, error: profileError } = await db
      .from("profiles")
      .select("platform")
      .eq("user_id", userId)
      .maybeSingle();
    if (profileError) {
      return jsonResponse({ error: "failed to read profile" }, 500);
    }
    platform = profile?.platform;
  }
  if (!platform) {
    return jsonResponse({ error: "profile platform not set" }, 400);
  }

  const windowStarted = existing?.window_started_at
    ? new Date(existing.window_started_at)
    : null;
  const windowExpired = !windowStarted ||
    now.getTime() - windowStarted.getTime() >= WINDOW_MS;

  const entriesThisWindow = windowExpired
    ? 1
    : (existing?.entries_this_window ?? 0) + 1;
  const windowStartedAt = windowExpired ? now : windowStarted;

  const { error: writeError } = await db
    .from("pass_state")
    .upsert({
      user_id: userId,
      platform,
      entries_this_window: entriesThisWindow,
      window_started_at: windowStartedAt.toISOString(),
      updated_at: now.toISOString(),
    }, { onConflict: "user_id" });
  if (writeError) {
    return jsonResponse({ error: "failed to update pass state" }, 500);
  }

  return jsonResponse({
    questions_owed: costForEntry(entriesThisWindow),
    entries_this_window: entriesThisWindow,
    window_started_at: windowStartedAt.toISOString(),
  });
});
