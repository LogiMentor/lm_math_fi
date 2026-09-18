#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 LogiMentor

"""Check that the generic-domain gate actually fails when it should.

A gate that cannot fail is not a gate. This script breaks the repository in a
known way, runs the gate, and requires it to fail FOR THE STATED REASON - then
puts everything back.

A mutation counts as caught only when the check it targets is the one that
failed, identified by name, and the diagnostic that check produced says what the
mutation declares it should say. A gate that fell over before reaching that check
is reported as an infrastructure failure, never as a detection: a Python
traceback or a missing build is not evidence that a gate works.

  python scripts/check_gate_mutations.py          run them all
  python scripts/check_gate_mutations.py --list   name them without running

SCOPE. The gates catch accidental regression. They do not claim to resist
deliberate tampering, and no mutation here edits a testbench so that it
misreports. See the verification strategy note in docs/VERIFICATION.md.

This is deliberately not run on every push: it edits tracked files while it runs.
CI runs it on pull requests. It refuses to start unless the working tree is
clean, and restores every file it touched even if a mutation fails or raises.
"""

from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
import time
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
GATE = ROOT / "scripts" / "run_ghdl_generic_domain_tests.py"
GENERATOR = ROOT / "scripts" / "gen_format_vectors.py"
BUILD = ROOT / "build" / "gate_mutations"
WORKDIR = ROOT / "build" / "ghdl_generic_domain"

RUNNER = "scripts/run_ghdl_generic_domain_tests.py"
GEN = "scripts/gen_format_vectors.py"
TB_DELAY = "sim/generic_domain/tb_neg_delay.vhd"
TB_FORMAT = "sim/generic_domain/tb_neg_format.vhd"
SRC_DELAY = "src/lm_math_fi_delay.vhd"
SRC_ADD_SUB = "src/lm_math_fi_add_sub.vhd"
SRC_MULT_ADD = "src/lm_math_fi_mult_add.vhd"
VECTORS = "sim/generic_domain/f_lm_quantize_vectors.txt"

TOUCHED = [RUNNER, GEN, TB_DELAY, TB_FORMAT, SRC_DELAY, SRC_ADD_SUB,
           SRC_MULT_ADD, VECTORS]

# Text that means the harness itself, or the environment, went wrong - never a
# detection.
INFRASTRUCTURE_SIGNS = [
    "Traceback (most recent call last)",
    "was not found on PATH",
    "SyntaxError",
]


def _edit(rel: str, old: str, new: str, *, count: int = 1) -> None:
    path = ROOT / rel
    text = path.read_text(encoding="utf-8")
    found = text.count(old)
    if found != count:
        raise SystemExit(
            f"mutation cannot be applied: expected {count} occurrence(s) of\n"
            f"  {old[:100]!r}\nin {rel}, found {found}. The file has moved on; "
            "update the mutation."
        )
    path.write_text(text.replace(old, new), encoding="utf-8", newline="\n")


# ---------------------------------------------------------------------------
# Mutations run through the whole gate
# ---------------------------------------------------------------------------

def m1_wrong_expected_text() -> None:
    _edit(RUNNER,
          '"lm_math_fi_mult_add: generic g_add_sub = 2 is not a supported value"',
          '"lm_math_fi_mult_add: generic g_add_sub = 2 is perfectly acceptable"')


def m2_illegal_default() -> None:
    _edit(TB_FORMAT,
          "    g_overflow       : natural  := C_LM_WRAP;",
          "    g_overflow       : natural  := 0;")


def m3_widened_entity_generic() -> None:
    _edit(SRC_DELAY,
          "    g_data_w : positive := 1",
          "    g_data_w : natural  := 1")


def m4_mult_add_constants() -> None:
    _edit(SRC_MULT_ADD,
          "  constant C_MULT_INT_W   : integer := C_MULT_WIDTH - C_MULT_BINPNT;",
          "  constant C_MULT_INT_W   : natural := C_MULT_WIDTH - C_MULT_BINPNT;")
    _edit(SRC_MULT_ADD,
          "  constant C_ADDEND_INT_W : integer := g_din_c_w - g_din_c_binpnt;",
          "  constant C_ADDEND_INT_W : natural := g_din_c_w - g_din_c_binpnt;")


def m5_unrelated_failure_named_after_the_generic() -> None:
    """Widen the testbench boundary so the override is accepted there, decouple
    it from the module so elaboration succeeds, and fail at 1 ns for a reason
    that has nothing to do with the generic. Targets the phase check."""
    _edit(TB_DELAY, "    g_data_w : positive := 4", "    g_data_w : natural  := 4")
    _edit(TB_DELAY,
          "generic map(g_delay => g_delay, g_data_w => g_data_w)",
          "generic map(g_delay => g_delay, g_data_w => 4)")
    _edit(TB_DELAY,
          "  signal s_din  : std_logic_vector(g_data_w - 1 downto 0) := (others => '0');\n"
          "  signal s_dout : std_logic_vector(g_data_w - 1 downto 0);",
          "  signal s_din  : std_logic_vector(3 downto 0) := (others => '0');\n"
          "  signal s_dout : std_logic_vector(3 downto 0);")
    _edit(TB_DELAY, "  proc_guard : process",
          "  proc_watchdog : process\n"
          "  begin\n"
          "    if g_data_w = 0 then\n"
          "      wait for 1 ns;\n"
          '      assert false report "an unrelated failure" severity failure;\n'
          "    end if;\n"
          "    wait;\n"
          "  end process proc_watchdog;\n\n"
          "  proc_guard : process")


def m6_hand_edited_expectation() -> None:
    path = ROOT / VECTORS
    lines = path.read_text(encoding="utf-8").splitlines()
    for index, line in enumerate(lines):
        if line and not line.startswith("#"):
            fields = line.split()
            fields[-1] = str(int(fields[-1]) ^ 1)
            lines[index] = " ".join(fields)
            break
    path.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")


def m7_assertion_moves_to_a_sub_entity() -> None:
    """Neuter lm_math_fi_add_sub's own g_round_mode assertion so the identical
    check inside the lm_math_fi_format instance it contains fires instead.

    The run still fails at time zero, still on an out-of-domain g_round_mode.
    Only source-location attribution can see that the entity under test stopped
    validating and a sub-entity picked up the slack. The assertion is left in
    place with its message intact, so it is still locatable - the case fails
    because the failure came from somewhere else, not because the target
    vanished.
    """
    _edit(SRC_ADD_SUB,
          "  assert f_lm_valid_round_mode(g_round_mode)\n"
          "    report \"lm_math_fi_add_sub: generic g_round_mode = \"",
          "  assert true  -- mutation: this entity no longer validates\n"
          "    report \"lm_math_fi_add_sub: generic g_round_mode = \"")


def m8_corrupt_one_reference() -> None:
    """Corrupt saturation in reference B only. Both references must compute the
    whole path, so this has to surface as a disagreement rather than as two
    pipelines quietly sharing a broken helper."""
    _edit(GEN,
          "        if ovf == SATURATE:\n"
          "            if value < low:\n"
          "                return low\n"
          "            if value > high:\n"
          "                return high\n"
          "            return value",
          "        if ovf == SATURATE:\n"
          "            if value < low:\n"
          "                return low\n"
          "            if value > high:\n"
          "                return high - 1\n"
          "            return value")


GATE_MUTATIONS = [
    ("M1", "runner expects assertion text the library never emits",
     m1_wrong_expected_text,
     "tb_neg_mult_add[g_add_sub=2]", "message no longer contains"),
    ("M2", "a negative testbench default is itself illegal",
     m2_illegal_default,
     "tb_neg_format defaults", "at least one default is illegal"),
    ("M3", "an entity generic is widened back to natural",
     m3_widened_entity_generic,
     "src/lm_math_fi_delay.vhd", "is declared 'natural', expected 'positive'"),
    # The reason a mutation must report has to be text this repository owns.
    # M4's was the simulator's phrase for a failed bound check, and neither that
    # phrase nor the file it names survives the move from GHDL 6.0.0 to 4.1.0.
    # It is matched on the runner's own verdict for the testbench instead. The
    # baseline run has to pass before any mutation is applied, so a testbench
    # that fails to simulate at all is attributable to the mutation.
    ("M4", "the two mult_add bit-count constants go back to natural",
     m4_mult_add_constants,
     "tb_legal_sweep", "simulation failed"),
    ("M5", "review round 1: boundary widened, unrelated failure at 1 ns",
     m5_unrelated_failure_named_after_the_generic,
     "tb_neg_delay[g_data_w=0]", "wrong phase"),
    ("M6", "one committed expectation is edited by hand",
     m6_hand_edited_expectation,
     GEN, "does not match the generator"),
    ("M7", "an entity stops validating and its sub-entity's assertion fires instead",
     m7_assertion_moves_to_a_sub_entity,
     "tb_neg_add_sub[g_round_mode=42]", "not from the assertion this case targets"),
    ("M8", "saturation corrupted in one reference only",
     m8_corrupt_one_reference,
     GEN, "references disagree"),
]


# ---------------------------------------------------------------------------
# Vector-file mutations, handed straight to the bench
# ---------------------------------------------------------------------------
# Run through the whole gate these would be caught by the provenance step before
# the bench ever saw them, so they go straight to the bench - which is the thing
# whose coverage protection they test.

def _split(text):
    head = [l for l in text.splitlines() if l.startswith("#")]
    rows = [l for l in text.splitlines() if l and not l.startswith("#")]
    return head, rows


def _remanifest(rows):
    """Rebuild a manifest that is exactly consistent with the rows given, the way
    a regenerated reduction would be."""
    per = {}
    order = []
    for row in rows:
        f = row.split()
        key = (f[0], f[1], f[3], f[4])
        if key not in per:
            per[key] = 0
            order.append(key)
        per[key] += 1
    head = [f"#! 0 {len(rows)}"]
    for key in order:
        head.append(f"#! 1 {key[0]} {key[1]} {key[2]} {key[3]} {per[key]}")
    return head


def v_truncate(text: str) -> str:
    head, rows = _split(text)
    return "\n".join(head + rows[:1]) + "\n"


def v_drop_degenerate(text: str) -> str:
    _head, rows = _split(text)
    base = [r for r in rows if tuple(r.split()[i] for i in (0, 1, 3, 4)) == ("6", "2", "4", "1")]
    dropped = len(rows) - len(base)
    padded = base + [base[0]] * dropped
    prose = [l for l in text.splitlines() if l.startswith("#") and not l.startswith("#!")]
    manifest = [l for l in text.splitlines() if l.startswith("#!")]
    return "\n".join(prose + manifest + padded) + "\n"


def v_strip_manifest(text: str) -> str:
    return "\n".join(l for l in text.splitlines() if not l.startswith("#!")) + "\n"


def v_zero_input_only(text: str) -> str:
    """Review round 2: regenerate enumerating only the zero input. Every geometry
    is still declared and every per-geometry count still matches its rows."""
    prose = [l for l in text.splitlines() if l.startswith("#") and not l.startswith("#!")]
    _head, rows = _split(text)
    kept = [r for r in rows if r.split()[8] == "0"]
    return "\n".join(prose + _remanifest(kept) + kept) + "\n"


def v_zero_input_padded(text: str) -> str:
    """Review round 2: the same reduction, padded back to the original row count
    per geometry, so the totals and per-geometry counts are untouched."""
    prose = [l for l in text.splitlines() if l.startswith("#") and not l.startswith("#!")]
    _head, rows = _split(text)
    by_geom = {}
    order = []
    for row in rows:
        f = row.split()
        key = (f[0], f[1], f[3], f[4])
        if key not in by_geom:
            by_geom[key] = {"all": [], "zero": []}
            order.append(key)
        by_geom[key]["all"].append(row)
        if f[8] == "0":
            by_geom[key]["zero"].append(row)
    out = []
    for key in order:
        zero = by_geom[key]["zero"]
        want = len(by_geom[key]["all"])
        padded = (zero * ((want // len(zero)) + 1))[:want]
        out += padded
    return "\n".join(prose + _remanifest(out) + out) + "\n"


VECTOR_MUTATIONS = [
    ("V1", "vector file truncated to a single data row", v_truncate,
     "the vector file has been truncated or padded"),
    ("V2", "every degenerate-format vector dropped, total padded back",
     v_drop_degenerate,
     "do not carry the number of rows the manifest declares"),
    ("V3", "the manifest directives are removed", v_strip_manifest,
     "missing its manifest"),
    ("V4", "review round 2: regenerated enumerating only the zero input",
     v_zero_input_only,
     "do not enumerate their whole input space"),
    ("V5", "review round 2: zero input padded back to the original row counts",
     v_zero_input_padded,
     "do not enumerate their whole input space"),
]


# ---------------------------------------------------------------------------

def tree_is_clean() -> bool:
    out = subprocess.run(["git", "status", "--porcelain"], cwd=ROOT,
                         capture_output=True, text=True).stdout.strip()
    return out == ""


def restore() -> None:
    subprocess.run(["git", "checkout", "--"] + TOUCHED, cwd=ROOT,
                   capture_output=True, text=True)


def run_gate() -> tuple[int, str]:
    r = subprocess.run([sys.executable, str(GATE)], cwd=ROOT,
                       capture_output=True, text=True)
    return r.returncode, (r.stdout or "") + (r.stderr or "")


def run_vector_bench(ghdl: str, vector_path: Path) -> tuple[int, str]:
    r = subprocess.run(
        [ghdl, "-r", "--std=08", "--work=lm_math_fi_lib", f"--workdir={WORKDIR}",
         f"-P{WORKDIR}", "tb_quantize_vectors",
         f"-gg_vector_file={vector_path.name}",
         "--assert-level=error", "--stop-time=1us"],
        cwd=WORKDIR, capture_output=True, text=True,
    )
    return r.returncode, (r.stdout or "") + (r.stderr or "")


def infrastructure_problem(output: str) -> str | None:
    for sign in INFRASTRUCTURE_SIGNS:
        if sign in output:
            return sign
    return None


def judge_gate(rc: int, out: str, expect_test: str, expect_reason: str):
    """Caught, not caught, or the harness itself fell over."""
    sign = infrastructure_problem(out)
    if sign is not None:
        return "INFRA", f"the gate did not run cleanly ({sign!r})"
    if rc == 0:
        return "MISSED", "the gate passed; the mutation went undetected"
    # The failing line has to be the check this mutation targets, and it has to
    # say what the mutation declares.
    for line in out.splitlines():
        if expect_test in line and expect_reason in line:
            return "CAUGHT", line.strip()
    for line in out.splitlines():
        if expect_test in line and line.strip().startswith(("FAIL", "-")):
            return "WRONG", (f"{expect_test} failed, but not with "
                             f"{expect_reason!r}: {line.strip()[:160]}")
    # Nothing matched. Show what the gate did say, so a mismatch is diagnosable
    # from a CI log without another round-trip.
    said = [l.strip() for l in out.splitlines()
            if l.strip().startswith(("FAIL", "  - ")) or "error:" in l][:6]
    return "WRONG", (f"the gate failed, but {expect_test} did not fail with "
                     f"{expect_reason!r}. The gate reported: "
                     + " | ".join(said) if said else
                     f"the gate failed, but {expect_test} did not fail with "
                     f"{expect_reason!r}, and reported nothing recognisable")


def judge_bench(rc: int, out: str, expect_reason: str):
    sign = infrastructure_problem(out)
    if sign is not None:
        return "INFRA", f"the bench did not run cleanly ({sign!r})"
    if rc == 0:
        return "MISSED", "the bench passed; the mutation went undetected"
    for line in out.splitlines():
        if expect_reason in line:
            return "CAUGHT", line.strip()[:170]
    return "WRONG", f"the bench failed, but not with {expect_reason!r}"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--list", action="store_true", help="Name the mutations and exit.")
    parser.add_argument("--ghdl", default="ghdl", help="GHDL executable")
    args = parser.parse_args()

    if args.list:
        for tag, note, _fn, test, reason in GATE_MUTATIONS:
            print(f"  {tag}  {note}\n        {test} must report {reason!r}")
        for tag, note, _fn, reason in VECTOR_MUTATIONS:
            print(f"  {tag}  {note}\n        tb_quantize_vectors must report {reason!r}")
        return 0

    if not tree_is_clean():
        print("error: the working tree has uncommitted changes. This script edits "
              "tracked files and restores them with 'git checkout --', which would "
              "discard your work. Commit or stash first.", file=sys.stderr)
        return 2

    started = time.monotonic()
    results = []

    print("=" * 78)
    print("Baseline: the gate must pass before anything is broken")
    print("=" * 78)
    rc, out = run_gate()
    if rc != 0:
        print("error: the gate does not pass on an unmodified tree; fix that first",
              file=sys.stderr)
        print(out[-2000:], file=sys.stderr)
        return 1
    baseline = time.monotonic() - started
    print(f"  ok: gate passes ({baseline:.0f}s)")

    for tag, note, mutate, expect_test, expect_reason in GATE_MUTATIONS:
        print("=" * 78)
        print(f"{tag}: {note}")
        print("=" * 78)
        try:
            mutate()
            rc, out = run_gate()
        finally:
            restore()
        verdict, detail = judge_gate(rc, out, expect_test, expect_reason)
        results.append((tag, verdict, detail))
        print(f"  {verdict:6s} {detail[:170]}")

    BUILD.mkdir(parents=True, exist_ok=True)
    original = (ROOT / VECTORS).read_text(encoding="utf-8")
    for tag, note, transform, expect_reason in VECTOR_MUTATIONS:
        print("=" * 78)
        print(f"{tag}: {note}")
        print("=" * 78)
        mutated = WORKDIR / f"mutated_{tag}.txt"
        mutated.write_text(transform(original), encoding="utf-8", newline="\n")
        rc, out = run_vector_bench(args.ghdl, mutated)
        shutil.copyfile(mutated, BUILD / mutated.name)
        mutated.unlink(missing_ok=True)
        verdict, detail = judge_bench(rc, out, expect_reason)
        results.append((tag, verdict, detail))
        print(f"  {verdict:6s} {detail[:170]}")

    elapsed = time.monotonic() - started
    print("=" * 78)
    for tag, verdict, detail in results:
        print(f"  {verdict:6s} {tag}: {detail[:150]}")
    caught = [r for r in results if r[1] == "CAUGHT"]
    infra = [r for r in results if r[1] == "INFRA"]
    print()
    print(f"{len(caught)} of {len(results)} mutations caught, "
          f"{len(infra)} infrastructure failures, in {elapsed:.0f}s "
          f"(baseline gate run {baseline:.0f}s of that)")
    if not tree_is_clean():
        print("error: the working tree is not clean after restoring; check "
              "'git status'", file=sys.stderr)
        return 1
    return 0 if len(caught) == len(results) else 1


if __name__ == "__main__":
    raise SystemExit(main())
