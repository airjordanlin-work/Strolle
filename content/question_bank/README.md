# Question bank

Original SAT-style questions, written from the published skill taxonomy.
No official practice material is copied here. Every item lands with
`reviewed: false`; nothing is served until a person flips it.

| File | What it is |
| --- | --- |
| `questions.json` | 56 seed items: 31 math, 25 reading and writing; 36 gate, 20 session |
| `skills.json` | Skill taxonomy by SAT domain, domain weights, and the 4D definitions |
| `validate.py` | Schema checks plus independently recomputed math answer keys |

Run `python3 content/question_bank/validate.py` after any edit. It fails on
a bad tag, a missing explanation, a passage on a gate item, or a math key
that doesn't match its own computation.

## Item shape

```json
{
  "id": "m-005",
  "section": "math",                  // math | reading | writing
  "skill": "systems-of-linear-equations",
  "difficulty": 3,                    // 1-5, author estimate
  "tier": "gate",                     // gate (<15s, no passage) | session
  "four_d": "delegation",
  "time_target_seconds": 15,
  "passage": "...",                   // session items only, optional
  "stem": "If x + y = 10 and x − y = 4, what is x?",
  "choices": ["3", "6", "7", "14"],
  "correct_index": 2,
  "explanation": "Add the equations so y cancels ...",
  "reviewed": false
}
```

This extends the shape already used by `app/assets/questions.json` and the
`questions` table; the three original `seed-00x` items are kept by id.
Migration `backend/supabase/migrations/0002_question_bank.sql` adds the new
columns plus the `skills` and `skill_ability` tables.

## The 4Ds on an SAT question

Each item has one primary D: the habit that most often decides whether a
student gets it right.

- **Description**: putting meaning into precise words or symbols. Words in
  context, translating a word problem into an equation.
- **Discernment**: judging what the evidence actually allows. Main idea,
  inference, sample conclusions, association versus cause.
- **Delegation**: choosing the approach before doing the work. Which
  formula or shortcut, which notes serve the stated goal.
- **Diligence**: careful execution. Sign flips, NOT questions,
  subject-verb agreement, checking every data point.

## Adaptive selection

`backend/supabase/functions/_shared/adaptive.ts`, tested in
`adaptive_test.ts`.

1. A due review item always comes first (same order as the app's
   `ReviewQueue`).
2. Otherwise a new item. The selector keeps an Elo-style rating per user
   per skill, picks the skill with the most to gain (SAT weight times
   distance from mastery, plus a small bonus for skills barely tried), then
   picks the item whose predicted success is closest to the target: 85% at
   the gate, 70% in a session. A 4D that dominated the last few items gets
   a small penalty so all four get practice.
3. If everything has been seen and nothing is due, the soonest review comes
   back early.

After a scored answer, `updateAbility` moves the skill rating (big steps
early, small once settled) and `updateItemRating` nudges the item's
calibrated difficulty. Too-fast answers update nothing.
