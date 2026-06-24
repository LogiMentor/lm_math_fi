// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 LogiMentor

// Node built-in test runner (no third-party deps). Replays the JSON golden
// vectors emitted by scripts/gen_js_golden_vectors.py and asserts the JS library
// reproduces every entry bit-for-bit (including the cases where fxpmath raises,
// which are recorded as expected-error vectors).
//
// Run with:  node --test js/test/golden.test.mjs

import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

import {
  FiFormat,
  fi,
  bits,
  raw,
  quantize,
  add,
  sub,
  mul,
  mult_add,
} from "../lm_math_fi.mjs";

const here = dirname(fileURLToPath(import.meta.url));
const vectorsPath = join(here, "..", "golden_vectors.json");
const doc = JSON.parse(readFileSync(vectorsPath, "utf-8"));

function asFmt(spec) {
  const [w, b, s] = spec;
  return new FiFormat(w, b, Boolean(s));
}

function asValue(valueSpec) {
  switch (valueSpec.t) {
    case "float":
      return Number(valueSpec.v);
    case "int":
      return BigInt(valueSpec.v);
    case "str":
      return String(valueSpec.v);
    default:
      throw new Error(`bad value spec ${JSON.stringify(valueSpec)}`);
  }
}

function buildCtor(ctor) {
  const fmt = asFmt(ctor.fmt);
  switch (ctor.ctor) {
    case "fi":
      return fi(asValue(ctor.value), fmt, {
        rounding: ctor.rounding ?? "trunc_bits",
        overflow: ctor.overflow ?? "wrap",
      });
    case "bits":
      return bits(ctor.value, fmt);
    case "raw":
      return raw(BigInt(ctor.value), fmt);
    default:
      throw new Error(`bad ctor ${ctor.ctor}`);
  }
}

function runOp(entry) {
  const s = entry.spec;
  switch (entry.op) {
    case "fi":
    case "bits":
    case "raw":
      return buildCtor(s);
    case "quantize":
      return quantize(buildCtor(s.source), asFmt(s.fmt), {
        rounding: s.rounding ?? "trunc_bits",
        overflow: s.overflow ?? "wrap",
      });
    case "add":
    case "sub":
    case "mul": {
      const fn = { add, sub, mul }[entry.op];
      return fn(buildCtor(s.left), buildCtor(s.right), asFmt(s.fmt), {
        rounding: s.rounding ?? "trunc_bits",
        overflow: s.overflow ?? "wrap",
      });
    }
    case "mult_add":
      return mult_add(
        buildCtor(s.left),
        buildCtor(s.right),
        buildCtor(s.addend),
        asFmt(s.fmt),
        {
          subtract: s.subtract ?? false,
          rounding: s.rounding ?? "trunc_bits",
          overflow: s.overflow ?? "wrap",
        }
      );
    default:
      throw new Error(`bad op ${entry.op}`);
  }
}

test(`golden vectors provenance (fxpmath ${doc.fxpmath_version})`, () => {
  assert.equal(doc.schema, "lm_math_fi.golden.v1");
  assert.equal(doc.fxpmath_version, "0.4.10");
  assert.equal(doc.count, doc.vectors.length);
  assert.ok(doc.count > 0);
});

test("golden vectors reproduce the Python/fxpmath model bit-for-bit", () => {
  let checked = 0;
  const failures = [];
  for (const entry of doc.vectors) {
    const e = entry.expect;
    // Expected-error vectors: fxpmath raised, so the JS port must throw AND the
    // thrown error's category must equal the category fxpmath's exception mapped
    // to. An unrelated JS error with the wrong category fails the vector.
    if (e.error) {
      const wantCategory = e.error.category;
      let caught;
      try {
        runOp(entry);
      } catch (err) {
        caught = err;
      }
      if (!caught) {
        failures.push(`#${entry.id} (${entry.op}, ${entry.note}): expected to throw (${wantCategory}) but returned a value`);
      } else if (caught.category !== wantCategory) {
        failures.push(
          `#${entry.id} (${entry.op}, ${entry.note}): threw category '${caught.category}' (${caught.message}) but expected '${wantCategory}'`
        );
      }
      checked++;
      continue;
    }
    let value;
    try {
      value = runOp(entry);
    } catch (err) {
      failures.push(`#${entry.id} (${entry.op}, ${entry.note}): threw ${err.message}`);
      continue;
    }
    const mismatches = [];
    if (value.bits !== e.bits) mismatches.push(`bits ${value.bits} != ${e.bits}`);
    if (value.raw_signed !== BigInt(e.raw_signed)) mismatches.push(`raw_signed ${value.raw_signed} != ${e.raw_signed}`);
    if (value.raw_unsigned !== BigInt(e.raw_unsigned)) mismatches.push(`raw_unsigned ${value.raw_unsigned} != ${e.raw_unsigned}`);
    if (value.hex !== e.hex) mismatches.push(`hex ${value.hex} != ${e.hex}`);
    // float: compare as IEEE-754 doubles (NaN/Inf do not occur in-domain).
    if (value.toFloat() !== e.float && !(Number.isNaN(value.toFloat()) && Number.isNaN(e.float))) {
      mismatches.push(`float ${value.toFloat()} != ${e.float}`);
    }
    if (mismatches.length) {
      failures.push(`#${entry.id} (${entry.op}, ${entry.note}): ${mismatches.join("; ")}`);
    }
    checked++;
  }
  if (failures.length) {
    const shown = failures.slice(0, 40).join("\n");
    assert.fail(`${failures.length}/${checked} vectors mismatched:\n${shown}`);
  }
});
