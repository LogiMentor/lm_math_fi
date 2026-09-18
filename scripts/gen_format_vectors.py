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
  arithmetic is written from the documented semantics using Python's
  arbitrary-precision integers and fractions: a stored word R with binary point
  B denotes the exact rational R / 2**B, with R read as two's complement when
  the format is signed. An expectation that came from the code under test would
  certify nothing, so this file must never grow a dependency on it. The only
  thing it reads from the repository is its own previous output, and only to
  compare.

  The arithmetic is implemented TWICE, in two deliberately different styles:

    reference A  exact integers, floor division and remainder
    reference B  exact rationals, comparison against the midpoint

  Every value is computed both ways and the two must agree before anything is
  written. A single implementation could be self-consistently wrong; two written
  from the same prose in different styles are much less likely to be wrong the
  same way.

USAGE
  python scripts/gen_format_vectors.py           regenerate both files
  python scripts/gen_format_vectors.py --check   regenerate in memory and fail
                                                 if either committed file differs

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

# The library's encodings, restated here rather than imported.
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


# ---------------------------------------------------------------------------
# Shared, non-arithmetic helpers
# ---------------------------------------------------------------------------

def raw_of(bits: str, arith: int) -> int:
    """Read a bit string as the stored integer of a format."""
    value = int(bits, 2)
    if arith == SIGNED and bits[0] == "1":
        return value - (1 << len(bits))
    return value


def bits_of(raw: int, width: int) -> str:
    """Render a stored integer as a two's-complement bit string."""
    return format(raw & ((1 << width) - 1), f"0{width}b")


def bounds(width: int, arith: int) -> tuple[int, int]:
    if arith == SIGNED:
        return -(1 << (width - 1)), (1 << (width - 1)) - 1
    return 0, (1 << width) - 1


def store(value: int, width: int, arith: int, ovf: int) -> int:
    """Place an integer into a format under the selected overflow mode."""
    low, high = bounds(width, arith)
    if ovf == SATURATE:
        return max(low, min(high, value))
    value &= (1 << width) - 1
    if arith == SIGNED and value >= (1 << (width - 1)):
        value -= 1 << width
    return value


# ---------------------------------------------------------------------------
# Reference A: exact integers, floor division and remainder
# ---------------------------------------------------------------------------

def _round_a(num: int, den: int, mode: int) -> int:
    quotient, remainder = divmod(num, den)      # floor division, 0 <= remainder < den
    if remainder == 0:
        return quotient
    if mode in (TRUNC_BITS, FLOOR):
        return quotient
    if mode == CEIL:
        return quotient + 1
    if mode == TRUNC_ZERO:
        return quotient + 1 if num < 0 else quotient
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
        return quotient + 1 if num < 0 else quotient
    if mode == ROUND_AWAY:
        return quotient if num < 0 else quotient + 1
    raise ValueError(f"unknown rounding mode {mode}")


def _rescale_a(raw: int, src_bp: int, dst_bp: int, mode: int) -> int:
    delta = dst_bp - src_bp
    if delta >= 0:
        return raw << delta                     # nothing is discarded
    return _round_a(raw, 1 << (-delta), mode)


# ---------------------------------------------------------------------------
# Reference B: exact rationals, comparison against the midpoint
# ---------------------------------------------------------------------------

def _round_b(exact: Fraction, mode: int) -> int:
    below = exact.numerator // exact.denominator      # floor, for any sign
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


def _rescale_b(raw: int, src_bp: int, dst_bp: int, mode: int) -> int:
    value = Fraction(raw) / (Fraction(2) ** src_bp)   # the exact represented value
    scaled = value * (Fraction(2) ** dst_bp)          # the destination's integer scale
    return _round_b(scaled, mode)


# ---------------------------------------------------------------------------
# Agreement gate: every value is computed both ways
# ---------------------------------------------------------------------------

_DISAGREEMENTS: list[str] = []


def rescale(raw: int, src_bp: int, dst_bp: int, mode: int) -> int:
    a = _rescale_a(raw, src_bp, dst_bp, mode)
    b = _rescale_b(raw, src_bp, dst_bp, mode)
    if a != b:
        _DISAGREEMENTS.append(
            f"raw={raw} {src_bp}->{dst_bp} mode={ROUND_NAME[mode]}: A={a} B={b}"
        )
    return a


# ---------------------------------------------------------------------------
# The operations, expressed on top of rescale/store
# ---------------------------------------------------------------------------

def quantize(inbits, ow, obp, oa, nw, nbp, na, rnd, ovf) -> str:
    """Conversion. The reference for f_lm_quantize and lm_math_fi_format."""
    return bits_of(store(rescale(raw_of(inbits, oa), obp, nbp, rnd), nw, na, ovf), nw)


def mult(abits, bbits, aw, abp, aa, bw, bbp, ba, nw, nbp, na, rnd, ovf) -> str:
    """lm_math_fi_mult. The product is held exactly in (aw+bw, abp+bbp); it is
    unsigned only when both operands are unsigned."""
    product = raw_of(abits, aa) * raw_of(bbits, ba)
    product_arith = UNSIGNED if (aa == UNSIGNED and ba == UNSIGNED) else SIGNED
    held = store(product, aw + bw, product_arith, WRAP)
    return bits_of(store(rescale(held, abp + bbp, nbp, rnd), nw, na, ovf), nw)


def add_sub(abits, bbits, aw, abp, bw, bbp, arith, nw, nbp, na, rnd, direction) -> str:
    """lm_math_fi_add_sub. Both operands are aligned into the module's internal
    format and wrap there, the sum is formed and wraps, then it is quantized.
    The module has no overflow generic and always wraps."""
    res_bp = max(abp, bbp)
    res_w = max(aw - abp, bw - bbp) + res_bp + 1
    a = store(raw_of(abits, arith) << (res_bp - abp), res_w, arith, WRAP)
    b = store(raw_of(bbits, arith) << (res_bp - bbp), res_w, arith, WRAP)
    acc = store(a + b if direction == ADD else a - b, res_w, arith, WRAP)
    return bits_of(store(rescale(acc, res_bp, nbp, rnd), nw, na, WRAP), nw)


def mult_add(abits, bbits, cbits, aw, abp, bw, bbp, cw, cbp, arith,
             nw, nbp, na, rnd, ovf, direction) -> str:
    """lm_math_fi_mult_add. The product and the addend are aligned into the
    module's internal format and wrap there, the sum is formed and wraps, then
    it is quantized."""
    mult_bp = abp + bbp
    sum_bp = max(mult_bp, cbp)
    sum_w = max((aw + bw) - mult_bp, cw - cbp) + sum_bp + 1
    product = store((raw_of(abits, arith) * raw_of(bbits, arith)) << (sum_bp - mult_bp),
                    sum_w, arith, WRAP)
    addend = store(raw_of(cbits, arith) << (sum_bp - cbp), sum_w, arith, WRAP)
    acc = store(product + addend if direction == ADD else product - addend,
                sum_w, arith, WRAP)
    return bits_of(store(rescale(acc, sum_bp, nbp, rnd), nw, na, ovf), nw)


# ---------------------------------------------------------------------------
# The vector file
# ---------------------------------------------------------------------------

# (label, old_width, old_binpnt, new_width, new_binpnt)
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
    """Return (rows, per_geometry_counts) for the vector file."""
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
        "# PURPOSE",
        "#   Pins the arithmetic of f_lm_quantize across the format domain, so that a",
        "#   future edit to the function cannot change the result for a legal",
        "#   configuration without failing the gate.",
        "#",
        "# HOW THESE WERE PRODUCED",
        "#   Every value in this file, without exception, is emitted by",
        "#   scripts/gen_format_vectors.py. That script computes the arithmetic from",
        "#   the documented semantics using Python's arbitrary-precision integers and",
        "#   fractions, twice, in two different styles, and refuses to emit anything",
        "#   unless the two agree. It imports nothing from src/, model/ or js/: an",
        "#   expectation taken from the code under test would certify nothing.",
        "#",
        "#   Do not edit this file by hand. Regenerate it:",
        "#     python scripts/gen_format_vectors.py",
        "#   and verify the committed copy matches the generator:",
        "#     python scripts/gen_format_vectors.py --check",
        "#   which the generic-domain gate runs on every invocation.",
        "#",
        "#   Regenerating is a deliberate act: it re-baselines the arithmetic. Do it",
        "#   only when a behaviour change is intended, and say so in the changelog.",
        "#",
        "# COVERAGE",
        "#   Every input value of each geometry below, crossed with 2 source",
        "#   signednesses (C_LM_UNSIGNED = 1, C_LM_SIGNED = 2), 2 destination",
        "#   signednesses, 9 rounding modes (C_LM_TRUNC_BITS = 0 .. C_LM_ROUND_AWAY = 8)",
        "#   and 2 overflow modes (C_LM_SATURATE = 1, C_LM_WRAP = 2). The four alias",
        "#   constants share a value with one of the nine rounding modes, so they are",
        "#   covered by the value they alias.",
        "#",
    ]
    for (label, ow, obp, nw, nbp), (_a, _b, _c, _d, count) in zip(VECTOR_GEOMETRIES, tally):
        head.append(f"#     ({ow},{obp}) -> ({nw},{nbp})   {count:5d}   {label}")
    head += [
        "#",
        "# FORMAT",
        "#   Lines beginning with '#!' are manifest directives, read by the testbench",
        "#   so that truncating or thinning this file fails the gate instead of",
        "#   quietly shrinking its coverage:",
        "#     #! 0 <total>                              expected number of vectors",
        "#     #! 1 <old_w> <old_bp> <new_w> <new_bp> <n>  expected vectors per geometry",
        "#   Other lines beginning with '#' are comments. Every remaining line is one",
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


# ---------------------------------------------------------------------------
# The entity testbench
# ---------------------------------------------------------------------------

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


ENTITY_CASES = [
    # --- lm_math_fi_format ---------------------------------------------------
    _fmt("f_bpeq_u", "binary point equal to the width", 4, 4, 4, 4, UNSIGNED, ROUND_EVEN, SATURATE, W4),
    _fmt("f_bpeq_s", "binary point equal to the width", 4, 4, 4, 4, SIGNED, ROUND_EVEN, SATURATE, W4),
    _fmt("f_bpgt_src_u", "binary point above the width, source", 4, 8, 4, 2, UNSIGNED, TRUNC_BITS, WRAP, W4),
    _fmt("f_bpgt_src_s", "binary point above the width, source", 4, 8, 4, 2, SIGNED, TRUNC_BITS, WRAP, W4),
    _fmt("f_bpgt_dst_u", "binary point above the width, destination", 4, 2, 4, 8, UNSIGNED, ROUND_AWAY, SATURATE, W4),
    _fmt("f_bpgt_both_s", "binary point above the width, both sides", 4, 8, 4, 6, SIGNED, ROUND_EVEN, SATURATE, W4),
    _fmt("f_disj_above_s", "disjoint weights, destination above source", 4, 8, 4, 0, SIGNED, ROUND_AWAY, SATURATE, W4),
    _fmt("f_disj_below_u", "disjoint weights, destination below source", 4, 0, 4, 8, UNSIGNED, TRUNC_BITS, SATURATE, W4),
    _fmt("f_overlap1_u", "exactly one bit of weight overlap", 4, 4, 4, 1, UNSIGNED, ROUND_EVEN, WRAP, W4),
    _fmt("f_w1_u", "width 1 unsigned, binary point equal to the width", 1, 1, 1, 1, UNSIGNED, ROUND_EVEN, SATURATE, W1),
    _fmt("f_w1_s", "width 1 signed, binary point equal to the width", 1, 1, 1, 1, SIGNED, ROUND_EVEN, SATURATE, W1),
    _fmt("f_w1_from_wide_s", "width 1 signed destination from a wider source", 4, 3, 1, 1, SIGNED, ROUND_EVEN, SATURATE, W4),
    _fmt("f_w1_to_wide_s", "width 1 signed source into a wider destination", 1, 3, 4, 1, SIGNED, ROUND_EVEN, SATURATE, W1),
    # --- lm_math_fi_mult -----------------------------------------------------
    _mul("m_bpeq_u", "binary point equal to the width", 4, 4, 4, 4, 4, 4, UNSIGNED, ROUND_EVEN, SATURATE,
         [(a, b) for a in (0, 3, 15) for b in (0, 5, 15)]),
    _mul("m_bpgt_s", "binary point above the width", 4, 6, 4, 6, 4, 8, SIGNED, TRUNC_BITS, WRAP,
         [(a, b) for a in (0, 1, 7, 8) for b in (1, 15)]),
    _mul("m_w1_u", "width 1 unsigned", 1, 1, 1, 1, 1, 1, UNSIGNED, ROUND_EVEN, SATURATE,
         [(a, b) for a in W1 for b in W1]),
    _mul("m_w1_s", "width 1 signed", 1, 1, 1, 1, 1, 1, SIGNED, ROUND_EVEN, SATURATE,
         [(a, b) for a in W1 for b in W1]),
    # --- lm_math_fi_add_sub --------------------------------------------------
    _as("a_bpeq_u", "binary point equal to the width", 4, 4, 4, 4, 4, 4, UNSIGNED, ROUND_EVEN, ADD,
        [(a, b) for a in (0, 1, 15) for b in (0, 7, 15)]),
    _as("a_bpgt_s", "binary point above the width", 4, 8, 4, 6, 4, 9, SIGNED, ROUND_EVEN, SUB,
        [(a, b) for a in (0, 1, 8, 15) for b in (1, 15)]),
    _as("a_w1_u", "width 1 unsigned", 1, 1, 1, 1, 1, 1, UNSIGNED, ROUND_EVEN, ADD,
        [(a, b) for a in W1 for b in W1]),
    _as("a_w1_s", "width 1 signed", 1, 1, 1, 1, 1, 1, SIGNED, ROUND_EVEN, ADD,
        [(a, b) for a in W1 for b in W1]),
    # --- lm_math_fi_mult_add -------------------------------------------------
    _ma("ma_bpeq_u", "binary point equal to the width everywhere",
        4, 4, 4, 4, 8, 8, 8, 8, UNSIGNED, ROUND_EVEN, SATURATE, ADD,
        [(a, b, c) for a in (0, 3, 15) for b in (0, 15) for c in (0, 129, 255)]),
    _ma("ma_bpgt_ops_s", "binary point above the width on the operands",
        4, 6, 4, 6, 8, 2, 8, 4, SIGNED, ROUND_EVEN, SATURATE, ADD,
        [(a, b, c) for a in (0, 1, 8, 15) for b in (1, 15) for c in (0, 200)]),
    _ma("ma_bpgt_addend_s", "binary point above the width on the addend, subtract",
        4, 1, 4, 1, 8, 12, 8, 4, SIGNED, ROUND_EVEN, SATURATE, SUB,
        [(a, b, c) for a in (0, 1, 8) for b in (1, 15) for c in (0, 129, 255)]),
    _ma("ma_bpgt_all_u", "binary point above the width everywhere",
        4, 6, 4, 6, 8, 12, 8, 14, UNSIGNED, ROUND_AWAY, WRAP, ADD,
        [(a, b, c) for a in (0, 1, 15) for b in (1, 15) for c in (0, 255)]),
    _ma("ma_bpgt_out_s", "binary point above the width on the output only",
        4, 1, 4, 1, 8, 1, 4, 9, SIGNED, ROUND_EVEN, SATURATE, ADD,
        [(a, b, c) for a in (0, 1, 8) for b in (1, 15) for c in (0, 200)]),
    _ma("ma_w1_u", "width 1 unsigned everywhere",
        1, 1, 1, 1, 1, 1, 1, 1, UNSIGNED, ROUND_EVEN, SATURATE, ADD,
        [(a, b, c) for a in W1 for b in W1 for c in W1]),
    _ma("ma_w1_s", "width 1 signed everywhere",
        1, 1, 1, 1, 1, 1, 1, 1, SIGNED, ROUND_EVEN, SATURATE, ADD,
        [(a, b, c) for a in W1 for b in W1 for c in W1]),
]


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
    if case["kind"] == "add_sub":
        sign = "+" if case["direction"] == ADD else "-"
        return f'({case["aw"]},{case["abp"]}){sign}({case["bw"]},{case["bbp"]}) -> {dst}'
    sign = "+" if case["direction"] == ADD else "-"
    return (f'({case["aw"]},{case["abp"]})x({case["bw"]},{case["bbp"]})'
            f'{sign}({case["cw"]},{case["cbp"]}) -> {dst}')


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
-- Covered here, on each of the four entities that quantize a result:
--   binary point equal to the width
--   binary point above the width: source only, destination only, both
--   bit weights disjoint, destination entirely above and entirely below
--   exactly one bit of weight overlap
--   width 1, unsigned and signed
--
-- HOW THE EXPECTED VALUES WERE PRODUCED
--   By scripts/gen_format_vectors.py, which computes the arithmetic from the
--   documented semantics using arbitrary-precision integers and fractions,
--   twice in two different styles, and refuses to emit anything unless the two
--   agree. It imports nothing from src/, model/ or js/.
--
--   For the three arithmetic modules the reference also models each module's
--   own internal intermediate format, because that is part of the library's
--   defined behaviour: operands are aligned into the internal format and the
--   accumulator wraps there. That is what makes an unsigned subtraction that
--   goes negative wrap rather than clamp, which sim/tb/tb_lm_math_fi_add_sub.vhd
--   already relies on.
--
-- {n_checks} named checks.

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


# ---------------------------------------------------------------------------

def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--check",
        action="store_true",
        help="Regenerate in memory and fail if either committed file differs.",
    )
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
            on_disk = path.read_bytes()
            if on_disk != text.encode("utf-8"):
                print(f"error: {rel} does not match the generator; regenerate it with "
                      "'python scripts/gen_format_vectors.py'", file=sys.stderr)
                print(f"  on disk {len(on_disk)} bytes, generated "
                      f"{len(text.encode('utf-8'))} bytes", file=sys.stderr)
                failed = True
        if failed:
            return 1
        print(f"format expectations up to date: {len(rows)} vectors over "
              f"{len(VECTOR_GEOMETRIES)} geometries, and the entity testbench, "
              "both reproduced by two independent references")
        return 0

    for path, text in targets:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(text.encode("utf-8"))
        print(f"wrote {path.relative_to(ROOT).as_posix()}")
    print(f"{len(rows)} vectors over {len(VECTOR_GEOMETRIES)} geometries; "
          "two independent references agreed on every value")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
