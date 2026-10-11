// Called when the gate opens, before any question is shown. Advances
// pass_state's rolling-hour entry window and returns how many questions
// are owed for this entry. This is the only function allowed to write
// pass_state.entries_this_hour / hour_window_started. It also sets
// questions_owed, which grade-attempt counts down.
//
// A free entry (nothing owed) gets its pass here, since no question will
// be graded for it. This is the one place besides grade-attempt that sets
// pass_expires_at.
//
// The schema stores one window-start timestamp plus a count, not a log
// of individual entry times, so this is a tumbling window (it resets
// once a full hour has elapsed since it opened) rather than a true
// sliding window. That's a property of the schema, not a shortcut taken
// here.
import { costForEntry } from "./cost.ts";
import { freeEntryPassSeconds, parsePlatform } from "../_shared/grading.ts";
import {
  jsonResponse,
  preflight,
  readJson,
  requireUser,
  serviceClient,
} from "../_shared/http.ts";

const WINDOW_MS = 60 * 60 * 1000;

Deno.serve(async (req) => {
  const early = preflight(req);
  if (early) return early;

  const auth = await requireUser(req);
  if ("response" in auth) return auth.response;
  const userId = auth.userId;

  let body: Record<string, unknown>;
  try {
    body = (await readJson(req)) as Record<string, unknown>;
  } catch {
    return jsonResponse({ error: "invalid JSON body" }, 400);
  }
  const platform = parsePlatform(body?.platform);
  if (!platform) {
    return jsonResponse({ error: "platform must be 'ios' or 'android'" }, 400);
  }

  const now = new Date();
  const db = serviceClient();

  const { data: existing, error: fetchError } = await db
    .from("pass_state")
    .select("entries_this_hour, hour_window_started")
    .eq("user_id", userId)
    .maybeSingle();
  if (fetchError) {
    return jsonResponse({ error: "failed to read pass state" }, 500);
  }

  const windowStarted = existing?.hour_window_started
    ? new Date(existing.hour_window_started)
    : null;
  const windowExpired = !windowStarted ||
    now.getTime() - windowStarted.getTime() >= WINDOW_MS;

  const entriesThisHour = windowExpired
    ? 1
    : (existing?.entries_this_hour ?? 0) + 1;
  const windowStartedAt = windowExpired ? now : windowStarted;

  const questionsOwed = costForEntry(entriesThisHour);
  const passExpiresAt = questionsOwed === 0
    ? new Date(now.getTime() + freeEntryPassSeconds(platform) * 1000)
    : null;

  const update: Record<string, unknown> = {
    user_id: userId,
    entries_this_hour: entriesThisHour,
    hour_window_started: windowStartedAt.toISOString(),
    questions_owed: questionsOwed,
    updated_at: now.toISOString(),
  };
  if (passExpiresAt) update.pass_expires_at = passExpiresAt.toISOString();

  const { error: writeError } = await db
    .from("pass_state")
    .upsert(update, { onConflict: "user_id" });
  if (writeError) {
    return jsonResponse({ error: "failed to update pass state" }, 500);
  }

  return jsonResponse({
    questions_owed: questionsOwed,
    entries_this_hour: entriesThisHour,
    window_started_at: windowStartedAt.toISOString(),
    pass_expires_at: passExpiresAt?.toISOString() ?? null,
  });
});
