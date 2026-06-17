# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 LogiMentor

"""Fixed-point reference helpers for lm_math_fi.

The public API uses the same format vocabulary as the VHDL library:
``width`` is the total number of bits, ``binpnt`` is the number of
fractional bits, and ``signed`` selects two's-complement interpretation.
"""

from __future__ import annotations

from dataclasses import dataclass
import warnings
from typing import Any

from fxpmath import Fxp


ROUNDING_MAP = {
    "trunc_bits": "bit_trunc",
    "trunc": "bit_trunc",
    "bit_trunc": "bit_trunc",
    "trunc_zero": "trunc",
    "fix": "fix",
    "round": "nearest_even",
    "round_even": "nearest_even",
    "nearest_even": "nearest_even",
    "round_pos_inf": "nearest_posinf",
    "nearest_posinf": "nearest_posinf",
    "round_neg_inf": "nearest_neginf",
    "nearest_neginf": "nearest_neginf",
    "round_zero": "nearest_zero",
    "nearest_zero": "nearest_zero",
    "round_away": "nearest_away",
    "nearest_away": "nearest_away",
    "round_inf": "nearest_away",
    "floor": "floor",
    "ceil": "ceil",
}

OVERFLOW_MAP = {
    "wrap": "wrap",
    "saturate": "saturate",
}


@dataclass(frozen=True)
class FiFormat:
    width: int
    binpnt: int
    signed: bool = True

    def __post_init__(self) -> None:
        if self.width <= 0:
            raise ValueError("width must be positive")
        if self.binpnt < 0:
            raise ValueError("binpnt must be non-negative")


@dataclass(frozen=True)
class FiValue:
    value: Fxp
    fmt: FiFormat

    @classmethod
    def from_value(
        cls,
        value: Any,
        fmt: FiFormat,
        *,
        rounding: str = "trunc_bits",
        overflow: str = "wrap",
    ) -> "FiValue":
        return cls(_to_fxp(value, fmt, rounding=rounding, overflow=overflow), fmt)

    @classmethod
    def from_bits(cls, bits: str, fmt: FiFormat) -> "FiValue":
        clean_bits = bits.replace("_", "")
        if len(clean_bits) != fmt.width:
            raise ValueError("bit string length does not match format width")
        if any(bit not in "01" for bit in clean_bits):
            raise ValueError("bit string must contain only 0 or 1")
        return cls.from_value("0b" + clean_bits, fmt)

    @classmethod
    def from_raw(cls, raw_value: int, fmt: FiFormat) -> "FiValue":
        mask = (1 << fmt.width) - 1
        return cls.from_bits(format(raw_value & mask, f"0{fmt.width}b"), fmt)

    @property
    def bits(self) -> str:
        return self.value.bin(frac_dot=False).replace(".", "")

    @property
    def raw_signed(self) -> int:
        return int(self.value.val)

    @property
    def raw_unsigned(self) -> int:
        return self.raw_signed & ((1 << self.fmt.width) - 1)

    def to_float(self) -> float:
        return float(self.value)

    def quantize(
        self,
        fmt: FiFormat,
        *,
        rounding: str = "trunc_bits",
        overflow: str = "wrap",
    ) -> "FiValue":
        return FiValue.from_value(self.value, fmt, rounding=rounding, overflow=overflow)

    def __add__(self, other: "FiValue") -> "FiValue":
        return _from_fxp(_quiet_fxp_op(lambda: self.value + other.value))

    def __sub__(self, other: "FiValue") -> "FiValue":
        return _from_fxp(_quiet_fxp_op(lambda: self.value - other.value))

    def __mul__(self, other: "FiValue") -> "FiValue":
        return _from_fxp(_quiet_fxp_op(lambda: self.value * other.value))


def fi(
    value: Any,
    fmt: FiFormat,
    *,
    rounding: str = "trunc_bits",
    overflow: str = "wrap",
) -> FiValue:
    return FiValue.from_value(value, fmt, rounding=rounding, overflow=overflow)


def bits(bits_value: str, fmt: FiFormat) -> FiValue:
    return FiValue.from_bits(bits_value, fmt)


def raw(raw_value: int, fmt: FiFormat) -> FiValue:
    return FiValue.from_raw(raw_value, fmt)


def quantize(
    value: FiValue,
    fmt: FiFormat,
    *,
    rounding: str = "trunc_bits",
    overflow: str = "wrap",
) -> FiValue:
    return value.quantize(fmt, rounding=rounding, overflow=overflow)


def add(
    left: FiValue,
    right: FiValue,
    fmt: FiFormat,
    *,
    rounding: str = "trunc_bits",
    overflow: str = "wrap",
) -> FiValue:
    return (left + right).quantize(fmt, rounding=rounding, overflow=overflow)


def sub(
    left: FiValue,
    right: FiValue,
    fmt: FiFormat,
    *,
    rounding: str = "trunc_bits",
    overflow: str = "wrap",
) -> FiValue:
    return (left - right).quantize(fmt, rounding=rounding, overflow=overflow)


def mul(
    left: FiValue,
    right: FiValue,
    fmt: FiFormat,
    *,
    rounding: str = "trunc_bits",
    overflow: str = "wrap",
) -> FiValue:
    return (left * right).quantize(fmt, rounding=rounding, overflow=overflow)


def mult_add(
    left: FiValue,
    right: FiValue,
    addend: FiValue,
    fmt: FiFormat,
    *,
    subtract: bool = False,
    rounding: str = "trunc_bits",
    overflow: str = "wrap",
) -> FiValue:
    product = left * right
    result = product - addend if subtract else product + addend
    return result.quantize(fmt, rounding=rounding, overflow=overflow)


def _to_fxp(value: Any, fmt: FiFormat, *, rounding: str, overflow: str) -> Fxp:
    return Fxp(
        value,
        signed=fmt.signed,
        n_word=fmt.width,
        n_frac=fmt.binpnt,
        overflow=_map_overflow(overflow),
        rounding=_map_rounding(rounding),
    )


def _from_fxp(value: Fxp) -> FiValue:
    fmt = FiFormat(width=int(value.n_word), binpnt=int(value.n_frac), signed=bool(value.signed))
    return FiValue(value, fmt)


def _quiet_fxp_op(callback: Any) -> Fxp:
    with warnings.catch_warnings():
        warnings.simplefilter("ignore", RuntimeWarning)
        return callback()


def _map_rounding(rounding: str) -> str:
    try:
        return ROUNDING_MAP[rounding]
    except KeyError as exc:
        allowed = ", ".join(sorted(ROUNDING_MAP))
        raise ValueError(f"unsupported rounding mode {rounding!r}; expected one of: {allowed}") from exc


def _map_overflow(overflow: str) -> str:
    try:
        return OVERFLOW_MAP[overflow]
    except KeyError as exc:
        allowed = ", ".join(sorted(OVERFLOW_MAP))
        raise ValueError(f"unsupported overflow mode {overflow!r}; expected one of: {allowed}") from exc
