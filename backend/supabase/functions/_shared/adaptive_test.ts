import { assert, assertEquals } from "jsr:@std/assert";
import {
  answerWeight,
  type BankItem,
  domainsFromTaxonomy,
  GUESS_FLOOR,
  MAX_SAME_SKILL_RUN,
  MIN_EVIDENCE,
  predictCorrect,
  selectNext,
  type SelectionInput,
  skillPriority,
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

const veteran = (rating: number) => ({ rating, attempts: 30 });

Deno.test("a guess (very fast answer) carries no weight and leaves ability alone", () => {
  const q = item("x", "a", 3);
  const start = { rating: 0, attempts: 3 };
  assertEquals(answerWeight(start, q, true, 500), 0);
  assertEquals(updateAbility(start, q, true, 0), start);
  assertEquals(answerWeight(start, q, true, 20_000), 1);
  assertEquals(answerWeight(start, q, true), 1); // unknown time: no discount
});

Deno.test("a miss on an easy item counts half, a miss on a hard one counts full", () => {
  const strong = { rating: 1.5, attempts: 30 };
  assertEquals(answerWeight(strong, item("e", "a", 1), false, 15_000), 0.5);
  assertEquals(answerWeight(strong, item("h", "a", 5), false, 15_000), 1);
  assertEquals(answerWeight(strong, item("e", "a", 1), true, 15_000), 1);
  const q = item("e", "a", 1);
  const full = updateAbility(strong, q, false, 1).rating;
  const half = updateAbility(strong, q, false, 0.5).rating;
  assert(strong.rating - half < strong.rating - full);
});

Deno.test("a skill with too little evidence is not called weak", () => {
  const bank = [item("b1", "b", 3)];
  const priority = (rating: number, answers: number) =>
    skillPriority(base(bank, {
      abilities: { b: { rating, attempts: answers } },
      history: Array(answers).fill({ skill: "b", correct: false }),
    }), "b");
  // Below MIN_EVIDENCE the rating is ignored: -3 looks the same as 0.
  assertEquals(priority(-3, MIN_EVIDENCE - 1), priority(0, MIN_EVIDENCE - 1));
  // At MIN_EVIDENCE the same rating finally counts as weak.
  assert(priority(-3, MIN_EVIDENCE) > priority(0, MIN_EVIDENCE));
});

Deno.test("with enough recent evidence the weaker skill wins", () => {
  const bank = [item("a1", "a", 3), item("b1", "b", 3)];
  const sel = selectNext(base(bank, {
    diagnostic: false,
    abilities: { a: veteran(0.5), b: veteran(-2) },
    history: [
      ...Array(MIN_EVIDENCE).fill({ skill: "a", correct: true }),
      ...Array(MIN_EVIDENCE).fill({ skill: "b", correct: false }),
    ],
  }));
  assertEquals(sel?.item.skill, "b");
});

Deno.test("the same skill is not served more than the cap in a row", () => {
  const bank = [item("a1", "a", 3), item("a2", "a", 3), item("b1", "b", 3)];
  const input = base(bank, {
    diagnostic: false,
    abilities: { a: veteran(-2), b: veteran(1) }, // a is much weaker
    recentSkills: Array(MAX_SAME_SKILL_RUN).fill("a"),
  });
  assertEquals(selectNext(input)?.item.skill, "b");
  // Below the cap, the weak skill is still preferred.
  assertEquals(
    selectNext({ ...input, recentSkills: ["b", "a"] })?.item.skill,
    "a",
  );
  // If nothing else is left the cap relaxes rather than stalling the gate.
  assertEquals(selectNext({ ...input, bank: bank.slice(0, 2) })?.item.skill, "a");
});

Deno.test("a capped skill's due review waits behind another skill", () => {
  const bank = [item("a1", "a", 3), item("b1", "b", 3)];
  const sel = selectNext(base(bank, {
    diagnostic: false,
    reviews: { a1: { dueAt: minutes(-5) } },
    recentSkills: ["a", "a"],
  }));
  assertEquals(sel?.item.id, "b1");
});

Deno.test("every fourth new item is a mastered skill", () => {
  const bank = [item("a1", "a", 3), item("b1", "b", 3)];
  const at = (bAttempts: number) => {
    const aAttempts = 7;
    return base(bank, {
      abilities: {
        a: { rating: 2, attempts: aAttempts }, // mastered
        b: { rating: -2, attempts: bAttempts }, // weak
      },
      history: [
        ...Array(aAttempts).fill({ skill: "a", correct: true }),
        ...Array(bAttempts).fill({ skill: "b", correct: false }),
      ],
    });
  };
  // 7 + 5 = 12 answers so far: an ordinary turn, the weak skill.
  assertEquals(selectNext(at(5))?.item.skill, "b");
  // 7 + 8 = 15, 15 % 4 = 3: maintenance turn, the mastered skill.
  const turn = selectNext(at(8));
  assertEquals(turn?.item.skill, "a");
  assertEquals(turn?.reason, "maintenance");
});

Deno.test("a new student gets a diagnostic that spreads across domains", () => {
  const bank = bankData as BankItem[];
  const skillWeights = weightsFromTaxonomy(taxonomy.domains);
  const skillDomains = domainsFromTaxonomy(taxonomy.domains);
  const abilities: SelectionInput["abilities"] = {};
  const reviews: SelectionInput["reviews"] = {};
  const domains = new Set<string>();
  for (let i = 0; i < taxonomy.domains.filter((d) => d.section === "math").length; i++) {
    const sel = selectNext({
      now, tier: "gate", bank, abilities, reviews, skillWeights, skillDomains,
    })!;
    assertEquals(sel.reason, "diagnostic");
    domains.add(skillDomains[sel.item.skill]);
    abilities[sel.item.skill] = { rating: 0, attempts: 1 };
    reviews[sel.item.id] = { dueAt: minutes(60) };
  }
  // Four picks, four different domains.
  assertEquals(domains.size, 4);
});

Deno.test("the diagnostic ends after DIAGNOSTIC_ITEMS answers", () => {
  const bank = [item("a1", "a", 3), item("b1", "b", 3)];
  const sel = selectNext(base(bank, {
    abilities: { a: { rating: 0, attempts: 6 }, b: { rating: 0, attempts: 6 } },
  }));
  assertEquals(sel?.reason, "adaptive-new");
});

Deno.test("domain weights steer the pick: equal ability, heavier domain first", () => {
  const bank = [item("a1", "a", 3), item("b1", "b", 3)];
  const sel = selectNext(base(bank, {
    diagnostic: false,
    skillWeights: { a: 0.35, b: 0.05 },
    abilities: { a: veteran(0), b: veteran(0) },
  }));
  assertEquals(sel?.item.skill, "a");
});

Deno.test("simulated student: no skill runs past the cap and weak skills get more practice", () => {
  const bank = (bankData as BankItem[]).filter((q) => q.tier === "gate");
  const skillWeights = weightsFromTaxonomy(taxonomy.domains);
  const skillDomains = domainsFromTaxonomy(taxonomy.domains);
  const truth = (skill: string) => skill === "transitions" ? -2 : 1.5;
  const abilities: SelectionInput["abilities"] = {};
  const reviews: SelectionInput["reviews"] = {};
  const history: { skill: string; correct: boolean }[] = [];
  const served: string[] = [];
  let seed = 11;
  const rand = () => (seed = (seed * 16807) % 2147483647) / 2147483647;
  let clock = now.getTime();

  for (let i = 0; i < 120; i++) {
    clock += 60_000;
    const sel = selectNext({
      now: new Date(clock), tier: "gate", bank, abilities, reviews, skillWeights,
      skillDomains, history, recentSkills: served.slice(-6),
    });
    if (!sel) break;
    served.push(sel.item.skill);
    const correct = rand() < predictCorrect(truth(sel.item.skill), (sel.item.difficulty - 3) * 0.8);
    const before = abilities[sel.item.skill] ?? { rating: 0, attempts: 0 };
    abilities[sel.item.skill] = updateAbility(before, sel.item, correct);
    history.push({ skill: sel.item.skill, correct });
    reviews[sel.item.id] = { dueAt: new Date(clock + 10 * 60_000) };
  }

  let run = 1;
  for (let i = 1; i < served.length; i++) {
    run = served[i] === served[i - 1] ? run + 1 : 1;
    assert(run <= MAX_SAME_SKILL_RUN, `run of ${run} at ${i}: ${served[i]}`);
  }
  const share = (s: string) => served.filter((x) => x === s).length;
  // transitions (3 gate items) is the only weak skill: it should be seen
  // well beyond its one-in-twenty-five share of the bank.
  assert(share("transitions") >= 6, `transitions served ${share("transitions")}x`);
});
