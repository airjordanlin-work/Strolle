import { assert, assertEquals } from "jsr:@std/assert";
import {
  CAP_MINUTES,
  freeEntryPassSeconds,
  isTooFast,
  nextReview,
  parseGradeRequest,
  passLengthSeconds,
  remainingAfterAnswer,
} from "./grading.ts";
import questionData from "./questions.json" with { type: "json" };

const NOW = new Date("2026-10-11T12:00:00Z");

Deno.test("first correct answer grows the interval from 10 to 25 minutes", () => {
  const r = nextReview(null, true, NOW);
  assertEquals(r.intervalMinutes, 25);
  assertEquals(r.streak, 1);
  assertEquals(r.dueAt.toISOString(), "2026-10-11T12:25:00.000Z");
});

Deno.test("repeated correct answers grow x2.5 and cap at one week", () => {
  let state = { intervalMinutes: 10, streak: 0 };
  const seen: number[] = [];
  for (let i = 0; i < 8; i++) {
    state = nextReview(state, true, NOW);
    seen.push(state.intervalMinutes);
  }
  assertEquals(seen.slice(0, 4), [25, 63, 158, 395]);
  assertEquals(seen.at(-1), CAP_MINUTES);
  assertEquals(state.streak, 8);
});

Deno.test("a wrong answer resets the interval and the streak", () => {
  const r = nextReview({ intervalMinutes: 395, streak: 4 }, false, NOW);
  assertEquals(r.intervalMinutes, 10);
  assertEquals(r.streak, 0);
  assertEquals(r.dueAt.toISOString(), "2026-10-11T12:10:00.000Z");
});

Deno.test("android: 5 minutes correct, 90 seconds wrong", () => {
  assertEquals(passLengthSeconds(true, "android"), 300);
  assertEquals(passLengthSeconds(false, "android"), 90);
});

Deno.test("ios: a wrong answer still gets the 5-minute floor", () => {
  assertEquals(passLengthSeconds(true, "ios"), 300);
  assertEquals(passLengthSeconds(false, "ios"), 300);
});

Deno.test("answers under 2 seconds are too fast", () => {
  assert(isTooFast(0));
  assert(isTooFast(1999));
  assert(!isTooFast(2000));
});

Deno.test("a free entry gets the full 5-minute pass on both platforms", () => {
  assertEquals(freeEntryPassSeconds("ios"), 300);
  assertEquals(freeEntryPassSeconds("android"), 300);
});

Deno.test("owed questions count down, and nothing owed still means one", () => {
  assertEquals(remainingAfterAnswer(3), 2);
  assertEquals(remainingAfterAnswer(1), 0);
  assertEquals(remainingAfterAnswer(0), 0);
});

Deno.test("request parsing defaults platform to ios and rejects bad input", () => {
  const id = "0b6f2a52-3c1e-4d7a-9a51-2f8e6c4b7d10";
  const ok = parseGradeRequest({ attempt_id: id, choice_index: 2 });
  assert("request" in ok);
  assertEquals(ok.request.platform, "ios");

  assert("error" in parseGradeRequest(null));
  assert("error" in parseGradeRequest({ attempt_id: id }));
  assert("error" in parseGradeRequest({ attempt_id: "m-001", choice_index: 0 }));
  assert("error" in parseGradeRequest({ attempt_id: id, choice_index: 1.5 }));
  assert(
    "error" in parseGradeRequest({ attempt_id: id, choice_index: 0, platform: "web" }),
  );
});

Deno.test("bundled questions have unique ids and in-range answer keys", () => {
  const qs = questionData as Array<
    { id: string; choices: string[]; correct_index: number }
  >;
  assertEquals(new Set(qs.map((q) => q.id)).size, qs.length);
  for (const q of qs) {
    assert(q.correct_index >= 0 && q.correct_index < q.choices.length, q.id);
  }
});
