#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 LogiMentor

"""Gate the generic domains of the public entities, in both directions.

Provenance - the committed expectations must come from the committed generator:
  * scripts/gen_format_vectors.py is re-run and its output compared with the
    committed vector file and entity testbench, so neither can drift from the
    generator, and neither can quietly acquire a value the generator would not
    produce. That generator imports nothing from src/, model/ or js/.

Positive half - a legal value must never be rejected:
  * every entity is instantiated across the full legal cross-product of its
    discrete-domain generics and run past time 0, and no assertion may fire;
  * every entity is driven at degenerate binary points - equal to the width,
    above the width, bit weights disjoint either way, one bit of overlap, and
    width 1 - and the RESULT is checked, not only that it elaborates;
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
# Regenerates the committed expectations and fails if they have drifted from the
# generator that is supposed to produce them.
EXPECTATION_GENERATOR = "scripts/gen_format_vectors.py"

SRC_FILES = [
    "src/lm_math_fi_pkg.vhd",
    "src/lm_math_fi_delay.vhd",
    "src/lm_math_fi_format.vhd",
    "src/lm_math_fi_add_sub.vhd",
    "src/lm_math_fi_mult.vhd",
    "src/lm_math_fi_mult_add.vhd",
]

# Support packages the gate testbenches depend on, compiled before them.
SUPPORT_FILES = [
    "sim/tb/tb_lm_math_fi_test_pkg.vhd",
]

# Units elaborated once and then run many times with different -g overrides.
POSITIVE_UNITS = ["tb_legal_sweep", "tb_quantize_vectors", "tb_degenerate_formats"]

# Per-unit simulation window, for the units that need more than the default.
# tb_degenerate_formats walks its checks two clock edges apart and needs more
# room than the rest; the window below is an upper bound, not a measurement, and
# the bench reports how many checks it ran and at what time when it passes. No
# count or duration is written down here, because either would go stale silently.
# Five of the six negative benches run a free-running clock that is never
# stopped, so the window is what ends those runs - another reason to keep it
# tight for them.
UNIT_STOP_TIME = {
    "tb_degenerate_formats": "10us",
}
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
# Emitted by every negative testbench at the first simulation delta. Its absence
# is what proves a case was rejected before simulation started.
STARTED_MARKER = "GENERIC DOMAIN TB STARTED"
# Emitted by both positive testbenches on success.
PASS_MARKER = "TEST PASSED"

KIND_ASSERTION = "assertion"
KIND_SUBTYPE = "subtype"

# The phase in which a case must fail. Checked, not assumed.
#   elaboration - the design never elaborates, so simulation never starts. The
#                 testbench's STARTED marker must be absent and the simulator
#                 must have reported nothing against a source line.
#   time_zero   - the design elaborates and a concurrent assertion whose
#                 condition is made of generics alone fires during
#                 initialisation, at time zero, carrying our message.
PHASE_ELABORATION = "elaboration"
PHASE_TIME_ZERO = "time_zero"

# A source-located simulator diagnostic:
#   <file>:<line>:<col>:@<time><unit>:(assertion|report <severity>): <message>
# Parsed structurally so that a message can be matched WITHOUT matching an
# instance path, and so that the time of the failure is available.
DIAGNOSTIC_RE = re.compile(
    r"^(?P<file>.+?):(?P<line>\d+):(?P<col>\d+):"
    r"@(?P<time>\d+)(?P<unit>fs|ps|ns|us|ms|sec|min|hr):"
    r"\((?P<kind>assertion|report) (?P<severity>note|warning|error|failure)\):"
    r"\s*(?P<message>.*)$"
)
# Lines naming the instance a diagnostic came from. A generic's name can appear
# here purely because it is part of a process or instance label, so these lines
# are removed before any name match.
INSTANCE_RE = re.compile(r"^\s*instance:")

# The simulator names an out-of-subtype top-level generic by quoting it. Only
# the SHAPE is matched - an error diagnostic carrying a quoted identifier -
# together with the identifier itself. The surrounding wording is the
# simulator's and is not matched.
#
# THIS MATCHER DEPENDS ON THE SIMULATOR, and the two GHDL versions this
# repository is tested against already differ:
#   GHDL 6.0.0 (llvm)   value not in range for generic 'g_data_w'
#   GHDL 4.1.0 (mcode)  override for generic "g_data_w" is out of bounds
# Both quoting styles are accepted, because the quote character is part of the
# shape rather than of the wording. A tool that names the generic some other way
# would need its shape adding here.
QUOTED_GENERIC_RE = re.compile(
    r":error:[^\n]*?[\x22\x27](?P<generic>[A-Za-z_][A-Za-z_0-9]*)[\x22\x27]"
)

# Which source file holds the assertions each negative testbench can trip.
UNIT_SOURCE = {
    "tb_neg_format": "src/lm_math_fi_format.vhd",
    "tb_neg_add_sub": "src/lm_math_fi_add_sub.vhd",
    "tb_neg_mult": "src/lm_math_fi_mult.vhd",
    "tb_neg_mult_add": "src/lm_math_fi_mult_add.vhd",
    "tb_neg_pkg": "src/lm_math_fi_pkg.vhd",
}

# The package's two assertions are not about a generic, so they are anchored on
# what they are about instead.
PACKAGE_ANCHOR = {"g_round_mode": "rounding mode", "g_overflow": "overflow mode"}

# An assert statement and the report text that follows it, so each assertion can
# be located in the source and keyed by what it checks.
ASSERT_RE = re.compile(r"^\s*assert\b")
SEVERITY_RE = re.compile(r"^\s*severity\b")
ANCHOR_GENERIC_RE = re.compile(r"generic (?P<generic>g_[a-z_0-9]+)")


# ---------------------------------------------------------------------------
# Interface declarations: which generics carry their domain in their subtype.
# ---------------------------------------------------------------------------
# This is the record of a deliberate decision. Width and pipeline-depth domains
# are contiguous, self-evident numeric bounds, so they live in the subtype.
# Enumerations encoded as integers (rounding, overflow, representation, add/sub
# selector) do NOT get a range here: their admissible set can grow and is not
# contiguous in every case, and a range duplicated across entities would drift
# from the constants in lm_math_fi_pkg. Those keep their assertions.
# Which negative testbench mirrors the generics of each entity source. Every
# declaration below must have a negative case on the unit named here; the gate
# refuses to pass otherwise, so a declaration cannot be pinned without also
# being exercised.
NEGATIVE_UNIT = {
    "src/lm_math_fi_delay.vhd": "tb_neg_delay",
    "src/lm_math_fi_format.vhd": "tb_neg_format",
    "src/lm_math_fi_add_sub.vhd": "tb_neg_add_sub",
    "src/lm_math_fi_mult.vhd": "tb_neg_mult",
    "src/lm_math_fi_mult_add.vhd": "tb_neg_mult_add",
}

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
    phase: str
    why: str
    expect: list[str] = field(default_factory=list)

    @property
    def name(self) -> str:
        return f"{self.unit}[{self.generic}={self.value}]"


def assertion_case(unit, generic, value, why, expect):
    """Rejected by an assertion this repository wrote, at time zero."""
    return Case(unit, generic, value, KIND_ASSERTION, PHASE_TIME_ZERO, why, expect)


def subtype_case(unit, generic, value, why):
    """Rejected by the generic's own subtype, before simulation starts.

    The expected text is the generic's name and nothing else, because the rest
    of the wording is the simulator's and changes across versions. The name on
    its own is far too weak a signal, so check_case pairs it with the phase
    check: the testbench must never have started, and the simulator must not
    have reported anything against a source line.
    """
    return Case(unit, generic, value, KIND_SUBTYPE, PHASE_ELABORATION, why, [generic])


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
    subtype_case("tb_neg_format", "g_pipe_stages", "-1",
                 "a negative pipeline depth is not a configuration"),
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
    subtype_case("tb_neg_add_sub", "g_pipeline_output", "-1",
                 "a negative output pipeline depth is not a configuration"),
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


def locate_assertions(rel: str) -> dict[str, list[int]]:
    """Where the assertions in a source file are, keyed by what each checks.

    Derived from the source on every run, never written down. Move an assertion
    and the expected line moves with it; delete one, or change its message so it
    can no longer be keyed, and the case that needs it fails with a message
    saying the assertion could not be located - which is the right outcome,
    because the gate can no longer prove which assertion fired.

    EVERY line is recorded, not the first. Two assertions in one file keyed on
    the same thing are ambiguous: the gate cannot then say which of them a
    diagnostic came from, so it must refuse the case rather than pick one.
    """
    text = (ROOT / rel).read_text(encoding="utf-8")
    found: dict[str, list[int]] = {}
    lines = text.splitlines()
    index = 0
    while index < len(lines):
        if ASSERT_RE.match(lines[index]):
            start = index + 1                      # 1-based, as the simulator counts
            body = []
            scan = index
            while scan < len(lines) and not SEVERITY_RE.match(lines[scan]):
                body.append(lines[scan])
                scan += 1
            if scan < len(lines):
                body.append(lines[scan])
            joined = squash(" ".join(body))
            match = ANCHOR_GENERIC_RE.search(joined)
            if match:
                found.setdefault(match.group("generic"), []).append(start)
            else:
                for anchor in PACKAGE_ANCHOR.values():
                    if anchor in joined:
                        found.setdefault(anchor, []).append(start)
            index = scan + 1
        else:
            index += 1
    return found


def expected_assertion_site(case: "Case") -> tuple[str, int] | str:
    """The (source file, line) the case's own assertion lives at, or why not."""
    rel = UNIT_SOURCE.get(case.unit)
    if rel is None:
        return f"no source file is recorded for {case.unit}"
    anchor = PACKAGE_ANCHOR[case.generic] if case.unit == "tb_neg_pkg" else case.generic
    sites = locate_assertions(rel)
    lines = sites.get(anchor, [])
    if not lines:
        return (f"no assertion keyed on {anchor!r} could be located in {rel}; "
                "it has been deleted or its message no longer names what it checks")
    if len(lines) > 1:
        return (f"{len(lines)} assertions in {rel} are keyed on {anchor!r} "
                f"(lines {', '.join(str(n) for n in lines)}); the gate cannot prove "
                "which of them a diagnostic came from, so it will not accept any "
                "of them as evidence for this case")
    return rel, lines[0]


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
    errors.extend(check_every_declaration_is_exercised())
    return errors


def check_every_declaration_is_exercised() -> list[str]:
    """Every pinned declaration must have a negative case that exercises it.

    Pinning a subtype proves what the entity SAYS. Only a negative case proves
    the tool enforces it. Reporting a count of declarations while exercising
    fewer of them overstates what ran, so the gap is closed as a class here
    rather than case by case: add a declaration without a case and the gate
    fails until the case exists.
    """
    exercised = {(case.unit, case.generic) for case in CASES if case.kind == "subtype"}
    errors: list[str] = []
    for rel, generic, _subtype in INTERFACE_DECLARATIONS:
        unit = NEGATIVE_UNIT.get(rel)
        if unit is None:
            errors.append(
                f"{rel}: no negative testbench is recorded for this source, so the "
                f"declaration of {generic} is pinned but never exercised"
            )
            continue
        if (unit, generic) not in exercised:
            errors.append(
                f"{rel}: generic {generic} is pinned in INTERFACE_DECLARATIONS but "
                f"no subtype case on {unit} exercises it; a declaration that is "
                "never driven out of range proves only what the entity says"
            )
    return errors


def analyze(ghdl: str) -> tuple[bool, str]:
    BUILD.mkdir(parents=True, exist_ok=True)
    for src in SRC_FILES:
        result = run(ghdl_common(ghdl, "-a")[:-1] + [str(ROOT / src)])
        if result.returncode != 0:
            sys.stdout.write(result.stdout or "")
            return False, f"source analysis failed: {src}"

    for support in SUPPORT_FILES:
        result = run(ghdl_common(ghdl, "-a") + [str(ROOT / support)])
        if result.returncode != 0:
            sys.stdout.write(result.stdout or "")
            return False, f"support package analysis failed: {support}"

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
    window = UNIT_STOP_TIME.get(unit, stop_time)
    cmd += ["--assert-level=error", f"--stop-time={window}"]
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


def diagnostics(output: str) -> list[dict]:
    """Every source-located diagnostic the simulator printed."""
    out = []
    for line in output.splitlines():
        m = DIAGNOSTIC_RE.match(line.rstrip())
        if m:
            d = m.groupdict()
            d["at_time_zero"] = int(d["time"]) == 0
            out.append(d)
    return out


def without_instance_lines(output: str) -> str:
    """Drop the lines that name the instance a diagnostic came from.

    A generic's name can appear in one of these purely because it is part of a
    process or instance label, which says nothing about why the run failed.
    """
    return "\n".join(l for l in output.splitlines() if not INSTANCE_RE.match(l))


def plain_diagnostic_text(output: str) -> str:
    """What the simulator said, minus instance paths and minus anything it
    attributed to a source line. What is left is the simulator speaking about
    the design as a whole, which is where an out-of-subtype generic is named."""
    keep = []
    for line in output.splitlines():
        if INSTANCE_RE.match(line):
            continue
        if DIAGNOSTIC_RE.match(line.rstrip()):
            continue
        keep.append(line)
    return "\n".join(keep)


def same_source(reported: str, rel: str) -> bool:
    """Is the file the simulator named the repository file `rel`?

    The simulator prints whatever path it was handed, absolute or relative, with
    either separator, so compare on the normalised tail rather than on the text.
    """
    normalised = reported.replace("\\", "/")
    return normalised == rel or normalised.endswith("/" + rel)


def check_case(ghdl: str, case: Case, stop_time: str) -> tuple[bool, str]:
    result = simulate(ghdl, case.unit, stop_time, [f"-g{case.generic}={case.value}"])
    output = result.stdout or ""
    tail = "\n--- output ---\n" + output.rstrip()

    def wrong(reason):
        return False, reason + tail

    if COMPLETION_MARKER in output:
        return wrong("the design ran to completion instead of being rejected")
    if result.returncode == 0:
        return wrong("simulation succeeded but the case must fail")

    diags = diagnostics(output)

    if case.phase == PHASE_ELABORATION:
        # Phase, from the testbench's own marker and from the absence of
        # anything the simulator attributed to a source line.
        if STARTED_MARKER in output:
            return wrong(
                "wrong phase: this case must be rejected before simulation starts, "
                "but the testbench reported that it started"
            )
        if diags:
            first = diags[0]
            return wrong(
                "wrong phase: this case must be rejected before simulation starts, "
                f"but the simulator reported a {first['kind']} {first['severity']} "
                f"at {first['time']}{first['unit']} from {first['file']}:{first['line']}"
            )
        # Attribution. An elaboration failure is not evidence on its own - the
        # review showed an unrelated one satisfying that. The simulator has to
        # have named THIS generic, in a diagnostic shaped as one naming a
        # generic, outside any instance path.
        named = [
            m.group("generic")
            for m in QUOTED_GENERIC_RE.finditer(plain_diagnostic_text(output))
        ]
        if case.generic not in named:
            return wrong(
                "failed before simulation started, but no diagnostic names the "
                f"generic {case.generic!r}"
                + (f"; the generics named were {sorted(set(named))}" if named
                   else "; no diagnostic names any generic, so the failure cannot "
                        "be attributed to a generic's subtype at all")
            )
        return True, (
            f"rejected before simulation started, diagnostic names {case.generic}"
        )

    # PHASE_TIME_ZERO. The failure has to come from the one assertion this case
    # exists to exercise, identified by where it is in the source.
    site = expected_assertion_site(case)
    if isinstance(site, str):
        return wrong("cannot determine which assertion this case targets: " + site)
    rel, line = site

    failures = [d for d in diags if d["severity"] in ("error", "failure")]
    if not failures:
        return wrong(
            "wrong phase: this case must be rejected by an assertion during "
            "initialisation, but the simulator reported no assertion at all"
        )
    at_zero = [d for d in failures if d["at_time_zero"]]
    if not at_zero:
        first = failures[0]
        return wrong(
            "wrong phase: this case must be rejected at time zero, but the first "
            f"failure was at {first['time']}{first['unit']}"
        )
    located = [
        d for d in at_zero
        if same_source(d["file"], rel) and int(d["line"]) == line
    ]
    if not located:
        seen = ", ".join(
            f"{d['file'].replace(chr(92), '/').rsplit('/', 1)[-1]}:{d['line']}"
            for d in at_zero
        )
        return wrong(
            f"failed at time zero, but not from the assertion this case targets "
            f"({rel}:{line}, the one checking {case.generic}). The failure came "
            f"from {seen}. Another assertion, a testbench report, or the package "
            "does not satisfy this case however it is worded."
        )
    # Text, as an additional condition only. Location has already decided which
    # assertion fired; this catches an assertion whose message stopped matching
    # what it checks.
    messages = squash(" ".join(d["message"] for d in located))
    absent = [x for x in case.expect if squash(x) not in messages]
    if absent:
        return wrong(
            f"the assertion at {rel}:{line} fired, but its message no longer "
            "contains: " + "; ".join(repr(x) for x in absent)
        )
    return True, (
        f"rejected at time zero by the assertion at {rel}:{line}, "
        "with the expected diagnostic"
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ghdl", default="ghdl", help="GHDL executable")
    parser.add_argument(
        "--stop-time",
        default="1us",
        help=(
            "Default simulation window. tb_legal_sweep and tb_degenerate_formats "
            "stop their own clocks when they finish; the six negative benches do "
            "not, and five of them run a free-running clock, so this window is "
            "what ends those runs. Units needing more are listed in "
            "UNIT_STOP_TIME rather than raising this for everything."
        ),
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
    print("Expectation provenance")
    print("=" * 72)
    gen = subprocess.run(
        [sys.executable, str(ROOT / EXPECTATION_GENERATOR), "--check"],
        cwd=ROOT, text=True, capture_output=True,
    )
    gen_out = ((gen.stdout or "") + (gen.returncode and (gen.stderr or "") or "")).strip()
    if gen.returncode != 0:
        failures.append((EXPECTATION_GENERATOR, gen_out or "generator check failed"))
        print(f"  FAIL {gen_out}")
    else:
        print(f"  ok: {gen_out}")

    print("=" * 72)
    print("Interface declarations")
    print("=" * 72)
    decl_errors = check_interface_declarations()
    for error in decl_errors:
        failures.append(("interface declaration", error))
        print(f"  FAIL {error}")
    if not decl_errors:
        print(f"  ok: {len(INTERFACE_DECLARATIONS)} range-constrained generics declared as "
              f"expected, each exercised by a negative case")

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
