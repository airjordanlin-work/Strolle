import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))
import generate  # noqa: E402

SECTIONS = {"percentages": "math", "central-ideas": "reading"}


class FakeApi:
    def __init__(self, answer):
        self.answer = answer

    def blind_solve(self, item):
        return self.answer


def raw(**kw):
    base = {"four_d": "diligence", "passage": "", "stem": "A jacket costs $80 and is 25% off. Sale price?",
            "choices": ["$20", "$55", "$60", "$75"], "correct_index": 2,
            "explanation": "25% of 80 is 20, so the sale price is 80 - 20 = 60; $20 is the discount.",
            "answer_kind": "numeric", "solution_expr": "80*(1-0.25)"}
    base.update(kw)
    return base


JOB = generate.Job("percentages", 2, "gate", 1)


class ProcessTests(unittest.TestCase):
    def test_accepts_and_stamps_provenance(self):
        item, problems = generate.process(raw(), JOB, SECTIONS, [], FakeApi(2))
        self.assertEqual(problems, [])
        self.assertIs(item["reviewed"], False)
        self.assertEqual(item["provenance"]["model"], generate.MODEL)
        self.assertEqual(item["provenance"]["prompt_version"], generate.PROMPT_VERSION)

    def test_rejects_wrong_math_key(self):
        item, problems = generate.process(raw(correct_index=1), JOB, SECTIONS, [], FakeApi(1))
        self.assertIsNone(item)
        self.assertTrue(any("recomputed" in p for p in problems))

    def test_rejects_blind_solver_disagreement(self):
        item, problems = generate.process(raw(), JOB, SECTIONS, [], FakeApi(1))
        self.assertIsNone(item)

    def test_rejects_near_duplicate(self):
        existing = [dict(raw(), id="seed")]
        item, problems = generate.process(raw(), JOB, SECTIONS, existing, FakeApi(2))
        self.assertIsNone(item)
        self.assertTrue(any("too similar" in p for p in problems))

    def test_math_without_key_needs_blind_solve(self):
        r = raw(answer_kind="none", solution_expr="")
        self.assertIsNone(generate.process(r, JOB, SECTIONS, [], None)[0])
        self.assertIsNotNone(generate.process(r, JOB, SECTIONS, [], FakeApi(2))[0])


if __name__ == "__main__":
    unittest.main()
