<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 LogiMentor -->

# Verification

## Gates

The public-release gate is:

```bash
python scripts/check_repo_hygiene.py --no-history
python scripts/run_python_model_tests.py
python scripts/run_ghdl_tests.py
python scripts/run_ghdl_generic_domain_tests.py
python scripts/check_repo_hygiene.py --no-history
```

CI runs repository hygiene as a separate job with full ref inspection and runs
the GHDL regression, then the generic-domain gate, with a post-regression
hygiene check.

## Scope

The regression checks:

| Area | Coverage |
|---|---|
| Signed and unsigned arithmetic | add/subtract, multiply, multiply-add |
| Binary-point conversion | resize, fractional input/output alignment |
| Rounding | bit truncation, truncate toward zero, floor, ceil, nearest-even, nearest tie directions |
| Overflow | wrap and saturation |
| Pipeline behavior | declared latencies and clock-enable hold/resume |
| Delay line behavior | zero, one-cycle, and multi-cycle delays |
| Python model | vectors aligned with RTL expectations |
| Generic domains | every legal value of every discrete-domain generic is accepted, and every out-of-domain value is rejected with a diagnostic naming the generic |

## Generic Domains

`scripts/run_ghdl_generic_domain_tests.py` gates the generic domains in both
directions, using the units under `sim/generic_domain/`.

Positive half: every entity is instantiated across the full legal cross-product
of its discrete-domain generics and run past time 0, and no assertion may fire;
every entity is driven at degenerate binary points - equal to the width, above
the width, bit weights disjoint either way, one bit of overlap, and width 1 - and
the result is checked, not only that it elaborates; `f_lm_quantize` is replayed
against committed vectors that pin its arithmetic for every legal rounding and
overflow mode across fifteen format geometries; and every negative testbench is
run once with no override, proving its defaults are all legal.

A binary point may equal or exceed its width; see the binary-point section of
docs/USER_GUIDE.md. Nothing constrains a binary point against a width, so the
gate covers that region rather than excluding it.

Negative half: one case per generic-domain check, selected by a top-level
generic override. A case passes only when the run fails, the testbench does not
reach its completion marker, and the output carries what the runner expects for
that case.

Two mechanisms enforce the domains, and they have different reach.

Width and pipeline-depth domains are contiguous numeric bounds, so they live in
the generic's own subtype: widths are `positive`, pipeline depths are `natural`,
and `lm_math_fi_add_sub.g_pipeline_input` is `natural range 0 to 1`. Every tool
that reads the entity enforces those, synthesis included.

Rounding modes, overflow modes, representations and the multiply-add selector
are enumerations encoded as integers. Their admissible set can grow and is not
contiguous in every case, and a range repeated on each entity would drift from
the constants in `lm_math_fi_pkg`, so they are checked by concurrent assertions
instead. A VHDL assertion is a simulation and elaboration diagnostic: an
out-of-domain rounding, overflow or representation value is rejected when the
design is simulated or elaborated, and is not rejected by synthesis tools that
ignore assertions. Ports and generics deliberately use standard types only, so
that an integrator never has to reference this library's package to instantiate
a module and so that mixed-language instantiation keeps working; that choice is
what rules out an enumerated generic type, which would have carried the domain
into synthesis.

## Known Limits

The regression is not exhaustive. It does not yet include constrained-random
stimulus, formal proofs, or coverage collection.

No reset behavior is verified because the RTL has no reset ports. Pipeline
contents before the first valid sample are unspecified; integrations that need
deterministic startup should add project-specific valid, flush, or reset
wrapping.

No vendor synthesis flow is part of CI. `scripts/run_synth_reports.py` can
generate local Vivado, Quartus, Radiant, and Libero scripts under
`build/synth`, but timing and utilization depend on local tool versions,
devices, constraints, and multiplier inference choices.

The current multiplier RTL is generic and portable. It does not yet implement a
device-aware generated wide-multiplier architecture with DSP tiling, placement,
or register-placement policy.

There is no fixed-point divider module in this repository.
