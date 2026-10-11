import { assert, assertEquals } from "jsr:@std/assert";
import {
  type BankItem,
  GUESS_FLOOR,
  predictCorrect,
  selectNext,
  type SelectionInput,
  updateAbility,
  weightsFromTaxonomy,
} from "./adaptive.ts";
import bankData from "../../../../content/question_bank/questions.json" with {
  type: "json",
};
import taxonomy from "../../../../content/question_bank/skills.json" with {
  type: "json",
};

const now = new Date("2026-10-11T12:00:00Z");
const minutes = (m: number) => new Date(now.getTime() + m * 60_000);

const item = (
  id: string,
  skill: string,
  difficulty: number,
  tier: BankItem["tier"] = "gate",
  four_d: BankItem["four_d"] = "diligence",
): BankItem => ({ id, skill, difficulty, tier, four_d });

const base = (bank: BankItem[], over: Partial<SelectionInput> = {}): SelectionInput => ({
  now,
  tier: "gate",
  bank,
  abilities: {},
  reviews: {},
  skillWeights: { a: 0.5, b: 0.5 },
  ...over,
});

Deno.test("prediction never drops below the guessing floor and rises with ability", () => {
  assert(predictCorrect(-20, 0) >= GUESS_FLOOR);
  assert(predictCorrect(1, 0) > predictCorrect(0, 0));
  assert(predictCorrect(0, 1) < predictCorrect(0, 0));
});

Deno.test("correct answers raise ability, wrong answers lower it", () => {
  const start = { rating: 0, attempts: 0 };
  const q = item("x", "a", 3);
  assert(updateAbility(start, q, true).rating > 0);
  assert(updateAbility(start, q, false).rating < 0);
  assertEquals(updateAbility(start, q, true).attempts, 1);
});

Deno.test("ratings settle: a veteran moves less than a newcomer", () => {
  const q = item("x", "a", 3);
  const fresh = updateAbility({ rating: 0, attempts: 0 }, q, true).rating;
  const veteran = updateAbility({ rating: 0, attempts: 200 }, q, true).rating;
  assert(fresh > veteran);
});

Deno.test("most overdue review is served before anything new", () => {
  const bank = [item("q1", "a", 3), item("q2", "a", 3), item("q3", "b", 3)];
  const sel = selectNext(base(bank, {
    reviews: { q1: { dueAt: minutes(-5) }, q2: { dueAt: minutes(-30) } },
  }));
  assertEquals(sel?.item.id, "q2");
  assertEquals(sel?.reason, "due-review");
});

Deno.test("the gate never serves a session item", () => {
  const bank = [item("s1", "a", 1, "session"), item("g1", "b", 5, "gate")];
  assertEquals(selectNext(base(bank))?.item.id, "g1");
});

Deno.test("the weaker skill is introduced first when weights are equal", () => {
  const bank = [item("a1", "a", 3), item("b1", "b", 3)];
  const sel = selectNext(base(bank, {
    abilities: { a: { rating: 1.5, attempts: 30 }, b: { rating: -1, attempts: 30 } },
  }));
  assertEquals(sel?.item.skill, "b");
  assertEquals(sel?.reason, "adaptive-new");
});

Deno.test("a stronger student gets a harder session item", () => {
  const bank = [1, 2, 3, 4, 5].map((d) => item(`a${d}`, "a", d, "session"));
  const pick = (rating: number) =>
    selectNext(base(bank, {
      tier: "session",
      abilities: { a: { rating, attempts: 30 } },
    }))!.item.difficulty;
  assert(pick(2) > pick(-2));
});

Deno.test("the gate aims easier than a session for the same student", () => {
  const gate = [1, 2, 3, 4, 5].map((d) => item(`g${d}`, "a", d, "gate"));
  const sess = [1, 2, 3, 4, 5].map((d) => item(`s${d}`, "a", d, "session"));
  const abilities = { a: { rating: 0.5, attempts: 30 } };
  const g = selectNext(base([...gate, ...sess], { abilities }))!;
  const s = selectNext(base([...gate, ...sess], { tier: "session", abilities }))!;
  assert(g.predictedCorrect > s.predictedCorrect);
});

Deno.test("a 4D just practiced loses a tie to one that wasn't", () => {
  const bank = [
    item("a1", "a", 3, "gate", "diligence"),
    item("a2", "a", 3, "gate", "description"),
  ];
  const sel = selectNext(base(bank, {
    skillWeights: { a: 1 },
    recentFourD: ["diligence", "diligence"],
  }));
  assertEquals(sel?.item.four_d, "description");
});

Deno.test("with everything seen and nothing due, the soonest review comes back early", () => {
  const bank = [item("q1", "a", 3), item("q2", "a", 3)];
  const sel = selectNext(base(bank, {
    reviews: { q1: { dueAt: minutes(90) }, q2: { dueAt: minutes(15) } },
  }));
  assertEquals(sel?.item.id, "q2");
  assertEquals(sel?.reason, "early-review");
});

Deno.test("ability converges toward a simulated student's true level", () => {
  const bank = (bankData as BankItem[]).filter((q) => q.skill === "vocabulary-in-context");
  let ability = { rating: 0, attempts: 0 };
  const trueAbility = 1.2;
  let seed = 7;
  const rand = () => (seed = (seed * 16807) % 2147483647) / 2147483647;
  for (let i = 0; i < 400; i++) {
    const q = bank[i % bank.length];
    const correct = rand() < predictCorrect(trueAbility, (q.difficulty - 3) * 0.8);
    ability = updateAbility(ability, q, correct);
  }
  assert(Math.abs(ability.rating - trueAbility) < 0.6, `got ${ability.rating}`);
});

Deno.test("the seed bank works end to end for both tiers", () => {
  const bank = bankData as BankItem[];
  const skillWeights = weightsFromTaxonomy(taxonomy.domains);
  for (const tier of ["gate", "session"] as const) {
    const sel = selectNext({ now, tier, bank, abilities: {}, reviews: {}, skillWeights });
    assertEquals(sel?.item.tier, tier);
  }
});
