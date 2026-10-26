"""Offline question generation: generate, validate, stage, report coverage.

Rules that are not negotiable:
  1. Prompt against the published skill taxonomy, never against a
     specific source question.
  2. Reject anything too similar to the existing bank, the staged items,
     and the local reference set. Models do occasionally reproduce
     near-verbatim text.
  3. Verify math answer keys programmatically. Generated keys are wrong
     often enough that this is not optional.
  4. Everything lands reviewed=false, in pipeline/staging/, never in the
     live bank. A person promotes items by hand.

pipeline/reference/ is gitignored. Official practice material stays
local and is used for prompt tuning only (here: as a similarity filter).

Usage (see pipeline/README.md):
  python3 pipeline/src/generate.py --report
  python3 pipeline/src/generate.py --fill-gaps --target-per-skill 6 --dry-run
  python3 pipeline/src/generate.py --skill percentages --difficulty 3 --tier gate -n 5
Needs ANTHROPIC_API_KEY in the environment for anything but --dry-run/--report.
"""
import argparse
import hashlib
import json
import os
import sys
from collections import Counter
from dataclasses import dataclass
from datetime import date
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import checks  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
BANK_DIR = ROOT / "content" / "question_bank"
STAGING_DIR = ROOT / "pipeline" / "staging"
REFERENCE_DIR = ROOT / "pipeline" / "reference"

MODEL = "claude-sonnet-5-5"
PROMPT_VERSION = "v1"
PRICE_IN, PRICE_OUT = 2.00, 10.00  # USD per 1M tokens, Sonnet 5.5
TIME_TARGET = {"gate": 15, "session": 75}  # matches the seed bank
MAX_EXAMPLES_IN_PROMPT = 6
# Need a passage or notes, which gate items never carry.
SESSION_ONLY = {"text-structure-purpose", "cross-text-connections", "central-ideas",
                "command-of-evidence-textual", "command-of-evidence-quantitative",
                "inferences", "rhetorical-synthesis"}

SYSTEM = """You write original practice questions for a digital-SAT-style prep app.

Hard rules:
- Every question is original. Never reproduce, reconstruct, or closely paraphrase any real SAT, College Board, or other published test item. Use invented scenarios, names, and numbers.
- Exactly one choice is correct. The three distractors must each be wrong for a reason a student could plausibly fall for (a sign slip, a misread, a half-finished step), and none may be arguably correct.
- Four choices, all distinct. Vary which position holds the correct answer across the batch.
- The explanation teaches: say why the key is right and name the trap in the most tempting wrong choice. Keep it under 60 words.
- Math: keep numbers clean enough to do without a calculator. Give `solution_expr`, a single Python arithmetic expression that computes the answer from the problem's givens WITHOUT referring to the choices (functions available: Fraction, sqrt, pi, abs, round, min, max, sum, floor, ceil, comb, factorial, sin, cos, radians, gcd; `**` for powers with a literal exponent). Use answer_kind "numeric" when the key is a number (for percents or degrees give just the number; for kπ use `k*pi`), "expression" when the key is an algebraic expression (then `solution_expr` is written in the variable x and the choices use x), and "none" with an empty `solution_expr` only for interpretation questions that have no single computed value.
- Non-math: answer_kind is "none" and solution_expr is "".
- `passage` is "" for gate-tier items. Session-tier reading items need a short original passage (40-120 words) you invent; session math or writing items may use a passage or a short table only if the stem needs it.
- `four_d` is the one habit that most decides whether a student gets it right.

Difficulty scale: 1 = one routine step, 2 = two steps or a familiar trap, 3 = typical test-day item, 4 = multi-step or a subtle trap, 5 = hardest items, still solvable in about two minutes.
Tiers: gate = readable and answerable in about 15 seconds, stem under 160 characters, no passage. session = a fuller question, about 75 seconds."""

ITEM_SCHEMA = {
    "type": "object",
    "properties": {
        "four_d": {"type": "string", "enum": sorted(checks.FOUR_D)},
        "passage": {"type": "string"},
        "stem": {"type": "string"},
        "choices": {"type": "array", "items": {"type": "string"}},
        "correct_index": {"type": "integer"},
        "explanation": {"type": "string"},
        "answer_kind": {"type": "string", "enum": ["numeric", "expression", "none"]},
        "solution_expr": {"type": "string"},
    },
    "required": ["four_d", "passage", "stem", "choices", "correct_index",
                 "explanation", "answer_kind", "solution_expr"],
    "additionalProperties": False,
}
BATCH_SCHEMA = {"type": "object",
                "properties": {"items": {"type": "array", "items": ITEM_SCHEMA}},
                "required": ["items"], "additionalProperties": False}
SOLVE_SCHEMA = {"type": "object",
                "properties": {"choice_index": {"type": "integer"}},
                "required": ["choice_index"], "additionalProperties": False}


# --- data ---------------------------------------------------------------------

def load_json(path: Path, default):
    return json.loads(path.read_text()) if path.exists() else default


def load_taxonomy():
    doc = json.loads((BANK_DIR / "skills.json").read_text())
    skill_section = {s: d["section"] for d in doc["domains"] for s in d["skills"]}
    skill_weight = {s: d["sat_weight"] / len(d["skills"]) for d in doc["domains"] for s in d["skills"]}
    return doc, skill_section, skill_weight


def load_reference() -> list[dict]:
    """Local-only official material, used purely as a similarity filter."""
    out = []
    for f in sorted(REFERENCE_DIR.glob("*.json")) if REFERENCE_DIR.is_dir() else []:
        data = json.loads(f.read_text())
        out += [{"id": f"ref:{f.name}", **d} for d in data if isinstance(d, dict) and "stem" in d and "choices" in d]
    return out


# --- coverage -----------------------------------------------------------------

def coverage_report(bank: list[dict], staged: list[dict], skill_section: dict, skill_weight: dict,
                    target: int) -> str:
    live, new = Counter(i["skill"] for i in bank), Counter(i["skill"] for i in staged)
    lines = [f"Coverage (live bank + staged; target {target} per skill)",
             f"{'skill':38}{'section':9}{'weight':>7}{'live':>6}{'staged':>7}{'gate':>6}{'sess':>6}  difficulty 1-5   gap"]
    allitems = bank + staged
    for s in sorted(skill_section, key=lambda s: (skill_section[s], -skill_weight[s], s)):
        its = [i for i in allitems if i["skill"] == s]
        tiers = Counter(i["tier"] for i in its)
        diffs = Counter(i["difficulty"] for i in its)
        gap = max(target - len(its), 0)
        lines.append(f"{s:38}{skill_section[s]:9}{skill_weight[s]:7.3f}{live[s]:6}{new[s]:7}"
                     f"{tiers['gate']:6}{tiers['session']:6}  "
                     f"{' '.join(str(diffs[d]) for d in range(1, 6))}          "
                     f"{'-' + str(gap) if gap else 'ok'}")
    if staged:
        pos = Counter(i["correct_index"] for i in staged)
        lines.append(f"\nStaged correct-answer positions: {dict(sorted(pos.items()))} (should be roughly even)")
    return "\n".join(lines)


# --- planning and cost --------------------------------------------------------

@dataclass
class Job:
    skill: str
    difficulty: int
    tier: str
    n: int


def plan_fill_gaps(bank, staged, skill_section, skill_weight, target, batch_size, max_items) -> list[Job]:
    """Biggest weighted deficits first; spread difficulty 2-4 and alternate tiers."""
    counts = Counter(i["skill"] for i in bank + staged)
    deficits = {s: target - counts[s] for s in skill_section if counts[s] < target}
    order = sorted(deficits, key=lambda s: -(deficits[s] * skill_weight[s]))
    jobs: list[Job] = []
    remaining = max_items
    for s in order:
        need = min(deficits[s], remaining)
        k = 0
        while need > 0:
            n = min(batch_size, need)
            tier = "session" if s in SESSION_ONLY else ("gate", "session")[k % 2]
            jobs.append(Job(s, (2, 3, 4)[k % 3], tier, n))
            need -= n
            remaining -= n
            k += 1
        if remaining <= 0:
            break
    return jobs


def build_prompt(job: Job, skill_section: dict, four_d_defs: dict, examples: list[dict]) -> str:
    ex = "\n".join(f"- {e['stem']}" for e in examples[:MAX_EXAMPLES_IN_PROMPT])
    defs = "\n".join(f"- {k}: {v}" for k, v in four_d_defs.items())
    return (f"Write {job.n} new questions.\n"
            f"Section: {skill_section[job.skill]}\nSkill: {job.skill}\n"
            f"Difficulty: {job.difficulty}\nTier: {job.tier}\n\n"
            f"The four habits (pick one `four_d` per item, and vary them across the batch):\n{defs}\n\n"
            + (f"Stems already in our bank for this skill. Do not repeat these scenarios or structures:\n{ex}\n\n" if ex else "")
            + "Return the questions as JSON matching the schema.")


def estimate_cost(jobs: list[Job], prompts: list[str], blind_solve: bool) -> dict:
    """Rough: ~3.5 chars/token in; output per item includes thinking at medium effort."""
    in_tok = out_tok = 0
    for j, p in zip(jobs, prompts):
        in_tok += (len(SYSTEM) + len(p)) / 3.5
        out_tok += j.n * (900 if j.tier == "session" else 600)
        if blind_solve:
            in_tok += j.n * 400
            out_tok += j.n * 500
    usd = in_tok / 1e6 * PRICE_IN + out_tok / 1e6 * PRICE_OUT
    return {"input_tokens": int(in_tok), "output_tokens": int(out_tok), "usd": usd}


# --- API ----------------------------------------------------------------------

class Api:
    def __init__(self):
        import anthropic
        self.client = anthropic.Anthropic()  # key from ANTHROPIC_API_KEY, never hardcoded
        self.in_tok = self.out_tok = 0

    def _call(self, system: str, user: str, schema: dict, effort: str, max_tokens: int = 16000) -> dict | None:
        r = self.client.messages.create(
            model=MODEL, max_tokens=max_tokens, system=system,
            output_config={"effort": effort, "format": {"type": "json_schema", "schema": schema}},
            messages=[{"role": "user", "content": user}])
        self.in_tok += r.usage.input_tokens
        self.out_tok += r.usage.output_tokens
        if r.stop_reason != "end_turn":
            print(f"  ! stop_reason={r.stop_reason}; batch skipped", file=sys.stderr)
            return None
        text = next((b.text for b in r.content if b.type == "text"), "")
        return json.loads(text)

    def generate(self, prompt: str) -> list[dict]:
        out = self._call(SYSTEM, prompt, BATCH_SCHEMA, "medium")
        return out["items"] if out else []

    def blind_solve(self, item: dict) -> int | None:
        letters = "ABCD"
        q = (item.get("passage") + "\n\n" if item.get("passage") else "") + item["stem"] + "\n" + \
            "\n".join(f"{letters[i]}. {c}" for i, c in enumerate(item["choices"]))
        out = self._call("You are an expert SAT tutor. Answer the question. Return choice_index as 0-3 "
                         "(A=0). If you think none or several choices are correct, pick the best one.",
                         q, SOLVE_SCHEMA, "medium", max_tokens=8000)
        return out["choice_index"] if out else None

    def cost(self) -> float:
        return self.in_tok / 1e6 * PRICE_IN + self.out_tok / 1e6 * PRICE_OUT


# --- pipeline -----------------------------------------------------------------

def make_id(skill: str, raw: dict) -> str:
    h = hashlib.sha1((raw["stem"] + "|".join(raw["choices"])).encode()).hexdigest()[:8]
    return f"g-{skill}-{h}"


def process(raw: dict, job: Job, skill_section: dict, pool: list[dict], api: Api | None) -> tuple[dict | None, list[str]]:
    """Validate one generated item. Returns (staged item or None, problems)."""
    item = {
        "id": make_id(job.skill, raw) if isinstance(raw.get("stem"), str) and isinstance(raw.get("choices"), list) else "g-bad",
        "section": skill_section[job.skill], "skill": job.skill, "difficulty": job.difficulty,
        "tier": job.tier, "four_d": raw.get("four_d"), "time_target_seconds": TIME_TARGET[job.tier],
        "stem": raw.get("stem", ""), "choices": raw.get("choices", []),
        "correct_index": raw.get("correct_index"), "explanation": raw.get("explanation", ""),
        "reviewed": False,
    }
    if raw.get("passage"):
        item["passage"] = raw["passage"]
    problems = checks.schema_problems(item, skill_section)
    if problems:
        return None, problems
    verified = {}
    if item["section"] == "math":
        mp, how = checks.math_key_problems(item, raw.get("answer_kind", "none"), raw.get("solution_expr", ""))
        problems += mp
        verified["math_key"] = how
    sim, sim_id = checks.nearest_duplicate(item, pool)
    verified["max_similarity"] = round(sim, 3)
    if sim >= checks.SIMILARITY_REJECT_THRESHOLD:
        problems.append(f"too similar ({sim:.2f}) to {sim_id}")
    if problems:
        return None, problems
    if api is not None:  # last, since it costs money
        guess = api.blind_solve(item)
        verified["blind_solve_agrees"] = guess == item["correct_index"]
        if guess != item["correct_index"]:
            return None, [f"blind solver chose {guess}, key is {item['correct_index']} (wrong key or ambiguous)"]
    if item["section"] == "math" and verified["math_key"] == "none" and "blind_solve_agrees" not in verified:
        return None, ["math item has no computed key and blind-solve is off"]
    item["provenance"] = {"generated_by": "pipeline/src/generate.py", "model": MODEL,
                          "date": date.today().isoformat(), "prompt_version": PROMPT_VERSION}
    item["verification"] = verified
    return item, []


def save(path: Path, data: list[dict]):
    STAGING_DIR.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(".tmp")
    tmp.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")
    tmp.replace(path)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--skill"); ap.add_argument("--difficulty", type=int, choices=range(1, 6))
    ap.add_argument("--tier", choices=["gate", "session"]); ap.add_argument("-n", type=int, default=5)
    ap.add_argument("--fill-gaps", action="store_true", help="plan jobs for the thinnest skills")
    ap.add_argument("--target-per-skill", type=int, default=6)
    ap.add_argument("--batch-size", type=int, default=5, help="questions per API call")
    ap.add_argument("--max-items", type=int, default=20, help="hard cap on questions requested per run")
    ap.add_argument("--dry-run", action="store_true", help="print the plan and cost estimate; no API calls")
    ap.add_argument("--report", action="store_true", help="print coverage and exit")
    ap.add_argument("--no-blind-solve", action="store_true", help="skip the second-model answer check")
    ap.add_argument("--yes", action="store_true", help="don't pause for confirmation before spending")
    a = ap.parse_args()

    doc, skill_section, skill_weight = load_taxonomy()
    bank = load_json(BANK_DIR / "questions.json", [])
    staged = load_json(STAGING_DIR / "generated.json", [])
    rejected = load_json(STAGING_DIR / "rejected.json", [])
    reference = load_reference()

    if a.report:
        print(coverage_report(bank, staged, skill_section, skill_weight, a.target_per_skill))
        return 0

    if a.fill_gaps:
        jobs = plan_fill_gaps(bank, staged, skill_section, skill_weight, a.target_per_skill, a.batch_size, a.max_items)
    elif a.skill and a.difficulty and a.tier:
        if a.skill not in skill_section:
            ap.error(f"unknown skill {a.skill}; see content/question_bank/skills.json")
        if a.skill in SESSION_ONLY and a.tier == "gate":
            ap.error(f"{a.skill} needs a passage or notes; use --tier session")
        jobs = [Job(a.skill, a.difficulty, a.tier, min(a.n, a.max_items))]
    else:
        ap.error("give --report, --fill-gaps, or all of --skill --difficulty --tier")
    if not jobs:
        print("Nothing to do: every skill is at or above the target.")
        return 0

    prompts = [build_prompt(j, skill_section, doc["four_d"],
                            [i for i in bank + staged if i["skill"] == j.skill]) for j in jobs]
    est = estimate_cost(jobs, prompts, not a.no_blind_solve)
    print(f"Plan: {sum(j.n for j in jobs)} questions in {len(jobs)} calls on {MODEL} (prompt {PROMPT_VERSION})")
    for j in jobs:
        print(f"  {j.n} x {j.skill} d{j.difficulty} {j.tier}")
    print(f"Estimated cost: ~${est['usd']:.2f} ({est['input_tokens']:,} in / {est['output_tokens']:,} out tokens, rough)")
    if a.dry_run:
        return 0
    if not os.environ.get("ANTHROPIC_API_KEY"):
        print("Set ANTHROPIC_API_KEY in your environment (never commit it).", file=sys.stderr)
        return 2
    if not a.yes and sys.stdin.isatty() and input("Proceed? [y/N] ").strip().lower() != "y":
        return 1

    api = Api()
    pool = bank + staged + reference
    accepted = 0
    for j, prompt in zip(jobs, prompts):
        print(f"- {j.skill} d{j.difficulty} {j.tier} x{j.n}")
        for raw in api.generate(prompt):
            item, problems = process(raw, j, skill_section, pool, None if a.no_blind_solve else api)
            if item:
                staged.append(item); pool.append(item); accepted += 1
                print(f"    staged {item['id']}")
            else:
                rejected.append({"date": date.today().isoformat(), "prompt_version": PROMPT_VERSION,
                                 "skill": j.skill, "problems": problems, "raw": raw})
                print(f"    rejected: {'; '.join(problems)}")
        save(STAGING_DIR / "generated.json", staged)  # persist per job so a crash loses little
        save(STAGING_DIR / "rejected.json", rejected)

    print(f"\nStaged {accepted} / {sum(j.n for j in jobs)}; actual cost ~${api.cost():.2f} "
          f"({api.in_tok:,} in / {api.out_tok:,} out)")
    print(f"Output: {STAGING_DIR / 'generated.json'} (reviewed=false; not merged anywhere)\n")
    print(coverage_report(bank, staged, skill_section, skill_weight, a.target_per_skill))
    return 0


if __name__ == "__main__":
    sys.exit(main())
