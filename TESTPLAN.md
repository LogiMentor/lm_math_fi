<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 LogiMentor -->

# Test Plan

## Objectives

Verify that the public fixed-point modules compile as VHDL-2008, produce the
expected fixed-point results for directed edge cases, and keep all generated
output under `build/`.

## Regression Commands

```bash
python scripts/check_repo_hygiene.py --no-history
python scripts/run_python_model_tests.py
python scripts/run_ghdl_tests.py
python scripts/run_ghdl_generic_domain_tests.py
python scripts/check_repo_hygiene.py --no-history
```

## VHDL Testbenches

| Testbench | Checks | Cases |
|---|---:|---|
| `tb_lm_math_fi_pkg` | 36 | helper conversion, extension, alignment, resize, all rounding modes, wrap, saturation |
| `tb_lm_math_fi_delay` | 9 | `g_delay` 0/1/3, pipeline fill, clock-enable hold/resume |
| `tb_lm_math_fi_format` | 14 | truncation, signed/unsigned nearest-even rounding, positive/negative saturation, wrap, output pipeline |
| `tb_lm_math_fi_add_sub` | 12 | unsigned add/sub, signed add/sub, signed fractional rounding, dynamic select, input/output clock-enable behavior |
| `tb_lm_math_fi_mult` | 13 | unsigned max/wrap/saturation, signed minimum operand, mixed signedness, signed/unsigned fractional rounding, pipeline |
| `tb_lm_math_fi_mult_add` | 11 | add, subtract, fractional multiply-add, wide addend alignment, saturation, pipeline |

## Generic-Domain Gate

`scripts/run_ghdl_generic_domain_tests.py` drives the units under
`sim/generic_domain/`. There is one testbench per entity under test; its
generics mirror the entity's own, with legal defaults, and a case is selected by
a top-level generic override rather than by a dedicated file.

Positive half:

| Unit | Checks |
|---|---|
| `tb_legal_sweep` | 607 instances across the full legal cross-product of every discrete-domain generic, including all nine rounding modes, all four alias spellings, the minimum legal width, and degenerate binary points on all four quantizing entities; no assertion may fire |
| `tb_quantize_vectors` | replays 16704 committed `f_lm_quantize` vectors across fifteen format geometries, covering every legal rounding and overflow mode and the degenerate binary-point region |
| `tb_degenerate_formats` | 192 value checks driving all four quantizing entities at binary points equal to and above the width, disjoint bit weights in both directions, one bit of weight overlap, and width 1 in both signednesses |
| `tb_neg_*` with no override | each negative testbench runs to completion, proving that all of its defaults are legal |

Negative half, one case per generic-domain check:

| Entity | Rejected by an assertion | Rejected by the generic's subtype |
|---|---|---|
| `lm_math_fi_pkg.f_lm_quantize` | rounding mode, overflow mode | — |
| `lm_math_fi_delay` | — | `g_data_w`, `g_delay` |
| `lm_math_fi_format` | `g_representation`, `g_round_mode`, `g_overflow` | `g_din_w`, `g_dout_w` |
| `lm_math_fi_add_sub` | `g_direction`, `g_representation`, `g_round_mode` | `g_pipeline_input`, `g_din1_w`, `g_din2_w`, `g_dout_w` |
| `lm_math_fi_mult` | `g_din_a_type`, `g_din_b_type`, `g_dout_type`, `g_round_mode`, `g_overflow` | `g_pipe_stages`, `g_din_a_w`, `g_din_b_w`, `g_dout_w` |
| `lm_math_fi_mult_add` | `g_add_sub`, `g_representation`, `g_round_mode`, `g_overflow` | `g_pipe_stages`, `g_din_a_w`, `g_din_b_w`, `g_din_c_w`, `g_dout_w` |

Assertion cases are matched on the diagnostic text, which this repository owns.
Subtype cases are matched on the failing phase and the generic's name only,
because GHDL's wording for an out-of-subtype value is tool output that changes
across versions. The runner additionally pins the subtype each entity declares,
so a subtype case cannot pass if an entity's own declaration were widened.

## Python Reference Tests

The Python model tests cover:

| Area | Cases |
|---|---|
| Construction | bit strings and raw integer patterns |
| Rounding | bit truncation, truncate toward zero, nearest-even, tie-directed modes |
| Overflow | wrap, saturation, unsigned-to-signed resize |
| Arithmetic | add, subtract, multiply, multiply-add |

## Open Gaps

Add constrained-random RTL vectors against the Python model.

Add synthesis report baselines for representative devices after local vendor
tool runs are available.

Add explicit wide-multiplier tests once a device-aware multiplier generator is
introduced.

Add divider coverage if a fixed-point divider module is added.
