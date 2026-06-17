-- SPDX-License-Identifier: Apache-2.0
-- Copyright 2026 LogiMentor

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library lm_math_fi_lib;
use lm_math_fi_lib.lm_math_fi_pkg.all;
use lm_math_fi_lib.tb_lm_math_fi_test_pkg.all;

entity tb_lm_math_fi_pkg is
end entity tb_lm_math_fi_pkg;

architecture a_tb of tb_lm_math_fi_pkg is
begin
  proc_main : process
  begin
    p_check_int(f_lm_max(-3, 7), 7, "f_lm_max positive side");
    p_check_int(f_lm_max(-3, -9), -3, "f_lm_max negative side");

    p_check_slv(f_lm_uns_to_slv(f_lm_slv_to_uns("1010")), "1010", "unsigned conversion round-trip");
    p_check_slv(f_lm_sig_to_slv(f_lm_slv_to_sig("1010")), "1010", "signed conversion round-trip");

    p_check_slv(f_lm_add_sig(f_slv_s(-2, 4), f_slv_s(3, 4), 5), f_slv_s(1, 5), "signed add with resize");
    p_check_slv(f_lm_sub_sig(f_slv_s(-2, 4), f_slv_s(3, 4), 5), f_slv_s(-5, 5), "signed sub with resize");
    p_check_slv(f_lm_add_uns(f_slv_u(15, 4), f_slv_u(1, 4), 5), f_slv_u(16, 5), "unsigned add with carry");
    p_check_slv(f_lm_sub_uns(f_slv_u(1, 4), f_slv_u(3, 4), 4), f_slv_u(14, 4), "unsigned sub wrap");

    p_check_slv(f_lm_zero_ext("101", 5), "00101", "zero extend");
    p_check_slv(f_lm_sign_ext("101", 5), "11101", "sign extend");
    p_check_slv(f_lm_pad_lsb("101", 5), "10100", "pad LSB");
    p_check_slv(f_lm_align("1011", 5, 3, 2, C_LM_UNSIGNED), "10110", "align with fractional padding");

    p_check_slv(f_lm_trunc_bits("1011", 4, 2, C_LM_UNSIGNED, 3, 1, C_LM_UNSIGNED), "101", "bit truncate unsigned");
    p_check_slv(f_lm_round_even("1001", 4, 2, C_LM_UNSIGNED, 3, 1, C_LM_UNSIGNED), "100", "round half to even down");
    p_check_slv(f_lm_round_even("1011", 4, 2, C_LM_UNSIGNED, 3, 1, C_LM_UNSIGNED), "110", "round half to even up");
    p_check_slv(f_lm_round_even(f_slv_s(-9, 5), 5, 2, C_LM_SIGNED, 5, 1, C_LM_SIGNED),
                f_slv_s(-4, 5), "signed round half to even toward zero");
    p_check_slv(f_lm_round_even(f_slv_s(-11, 5), 5, 2, C_LM_SIGNED, 5, 1, C_LM_SIGNED),
                f_slv_s(-6, 5), "signed round half to even away from zero");
    p_check_slv(f_lm_round_ceil("1001", 4, 2, C_LM_UNSIGNED, 3, 1, C_LM_UNSIGNED), "101", "round unsigned toward infinity");

    p_check_slv(f_lm_quantize(f_slv_s(-9, 5), 5, 1, C_LM_SIGNED, 5, 2, C_LM_SIGNED,
                               C_LM_TRUNC_BITS, C_LM_WRAP),
                f_slv_s(-5, 5), "signed bit truncate drops LSBs");
    p_check_slv(f_lm_quantize(f_slv_s(-9, 5), 5, 1, C_LM_SIGNED, 5, 2, C_LM_SIGNED,
                               C_LM_TRUNC_ZERO, C_LM_WRAP),
                f_slv_s(-4, 5), "signed truncate toward zero");
    p_check_slv(f_lm_quantize(f_slv_s(9, 5), 5, 1, C_LM_SIGNED, 5, 2, C_LM_SIGNED,
                               C_LM_FLOOR, C_LM_WRAP),
                f_slv_s(4, 5), "signed floor positive tie");
    p_check_slv(f_lm_quantize(f_slv_s(-9, 5), 5, 1, C_LM_SIGNED, 5, 2, C_LM_SIGNED,
                               C_LM_CEIL, C_LM_WRAP),
                f_slv_s(-4, 5), "signed ceil negative tie");
    p_check_slv(f_lm_quantize(f_slv_s(9, 5), 5, 1, C_LM_SIGNED, 5, 2, C_LM_SIGNED,
                               C_LM_ROUND_POS_INF, C_LM_WRAP),
                f_slv_s(5, 5), "round tie toward positive infinity positive");
    p_check_slv(f_lm_quantize(f_slv_s(-9, 5), 5, 1, C_LM_SIGNED, 5, 2, C_LM_SIGNED,
                               C_LM_ROUND_POS_INF, C_LM_WRAP),
                f_slv_s(-4, 5), "round tie toward positive infinity negative");
    p_check_slv(f_lm_quantize(f_slv_s(9, 5), 5, 1, C_LM_SIGNED, 5, 2, C_LM_SIGNED,
                               C_LM_ROUND_NEG_INF, C_LM_WRAP),
                f_slv_s(4, 5), "round tie toward negative infinity positive");
    p_check_slv(f_lm_quantize(f_slv_s(-9, 5), 5, 1, C_LM_SIGNED, 5, 2, C_LM_SIGNED,
                               C_LM_ROUND_NEG_INF, C_LM_WRAP),
                f_slv_s(-5, 5), "round tie toward negative infinity negative");
    p_check_slv(f_lm_quantize(f_slv_s(9, 5), 5, 1, C_LM_SIGNED, 5, 2, C_LM_SIGNED,
                               C_LM_ROUND_ZERO, C_LM_WRAP),
                f_slv_s(4, 5), "round tie toward zero positive");
    p_check_slv(f_lm_quantize(f_slv_s(-9, 5), 5, 1, C_LM_SIGNED, 5, 2, C_LM_SIGNED,
                               C_LM_ROUND_ZERO, C_LM_WRAP),
                f_slv_s(-4, 5), "round tie toward zero negative");
    p_check_slv(f_lm_quantize(f_slv_s(9, 5), 5, 1, C_LM_SIGNED, 5, 2, C_LM_SIGNED,
                               C_LM_ROUND_AWAY, C_LM_WRAP),
                f_slv_s(5, 5), "round tie away from zero positive");
    p_check_slv(f_lm_quantize(f_slv_s(-9, 5), 5, 1, C_LM_SIGNED, 5, 2, C_LM_SIGNED,
                               C_LM_ROUND_AWAY, C_LM_WRAP),
                f_slv_s(-5, 5), "round tie away from zero negative");

    p_check_slv(f_lm_saturate("01000", 3, 0, C_LM_SIGNED, 5, 0, C_LM_SIGNED), "011", "positive signed saturation");
    p_check_slv(f_lm_saturate("11000", 3, 0, C_LM_SIGNED, 5, 0, C_LM_SIGNED), "100", "negative signed saturation");
    p_check_slv(f_lm_saturate("11100", 3, 0, C_LM_UNSIGNED, 5, 0, C_LM_SIGNED), "000", "negative signed to unsigned saturation");
    p_check_slv(f_lm_saturate(f_slv_u(15, 4), 4, 0, C_LM_SIGNED, 4, 0, C_LM_UNSIGNED), f_slv_s(7, 4), "unsigned to signed saturation");
    p_check_slv(f_lm_wrap("01000", 3, 0, C_LM_SIGNED, 5, 0, C_LM_SIGNED), "000", "signed wrap");
    p_check_slv(f_lm_quantize(f_slv_u(15, 4), 5, 0, C_LM_SIGNED, 4, 0, C_LM_UNSIGNED,
                               C_LM_TRUNC_BITS, C_LM_WRAP),
                f_slv_u(15, 5), "unsigned to signed widening keeps magnitude");

    report "TEST PASSED: tb_lm_math_fi_pkg (36 checks)" severity note;
    wait;
  end process proc_main;
end architecture a_tb;
