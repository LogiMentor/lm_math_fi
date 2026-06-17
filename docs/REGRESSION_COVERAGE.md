<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 LogiMentor -->

# Regression Coverage

The VHDL regression contains 6 self-checking testbenches and 95 named checks.
Each testbench reports `TEST PASSED` on success and fails with `severity
failure` on mismatch.

| Module | Testbench | Named checks | Main coverage |
|---|---|---:|---|
| `lm_math_fi_pkg` | `tb_lm_math_fi_pkg` | 36 | conversions, sign/zero extension, add/sub helpers, alignment, rounding modes, saturation, wrap |
| `lm_math_fi_delay` | `tb_lm_math_fi_delay` | 9 | zero delay, one-cycle delay, multi-cycle delay, clock-enable hold/resume |
| `lm_math_fi_format` | `tb_lm_math_fi_format` | 14 | truncation, signed/unsigned nearest-even rounding, signed saturation, signed wrap, output pipeline, clock enable |
| `lm_math_fi_add_sub` | `tb_lm_math_fi_add_sub` | 12 | unsigned add/sub, signed add/sub, signed fractional rounding, runtime select, output pipeline, input and output clock enable |
| `lm_math_fi_mult` | `tb_lm_math_fi_mult` | 13 | unsigned, signed minimum, mixed signedness, overflow wrap/saturation, signed/unsigned fractional rounding, pipeline, clock enable |
| `lm_math_fi_mult_add` | `tb_lm_math_fi_mult_add` | 11 | add, subtract, saturation, fractional rounding, wide addend alignment, pipeline, clock enable |

The Python reference-model regression adds 10 unit tests covering bit/raw
construction, rounding aliases, directed and tie rounding modes, wrap,
saturation, widening, add, multiply, and multiply-add vectors.

## Direct Coverage Status

| Public item | Status |
|---|---|
| `lm_math_fi_pkg.vhd` | directly tested |
| `lm_math_fi_delay.vhd` | directly tested |
| `lm_math_fi_format.vhd` | directly tested |
| `lm_math_fi_add_sub.vhd` | directly tested |
| `lm_math_fi_mult.vhd` | directly tested |
| `lm_math_fi_mult_add.vhd` | directly tested |

## Gaps

The regression is directed, not exhaustive or randomized. It does not yet
collect functional coverage, does not sweep large DSP-tiling widths, and does
not validate timing closure on vendor devices.
