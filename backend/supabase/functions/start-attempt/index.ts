// Picks the next gate (or session) question for the signed-in user and
// opens an attempt row for it. The row's started_at is what lets
// grade-attempt measure response time on the server instead of trusting
// the client, which is how it spots guesses.
//
// All the choosing happens in _shared/adaptive.ts (pure, unit tested).
// This file only loads the user's state, calls selectNext, and records
// the attempt. It never returns correct_index or the explanation: those
// stay on the server until the answer is graded.
//
// Bank source is the copy bundled with grade-attempt, so the two
// functions can't disagree about what a question id means. _shared/skills.json
// is a copy of content/question_bank/skills.json (the source), kept by hand
// like the questions copies, because functions deploy without the repo root. Until a person
// sets `reviewed: true` on an item it is not served; set
// ALLOW_UNREVIEWED_QUESTIONS=true on a dev stack to serve the seed bank.
import { createClient } from "npm:@supabase/supabase-js@2";
import questionData from "../grade-attempt/questions.json" with { type: "json" };
import taxonomy from "../_shared/skills.json" with { type: "json" };
import {
  type BankItem,
  domainsFromTaxonomy,
  type FourD,
  selectNext,
  type Tier,
  weightsFromTaxonomy,
} from "../_shared/adaptive.ts";

type StoredQuestion = BankItem & {
  section: string;
  stem: string;
  passage?: string;
  choices: string[];
  reviewed?: boolean;
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const ALLOW_UNREVIEWED = Deno.env.get("ALLOW_UNREVIEWED_QUESTIONS") === "true";

const allQuestions = questionData as unknown as StoredQuestion[];
const bank = allQuestions.filter((q) => ALLOW_UNREVIEWED || q.reviewed === true);
const byId = new Map(allQuestions.map((q) => [q.id, q]));
const skillWeights = weightsFromTaxonomy(taxonomy.domains);
const skillDomains = domainsFromTaxonomy(taxonomy.domains);

const HISTORY_LIMIT = 100; // scored answers fed to the selector
const SESSION_GAP_MS = 30 * 60_000; // a longer pause starts a new session
const RECENT_FOUR_D = 5;

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

  let payload: { tier?: unknown; mode?: unknown } = {};
  try {
    payload = (await req.json()) ?? {};
  } catch {
    // An empty body is fine: defaults to the gate tier.
  }
  if (typeof payload !== "object") {
    return jsonResponse({ error: "body must be a JSON object" }, 400);
  }
  const tier = payload.tier ?? "gate";
  if (tier !== "gate" && tier !== "session") {
    return jsonResponse({ error: "tier must be 'gate' or 'session'" }, 400);
  }
  // mode "diagnostic" is the onboarding hook: forces the cold-start
  // diagnostic on. Omitted, it runs by itself for a user with no history.
  if (payload.mode !== undefined && payload.mode !== "diagnostic") {
    return jsonResponse({ error: "mode, if given, must be 'diagnostic'" }, 400);
  }

  const db = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
  const [abilityRes, reviewRes, attemptRes] = await Promise.all([
    db.from("skill_ability").select("skill, rating, attempts")
      .eq("user_id", userId),
    db.from("review_items").select("question_id, due_at").eq("user_id", userId),
    db.from("attempts").select("question_id, started_at, answered_at, result")
      .eq("user_id", userId)
      .order("started_at", { ascending: false })
      .limit(HISTORY_LIMIT),
  ]);
  if (abilityRes.error || reviewRes.error || attemptRes.error) {
    return jsonResponse({ error: "failed to load user state" }, 500);
  }

  const abilities: Record<string, { rating: number; attempts: number }> = {};
  for (const a of abilityRes.data) {
    abilities[a.skill] = { rating: a.rating, attempts: a.attempts };
  }
  const reviews: Record<string, { dueAt: Date }> = {};
  for (const r of reviewRes.data) {
    reviews[r.question_id] = { dueAt: new Date(r.due_at) };
  }

  const now = new Date();
  const newestLast = [...attemptRes.data].reverse(); // rows came newest first
  const history = newestLast
    .filter((a) => a.answered_at && (a.result === "correct" || a.result === "incorrect"))
    .flatMap((a) => {
      const q = byId.get(a.question_id);
      return q ? [{ skill: q.skill, correct: a.result === "correct" }] : [];
    });
  // "This session" = the run of attempts with no pause over SESSION_GAP_MS,
  // ending now. Unanswered attempts count: they were served.
  const session: StoredQuestion[] = [];
  let cursor = now.getTime();
  for (const a of [...newestLast].reverse()) {
    const t = new Date(a.started_at).getTime();
    if (cursor - t > SESSION_GAP_MS) break;
    cursor = t;
    const q = byId.get(a.question_id);
    if (q) session.unshift(q);
  }

  const selection = selectNext({
    now,
    tier: tier as Tier,
    bank,
    abilities,
    reviews,
    skillWeights,
    skillDomains,
    history,
    recentSkills: session.map((q) => q.skill),
    recentFourD: session.slice(-RECENT_FOUR_D).map((q) => q.four_d as FourD),
    diagnostic: payload.mode === "diagnostic" ? true : undefined,
  });
  if (!selection) {
    return jsonResponse({ error: "no questions available for this tier" }, 404);
  }

  const q = byId.get(selection.item.id)!;
  const { data: attempt, error: attemptError } = await db
    .from("attempts")
    .insert({ user_id: userId, question_id: q.id, started_at: now.toISOString() })
    .select("id")
    .single();
  if (attemptError) {
    return jsonResponse({ error: "failed to open attempt" }, 500);
  }

  return jsonResponse({
    attempt_id: attempt.id,
    reason: selection.reason,
    question: {
      id: q.id,
      section: q.section,
      skill: q.skill,
      tier: q.tier,
      four_d: q.four_d,
      stem: q.stem,
      passage: q.passage ?? null,
      choices: q.choices,
      time_target_seconds: q.time_target_seconds ?? null,
    },
  });
});
