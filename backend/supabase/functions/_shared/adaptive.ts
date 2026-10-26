// Adaptive question selection. Pure functions only, no I/O, so it can be
// unit tested; start-attempt calls selectNext, grade-attempt calls
// answerWeight + updateAbility.
//
// Order of preference is ported from ReviewQueue.nextDue() in
// app/lib/data/review_queue.dart, keep the two in sync by hand:
//   1. a due review item (most overdue first)
//   2. a new item, which is where the adaptive part lives
//   3. the soonest not-yet-due review, so the gate always has something
// A brand-new user first gets a short diagnostic (one item per domain,
// widest coverage first) so the ratings have something to start from.
//
// The adaptive part keeps one ability rating per (user, skill) on a logit
// scale, Elo-style. Each item has a difficulty rating on the same scale.
// To pick a new item we choose the skill with the most score to gain
// (SAT weight x how far from mastery, plus a little exploration for
// skills the user has barely tried), then the item in that skill whose
// predicted success rate is closest to the tier's target. Gate items aim
// high (fast, calm, mostly right); session items aim for a stretch.
//
// Guard rails, all tested in adaptive_test.ts:
//   - a skill only counts as weak or mastered after MIN_EVIDENCE recent
//     answers; before that it gets a neutral prior plus exploration
//   - the same skill is never served more than MAX_SAME_SKILL_RUN times
//     in a row within a session
//   - every MIX_EVERY-th new item comes from a mastered skill, so the
//     student keeps seeing things they can do
//   - guesses (answers faster than a human can read) carry no weight, and
//     a miss on an item the student should get right counts half

export type Tier = "gate" | "session";
export type FourD = "delegation" | "description" | "discernment" | "diligence";

export interface BankItem {
  id: string;
  skill: string;
  tier: Tier;
  difficulty: number; // 1-5, author's estimate
  four_d: FourD;
  rating?: number; // calibrated difficulty, overrides `difficulty` once set
  time_target_seconds?: number;
}

export interface SkillAbility {
  rating: number; // logit scale, 0 = can do a difficulty-3 item ~62% of the time
  attempts: number;
}

export interface ReviewState {
  dueAt: Date;
}

export interface SelectionInput {
  now: Date;
  tier: Tier;
  bank: BankItem[];
  abilities: Record<string, SkillAbility>; // keyed by skill; missing = new
  reviews: Record<string, ReviewState>; // keyed by question id; missing = unseen
  skillWeights: Record<string, number>; // from skills.json sat_weight
  recentFourD?: FourD[]; // four_d of the last few items served, newest last
  // Scored answers, newest last. When given, "recent evidence" for a skill
  // is how many of these are in that skill; otherwise skill_ability.attempts.
  history?: { skill: string; correct: boolean }[];
  recentSkills?: string[]; // skill of each item served this session, newest last
  skillDomains?: Record<string, string>; // skill -> domain, for the diagnostic
  diagnostic?: boolean; // force on/off; default is on until DIAGNOSTIC_ITEMS answers
}

export type SelectionReason =
  | "due-review"
  | "diagnostic"
  | "maintenance"
  | "adaptive-new"
  | "early-review";

export interface Selection {
  item: BankItem;
  reason: SelectionReason;
  predictedCorrect: number;
}

// Four answer choices, so even a blind guess is right a quarter of the time.
export const GUESS_FLOOR = 0.25;
export const TARGET_SUCCESS: Record<Tier, number> = { gate: 0.85, session: 0.7 };
export const EXPLORATION = 0.15;
export const FOUR_D_REPEAT_PENALTY = 0.08;
export const MIN_EVIDENCE = 4; // recent answers before a skill is called weak or mastered
export const MAX_SAME_SKILL_RUN = 2;
export const MIX_EVERY = 4; // every 4th new item is a mastered skill
export const MASTERY_RATING = 1;
export const DIAGNOSTIC_ITEMS = 12;
export const MIN_GUESS_MS = 2000; // matches PassService.guessThreshold
export const EASY_MISS_P = 0.85; // a miss above this predicted success is half-weighted
const K_START = 0.6;
const K_MIN = 0.12;
const K_DECAY_ATTEMPTS = 10;
const ITEM_K = 0.05;

/** Author difficulty 1-5 mapped onto the ability scale until calibrated. */
export function itemRating(item: BankItem): number {
  return item.rating ?? (item.difficulty - 3) * 0.8;
}

/** Probability a user with `ability` answers an item rated `difficulty`. */
export function predictCorrect(ability: number, difficulty: number): number {
  const p = 1 / (1 + Math.exp(-(ability - difficulty)));
  return GUESS_FLOOR + (1 - GUESS_FLOOR) * p;
}

/** Answers faster than this are guesses, not evidence. */
export function guessThresholdMs(item: BankItem): number {
  return Math.max(MIN_GUESS_MS, (item.time_target_seconds ?? 0) * 100);
}

/**
 * How much a scored answer should move the ability rating, 0 to 1.
 * A very fast answer is a guess whether or not it landed, so it counts
 * for nothing. A miss on an item the student was expected to get is
 * more likely a slip or a guess than a gap, so it counts half.
 * `responseMs` is measured server-side; unknown means no discount for speed.
 */
export function answerWeight(
  ability: SkillAbility,
  item: BankItem,
  correct: boolean,
  responseMs?: number,
): number {
  if (responseMs !== undefined && responseMs < guessThresholdMs(item)) return 0;
  const p = predictCorrect(ability.rating, itemRating(item));
  if (!correct && p >= EASY_MISS_P) return 0.5;
  return 1;
}

/**
 * New skill ability after a scored answer. Never call for a tooFast
 * answer: a discarded attempt is not a rep, same as the review queue.
 * Early answers move the rating a lot, later ones settle it. `weight`
 * comes from answerWeight; 0 leaves the ability untouched.
 */
export function updateAbility(
  ability: SkillAbility,
  item: BankItem,
  correct: boolean,
  weight = 1,
): SkillAbility {
  if (weight <= 0) return ability;
  const p = predictCorrect(ability.rating, itemRating(item));
  const k = Math.max(K_MIN, K_START / (1 + ability.attempts / K_DECAY_ATTEMPTS));
  return {
    rating: ability.rating + weight * k * ((correct ? 1 : 0) - p),
    attempts: ability.attempts + 1,
  };
}

/**
 * Nudges an item's calibrated rating toward how hard it actually played.
 * Run server-side over every scored answer; it starts from the author's
 * 1-5 estimate and drifts slowly, so one user can't swing it.
 */
export function updateItemRating(
  item: BankItem,
  userAbility: number,
  correct: boolean,
): number {
  const current = itemRating(item);
  const p = predictCorrect(userAbility, current);
  return current - ITEM_K * ((correct ? 1 : 0) - p);
}

function abilityFor(input: SelectionInput, skill: string): SkillAbility {
  return input.abilities[skill] ?? { rating: 0, attempts: 0 };
}

/** Recent scored answers in this skill. */
export function evidence(input: SelectionInput, skill: string): number {
  if (input.history) return input.history.filter((h) => h.skill === skill).length;
  return abilityFor(input, skill).attempts;
}

function totalAttempts(input: SelectionInput): number {
  return Object.values(input.abilities).reduce((n, s) => n + s.attempts, 0);
}

/** Enough evidence and a high rating. */
export function isMastered(input: SelectionInput, skill: string): boolean {
  return evidence(input, skill) >= MIN_EVIDENCE &&
    abilityFor(input, skill).rating >= MASTERY_RATING;
}

/**
 * How much practicing this skill is worth right now. Weighted by how much
 * of the SAT the skill covers and how far the user is from mastering a
 * medium item, plus an exploration bonus that fades as attempts grow.
 * Until MIN_EVIDENCE recent answers exist the gap is a neutral prior, so
 * one unlucky miss can't make a skill look weak.
 */
export function skillPriority(input: SelectionInput, skill: string): number {
  const a = abilityFor(input, skill);
  const rating = evidence(input, skill) >= MIN_EVIDENCE ? a.rating : 0;
  const gap = 1 - predictCorrect(rating, 0);
  const weight = input.skillWeights[skill] ?? 0;
  const explore = EXPLORATION *
    Math.sqrt(Math.log(1 + totalAttempts(input) + 1) / (1 + a.attempts));
  return weight * gap + explore;
}

function fourDPenalty(input: SelectionInput, fd: FourD): number {
  const recent = input.recentFourD ?? [];
  if (recent.length === 0) return 0;
  const share = recent.filter((d) => d === fd).length / recent.length;
  return FOUR_D_REPEAT_PENALTY * share;
}

/** The skill that has just hit the consecutive cap, if any. */
function cappedSkill(input: SelectionInput): string | undefined {
  const recent = input.recentSkills ?? [];
  if (recent.length < MAX_SAME_SKILL_RUN) return undefined;
  const tail = recent.slice(-MAX_SAME_SKILL_RUN);
  return tail.every((s) => s === tail[0]) ? tail[0] : undefined;
}

interface PickOpts {
  only?: Set<string>; // restrict to these skills
  avoid?: string; // skip this skill
}

function pickNew(
  input: SelectionInput,
  pool: BankItem[],
  opts: PickOpts = {},
): Selection | null {
  const unseen = pool.filter((q) =>
    !(q.id in input.reviews) &&
    q.skill !== opts.avoid &&
    (!opts.only || opts.only.has(q.skill))
  );
  if (unseen.length === 0) return null;

  const skills = [...new Set(unseen.map((q) => q.skill))].sort();
  let bestSkill = skills[0];
  let bestPriority = -Infinity;
  for (const s of skills) {
    const pr = skillPriority(input, s);
    if (pr > bestPriority) {
      bestPriority = pr;
      bestSkill = s;
    }
  }
  return closestToTarget(input, unseen.filter((q) => q.skill === bestSkill));
}

function closestToTarget(input: SelectionInput, items: BankItem[]): Selection | null {
  const ability = (s: string) => abilityFor(input, s).rating;
  const target = TARGET_SUCCESS[input.tier];
  let best: Selection | null = null;
  let bestScore = Infinity;
  for (const q of [...items].sort(byId)) {
    const p = predictCorrect(ability(q.skill), itemRating(q));
    const score = Math.abs(p - target) + fourDPenalty(input, q.four_d);
    if (score < bestScore) {
      bestScore = score;
      best = { item: q, reason: "adaptive-new", predictedCorrect: p };
    }
  }
  return best;
}

function diagnosticActive(input: SelectionInput): boolean {
  return input.diagnostic ?? totalAttempts(input) < DIAGNOSTIC_ITEMS;
}

/**
 * Cold start: one medium item from a skill the student hasn't touched,
 * spread across domains (least-covered domain first, then the heavier
 * one). Answers feed updateAbility like any other, so by the time the
 * diagnostic ends every domain has a starting rating. Returns null when
 * every skill in the pool has been tried, which ends the diagnostic early.
 */
function pickDiagnostic(
  input: SelectionInput,
  pool: BankItem[],
  avoid?: string,
): Selection | null {
  const domainOf = (s: string) => input.skillDomains?.[s] ?? s;
  const untried = pool.filter((q) =>
    !(q.id in input.reviews) && q.skill !== avoid &&
    abilityFor(input, q.skill).attempts === 0
  );
  if (untried.length === 0) return null;

  const covered: Record<string, number> = {};
  for (const [skill, a] of Object.entries(input.abilities)) {
    if (a.attempts > 0) covered[domainOf(skill)] = (covered[domainOf(skill)] ?? 0) + 1;
  }
  const domains = [...new Set(untried.map((q) => domainOf(q.skill)))].sort();
  const domainWeight = (d: string) =>
    Math.max(...untried.filter((q) => domainOf(q.skill) === d)
      .map((q) => input.skillWeights[q.skill] ?? 0));
  domains.sort((x, y) =>
    (covered[x] ?? 0) - (covered[y] ?? 0) || domainWeight(y) - domainWeight(x)
  );

  const inDomain = untried.filter((q) => domainOf(q.skill) === domains[0]);
  const skills = [...new Set(inDomain.map((q) => q.skill))].sort((x, y) =>
    (input.skillWeights[y] ?? 0) - (input.skillWeights[x] ?? 0) || (x < y ? -1 : 1)
  );
  const items = inDomain.filter((q) => q.skill === skills[0]);

  // Medium difficulty tells us the most about a student we know nothing about.
  let best = items[0];
  let bestScore = Infinity;
  for (const q of [...items].sort(byId)) {
    const score = Math.abs(itemRating(q)) + fourDPenalty(input, q.four_d);
    if (score < bestScore) {
      bestScore = score;
      best = q;
    }
  }
  return {
    item: best,
    reason: "diagnostic",
    predictedCorrect: predictCorrect(0, itemRating(best)),
  };
}

function byId(a: BankItem, b: BankItem): number {
  return a.id < b.id ? -1 : a.id > b.id ? 1 : 0;
}

function withPrediction(
  input: SelectionInput,
  item: BankItem,
  reason: SelectionReason,
): Selection {
  const p = predictCorrect(abilityFor(input, item.skill).rating, itemRating(item));
  return { item, reason, predictedCorrect: p };
}

/** Next item to serve for this tier, or null if the tier has no items. */
export function selectNext(input: SelectionInput): Selection | null {
  const pool = input.bank.filter((q) => q.tier === input.tier);
  if (pool.length === 0) return null;

  const avoid = cappedSkill(input);
  const seen = pool
    .filter((q) => q.id in input.reviews)
    .sort((a, b) =>
      input.reviews[a.id].dueAt.getTime() - input.reviews[b.id].dueAt.getTime() ||
      byId(a, b)
    );
  const dueList = seen.filter((q) => input.reviews[q.id].dueAt <= input.now);

  // 1. Most overdue review first (unless its skill just hit the run cap).
  const due = dueList.find((q) => q.skill !== avoid);
  if (due) return withPrediction(input, due, "due-review");

  // 2. Cold start: the diagnostic runs until the student has some history.
  if (diagnosticActive(input)) {
    const d = pickDiagnostic(input, pool, avoid);
    if (d) return d;
  }

  // 3. Every MIX_EVERY-th new item comes from a mastered skill.
  if (totalAttempts(input) % MIX_EVERY === MIX_EVERY - 1) {
    const mastered = new Set(
      [...new Set(pool.map((q) => q.skill))].filter((s) => isMastered(input, s)),
    );
    if (mastered.size > 0) {
      const m = pickNew(input, pool, { only: mastered, avoid });
      if (m) return { ...m, reason: "maintenance" };
    }
  }

  // 4. Otherwise the best new item for this user.
  const fresh = pickNew(input, pool, { avoid });
  if (fresh) return fresh;

  // 5. Only the capped skill is left: relax the cap rather than stall.
  if (dueList.length > 0) return withPrediction(input, dueList[0], "due-review");
  const relaxed = pickNew(input, pool);
  if (relaxed) return relaxed;

  // 6. Everything seen, nothing due: serve the soonest review early.
  const early = seen.find((q) => q.skill !== avoid) ?? seen[0];
  return withPrediction(input, early, "early-review");
}

/** Per-skill weights from skills.json: domain sat_weight split evenly. */
export function weightsFromTaxonomy(
  domains: { sat_weight: number; skills: string[] }[],
): Record<string, number> {
  const out: Record<string, number> = {};
  for (const d of domains) {
    for (const s of d.skills) out[s] = d.sat_weight / d.skills.length;
  }
  return out;
}

/** skill -> domain from skills.json, for the diagnostic's coverage spread. */
export function domainsFromTaxonomy(
  domains: { domain: string; skills: string[] }[],
): Record<string, string> {
  const out: Record<string, string> = {};
  for (const d of domains) for (const s of d.skills) out[s] = d.domain;
  return out;
}
