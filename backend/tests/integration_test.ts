// Integration tests for register-entry and grade-attempt against a local
// Supabase stack. Needs, from backend/:
//
//   supabase start
//   supabase functions serve        (in another terminal)
//   deno test --node-modules-dir=none --allow-net --allow-env --allow-read tests/
//
// Every test signs up its own throwaway user, so runs don't interfere and
// the database never needs resetting between them. If the stack isn't
// reachable, the tests are skipped rather than failed.
//
// The keys below are the Supabase CLI's well-known local dev keys (same on
// every machine, never valid against a real project).
import { assert, assertEquals } from "jsr:@std/assert";
import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2";
import questionData from "../supabase/functions/grade-attempt/questions.json" with {
  type: "json",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "http://127.0.0.1:54321";
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ??
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0";
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU";

type Q = { id: string; tier: string; choices: string[]; correct_index: number };
const questions = questionData as Q[];
const gate = questions.filter((q) => q.tier === "gate");
const session = questions.find((q) => q.tier === "session")!;
const wrongChoice = (q: Q) => (q.correct_index + 1) % q.choices.length;

async function stackIsUp(): Promise<boolean> {
  try {
    const res = await fetch(`${SUPABASE_URL}/functions/v1/grade-attempt`, {
      method: "OPTIONS",
      signal: AbortSignal.timeout(2000),
    });
    await res.body?.cancel();
    return true;
  } catch {
    return false;
  }
}
const ignore = !(await stackIsUp());
if (ignore) {
  console.warn(
    `Local Supabase not reachable at ${SUPABASE_URL}; integration tests skipped.`,
  );
}

const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

interface TestUser {
  id: string;
  token: string;
  client: SupabaseClient;
}

async function newUser(): Promise<TestUser> {
  const email = `it-${crypto.randomUUID()}@local.test`;
  const password = "integration-test-password";
  const { data, error } = await admin.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
  });
  if (error) throw error;
  const client = createClient(SUPABASE_URL, ANON_KEY);
  const { data: signedIn, error: signInError } = await client.auth
    .signInWithPassword({ email, password });
  if (signInError) throw signInError;
  return { id: data.user.id, token: signedIn.session!.access_token, client };
}

async function call(
  fn: string,
  token: string | null,
  body: unknown = {},
): Promise<{ status: number; json: Record<string, unknown> }> {
  const headers: Record<string, string> = { "content-type": "application/json" };
  if (token) headers.authorization = `Bearer ${token}`;
  const res = await fetch(`${SUPABASE_URL}/functions/v1/${fn}`, {
    method: "POST",
    headers,
    body: JSON.stringify(body),
  });
  return { status: res.status, json: await res.json() };
}

function secondsUntil(iso: unknown): number {
  return Math.round((new Date(iso as string).getTime() - Date.now()) / 1000);
}

Deno.test({
  name: "a correct answer writes the review item and a 5-minute pass",
  ignore,
  async fn() {
    const user = await newUser();
    const q = gate[0];
    const { status, json } = await call("grade-attempt", user.token, {
      question_id: q.id,
      choice_index: q.correct_index,
      elapsed_ms: 4000,
    });
    assertEquals(status, 200);
    assertEquals(json.correct, true);
    assertEquals(json.questions_remaining, 0);
    const left = secondsUntil(json.pass_expires_at);
    assert(left > 290 && left <= 300, `pass ends in ${left}s`);

    const { data: review } = await admin.from("review_items")
      .select("interval_minutes, streak")
      .eq("user_id", user.id).eq("question_id", q.id).single();
    assertEquals(review, { interval_minutes: 25, streak: 1 });

    const { data: pass } = await admin.from("pass_state")
      .select("pass_expires_at, questions_owed")
      .eq("user_id", user.id).single();
    assertEquals(pass!.questions_owed, 0);
    assertEquals(
      new Date(pass!.pass_expires_at).getTime(),
      new Date(json.pass_expires_at as string).getTime(),
    );
  },
});

Deno.test({
  name: "a wrong answer still grants entry: 90 s on Android, 5 min on iOS",
  ignore,
  async fn() {
    const q = gate[1];
    const android = await newUser();
    const a = await call("grade-attempt", android.token, {
      question_id: q.id,
      choice_index: wrongChoice(q),
      platform: "android",
    });
    assertEquals(a.json.correct, false);
    const aLeft = secondsUntil(a.json.pass_expires_at);
    assert(aLeft > 80 && aLeft <= 90, `android pass ends in ${aLeft}s`);
    assertEquals((a.json.review_item as { streak: number }).streak, 0);

    const ios = await newUser();
    const i = await call("grade-attempt", ios.token, {
      question_id: q.id,
      choice_index: wrongChoice(q),
      platform: "ios",
    });
    const iLeft = secondsUntil(i.json.pass_expires_at);
    assert(iLeft > 290 && iLeft <= 300, `ios pass ends in ${iLeft}s`);
  },
});

Deno.test({
  name: "a too-fast answer is discarded and writes nothing",
  ignore,
  async fn() {
    const user = await newUser();
    const q = gate[2];
    const { status, json } = await call("grade-attempt", user.token, {
      question_id: q.id,
      choice_index: q.correct_index,
      elapsed_ms: 500,
    });
    assertEquals(status, 200);
    assertEquals(json, { scored: false, too_fast: true });

    const { count } = await admin.from("review_items")
      .select("*", { count: "exact", head: true })
      .eq("user_id", user.id);
    assertEquals(count, 0);
  },
});

Deno.test({
  name: "escalating cost: the pass only comes after every owed question",
  ignore,
  async fn() {
    const user = await newUser();
    const owed = [];
    for (let i = 0; i < 3; i++) {
      const { json } = await call("register-entry", user.token);
      owed.push(json.questions_owed);
    }
    assertEquals(owed, [0, 1, 2]);

    const first = await call("grade-attempt", user.token, {
      question_id: gate[3].id,
      choice_index: gate[3].correct_index,
    });
    assertEquals(first.json.questions_remaining, 1);
    assertEquals(first.json.pass_expires_at, null);

    const second = await call("grade-attempt", user.token, {
      question_id: gate[4].id,
      choice_index: gate[4].correct_index,
    });
    assertEquals(second.json.questions_remaining, 0);
    assert(second.json.pass_expires_at !== null);
  },
});

Deno.test({
  name: "repeat correct answers grow the interval x2.5",
  ignore,
  async fn() {
    const user = await newUser();
    const q = gate[5];
    const intervals = [];
    for (let i = 0; i < 3; i++) {
      const { json } = await call("grade-attempt", user.token, {
        question_id: q.id,
        choice_index: q.correct_index,
      });
      intervals.push((json.review_item as { interval_minutes: number }).interval_minutes);
    }
    assertEquals(intervals, [25, 63, 158]);
  },
});

Deno.test({
  name: "bad requests are rejected",
  ignore,
  async fn() {
    const user = await newUser();
    const q = gate[0];
    assertEquals(
      (await call("grade-attempt", null, { question_id: q.id, choice_index: 0 })).status,
      401,
    );
    assertEquals(
      (await call("grade-attempt", user.token, { question_id: "nope", choice_index: 0 }))
        .status,
      404,
    );
    assertEquals(
      (await call("grade-attempt", user.token, {
        question_id: session.id,
        choice_index: 0,
      })).status,
      400,
    );
    assertEquals(
      (await call("grade-attempt", user.token, { question_id: q.id, choice_index: 9 }))
        .status,
      400,
    );
  },
});

Deno.test({
  name: "RLS: a user can read their pass state but not change it",
  ignore,
  async fn() {
    const user = await newUser();
    await call("grade-attempt", user.token, {
      question_id: gate[0].id,
      choice_index: gate[0].correct_index,
    });

    const { data: own } = await user.client.from("pass_state")
      .select("pass_expires_at").eq("user_id", user.id);
    assertEquals(own!.length, 1);

    const farFuture = "2099-01-01T00:00:00Z";
    await user.client.from("pass_state")
      .update({ pass_expires_at: farFuture }).eq("user_id", user.id);
    await user.client.from("pass_state")
      .upsert({ user_id: user.id, pass_expires_at: farFuture });

    const { data: after } = await admin.from("pass_state")
      .select("pass_expires_at").eq("user_id", user.id).single();
    assert(new Date(after!.pass_expires_at).getFullYear() < 2099);

    const other = await newUser();
    const { data: theirs } = await other.client.from("pass_state")
      .select("*").eq("user_id", user.id);
    assertEquals(theirs, []);
  },
});
