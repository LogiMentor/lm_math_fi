-- SPDX-License-Identifier: Apache-2.0
-- Copyright 2026 LogiMentor
--
-- NEGATIVE TEST - THIS DESIGN IS EXPECTED TO FAIL.
-- Calls lm_math_fi_pkg.f_lm_quantize directly with a rounding mode that is
-- not one of the nine supported constants. Before this check existed the
-- call silently returned a bit-truncated result.
--
-- Driven by scripts/run_ghdl_negative_tests.py, which passes only when this
-- unit fails with the diagnostic named in that script. It is deliberately not
-- part of scripts/run_ghdl_tests.py or sim/questasim/run_all.do and must never
-- be added to either.

library ieee;
use ieee.std_logic_1164.all;

library lm_math_fi_lib;
use lm_math_fi_lib.lm_math_fi_pkg.all;

entity tb_neg_pkg_round_mode is
end entity tb_neg_pkg_round_mode;

architecture a_tb of tb_neg_pkg_round_mode is
  -- 42 is not a rounding-mode constant. The supported values are 0 to 8.
  constant C_BAD_ROUND_MODE : integer := 42;
  signal   s_result         : std_logic_vector(3 downto 0);
begin

  s_result <= f_lm_quantize("1011",
                            4, 1, C_LM_UNSIGNED,
                            4, 2, C_LM_UNSIGNED,
                            C_BAD_ROUND_MODE, C_LM_WRAP);

  proc_guard : process
  begin
    wait for 50 ns;
    report "NEGATIVE TEST DID NOT FAIL: f_lm_quantize accepted rounding mode 42"
      severity failure;
    wait;
  end process proc_guard;

end architecture a_tb;
