<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 LogiMentor -->

# Contributing

Contributions are welcome through pull requests.

Before opening a pull request, please run:

```bash
python scripts/check_repo_hygiene.py --no-history
python scripts/run_python_model_tests.py
python scripts/run_ghdl_tests.py
python scripts/run_ghdl_generic_domain_tests.py
```

`run_ghdl_generic_domain_tests.py` gates the generic domains in both
directions, using the units under `sim/generic_domain/`: a legal value must
never be rejected, and an illegal one must be rejected with a diagnostic that
names the generic. The `tb_neg_*` units there are expected to fail once per
case and must not be added to `scripts/run_ghdl_tests.py` or
`sim/questasim/run_all.do`.

Install the local hooks with:

```bash
python -m pip install pre-commit
pre-commit install
pre-commit install --hook-type commit-msg
pre-commit install --hook-type pre-push
```

Keep changes focused, include or update self-checking testbenches for behavior changes, and keep generated tool output under `build/`.
