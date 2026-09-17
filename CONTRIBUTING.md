<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 LogiMentor -->

# Contributing

Contributions are welcome through pull requests.

Before opening a pull request, please run:

```bash
python scripts/check_repo_hygiene.py --no-history
python scripts/run_python_model_tests.py
python scripts/run_ghdl_tests.py
python scripts/run_ghdl_negative_tests.py
```

`run_ghdl_negative_tests.py` checks that the deliberately illegal generic
configurations under `sim/negative/` are each rejected with the expected
diagnostic. Those units are expected to fail and must not be added to
`scripts/run_ghdl_tests.py` or `sim/questasim/run_all.do`.

Install the local hooks with:

```bash
python -m pip install pre-commit
pre-commit install
pre-commit install --hook-type commit-msg
pre-commit install --hook-type pre-push
```

Keep changes focused, include or update self-checking testbenches for behavior changes, and keep generated tool output under `build/`.
