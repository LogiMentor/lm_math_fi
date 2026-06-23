// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 LogiMentor

/**
 * Fixed-point reference helpers for lm_math_fi — zero-dependency ES module port
 * of the Python model (model/lm_math_fi_model/__init__.py), itself a thin wrapper
 * over fxpmath==0.4.10.
 *
 * The public API mirrors the Python model exactly: `width` is the total number of
 * bits, `binpnt` is the number of fractional bits, and `signed` selects
 * two's-complement interpretation. The same friendly rounding keys and overflow
 * keys are accepted.
 *
 * GOAL: reproduce fxpmath's conversion pipeline BIT-FOR-BIT, including the places
 * where fxpmath is float64-lossy. We deliberately do NOT "improve" it to exact
 * arithmetic.
 *
 * fxpmath's decimal/float -> raw-integer step is: coerce the input to a float64,
 * compute `value * 2**n_frac` in float64 (multiplying a double by a power of two
 * only shifts the exponent, so it is exact), apply the rounding mode in float64,
 * then apply overflow (wrap/saturate) and mask to `n_word` bits. The only float64
 * error therefore comes from representing the input as a double. JS `Number` IS an
 * IEEE-754 double identical to numpy float64, and decimal-string -> double is
 * correctly rounded in both Python and JS, so the results match.
 *
 * SUPPORTED DOMAIN / HIGH-WIDTH BOUNDARY (matches fxpmath, reproduced not "fixed"):
 *   - Float / decimal input: lossless while the scaled raw magnitude stays within
 *     2**53. Above that the result is float64-lossy but DETERMINISTIC, and this
 *     port reproduces fxpmath's exact lossy result (it uses the same float64
 *     arithmetic) rather than diverging.
 *   - Integer input passed as a BigInt: exact at any magnitude (mirrors a Python
 *     `int`, which fxpmath keeps in integer/object form with no float step).
 *   - Integer input passed as a Number: takes the float path; this is safe because
 *     a JS Number cannot represent an exact integer above 2**53 in the first place.
 *   - Bit-string / raw input with binpnt == 0: exact at any width (fxpmath parses
 *     the integer exactly; verified lossless at 53/60/64/65 bits).
 *   - Bit-string / raw input with binpnt > 0: fxpmath parses the integer then does
 *     `int / 2**n_frac` in float64 (utils.strbin2float), so it is float64-lossy
 *     once the raw magnitude exceeds 2**53. This port reproduces that exact lossy
 *     behavior (e.g. an all-ones unsigned 54/4 value collapses to raw 0, matching
 *     fxpmath). Use widths <= 53 for fractional bit/raw input if losslessness is
 *     required.
 *   - Arithmetic intermediates (add/sub/mul/mult_add) are held exactly in BigInt.
 *     Requantization that REDUCES the number of fractional bits reproduces
 *     fxpmath's `float(intermediate_raw) * 2**delta` float64 step (lossy above
 *     2**53, deterministically); requantization that keeps or grows fractional
 *     bits is an exact BigInt shift.
 *
 * raw_signed / raw_unsigned return BigInt to preserve exactness for raws wider
 * than 53 bits. `bits` and `hex` are strings; `toFloat()` returns a Number.
 */

// Friendly rounding keys -> fxpmath canonical names. Mirror of ROUNDING_MAP in the
// Python model. (fxpmath further aliases "nearest_even" -> numpy "around"; we
// implement that round-half-to-even directly below.)
const ROUNDING_MAP = {
  trunc_bits: "bit_trunc",
  trunc: "bit_trunc",
  bit_trunc: "bit_trunc",
  trunc_zero: "trunc",
  fix: "fix",
  round: "nearest_even",
  round_even: "nearest_even",
  nearest_even: "nearest_even",
  round_pos_inf: "nearest_posinf",
  nearest_posinf: "nearest_posinf",
  round_neg_inf: "nearest_neginf",
  nearest_neginf: "nearest_neginf",
  round_zero: "nearest_zero",
  nearest_zero: "nearest_zero",
  round_away: "nearest_away",
  nearest_away: "nearest_away",
  round_inf: "nearest_away",
  floor: "floor",
  ceil: "ceil",
};

const OVERFLOW_SET = new Set(["wrap", "saturate"]);

function _mapRounding(rounding) {
  if (!Object.prototype.hasOwnProperty.call(ROUNDING_MAP, rounding)) {
    const allowed = Object.keys(ROUNDING_MAP).sort().join(", ");
    throw new Error(`unsupported rounding mode '${rounding}'; expected one of: ${allowed}`);
  }
  return ROUNDING_MAP[rounding];
}

function _mapOverflow(overflow) {
  if (!OVERFLOW_SET.has(overflow)) {
    const allowed = Array.from(OVERFLOW_SET).sort().join(", ");
    throw new Error(`unsupported overflow mode '${overflow}'; expected one of: ${allowed}`);
  }
  return overflow;
}

/**
 * Apply a fxpmath canonical rounding mode to a float64 value, returning an
 * integer-valued Number. Mirrors fxpmath.objects.Fxp._round exactly:
 *   - bit_trunc / floor  -> np.floor (toward -infinity)
 *   - ceil               -> np.ceil
 *   - trunc / fix        -> toward zero (np.trunc == np.fix for real scalars)
 *   - nearest_even       -> round half to EVEN (numpy "around"/rint)
 *   - nearest_{posinf,neginf,zero,away} -> explicit tie rules on frac == 0.5
 */
function _applyRound(val, method) {
  switch (method) {
    case "bit_trunc":
    case "floor":
      return Math.floor(val);
    case "ceil":
      return Math.ceil(val);
    case "trunc":
    case "fix":
      return Math.trunc(val);
    case "nearest_even": {
      const f = Math.floor(val);
      const frac = val - f;
      if (frac < 0.5) return f;
      if (frac > 0.5) return f + 1;
      // exact tie: round to the even neighbor
      return f % 2 === 0 ? f : f + 1;
    }
    case "nearest_posinf":
    case "nearest_neginf":
    case "nearest_zero":
    case "nearest_away": {
      const f = Math.floor(val);
      const frac = val - f;
      const gt = frac > 0.5;
      const eq = frac === 0.5;
      let inc;
      if (method === "nearest_posinf") inc = gt || eq;
      else if (method === "nearest_neginf") inc = gt;
      else if (method === "nearest_zero") inc = gt || (eq && val < 0);
      else inc = gt || (eq && val >= 0); // nearest_away
      return inc ? f + 1 : f;
    }
    default:
      throw new Error(`<${method}> rounding method not valid!`);
  }
}

// Convert an integer-valued Number (output of _applyRound) to an exact BigInt.
// `r` is always integral here, so BigInt(r) yields the exact integer the double
// represents (matching numpy's float64 -> int64 cast for integral values).
function _floatToBigInt(r) {
  // Guard against -0 and ensure exact integral input.
  if (!Number.isFinite(r)) {
    throw new Error(`non-finite intermediate value: ${r}`);
  }
  return BigInt(r === 0 ? 0 : r);
}

/**
 * Apply overflow handling to a candidate raw BigInt and return the stored value in
 * the target format's natural representation (signed two's-complement value for a
 * signed format, non-negative for an unsigned format). Mirrors
 * fxpmath.objects.Fxp._overflow_action followed by the int cast.
 *
 * For saturate, fxpmath clips the float64 against integer bounds; comparing the
 * exact integer value of the (integral) rounded double against exact BigInt bounds
 * is identical to Python's exact float-vs-int comparison.
 */
function _overflowStore(cand, width, signed, overflow) {
  const mod = 1n << BigInt(width);
  if (overflow === "wrap") {
    let u = ((cand % mod) + mod) % mod; // unsigned, masked to width bits
    if (signed && u >= mod >> 1n) return u - mod;
    return u;
  }
  // saturate
  let vmax;
  let vmin;
  if (signed) {
    vmax = (1n << BigInt(width - 1)) - 1n;
    vmin = -(1n << BigInt(width - 1));
  } else {
    vmax = mod - 1n;
    vmin = 0n;
  }
  if (cand > vmax) return vmax;
  if (cand < vmin) return vmin;
  return cand;
}

function _checkFmt(width, binpnt) {
  if (!Number.isInteger(width) || width <= 0) {
    throw new Error("width must be a positive integer");
  }
  if (!Number.isInteger(binpnt) || binpnt < 0) {
    throw new Error("binpnt must be a non-negative integer");
  }
}

export class FiFormat {
  constructor(width, binpnt, signed = true) {
    _checkFmt(width, binpnt);
    this.width = width;
    this.binpnt = binpnt;
    this.signed = Boolean(signed);
    Object.freeze(this);
  }
}

// Coerce a FiFormat-like argument (FiFormat instance or {width, binpnt, signed})
// into a FiFormat.
function _asFmt(fmt) {
  if (fmt instanceof FiFormat) return fmt;
  if (fmt && typeof fmt === "object" && "width" in fmt && "binpnt" in fmt) {
    return new FiFormat(fmt.width, fmt.binpnt, "signed" in fmt ? fmt.signed : true);
  }
  throw new Error("format must be a FiFormat or {width, binpnt, signed}");
}

export class FiValue {
  /**
   * @param {bigint} rawSigned Stored raw value in the format's natural form
   *   (signed two's-complement value for signed; non-negative for unsigned).
   * @param {FiFormat} fmt
   */
  constructor(rawSigned, fmt) {
    this._raw = rawSigned; // BigInt
    this.fmt = fmt;
    Object.freeze(this);
  }

  // ---- constructors -------------------------------------------------------

  static fromValue(value, fmt, { rounding = "trunc_bits", overflow = "wrap" } = {}) {
    fmt = _asFmt(fmt);
    const method = _mapRounding(rounding);
    const ovf = _mapOverflow(overflow);

    // FiValue -> requantize (fxpmath Fxp-input path).
    if (value instanceof FiValue) {
      return value.quantize(fmt, { rounding, overflow });
    }

    // String inputs: based literals route through the bit/raw parser; decimal
    // strings route through the float path (or exact-integer path, mirroring
    // fxpmath.utils.str2num which uses int(x) only when no '.' and n_frac == 0).
    if (typeof value === "string") {
      const s = value.trim();
      const low = s.toLowerCase();
      if (low.startsWith("0b") || low.startsWith("0x") || low.startsWith("-0b") || low.startsWith("-0x")) {
        return FiValue._fromBased(s, fmt, method, ovf);
      }
      if (s.includes(".") || /[eE]/.test(s) || fmt.binpnt > 0) {
        return FiValue._fromFloat(Number(s), fmt, method, ovf);
      }
      return FiValue._fromInteger(BigInt(s), fmt, fmt.binpnt, ovf);
    }

    // BigInt -> exact integer input (mirrors a Python int: no float, no rounding).
    if (typeof value === "bigint") {
      return FiValue._fromInteger(value, fmt, fmt.binpnt, ovf);
    }

    // Number -> float64 path.
    if (typeof value === "number") {
      return FiValue._fromFloat(value, fmt, method, ovf);
    }

    throw new Error(`unsupported input type: ${typeof value}`);
  }

  static fromBits(bitsStr, fmt) {
    fmt = _asFmt(fmt);
    const clean = String(bitsStr).replace(/_/g, "");
    if (clean.length !== fmt.width) {
      throw new Error("bit string length does not match format width");
    }
    if (!/^[01]+$/.test(clean)) {
      throw new Error("bit string must contain only 0 or 1");
    }
    // Mirror the Python model: from_bits -> from_value("0b" + bits) with default
    // rounding=trunc_bits, overflow=wrap.
    return FiValue._fromBased("0b" + clean, fmt, _mapRounding("trunc_bits"), "wrap");
  }

  static fromRaw(rawValue, fmt) {
    fmt = _asFmt(fmt);
    const mod = 1n << BigInt(fmt.width);
    const u = ((BigInt(rawValue) % mod) + mod) % mod; // raw_value & mask
    const bitsStr = u.toString(2).padStart(fmt.width, "0");
    return FiValue.fromBits(bitsStr, fmt);
  }

  // ---- internal conversion paths -----------------------------------------

  // Float64 path: coerce to Number, scale by 2**binpnt in float64, round, overflow.
  static _fromFloat(num, fmt, method, ovf) {
    const scaled = num * 2 ** fmt.binpnt; // exact exponent shift (power of two)
    const r = _applyRound(scaled, method);
    const cand = _floatToBigInt(r);
    return new FiValue(_overflowStore(cand, fmt.width, fmt.signed, ovf), fmt);
  }

  // Exact-integer path (Python int input): scale by an exact BigInt shift, no
  // rounding (the raw-domain value is already integral), then overflow.
  static _fromInteger(intVal, fmt, binpnt, ovf) {
    const cand = intVal << BigInt(binpnt);
    return new FiValue(_overflowStore(cand, fmt.width, fmt.signed, ovf), fmt);
  }

  // Binary/hex based-literal path. Reproduces fxpmath.utils.str2num:
  //   - binpnt == 0 (integer literal): parse exactly, no float (lossless any width).
  //   - binpnt  > 0 (fractional literal): parse the integer exactly then divide by
  //     2**binpnt in float64 (strbin2float), then run the standard float pipeline
  //     with the supplied rounding/overflow. This is float64-lossy above 2**53,
  //     reproducing fxpmath exactly.
  static _fromBased(litStr, fmt, method, ovf) {
    let s = litStr.trim();
    let neg = false;
    if (s[0] === "+" || s[0] === "-") {
      neg = s[0] === "-";
      s = s.slice(1);
    }
    const low = s.toLowerCase();
    let signedRaw; // exact BigInt value as interpreted by fxpmath
    if (low.startsWith("0b")) {
      const body = s.slice(2);
      const u = BigInt("0b" + body);
      // Signed two's-complement interpretation only when the literal width
      // matches the format width (the from_bits/from_raw case). fxpmath's
      // strbin2int sign-extends/interprets using n_word.
      signedRaw = _interpretSigned(u, body.length, fmt);
    } else if (low.startsWith("0x")) {
      const body = s.slice(2);
      const u = BigInt("0x" + body);
      signedRaw = _interpretSigned(u, body.length * 4, fmt);
    } else {
      throw new Error(`unsupported based literal: ${litStr}`);
    }
    if (neg) signedRaw = -signedRaw;

    if (fmt.binpnt === 0) {
      // Integer literal: exact, no float step.
      const cand = signedRaw; // floor of an integer is itself
      return new FiValue(_overflowStore(cand, fmt.width, fmt.signed, ovf), fmt);
    }
    // Fractional literal: float64 round-trip (lossy above 2**53), matching fxpmath.
    const f = Number(signedRaw) / 2 ** fmt.binpnt; // strbin2float: val /= 2**n_frac
    return FiValue._fromFloat(f, fmt, method, ovf);
  }

  // ---- accessors ----------------------------------------------------------

  get bits() {
    return this.raw_unsigned.toString(2).padStart(this.fmt.width, "0");
  }

  get raw_signed() {
    return this._raw;
  }

  get raw_unsigned() {
    const mod = 1n << BigInt(this.fmt.width);
    return ((this._raw % mod) + mod) % mod;
  }

  get hex() {
    const digits = Math.ceil(this.fmt.width / 4);
    return "0x" + this.raw_unsigned.toString(16).toUpperCase().padStart(digits, "0");
  }

  toFloat() {
    return Number(this._raw) / 2 ** this.fmt.binpnt;
  }

  // ---- operations ---------------------------------------------------------

  quantize(fmt, { rounding = "trunc_bits", overflow = "wrap" } = {}) {
    fmt = _asFmt(fmt);
    const method = _mapRounding(rounding);
    const ovf = _mapOverflow(overflow);
    const delta = fmt.binpnt - this.fmt.binpnt;
    let cand;
    if (delta >= 0) {
      // Growing or keeping fractional bits: exact BigInt shift, no rounding
      // (fxpmath passes the resulting integer straight through _round).
      cand = this._raw << BigInt(delta);
    } else {
      // Reducing fractional bits: fxpmath computes float(raw) * 2**delta in
      // float64 then applies the rounding mode (lossy above 2**53).
      const scaled = Number(this._raw) * 2 ** delta;
      cand = _floatToBigInt(_applyRound(scaled, method));
    }
    return new FiValue(_overflowStore(cand, fmt.width, fmt.signed, ovf), fmt);
  }

  // Full-precision add/sub mirroring fxpmath's growing-format arithmetic. The
  // result format is sized as fxpmath sizes it:
  //   n_frac = max(a.n_frac, b.n_frac)
  //   n_int  = max(a.n_int, b.n_int) + 1
  //   signed = a.signed || b.signed
  // The exact value is then STORED WRAPPED into that format. This matters for
  // unsigned results: a subtraction that goes negative wraps at the intermediate
  // width (e.g. unsigned 0 - 0.5 -> raw -1 -> wraps to the unsigned intermediate),
  // exactly as fxpmath does, and that wrapped value is what later requantizes.
  _combineAdd(other, subtract) {
    const nfrac = Math.max(this.fmt.binpnt, other.fmt.binpnt);
    const nint = Math.max(_nint(this.fmt), _nint(other.fmt)) + 1;
    const signed = this.fmt.signed || other.fmt.signed;
    const a = this._raw << BigInt(nfrac - this.fmt.binpnt);
    const b = other._raw << BigInt(nfrac - other.fmt.binpnt);
    const exact = subtract ? a - b : a + b;
    return _intermediate(exact, nint, nfrac, signed);
  }

  add(other) {
    return this._combineAdd(other, false);
  }

  sub(other) {
    return this._combineAdd(other, true);
  }

  // Full-precision multiply mirroring fxpmath's sizing:
  //   n_frac = a.n_frac + b.n_frac
  //   n_int  = a.n_int + b.n_int + (a.signed && b.signed ? 1 : 0)
  //   signed = a.signed || b.signed
  // The product always fits this format, so the wrap is an identity here.
  mul(other) {
    const nfrac = this.fmt.binpnt + other.fmt.binpnt;
    const nint = _nint(this.fmt) + _nint(other.fmt) + (this.fmt.signed && other.fmt.signed ? 1 : 0);
    const signed = this.fmt.signed || other.fmt.signed;
    const exact = this._raw * other._raw;
    return _intermediate(exact, nint, nfrac, signed);
  }
}

// Integer-bit count of a fixed-point format (matches fxpmath's n_int):
// n_int = n_word - n_frac - (sign bit).
function _nint(fmt) {
  return fmt.width - fmt.binpnt - (fmt.signed ? 1 : 0);
}

// Interpret an unsigned BigInt of `nbits` bits as the value fxpmath's strbin2int
// would produce for the given format: signed two's-complement when the format is
// signed (using the format width when the literal is at least that wide).
function _interpretSigned(u, nbits, fmt) {
  if (!fmt.signed) return u;
  const w = fmt.width;
  // fxpmath sign-extends a shorter literal with the sign bit, or interprets a
  // width-matched literal in two's complement over n_word bits.
  const bits = Math.max(nbits, w);
  const mod = 1n << BigInt(bits);
  if (u >= mod >> 1n) return u - mod;
  return u;
}

// Build an intermediate (un-quantized) FiValue in fxpmath's grown result format
// (n_int, n_frac, signed). The exact value is stored WRAPPED into that format,
// matching how fxpmath stores the result of an arithmetic op before the caller
// requantizes it. Operands carry the default 'wrap' overflow, so intermediates
// wrap (verified against the model, e.g. unsigned subtraction going negative).
function _intermediate(exact, nint, nfrac, signed) {
  const width = nint + nfrac + (signed ? 1 : 0);
  const stored = _overflowStore(exact, width, signed, "wrap");
  return new FiValue(stored, new FiFormat(width, nfrac, signed));
}

// ---- module-level functions (mirror the Python model API) -----------------

export function fi(value, fmt, opts = {}) {
  return FiValue.fromValue(value, fmt, opts);
}

export function bits(bitsValue, fmt) {
  return FiValue.fromBits(bitsValue, fmt);
}

export function raw(rawValue, fmt) {
  return FiValue.fromRaw(rawValue, fmt);
}

export function quantize(value, fmt, opts = {}) {
  return value.quantize(fmt, opts);
}

export function add(left, right, fmt, opts = {}) {
  return left.add(right).quantize(fmt, opts);
}

export function sub(left, right, fmt, opts = {}) {
  return left.sub(right).quantize(fmt, opts);
}

export function mul(left, right, fmt, opts = {}) {
  return left.mul(right).quantize(fmt, opts);
}

export function mult_add(left, right, addend, fmt, opts = {}) {
  const { subtract = false, ...qopts } = opts;
  const product = left.mul(right);
  const result = subtract ? product.sub(addend) : product.add(addend);
  return result.quantize(fmt, qopts);
}

export { ROUNDING_MAP };
