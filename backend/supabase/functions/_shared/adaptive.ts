// Adaptive question selection. Pure functions only, no I/O, so it can be
// unit tested and called from /start-attempt once that function exists.
//
// Order of preference is ported from ReviewQueue.nextDue() in
// app/lib/data/review_queue.dart, keep the two in sync by hand:
//   1. a due review item (most overdue first)
//   2. a new item, which is where the adaptive part lives
//   3. the soonest not-yet-due review, so the gate always has something
//
// The adaptive part keeps one ability rating per (user, skill) on a logit
// scale, Elo-style. Each item has a difficulty rating on the same scale.
// To pick a new item we choose the skill with the most score to gain
// (SAT weight x how far from mastery, plus a little exploration for
// skills the user has barely tried), then the item in that skill whose
// predicted success rate is closest to the tier's target. Gate items aim
// high (fast, calm, mostly right); session items aim for a stretch.

export type Tier = "gate" | "session";
export type FourD = "delegation" | "description" | "discernment" | "diligence";

export interface BankItem {
  id: string;
  skill: string;
  tier: Tier;
  difficulty: number; // 1-5, author's estimate
  four_d: FourD;
  rating?: number; // calibrated difficulty, overrides `difficulty` once set
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
}

export type SelectionReason = "due-review" | "adaptive-new" | "early-review";

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

/**
 * New skill ability after a scored answer. Never call for a tooFast
 * answer: a discarded attempt is not a rep, same as the review queue.
 * Early answers move the rating a lot, later ones settle it.
 */
export function updateAbility(
  ability: SkillAbility,
  item: BankItem,
  correct: boolean,
): SkillAbility {
  const p = predictCorrect(ability.rating, itemRating(item));
  const k = Math.max(K_MIN, K_START / (1 + ability.attempts / K_DECAY_ATTEMPTS));
  return {
    rating: ability.rating + k * ((correct ? 1 : 0) - p),
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

/**
 * How much practicing this skill is worth right now. Weighted by how much
 * of the SAT the skill covers and how far the user is from mastering a
 * medium item, plus an exploration bonus that fades as attempts grow.
 */
export function skillPriority(input: SelectionInput, skill: string): number {
  const a = abilityFor(input, skill);
  const totalAttempts = Object.values(input.abilities)
    .reduce((n, s) => n + s.attempts, 0);
  const gap = 1 - predictCorrect(a.rating, 0);
  const weight = input.skillWeights[skill] ?? 0;
  const explore = EXPLORATION *
    Math.sqrt(Math.log(1 + totalAttempts + 1) / (1 + a.attempts));
  return weight * gap + explore;
}

function fourDPenalty(input: SelectionInput, fd: FourD): number {
  const recent = input.recentFourD ?? [];
  if (recent.length === 0) return 0;
  const share = recent.filter((d) => d === fd).length / recent.length;
  return FOUR_D_REPEAT_PENALTY * share;
}

function pickNew(input: SelectionInput, pool: BankItem[]): Selection | null {
  const unseen = pool.filter((q) => !(q.id in input.reviews));
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

  const ability = abilityFor(input, bestSkill).rating;
  const target = TARGET_SUCCESS[input.tier];
  let best: Selection | null = null;
  let bestScore = Infinity;
  for (const q of unseen.filter((q) => q.skill === bestSkill).sort(byId)) {
    const p = predictCorrect(ability, itemRating(q));
    const score = Math.abs(p - target) + fourDPenalty(input, q.four_d);
    if (score < bestScore) {
      bestScore = score;
      best = { item: q, reason: "adaptive-new", predictedCorrect: p };
    }
  }
  return best;
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

  const seen = pool
    .filter((q) => q.id in input.reviews)
    .sort((a, b) =>
      input.reviews[a.id].dueAt.getTime() - input.reviews[b.id].dueAt.getTime() ||
      byId(a, b)
    );

  // 1. Most overdue review first.
  const due = seen.find((q) => input.reviews[q.id].dueAt <= input.now);
  if (due) return withPrediction(input, due, "due-review");

  // 2. Nothing due: introduce the best new item for this user.
  const fresh = pickNew(input, pool);
  if (fresh) return fresh;

  // 3. Everything seen, nothing due: serve the soonest review early.
  return withPrediction(input, seen[0], "early-review");
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
