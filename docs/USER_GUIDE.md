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

### The Binary Point

`*_binpnt` is the number of fractional bits. A stored word `R` of `*_w` bits with
binary point `B` denotes the exact value `R / 2**B`, where `R` is read as a
two's-complement integer for a signed format and as an unsigned integer
otherwise. Moving the binary point does not change the bits; it changes which
power of two each bit carries.

The binary point may equal or exceed the width. Such a format has no integer
bits: every bit is fractional and the binary point sits at or beyond the top of
the word, so the represented magnitude is below `2**(-(B - *_w))`. This is the
ordinary way to carry a normalized coefficient or a residual error term, and all
modules support it.

The binary-point generics are `natural`. Their domain is zero upwards and bears
no relationship to the width:

| Generic | Type | Domain |
|---|---|---|
| every `*_binpnt` on every entity | `natural` | `0` upwards; may equal or exceed the matching `*_w` |
| every `*_w` on every entity | `positive` | `1` upwards |

No upper bound is imposed on a binary point, and nothing rejects a large one.
A limit exists in practice, but it is a limit on the **distance between** binary
points rather than on any one of them. The modules size their internal signals
from the widths and from the difference between the binary points they must
align, so:

- binary points that are large but aligned with each other cost nothing. A
  conversion from `(4, 1000000000)` to `(4, 1000000000)` elaborates and runs.
- binary points far apart cost the difference. A conversion from `(4, 0)` to
  `(4, 1000000000)` asks for an internal object of about a gigabyte and fails.

So the practical bound is on `|source binpnt - destination binpnt|`, and on the
corresponding differences inside the arithmetic modules, not on the absolute
value of a binary point.

What the committed regression actually exercises is much smaller than either:
binary points from 0 to 14 and widths from 1 to 8, chosen so that every input
value of every geometry can be enumerated exhaustively. Run
`python scripts/gen_format_vectors.py --coverage` for the current figures.

The conversion helpers in `lm_math_fi_pkg` take their binary points as `integer`
rather than `natural`, so the package accepts a wider domain than any entity can
express: a negative binary point, meaning a word whose least significant bit
carries a weight above `2**0`. Entities cannot be given one, because their
generics are `natural`.

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
