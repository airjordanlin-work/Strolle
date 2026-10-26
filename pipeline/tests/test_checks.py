import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))
import checks  # noqa: E402

SECTIONS = {"systems-of-linear-equations": "math", "transitions": "writing"}


def item(**kw):
    base = {"section": "math", "skill": "systems-of-linear-equations", "difficulty": 3,
            "tier": "gate", "four_d": "delegation",
            "stem": "If x + y = 10 and x − y = 4, what is x?",
            "choices": ["3", "6", "7", "14"], "correct_index": 2,
            "explanation": "Add the equations so y cancels and x is 7."}
    base.update(kw)
    return base


class SchemaTests(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(checks.schema_problems(item(), SECTIONS), [])

    def test_duplicate_choices(self):
        self.assertTrue(checks.schema_problems(item(choices=["3", "3", "7", "14"]), SECTIONS))

    def test_gate_passage_and_length(self):
        self.assertTrue(checks.schema_problems(item(passage="x"), SECTIONS))
        self.assertTrue(checks.schema_problems(item(stem="x" * 200), SECTIONS))

    def test_wrong_section(self):
        self.assertTrue(checks.schema_problems(item(section="writing"), SECTIONS))


class MathTests(unittest.TestCase):
    def test_numeric_ok(self):
        self.assertEqual(checks.math_key_problems(item(), "numeric", "(10+4)/2")[0], [])

    def test_numeric_wrong_key(self):
        self.assertTrue(checks.math_key_problems(item(correct_index=1), "numeric", "(10+4)/2")[0])

    def test_distractor_equals_answer(self):
        self.assertTrue(checks.math_key_problems(item(choices=["7.0", "6", "7", "14"]), "numeric", "7")[0])

    def test_pi_and_fraction(self):
        pi = item(choices=["3π", "6π", "9π", "18π"], correct_index=2)
        self.assertEqual(checks.math_key_problems(pi, "numeric", "pi*3**2/pi*pi")[0], [])
        fr = item(choices=["3/5", "4/5", "3/4", "5/3"], correct_index=0)
        self.assertEqual(checks.math_key_problems(fr, "numeric", "Fraction(3,5)")[0], [])

    def test_expression(self):
        it = item(choices=["2x + 12", "4x + 12", "2x + 4", "3x + 12"], correct_index=0)
        self.assertEqual(checks.math_key_problems(it, "expression", "3*(x+4)-x")[0], [])
        it["correct_index"] = 1
        self.assertTrue(checks.math_key_problems(it, "expression", "3*(x+4)-x")[0])

    def test_unsafe_expr_rejected(self):
        for bad in ("__import__('os').system('x')", "().__class__", "2**9999", "open('f')"):
            self.assertTrue(checks.math_key_problems(item(), "numeric", bad)[0], bad)


class SimilarityTests(unittest.TestCase):
    def test_identical_and_different(self):
        a = item()
        b = item(stem="A rectangle has a perimeter of 30 and a length of 9. Find its width.",
                 choices=["3", "6", "12", "21"])
        self.assertGreater(checks.nearest_duplicate(a, [dict(a, id="a")])[0], 0.99)
        self.assertLess(checks.nearest_duplicate(a, [dict(b, id="b")])[0], checks.SIMILARITY_REJECT_THRESHOLD)


if __name__ == "__main__":
    unittest.main()
