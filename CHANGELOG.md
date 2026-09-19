<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 LogiMentor -->

# Changelog

## [Unreleased]

Validation of the generic and format domains of the public entities, a defect fix
in `lm_math_fi_mult_add`, and the gates that hold both in place.

### Added

- Generic-domain assertions on every entity. An out-of-domain signedness,
  rounding mode, overflow mode, direction or add/subtract selector now fails with
  a message naming the entity, the generic, the offending value and the accepted
  values. VHDL assertions are a simulation and elaboration diagnostic; most
  synthesis tools ignore them, and `docs/VERIFICATION.md` records what that means.
- Diagnostics on the rounding-mode and overflow fallback branches of
  `lm_math_fi_pkg.f_lm_quantize`. Every supported constant now has an explicit
  branch, so an unrecognised value stops instead of silently bit-truncating or
  wrapping.
- `scripts/gen_format_vectors.py`, which produces every committed format
  expectation from the documented semantics using arbitrary-precision integers
  and fractions. It implements the whole path from input decoding to emitted
  expectation twice, in two pipelines that share no arithmetic, and refuses to
  emit unless both agree. It imports nothing from `src/`, `model/` or `js/`.
- `scripts/run_ghdl_generic_domain_tests.py`, which gates the generic and format
  domains in both directions, using the units under `sim/generic_domain/`: a
  legal value must never be rejected, and an illegal one must be rejected in the
  phase the case declares, attributed to the specific assertion or generic
  subtype that case exists to exercise. It re-runs the generator with `--check`
  on every invocation.
- `sim/generic_domain/f_lm_quantize_vectors.txt` and
  `sim/generic_domain/tb_degenerate_formats.vhd`, the committed expectations, and
  `sim/generic_domain/tb_legal_sweep.vhd`, which instantiates every entity across
  the full legal cross-product of its discrete-domain generics.
- `scripts/check_gate_mutations.py`, which breaks the repository in known ways and
  requires the gate to notice each one, naming the check that must fail and what
  it must say. CI runs it on pull requests; it edits tracked files while it runs,
  so it is not part of the per-push gate.
- The binary-point domain in `docs/USER_GUIDE.md`: what a binary point means, that
  it may equal or exceed the width, what actually bounds it in practice, and that
  the package helpers accept a wider domain than the entities can express.
- A statement in `docs/VERIFICATION.md` of what these gates claim: they catch
  accidental regression, and do not claim to resist deliberate tampering.

### Changed

- **Interface change.** `g_pipeline_input` on `lm_math_fi_add_sub` is now
  `natural range 0 to 1`. It previously accepted any natural and treated every
  value above zero as one register stage; values above 1 are now rejected.
  Instantiations passing 0 or 1 are unaffected.
- **Interface change.** Every width generic is now `positive` rather than
  `natural`: `g_data_w`, `g_din_w`, `g_dout_w`, `g_din1_w`, `g_din2_w`,
  `g_din_a_w`, `g_din_b_w` and `g_din_c_w`. A width of 0 previously analysed,
  elaborated and ran, producing a degenerate null-vector instance.
- Narrowed the remaining `integer` generics to `natural`: `g_pipe_stages`,
  `g_round_mode`, `g_din_a_type`, `g_din_b_type` and `g_dout_type` on
  `lm_math_fi_mult`, `g_round_mode` and `g_representation` on
  `lm_math_fi_mult_add`, and `g_direction` on `lm_math_fi_add_sub`. No `integer`
  generic remains in the library.
- The local gate documented in `CONTRIBUTING.md`, `docs/VERIFICATION.md` and
  `TESTPLAN.md` now lists every check CI runs on a push, in CI's order. CI's
  behaviour is unchanged.

### Fixed

- `lm_math_fi_mult_add` aborted elaboration with a bound check failure whenever a
  binary point exceeded its width: `C_MULT_INT_W` and `C_ADDEND_INT_W` count bits
  above the binary point and were declared `natural`, so they failed for a purely
  fractional operand or addend. They are now `integer`. A binary point at or above
  the width is a legal format, and the other three quantizing modules already
  handled it. No result changes for any configuration that previously elaborated.
- `lm_math_fi_mult_add` given `C_LM_ADDSUB` and `lm_math_fi_add_sub` given a
  representation other than `C_LM_SIGNED` or `C_LM_UNSIGNED` previously selected
  no generate branch, left the result undriven and simulated silently at all-`U`.
  Both now stop with a diagnostic.

## [1.0.0] - 2026-06-15

### Added

- Added self-contained fixed-point VHDL-2008 RTL under Apache-2.0.
- Added self-checking GHDL/QuestaSim testbenches for all public modules.
- Added Python fixed-point reference helpers and tests.
- Added repository hygiene checks, local hooks, and GitHub Actions.
- Added local synthesis-report script for Vivado, Quartus, Radiant, and Libero.

[1.0.0]: https://github.com/LogiMentor/lm_math_fi/releases/tag/v1.0.0
