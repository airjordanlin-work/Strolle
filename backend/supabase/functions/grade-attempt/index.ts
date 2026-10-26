// Scores a gate attempt server-side and updates the two tables only this
// function is allowed to write: pass_state and review_items. The client
// sends question_id + choice_index; correctness is never taken from the
// client, it's decided against the bundled question set below.
//
// questions.json here is a copy of app/assets/questions.json. Content
// sourcing (a shared table, or generation pipeline) is a separate,
// not-yet-scoped decision — this copy is a stand-in until that lands, and
// needs to stay in sync with the app bundle by hand until then.
//
// Escalating-cost / rolling-window state (pass_state.entries_this_window)
// is out of scope here — register-entry owns that, and also owns creating
// the pass_state row, so this function only updates an existing one.
import { createClient } from "npm:@supabase/supabase-js@2";
import questionData from "./questions.json" with { type: "json" };

type StoredQuestion = { id: string; choices: string[]; correct_index: number };
const questions = questionData as StoredQuestion[];

const GROWTH_FACTOR = 2.5;
const RESET_INTERVAL_MINUTES = 10;
const CAP_MINUTES = 60 * 24 * 7; // one week, matches ReviewQueue._capMinutes

const CORRECT_PASS_MINUTES = 5;
const INCORRECT_PASS_SECONDS = 90;

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

  let payload: { question_id?: string; choice_index?: number };
  try {
    payload = await req.json();
  } catch {
    return jsonResponse({ error: "invalid JSON body" }, 400);
  }
  // A literal JSON `null` (or array/primitive) parses but can't be destructured.
  if (payload === null || typeof payload !== "object" || Array.isArray(payload)) {
    return jsonResponse({ error: "body must be a JSON object" }, 400);
  }

  const { question_id, choice_index } = payload;
  if (typeof question_id !== "string" || !Number.isInteger(choice_index)) {
    return jsonResponse(
      { error: "question_id (string) and choice_index (integer) required" },
      400,
    );
  }

  const question = questions.find((q) => q.id === question_id);
  if (!question) {
    return jsonResponse({ error: "unknown question_id" }, 404);
  }

  const correct = choice_index === question.correct_index;
  const now = new Date();

  const db = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

  // register-entry owns creating pass_state and opening the entry window.
  // Grading before it has run would otherwise have to create the row
  // here, starting the rolling window without charging an entry, so
  // reject instead — and before review_items is touched.
  const { data: passRow, error: passFetchError } = await db
    .from("pass_state")
    .select("user_id")
    .eq("user_id", userId)
    .maybeSingle();
  if (passFetchError) {
    return jsonResponse({ error: "failed to read pass state" }, 500);
  }
  if (!passRow) {
    return jsonResponse({ error: "no entry registered; call register-entry first" }, 409);
  }

  const { data: existingItem, error: itemFetchError } = await db
    .from("review_items")
    .select("interval_minutes, consecutive_correct")
    .eq("user_id", userId)
    .eq("question_id", question_id)
    .maybeSingle();
  if (itemFetchError) {
    return jsonResponse({ error: "failed to read review item" }, 500);
  }

  let intervalMinutes = existingItem?.interval_minutes ??
    RESET_INTERVAL_MINUTES;
  let consecutiveCorrect = existingItem?.consecutive_correct ?? 0;

  if (correct) {
    consecutiveCorrect += 1;
    const grown = Math.round(intervalMinutes * GROWTH_FACTOR);
    intervalMinutes = Math.min(grown, CAP_MINUTES);
  } else {
    consecutiveCorrect = 0;
    intervalMinutes = RESET_INTERVAL_MINUTES;
  }

  const dueAt = new Date(now.getTime() + intervalMinutes * 60_000);

  const { error: reviewError } = await db
    .from("review_items")
    .upsert({
      user_id: userId,
      question_id: question_id,
      due_at: dueAt.toISOString(),
      interval_minutes: intervalMinutes,
      consecutive_correct: consecutiveCorrect,
    }, { onConflict: "user_id,question_id" });
  if (reviewError) {
    return jsonResponse({ error: "failed to update review item" }, 500);
  }

  const passExpiresAt = correct
    ? new Date(now.getTime() + CORRECT_PASS_MINUTES * 60_000)
    : new Date(now.getTime() + INCORRECT_PASS_SECONDS * 1_000);

  const { error: passError } = await db
    .from("pass_state")
    .update({
      pass_expires_at: passExpiresAt.toISOString(),
      updated_at: now.toISOString(),
    })
    .eq("user_id", userId);
  if (passError) {
    return jsonResponse({ error: "failed to update pass state" }, 500);
  }

  return jsonResponse({
    correct,
    pass_expires_at: passExpiresAt.toISOString(),
    review_item: {
      question_id,
      due_at: dueAt.toISOString(),
      interval_minutes: intervalMinutes,
      consecutive_correct: consecutiveCorrect,
    },
  });
});
