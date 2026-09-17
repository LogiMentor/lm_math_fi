-- SPDX-License-Identifier: Apache-2.0
-- Copyright 2026 LogiMentor
--
-- NEGATIVE TEST - THIS DESIGN IS EXPECTED TO FAIL.
-- lm_math_fi_mult with a g_din_a_type that is neither C_LM_SIGNED nor
-- C_LM_UNSIGNED. Before this check existed the operand silently took the
-- unsigned path.
--
-- Driven by scripts/run_ghdl_negative_tests.py, which passes only when this
-- unit fails with the diagnostic named in that script. It is deliberately not
-- part of scripts/run_ghdl_tests.py or sim/questasim/run_all.do and must never
-- be added to either.

library ieee;
use ieee.std_logic_1164.all;

library lm_math_fi_lib;
use lm_math_fi_lib.lm_math_fi_pkg.all;

entity tb_neg_mult_din_a_type is
end entity tb_neg_mult_din_a_type;

architecture a_tb of tb_neg_mult_din_a_type is
  signal clk_tb : std_logic := '0';
  signal s_a    : std_logic_vector(3 downto 0) := "0011";
  signal s_b    : std_logic_vector(3 downto 0) := "0010";
  signal s_dout : std_logic_vector(7 downto 0);
begin

  clk_tb <= not clk_tb after 5 ns;

  dut : entity lm_math_fi_lib.lm_math_fi_mult
    generic map(
      g_din_a_w => 4, g_din_a_binpnt => 0, g_din_b_w => 4, g_din_b_binpnt => 0,
      g_dout_w => 8, g_dout_binpnt => 0, g_round_mode => C_LM_TRUNC_BITS,
      g_din_a_type => 0, g_din_b_type => C_LM_UNSIGNED, g_dout_type => C_LM_UNSIGNED,
      g_overflow => C_LM_WRAP, g_pipe_stages => 0)
    port map(clk_i => clk_tb, ce_i => '1', din1_i => s_a, din2_i => s_b, dout_o => s_dout);

  proc_guard : process
  begin
    wait for 50 ns;
    report "NEGATIVE TEST DID NOT FAIL: tb_neg_mult_din_a_type elaborated and ran without the expected diagnostic"
      severity failure;
    wait;
  end process proc_guard;

end architecture a_tb;
