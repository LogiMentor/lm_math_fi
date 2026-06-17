<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 LogiMentor -->

# User Guide

## Library Setup

Compile the synthesizable sources into `lm_math_fi_lib` in this order:

1. `src/lm_math_fi_pkg.vhd`
2. `src/lm_math_fi_delay.vhd`
3. `src/lm_math_fi_format.vhd`
4. `src/lm_math_fi_add_sub.vhd`
5. `src/lm_math_fi_mult.vhd`
6. `src/lm_math_fi_mult_add.vhd`

The RTL uses only IEEE VHDL packages plus entities from this repository.

## Fixed-Point Format

Every numeric port is a `std_logic_vector`. Its interpretation is controlled by
generics:

| Generic | Meaning |
|---|---|
| `*_w` | total bit width |
| `*_binpnt` | number of fractional bits |
| `*_type` or `g_representation` | `C_LM_SIGNED` or `C_LM_UNSIGNED` |
| `g_round_mode` | one of the `C_LM_*` rounding constants |
| `g_overflow` | `C_LM_WRAP` or `C_LM_SATURATE` |

For signed formats, the vector is two's-complement. For unsigned formats, the
vector is an unsigned integer scaled by `2**(-binpnt)`.

## Clocking, Clock Enable, And Reset

All sequential modules use `clk_i`. No module currently has a reset port.
Pipeline contents before the first valid sample reaches the output are
intentionally unspecified. Integrations that require deterministic startup
values should add project-specific valid, flush, or reset wrapping.

`ce_i` gates internal registers and pipeline stages. If a selected generic path
is combinational, that path still follows its inputs even when `ce_i = '0'`.

## Module Notes

`lm_math_fi_delay` implements a delay line for `std_logic_vector` data.
`g_delay = 0` is a pure combinational pass-through.

`lm_math_fi_format` converts width, binary point, rounding mode, signedness, and
overflow behavior. Use it at datapath boundaries where bit growth must be
controlled explicitly.

`lm_math_fi_add_sub` supports static add, static subtract, or runtime selection
through `sel_add_i` when `g_direction = C_LM_ADDSUB`. `g_pipeline_input` is
treated as a boolean input-register enable; `g_pipeline_output` is a delay
count.

`lm_math_fi_mult` registers the product, optionally adds pipeline stages, then
formats the result with the selected rounding and overflow behavior. The RTL
describes native-width products. Wide multipliers may require project-specific
tiling or placement guidance for maximum Fmax.

`lm_math_fi_mult_add` registers `a*b` and `c`, aligns both operands to an
internal format wide enough for the product and addend integer/fractional
ranges, adds or subtracts, optionally pipelines, and formats the output.

## Reference Model

The Python reference helpers under `model/lm_math_fi_model` wrap `fxpmath` with
the same vocabulary used by the VHDL generics.

```python
from lm_math_fi_model import FiFormat, fi, mult_add

q_in = FiFormat(width=4, binpnt=2, signed=False)
q_out = FiFormat(width=6, binpnt=2, signed=False)

result = mult_add(
    fi(1.5, q_in),
    fi(0.75, q_in),
    fi(0.25, q_out),
    q_out,
    rounding="round",
    overflow="wrap",
)

assert result.bits == "000110"
```

Run the tests with:

```bash
python -m pip install -r requirements-dev.txt
python scripts/run_python_model_tests.py
```

## Simulation

Run GHDL:

```bash
python scripts/run_ghdl_tests.py
```

Run QuestaSim / ModelSim:

```bash
repo_root="$(pwd -P)"
mkdir -p "$repo_root/build/questasim"
vsim -c -l "$repo_root/build/questasim/transcript" -wlf "$repo_root/build/questasim/vsim.wlf" -do "set ::LM_MATH_FI_QUESTASIM_DIR {$repo_root/sim/questasim}; do {$repo_root/sim/questasim/run_all.do}; quit -f"
```

Both flows keep generated output under `build/`.

## Synthesis Reports

`scripts/run_synth_reports.py` is a local utility for Vivado, Quartus, Radiant,
and Libero installations. It writes all scripts, logs, and summaries under
`build/synth`.

Use `--emit-only` to inspect generated scripts without running vendor tools.
Use `--module` to limit the run to one or more modules.
