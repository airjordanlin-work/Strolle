"""Automated validation for generated questions. No network, stdlib only.

Each check returns a list of problem strings; empty means pass. A candidate
that fails any check is rejected and logged, never staged.
"""
import ast
import math
import re
from fractions import Fraction

GATE_MAX_STEM_CHARS = 160  # mirrors content/question_bank/validate.py
FOUR_D = {"delegation", "description", "discernment", "diligence"}
SIMILARITY_REJECT_THRESHOLD = 0.85


# --- schema -----------------------------------------------------------------

def schema_problems(item: dict, skill_section: dict) -> list[str]:
    p = []
    for key in ("section", "skill", "difficulty", "tier", "four_d", "stem",
                "choices", "correct_index", "explanation"):
        if key not in item:
            p.append(f"missing {key}")
    if p:
        return p
    if item["skill"] not in skill_section:
        p.append(f"unknown skill {item['skill']}")
    elif skill_section[item["skill"]] != item["section"]:
        p.append(f"skill {item['skill']} belongs to {skill_section[item['skill']]}")
    if item["four_d"] not in FOUR_D:
        p.append(f"bad four_d {item['four_d']}")
    if item["tier"] not in ("gate", "session"):
        p.append(f"bad tier {item['tier']}")
    if not (isinstance(item["difficulty"], int) and 1 <= item["difficulty"] <= 5):
        p.append("difficulty must be an int 1-5")
    ch = item["choices"]
    if not (isinstance(ch, list) and len(ch) == 4 and all(isinstance(c, str) and c.strip() for c in ch)):
        p.append("need exactly 4 non-empty string choices")
        return p
    if len({_norm(c) for c in ch}) != 4:
        p.append("choices are not 4 distinct values")
    if not (isinstance(item["correct_index"], int) and 0 <= item["correct_index"] < 4):
        p.append("correct_index out of range")
    if len(item["explanation"].strip()) < 25:
        p.append("explanation too thin to teach anything")
    if not item["stem"].strip():
        p.append("empty stem")
    if item["tier"] == "gate":
        if item.get("passage"):
            p.append("gate items never carry a passage")
        if len(item["stem"]) > GATE_MAX_STEM_CHARS:
            p.append(f"gate stem over {GATE_MAX_STEM_CHARS} chars")
    elif item["section"] == "reading" and not item.get("passage"):
        p.append("reading session items need a passage")
    # The explanation must not point at a different choice than the key.
    return p


def _norm(s: str) -> str:
    return re.sub(r"\s+", "", s.lower().replace("−", "-"))


# --- math key verification ----------------------------------------------------

_ALLOWED_FUNCS = {
    "Fraction": Fraction, "sqrt": math.sqrt, "pi": math.pi, "abs": abs,
    "round": round, "min": min, "max": max, "sum": sum, "floor": math.floor,
    "ceil": math.ceil, "comb": math.comb, "factorial": math.factorial,
    "sin": math.sin, "cos": math.cos, "tan": math.tan, "radians": math.radians,
    "degrees": math.degrees, "gcd": math.gcd,
}
_ALLOWED_NODES = (ast.Expression, ast.BinOp, ast.UnaryOp, ast.Constant, ast.Name,
                  ast.Call, ast.Load, ast.Tuple, ast.List, ast.Add, ast.Sub,
                  ast.Mult, ast.Div, ast.FloorDiv, ast.Mod, ast.Pow, ast.USub, ast.UAdd)


def safe_eval(expr: str, variables: dict | None = None):
    """Evaluate a small arithmetic expression. Whitelisted AST only."""
    tree = ast.parse(expr.strip(), mode="eval")
    names = {**_ALLOWED_FUNCS, **(variables or {})}
    for node in ast.walk(tree):
        if not isinstance(node, _ALLOWED_NODES):
            raise ValueError(f"disallowed syntax {type(node).__name__}")
        if isinstance(node, ast.Name) and node.id not in names:
            raise ValueError(f"unknown name {node.id}")
        if isinstance(node, ast.Call) and not (
                isinstance(node.func, ast.Name) and node.func.id in _ALLOWED_FUNCS and not node.keywords):
            raise ValueError("disallowed call")
        if isinstance(node, ast.Constant):
            if not isinstance(node.value, (int, float)) or abs(node.value) > 1e9:
                raise ValueError("disallowed constant")
        if isinstance(node, ast.BinOp) and isinstance(node.op, ast.Pow):
            e = node.right
            if not (isinstance(e, ast.Constant) or (isinstance(e, ast.UnaryOp) and isinstance(e.operand, ast.Constant))):
                raise ValueError("exponent must be a literal")
            if abs(ast.literal_eval(e)) > 50:
                raise ValueError("exponent too large")
    return eval(compile(tree, "<expr>", "eval"), {"__builtins__": {}}, names)


_NUM = re.compile(r"[-+]?(?:\d+\.?\d*|\.\d+)(?:/\d+)?")


def parse_choice_number(text: str):
    """First number in a choice ('$60', '3/5', '9π', '47°'); π multiplies."""
    t = text.replace("−", "-").replace(",", "").replace("$", "").strip()
    m = _NUM.match(t)
    if not m:
        return None
    raw = m.group()
    val = Fraction(raw) if "/" in raw else Fraction(raw)
    rest = t[m.end():].lstrip()
    if rest.startswith("π"):
        return float(val) * math.pi
    return val


def _close(a, b) -> bool:
    return math.isclose(float(a), float(b), rel_tol=1e-9, abs_tol=1e-9)


def _poly_choice(text: str) -> str:
    """'2x + 12' -> '2*x + 12' so it can go through safe_eval."""
    t = text.replace("−", "-").replace("^", "**").replace("$", "")
    t = re.sub(r"(\d)\s*([a-z(])", r"\1*\2", t)
    t = re.sub(r"([a-z)])\s*(\d|\()", r"\1*\2", t)
    return t


def math_key_problems(item: dict, answer_kind: str, solution_expr: str) -> tuple[list[str], str]:
    """Recompute the answer independently of the key.

    answer_kind: numeric | expression | none. Returns (problems, how_verified).
    'expression' compares the model-supplied solution (a Python expression in x)
    with the keyed choice at several points.
    """
    keyed = item["choices"][item["correct_index"]]
    if answer_kind == "none" or not solution_expr.strip():
        return [], "none"
    try:
        if answer_kind == "numeric":
            want = safe_eval(solution_expr)
            got = parse_choice_number(keyed)
            if got is None:
                return [f"keyed choice '{keyed}' is not numeric"], "numeric"
            if not _close(want, got):
                return [f"keyed '{keyed}' but recomputed {want}"], "numeric"
            # Wrong choices must not also equal the answer.
            dupes = [c for i, c in enumerate(item["choices"])
                     if i != item["correct_index"]
                     and (v := parse_choice_number(c)) is not None and _close(want, v)]
            return ([f"distractor equals the answer: {dupes}"] if dupes else []), "numeric"
        if answer_kind == "expression":
            for x in (-3, 0, 1, 7):
                if not _close(safe_eval(solution_expr, {"x": x}),
                              safe_eval(_poly_choice(keyed), {"x": x})):
                    return [f"keyed expression '{keyed}' differs from solution at x={x}"], "expression"
            for i, c in enumerate(item["choices"]):
                if i != item["correct_index"] and all(
                        _close(safe_eval(solution_expr, {"x": x}), safe_eval(_poly_choice(c), {"x": x}))
                        for x in (-3, 0, 1, 7)):
                    return [f"distractor '{c}' is equivalent to the answer"], "expression"
            return [], "expression"
    except Exception as e:  # unparsable key or expression: treat as unverified
        return [f"could not verify math key: {e}"], answer_kind
    return [f"unknown answer_kind {answer_kind}"], answer_kind


# --- near-duplicate detection -------------------------------------------------

def _shingles(text: str, n: int = 3) -> dict:
    t = re.sub(r"[^a-z0-9 ]+", " ", text.lower().replace("−", "-"))
    t = re.sub(r"\s+", " ", t).strip()
    grams: dict = {}
    for i in range(max(len(t) - n + 1, 1)):
        g = t[i:i + n]
        grams[g] = grams.get(g, 0) + 1
    return grams


def similarity(a: str, b: str) -> float:
    """Cosine similarity over character trigrams (stdlib stand-in for embeddings)."""
    va, vb = _shingles(a), _shingles(b)
    dot = sum(c * vb.get(g, 0) for g, c in va.items())
    na = math.sqrt(sum(c * c for c in va.values()))
    nb = math.sqrt(sum(c * c for c in vb.values()))
    return dot / (na * nb) if na and nb else 0.0


def item_text(item: dict) -> str:
    return " ".join([item.get("passage") or "", item["stem"], " | ".join(item["choices"])])


def nearest_duplicate(item: dict, others: list[dict]) -> tuple[float, str | None]:
    """Highest similarity against `others` (dicts with 'id' and the item fields)."""
    text = item_text(item)
    best, best_id = 0.0, None
    for o in others:
        s = similarity(text, item_text(o))
        if s > best:
            best, best_id = s, o.get("id")
    return best, best_id
