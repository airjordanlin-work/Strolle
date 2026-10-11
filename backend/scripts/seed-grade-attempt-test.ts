// One-shot local seed for testing grade-attempt by hand. Run after
// `supabase db reset`:
//
//   deno run --node-modules-dir=none --allow-net --allow-env --allow-read backend/scripts/seed-grade-attempt-test.ts
//
// (--node-modules-dir=none is needed because this repo has no deno.json;
// without it Deno 2.x looks for a local node_modules install of the npm
// specifier below instead of fetching it directly.)
//
// Creates (or reuses) a test auth user, signs in to mint a real access
// token, and prints a real gate question_id with its answer key from the
// bundled question set: everything needed to construct a curl call
// against grade-attempt. See backend/MANUAL_TEST.md.
//
// Defaults below are the Supabase CLI's well-known local dev keys
// (same on every machine, never valid against a real project). Override
// via env vars if your local stack runs on non-default ports.
import { createClient } from "npm:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "http://127.0.0.1:54321";
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ??
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0";
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU";

const TEST_EMAIL = "grade-attempt-test@local.test";
const TEST_PASSWORD = "grade-attempt-test-password";

const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
const anon = createClient(SUPABASE_URL, ANON_KEY);

async function getOrCreateTestUser(): Promise<string> {
  const { data: created, error: createError } = await admin.auth.admin
    .createUser({
      email: TEST_EMAIL,
      password: TEST_PASSWORD,
      email_confirm: true,
    });
  if (!createError) return created.user.id;

  if (!createError.message.toLowerCase().includes("already")) {
    throw createError;
  }

  const { data: listed, error: listError } = await admin.auth.admin
    .listUsers();
  if (listError) throw listError;
  const existing = listed.users.find((u) => u.email === TEST_EMAIL);
  if (!existing) throw new Error("user creation said 'already exists' but couldn't find it");
  return existing.id;
}

const userId = await getOrCreateTestUser();

const { data: signedIn, error: signInError } = await anon.auth
  .signInWithPassword({ email: TEST_EMAIL, password: TEST_PASSWORD });
if (signInError || !signedIn.session) {
  throw signInError ?? new Error("sign-in returned no session");
}
const accessToken = signedIn.session.access_token;

const questionsPath = new URL(
  "../supabase/functions/grade-attempt/questions.json",
  import.meta.url,
);
const questions: Array<
  { id: string; tier: string; correct_index: number }
> = JSON.parse(await Deno.readTextFile(questionsPath));
const sample = questions.find((q) => q.tier === "gate")!;
const sampleQuestionId = sample.id;

console.log(`user_id:       ${userId}`);
console.log(`access_token:  ${accessToken}`);
console.log(`question_id:   ${sampleQuestionId}`);
console.log(`correct_index: ${sample.correct_index}`);
console.log();
console.log("Example call:");
console.log(
  `curl -i "${SUPABASE_URL}/functions/v1/grade-attempt" \\
  -H "Authorization: Bearer ${accessToken}" \\
  -H "Content-Type: application/json" \\
  -d '{"question_id": "${sampleQuestionId}", "choice_index": ${sample.correct_index}, "elapsed_ms": 4000}'`,
);
