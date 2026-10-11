// Scores a gate answer server-side and updates the things only the
// grading path may write: pass_expires_at (plus the owed-question
// countdown) in pass_state, review_items, and the gate_serves row.
//
// The client sends the attempt_id it got from start-attempt plus its
// choice_index. Correctness is decided against the bundled question set,
// and answer time is measured between the two server timestamps, so
// neither is taken from the client.
//
// _shared/questions.json is a generated copy of
// content/question_bank/questions.json. Don't edit it by hand; run
// `python3 content/question_bank/sync.py` after changing the bank.
//
// The rules themselves (interval math, pass length, guess threshold, owed
// countdown) live in _shared/grading.ts so they can be unit tested.
//
// Known gap: the pass_state read and write are two calls, so two answers
// racing for the same user can double-count. The design doc's single
// gate_answer Postgres function fixes this.
import questionData from "../_shared/questions.json" with { type: "json" };
import {
  isTooFast,
  nextReview,
  parseGradeRequest,
  passLengthSeconds,
  remainingAfterAnswer,
} from "../_shared/grading.ts";
import {
  jsonResponse,
  preflight,
  readJson,
  requireUser,
  serviceClient,
} from "../_shared/http.ts";

type StoredQuestion = {
  id: string;
  choices: string[];
  correct_index: number;
};
const questions = questionData as StoredQuestion[];

Deno.serve(async (req) => {
  const early = preflight(req);
  if (early) return early;

  const auth = await requireUser(req);
  if ("response" in auth) return auth.response;
  const userId = auth.userId;

  let body: unknown;
  try {
    body = await readJson(req);
  } catch {
    return jsonResponse({ error: "invalid JSON body" }, 400);
  }
  const parsed = parseGradeRequest(body);
  if ("error" in parsed) {
    return jsonResponse({ error: parsed.error }, 400);
  }
  const { attempt_id, choice_index, platform } = parsed.request;
  const db = serviceClient();

  const { data: serve, error: serveError } = await db
    .from("gate_serves")
    .select("question_id, graded_at")
    .eq("id", attempt_id)
    .eq("user_id", userId)
    .maybeSingle();
  if (serveError) {
    return jsonResponse({ error: "failed to read attempt" }, 500);
  }
  if (!serve) {
    return jsonResponse({ error: "unknown attempt_id" }, 404);
  }
  if (serve.graded_at) {
    return jsonResponse({ error: "attempt already graded" }, 409);
  }

  const question = questions.find((q) => q.id === serve.question_id);
  if (!question) {
    return jsonResponse({ error: "question no longer in the bank" }, 410);
  }
  if (choice_index < 0 || choice_index >= question.choices.length) {
    return jsonResponse({ error: "choice_index out of range" }, 400);
  }

  // Claim the attempt. The graded_at check makes this the single winner
  // if the same attempt is submitted twice at once.
  const { data: claimed, error: claimError } = await db
    .from("gate_serves")
    .update({ graded_at: new Date().toISOString() })
    .eq("id", attempt_id)
    .is("graded_at", null)
    .select("served_at, graded_at")
    .maybeSingle();
  if (claimError) {
    return jsonResponse({ error: "failed to grade attempt" }, 500);
  }
  if (!claimed) {
    return jsonResponse({ error: "attempt already graded" }, 409);
  }

  const now = new Date(claimed.graded_at);
  const elapsedMs = now.getTime() - new Date(claimed.served_at).getTime();
  const correct = choice_index === question.correct_index;

  // Under the guess threshold: not a rep. Only the attempt is recorded.
  if (isTooFast(elapsedMs)) {
    await db.from("gate_serves").update({ outcome: "too_fast" })
      .eq("id", attempt_id);
    return jsonResponse({ scored: false, too_fast: true, elapsed_ms: elapsedMs });
  }

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
      .eq("question_id", question.id)
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
      question_id: question.id,
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

  const [{ error: passError }, { error: outcomeError }] = await Promise.all([
    db.from("pass_state").upsert(passUpdate, { onConflict: "user_id" }),
    db.from("gate_serves")
      .update({ outcome: correct ? "correct" : "incorrect" })
      .eq("id", attempt_id),
  ]);
  if (passError || outcomeError) {
    return jsonResponse({ error: "failed to update pass state" }, 500);
  }

  return jsonResponse({
    scored: true,
    correct,
    elapsed_ms: elapsedMs,
    questions_remaining: remaining,
    pass_expires_at: passExpiresAt?.toISOString() ?? null,
    review_item: {
      question_id: question.id,
      due_at: review.dueAt.toISOString(),
      interval_minutes: review.intervalMinutes,
      streak: review.streak,
    },
  });
});
