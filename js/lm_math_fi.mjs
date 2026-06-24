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

    // String inputs. fxpmath.utils.str2num detects a binary literal when 'b' is in
    // the first two characters and a hex literal when 'x' is (after replacing 'h'
    // with 'x'); otherwise it is a base-10 literal parsed with Python int(x)/float(x).
    // Detection is case-sensitive, so uppercase prefixes ("0X", "0B") are NOT based
    // literals and reach the base-10 parser, which rejects them (Python int("0XF")
    // raises). Base-10 uses float(x) when the string has a '.' or n_frac > 0, else
    // int(x); _decToNumber / _decToBigInt reproduce Python's grammar (rejecting
    // radix prefixes and other non-decimal forms, accepting underscore separators).
    if (typeof value === "string") {
      const s = value.trim();
      const head = s.replace(/h/g, "x").slice(0, 2);
      if (head.includes("b") || head.includes("x")) {
        return FiValue._fromBased(s, fmt, method, ovf);
      }
      if (s.includes(".") || fmt.binpnt > 0) {
        return FiValue._fromFloat(_decToNumber(s), fmt, method, ovf);
      }
      return FiValue._fromInteger(_decToBigInt(s), fmt, fmt.binpnt, ovf);
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
  // rounding (the raw-domain value is already integral), then overflow. Uses the
  // integer-path domain guard so it raises exactly where fxpmath does.
  static _fromInteger(intVal, fmt, binpnt, ovf) {
    const cand = intVal << BigInt(binpnt);
    // conv_factor = 2**binpnt here, so the domain check is on intVal (pre-shift):
    // fxpmath's int64 multiply by 2**binpnt wraps silently rather than raising.
    return new FiValue(_storeIntegerCand(cand, fmt, ovf, intVal), fmt);
  }

  // Binary/hex based-literal path. Reproduces fxpmath.utils.str2num exactly via
  // the strbin2int / strbin2float / strhex2int / strhex2float rules (see
  // _basedToValue): short signed literals are SIGN-extended (hex is zero-padded
  // then interpreted in two's complement), over-wide literals are REJECTED, and a
  // binary point is honored.
  //   - integer literal (binpnt == 0, no '.'): exact, no float (lossless any width).
  //   - fractional literal (binpnt > 0 or '.'): parse the integer exactly then
  //     divide by 2**binpnt in float64, then run the standard float pipeline. This
  //     is float64-lossy above 2**53, reproducing fxpmath exactly.
  static _fromBased(litStr, fmt, method, ovf) {
    const parsed = _basedToValue(litStr, fmt);
    if (parsed.isFloat) {
      return FiValue._fromFloat(parsed.value, fmt, method, ovf);
    }
    // Exact integer literal. The integer-path domain check applies (it matches
    // fxpmath, though a width-bounded literal can never exceed it).
    return FiValue._fromInteger(parsed.value, fmt, fmt.binpnt, ovf);
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
    if (delta >= 0) {
      // Growing or keeping fractional bits: exact BigInt shift, no rounding
      // (fxpmath passes the resulting integer straight through _round). This is
      // the integer path, so the out-of-domain guard applies (e.g. narrowing a
      // >64-bit product into a sub-64-bit format raises, matching fxpmath).
      const cand = this._raw << BigInt(delta);
      return new FiValue(_storeIntegerCand(cand, fmt, ovf), fmt);
    }
    // Reducing fractional bits: fxpmath computes float(raw) * 2**delta in float64
    // then applies the rounding mode (lossy above 2**53). The float path never
    // raises OverflowError in fxpmath, so it uses the plain store.
    const scaled = Number(this._raw) * 2 ** delta;
    const cand = _floatToBigInt(_applyRound(scaled, method));
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

// Convert a digit string to a BigInt the way Python's int(str, base) does:
// single underscores are accepted as separators BETWEEN digits (never leading,
// trailing, or doubled) and stripped; anything else raises (matching the Python
// ValueError fxpmath surfaces). Used for both based literals and decimal input.
function _intFromDigits(digits, base) {
  const re = base === 2 ? /^[01](?:_?[01])*$/ : /^[0-9a-fA-F](?:_?[0-9a-fA-F])*$/;
  if (!re.test(digits)) {
    throw new Error(`invalid base-${base} digit string: ${digits}`);
  }
  return BigInt((base === 2 ? "0b" : "0x") + digits.replace(/_/g, ""));
}

// Base-10 parsing matching Python int(x) / float(x): a decimal grammar with
// optional sign and underscore separators between digits, and NO radix prefix
// (so "0XF", "0B1", "0o17" are rejected exactly as Python int()/float() reject
// them). These guard against JS BigInt()/Number() being more lenient.
const _DEC_GROUP = String.raw`\d(?:_?\d)*`;
const _DEC_INT_RE = new RegExp(`^[+-]?${_DEC_GROUP}$`);
const _DEC_FLOAT_RE = new RegExp(
  `^[+-]?(?:${_DEC_GROUP}(?:\\.(?:${_DEC_GROUP})?)?|\\.${_DEC_GROUP})(?:[eE][+-]?${_DEC_GROUP})?$`
);

function _decToBigInt(s) {
  const t = s.trim();
  if (!_DEC_INT_RE.test(t)) {
    throw new Error(`invalid decimal integer literal: ${s}`);
  }
  let clean = t.replace(/_/g, "");
  if (clean[0] === "+") clean = clean.slice(1); // BigInt() rejects a leading '+'
  return BigInt(clean);
}

function _decToNumber(s) {
  const t = s.trim();
  if (!_DEC_FLOAT_RE.test(t)) {
    throw new Error(`invalid decimal literal: ${s}`);
  }
  return Number(t.replace(/_/g, ""));
}

// fxpmath.utils.strbin2int: parse a binary literal to an exact integer (BigInt).
// Mirrors the length/sign rules precisely:
//   - strip "0b"/"b", spaces and "+"; a leading "-" sets an explicit sign;
//   - shorter than n_word: SIGN-extend (signed) or zero-extend (unsigned);
//   - longer than n_word: REJECT;
//   - signed values are interpreted in two's complement over n_word bits.
function _strbin2int(litStr, signed, nWord) {
  let x = litStr.replace(/0b/g, "b").replace(/b/g, "");
  x = x.replace(/ /g, "").replace(/\+/g, "");
  let sign = 1n;
  if (x[0] === "-") {
    sign = -1n;
    x = x.replace(/-/g, "");
  }
  if (x.length === 0) {
    throw new Error(`invalid binary literal: ${litStr}`);
  }
  // Underscores are kept here: fxpmath does not strip them before the length and
  // sign-extension logic (they count as characters, like Python's int(x, 2)), so
  // the digit count used for sign-extension includes them. They are consumed by
  // _intFromDigits at conversion. Invalid characters are rejected there too.
  if (x.length < nWord) {
    x = (signed ? x[0] : "0").repeat(nWord - x.length) + x;
  } else if (x.length > nWord) {
    throw new Error(`binary val has more bits (${x.length}) than word (${nWord})!`);
  }
  let val;
  if (signed) {
    if (x.length < 2) {
      throw new Error("signed binary with not enough bits!");
    }
    val = _intFromDigits(x.slice(1), 2); // Python int(x[1:], 2)
    if (x[0] === "1") {
      val = -((1n << BigInt(nWord - 1)) - val);
    }
  } else {
    val = _intFromDigits(x, 2); // Python int(x, 2)
  }
  return sign * val;
}

// fxpmath.utils.strbin2float: integer part via strbin2int over n_word bits (after
// padding the fractional part with trailing zeros up to n_frac), divided by
// 2**n_frac in float64 (lossy above 2**53). Returns a Number.
function _strbin2float(litStr, signed, nWord, nFrac) {
  let x = litStr;
  const dot = x.indexOf(".");
  if (dot !== -1) {
    const fracLen = x.length - dot - 1;
    const pad = nFrac - fracLen;
    if (pad > 0) x = x + "0".repeat(pad);
    x = x.replace(".", "");
  }
  const intVal = _strbin2int(x, signed, nWord);
  return Number(intVal) / 2 ** nFrac;
}

// fxpmath.utils.strhex2int: strip "0x", convert to binary, ZERO-pad to n_word,
// then interpret in two's complement via strbin2int (so a short hex literal is
// zero-extended, NOT sign-extended). Over-wide literals are rejected by strbin2int.
function _strhex2int(litStr, signed, nWord) {
  const body = litStr.replace(/0x/g, "");
  // fxpmath does int(body, 16) (consuming underscores, rejecting '.', etc.) then
  // converts to binary and zero-pads to n_word before the two's-complement read.
  let xbin = _intFromDigits(body, 16).toString(2);
  if (xbin.length < nWord) {
    xbin = "0".repeat(nWord - xbin.length) + xbin;
  }
  return _strbin2int("0b" + xbin, signed, nWord);
}

// fxpmath.utils.strhex2float: as strhex2int but divided by 2**n_frac in float64.
function _strhex2float(litStr, signed, nWord, nFrac) {
  const intVal = _strhex2int(litStr, signed, nWord);
  return Number(intVal) / 2 ** nFrac;
}

// Classify and parse a based literal (binary or hex) per fxpmath.utils.str2num.
// Returns { isFloat, value } where value is a BigInt (integer literal) or a Number
// (fractional literal). Throws (matching fxpmath) on over-wide or invalid input.
function _basedToValue(litStr, fmt) {
  const x = String(litStr).replace(/h/g, "x");
  const head = x.slice(0, 2);
  const binpnt = fmt.binpnt;
  if (head.includes("b")) {
    if (x.includes(".") || binpnt > 0) {
      return { isFloat: true, value: _strbin2float(x, fmt.signed, fmt.width, binpnt) };
    }
    return { isFloat: false, value: _strbin2int(x, fmt.signed, fmt.width) };
  }
  if (head.includes("x")) {
    if (binpnt > 0) {
      return { isFloat: true, value: _strhex2float(x, fmt.signed, fmt.width, binpnt) };
    }
    return { isFloat: false, value: _strhex2int(x, fmt.signed, fmt.width) };
  }
  throw new Error(`unsupported based literal: ${litStr}`);
}

// fxpmath raises OverflowError (overflow='wrap', target width < 64) when the value
// it stores as numpy int64/uint64 leaves the range numpy can cast: a value above
// uint64 max (> 2**64 - 1) or below int64 min (< -2**63). The check is on the value
// set_val sees BEFORE applying conv_factor:
//   - direct integer input: conv_factor = 2**binpnt, so the decision is on the raw
//     integer (the subsequent int64 multiply by 2**binpnt overflows SILENTLY,
//     wrapping mod 2**64 -- no error -- so e.g. fi((2**60)+1, (32,4)) returns 16);
//   - quantize of a fixed-point value: conv_factor = 1, so the decision is on the
//     already-scaled candidate (raw << delta).
// For width >= 64 fxpmath uses an object dtype (no overflow); saturate clips; and
// float-path values never reach this (they wrap/sentinel without raising). The
// stored value, when it does not raise, is always (candidate mod 2**width) because
// the int64/uint64 reinterpretation preserves the low `width` bits.
const _INT64_MIN = -(1n << 63n);
const _UINT64_MAX = (1n << 64n) - 1n;

function _storeIntegerCand(cand, fmt, ovf, checkValue = cand) {
  if (ovf === "wrap" && fmt.width < 64 && (checkValue > _UINT64_MAX || checkValue < _INT64_MIN)) {
    throw new RangeError(
      `out of fxpmath domain: storing an integer of ${checkValue < 0n ? "" : "+"}${checkValue} into a ` +
        `${fmt.width}-bit format exceeds the 64-bit integer range fxpmath casts through ` +
        `(fxpmath raises OverflowError here)`
    );
  }
  return _overflowStore(cand, fmt.width, fmt.signed, ovf);
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
