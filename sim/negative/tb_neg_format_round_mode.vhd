-- SPDX-License-Identifier: Apache-2.0
-- Copyright 2026 LogiMentor
--
-- NEGATIVE TEST - THIS DESIGN IS EXPECTED TO FAIL.
-- lm_math_fi_format with a g_round_mode that is not a rounding-mode constant.
--
-- Driven by scripts/run_ghdl_negative_tests.py, which passes only when this
-- unit fails with the diagnostic named in that script. It is deliberately not
-- part of scripts/run_ghdl_tests.py or sim/questasim/run_all.do and must never
-- be added to either.

library ieee;
use ieee.std_logic_1164.all;

library lm_math_fi_lib;
use lm_math_fi_lib.lm_math_fi_pkg.all;

entity tb_neg_format_round_mode is
end entity tb_neg_format_round_mode;

architecture a_tb of tb_neg_format_round_mode is
  signal clk_tb : std_logic := '0';
  signal s_din  : std_logic_vector(3 downto 0) := "1011";
  signal s_dout : std_logic_vector(2 downto 0);
begin

  clk_tb <= not clk_tb after 5 ns;

  dut : entity lm_math_fi_lib.lm_math_fi_format
    generic map(
      g_din_w => 4, g_din_binpnt => 2, g_dout_w => 3, g_dout_binpnt => 1,
      g_pipe_stages => 0, g_round_mode => 42,
      g_overflow => C_LM_WRAP, g_representation => C_LM_UNSIGNED)
    port map(clk_i => clk_tb, din_i => s_din, dout_o => s_dout);

  proc_guard : process
  begin
    wait for 50 ns;
    report "NEGATIVE TEST DID NOT FAIL: tb_neg_format_round_mode elaborated and ran without the expected diagnostic"
      severity failure;
    wait;
  end process proc_guard;

end architecture a_tb;
