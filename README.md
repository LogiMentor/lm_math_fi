<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 LogiMentor -->

# lm_math_fi

`lm_math_fi` is a self-contained VHDL-2008 library of fixed-point arithmetic
building blocks. It provides format conversion, add/subtract, multiply, and
multiply-add/subtract primitives with explicit binary-point, signedness,
rounding, overflow, clock-enable, and pipeline settings.

All synthesizable sources compile into `lm_math_fi_lib`. Verification
testbenches are self-checking: each bench reports `TEST PASSED` on success and
raises `severity failure` on mismatch.

## Repository Layout

```text
src/
  lm_math_fi_pkg.vhd       constants and fixed-point helper functions
  lm_math_fi_delay.vhd     fixed delay line for std_logic_vector signals
  lm_math_fi_format.vhd    fixed-point format conversion
  lm_math_fi_add_sub.vhd   fixed-point add/subtract
  lm_math_fi_mult.vhd      fixed-point multiply
  lm_math_fi_mult_add.vhd  fixed-point multiply-add/subtract

sim/
  tb/                      self-checking VHDL testbenches
  questasim/               QuestaSim / ModelSim scripts

model/
  lm_math_fi_model/        Python fixed-point reference helpers
  tests/                   Python reference-model tests

scripts/
  run_ghdl_tests.py        GHDL compile-and-run regression
  run_python_model_tests.py Python reference-model regression
  run_synth_reports.py     local FPGA synthesis/timing summaries
  check_repo_hygiene.py    repository hygiene checks

docs/
  USER_GUIDE.md            integration and verification guide
  REGRESSION_COVERAGE.md   module-to-test coverage matrix
  VERIFICATION.md          verification scope and known limits

TESTPLAN.md                regression cases and gaps
CHANGELOG.md               public release history
CONTRIBUTING.md            contribution and local hook notes
```

## Modules

| Module | Operation | Latency | Notes |
|---|---|---:|---|
| `lm_math_fi_delay` | delay line | `g_delay` clocks | `g_delay = 0` is combinational. |
| `lm_math_fi_format` | resize, binary-point conversion, rounding, overflow | `g_pipe_stages` clocks | Uses `lm_math_fi_delay` for optional output registers. |
| `lm_math_fi_add_sub` | `a + b`, `a - b`, or runtime add/subtract | `(g_pipeline_input > 0 ? 1 : 0) + g_pipeline_output` clocks | `ce_i` gates enabled register stages. |
| `lm_math_fi_mult` | `a * b` | `1 + g_pipe_stages` clocks | Supports signed, unsigned, mixed operands, output rounding, and overflow handling. |
| `lm_math_fi_mult_add` | `a * b + c` or `a * b - c` | `1 + g_pipe_stages` clocks | Supports signed or unsigned operands, output rounding, and overflow handling. |

Sequential modules have no reset port. Pipeline contents before the first valid
sample reaches the output are intentionally unspecified; downstream logic should
observe the documented latency or add project-specific valid/reset wrapping.

## Rounding And Overflow

`lm_math_fi_pkg.vhd` defines fixed-point conversion constants:

| Constant | Behavior |
|---|---|
| `C_LM_TRUNC_BITS` | discard low-order bits |
| `C_LM_TRUNC_ZERO` | truncate toward zero |
| `C_LM_FLOOR` | round toward negative infinity |
| `C_LM_CEIL` | round toward positive infinity |
| `C_LM_ROUND_EVEN` | round to nearest, ties to even |
| `C_LM_ROUND_POS_INF` | round to nearest, ties toward positive infinity |
| `C_LM_ROUND_NEG_INF` | round to nearest, ties toward negative infinity |
| `C_LM_ROUND_ZERO` | round to nearest, ties toward zero |
| `C_LM_ROUND_AWAY` | round to nearest, ties away from zero |
| `C_LM_WRAP` | wrap overflow |
| `C_LM_SATURATE` | saturate overflow |

`C_LM_TRUNC`, `C_LM_ROUND`, `C_LM_ROUND_NEAREST`, and `C_LM_ROUND_INF` remain
available as short aliases.

## Quick Start

Run the repository hygiene checks:

```bash
python scripts/check_repo_hygiene.py --no-history
```

Install Python model dependencies and run the reference-model tests:

```bash
python -m pip install -r requirements-dev.txt
python scripts/run_python_model_tests.py
```

Run the VHDL regression with GHDL:

```bash
python scripts/run_ghdl_tests.py
```

The GHDL runner uses `build/ghdl`. It reports analysis, elaboration, simulation
failures, and missing `TEST PASSED` markers as readable regression failures.

## QuestaSim / ModelSim

The QuestaSim / ModelSim scripts keep local output under `build/questasim`:

```bash
repo_root="$(pwd -P)"
mkdir -p "$repo_root/build/questasim"
vsim -c -l "$repo_root/build/questasim/transcript" -wlf "$repo_root/build/questasim/vsim.wlf" -do "set ::LM_MATH_FI_QUESTASIM_DIR {$repo_root/sim/questasim}; do {$repo_root/sim/questasim/run_all.do}; quit -f"
```

Single-test scripts are also provided under `sim/questasim/run_tb_*.do`.

## Local Synthesis Reports

Local synthesis is intentionally not part of CI because it depends on licensed
vendor tools. Generate scripts or reports under `build/synth` with:

```bash
python scripts/run_synth_reports.py --emit-only
python scripts/run_synth_reports.py --tools vivado --vivado-dir /path/to/Vivado
python scripts/run_synth_reports.py --tools quartus --quartus-dir /path/to/quartus
python scripts/run_synth_reports.py --tools radiant --radiant-dir /path/to/radiant
python scripts/run_synth_reports.py --tools libero --libero-dir /path/to/libero
```

The script emits `synthesis_summary.md` and `synthesis_summary.csv` when vendor
tools are available.

## Verification Status

The current regression contains 6 VHDL self-checking testbenches with 95 named
checks, plus 10 Python reference-model tests. Coverage includes signed and
unsigned arithmetic, binary-point conversion, overflow wrap/saturation,
rounding modes, zero-delay behavior, pipeline latency, and clock-enable holds.

See [docs/REGRESSION_COVERAGE.md](docs/REGRESSION_COVERAGE.md),
[docs/VERIFICATION.md](docs/VERIFICATION.md), and [TESTPLAN.md](TESTPLAN.md)
for the detailed matrix and known limits.

## Repository Hygiene

Generated output must stay under `build/`:

| Flow | Output directory |
|---|---|
| GHDL | `build/ghdl` |
| QuestaSim / ModelSim | `build/questasim` |
| Local synthesis | `build/synth` |

`scripts/check_repo_hygiene.py` checks license files, SPDX headers, forbidden
publication markers, commit messages and historical file blobs when history is
enabled, and generated simulator or FPGA-tool output outside `build/`. The
check is integrated into pre-commit, commit-message, pre-push hooks, and GitHub
Actions.

## License

Licensed under the Apache License, Version 2.0. See [LICENSE](LICENSE).

For customization, integration support, verification extensions, or related FPGA design services, visit [LogiMentor](https://www.logimentor.com).
