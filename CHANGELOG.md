<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 LogiMentor -->

# Changelog

## [Unreleased]

### Added

- Added generic-domain assertions to every entity so an out-of-domain
  signedness, rounding mode, overflow mode, direction or add/subtract selector
  fails with a message naming the entity, the generic, the offending value and
  the accepted values. VHDL assertions are a simulation and elaboration
  diagnostic; most synthesis tools ignore them.
- Added assertions to the rounding-mode and overflow fallback branches of
  `lm_math_fi_pkg.f_lm_quantize`. Every supported constant now has an explicit
  branch, so an unrecognised value stops instead of silently bit-truncating or
  wrapping.
- Added `scripts/run_ghdl_negative_tests.py` and the deliberately illegal units
  under `sim/negative/`. Each unit is expected to fail, and the runner passes
  only when the failure carries the expected diagnostic. Added the runner to CI
  and to the documented local gate.

### Changed

- Narrowed `g_pipe_stages`, `g_round_mode`, `g_din_a_type`, `g_din_b_type` and
  `g_dout_type` on `lm_math_fi_mult`, `g_round_mode` and `g_representation` on
  `lm_math_fi_mult_add`, and `g_direction` on `lm_math_fi_add_sub` from
  `integer` to `natural`. Every generic in the library is now `natural`. A
  negative `g_pipe_stages` is rejected at analysis instead of aborting later
  with an index error inside the library.

### Fixed

- `lm_math_fi_mult_add` given `C_LM_ADDSUB` and `lm_math_fi_add_sub` given a
  representation other than `C_LM_SIGNED` or `C_LM_UNSIGNED` previously
  selected no generate branch, left the result undriven and simulated silently
  at all-`U`. Both now stop with a diagnostic.

## [1.0.0] - 2026-06-15

### Added

- Added self-contained fixed-point VHDL-2008 RTL under Apache-2.0.
- Added self-checking GHDL/QuestaSim testbenches for all public modules.
- Added Python fixed-point reference helpers and tests.
- Added repository hygiene checks, local hooks, and GitHub Actions.
- Added local synthesis-report script for Vivado, Quartus, Radiant, and Libero.

[1.0.0]: https://github.com/LogiMentor/lm_math_fi/releases/tag/v1.0.0
