#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 LogiMentor

"""Check that illegal generic values are rejected with the expected diagnostic.

Every unit under sim/negative/ is expected to FAIL. A case passes only when the
expected phase fails *and* the output contains the diagnostic text this script
names for it, so a case cannot pass because the design broke for an unrelated
reason. Every earlier phase must still succeed.

This runner is separate from scripts/run_ghdl_tests.py on purpose: that runner
greps for a TEST PASSED marker and treats a non-zero exit as a failure, so it
cannot express a test that is supposed to fail.
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
BUILD = ROOT / "build" / "ghdl_negative"
NEGATIVE_DIR = ROOT / "sim" / "negative"

SRC_FILES = [
    "src/lm_math_fi_pkg.vhd",
    "src/lm_math_fi_delay.vhd",
    "src/lm_math_fi_format.vhd",
    "src/lm_math_fi_add_sub.vhd",
    "src/lm_math_fi_mult.vhd",
    "src/lm_math_fi_mult_add.vhd",
]

# Phase in which the case must fail.
#   "analyse" - rejected by the generic's subtype, before any simulation.
#   "run"     - rejected by a concurrent assertion at time 0.
PHASE_ANALYSE = "analyse"
PHASE_RUN = "run"


@dataclass(frozen=True)
class NegativeCase:
    unit: str
    phase: str
    why: str
    expect: list[str] = field(default_factory=list)


CASES = [
    # --- lm_math_fi_pkg: the two former silent `when others` fallbacks --------
    NegativeCase(
        unit="tb_neg_pkg_round_mode",
        phase=PHASE_RUN,
        why="f_lm_quantize must reject a rounding mode that is not one of the nine constants",
        expect=[
            "lm_math_fi_pkg.f_lm_quantize: rounding mode 42 is not a supported value",
            "C_LM_TRUNC_BITS (0)",
            "C_LM_ROUND_AWAY (8)",
        ],
    ),
    NegativeCase(
        unit="tb_neg_pkg_overflow",
        phase=PHASE_RUN,
        why="f_lm_quantize must reject an overflow mode that is neither saturate nor wrap",
        expect=[
            "lm_math_fi_pkg.f_lm_quantize: overflow mode 0 is not a supported value",
            "C_LM_SATURATE (1) or C_LM_WRAP (2)",
        ],
    ),
    # --- lm_math_fi_format ---------------------------------------------------
    NegativeCase(
        unit="tb_neg_format_round_mode",
        phase=PHASE_RUN,
        why="lm_math_fi_format must reject an out-of-domain g_round_mode",
        expect=[
            "lm_math_fi_format: generic g_round_mode = 42 is not a supported value",
            "C_LM_ROUND_AWAY (8)",
        ],
    ),
    NegativeCase(
        unit="tb_neg_format_overflow",
        phase=PHASE_RUN,
        why="lm_math_fi_format must reject an out-of-domain g_overflow",
        expect=[
            "lm_math_fi_format: generic g_overflow = 0 is not a supported value",
            "C_LM_SATURATE (1) or C_LM_WRAP (2)",
        ],
    ),
    # --- lm_math_fi_add_sub --------------------------------------------------
    NegativeCase(
        unit="tb_neg_add_sub_representation",
        phase=PHASE_RUN,
        why="lm_math_fi_add_sub must reject a g_representation that selects no arithmetic branch",
        expect=[
            "lm_math_fi_add_sub: generic g_representation = 0 is not a supported value",
            "C_LM_UNSIGNED (1) or C_LM_SIGNED (2)",
        ],
    ),
    NegativeCase(
        unit="tb_neg_add_sub_direction",
        phase=PHASE_RUN,
        why="lm_math_fi_add_sub must reject an out-of-domain g_direction",
        expect=[
            "lm_math_fi_add_sub: generic g_direction = 7 is not a supported value",
            "C_LM_ADDSUB (2)",
        ],
    ),
    # --- lm_math_fi_mult -----------------------------------------------------
    NegativeCase(
        unit="tb_neg_mult_din_a_type",
        phase=PHASE_RUN,
        why="lm_math_fi_mult must reject an operand type that is neither signed nor unsigned",
        expect=[
            "lm_math_fi_mult: generic g_din_a_type = 0 is not a supported value",
            "C_LM_UNSIGNED (1) or C_LM_SIGNED (2)",
        ],
    ),
    NegativeCase(
        unit="tb_neg_mult_pipe_stages_negative",
        phase=PHASE_ANALYSE,
        why=(
            "a negative g_pipe_stages must be rejected by the natural subtype at analysis, "
            "with the diagnostic pointing at the caller's generic map"
        ),
        expect=[
            "static expression violates bounds",
            "tb_neg_mult_pipe_stages_negative.vhd",
        ],
    ),
    # --- lm_math_fi_mult_add -------------------------------------------------
    NegativeCase(
        unit="tb_neg_mult_add_addsub",
        phase=PHASE_RUN,
        why="lm_math_fi_mult_add must reject C_LM_ADDSUB, which it does not implement",
        expect=[
            "lm_math_fi_mult_add: generic g_add_sub = 2 is not a supported value",
            "use lm_math_fi_add_sub with g_direction = C_LM_ADDSUB",
        ],
    ),
    NegativeCase(
        unit="tb_neg_mult_add_representation",
        phase=PHASE_RUN,
        why="lm_math_fi_mult_add must reject an out-of-domain g_representation",
        expect=[
            "lm_math_fi_mult_add: generic g_representation = 0 is not a supported value",
            "C_LM_UNSIGNED (1) or C_LM_SIGNED (2)",
        ],
    ),
]

# A case that reaches this text ran to completion instead of being rejected.
GUARD_MARKER = "NEGATIVE TEST DID NOT FAIL"


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


def analyze_sources(ghdl: str) -> tuple[bool, str]:
    BUILD.mkdir(parents=True, exist_ok=True)
    for src in SRC_FILES:
        result = run(
            [
                ghdl,
                "-a",
                "--std=08",
                "--work=lm_math_fi_lib",
                f"--workdir={BUILD}",
                str(ROOT / src),
            ]
        )
        if result.returncode != 0:
            sys.stdout.write(result.stdout or "")
            return False, f"source analysis failed: {src}"
    return True, "source analysis passed"


def missing_fragments(case: NegativeCase, output: str) -> list[str]:
    haystack = squash(output)
    return [text for text in case.expect if squash(text) not in haystack]


def check_case(ghdl: str, case: NegativeCase, stop_time: str) -> tuple[bool, str]:
    tb_file = NEGATIVE_DIR / f"{case.unit}.vhd"
    if not tb_file.is_file():
        return False, f"missing negative testbench {tb_file.relative_to(ROOT).as_posix()}"

    analyze_cmd = [
        ghdl,
        "-a",
        "--std=08",
        "--work=lm_math_fi_lib",
        f"--workdir={BUILD}",
        f"-P{BUILD}",
    ]
    if case.phase == PHASE_ANALYSE:
        # Promote GHDL's static-bounds warning to an error so the out-of-subtype
        # generic is a hard analysis failure rather than a note.
        analyze_cmd.append("--warn-error")
    analyze_cmd.append(str(tb_file))

    result = run(analyze_cmd)
    output = result.stdout or ""

    if case.phase == PHASE_ANALYSE:
        if result.returncode == 0:
            return False, "analysis succeeded but the case must be rejected at analysis"
        absent = missing_fragments(case, output)
        if absent:
            return False, (
                "analysis failed for the wrong reason; expected text not found: "
                + "; ".join(repr(text) for text in absent)
                + "\n--- analysis output ---\n"
                + output.rstrip()
            )
        return True, "rejected at analysis with the expected diagnostic"

    if result.returncode != 0:
        return False, (
            "analysis failed, but this case must analyse cleanly and fail at run time"
            "\n--- analysis output ---\n" + output.rstrip()
        )

    result = run(
        [
            ghdl,
            "-e",
            "--std=08",
            "--work=lm_math_fi_lib",
            f"--workdir={BUILD}",
            f"-P{BUILD}",
            case.unit,
        ]
    )
    if result.returncode != 0:
        return False, (
            "elaboration failed, but this case must elaborate and fail at run time"
            "\n--- elaboration output ---\n" + (result.stdout or "").rstrip()
        )

    result = run(
        [
            ghdl,
            "-r",
            "--std=08",
            "--work=lm_math_fi_lib",
            f"--workdir={BUILD}",
            f"-P{BUILD}",
            case.unit,
            "--assert-level=error",
            f"--stop-time={stop_time}",
        ]
    )
    output = result.stdout or ""

    if GUARD_MARKER in output:
        return False, (
            "the design ran to completion instead of being rejected"
            "\n--- simulation output ---\n" + output.rstrip()
        )
    if result.returncode == 0:
        return False, (
            "simulation succeeded but the case must fail"
            "\n--- simulation output ---\n" + output.rstrip()
        )

    absent = missing_fragments(case, output)
    if absent:
        return False, (
            "simulation failed for the wrong reason; expected text not found: "
            + "; ".join(repr(text) for text in absent)
            + "\n--- simulation output ---\n"
            + output.rstrip()
        )
    return True, "rejected at run time with the expected diagnostic"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ghdl", default="ghdl", help="GHDL executable")
    parser.add_argument(
        "--stop-time",
        default="1us",
        help="Simulation stop time; a case that reaches it has already failed its guard",
    )
    parser.add_argument(
        "--keep-build",
        action="store_true",
        help="Keep build/ghdl_negative instead of starting from a clean work library",
    )
    args = parser.parse_args()

    if shutil.which(args.ghdl) is None:
        print(f"error: '{args.ghdl}' was not found on PATH", file=sys.stderr)
        return 127

    if BUILD.exists() and not args.keep_build:
        shutil.rmtree(BUILD)

    ok, reason = analyze_sources(args.ghdl)
    if not ok:
        print(f"GHDL negative regression failed: {reason}")
        return 1

    failed: list[tuple[str, str]] = []
    for case in CASES:
        print("=" * 72)
        print(f"Checking {case.unit}")
        print(f"  expects: {case.why}")
        print(f"  must fail at: {case.phase}")
        print("=" * 72)
        ok, reason = check_case(args.ghdl, case, args.stop_time)
        print(f"  -> {reason}")
        if not ok:
            failed.append((case.unit, reason))

    if failed:
        print("GHDL negative regression failed:")
        for unit, reason in failed:
            print(f"  - {unit}: {reason}")
        return 1

    print(
        f"GHDL negative regression passed: {len(CASES)} illegal configurations "
        "were each rejected with the expected diagnostic."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
