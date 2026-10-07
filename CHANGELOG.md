<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 LogiMentor -->

# Changelog

## [0.1.0] - 2026-10-07

First tagged release. An earlier revision of this file labelled the initial
content 1.0.0; no 1.0.0 tag or release was ever published, and that content is
included in this entry.

### Added

- Self-contained fixed-point VHDL-2008 RTL under Apache-2.0: the package
  `lm_math_fi_pkg` and the entities `lm_math_fi_delay`, `lm_math_fi_format`,
  `lm_math_fi_add_sub`, `lm_math_fi_mult` and `lm_math_fi_mult_add`.
- Generic-domain assertions on every entity that has an enumerated generic, which
  is every entity except `lm_math_fi_delay`, whose generics are bounded by their
  subtypes. An out-of-domain signedness, rounding mode, overflow mode, direction
  or add/subtract selector now fails with a message naming the entity, the
  generic, the offending value and the accepted values. VHDL assertions are a
  simulation and elaboration diagnostic; most synthesis tools ignore them, and
  `docs/VERIFICATION.md` records what that means.
- Diagnostics on the rounding-mode and overflow fallback branches of
  `lm_math_fi_pkg.f_lm_quantize`. Every supported constant now has an explicit
  branch, so an unrecognised value stops instead of silently bit-truncating or
  wrapping.
- Python fixed-point reference helpers in `model/lm_math_fi_model`, a wrapper over
  `fxpmath==0.4.10`, and their tests.
- `js/lm_math_fi.mjs`, a zero-dependency ES module port of the Python reference
  model (#3). It exposes `FiFormat`, `fi`, `bits`, `raw`, `quantize`, `add`,
  `sub`, `mul` and `mult_add`, accepts the Python model's rounding and overflow
  keys, and follows fxpmath's float64 conversion pipeline, including where that
  pipeline is lossy, rather than computing exact rational results.
- The binary-point domain in `docs/USER_GUIDE.md`: what a binary point means, that
  it may equal or exceed the width, what actually bounds it in practice, and that
  the package helpers accept a wider domain than the entities can express.
- Self-checking testbenches under `sim/tb/`, one for the package and one for each
  entity, six in all. CI runs them under GHDL with `scripts/run_ghdl_tests.py`.
  QuestaSim scripts for the same testbenches are included under `sim/questasim/`;
  CI does not run them.
- The golden-vector oracle for the JavaScript port (#4): `js/golden_vectors.json`,
  6342 vectors generated from the Python model by
  `scripts/gen_js_golden_vectors.py`, and `js/test/golden.test.mjs`, which replays
  every vector against the port under Node's built-in test runner. The file
  carries no commit hash, timestamp or random field, so regenerating it
  reproduces it byte for byte, and `--check` compares the full bytes. Inputs on
  which fxpmath raises are recorded as expected-error vectors whose category is
  derived from the exception type, and the port must throw an error of the same
  category. CI runs both the byte-exact check and the replay.
- `scripts/run_ghdl_generic_domain_tests.py`, which gates the generic and format
  domains in both directions, using the units under `sim/generic_domain/`: a
  legal value must never be rejected, and an illegal one must be rejected in the
  phase the case declares, attributed to the specific assertion or generic
  subtype that case exists to exercise. Attribution is by source location,
  derived from `src/` on each run; two assertions keyed on the same thing are an
  ambiguity it refuses to resolve rather than one it picks from. It re-runs the
  generator with `--check` on every invocation.
- A coverage policy stated in `sim/generic_domain/tb_quantize_vectors.vhd`
  rather than derived from the vector file: every geometry must carry every
  combination of input value, source signedness, destination signedness,
  rounding mode and overflow mode exactly once, with the signednesses and modes
  being those `lm_math_fi_pkg` accepts, and the declared geometries must cover
  all eight geometry families the bench classifies for itself. The product is
  enforced through a canonical row order the bench defines plus a row count
  equal to the product of the domain sizes. Which signednesses and modes are
  required is asked of the package on each run, so a mode added there is
  demanded of the vectors, in every combination, rather than left silently
  uncovered. A vector set reduced but kept internally consistent fails, and the
  diagnostic names each signedness or mode absent from the failing geometry, or
  says that the shortfall is in the combinations rather than in any dimension.
- `sim/generic_domain/f_lm_quantize_vectors.txt` and
  `sim/generic_domain/tb_degenerate_formats.vhd`, the committed expectations, and
  `sim/generic_domain/tb_legal_sweep.vhd`, which instantiates every entity across
  the full legal cross-product of its discrete-domain generics.
- A statement in `docs/VERIFICATION.md` of what these gates claim: they catch
  accidental regression, and do not claim to resist deliberate tampering.
- `scripts/gen_format_vectors.py`, which produces every committed format
  expectation from the documented semantics using arbitrary-precision integers
  and fractions. Decoding, rescaling, rounding and overflow are implemented
  twice, in two references that share none of that arithmetic, compared on the
  emitted bit string, and it refuses to emit unless both agree. The composition
  of each operation is written once and is checked only by the gate's
  comparison against the RTL. It imports nothing from `src/`, `model/` or
  `js/`.
- `scripts/check_gate_mutations.py`, which breaks the repository in known ways and
  requires the gate to notice each one, naming the check that must fail and what
  it must say. Mutations that fail the same check are cross-judged, so that no
  judge is satisfied by another mutation's output. CI runs it on pull requests;
  it edits tracked files while it runs, so it is not part of the per-push gate.
- Repository hygiene checks in `scripts/check_repo_hygiene.py`, pre-commit hooks
  that run them, and GitHub Actions CI.
- `scripts/run_synth_reports.py`, which writes Vivado, Quartus, Radiant and Libero
  build scripts under `build/synth` and runs whichever of those tools it finds
  installed, or only writes the scripts with `--emit-only`. No synthesis tool
  runs in CI, and the script's presence is not evidence that any of these tools
  was run for this release.

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

### Known limitations

- `lm_math_fi_add_sub` has no overflow-mode generic. It forms the sum or
  difference at full precision and then wraps it into the output format, so the
  result wraps whenever it does not fit the output format, for example when the
  output is narrower than the full-precision sum at the same binary point.
- Workaround: set `g_dout_w` and `g_dout_binpnt` to the full-precision format,
  which the entity computes internally as `C_RES_W` and `C_RES_BINPNT`, and feed
  the result to `lm_math_fi_format` with `g_overflow => C_LM_SATURATE`. Those two
  constants are local to the architecture, so the instantiating design has to
  compute the same values: `C_RES_BINPNT` is the larger of the two input binary
  points, and `C_RES_W` is the larger of the two inputs' integer-bit counts
  (width minus binary point) plus `C_RES_BINPNT` plus 1.
- The workaround does not cover an unsigned subtraction whose result is
  negative. That result already wraps within the full-precision format, as
  `sim/tb/tb_lm_math_fi_add_sub.vhd` asserts, so saturating it afterwards gives
  the largest unsigned value rather than zero.
- `lm_math_fi_mult_add` with `g_representation => C_LM_UNSIGNED` and
  `g_add_sub => C_LM_SUB` behaves the same way: a negative difference wraps in
  the internal accumulator before `g_overflow` is applied, so `C_LM_SATURATE`
  gives the largest unsigned value rather than zero.

[0.1.0]: https://github.com/LogiMentor/lm_math_fi/releases/tag/v0.1.0
