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
