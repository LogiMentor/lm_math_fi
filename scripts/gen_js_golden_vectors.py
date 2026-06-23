#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 LogiMentor

"""Generate the JS golden-vector file from the fxpmath-based Python model.

The Python model (model/lm_math_fi_model) is the single source of truth. This
script exercises it across the full mode/format/value cross product and emits a
JSON file that the Node test runner replays to confirm the JS port reproduces
every result bit-for-bit.

Each vector records a replayable operation plus the model's exact outputs
(bits, raw_signed, raw_unsigned, hex, float). raw_signed / raw_unsigned are
emitted as decimal strings so values wider than 53 bits survive JSON.

Provenance (fxpmath version and the repository git commit) is embedded in the
output for downstream auditing.
"""

from __future__ import annotations

import json
import math
import pathlib
import subprocess
import sys
from importlib import metadata

sys.dont_write_bytecode = True

ROOT = pathlib.Path(__file__).resolve().parents[1]
MODEL_DIR = ROOT / "model"
OUT_PATH = ROOT / "js" / "golden_vectors.json"

sys.path.insert(0, str(MODEL_DIR))

from lm_math_fi_model import (  # noqa: E402
    FiFormat,
    ROUNDING_MAP,
    bits as m_bits,
    fi as m_fi,
    quantize as m_quantize,
    raw as m_raw,
    add as m_add,
    sub as m_sub,
    mul as m_mul,
    mult_add as m_mult_add,
)

ALL_ROUNDINGS = sorted(ROUNDING_MAP)
OVERFLOWS = ["wrap", "saturate"]


# --- value-spec helpers (replayable in both Python and JS) -------------------

def vfloat(v):
    return {"t": "float", "v": v}


def vint(v):
    return {"t": "int", "v": str(int(v))}


def vstr(v):
    return {"t": "str", "v": str(v)}


def fmt_spec(width, binpnt, signed):
    return [width, binpnt, signed]


def ctor_fi(value_spec, width, binpnt, signed, rounding="trunc_bits", overflow="wrap"):
    return {
        "ctor": "fi",
        "value": value_spec,
        "fmt": fmt_spec(width, binpnt, signed),
        "rounding": rounding,
        "overflow": overflow,
    }


def ctor_bits(bitstr, width, binpnt, signed):
    return {"ctor": "bits", "value": str(bitstr), "fmt": fmt_spec(width, binpnt, signed)}


def ctor_raw(rawval, width, binpnt, signed):
    return {"ctor": "raw", "value": str(int(rawval)), "fmt": fmt_spec(width, binpnt, signed)}


# --- model execution of a ctor / operation ----------------------------------

def _fmt(spec):
    w, b, s = spec
    return FiFormat(width=w, binpnt=b, signed=bool(s))


def _value(value_spec):
    t = value_spec["t"]
    v = value_spec["v"]
    if t == "float":
        return float(v)
    if t == "int":
        return int(v)
    if t == "str":
        return str(v)
    raise ValueError(f"bad value spec {value_spec!r}")


def build_ctor(ctor):
    fmt = _fmt(ctor["fmt"])
    kind = ctor["ctor"]
    if kind == "fi":
        return m_fi(
            _value(ctor["value"]),
            fmt,
            rounding=ctor.get("rounding", "trunc_bits"),
            overflow=ctor.get("overflow", "wrap"),
        )
    if kind == "bits":
        return m_bits(ctor["value"], fmt)
    if kind == "raw":
        return m_raw(int(ctor["value"]), fmt)
    raise ValueError(f"bad ctor {kind!r}")


def hex_of(value):
    digits = math.ceil(value.fmt.width / 4)
    return "0x" + format(value.raw_unsigned, "0{}X".format(digits))


def expect_of(value):
    return {
        "bits": value.bits,
        "raw_signed": str(value.raw_signed),
        "raw_unsigned": str(value.raw_unsigned),
        "hex": hex_of(value),
        "float": value.to_float(),
    }


def run_op(entry):
    op = entry["op"]
    s = entry["spec"]
    if op in ("fi", "bits", "raw"):
        return build_ctor(s)
    if op == "quantize":
        src = build_ctor(s["source"])
        return m_quantize(src, _fmt(s["fmt"]), rounding=s.get("rounding", "trunc_bits"), overflow=s.get("overflow", "wrap"))
    if op in ("add", "sub", "mul"):
        left = build_ctor(s["left"])
        right = build_ctor(s["right"])
        fn = {"add": m_add, "sub": m_sub, "mul": m_mul}[op]
        return fn(left, right, _fmt(s["fmt"]), rounding=s.get("rounding", "trunc_bits"), overflow=s.get("overflow", "wrap"))
    if op == "mult_add":
        left = build_ctor(s["left"])
        right = build_ctor(s["right"])
        addend = build_ctor(s["addend"])
        return m_mult_add(
            left, right, addend, _fmt(s["fmt"]),
            subtract=s.get("subtract", False),
            rounding=s.get("rounding", "trunc_bits"),
            overflow=s.get("overflow", "wrap"),
        )
    raise ValueError(f"bad op {op!r}")


# --- vector construction -----------------------------------------------------

class Builder:
    def __init__(self):
        self.entries = []
        self._id = 0
        self.skipped = []

    def add(self, op, spec, note=""):
        value = run_op({"op": op, "spec": spec})
        self._id += 1
        self.entries.append({
            "id": self._id,
            "op": op,
            "note": note,
            "spec": spec,
            "expect": expect_of(value),
        })
        return value

    def try_add(self, op, spec, note=""):
        """Add a vector, but skip (and record) cases fxpmath itself cannot compute.

        Used only for extreme high-width probes: fxpmath raises (e.g. OverflowError)
        for some >64-bit results, which marks the edge of its supported domain. We
        record these so coverage limits are never silent.
        """
        try:
            return self.add(op, spec, note=note)
        except Exception as exc:  # noqa: BLE001 - intentional domain probe
            self.skipped.append((op, note, type(exc).__name__, str(exc)))
            return None


def build_vectors():
    b = Builder()

    # ---- 1. rounding cross product: quantize every source raw of a small -----
    #         signed/unsigned (W,2) format down to (W,1) for every rounding mode.
    #         This systematically covers ties (pos/neg) and non-ties.
    for signed in (True, False):
        src_w, src_bp = 6, 2
        if signed:
            raws = range(-(1 << (src_w - 1)), 1 << (src_w - 1))
        else:
            raws = range(0, 1 << src_w)
        for rnd in ALL_ROUNDINGS:
            for rv in raws:
                b.add("quantize", {
                    "source": ctor_raw(rv, src_w, src_bp, signed),
                    "fmt": fmt_spec(src_w, 1, signed),
                    "rounding": rnd,
                    "overflow": "wrap",
                }, note=f"round {rnd} signed={signed}")

    # ---- 2. float-input ties and near-ties for every rounding mode -----------
    float_vals = [
        0.0, -0.0, 0.125, -0.125, 0.375, -0.375, 0.625, -0.625, 0.875, -0.875,
        0.25, -0.25, 0.5, -0.5, 1.5, -1.5, 2.5, -2.5, 0.1, -0.1, 0.7, -0.7,
        1.0 / 3.0, -1.0 / 3.0, 0.96875, -0.96875,
    ]
    for signed in (True, False):
        for rnd in ALL_ROUNDINGS:
            for v in float_vals:
                if not signed and v < 0:
                    continue
                b.add("fi", ctor_fi(vfloat(v), 8, 2, signed, rounding=rnd, overflow="wrap"),
                      note=f"fi float {v} round {rnd}")

    # ---- 3. overflow: wrap and saturate, signed and unsigned ----------------
    for signed in (True, False):
        for ovf in OVERFLOWS:
            for v in [3.5, -3.5, 7.9, -7.9, 15.0, -15.0, 100.0, -100.0, 0.0]:
                if not signed and v < 0:
                    continue
                b.add("fi", ctor_fi(vfloat(v), 5, 1, signed, rounding="trunc_bits", overflow=ovf),
                      note=f"overflow {ovf} signed={signed} v={v}")

    # signed<->unsigned conversions (incl. the model's documented cases)
    for ovf in OVERFLOWS:
        b.add("quantize", {"source": ctor_bits("1111", 4, 0, False), "fmt": fmt_spec(4, 0, True), "overflow": ovf},
              note="unsigned->signed convert")
        b.add("quantize", {"source": ctor_bits("1111", 4, 0, False), "fmt": fmt_spec(5, 0, True), "overflow": ovf},
              note="unsigned->signed widen")
        b.add("quantize", {"source": ctor_raw(-1, 5, 0, True), "fmt": fmt_spec(4, 0, False), "overflow": ovf},
              note="signed->unsigned convert")

    # binpnt growth/shrink and width changes
    for rnd in ["trunc_bits", "trunc_zero", "fix", "round", "floor", "ceil"]:
        b.add("quantize", {"source": ctor_raw(0b10111, 5, 2, True), "fmt": fmt_spec(8, 4, True), "rounding": rnd},
              note="binpnt grow")
        b.add("quantize", {"source": ctor_raw(0b10111, 5, 2, True), "fmt": fmt_spec(5, 0, True), "rounding": rnd},
              note="binpnt shrink to int")

    # ---- 4. arithmetic: add/sub/mul/mult_add --------------------------------
    arith_ops = []
    for la, lb, ls in [(4, 1, False), (4, 1, True), (4, 2, True), (6, 3, True)]:
        for ra, rb, rs in [(4, 1, False), (4, 1, True), (4, 2, True)]:
            arith_ops.append(((la, lb, ls), (ra, rb, rs)))

    def operands(lf, rf):
        lw, lbp, lsg = lf
        rw, rbp, rsg = rf
        lmax = (1 << (lw - 1)) - 1 if lsg else (1 << lw) - 1
        lmin = -(1 << (lw - 1)) if lsg else 0
        rmax = (1 << (rw - 1)) - 1 if rsg else (1 << rw) - 1
        rmin = -(1 << (rw - 1)) if rsg else 0
        lvals = sorted({lmin, lmax, 0, lmin // 2, lmax // 2, 1, -1 if lsg else 0})
        rvals = sorted({rmin, rmax, 0, rmin // 2, rmax // 2, 1, -1 if rsg else 0})
        for lv in lvals:
            for rv in rvals:
                yield lv, rv

    for (lf, rf) in arith_ops:
        out_w = max(lf[0], rf[0]) + 2
        out_bp = max(lf[1], rf[1])
        out_signed = lf[2] or rf[2]
        for lv, rv in operands(lf, rf):
            left = ctor_raw(lv, *lf)
            right = ctor_raw(rv, *rf)
            for op in ("add", "sub", "mul"):
                b.add(op, {"left": left, "right": right,
                           "fmt": fmt_spec(out_w, out_bp, out_signed),
                           "rounding": "trunc_bits", "overflow": "wrap"},
                      note=f"{op}")
            # mult_add and msub
            addend = ctor_raw(rv, max(lf[0], rf[0]) + 1, out_bp, out_signed)
            for sub_flag in (False, True):
                b.add("mult_add", {"left": left, "right": right, "addend": addend,
                                   "fmt": fmt_spec(out_w + lf[1] + rf[1], out_bp, out_signed),
                                   "subtract": sub_flag,
                                   "rounding": "round", "overflow": "wrap"},
                      note=f"mult_add subtract={sub_flag}")

    # fractional mul with rounding (exercises requantization narrowing + ties)
    for rnd in ALL_ROUNDINGS:
        b.add("mul", {"left": ctor_raw(0b0010, 4, 2, False), "right": ctor_raw(0b0111, 4, 2, False),
                      "fmt": fmt_spec(8, 2, False), "rounding": rnd, "overflow": "wrap"},
              note=f"frac mul round {rnd}")
        b.add("mul", {"left": ctor_raw(-2, 4, 2, True), "right": ctor_raw(5, 4, 2, True),
                      "fmt": fmt_spec(8, 2, True), "rounding": rnd, "overflow": "wrap"},
              note=f"signed frac mul round {rnd}")

    # ---- 5. high-width boundary probes --------------------------------------
    #         widths around 52/53/54 and 63/64/65 for float, raw, and bit input.
    boundary_widths = [52, 53, 54, 63, 64, 65]
    for w in boundary_widths:
        for signed in (True, False):
            # bit input, integer (binpnt 0): exact at any width
            ones = "1" * w
            b.add("bits", ctor_bits(ones, w, 0, signed), note=f"bit int w={w} signed={signed}")
            # bit input, fractional (binpnt 4): float64-lossy above 2**53
            b.add("bits", ctor_bits(ones, w, 4, signed), note=f"bit frac w={w} signed={signed}")
            # raw input across the boundary, integer and fractional
            probe_raws = [(1 << (w - 1)), (1 << (w - 1)) - 1, (1 << (w - 1)) + 1,
                          (1 << 53), (1 << 53) + 1, (1 << 52) + 3]
            for rv in probe_raws:
                b.add("raw", ctor_raw(rv, w, 0, signed), note=f"raw int w={w} rv={rv}")
                b.add("raw", ctor_raw(rv, w, 4, signed), note=f"raw frac w={w} rv={rv}")
            # float input near the 2**53 boundary at this width
            for v in [float(1 << 50), float((1 << 53) - 1), 1.5, 0.5, 123.456]:
                b.add("fi", ctor_fi(vfloat(v), w, 4, signed, rounding="round", overflow="wrap"),
                      note=f"fi float w={w} v={v}")
            # exact large-integer input (BigInt path mirrors a Python int)
            b.add("fi", ctor_fi(vint((1 << (w - 2)) + 1), w, 0, signed, rounding="trunc_bits", overflow="wrap"),
                  note=f"fi bigint w={w}")
            b.add("fi", ctor_fi(vint((1 << (w - 2)) + 1), w, 4, signed, rounding="trunc_bits", overflow="wrap"),
                  note=f"fi bigint frac w={w}")

    # ---- 5b. high-width arithmetic (exact in fxpmath via object/int) ---------
    #          products and sums that exceed 53/64 bits, with narrowing requant.
    hw_pairs = [
        ((40, 0, True), (40, 0, True), (1 << 31) + 1, (1 << 31) - 1),
        ((60, 0, True), (60, 0, True), (1 << 50) + 12345, (1 << 50) + 67),
        ((64, 0, True), (64, 0, True), (1 << 62) + 5, -((1 << 62) - 9)),
        ((48, 20, True), (48, 20, True), (1 << 40) + 3, (1 << 40) - 7),
        ((40, 0, False), (40, 0, False), (1 << 39) + 1, (1 << 39) - 2),
    ]
    for (lf, rf, lv, rv) in hw_pairs:
        left = ctor_raw(lv, *lf)
        right = ctor_raw(rv, *rf)
        # product is exact and wide; narrow back below the float64 boundary too.
        # try_add skips cases fxpmath itself cannot compute (extreme >64-bit).
        b.try_add("mul", {"left": left, "right": right,
                          "fmt": fmt_spec(lf[0] + rf[0], lf[1] + rf[1], lf[2] or rf[2]),
                          "rounding": "trunc_bits", "overflow": "wrap"}, note="hw mul full")
        b.try_add("mul", {"left": left, "right": right,
                          "fmt": fmt_spec(32, max(lf[1], rf[1]), lf[2] or rf[2]),
                          "rounding": "round", "overflow": "wrap"}, note="hw mul narrow round")
        for op in ("add", "sub"):
            b.try_add(op, {"left": left, "right": right,
                           "fmt": fmt_spec(max(lf[0], rf[0]) + 2, max(lf[1], rf[1]), lf[2] or rf[2]),
                           "rounding": "trunc_bits", "overflow": "wrap"}, note=f"hw {op}")

    # ---- 6. negative zero in several forms ----------------------------------
    for signed in (True, False):
        b.add("fi", ctor_fi(vfloat(-0.0), 8, 4, signed), note="fi -0.0")
        b.add("fi", ctor_fi(vfloat(0.0), 8, 4, signed), note="fi 0.0")
        b.add("raw", ctor_raw(0, 8, 4, signed), note="raw 0")
    b.add("quantize", {"source": ctor_fi(vfloat(-0.0), 8, 4, True), "fmt": fmt_spec(4, 1, True), "rounding": "round"},
          note="quantize -0.0")

    # ---- 7. every case already asserted in test_lm_math_fi_model.py ---------
    add_unittest_cases(b)

    return b


def add_unittest_cases(b):
    # Mirror model/tests/test_lm_math_fi_model.py exactly.
    b.add("bits", ctor_bits("10111", 5, 2, True), note="ut bits_and_raw_values")
    b.add("quantize", {"source": ctor_bits("10111", 5, 2, True), "fmt": fmt_spec(5, 1, True), "rounding": "trunc_bits"}, note="ut trunc_bits")
    b.add("quantize", {"source": ctor_bits("10111", 5, 2, True), "fmt": fmt_spec(5, 1, True), "rounding": "trunc_zero"}, note="ut trunc_zero")
    b.add("quantize", {"source": ctor_bits("10111", 5, 2, True), "fmt": fmt_spec(5, 1, True), "rounding": "round"}, note="ut round even neg")
    b.add("quantize", {"source": ctor_bits("10101", 5, 2, True), "fmt": fmt_spec(5, 1, True), "rounding": "round"}, note="ut round even pos")
    for rnd, src in [("floor", "01001"), ("ceil", "10111"), ("round_pos_inf", "01001"), ("round_pos_inf", "10111"),
                     ("round_neg_inf", "01001"), ("round_neg_inf", "10111"), ("round_zero", "01001"), ("round_zero", "10111"),
                     ("round_away", "01001"), ("round_away", "10111"), ("round_inf", "01001"), ("round_inf", "10111")]:
        b.add("quantize", {"source": ctor_bits(src, 5, 2, True), "fmt": fmt_spec(5, 1, True), "rounding": rnd}, note=f"ut tie {rnd} {src}")
    b.add("sub", {"left": ctor_bits("0001", 4, 0, False), "right": ctor_bits("0011", 4, 0, False), "fmt": fmt_spec(5, 0, False)}, note="ut unsigned sub wrap")
    b.add("quantize", {"source": ctor_bits("1111", 4, 0, False), "fmt": fmt_spec(4, 0, True), "overflow": "saturate"}, note="ut u2s sat")
    b.add("quantize", {"source": ctor_bits("1111", 4, 0, False), "fmt": fmt_spec(5, 0, True), "overflow": "wrap"}, note="ut u2s widen")
    b.add("add", {"left": ctor_raw(3, 4, 1, False), "right": ctor_raw(5, 4, 1, False), "fmt": fmt_spec(5, 1, False)}, note="ut add rtl")
    b.add("mul", {"left": ctor_raw(-3, 4, 0, True), "right": ctor_raw(15, 4, 0, False), "fmt": fmt_spec(8, 0, True)}, note="ut mul rtl")
    b.add("mult_add", {"left": ctor_fi(vfloat(1.5), 4, 2, False), "right": ctor_fi(vfloat(0.75), 4, 2, False),
                       "addend": ctor_fi(vfloat(0.25), 6, 2, False), "fmt": fmt_spec(6, 2, False), "rounding": "round"}, note="ut mult_add round")


# --- RTL-overlap cross-check (vectors baked into the VHDL testbenches) -------

def rtl_overlap_checks():
    """Assert the model reproduces concrete expectations from the VHDL TBs.

    Sourced from sim/tb/tb_lm_math_fi_mult.vhd. This is a sanity cross-check
    (not the primary gate). Each entry: (operation result, expected bits).
    """
    F = FiFormat
    checks = [
        # unsigned 15*15 -> 225 in (8,0,U)
        (m_mul(m_raw(15, F(4, 0, False)), m_raw(15, F(4, 0, False)), F(8, 0, False)), "11100001"),
        # unsigned 15*15 wrap to (4,0,U) -> 1
        (m_mul(m_raw(15, F(4, 0, False)), m_raw(15, F(4, 0, False)), F(4, 0, False), overflow="wrap"), "0001"),
        # unsigned 15*15 saturate to (4,0,U) -> 15
        (m_mul(m_raw(15, F(4, 0, False)), m_raw(15, F(4, 0, False)), F(4, 0, False), overflow="saturate"), "1111"),
        # signed -3*5 -> -15 in (8,0,S)
        (m_mul(m_raw(-3, F(4, 0, True)), m_raw(5, F(4, 0, True)), F(8, 0, True)), "11110001"),
        # signed*unsigned -3*15 -> -45
        (m_mul(m_raw(-3, F(4, 0, True)), m_raw(15, F(4, 0, False)), F(8, 0, True)), "11010011"),
        # unsigned*signed 15*-3 -> -45
        (m_mul(m_raw(15, F(4, 0, False)), m_raw(-3, F(4, 0, True)), F(8, 0, True)), "11010011"),
        # unsigned frac round-even: 0.5 * 1.75 = 0.875 -> raw 3.5 -> 4
        (m_mul(m_raw(2, F(4, 2, False)), m_raw(7, F(4, 2, False)), F(8, 2, False), rounding="round_even"), "00000100"),
        # signed frac round-even tie toward even (zero): -0.5*1.25=-0.625 -> -2.5 -> -2
        (m_mul(m_raw(-2, F(4, 2, True)), m_raw(5, F(4, 2, True)), F(8, 2, True), rounding="round_even"), "11111110"),
        # signed min: -8*1 -> -8
        (m_mul(m_raw(-8, F(4, 0, True)), m_raw(1, F(4, 0, True)), F(8, 0, True)), "11111000"),
        # signed frac round-even tie to even (away): -0.5*1.75=-0.875 -> -3.5 -> -4
        (m_mul(m_raw(-2, F(4, 2, True)), m_raw(7, F(4, 2, True)), F(8, 2, True), rounding="round_even"), "11111100"),
    ]
    failures = []
    for value, expected in checks:
        if value.bits != expected:
            failures.append((value.bits, expected))
    return failures


# --- main --------------------------------------------------------------------

def git_commit():
    try:
        return subprocess.check_output(
            ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True
        ).strip()
    except Exception:
        return "unknown"


def main() -> int:
    import argparse

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--check",
        action="store_true",
        help="Regenerate in memory and verify the committed file matches (ignoring "
        "the volatile provenance git commit). Exit non-zero on any vector drift.",
    )
    args = parser.parse_args()

    fxp_version = metadata.version("fxpmath")
    if fxp_version != "0.4.10":
        print(f"error: expected fxpmath==0.4.10, found {fxp_version}", file=sys.stderr)
        return 2

    failures = rtl_overlap_checks()
    if failures:
        print("error: model disagrees with VHDL-testbench overlap vectors:", file=sys.stderr)
        for got, want in failures:
            print(f"  got {got} want {want}", file=sys.stderr)
        return 1

    builder = build_vectors()
    entries = builder.entries

    doc = {
        "schema": "lm_math_fi.golden.v1",
        "provenance": {
            "fxpmath_version": fxp_version,
            "model": "lm_math_fi_model",
            "source_git_commit": git_commit(),
            "rounding_keys": ALL_ROUNDINGS,
            "overflow_keys": OVERFLOWS,
        },
        "rtl_overlap_checked": True,
        "count": len(entries),
        "vectors": entries,
    }

    if builder.skipped:
        print(f"note: skipped {len(builder.skipped)} probe(s) that fxpmath itself cannot compute "
              "(edge of fxpmath's supported domain):")
        for op, note, exc, msg in builder.skipped:
            print(f"  - {op} [{note}]: {exc}: {msg}")

    serialized = json.dumps(doc, indent=1, ensure_ascii=False) + "\n"

    if args.check:
        if not OUT_PATH.exists():
            print(f"error: {OUT_PATH.relative_to(ROOT)} is missing; run the generator", file=sys.stderr)
            return 1
        committed = json.loads(OUT_PATH.read_text(encoding="utf-8"))
        fresh = json.loads(serialized)
        # Ignore the volatile provenance commit (it tracks generation-time HEAD).
        committed["provenance"]["source_git_commit"] = ""
        fresh["provenance"]["source_git_commit"] = ""
        if committed != fresh:
            print(
                "error: committed js/golden_vectors.json does not match the current model; "
                "regenerate with 'python scripts/gen_js_golden_vectors.py'",
                file=sys.stderr,
            )
            return 1
        print(f"golden vectors up to date ({len(entries)} vectors, fxpmath=={fxp_version})")
        return 0

    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUT_PATH.write_text(serialized, encoding="utf-8", newline="\n")

    print(f"wrote {len(entries)} vectors to {OUT_PATH.relative_to(ROOT)}")
    print(f"fxpmath=={fxp_version} commit={doc['provenance']['source_git_commit'][:12]}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
