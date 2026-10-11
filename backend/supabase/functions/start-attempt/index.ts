// Called when a gate question is put on screen. Records a gate_serves row
// stamped with the server clock and returns its id; the client sends
// that id back to grade-attempt, which measures the answer time from it.
// This is what makes the 2-second guess threshold server-side.
//
// The client still chooses the question for now. Moving selection here
// (via _shared/adaptive.ts) is a later change.
import questionData from "../_shared/questions.json" with { type: "json" };
import {
  jsonResponse,
  preflight,
  readJson,
  requireUser,
  serviceClient,
} from "../_shared/http.ts";

type StoredQuestion = { id: string; tier: "gate" | "session" };
const questions = questionData as StoredQuestion[];

Deno.serve(async (req) => {
  const early = preflight(req);
  if (early) return early;

  const auth = await requireUser(req);
  if ("response" in auth) return auth.response;

  let body: Record<string, unknown>;
  try {
    body = (await readJson(req)) as Record<string, unknown>;
  } catch {
    return jsonResponse({ error: "invalid JSON body" }, 400);
  }
  const questionId = body?.question_id;
  if (typeof questionId !== "string") {
    return jsonResponse({ error: "question_id (string) required" }, 400);
  }

  const question = questions.find((q) => q.id === questionId);
  if (!question) {
    return jsonResponse({ error: "unknown question_id" }, 404);
  }
  if (question.tier !== "gate") {
    return jsonResponse({ error: "not a gate question" }, 400);
  }

  const { data, error } = await serviceClient()
    .from("gate_serves")
    .insert({
      user_id: auth.userId,
      question_id: questionId,
      served_at: new Date().toISOString(),
    })
    .select("id, served_at")
    .single();
  if (error || !data) {
    return jsonResponse({ error: "failed to record attempt" }, 500);
  }

  return jsonResponse({
    attempt_id: data.id,
    question_id: questionId,
    served_at: data.served_at,
  });
});
