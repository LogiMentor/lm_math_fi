# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 LogiMentor

from __future__ import annotations

import unittest

from lm_math_fi_model import FiFormat, add, bits, fi, mul, mult_add, quantize, raw, sub


class FiModelTest(unittest.TestCase):
    def test_bits_and_raw_values(self) -> None:
        fmt = FiFormat(width=5, binpnt=2, signed=True)
        value = bits("10111", fmt)

        self.assertEqual(value.bits, "10111")
        self.assertEqual(value.raw_signed, -9)
        self.assertEqual(value.raw_unsigned, 23)
        self.assertEqual(value.to_float(), -2.25)

    def test_trunc_uses_bit_truncation(self) -> None:
        source = bits("10111", FiFormat(width=5, binpnt=2, signed=True))
        result = quantize(source, FiFormat(width=5, binpnt=1, signed=True), rounding="trunc_bits")

        self.assertEqual(result.bits, "11011")
        self.assertEqual(result.to_float(), -2.5)

    def test_truncate_toward_zero(self) -> None:
        source = bits("10111", FiFormat(width=5, binpnt=2, signed=True))
        result = quantize(source, FiFormat(width=5, binpnt=1, signed=True), rounding="trunc_zero")

        self.assertEqual(result.bits, "11100")
        self.assertEqual(result.to_float(), -2.0)

    def test_signed_round_half_even(self) -> None:
        out_fmt = FiFormat(width=5, binpnt=1, signed=True)

        self.assertEqual(quantize(bits("10111", FiFormat(5, 2, True)), out_fmt, rounding="round").bits, "11100")
        self.assertEqual(quantize(bits("10101", FiFormat(5, 2, True)), out_fmt, rounding="round").bits, "11010")

    def test_rounding_tie_modes(self) -> None:
        out_fmt = FiFormat(width=5, binpnt=1, signed=True)
        pos = bits("01001", FiFormat(5, 2, True))
        neg = bits("10111", FiFormat(5, 2, True))

        self.assertEqual(quantize(pos, out_fmt, rounding="floor").bits, "00100")
        self.assertEqual(quantize(neg, out_fmt, rounding="ceil").bits, "11100")
        self.assertEqual(quantize(pos, out_fmt, rounding="round_pos_inf").bits, "00101")
        self.assertEqual(quantize(neg, out_fmt, rounding="round_pos_inf").bits, "11100")
        self.assertEqual(quantize(pos, out_fmt, rounding="round_neg_inf").bits, "00100")
        self.assertEqual(quantize(neg, out_fmt, rounding="round_neg_inf").bits, "11011")
        self.assertEqual(quantize(pos, out_fmt, rounding="round_zero").bits, "00100")
        self.assertEqual(quantize(neg, out_fmt, rounding="round_zero").bits, "11100")
        self.assertEqual(quantize(pos, out_fmt, rounding="round_away").bits, "00101")
        self.assertEqual(quantize(neg, out_fmt, rounding="round_away").bits, "11011")
        self.assertEqual(quantize(pos, out_fmt, rounding="round_inf").bits, "00101")
        self.assertEqual(quantize(neg, out_fmt, rounding="round_inf").bits, "11011")

    def test_unsigned_sub_wraps_in_full_precision(self) -> None:
        left = bits("0001", FiFormat(4, 0, False))
        right = bits("0011", FiFormat(4, 0, False))
        result = sub(left, right, FiFormat(5, 0, False))

        self.assertEqual(result.bits, "11110")

    def test_unsigned_to_signed_saturation(self) -> None:
        result = quantize(bits("1111", FiFormat(4, 0, False)), FiFormat(4, 0, True), overflow="saturate")

        self.assertEqual(result.bits, "0111")

    def test_unsigned_to_signed_widening_keeps_magnitude(self) -> None:
        result = quantize(bits("1111", FiFormat(4, 0, False)), FiFormat(5, 0, True), overflow="wrap")

        self.assertEqual(result.bits, "01111")

    def test_add_and_mul_match_rtl_vectors(self) -> None:
        self.assertEqual(add(raw(3, FiFormat(4, 1, False)), raw(5, FiFormat(4, 1, False)), FiFormat(5, 1, False)).bits, "01000")
        self.assertEqual(mul(raw(-3, FiFormat(4, 0, True)), raw(15, FiFormat(4, 0, False)), FiFormat(8, 0, True)).bits, "11010011")

    def test_fractional_mult_add_round_half_even(self) -> None:
        result = mult_add(
            fi(1.5, FiFormat(4, 2, False)),
            fi(0.75, FiFormat(4, 2, False)),
            fi(0.25, FiFormat(6, 2, False)),
            FiFormat(6, 2, False),
            rounding="round",
        )

        self.assertEqual(result.bits, "000110")


if __name__ == "__main__":
    unittest.main()
