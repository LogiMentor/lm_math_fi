<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 LogiMentor -->

# Verification

## Gates

The public-release gate is:

```bash
python scripts/check_repo_hygiene.py --no-history
python scripts/run_python_model_tests.py
python scripts/run_ghdl_tests.py
python scripts/run_ghdl_negative_tests.py
python scripts/check_repo_hygiene.py --no-history
```

CI runs repository hygiene as a separate job with full ref inspection and runs
the GHDL regression, then the GHDL negative regression, with a post-regression
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
| Generic-domain rejection | out-of-domain signedness, rounding, overflow, direction and add/subtract selectors are rejected with a diagnostic naming the generic |

Generic-domain rejection is covered by the separate negative regression,
`scripts/run_ghdl_negative_tests.py`, which drives the units under
`sim/negative/`. Each of those units is expected to fail; the runner passes only
when the failure carries the diagnostic it expects for that case, so a case
cannot pass because the design broke for an unrelated reason.

VHDL assertions are a simulation and elaboration diagnostic. Most synthesis
tools ignore them, so these checks constrain what reaches simulation, not what
reaches a bitstream.

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
