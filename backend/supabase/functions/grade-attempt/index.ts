// Scores a gate answer server-side and updates the two things only this
// function is allowed to write: pass_expires_at (plus the owed-question
// countdown) in pass_state, and review_items. The client sends
// question_id + choice_index; correctness is never taken from the client,
// it's decided against the bundled question set below.
//
// questions.json here is a generated copy of
// content/question_bank/questions.json. Don't edit it by hand; run
// `python3 content/question_bank/sync.py` after changing the bank.
//
// The rules themselves (interval math, pass length, guess threshold, owed
// countdown) live in grading.ts so they can be unit tested.
//
// Known gaps:
// - elapsed_ms comes from the client. Timing it server-side needs
//   /start-attempt, which doesn't exist yet.
// - The pass_state read and write are two calls, so two answers racing
//   for the same user can double-count. The design doc's single
//   gate_answer Postgres function fixes this.
import { createClient } from "npm:@supabase/supabase-js@2";
import questionData from "./questions.json" with { type: "json" };
import {
  isTooFast,
  nextReview,
  parseGradeRequest,
  passLengthSeconds,
  remainingAfterAnswer,
} from "./grading.ts";

type StoredQuestion = {
  id: string;
  tier: "gate" | "session";
  choices: string[];
  correct_index: number;
};
const questions = questionData as StoredQuestion[];

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

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "invalid JSON body" }, 400);
  }
  const parsed = parseGradeRequest(body);
  if ("error" in parsed) {
    return jsonResponse({ error: parsed.error }, 400);
  }
  const { question_id, choice_index, platform, elapsed_ms } = parsed.request;

  const question = questions.find((q) => q.id === question_id);
  if (!question) {
    return jsonResponse({ error: "unknown question_id" }, 404);
  }
  if (question.tier !== "gate") {
    return jsonResponse({ error: "not a gate question" }, 400);
  }
  if (choice_index < 0 || choice_index >= question.choices.length) {
    return jsonResponse({ error: "choice_index out of range" }, 400);
  }

  // Under the guess threshold: not a rep. Nothing is written.
  if (isTooFast(elapsed_ms)) {
    return jsonResponse({ scored: false, too_fast: true });
  }

  const correct = choice_index === question.correct_index;
  const now = new Date();
  const db = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

  const [{ data: passRow, error: passReadError }, {
    data: reviewRow,
    error: reviewReadError,
  }] = await Promise.all([
    db.from("pass_state")
      .select("questions_owed")
      .eq("user_id", userId)
      .maybeSingle(),
    db.from("review_items")
      .select("interval_minutes, streak")
      .eq("user_id", userId)
      .eq("question_id", question_id)
      .maybeSingle(),
  ]);
  if (passReadError || reviewReadError) {
    return jsonResponse({ error: "failed to read state" }, 500);
  }

  const review = nextReview(
    reviewRow
      ? { intervalMinutes: reviewRow.interval_minutes, streak: reviewRow.streak }
      : null,
    correct,
    now,
  );

  const { error: reviewError } = await db
    .from("review_items")
    .upsert({
      user_id: userId,
      question_id,
      due_at: review.dueAt.toISOString(),
      interval_minutes: review.intervalMinutes,
      streak: review.streak,
    }, { onConflict: "user_id,question_id" });
  if (reviewError) {
    return jsonResponse({ error: "failed to update review item" }, 500);
  }

  const remaining = remainingAfterAnswer(passRow?.questions_owed ?? 0);
  const passExpiresAt = remaining === 0
    ? new Date(now.getTime() + passLengthSeconds(correct, platform) * 1000)
    : null;

  const passUpdate: Record<string, unknown> = {
    user_id: userId,
    questions_owed: remaining,
    updated_at: now.toISOString(),
  };
  if (passExpiresAt) passUpdate.pass_expires_at = passExpiresAt.toISOString();

  const { error: passError } = await db
    .from("pass_state")
    .upsert(passUpdate, { onConflict: "user_id" });
  if (passError) {
    return jsonResponse({ error: "failed to update pass state" }, 500);
  }

  return jsonResponse({
    scored: true,
    correct,
    questions_remaining: remaining,
    pass_expires_at: passExpiresAt?.toISOString() ?? null,
    review_item: {
      question_id,
      due_at: review.dueAt.toISOString(),
      interval_minutes: review.intervalMinutes,
      streak: review.streak,
    },
  });
});
