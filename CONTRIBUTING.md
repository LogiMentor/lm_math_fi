<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 LogiMentor -->

# Contributing

Contributions are welcome through pull requests.

Before opening a pull request, please run:

```bash
python scripts/check_repo_hygiene.py --no-history
python scripts/run_python_model_tests.py
python scripts/run_ghdl_tests.py
```

Install the local hooks with:

```bash
python -m pip install pre-commit
pre-commit install
pre-commit install --hook-type commit-msg
pre-commit install --hook-type pre-push
```

Keep changes focused, include or update self-checking testbenches for behavior changes, and keep generated tool output under `build/`.
