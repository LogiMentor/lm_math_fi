#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 LogiMentor

"""Generate the format-domain expectations the generic-domain gate replays.

Produces two committed files:

  sim/generic_domain/f_lm_quantize_vectors.txt   expectations for f_lm_quantize
  sim/generic_domain/tb_degenerate_formats.vhd   expectations for the four
                                                 entities that quantize a result

INDEPENDENCE IS THE POINT OF THIS FILE
  Nothing here imports, calls, or is transcribed from src/, model/ or js/. The
  arithmetic is written from the documented semantics: a stored word R with
  binary point B denotes the exact rational R / 2**B, with R read as two's
  complement when the format is signed. An expectation taken from the code under
  test would certify nothing, so this file must never grow a dependency on it.

TWO COMPLETE REFERENCES, NOT TWO ROUNDING RULES
  Every expectation is computed by two pipelines that share no arithmetic:

    reference A   stored value decoded with int(bits, 2) and a 2**n correction;
                  rescaling by floor division and remainder; overflow by masking
                  for wrap and min/max for saturate
    reference B   stored value decoded as a weighted sum with a negative
                  most-significant weight; rescaling through exact Fraction
                  arithmetic against the midpoint; overflow by modular reduction
                  onto the representable interval for wrap and an explicit
                  comparison chain for saturate

  Decoding, rescaling, rounding, overflow, and all four operations are
  implemented separately in each. The comparison is on the final emitted bit
  string, so corrupting any one step in either pipeline is caught.

  WHAT THIS DOES NOT BUY. Both references necessarily encode the same model of
  each module's internal structure - which intermediate format a module aligns
  into, and that its accumulator wraps there. Two references cannot disagree
  about a structure they were both told to model. The doubling catches an
  arithmetic slip; it does not catch a shared misreading of what a module does.
  That is what the gate's own comparison against the RTL is for.

USAGE
  python scripts/gen_format_vectors.py             regenerate both files
  python scripts/gen_format_vectors.py --check     fail if either has drifted
  python scripts/gen_format_vectors.py --coverage  print the coverage matrix

  The --check form is a gate step, so the committed expectations cannot drift
  from the generator that is supposed to produce them.

REGENERATING IS A DELIBERATE ACT
  It re-baselines what the library is allowed to compute. Do it only when a
  behaviour change is intended, and say so in the changelog.
"""

from __future__ import annotations

import argparse
import sys
from fractions import Fraction
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
GATE_DIR = ROOT / "sim" / "generic_domain"
VECTOR_FILE = GATE_DIR / "f_lm_quantize_vectors.txt"
ENTITY_TB_FILE = GATE_DIR / "tb_degenerate_formats.vhd"

TRUNC_BITS, ROUND_EVEN, CEIL, TRUNC_ZERO, FLOOR = 0, 1, 2, 3, 4
ROUND_POS_INF, ROUND_NEG_INF, ROUND_ZERO, ROUND_AWAY = 5, 6, 7, 8
SATURATE, WRAP = 1, 2
UNSIGNED, SIGNED = 1, 2
ADD, SUB = 0, 1

ROUND_NAME = {
    TRUNC_BITS: "C_LM_TRUNC_BITS", ROUND_EVEN: "C_LM_ROUND_EVEN", CEIL: "C_LM_CEIL",
    TRUNC_ZERO: "C_LM_TRUNC_ZERO", FLOOR: "C_LM_FLOOR",
    ROUND_POS_INF: "C_LM_ROUND_POS_INF", ROUND_NEG_INF: "C_LM_ROUND_NEG_INF",
    ROUND_ZERO: "C_LM_ROUND_ZERO", ROUND_AWAY: "C_LM_ROUND_AWAY",
}
OVF_NAME = {SATURATE: "C_LM_SATURATE", WRAP: "C_LM_WRAP"}
ARITH_NAME = {UNSIGNED: "C_LM_UNSIGNED", SIGNED: "C_LM_SIGNED"}
DIR_NAME = {ADD: "C_LM_ADD", SUB: "C_LM_SUB"}
ARITH_TAG = {UNSIGNED: "U", SIGNED: "S"}

ALL_ROUNDS = list(range(9))
ALL_OVFS = [SATURATE, WRAP]
ALL_ARITHS = [UNSIGNED, SIGNED]


def bits_of(raw: int, width: int) -> str:
    """Render a stored integer as a two's-complement bit string. Presentation,
    not arithmetic: both references agree on what a bit string looks like."""
    return format(raw & ((1 << width) - 1), f"0{width}b")


# ===========================================================================
# Reference A
# ===========================================================================

class RefA:
    name = "A"

    @staticmethod
    def decode(bits: str, arith: int) -> int:
        value = int(bits, 2)
        if arith == SIGNED and bits[0] == "1":
            return value - (1 << len(bits))
        return value

    @staticmethod
    def store(value: int, width: int, arith: int, ovf: int) -> int:
        if arith == SIGNED:
            low, high = -(1 << (width - 1)), (1 << (width - 1)) - 1
        else:
            low, high = 0, (1 << width) - 1
        if ovf == SATURATE:
            return max(low, min(high, value))
        value &= (1 << width) - 1
        if arith == SIGNED and value >= (1 << (width - 1)):
            value -= 1 << width
        return value

    @staticmethod
    def rescale(raw: int, src_bp: int, dst_bp: int, mode: int) -> int:
        delta = dst_bp - src_bp
        if delta >= 0:
            return raw << delta
        den = 1 << (-delta)
        quotient, remainder = divmod(raw, den)
        if remainder == 0:
            return quotient
        if mode in (TRUNC_BITS, FLOOR):
            return quotient
        if mode == CEIL:
            return quotient + 1
        if mode == TRUNC_ZERO:
            return quotient + 1 if raw < 0 else quotient
        doubled = 2 * remainder
        if doubled > den:
            return quotient + 1
        if doubled < den:
            return quotient
        if mode == ROUND_EVEN:
            return quotient if quotient % 2 == 0 else quotient + 1
        if mode == ROUND_POS_INF:
            return quotient + 1
        if mode == ROUND_NEG_INF:
            return quotient
        if mode == ROUND_ZERO:
            return quotient + 1 if raw < 0 else quotient
        if mode == ROUND_AWAY:
            return quotient if raw < 0 else quotient + 1
        raise ValueError(f"unknown rounding mode {mode}")


# ===========================================================================
# Reference B
# ===========================================================================

class RefB:
    name = "B"

    @staticmethod
    def decode(bits: str, arith: int) -> int:
        # Two's complement straight from its definition: every bit carries its
        # own weight, and the most significant weight is negative when signed.
        width = len(bits)
        total = 0
        for index, char in enumerate(reversed(bits)):
            if char == "1":
                weight = 1 << index
                if arith == SIGNED and index == width - 1:
                    total -= weight
                else:
                    total += weight
        return total

    @staticmethod
    def store(value: int, width: int, arith: int, ovf: int) -> int:
        span = 1 << width
        low = -(span // 2) if arith == SIGNED else 0
        high = low + span - 1
        if ovf == SATURATE:
            if value < low:
                return low
            if value > high:
                return high
            return value
        # Modular reduction onto the representable interval.
        return ((value - low) % span) + low

    @staticmethod
    def rescale(raw: int, src_bp: int, dst_bp: int, mode: int) -> int:
        # The exact represented value, then the destination's integer scale.
        exact = Fraction(raw) / (Fraction(2) ** src_bp) * (Fraction(2) ** dst_bp)
        below = exact.numerator // exact.denominator
        if Fraction(below) == exact:
            return below
        above = below + 1
        if mode in (TRUNC_BITS, FLOOR):
            return below
        if mode == CEIL:
            return above
        if mode == TRUNC_ZERO:
            return above if exact < 0 else below
        midpoint = Fraction(2 * below + 1, 2)
        if exact > midpoint:
            return above
        if exact < midpoint:
            return below
        if mode == ROUND_EVEN:
            return below if below % 2 == 0 else above
        if mode == ROUND_POS_INF:
            return above
        if mode == ROUND_NEG_INF:
            return below
        if mode == ROUND_ZERO:
            return above if exact < 0 else below
        if mode == ROUND_AWAY:
            return below if exact < 0 else above
        raise ValueError(f"unknown rounding mode {mode}")


# ===========================================================================
# The operations, once per reference. Each composes only its own helpers.
# ===========================================================================

def _quantize(R, inbits, ow, obp, oa, nw, nbp, na, rnd, ovf) -> str:
    return bits_of(R.store(R.rescale(R.decode(inbits, oa), obp, nbp, rnd), nw, na, ovf), nw)


def _mult(R, abits, bbits, aw, abp, aa, bw, bbp, ba, nw, nbp, na, rnd, ovf) -> str:
    product = R.decode(abits, aa) * R.decode(bbits, ba)
    product_arith = UNSIGNED if (aa == UNSIGNED and ba == UNSIGNED) else SIGNED
    held = R.store(product, aw + bw, product_arith, WRAP)
    return bits_of(R.store(R.rescale(held, abp + bbp, nbp, rnd), nw, na, ovf), nw)


def _add_sub(R, abits, bbits, aw, abp, bw, bbp, arith, nw, nbp, na, rnd, direction) -> str:
    res_bp = max(abp, bbp)
    res_w = max(aw - abp, bw - bbp) + res_bp + 1
    a = R.store(R.rescale(R.decode(abits, arith), abp, res_bp, TRUNC_BITS), res_w, arith, WRAP)
    b = R.store(R.rescale(R.decode(bbits, arith), bbp, res_bp, TRUNC_BITS), res_w, arith, WRAP)
    acc = R.store(a + b if direction == ADD else a - b, res_w, arith, WRAP)
    return bits_of(R.store(R.rescale(acc, res_bp, nbp, rnd), nw, na, WRAP), nw)


def _mult_add(R, abits, bbits, cbits, aw, abp, bw, bbp, cw, cbp, arith,
              nw, nbp, na, rnd, ovf, direction) -> str:
    mult_bp = abp + bbp
    sum_bp = max(mult_bp, cbp)
    sum_w = max((aw + bw) - mult_bp, cw - cbp) + sum_bp + 1
    raw_product = R.decode(abits, arith) * R.decode(bbits, arith)
    product = R.store(R.rescale(raw_product, mult_bp, sum_bp, TRUNC_BITS), sum_w, arith, WRAP)
    addend = R.store(R.rescale(R.decode(cbits, arith), cbp, sum_bp, TRUNC_BITS), sum_w, arith, WRAP)
    acc = R.store(product + addend if direction == ADD else product - addend,
                  sum_w, arith, WRAP)
    return bits_of(R.store(R.rescale(acc, sum_bp, nbp, rnd), nw, na, ovf), nw)


_DISAGREEMENTS: list[str] = []
_AGREED = 0


def _both(fn, *args) -> str:
    """Run the whole computation under both references and require agreement."""
    global _AGREED
    a = fn(RefA, *args)
    b = fn(RefB, *args)
    if a != b:
        _DISAGREEMENTS.append(f"{fn.__name__}{args!r}: A={a} B={b}")
    _AGREED += 1
    return a


def quantize(*args) -> str:
    return _both(_quantize, *args)


def mult(*args) -> str:
    return _both(_mult, *args)


def add_sub(*args) -> str:
    return _both(_add_sub, *args)


def mult_add(*args) -> str:
    return _both(_mult_add, *args)


# ===========================================================================
# Geometry families. The bench states which must be present; this is only the
# same classification, used to report coverage.
# ===========================================================================

def families(ow: int, obp: int, nw: int, nbp: int) -> list[str]:
    """Classify a source -> destination geometry. A geometry may be in several."""
    out = []
    if obp < ow and nbp < nw:
        out.append("ordinary")
    if obp == ow or nbp == nw:
        out.append("bp_equals_width")
    if obp > ow:
        out.append("bp_above_width_src")
    if nbp > nw:
        out.append("bp_above_width_dst")
    # Bit weights: source spans 2**-obp .. 2**(ow-1-obp).
    if -nbp > ow - 1 - obp:
        out.append("disjoint_dst_above")
    if -obp > nw - 1 - nbp:
        out.append("disjoint_dst_below")
    src = set(range(-obp, ow - obp))
    dst = set(range(-nbp, nw - nbp))
    if len(src & dst) == 1:
        out.append("one_bit_overlap")
    if ow == 1 or nw == 1:
        out.append("width_1")
    return out


REQUIRED_FAMILIES = [
    "ordinary", "bp_equals_width", "bp_above_width_src", "bp_above_width_dst",
    "disjoint_dst_above", "disjoint_dst_below", "one_bit_overlap", "width_1",
]


# ===========================================================================
# The vector file
# ===========================================================================

VECTOR_GEOMETRIES = [
    ("ordinary narrowing, the original baseline geometry", 6, 2, 4, 1),
    ("binary point equal to the width, both sides",        4, 4, 4, 4),
    ("binary point equal to the width, narrowing",         4, 4, 4, 0),
    ("binary point equal to the width, widening",          4, 0, 4, 4),
    ("binary point above the width, source only",          4, 6, 4, 2),
    ("binary point above the width, destination only",     4, 2, 4, 6),
    ("binary point above the width, both sides",           4, 8, 4, 6),
    ("disjoint bit weights, destination entirely above",   4, 8, 4, 0),
    ("disjoint bit weights, destination entirely below",   4, 0, 4, 8),
    ("exactly one bit of weight overlap",                  4, 4, 4, 1),
    ("width 1, no fractional bits",                        1, 0, 1, 0),
    ("width 1, binary point equal to the width",           1, 1, 1, 1),
    ("width 1 source into a wider destination",            1, 1, 4, 3),
    ("width 1 destination from a wider source",            4, 3, 1, 1),
    ("width 1, binary point above the width",              1, 3, 2, 1),
]


def build_vectors():
    rows = []
    tally = []
    for _label, ow, obp, nw, nbp in VECTOR_GEOMETRIES:
        before = len(rows)
        for value in range(1 << ow):
            inbits = bits_of(value, ow)
            for oa in ALL_ARITHS:
                for na in ALL_ARITHS:
                    for rnd in ALL_ROUNDS:
                        for ovf in ALL_OVFS:
                            expected = int(
                                quantize(inbits, ow, obp, oa, nw, nbp, na, rnd, ovf), 2
                            )
                            rows.append((ow, obp, oa, nw, nbp, na, rnd, ovf, value, expected))
        tally.append((ow, obp, nw, nbp, len(rows) - before))
    return rows, tally


def render_vector_file(rows, tally) -> str:
    head = [
        "# SPDX-License-Identifier: Apache-2.0",
        "# Copyright 2026 LogiMentor",
        "#",
        "# Expected values for lm_math_fi_pkg.f_lm_quantize, replayed by",
        "# sim/generic_domain/tb_quantize_vectors.vhd.",
        "#",
        "# GENERATED FILE - do not edit by hand.",
        "#",
        "# HOW THESE WERE PRODUCED",
        "#   Every value here is emitted by scripts/gen_format_vectors.py, which",
        "#   computes the arithmetic from the documented semantics using Python's",
        "#   arbitrary-precision integers and fractions. It implements the whole path",
        "#   from input decoding to emitted expectation twice, in two pipelines that",
        "#   share no arithmetic, and refuses to emit unless both agree. It imports",
        "#   nothing from src/, model/ or js/.",
        "#",
        "#   Regenerate:      python scripts/gen_format_vectors.py",
        "#   Verify committed: python scripts/gen_format_vectors.py --check",
        "#   The generic-domain gate runs the second on every invocation.",
        "#",
        "#   Regenerating is a deliberate act: it re-baselines the arithmetic. Do it",
        "#   only when a behaviour change is intended, and say so in the changelog.",
        "#",
        "# COVERAGE",
        "#   Every input value of each geometry, crossed with 2 source signednesses",
        "#   (C_LM_UNSIGNED = 1, C_LM_SIGNED = 2), 2 destination signednesses, 9",
        "#   rounding modes (C_LM_TRUNC_BITS = 0 .. C_LM_ROUND_AWAY = 8) and 2 overflow",
        "#   modes (C_LM_SATURATE = 1, C_LM_WRAP = 2). The four alias constants share a",
        "#   value with one of the nine rounding modes, so they are covered by the",
        "#   value they alias.",
        "#",
        "#   The testbench does not take this on trust. It requires each geometry to",
        "#   carry every one of its 2**old_width distinct input values, and requires",
        "#   the declared geometries to cover a set of families it names itself. A",
        "#   reduced vector set that is internally consistent still fails.",
        "#",
    ]
    for (label, ow, obp, nw, nbp), (_a, _b, _c, _d, count) in zip(VECTOR_GEOMETRIES, tally):
        fams = ",".join(families(ow, obp, nw, nbp))
        head.append(f"#     ({ow},{obp}) -> ({nw},{nbp})  {count:5d} rows  {label}")
        head.append(f"#         families: {fams}")
    head += [
        "#",
        "# FORMAT",
        "#   Lines beginning with '#!' are manifest directives:",
        "#     #! 0 <total>                                expected number of vectors",
        "#     #! 1 <old_w> <old_bp> <new_w> <new_bp> <n>  expected rows per geometry",
        "#   Other lines beginning with '#' are prose. Every remaining line is one",
        "#   vector:",
        "#     old_width old_binpnt old_arith new_width new_binpnt new_arith",
        "#     rounding overflow value expected",
        "#   where `value` and `expected` are unsigned integer renderings of the source",
        "#   and destination bit patterns.",
        "#",
    ]
    head.append(f"#! 0 {len(rows)}")
    for ow, obp, nw, nbp, count in tally:
        head.append(f"#! 1 {ow} {obp} {nw} {nbp} {count}")
    body = [" ".join(str(x) for x in row) for row in rows]
    return "\n".join(head + body) + "\n"


# ===========================================================================
# The entity testbench
# ===========================================================================

W4 = [0, 1, 5, 7, 8, 15]
W1 = [0, 1]


def _fmt(tag, note, ow, obp, nw, nbp, arith, rnd, ovf, values):
    return dict(kind="format", tag=tag, note=note, ow=ow, obp=obp, nw=nw, nbp=nbp,
                arith=arith, rnd=rnd, ovf=ovf, values=[(v,) for v in values])


def _mul(tag, note, aw, abp, bw, bbp, nw, nbp, arith, rnd, ovf, values):
    return dict(kind="mult", tag=tag, note=note, aw=aw, abp=abp, bw=bw, bbp=bbp,
                nw=nw, nbp=nbp, arith=arith, rnd=rnd, ovf=ovf, values=values)


def _as(tag, note, aw, abp, bw, bbp, nw, nbp, arith, rnd, direction, values):
    return dict(kind="add_sub", tag=tag, note=note, aw=aw, abp=abp, bw=bw, bbp=bbp,
                nw=nw, nbp=nbp, arith=arith, rnd=rnd, direction=direction, values=values)


def _ma(tag, note, aw, abp, bw, bbp, cw, cbp, nw, nbp, arith, rnd, ovf, direction, values):
    return dict(kind="mult_add", tag=tag, note=note, aw=aw, abp=abp, bw=bw, bbp=bbp,
                cw=cw, cbp=cbp, nw=nw, nbp=nbp, arith=arith, rnd=rnd, ovf=ovf,
                direction=direction, values=values)


def _pairs(xs, ys):
    return [(a, b) for a in xs for b in ys]


def _triples(xs, ys, zs):
    return [(a, b, c) for a in xs for b in ys for c in zs]


ENTITY_CASES = [
    # --- lm_math_fi_format ---------------------------------------------------
    _fmt("f_ordinary_u", "ordinary narrowing", 6, 2, 4, 1, UNSIGNED, ROUND_EVEN, SATURATE, [0, 1, 22, 37, 63]),
    _fmt("f_ordinary_s", "ordinary narrowing", 6, 2, 4, 1, SIGNED, ROUND_EVEN, SATURATE, [0, 1, 22, 37, 63]),
    _fmt("f_bpeq_u", "binary point equal to the width", 4, 4, 4, 4, UNSIGNED, ROUND_EVEN, SATURATE, W4),
    _fmt("f_bpeq_s", "binary point equal to the width", 4, 4, 4, 4, SIGNED, ROUND_EVEN, SATURATE, W4),
    _fmt("f_bpgt_src_u", "binary point above the width, source", 4, 8, 4, 2, UNSIGNED, TRUNC_BITS, WRAP, W4),
    _fmt("f_bpgt_src_s", "binary point above the width, source", 4, 8, 4, 2, SIGNED, TRUNC_BITS, WRAP, W4),
    _fmt("f_bpgt_dst_u", "binary point above the width, destination", 4, 2, 4, 8, UNSIGNED, ROUND_AWAY, SATURATE, W4),
    _fmt("f_bpgt_dst_s", "binary point above the width, destination", 4, 2, 4, 8, SIGNED, ROUND_AWAY, SATURATE, W4),
    _fmt("f_bpgt_both_s", "binary point above the width, both sides", 4, 8, 4, 6, SIGNED, ROUND_EVEN, SATURATE, W4),
    _fmt("f_disj_above_s", "disjoint weights, destination above source", 4, 8, 4, 0, SIGNED, ROUND_AWAY, SATURATE, W4),
    _fmt("f_disj_below_u", "disjoint weights, destination below source", 4, 0, 4, 8, UNSIGNED, TRUNC_BITS, SATURATE, W4),
    _fmt("f_overlap1_u", "exactly one bit of weight overlap", 4, 4, 4, 1, UNSIGNED, ROUND_EVEN, WRAP, W4),
    _fmt("f_w1_u", "width 1 unsigned, binary point equal to the width", 1, 1, 1, 1, UNSIGNED, ROUND_EVEN, SATURATE, W1),
    _fmt("f_w1_s", "width 1 signed, binary point equal to the width", 1, 1, 1, 1, SIGNED, ROUND_EVEN, SATURATE, W1),
    _fmt("f_w1_from_wide_s", "width 1 signed destination from a wider source", 4, 3, 1, 1, SIGNED, ROUND_EVEN, SATURATE, W4),
    _fmt("f_w1_to_wide_s", "width 1 signed source into a wider destination", 1, 3, 4, 1, SIGNED, ROUND_EVEN, SATURATE, W1),
    # --- lm_math_fi_mult -----------------------------------------------------
    _mul("m_ordinary_s", "ordinary narrowing", 4, 1, 4, 1, 6, 2, SIGNED, ROUND_EVEN, SATURATE,
         _pairs((0, 1, 7, 8, 15), (1, 15))),
    _mul("m_bpeq_u", "binary point equal to the width", 4, 4, 4, 4, 4, 4, UNSIGNED, ROUND_EVEN, SATURATE,
         _pairs((0, 3, 15), (0, 5, 15))),
    _mul("m_bpeq_s", "binary point equal to the width", 4, 4, 4, 4, 4, 4, SIGNED, ROUND_EVEN, SATURATE,
         _pairs((0, 3, 15), (0, 5, 15))),
    _mul("m_bpgt_s", "binary point above the width", 4, 6, 4, 6, 4, 8, SIGNED, TRUNC_BITS, WRAP,
         _pairs((0, 1, 7, 8), (1, 15))),
    _mul("m_bpgt_dst_u", "binary point above the width, destination", 4, 1, 4, 1, 4, 9, UNSIGNED, ROUND_EVEN, SATURATE,
         _pairs((0, 1, 15), (1, 15))),
    _mul("m_disj_below_u", "disjoint weights, destination below source", 4, 0, 4, 0, 4, 12, UNSIGNED, TRUNC_BITS, SATURATE,
         _pairs((0, 1, 15), (1, 15))),
    _mul("m_disj_above_s", "disjoint weights, destination above source", 4, 8, 4, 8, 4, 0, SIGNED, ROUND_AWAY, SATURATE,
         _pairs((0, 1, 8, 15), (1, 15))),
    _mul("m_overlap1_u", "exactly one bit of weight overlap", 4, 4, 4, 4, 4, 1, UNSIGNED, ROUND_EVEN, WRAP,
         _pairs((0, 3, 15), (5, 15))),
    _mul("m_w1_u", "width 1 unsigned", 1, 1, 1, 1, 1, 1, UNSIGNED, ROUND_EVEN, SATURATE, _pairs(W1, W1)),
    _mul("m_w1_s", "width 1 signed", 1, 1, 1, 1, 1, 1, SIGNED, ROUND_EVEN, SATURATE, _pairs(W1, W1)),
    # --- lm_math_fi_add_sub --------------------------------------------------
    _as("a_ordinary_s", "ordinary narrowing", 4, 1, 4, 1, 6, 2, SIGNED, ROUND_EVEN, ADD,
        _pairs((0, 1, 8, 15), (1, 7, 15))),
    _as("a_bpeq_u", "binary point equal to the width", 4, 4, 4, 4, 4, 4, UNSIGNED, ROUND_EVEN, ADD,
        _pairs((0, 1, 15), (0, 7, 15))),
    _as("a_bpeq_s", "binary point equal to the width", 4, 4, 4, 4, 4, 4, SIGNED, ROUND_EVEN, ADD,
        _pairs((0, 1, 15), (0, 7, 15))),
    _as("a_bpgt_s", "binary point above the width", 4, 8, 4, 6, 4, 9, SIGNED, ROUND_EVEN, SUB,
        _pairs((0, 1, 8, 15), (1, 15))),
    _as("a_bpgt_src_u", "binary point above the width, source", 4, 6, 4, 6, 4, 2, UNSIGNED, TRUNC_BITS, ADD,
        _pairs((0, 1, 15), (1, 15))),
    _as("a_disj_below_u", "disjoint weights, destination below source", 4, 0, 4, 0, 4, 10, UNSIGNED, TRUNC_BITS, ADD,
        _pairs((0, 1, 15), (1, 15))),
    _as("a_disj_above_s", "disjoint weights, destination above source", 4, 8, 4, 8, 4, 0, SIGNED, ROUND_AWAY, ADD,
        _pairs((0, 1, 8, 15), (1, 15))),
    _as("a_overlap1_u", "exactly one bit of weight overlap", 4, 4, 4, 4, 4, 1, UNSIGNED, ROUND_EVEN, ADD,
        _pairs((0, 3, 15), (5, 15))),
    _as("a_w1_u", "width 1 unsigned", 1, 1, 1, 1, 1, 1, UNSIGNED, ROUND_EVEN, ADD, _pairs(W1, W1)),
    _as("a_w1_s", "width 1 signed", 1, 1, 1, 1, 1, 1, SIGNED, ROUND_EVEN, ADD, _pairs(W1, W1)),
    # --- lm_math_fi_mult_add -------------------------------------------------
    _ma("ma_bpeq_u", "binary point equal to the width everywhere",
        4, 4, 4, 4, 8, 8, 8, 8, UNSIGNED, ROUND_EVEN, SATURATE, ADD,
        _triples((0, 3, 15), (0, 15), (0, 129, 255))),
    _ma("ma_bpeq_s", "binary point equal to the width everywhere",
        4, 4, 4, 4, 8, 8, 8, 8, SIGNED, ROUND_EVEN, SATURATE, ADD,
        _triples((0, 3, 15), (0, 15), (0, 129, 255))),
    _ma("ma_bpgt_ops_s", "binary point above the width on the operands",
        4, 6, 4, 6, 8, 2, 8, 4, SIGNED, ROUND_EVEN, SATURATE, ADD,
        _triples((0, 1, 8, 15), (1, 15), (0, 200))),
    _ma("ma_bpgt_addend_s", "binary point above the width on the addend, subtract",
        4, 1, 4, 1, 8, 12, 8, 4, SIGNED, ROUND_EVEN, SATURATE, SUB,
        _triples((0, 1, 8), (1, 15), (0, 129, 255))),
    _ma("ma_bpgt_all_u", "binary point above the width everywhere",
        4, 6, 4, 6, 8, 12, 8, 14, UNSIGNED, ROUND_AWAY, WRAP, ADD,
        _triples((0, 1, 15), (1, 15), (0, 255))),
    _ma("ma_bpgt_out_s", "binary point above the width on the output only",
        4, 1, 4, 1, 8, 1, 4, 9, SIGNED, ROUND_EVEN, SATURATE, ADD,
        _triples((0, 1, 8), (1, 15), (0, 200))),
    _ma("ma_disj_below_u", "disjoint weights, destination below source",
        4, 0, 4, 0, 8, 0, 4, 14, UNSIGNED, TRUNC_BITS, SATURATE, ADD,
        _triples((0, 1, 15), (1, 15), (0, 255))),
    _ma("ma_disj_above_s", "disjoint weights, destination above source",
        4, 8, 4, 8, 8, 10, 4, 0, SIGNED, ROUND_AWAY, SATURATE, ADD,
        _triples((0, 1, 8), (1, 15), (0, 255))),
    _ma("ma_overlap1_u", "exactly one bit of weight overlap",
        4, 4, 4, 4, 8, 8, 4, 5, UNSIGNED, ROUND_EVEN, WRAP, ADD,
        _triples((0, 3, 15), (5, 15), (0, 255))),
    _ma("ma_w1_u", "width 1 unsigned everywhere",
        1, 1, 1, 1, 1, 1, 1, 1, UNSIGNED, ROUND_EVEN, SATURATE, ADD, _triples(W1, W1, W1)),
    _ma("ma_w1_s", "width 1 signed everywhere",
        1, 1, 1, 1, 1, 1, 1, 1, SIGNED, ROUND_EVEN, SATURATE, ADD, _triples(W1, W1, W1)),
]

ENTITY_OF = {"format": "lm_math_fi_format", "mult": "lm_math_fi_mult",
             "add_sub": "lm_math_fi_add_sub", "mult_add": "lm_math_fi_mult_add"}


def case_geometry(case):
    """The (source, destination) geometry a case exercises, for classification.
    For the arithmetic modules the source is the widest operand format."""
    if case["kind"] == "format":
        return case["ow"], case["obp"], case["nw"], case["nbp"]
    return case["aw"], case["abp"], case["nw"], case["nbp"]


def entity_expectation(case, vals) -> str:
    kind = case["kind"]
    if kind == "format":
        return quantize(bits_of(vals[0], case["ow"]), case["ow"], case["obp"],
                        case["arith"], case["nw"], case["nbp"], case["arith"],
                        case["rnd"], case["ovf"])
    if kind == "mult":
        return mult(bits_of(vals[0], case["aw"]), bits_of(vals[1], case["bw"]),
                    case["aw"], case["abp"], case["arith"],
                    case["bw"], case["bbp"], case["arith"],
                    case["nw"], case["nbp"], case["arith"], case["rnd"], case["ovf"])
    if kind == "add_sub":
        return add_sub(bits_of(vals[0], case["aw"]), bits_of(vals[1], case["bw"]),
                       case["aw"], case["abp"], case["bw"], case["bbp"],
                       case["arith"], case["nw"], case["nbp"], case["arith"],
                       case["rnd"], case["direction"])
    return mult_add(bits_of(vals[0], case["aw"]), bits_of(vals[1], case["bw"]),
                    bits_of(vals[2], case["cw"]),
                    case["aw"], case["abp"], case["bw"], case["bbp"],
                    case["cw"], case["cbp"], case["arith"], case["nw"], case["nbp"],
                    case["arith"], case["rnd"], case["ovf"], case["direction"])


def _geometry_text(case) -> str:
    dst = f'({case["nw"]},{case["nbp"]})'
    if case["kind"] == "format":
        return f'({case["ow"]},{case["obp"]}) -> {dst}'
    if case["kind"] == "mult":
        return f'({case["aw"]},{case["abp"]})x({case["bw"]},{case["bbp"]}) -> {dst}'
    sign = "+" if case["direction"] == ADD else "-"
    if case["kind"] == "add_sub":
        return f'({case["aw"]},{case["abp"]}){sign}({case["bw"]},{case["bbp"]}) -> {dst}'
    return (f'({case["aw"]},{case["abp"]})x({case["bw"]},{case["bbp"]})'
            f'{sign}({case["cw"]},{case["cbp"]}) -> {dst}')


def coverage_matrix():
    """Per-entity family coverage, derived from the committed cases."""
    matrix = {e: set() for e in ENTITY_OF.values()}
    for case in ENTITY_CASES:
        ow, obp, nw, nbp = case_geometry(case)
        matrix[ENTITY_OF[case["kind"]]].update(families(ow, obp, nw, nbp))
    signedness = {e: set() for e in ENTITY_OF.values()}
    for case in ENTITY_CASES:
        ow, obp, nw, nbp = case_geometry(case)
        if "width_1" in families(ow, obp, nw, nbp):
            signedness[ENTITY_OF[case["kind"]]].add(ARITH_TAG[case["arith"]])
    return matrix, signedness


def render_entity_tb() -> str:
    decls, insts, steps = [], [], []
    n_checks = 0

    for case in ENTITY_CASES:
        tag, kind = case["tag"], case["kind"]
        if kind == "format":
            decls += [
                f'  signal s_{tag}_din  : std_logic_vector({case["ow"] - 1} downto 0) := (others => \'0\');',
                f'  signal s_{tag}_dout : std_logic_vector({case["nw"] - 1} downto 0);',
            ]
            insts.append(f"""  inst_{tag} : entity lm_math_fi_lib.lm_math_fi_format
    generic map(g_din_w => {case['ow']}, g_din_binpnt => {case['obp']},
                g_dout_w => {case['nw']}, g_dout_binpnt => {case['nbp']},
                g_pipe_stages => 0, g_round_mode => {ROUND_NAME[case['rnd']]},
                g_overflow => {OVF_NAME[case['ovf']]},
                g_representation => {ARITH_NAME[case['arith']]})
    port map(clk_i => clk_tb, ce_i => '1', din_i => s_{tag}_din, dout_o => s_{tag}_dout);
""")
        elif kind in ("mult", "add_sub"):
            decls += [
                f'  signal s_{tag}_a    : std_logic_vector({case["aw"] - 1} downto 0) := (others => \'0\');',
                f'  signal s_{tag}_b    : std_logic_vector({case["bw"] - 1} downto 0) := (others => \'0\');',
                f'  signal s_{tag}_dout : std_logic_vector({case["nw"] - 1} downto 0);',
            ]
            if kind == "mult":
                insts.append(f"""  inst_{tag} : entity lm_math_fi_lib.lm_math_fi_mult
    generic map(g_din_a_w => {case['aw']}, g_din_a_binpnt => {case['abp']},
                g_din_b_w => {case['bw']}, g_din_b_binpnt => {case['bbp']},
                g_dout_w => {case['nw']}, g_dout_binpnt => {case['nbp']},
                g_round_mode => {ROUND_NAME[case['rnd']]},
                g_din_a_type => {ARITH_NAME[case['arith']]},
                g_din_b_type => {ARITH_NAME[case['arith']]},
                g_dout_type => {ARITH_NAME[case['arith']]},
                g_overflow => {OVF_NAME[case['ovf']]}, g_pipe_stages => 0)
    port map(clk_i => clk_tb, ce_i => '1', din1_i => s_{tag}_a, din2_i => s_{tag}_b,
             dout_o => s_{tag}_dout);
""")
            else:
                insts.append(f"""  inst_{tag} : entity lm_math_fi_lib.lm_math_fi_add_sub
    generic map(g_direction => {DIR_NAME[case['direction']]},
                g_representation => {ARITH_NAME[case['arith']]},
                g_pipeline_input => 0, g_pipeline_output => 0,
                g_din1_w => {case['aw']}, g_din1_binpnt => {case['abp']},
                g_din2_w => {case['bw']}, g_din2_binpnt => {case['bbp']},
                g_dout_w => {case['nw']}, g_dout_binpnt => {case['nbp']},
                g_round_mode => {ROUND_NAME[case['rnd']]})
    port map(clk_i => clk_tb, ce_i => '1', sel_add_i => '1',
             din1_i => s_{tag}_a, din2_i => s_{tag}_b, dout_o => s_{tag}_dout);
""")
        else:
            decls += [
                f'  signal s_{tag}_a    : std_logic_vector({case["aw"] - 1} downto 0) := (others => \'0\');',
                f'  signal s_{tag}_b    : std_logic_vector({case["bw"] - 1} downto 0) := (others => \'0\');',
                f'  signal s_{tag}_c    : std_logic_vector({case["cw"] - 1} downto 0) := (others => \'0\');',
                f'  signal s_{tag}_dout : std_logic_vector({case["nw"] - 1} downto 0);',
            ]
            insts.append(f"""  inst_{tag} : entity lm_math_fi_lib.lm_math_fi_mult_add
    generic map(g_din_a_w => {case['aw']}, g_din_a_binpnt => {case['abp']},
                g_din_b_w => {case['bw']}, g_din_b_binpnt => {case['bbp']},
                g_din_c_w => {case['cw']}, g_din_c_binpnt => {case['cbp']},
                g_dout_w => {case['nw']}, g_dout_binpnt => {case['nbp']},
                g_add_sub => {DIR_NAME[case['direction']]},
                g_round_mode => {ROUND_NAME[case['rnd']]},
                g_representation => {ARITH_NAME[case['arith']]},
                g_overflow => {OVF_NAME[case['ovf']]}, g_pipe_stages => 0)
    port map(clk_i => clk_tb, ce_i => '1', din1_i => s_{tag}_a, din2_i => s_{tag}_b,
             din3_i => s_{tag}_c, dout_o => s_{tag}_dout);
""")

    for case in ENTITY_CASES:
        tag = case["tag"]
        geometry = _geometry_text(case)
        steps.append(f'    -- {case["note"]}: {ARITH_TAG[case["arith"]]}{geometry}')
        for vals in case["values"]:
            expected = entity_expectation(case, vals)
            if case["kind"] == "format":
                steps.append(f'    s_{tag}_din <= "{bits_of(vals[0], case["ow"])}";')
            elif case["kind"] in ("mult", "add_sub"):
                steps.append(f'    s_{tag}_a <= "{bits_of(vals[0], case["aw"])}";'
                             f' s_{tag}_b <= "{bits_of(vals[1], case["bw"])}";')
            else:
                steps.append(f'    s_{tag}_a <= "{bits_of(vals[0], case["aw"])}";'
                             f' s_{tag}_b <= "{bits_of(vals[1], case["bw"])}";'
                             f' s_{tag}_c <= "{bits_of(vals[2], case["cw"])}";')
            steps.append("    p_settle(clk_tb);")
            label = (f'{case["note"]} {ARITH_TAG[case["arith"]]}{geometry} '
                     f'in={"/".join(str(v) for v in vals)}')
            steps.append(f'    p_check_slv(s_{tag}_dout, "{expected}", "{label}");')
            n_checks += 1
        steps.append("")

    matrix, w1_sign = coverage_matrix()
    cov_lines = ["-- COVERAGE, derived from the cases below:"]
    for entity in ENTITY_OF.values():
        present = [f for f in REQUIRED_FAMILIES if f in matrix[entity]]
        missing = [f for f in REQUIRED_FAMILIES if f not in matrix[entity]]
        cov_lines.append(f"--   {entity}")
        cov_lines.append(f"--     families: {', '.join(present) if present else 'none'}")
        if missing:
            cov_lines.append(f"--     NOT covered here: {', '.join(missing)}")
        cov_lines.append(f"--     width-1 signedness: "
                         f"{', '.join(sorted(w1_sign[entity])) if w1_sign[entity] else 'none'}")

    newline = "\n"
    return f"""-- SPDX-License-Identifier: Apache-2.0
-- Copyright 2026 LogiMentor
--
-- GENERATED FILE - do not edit by hand.
-- Produced by scripts/gen_format_vectors.py; the generic-domain gate runs that
-- script with --check on every invocation, so an edit here fails the gate.
--
-- Value checks for every quantizing entity at degenerate binary points.
--
-- A binary point equal to or greater than its width is a legal fixed-point
-- format: every bit is fractional and the point sits outside the word. Nothing
-- constrains a binary point against a width, so every module must produce the
-- right answer for one, not merely elaborate. tb_legal_sweep covers elaboration;
-- this testbench covers the results.
--
{newline.join(cov_lines)}
--
-- HOW THE EXPECTED VALUES WERE PRODUCED
--   By scripts/gen_format_vectors.py, which computes the arithmetic from the
--   documented semantics using arbitrary-precision integers and fractions. It
--   implements the whole path from input decoding to emitted expectation twice,
--   in two pipelines that share no arithmetic, and refuses to emit unless both
--   agree. It imports nothing from src/, model/ or js/.
--
--   For the three arithmetic modules the reference also models each module's own
--   internal intermediate format, because that is part of the library's defined
--   behaviour: operands are aligned into the internal format and the accumulator
--   wraps there. That is what makes an unsigned subtraction that goes negative
--   wrap rather than clamp, which sim/tb/tb_lm_math_fi_add_sub.vhd already
--   relies on. Both references necessarily model that structure the same way;
--   the doubling catches an arithmetic slip, not a shared misreading.

library ieee;
use ieee.std_logic_1164.all;

library lm_math_fi_lib;
use lm_math_fi_lib.lm_math_fi_pkg.all;
use lm_math_fi_lib.tb_lm_math_fi_test_pkg.all;

entity tb_degenerate_formats is
end entity tb_degenerate_formats;

architecture a_tb of tb_degenerate_formats is
  signal s_done  : boolean := false;
  signal clk_tb  : std_logic := '0';

{newline.join(decls)}

  -- Settle long enough for the modules with a registered stage (mult and
  -- mult_add are one clock; format and add_sub are combinational here).
  procedure p_settle(signal clk : in std_logic) is
  begin
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    wait for 1 ns;
  end procedure;

begin

  proc_clk : process
  begin
    while not s_done loop
      clk_tb <= '0';
      wait for C_TB_CLK_PERIOD / 2;
      clk_tb <= '1';
      wait for C_TB_CLK_PERIOD / 2;
    end loop;
    clk_tb <= '0';
    wait;
  end process proc_clk;

{newline.join(insts)}
  proc_main : process
  begin
{newline.join(steps)}
    report "TEST PASSED: tb_degenerate_formats ({n_checks} checks)" severity note;
    s_done <= true;
    wait;
  end process proc_main;

end architecture a_tb;
"""


def print_coverage(rows, tally) -> None:
    matrix, w1_sign = coverage_matrix()
    print("Entity value-check coverage, derived from ENTITY_CASES:")
    print(f"  {'entity':22s} {'families covered':60s} width-1 signedness")
    for entity in ENTITY_OF.values():
        present = [f for f in REQUIRED_FAMILIES if f in matrix[entity]]
        signs = ", ".join(sorted(w1_sign[entity])) or "none"
        print(f"  {entity:22s} {', '.join(present):60s} {signs}")
        missing = [f for f in REQUIRED_FAMILIES if f not in matrix[entity]]
        if missing:
            print(f"  {'':22s} NOT covered: {', '.join(missing)}")
    print()
    print(f"Entity value checks: {sum(len(c['values']) for c in ENTITY_CASES)}")
    print(f"Vector rows: {len(rows)} over {len(tally)} geometries")
    print("Vector geometry families:")
    for _label, ow, obp, nw, nbp in VECTOR_GEOMETRIES:
        print(f"  ({ow},{obp}) -> ({nw},{nbp})  {', '.join(families(ow, obp, nw, nbp))}")
    covered = set()
    for _label, ow, obp, nw, nbp in VECTOR_GEOMETRIES:
        covered.update(families(ow, obp, nw, nbp))
    missing = [f for f in REQUIRED_FAMILIES if f not in covered]
    print(f"Vector families missing: {', '.join(missing) if missing else 'none'}")
    print(f"Binary points used by committed vectors: "
          f"{sorted({g[2] for g in VECTOR_GEOMETRIES} | {g[4] for g in VECTOR_GEOMETRIES})}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true",
                        help="Regenerate in memory and fail if either committed file differs.")
    parser.add_argument("--coverage", action="store_true",
                        help="Print the derived coverage matrix and exit.")
    args = parser.parse_args()

    rows, tally = build_vectors()
    vector_text = render_vector_file(rows, tally)
    entity_text = render_entity_tb()

    if _DISAGREEMENTS:
        print("error: the two independent references disagree; nothing was written:",
              file=sys.stderr)
        for line in _DISAGREEMENTS[:10]:
            print(f"  {line}", file=sys.stderr)
        return 2

    if args.coverage:
        print_coverage(rows, tally)
        return 0

    targets = [(VECTOR_FILE, vector_text), (ENTITY_TB_FILE, entity_text)]

    if args.check:
        failed = False
        for path, text in targets:
            rel = path.relative_to(ROOT).as_posix()
            if not path.is_file():
                print(f"error: {rel} is missing; run scripts/gen_format_vectors.py",
                      file=sys.stderr)
                failed = True
                continue
            if path.read_bytes() != text.encode("utf-8"):
                print(f"error: {rel} does not match the generator; regenerate it with "
                      "'python scripts/gen_format_vectors.py'", file=sys.stderr)
                failed = True
        if failed:
            return 1
        print(f"format expectations up to date: {len(rows)} vectors over "
              f"{len(VECTOR_GEOMETRIES)} geometries and "
              f"{sum(len(c['values']) for c in ENTITY_CASES)} entity checks, "
              f"{_AGREED} expectations each computed twice with no disagreement")
        return 0

    for path, text in targets:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(text.encode("utf-8"))
        print(f"wrote {path.relative_to(ROOT).as_posix()}")
    print(f"{len(rows)} vectors over {len(VECTOR_GEOMETRIES)} geometries and "
          f"{sum(len(c['values']) for c in ENTITY_CASES)} entity checks; "
          f"{_AGREED} expectations each computed twice with no disagreement")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
