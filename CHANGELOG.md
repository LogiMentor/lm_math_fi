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
- Added `scripts/run_ghdl_generic_domain_tests.py` and the units under
  `sim/generic_domain/`, which gate the generic domains in both directions: a
  legal value must never be rejected, and an illegal one must be rejected with a
  diagnostic that names the generic. Added the gate to CI and to the documented
  local gate.
- Added `scripts/gen_format_vectors.py`, which produces every committed format
  expectation - the `f_lm_quantize` vectors and the entity testbench - from the
  documented semantics using arbitrary-precision integers and fractions. It
  implements the arithmetic twice in different styles and refuses to emit
  anything unless the two agree, and it imports nothing from `src/`, `model/` or
  `js/`. The generic-domain gate re-runs it with `--check`, so the committed
  expectations cannot drift from the generator.
- Added `scripts/check_gate_mutations.py`, which breaks the repository in nine
  known ways and requires the gate to notice each one. Not part of CI: it edits
  tracked files while it runs.
- Added `sim/generic_domain/f_lm_quantize_vectors.txt`, 16704 committed vectors
  pinning the arithmetic of `f_lm_quantize` for every legal combination of its
  rounding and overflow arguments, across fifteen format geometries including
  binary points equal to and above the width, disjoint bit weights in both
  directions, one bit of weight overlap, and width 1.
- Added `sim/generic_domain/tb_degenerate_formats.vhd`, 192 value checks that
  drive all four quantizing entities at degenerate binary points and check the
  result rather than only that it elaborates. Expected values are computed by an
  exact-integer reference, not by the modules under test.
- Extended `sim/generic_domain/tb_legal_sweep.vhd` with degenerate binary-point
  instances of all four quantizing entities.
- Documented the binary-point domain in `docs/USER_GUIDE.md`: what a binary point
  means, that it may equal or exceed the width, the practical limit that exists
  even though none is enforced, and that the package helpers accept a wider
  domain than the entities can express.

### Changed

- The generic-domain gate now checks the phase in which a negative case fails, not
  only that it failed. A case that must be rejected by a generic's subtype has to
  be rejected before simulation starts, proved by the testbench's own
  `GENERIC DOMAIN TB STARTED` marker being absent and by the simulator having
  reported nothing against a source line; the generic's name is matched only
  outside instance paths. A case that must be rejected by an assertion has to
  fail at time zero with that assertion's message. An unrelated failure is now
  reported as failing for the wrong reason.
- `tb_quantize_vectors` now enforces a manifest carried in the vector file, so
  truncating the file, thinning it, or dropping a whole geometry fails instead of
  silently shrinking the gate's coverage.
- The generic-domain runner's simulation window is scoped per unit again. The
  default is back to 1us; only `tb_degenerate_formats` gets a longer one.
- Documented in `docs/VERIFICATION.md` which generic domains are enforced by the
  type system and which by assertions, and what that means for synthesis.

### Changed

- **Interface change.** `g_pipeline_input` on `lm_math_fi_add_sub` is now
  `natural range 0 to 1`. It previously accepted any natural and treated every
  value above zero as one register stage; values above 1 are now rejected.
  Instantiations that pass 0 or 1 are unaffected, and the documented latency
  formula is unchanged over the remaining domain.
- **Interface change.** Every width generic is now `positive` rather than
  `natural`: `g_data_w`, `g_din_w`, `g_dout_w`, `g_din1_w`, `g_din2_w`,
  `g_din_a_w`, `g_din_b_w` and `g_din_c_w`. A width of 0 previously analysed,
  elaborated and ran, producing a degenerate null-vector instance.
- Narrowed `g_pipe_stages`, `g_round_mode`, `g_din_a_type`, `g_din_b_type` and
  `g_dout_type` on `lm_math_fi_mult`, `g_round_mode` and `g_representation` on
  `lm_math_fi_mult_add`, and `g_direction` on `lm_math_fi_add_sub` from
  `integer` to `natural`. No `integer` generic remains in the library. A
  negative `g_pipe_stages` is rejected by its subtype instead of aborting later
  with an index error inside the library.

### Fixed

- `lm_math_fi_mult_add` aborted elaboration with a bound check failure whenever a
  binary point exceeded its width: `C_MULT_INT_W` and `C_ADDEND_INT_W` count bits
  above the binary point and were declared `natural`, so they failed for a purely
  fractional operand or addend. They are now `integer`. A binary point at or above
  the width is a legal format, and the other three quantizing modules already
  handled it. No result changes for any configuration that previously elaborated.
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
