// Ported from PassService.costForEntry() in
// app/lib/services/pass_service.dart — keep these two in sync by hand.
// Free first entry per rolling hour, then 1/2/3 questions, plateauing
// at 3 rather than climbing without bound.
export const FREE_ENTRIES_PER_HOUR = 1;
export const ESCALATION_CURVE = [1, 2, 3];

// entryNumberThisHour is 1-indexed.
export function costForEntry(entryNumberThisHour: number): number {
  const index = entryNumberThisHour - FREE_ENTRIES_PER_HOUR - 1;
  if (index < 0) return 0;
  if (index >= ESCALATION_CURVE.length) {
    return ESCALATION_CURVE[ESCALATION_CURVE.length - 1];
  }
  return ESCALATION_CURVE[index];
}
