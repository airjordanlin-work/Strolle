// Pure grading rules for grade-attempt and register-entry. No I/O, so
// they can be unit tested directly. Ported from app/lib/services/pass_service.dart and
// app/lib/data/review_queue.dart; keep the three in sync by hand.

export type Platform = "ios" | "android";

export const GROWTH_FACTOR = 2.5;
export const RESET_INTERVAL_MINUTES = 10;
export const CAP_MINUTES = 60 * 24 * 7; // one week, matches ReviewQueue._capMinutes

export const CORRECT_PASS_SECONDS = 5 * 60;
export const INCORRECT_PASS_SECONDS = 90;
// DeviceActivityEvent thresholds under ~5 minutes are unreliable on iOS,
// so no iOS pass is shorter than this.
export const IOS_PASS_FLOOR_SECONDS = 5 * 60;
export const GUESS_THRESHOLD_MS = 2000;

export interface ReviewState {
  intervalMinutes: number;
  streak: number;
}

export interface ReviewUpdate extends ReviewState {
  dueAt: Date;
}

// Same math as ReviewQueue.record(): a correct answer grows the interval
// x2.5 up to a week, a wrong one resets it to 10 minutes.
export function nextReview(
  existing: ReviewState | null,
  correct: boolean,
  now: Date,
): ReviewUpdate {
  let intervalMinutes = existing?.intervalMinutes ?? RESET_INTERVAL_MINUTES;
  let streak = existing?.streak ?? 0;

  if (correct) {
    streak += 1;
    intervalMinutes = Math.min(
      Math.round(intervalMinutes * GROWTH_FACTOR),
      CAP_MINUTES,
    );
  } else {
    streak = 0;
    intervalMinutes = RESET_INTERVAL_MINUTES;
  }

  return {
    intervalMinutes,
    streak,
    dueAt: new Date(now.getTime() + intervalMinutes * 60_000),
  };
}

// A wrong answer still grants entry, just a shorter pass, except on iOS
// where the floor makes both the same length.
export function passLengthSeconds(correct: boolean, platform: Platform): number {
  const base = correct ? CORRECT_PASS_SECONDS : INCORRECT_PASS_SECONDS;
  return platform === "ios" ? Math.max(base, IOS_PASS_FLOOR_SECONDS) : base;
}

// A free entry (nothing owed) gets the full pass straight away.
export function freeEntryPassSeconds(platform: Platform): number {
  return passLengthSeconds(true, platform);
}

// Answers faster than the guess threshold are discarded: no pass, no
// review update, the client serves another question. elapsedMs is
// measured on the server, from start-attempt to grade-attempt.
export function isTooFast(elapsedMs: number): boolean {
  return elapsedMs < GUESS_THRESHOLD_MS;
}

// How many questions are still owed after this scored answer. A user with
// nothing owed (no register-entry call, or a free entry) is treated as
// owing one, so a single answer always ends in a pass.
export function remainingAfterAnswer(questionsOwed: number): number {
  return Math.max(questionsOwed, 1) - 1;
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function parsePlatform(value: unknown): Platform | null {
  const platform = value ?? "ios";
  return platform === "ios" || platform === "android" ? platform : null;
}

export interface GradeRequest {
  attempt_id: string;
  choice_index: number;
  platform: Platform;
}

// Validates the request body. Returns an error message, or the parsed
// request.
export function parseGradeRequest(
  body: unknown,
): { error: string } | { request: GradeRequest } {
  if (typeof body !== "object" || body === null) {
    return { error: "body must be a JSON object" };
  }
  const b = body as Record<string, unknown>;
  if (
    typeof b.attempt_id !== "string" || !UUID.test(b.attempt_id) ||
    !Number.isInteger(b.choice_index)
  ) {
    return {
      error: "attempt_id (uuid from start-attempt) and choice_index (integer) required",
    };
  }
  const platform = parsePlatform(b.platform);
  if (!platform) {
    return { error: "platform must be 'ios' or 'android'" };
  }
  return {
    request: {
      attempt_id: b.attempt_id,
      choice_index: b.choice_index as number,
      platform,
    },
  };
}
