#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 LogiMentor

from __future__ import annotations

import pathlib
import sys
import unittest
import importlib.util


sys.dont_write_bytecode = True

ROOT = pathlib.Path(__file__).resolve().parents[1]
MODEL_DIR = ROOT / "model"


def main() -> int:
    if importlib.util.find_spec("fxpmath") is None:
        print(
            "error: missing Python dependency 'fxpmath'; run "
            "'python -m pip install -r requirements-dev.txt'",
            file=sys.stderr,
        )
        return 2

    sys.path.insert(0, str(MODEL_DIR))
    suite = unittest.defaultTestLoader.discover(str(MODEL_DIR / "tests"))
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    return 0 if result.wasSuccessful() else 1


if __name__ == "__main__":
    raise SystemExit(main())
