-- SPDX-License-Identifier: Apache-2.0
-- Copyright 2026 LogiMentor
--
-- NEGATIVE TEST - THIS DESIGN IS EXPECTED TO FAIL.
-- Calls lm_math_fi_pkg.f_lm_quantize directly with an overflow mode that is
-- neither C_LM_SATURATE nor C_LM_WRAP. Before this check existed the call
-- silently wrapped.
--
-- Driven by scripts/run_ghdl_negative_tests.py, which passes only when this
-- unit fails with the diagnostic named in that script. It is deliberately not
-- part of scripts/run_ghdl_tests.py or sim/questasim/run_all.do and must never
-- be added to either.

library ieee;
use ieee.std_logic_1164.all;

library lm_math_fi_lib;
use lm_math_fi_lib.lm_math_fi_pkg.all;

entity tb_neg_pkg_overflow is
end entity tb_neg_pkg_overflow;

architecture a_tb of tb_neg_pkg_overflow is
  -- 0 is not an overflow constant. C_LM_SATURATE is 1 and C_LM_WRAP is 2.
  constant C_BAD_OVERFLOW : integer := 0;
  signal   s_result       : std_logic_vector(3 downto 0);
begin

  s_result <= f_lm_quantize("1011",
                            4, 1, C_LM_UNSIGNED,
                            4, 2, C_LM_UNSIGNED,
                            C_LM_TRUNC_BITS, C_BAD_OVERFLOW);

  proc_guard : process
  begin
    wait for 50 ns;
    report "NEGATIVE TEST DID NOT FAIL: f_lm_quantize accepted overflow mode 0"
      severity failure;
    wait;
  end process proc_guard;

end architecture a_tb;
