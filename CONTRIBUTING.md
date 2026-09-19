<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 LogiMentor -->

# Contributing

Contributions are welcome through pull requests.

Before opening a pull request, please run:

```bash
python scripts/check_repo_hygiene.py --all-refs
python scripts/run_python_model_tests.py
python scripts/gen_js_golden_vectors.py --check
python scripts/run_ghdl_tests.py
python scripts/run_ghdl_generic_domain_tests.py
python scripts/check_repo_hygiene.py --no-history
node --test js/test/golden.test.mjs
```

That is every check CI runs on a push, in the order CI runs it, across all three
of its jobs. Running the list locally and running CI test the same things.

`run_ghdl_generic_domain_tests.py` gates the generic domains in both directions,
using the units under `sim/generic_domain/`: a legal value must never be
rejected, and an illegal one must be rejected, in the phase the case declares,
with a diagnostic that names the generic. It also re-runs
`scripts/gen_format_vectors.py --check`, so the committed expectations cannot
drift from the generator that produces them. The `tb_neg_*` units are expected
to fail once per case and must not be added to `scripts/run_ghdl_tests.py` or
`sim/questasim/run_all.do`.

If you change a gate, run `python scripts/check_gate_mutations.py`. It breaks the
repository in known ways and requires the gate to notice. It edits tracked files
while it runs, so it refuses to start unless your tree is clean, and it is not
part of CI.

Install the local hooks with:

```bash
python -m pip install pre-commit
pre-commit install
pre-commit install --hook-type commit-msg
pre-commit install --hook-type pre-push
```

Keep changes focused, include or update self-checking testbenches for behavior changes, and keep generated tool output under `build/`.
