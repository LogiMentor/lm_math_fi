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

## Quick Start From A Q Format

`lm_math_fi` is a synthesizable VHDL-2008 fixed-point library whose generics and
ports use only standard types, released under the Apache-2.0 license.

### From A Q Format To Generics

The [fixed-point calculator](https://logimentor.com/tools/fixed-point) writes
`Qm.n` with the sign bit counted in `m`, and `UQm.n` for unsigned, so the width
is `m + n` and the binary point is `n`. Its fields map to generics as follows:

| Calculator | Generic | Names |
|---|---|---|
| Width | width | `g_din_w`, `g_dout_w` (`lm_math_fi_format`); `g_din1_w`, `g_din2_w`, `g_dout_w` (`lm_math_fi_add_sub`); `g_din_a_w`, `g_din_b_w`, `g_dout_w` (`lm_math_fi_mult`); `g_din_a_w`, `g_din_b_w`, `g_din_c_w`, `g_dout_w` (`lm_math_fi_mult_add`) |
| Frac | binary point | the same names with `_binpnt` in place of `_w`, for example `g_din_binpnt` |
| Signed | representation | `g_representation`, or `g_din_a_type`, `g_din_b_type` and `g_dout_type` on `lm_math_fi_mult`: `C_LM_SIGNED` when checked, `C_LM_UNSIGNED` when not |

| Calculator format | Width generic | Binary-point generic | Representation |
|---|---:|---:|---|
| `Q4.12` | 16 | 12 | `C_LM_SIGNED` |
| `Q1.15` | 16 | 15 | `C_LM_SIGNED` |
| `UQ0.8` | 8 | 8 | `C_LM_UNSIGNED` |

The calculator offers the rounding and overflow keys of the reference model in
`model/lm_math_fi_model`, which `docs/USER_GUIDE.md` describes as using the same
vocabulary as the VHDL generics. The table pairs each option with the constant
of the same name in `src/lm_math_fi_pkg.vhd`, except `fix`, which it pairs by
the toward-zero rounding both implementations show; `bit_trunc` and the
`nearest_*` options are the model's other spellings of the mode they share a
row with.

| Calculator option | VHDL constant | Note |
|---|---|---|
| `trunc_bits`, `bit_trunc` | `C_LM_TRUNC_BITS` | |
| `trunc` | `C_LM_TRUNC` | alias of `C_LM_TRUNC_BITS` |
| `trunc_zero` | `C_LM_TRUNC_ZERO` | |
| `fix` | `C_LM_TRUNC_ZERO` | no constant of this name; the reference model rounds it toward zero, as `C_LM_TRUNC_ZERO` does |
| `floor` | `C_LM_FLOOR` | |
| `ceil` | `C_LM_CEIL` | |
| `round_even`, `nearest_even` | `C_LM_ROUND_EVEN` | |
| `round` | `C_LM_ROUND` | alias of `C_LM_ROUND_EVEN` |
| none | `C_LM_ROUND_NEAREST` | alias of `C_LM_ROUND_EVEN`; no calculator option |
| `round_pos_inf`, `nearest_posinf` | `C_LM_ROUND_POS_INF` | |
| `round_neg_inf`, `nearest_neginf` | `C_LM_ROUND_NEG_INF` | |
| `round_zero`, `nearest_zero` | `C_LM_ROUND_ZERO` | |
| `round_away`, `nearest_away` | `C_LM_ROUND_AWAY` | |
| `round_inf` | `C_LM_ROUND_INF` | alias of `C_LM_ROUND_AWAY` |
| `wrap` (Overflow) | `C_LM_WRAP` | |
| `saturate` (Overflow) | `C_LM_SATURATE` | |

The RTL and the calculator share the `Qm.n` convention and these mode names; no
check in this repository compares their results.

`lm_math_fi_add_sub` has no overflow generic; see Known limitations in
[CHANGELOG.md](CHANGELOG.md).

### Minimal Instantiation

Convert `Q4.12` signed to `Q2.6` signed, rounding to nearest and saturating:

```vhdl
library lm_math_fi_lib;
use lm_math_fi_lib.lm_math_fi_pkg.all;

-- In the architecture body:

-- Q4.12 signed (16 bits) -> Q2.6 signed (8 bits),
-- round to nearest (ties to even), saturate on overflow.
-- Latency: g_pipe_stages clock cycles (1 here); 0 makes it combinational.
u_q4_12_to_q2_6 : entity lm_math_fi_lib.lm_math_fi_format
  generic map(
    g_din_w          => 16,               -- Q4.12: width = 4 + 12
    g_din_binpnt     => 12,
    g_dout_w         => 8,                -- Q2.6: width = 2 + 6
    g_dout_binpnt    => 6,
    g_pipe_stages    => 1,
    g_round_mode     => C_LM_ROUND_EVEN,  -- calculator: round_even or round
    g_overflow       => C_LM_SATURATE,    -- calculator: saturate
    g_representation => C_LM_SIGNED       -- applies to din_i and dout_o
    )
  port map(
    clk_i  => clk,
    ce_i   => '1',
    din_i  => q4_12_data,                 -- std_logic_vector(15 downto 0)
    dout_o => q2_6_data                   -- std_logic_vector(7 downto 0)
    );
```

### Adding It To A Project

Compile the files in `src/` as VHDL-2008 into a library named `lm_math_fi_lib`,
in the order `scripts/run_ghdl_tests.py` and `sim/questasim/compile_lib.do` use:

1. `src/lm_math_fi_pkg.vhd`
2. `src/lm_math_fi_delay.vhd`
3. `src/lm_math_fi_format.vhd`
4. `src/lm_math_fi_add_sub.vhd`
5. `src/lm_math_fi_mult.vhd`
6. `src/lm_math_fi_mult_add.vhd`

Try formats and modes first in the
[fixed-point calculator](https://logimentor.com/tools/fixed-point).

For integration and verification details, see
[docs/USER_GUIDE.md](docs/USER_GUIDE.md) and
[docs/VERIFICATION.md](docs/VERIFICATION.md).

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
