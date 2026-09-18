#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 LogiMentor

"""Check that the generic-domain gate actually fails when it should.

A gate that cannot fail is not a gate. This script breaks the repository in a
known way, runs the gate, and requires it to fail for the stated reason - then
puts everything back. Each mutation targets one thing the gate claims to catch,
so a claim in a review or a pull request can be re-derived here instead of taken
on trust.

  python scripts/check_gate_mutations.py          run them all
  python scripts/check_gate_mutations.py --list   name them without running

This is deliberately NOT part of CI: it edits tracked files while it runs. It
refuses to start unless the working tree is clean, and restores every file it
touched even if a mutation fails or raises.
"""

from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
GATE = "scripts/run_ghdl_generic_domain_tests.py"
BUILD = ROOT / "build" / "gate_mutations"

RUNNER = "scripts/run_ghdl_generic_domain_tests.py"
TB_DELAY = "sim/generic_domain/tb_neg_delay.vhd"
TB_FORMAT = "sim/generic_domain/tb_neg_format.vhd"
SRC_DELAY = "src/lm_math_fi_delay.vhd"
SRC_MULT_ADD = "src/lm_math_fi_mult_add.vhd"
VECTORS = "sim/generic_domain/f_lm_quantize_vectors.txt"


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
# The mutations
# ---------------------------------------------------------------------------

def m1_wrong_expected_text() -> None:
    """The runner expects assertion text the library never emits."""
    _edit(RUNNER,
          '"lm_math_fi_mult_add: generic g_add_sub = 2 is not a supported value"',
          '"lm_math_fi_mult_add: generic g_add_sub = 2 is perfectly acceptable"')


def m2_illegal_default() -> None:
    """A negative testbench's default is itself an illegal value."""
    _edit(TB_FORMAT,
          "    g_overflow       : natural  := C_LM_WRAP;",
          "    g_overflow       : natural  := 0;")


def m3_widened_entity_generic() -> None:
    """An entity's range-constrained generic is widened back."""
    _edit(SRC_DELAY,
          "    g_data_w : positive := 1",
          "    g_data_w : natural  := 1")


def m4_mult_add_constants() -> None:
    """The two mult_add bit-count constants go back to natural."""
    _edit(SRC_MULT_ADD,
          "  constant C_MULT_INT_W   : integer := C_MULT_WIDTH - C_MULT_BINPNT;",
          "  constant C_MULT_INT_W   : natural := C_MULT_WIDTH - C_MULT_BINPNT;")
    _edit(SRC_MULT_ADD,
          "  constant C_ADDEND_INT_W : integer := g_din_c_w - g_din_c_binpnt;",
          "  constant C_ADDEND_INT_W : natural := g_din_c_w - g_din_c_binpnt;")


def m5_unrelated_failure_named_after_the_generic() -> None:
    """The review's mutation.

    Widen the testbench boundary so the override is accepted there, decouple it
    from the module so elaboration succeeds, and fail at 1 ns for a reason that
    has nothing to do with the generic - from a process whose name contains the
    generic's name, so the name turns up in the instance path. Before the phase
    check, the subtype case accepted this and the whole gate exited 0.
    """
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
          "  proc_g_data_w_watchdog : process\n"
          "  begin\n"
          "    if g_data_w = 0 then\n"
          "      wait for 1 ns;\n"
          '      assert false report "unrelated failure, nothing to do with the generic"\n'
          "        severity failure;\n"
          "    end if;\n"
          "    wait;\n"
          "  end process proc_g_data_w_watchdog;\n\n"
          "  proc_guard : process")


def m6_hand_edited_expectation() -> None:
    """One committed expectation is edited by hand."""
    path = ROOT / VECTORS
    lines = path.read_text(encoding="utf-8").splitlines()
    for i, line in enumerate(lines):
        if line and not line.startswith("#"):
            fields = line.split()
            fields[-1] = str(int(fields[-1]) ^ 1)
            lines[i] = " ".join(fields)
            break
    path.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")


SOURCE_MUTATIONS = [
    ("M1", "runner expects assertion text the library never emits",
     m1_wrong_expected_text, "failed for the wrong reason"),
    ("M2", "a negative testbench default is itself illegal",
     m2_illegal_default, "at least one default is illegal"),
    ("M3", "an entity generic is widened back to natural",
     m3_widened_entity_generic, "is declared 'natural', expected 'positive'"),
    ("M4", "the two mult_add bit-count constants go back to natural",
     m4_mult_add_constants, "bound check failure"),
    ("M5", "review's: boundary widened, unrelated failure at 1 ns from a process "
           "named after the generic",
     m5_unrelated_failure_named_after_the_generic, "wrong phase"),
    ("M6", "one committed expectation is edited by hand",
     m6_hand_edited_expectation, "does not match the generator"),
]


# ---------------------------------------------------------------------------
# Vector-file coverage mutations, run against the bench directly
# ---------------------------------------------------------------------------
# These thin the vector file rather than corrupting a value. Run through the
# whole gate they would be caught by the provenance step before the bench ever
# saw them, so they are handed straight to the bench instead - which is the
# thing whose self-protection they are testing.

def v_truncate(text: str) -> str:
    """Keep the manifest and a single data row."""
    head = [l for l in text.splitlines() if l.startswith("#")]
    first = next(l for l in text.splitlines() if l and not l.startswith("#"))
    return "\n".join(head + [first]) + "\n"


def v_drop_degenerate(text: str) -> str:
    """Drop every degenerate-format vector, padding the total back with copies
    of the baseline geometry so the count still matches the manifest."""
    head, base, dropped = [], [], 0
    for line in text.splitlines():
        if line.startswith("#"):
            head.append(line)
            continue
        if not line:
            continue
        f = line.split()
        if (f[0], f[1], f[3], f[4]) == ("6", "2", "4", "1"):
            base.append(line)
        else:
            dropped += 1
    padded = base + [base[0]] * dropped
    return "\n".join(head + padded) + "\n"


def v_strip_manifest(text: str) -> str:
    """Remove the manifest directives, leaving every vector in place."""
    return "\n".join(l for l in text.splitlines() if not l.startswith("#!")) + "\n"


VECTOR_MUTATIONS = [
    ("V1", "vector file truncated to a single data row", v_truncate,
     "the vector file has been truncated or padded"),
    ("V2", "every degenerate-format vector dropped, total padded back",
     v_drop_degenerate, "do not carry the number of vectors the manifest declares"),
    ("V3", "the manifest directives are removed", v_strip_manifest,
     "missing its manifest"),
]


# ---------------------------------------------------------------------------

def tree_is_clean() -> bool:
    out = subprocess.run(["git", "status", "--porcelain"], cwd=ROOT,
                         capture_output=True, text=True).stdout.strip()
    return out == ""


def restore(paths: list[str]) -> None:
    subprocess.run(["git", "checkout", "--"] + paths, cwd=ROOT,
                   capture_output=True, text=True)


def run_gate() -> tuple[int, str]:
    r = subprocess.run([sys.executable, str(ROOT / GATE)], cwd=ROOT,
                       capture_output=True, text=True)
    return r.returncode, (r.stdout or "") + (r.stderr or "")


def run_vector_bench(ghdl: str, workdir: Path, vector_path: Path) -> tuple[int, str]:
    r = subprocess.run(
        [ghdl, "-r", "--std=08", "--work=lm_math_fi_lib", f"--workdir={workdir}",
         f"-P{workdir}", "tb_quantize_vectors",
         f"-gg_vector_file={vector_path.name}",
         "--assert-level=error", "--stop-time=1us"],
        cwd=workdir, capture_output=True, text=True,
    )
    return r.returncode, (r.stdout or "") + (r.stderr or "")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--list", action="store_true", help="Name the mutations and exit.")
    parser.add_argument("--ghdl", default="ghdl", help="GHDL executable")
    args = parser.parse_args()

    if args.list:
        for tag, note, _fn, expect in SOURCE_MUTATIONS + [
                (t, n, f, e) for t, n, f, e in VECTOR_MUTATIONS]:
            print(f"  {tag}  {note}\n        must report: {expect!r}")
        return 0

    if not tree_is_clean():
        print("error: the working tree has uncommitted changes. This script edits "
              "tracked files and restores them with 'git checkout --', which would "
              "discard your work. Commit or stash first.", file=sys.stderr)
        return 2

    touched = [RUNNER, TB_DELAY, TB_FORMAT, SRC_DELAY, SRC_MULT_ADD, VECTORS]
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
    print("  ok: gate passes")

    workdir = ROOT / "build" / "ghdl_generic_domain"

    for tag, note, mutate, expect in SOURCE_MUTATIONS:
        print("=" * 78)
        print(f"{tag}: {note}")
        print("=" * 78)
        try:
            mutate()
            rc, out = run_gate()
        finally:
            restore(touched)
        if rc == 0:
            results.append((tag, False, "the gate PASSED; the mutation went undetected"))
            print("  FAIL the gate passed")
        elif expect not in out:
            results.append((tag, False, f"the gate failed, but not with {expect!r}"))
            print(f"  FAIL the gate failed for a different reason than {expect!r}")
        else:
            line = next((l.strip() for l in out.splitlines() if expect in l), expect)
            results.append((tag, True, line))
            print(f"  ok   rejected: {line[:150]}")

    BUILD.mkdir(parents=True, exist_ok=True)
    original = (ROOT / VECTORS).read_text(encoding="utf-8")
    for tag, note, transform, expect in VECTOR_MUTATIONS:
        print("=" * 78)
        print(f"{tag}: {note}")
        print("=" * 78)
        mutated = workdir / f"mutated_{tag}.txt"
        mutated.write_text(transform(original), encoding="utf-8", newline="\n")
        rc, out = run_vector_bench(args.ghdl, workdir, mutated)
        shutil.copyfile(mutated, BUILD / mutated.name)
        mutated.unlink(missing_ok=True)
        if rc == 0:
            results.append((tag, False, "the bench PASSED; the mutation went undetected"))
            print("  FAIL the bench passed")
        elif expect not in out:
            results.append((tag, False, f"the bench failed, but not with {expect!r}"))
            print(f"  FAIL the bench failed for a different reason than {expect!r}")
        else:
            line = next((l.strip() for l in out.splitlines() if expect in l), expect)
            results.append((tag, True, line))
            print(f"  ok   rejected: {line[:150]}")

    print("=" * 78)
    bad = [r for r in results if not r[1]]
    for tag, ok, detail in results:
        print(f"  {'ok  ' if ok else 'FAIL'} {tag}: {detail[:140]}")
    if bad:
        print(f"\n{len(bad)} of {len(results)} mutations were NOT caught.")
        return 1
    print(f"\nAll {len(results)} mutations were caught by the gate.")
    if not tree_is_clean():
        print("warning: the working tree is not clean after restoring; check "
              "'git status'", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
