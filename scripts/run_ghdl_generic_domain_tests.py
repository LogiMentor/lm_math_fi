#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 LogiMentor

"""Gate the generic domains of the public entities, in both directions.

Positive half - a legal value must never be rejected:
  * every entity is instantiated across the full legal cross-product of its
    discrete-domain generics and run past time 0, and no assertion may fire;
  * f_lm_quantize is replayed against committed vectors, so a domain check that
    wrongly narrowed the arithmetic fails here;
  * each negative testbench is run once with no override, proving that all of
    its defaults are legal. Without that, a negative case could pass because its
    default was already illegal rather than because the override was.

Negative half - an illegal value must be rejected with a diagnostic that names
the caller's mistake. Cases are selected by a GHDL top-level generic override,
so there is one testbench per entity rather than one per case.

Two kinds of negative case, matched differently:
  ASSERTION - rejected by a concurrent assertion written in src/. Matched on the
    message text, which this repository owns.
  SUBTYPE   - rejected by GHDL because the value is outside the generic's
    declared subtype. Matched on the failing phase and the generic's name only.
    GHDL's wording is tool output and will change across versions, so it is
    deliberately not matched.

SUBTYPE cases exercise the testbench's mirror of the generic, not the entity's
own declaration, so check_interface_declarations() separately pins the subtype
each entity declares. Both are needed: the run proves the value is rejected, the
source check proves the entity is what rejects it.
"""

from __future__ import annotations

import argparse
import re
import shutil
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / "build" / "ghdl_generic_domain"
GATE_DIR = ROOT / "sim" / "generic_domain"
VECTOR_FILE = "f_lm_quantize_vectors.txt"

SRC_FILES = [
    "src/lm_math_fi_pkg.vhd",
    "src/lm_math_fi_delay.vhd",
    "src/lm_math_fi_format.vhd",
    "src/lm_math_fi_add_sub.vhd",
    "src/lm_math_fi_mult.vhd",
    "src/lm_math_fi_mult_add.vhd",
]

# Units elaborated once and then run many times with different -g overrides.
POSITIVE_UNITS = ["tb_legal_sweep", "tb_quantize_vectors"]
NEGATIVE_UNITS = [
    "tb_neg_delay",
    "tb_neg_format",
    "tb_neg_add_sub",
    "tb_neg_mult",
    "tb_neg_mult_add",
    "tb_neg_pkg",
]

# Emitted by every negative testbench if it runs to completion.
COMPLETION_MARKER = "GENERIC DOMAIN TB COMPLETED"
# Emitted by both positive testbenches on success.
PASS_MARKER = "TEST PASSED"

KIND_ASSERTION = "assertion"
KIND_SUBTYPE = "subtype"


# ---------------------------------------------------------------------------
# Interface declarations: which generics carry their domain in their subtype.
# ---------------------------------------------------------------------------
# This is the record of a deliberate decision. Width and pipeline-depth domains
# are contiguous, self-evident numeric bounds, so they live in the subtype.
# Enumerations encoded as integers (rounding, overflow, representation, add/sub
# selector) do NOT get a range here: their admissible set can grow and is not
# contiguous in every case, and a range duplicated across entities would drift
# from the constants in lm_math_fi_pkg. Those keep their assertions.
INTERFACE_DECLARATIONS = [
    ("src/lm_math_fi_delay.vhd", "g_delay", "natural"),
    ("src/lm_math_fi_delay.vhd", "g_data_w", "positive"),
    ("src/lm_math_fi_format.vhd", "g_din_w", "positive"),
    ("src/lm_math_fi_format.vhd", "g_dout_w", "positive"),
    ("src/lm_math_fi_format.vhd", "g_pipe_stages", "natural"),
    ("src/lm_math_fi_add_sub.vhd", "g_pipeline_input", "natural range 0 to 1"),
    ("src/lm_math_fi_add_sub.vhd", "g_pipeline_output", "natural"),
    ("src/lm_math_fi_add_sub.vhd", "g_din1_w", "positive"),
    ("src/lm_math_fi_add_sub.vhd", "g_din2_w", "positive"),
    ("src/lm_math_fi_add_sub.vhd", "g_dout_w", "positive"),
    ("src/lm_math_fi_mult.vhd", "g_din_a_w", "positive"),
    ("src/lm_math_fi_mult.vhd", "g_din_b_w", "positive"),
    ("src/lm_math_fi_mult.vhd", "g_dout_w", "positive"),
    ("src/lm_math_fi_mult.vhd", "g_pipe_stages", "natural"),
    ("src/lm_math_fi_mult_add.vhd", "g_din_a_w", "positive"),
    ("src/lm_math_fi_mult_add.vhd", "g_din_b_w", "positive"),
    ("src/lm_math_fi_mult_add.vhd", "g_din_c_w", "positive"),
    ("src/lm_math_fi_mult_add.vhd", "g_dout_w", "positive"),
    ("src/lm_math_fi_mult_add.vhd", "g_pipe_stages", "natural"),
]


@dataclass(frozen=True)
class Case:
    unit: str
    generic: str
    value: str
    kind: str
    why: str
    expect: list[str] = field(default_factory=list)

    @property
    def name(self) -> str:
        return f"{self.unit}[{self.generic}={self.value}]"


def assertion_case(unit, generic, value, why, expect):
    return Case(unit, generic, value, KIND_ASSERTION, why, expect)


def subtype_case(unit, generic, value, why):
    # Matched on the generic name only, never on GHDL's wording.
    return Case(unit, generic, value, KIND_SUBTYPE, why, [generic])


REPRESENTATION_VALUES = "C_LM_UNSIGNED (1) or C_LM_SIGNED (2)"
OVERFLOW_VALUES = "C_LM_SATURATE (1) or C_LM_WRAP (2)"
ROUND_FIRST = "C_LM_TRUNC_BITS (0)"
ROUND_LAST = "C_LM_ROUND_AWAY (8)"

CASES = [
    # --- lm_math_fi_pkg.f_lm_quantize ---------------------------------------
    assertion_case(
        "tb_neg_pkg", "g_round_mode", "42",
        "f_lm_quantize rejects a rounding mode that is not one of the nine constants",
        ["lm_math_fi_pkg.f_lm_quantize: rounding mode 42 is not a supported value",
         ROUND_FIRST, ROUND_LAST],
    ),
    assertion_case(
        "tb_neg_pkg", "g_overflow", "0",
        "f_lm_quantize rejects an overflow mode that is neither saturate nor wrap",
        ["lm_math_fi_pkg.f_lm_quantize: overflow mode 0 is not a supported value",
         OVERFLOW_VALUES],
    ),
    # --- lm_math_fi_delay ---------------------------------------------------
    subtype_case("tb_neg_delay", "g_data_w", "0", "a zero-width port is not a configuration"),
    subtype_case("tb_neg_delay", "g_delay", "-1", "a negative delay is not a configuration"),
    # --- lm_math_fi_format --------------------------------------------------
    assertion_case(
        "tb_neg_format", "g_representation", "0",
        "lm_math_fi_format rejects a representation that is neither signed nor unsigned",
        ["lm_math_fi_format: generic g_representation = 0 is not a supported value",
         REPRESENTATION_VALUES],
    ),
    assertion_case(
        "tb_neg_format", "g_round_mode", "42",
        "lm_math_fi_format rejects an out-of-domain rounding mode",
        ["lm_math_fi_format: generic g_round_mode = 42 is not a supported value",
         ROUND_LAST],
    ),
    assertion_case(
        "tb_neg_format", "g_overflow", "0",
        "lm_math_fi_format rejects an out-of-domain overflow mode",
        ["lm_math_fi_format: generic g_overflow = 0 is not a supported value",
         OVERFLOW_VALUES],
    ),
    subtype_case("tb_neg_format", "g_din_w", "0", "a zero-width input is not a configuration"),
    subtype_case("tb_neg_format", "g_dout_w", "0", "a zero-width output is not a configuration"),
    # --- lm_math_fi_add_sub -------------------------------------------------
    assertion_case(
        "tb_neg_add_sub", "g_direction", "7",
        "lm_math_fi_add_sub rejects an out-of-domain direction",
        ["lm_math_fi_add_sub: generic g_direction = 7 is not a supported value",
         "C_LM_ADDSUB (2)"],
    ),
    assertion_case(
        "tb_neg_add_sub", "g_representation", "0",
        "lm_math_fi_add_sub rejects a representation that selects no arithmetic branch",
        ["lm_math_fi_add_sub: generic g_representation = 0 is not a supported value",
         REPRESENTATION_VALUES],
    ),
    assertion_case(
        "tb_neg_add_sub", "g_round_mode", "42",
        "lm_math_fi_add_sub rejects an out-of-domain rounding mode",
        ["lm_math_fi_add_sub: generic g_round_mode = 42 is not a supported value",
         ROUND_LAST],
    ),
    subtype_case("tb_neg_add_sub", "g_pipeline_input", "2",
                 "the input register stage is one deep or absent, never deeper"),
    subtype_case("tb_neg_add_sub", "g_din1_w", "0", "a zero-width input is not a configuration"),
    subtype_case("tb_neg_add_sub", "g_din2_w", "0", "a zero-width input is not a configuration"),
    subtype_case("tb_neg_add_sub", "g_dout_w", "0", "a zero-width output is not a configuration"),
    # --- lm_math_fi_mult ----------------------------------------------------
    assertion_case(
        "tb_neg_mult", "g_din_a_type", "0",
        "lm_math_fi_mult rejects an operand A type that is neither signed nor unsigned",
        ["lm_math_fi_mult: generic g_din_a_type = 0 is not a supported value",
         REPRESENTATION_VALUES],
    ),
    assertion_case(
        "tb_neg_mult", "g_din_b_type", "0",
        "lm_math_fi_mult rejects an operand B type that is neither signed nor unsigned",
        ["lm_math_fi_mult: generic g_din_b_type = 0 is not a supported value",
         REPRESENTATION_VALUES],
    ),
    assertion_case(
        "tb_neg_mult", "g_dout_type", "0",
        "lm_math_fi_mult rejects a result type that is neither signed nor unsigned",
        ["lm_math_fi_mult: generic g_dout_type = 0 is not a supported value",
         REPRESENTATION_VALUES],
    ),
    assertion_case(
        "tb_neg_mult", "g_round_mode", "42",
        "lm_math_fi_mult rejects an out-of-domain rounding mode",
        ["lm_math_fi_mult: generic g_round_mode = 42 is not a supported value", ROUND_LAST],
    ),
    assertion_case(
        "tb_neg_mult", "g_overflow", "0",
        "lm_math_fi_mult rejects an out-of-domain overflow mode",
        ["lm_math_fi_mult: generic g_overflow = 0 is not a supported value", OVERFLOW_VALUES],
    ),
    subtype_case("tb_neg_mult", "g_pipe_stages", "-1", "a negative pipeline depth is not a configuration"),
    subtype_case("tb_neg_mult", "g_din_a_w", "0", "a zero-width input is not a configuration"),
    subtype_case("tb_neg_mult", "g_din_b_w", "0", "a zero-width input is not a configuration"),
    subtype_case("tb_neg_mult", "g_dout_w", "0", "a zero-width output is not a configuration"),
    # --- lm_math_fi_mult_add ------------------------------------------------
    assertion_case(
        "tb_neg_mult_add", "g_add_sub", "2",
        "lm_math_fi_mult_add rejects C_LM_ADDSUB, which it does not implement",
        ["lm_math_fi_mult_add: generic g_add_sub = 2 is not a supported value",
         "use lm_math_fi_add_sub with g_direction = C_LM_ADDSUB"],
    ),
    assertion_case(
        "tb_neg_mult_add", "g_representation", "0",
        "lm_math_fi_mult_add rejects a representation that selects no arithmetic branch",
        ["lm_math_fi_mult_add: generic g_representation = 0 is not a supported value",
         REPRESENTATION_VALUES],
    ),
    assertion_case(
        "tb_neg_mult_add", "g_round_mode", "42",
        "lm_math_fi_mult_add rejects an out-of-domain rounding mode",
        ["lm_math_fi_mult_add: generic g_round_mode = 42 is not a supported value", ROUND_LAST],
    ),
    assertion_case(
        "tb_neg_mult_add", "g_overflow", "0",
        "lm_math_fi_mult_add rejects an out-of-domain overflow mode",
        ["lm_math_fi_mult_add: generic g_overflow = 0 is not a supported value", OVERFLOW_VALUES],
    ),
    subtype_case("tb_neg_mult_add", "g_pipe_stages", "-1", "a negative pipeline depth is not a configuration"),
    subtype_case("tb_neg_mult_add", "g_din_a_w", "0", "a zero-width input is not a configuration"),
    subtype_case("tb_neg_mult_add", "g_din_b_w", "0", "a zero-width input is not a configuration"),
    subtype_case("tb_neg_mult_add", "g_din_c_w", "0", "a zero-width addend is not a configuration"),
    subtype_case("tb_neg_mult_add", "g_dout_w", "0", "a zero-width output is not a configuration"),
]

# Text that must NOT appear in a defaults run. If it does, a default is illegal
# and every case on that testbench would be untrustworthy.
DIAGNOSTIC_SIGNATURES = [
    "is not a supported value",
    "not in range for generic",
    "bound check failure",
]


def squash(text: str) -> str:
    """Collapse whitespace so a wrapped diagnostic still matches."""
    return re.sub(r"\s+", " ", text)


def run(cmd: list[str], *, echo: bool = True) -> subprocess.CompletedProcess[str]:
    if echo:
        print("+ " + " ".join(cmd), flush=True)
    return subprocess.run(
        cmd,
        cwd=BUILD,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )


def ghdl_common(ghdl: str, verb: str) -> list[str]:
    return [ghdl, verb, "--std=08", "--work=lm_math_fi_lib", f"--workdir={BUILD}", f"-P{BUILD}"]


def check_interface_declarations() -> list[str]:
    """Pin the subtype each entity declares for its range-constrained generics.

    The SUBTYPE negative cases below are rejected at the testbench's own mirror
    of the generic, so on their own they would still pass if an entity's
    declaration were widened. This closes that gap.
    """
    errors: list[str] = []
    for rel, generic, subtype in INTERFACE_DECLARATIONS:
        path = ROOT / rel
        try:
            text = path.read_text(encoding="utf-8")
        except OSError as exc:
            errors.append(f"{rel}: cannot read ({exc})")
            continue
        pattern = re.compile(
            r"^\s*" + re.escape(generic) + r"\s*:\s*(.+?)\s*(?::=|;|$)", re.M
        )
        match = pattern.search(text)
        if match is None:
            errors.append(f"{rel}: no declaration found for generic {generic}")
            continue
        found = squash(match.group(1)).strip()
        if found != subtype:
            errors.append(
                f"{rel}: generic {generic} is declared '{found}', expected '{subtype}'"
            )
    return errors


def analyze(ghdl: str) -> tuple[bool, str]:
    BUILD.mkdir(parents=True, exist_ok=True)
    for src in SRC_FILES:
        result = run(ghdl_common(ghdl, "-a")[:-1] + [str(ROOT / src)])
        if result.returncode != 0:
            sys.stdout.write(result.stdout or "")
            return False, f"source analysis failed: {src}"

    for unit in POSITIVE_UNITS + NEGATIVE_UNITS:
        path = GATE_DIR / f"{unit}.vhd"
        if not path.is_file():
            return False, f"missing gate testbench {path.relative_to(ROOT).as_posix()}"
        result = run(ghdl_common(ghdl, "-a") + [str(path)])
        if result.returncode != 0:
            sys.stdout.write(result.stdout or "")
            return False, f"gate testbench analysis failed: {unit}"
    return True, "analysis passed"


def elaborate(ghdl: str) -> tuple[bool, str]:
    for unit in POSITIVE_UNITS + NEGATIVE_UNITS:
        result = run(ghdl_common(ghdl, "-e") + [unit])
        if result.returncode != 0:
            sys.stdout.write(result.stdout or "")
            return False, f"elaboration failed: {unit}"
    return True, "elaboration passed"


def simulate(ghdl: str, unit: str, stop_time: str, overrides: list[str] | None = None):
    cmd = ghdl_common(ghdl, "-r") + [unit]
    if overrides:
        cmd += overrides
    cmd += ["--assert-level=error", f"--stop-time={stop_time}"]
    return run(cmd, echo=False)


def check_positive_unit(ghdl: str, unit: str, stop_time: str) -> tuple[bool, str]:
    result = simulate(ghdl, unit, stop_time)
    output = result.stdout or ""
    if result.returncode != 0:
        return False, "simulation failed\n--- output ---\n" + output.rstrip()
    if PASS_MARKER not in output:
        return False, "missing TEST PASSED marker\n--- output ---\n" + output.rstrip()
    summary = next((ln for ln in output.splitlines() if PASS_MARKER in ln), "")
    return True, summary.split("):", 1)[-1].strip() or "passed"


def check_defaults_legal(ghdl: str, unit: str, stop_time: str) -> tuple[bool, str]:
    result = simulate(ghdl, unit, stop_time)
    output = result.stdout or ""
    if result.returncode != 0:
        return False, (
            "running with no override failed, so at least one default is illegal"
            "\n--- output ---\n" + output.rstrip()
        )
    if COMPLETION_MARKER not in output:
        return False, (
            "running with no override did not reach the completion marker"
            "\n--- output ---\n" + output.rstrip()
        )
    hit = [s for s in DIAGNOSTIC_SIGNATURES if s in output]
    if hit:
        return False, (
            "a generic-domain diagnostic fired on the defaults: "
            + "; ".join(repr(s) for s in hit)
            + "\n--- output ---\n" + output.rstrip()
        )
    return True, "all defaults legal"


def check_case(ghdl: str, case: Case, stop_time: str) -> tuple[bool, str]:
    result = simulate(ghdl, case.unit, stop_time, [f"-g{case.generic}={case.value}"])
    output = result.stdout or ""

    if COMPLETION_MARKER in output:
        return False, (
            "the design ran to completion instead of being rejected"
            "\n--- output ---\n" + output.rstrip()
        )
    if result.returncode == 0:
        return False, (
            "simulation succeeded but the case must fail"
            "\n--- output ---\n" + output.rstrip()
        )

    haystack = squash(output)
    absent = [text for text in case.expect if squash(text) not in haystack]
    if absent:
        return False, (
            "failed for the wrong reason; expected text not found: "
            + "; ".join(repr(text) for text in absent)
            + "\n--- output ---\n" + output.rstrip()
        )
    if case.kind == KIND_SUBTYPE:
        return True, "rejected by the generic's subtype, diagnostic names the generic"
    return True, "rejected by an assertion carrying the expected diagnostic"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ghdl", default="ghdl", help="GHDL executable")
    parser.add_argument(
        "--stop-time",
        default="1us",
        help="Simulation stop time; testbenches end well before it",
    )
    parser.add_argument(
        "--keep-build",
        action="store_true",
        help="Keep build/ghdl_generic_domain instead of starting from a clean work library",
    )
    args = parser.parse_args()

    if shutil.which(args.ghdl) is None:
        print(f"error: '{args.ghdl}' was not found on PATH", file=sys.stderr)
        return 127

    if BUILD.exists() and not args.keep_build:
        shutil.rmtree(BUILD)
    BUILD.mkdir(parents=True, exist_ok=True)

    failures: list[tuple[str, str]] = []

    print("=" * 72)
    print("Interface declarations")
    print("=" * 72)
    decl_errors = check_interface_declarations()
    for error in decl_errors:
        failures.append(("interface declaration", error))
        print(f"  FAIL {error}")
    if not decl_errors:
        print(f"  ok: {len(INTERFACE_DECLARATIONS)} range-constrained generics declared as expected")

    ok, reason = analyze(args.ghdl)
    if not ok:
        print(f"Generic-domain gate failed: {reason}")
        return 1

    # tb_quantize_vectors opens the vector file relative to the simulation
    # directory, so put a copy there.
    shutil.copyfile(GATE_DIR / VECTOR_FILE, BUILD / VECTOR_FILE)

    ok, reason = elaborate(args.ghdl)
    if not ok:
        print(f"Generic-domain gate failed: {reason}")
        return 1

    print("=" * 72)
    print("Positive gate: legal values must be accepted")
    print("=" * 72)
    for unit in POSITIVE_UNITS:
        ok, reason = check_positive_unit(args.ghdl, unit, args.stop_time)
        print(f"  {'ok  ' if ok else 'FAIL'} {unit}: {reason}")
        if not ok:
            failures.append((unit, reason))

    for unit in NEGATIVE_UNITS:
        ok, reason = check_defaults_legal(args.ghdl, unit, args.stop_time)
        print(f"  {'ok  ' if ok else 'FAIL'} {unit} defaults: {reason}")
        if not ok:
            failures.append((f"{unit} defaults", reason))

    print("=" * 72)
    print("Negative gate: illegal values must be rejected")
    print("=" * 72)
    for case in CASES:
        ok, reason = check_case(args.ghdl, case, args.stop_time)
        print(f"  {'ok  ' if ok else 'FAIL'} {case.name} [{case.kind}]: {reason}")
        if not ok:
            failures.append((case.name, reason))

    if failures:
        print()
        print("Generic-domain gate failed:")
        for name, reason in failures:
            print(f"  - {name}: {reason}")
        return 1

    n_assert = sum(1 for c in CASES if c.kind == KIND_ASSERTION)
    n_subtype = sum(1 for c in CASES if c.kind == KIND_SUBTYPE)
    print()
    print(
        f"Generic-domain gate passed: {len(POSITIVE_UNITS)} positive testbenches, "
        f"{len(NEGATIVE_UNITS)} default-legality checks, "
        f"{len(CASES)} negative cases ({n_assert} by assertion, {n_subtype} by subtype), "
        f"{len(INTERFACE_DECLARATIONS)} interface declarations."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
