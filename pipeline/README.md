# Question generation pipeline

Offline batch tool. Generates original SAT-style questions with the Claude
API, validates them, and writes them to `pipeline/staging/` for human review.
It never touches `content/question_bank/questions.json`, `app/assets`, or the
backend copies. Promotion into the live bank is a manual, Jordan-approved step.

## Setup

```sh
pip install -r pipeline/requirements.txt
export ANTHROPIC_API_KEY=...      # env var only; never commit it
```

## Use

```sh
python3 pipeline/src/generate.py --report                      # coverage, no API
python3 pipeline/src/generate.py --fill-gaps --target-per-skill 6 --dry-run
python3 pipeline/src/generate.py --fill-gaps --target-per-skill 6 --max-items 20
python3 pipeline/src/generate.py --skill percentages --difficulty 3 --tier gate -n 5
python3 -m unittest discover -s pipeline/tests                 # offline tests
```

`--dry-run` prints the plan and a rough cost estimate and makes no calls. A real
run prints the estimate and asks to proceed (`--yes` skips), then reports actual
token cost. `--max-items` (default 20) caps a run; `--batch-size` (default 5) sets
questions per call. Model is `claude-sonnet-5-5`.

## What gets checked

A candidate is staged only if it passes all of these; otherwise it goes to
`staging/rejected.json` with the reasons (useful for tuning the prompt).

1. Schema: known skill in the right section, 1-5 difficulty, 4 distinct choices,
   valid `correct_index`, explanation present, gate stem under 160 chars and no
   gate passage, reading session items have a passage.
2. Math key recomputed: the model supplies `solution_expr` (a Python arithmetic
   expression that does not see the choices); it is evaluated in a restricted
   AST sandbox and compared to the keyed choice. No distractor may equal the answer.
3. Near-duplicates: character-trigram cosine against the live bank, already
   staged items, and `pipeline/reference/*.json` if present (local only, gitignored).
   Rejects at 0.85 or above.
4. Blind solve: a second call answers the question without seeing the key. A
   disagreement means a wrong key or more than one defensible answer, so it is
   rejected. This is the only key check for math items with no computed answer.
   Skip with `--no-blind-solve` (math items without a computed key are then rejected).

Every staged item has `reviewed: false`, a `provenance` object (`generated_by`,
`model`, `date`, `prompt_version`), and a `verification` object. Strip
`provenance`/`verification` or add columns for them when promoting.

## Coverage

The report lists, per skill, live and staged counts, gate/session split,
difficulty histogram, and the gap to `--target-per-skill`, plus the spread of
correct-answer positions in staged items. `--fill-gaps` targets the largest
weighted deficits first. Skills that need a passage or notes are planned as
session tier only.

## Review checklist for a human

Solve each item yourself, check the explanation, confirm nothing resembles
official material, then move it into the bank and run `validate.py` (math items
need a `MATH_KEYS` entry there).
