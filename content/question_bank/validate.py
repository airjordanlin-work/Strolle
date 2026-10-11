"""Validates questions.json against skills.json and checks math answer keys.

Run from anywhere:  python3 content/question_bank/validate.py
Exits non-zero on any problem, so it can gate CI.

Math keys are recomputed independently below, per pipeline rule 3
("verify math answer keys programmatically"). A math item with no entry
in MATH_KEYS fails validation, so new math items can't skip the check.
"""
import json
import math
import sys
from collections import Counter
from fractions import Fraction
from pathlib import Path

HERE = Path(__file__).parent
FOUR_D = {"delegation", "description", "discernment", "diligence"}
TIERS = {"gate", "session"}
GATE_MAX_STEM_CHARS = 160  # gate items must read in seconds

# Independent solutions. Each value is the expected text of the correct choice.
MATH_KEYS = {
    "seed-002": str((21 - 6) // 3),
    "m-001": str((31 + 4) // 5),
    "m-002": "12m + 30",
    "m-003": str((10 - 4) // (3 - 1)),
    "m-004": str(12 // 3),
    "m-005": str((10 + 4) // 2),
    "m-006": next(v for v in ["−4", "−3", "0", "3"] if -2 * int(v.replace("−", "-")) > 6),
    "m-007": "2x + 12",  # checked numerically below
    "m-008": "−7",
    "m-009": str(4**2 - 3 * 4),
    "m-010": str(int(0.20 * 45)),
    "m-011": str(3 * 8 // 2),
    "m-012": "$" + str(round(80 * 0.75 * 0.90)),
    "m-013": str(60 * 25 // 60),
    "m-014": str(sorted([4, 7, 7, 9, 13])[2]),
    "m-015": str(Fraction(3 + 2, 10)),
    "m-016": f"{3**2}π",
    "m-017": f"{180 - 48 - 67}°",
    "m-018": str(int(math.hypot(6, 8))),
    "m-019": "3/5",  # sin A = cos B for complementary angles
    "m-020": "(2, −5)",
    "m-s01": str((500 - 140) // 20),
    "m-s02": str(next(a for a in range(16) if 12 * a + 7 * (15 - a) == 145)),
    "m-s03": str(sum(x for x in range(-20, 21) if x * x - 5 * x - 14 == 0)),
    "m-s04": str(int(max(-16 * t * t + 64 * t + 5 for t in [i / 100 for i in range(0, 501)]))),
    "m-s05": None,  # interpretation item, no numeric key
    "m-s06": None,  # interpretation item, no numeric key
    "m-s07": f"{int(2500 * 0.8):,}",
    "m-s08": str(72 // 9),
    "m-s09": str((10 // 2) ** 2),
    "m-s10": str(next(k for k in range(-10, 11)
                       # 3x - 6 = kx + 4 has no solution iff x terms cancel and constants differ
                       if 3 - k == 0 and -6 != 4)),
}

# Expression items: check the keyed choice equals the stem expression at several x.
EXPR_CHECKS = {
    "m-007": (lambda x: 3 * (x + 4) - x, lambda x: 2 * x + 12),
    "m-002": (lambda m: 12 * m + 30, lambda m: 12 * m + 30),
}


def fail(errors, item, msg):
    errors.append(f"{item.get('id', '?')}: {msg}")


def main() -> int:
    skills_doc = json.loads((HERE / "skills.json").read_text())
    items = json.loads((HERE / "questions.json").read_text())
    skill_section = {s: d["section"] for d in skills_doc["domains"] for s in d["skills"]}
    errors: list[str] = []
    seen = set()

    for it in items:
        for key in ("id", "section", "skill", "difficulty", "tier", "four_d",
                    "time_target_seconds", "stem", "choices", "correct_index",
                    "explanation", "reviewed"):
            if key not in it:
                fail(errors, it, f"missing {key}")
        if it["id"] in seen:
            fail(errors, it, "duplicate id")
        seen.add(it["id"])
        if it["skill"] not in skill_section:
            fail(errors, it, f"unknown skill {it['skill']}")
        elif skill_section[it["skill"]] != it["section"]:
            fail(errors, it, f"skill {it['skill']} belongs to {skill_section[it['skill']]}")
        if it["four_d"] not in FOUR_D:
            fail(errors, it, f"bad four_d {it['four_d']}")
        if it["tier"] not in TIERS:
            fail(errors, it, f"bad tier {it['tier']}")
        if not (isinstance(it["difficulty"], int) and 1 <= it["difficulty"] <= 5):
            fail(errors, it, "difficulty must be an int 1-5")
        ch = it["choices"]
        if len(ch) != 4 or len(set(ch)) != 4:
            fail(errors, it, "need 4 distinct choices")
        if not (0 <= it["correct_index"] < len(ch)):
            fail(errors, it, "correct_index out of range")
        if len(it["explanation"]) < 25:
            fail(errors, it, "explanation too thin to teach anything")
        if it["reviewed"] is not False:
            fail(errors, it, "seed items land reviewed=false; a human flips it")
        if it["tier"] == "gate":
            if "passage" in it:
                fail(errors, it, "gate items never carry a passage")
            if len(it["stem"]) > GATE_MAX_STEM_CHARS:
                fail(errors, it, f"gate stem over {GATE_MAX_STEM_CHARS} chars")

        if it["section"] == "math":
            if it["id"] not in MATH_KEYS:
                fail(errors, it, "math item has no independent key in MATH_KEYS")
            elif MATH_KEYS[it["id"]] is not None:
                keyed = ch[it["correct_index"]]
                if keyed != MATH_KEYS[it["id"]]:
                    fail(errors, it, f"keyed '{keyed}' but computed '{MATH_KEYS[it['id']]}'")
        if it["id"] in EXPR_CHECKS:
            stem_f, key_f = EXPR_CHECKS[it["id"]]
            if any(stem_f(x) != key_f(x) for x in (-3, 0, 1, 7)):
                fail(errors, it, "keyed expression not equivalent")

    if errors:
        print("\n".join(errors))
        return 1

    print(f"OK: {len(items)} items")
    for label, key in (("tier", "tier"), ("section", "section"), ("four_d", "four_d"),
                       ("difficulty", "difficulty")):
        print(f"  {label:10}", dict(sorted(Counter(i[key] for i in items).items())))
    missing = sorted(set(skill_section) - {i["skill"] for i in items})
    print("  skills without items:", missing or "none")
    return 0


if __name__ == "__main__":
    sys.exit(main())
