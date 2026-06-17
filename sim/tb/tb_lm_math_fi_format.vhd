-- SPDX-License-Identifier: Apache-2.0
-- Copyright 2026 LogiMentor

library ieee;
use ieee.std_logic_1164.all;

library lm_math_fi_lib;
use lm_math_fi_lib.lm_math_fi_pkg.all;
use lm_math_fi_lib.tb_lm_math_fi_test_pkg.all;

entity tb_lm_math_fi_format is
end entity tb_lm_math_fi_format;

architecture a_tb of tb_lm_math_fi_format is
  signal s_done         : boolean := false;
  signal clk_tb         : std_logic := '0';
  signal s_din_u        : std_logic_vector(3 downto 0) := (others => '0');
  signal s_dout_trunc   : std_logic_vector(2 downto 0);
  signal s_dout_round   : std_logic_vector(2 downto 0);
  signal s_din_s        : std_logic_vector(4 downto 0) := (others => '0');
  signal s_dout_round_s : std_logic_vector(4 downto 0);
  signal s_dout_sat     : std_logic_vector(2 downto 0);
  signal s_dout_wrap    : std_logic_vector(2 downto 0);
  signal s_pipe_ce      : std_logic := '1';
  signal s_din_pipe     : std_logic_vector(3 downto 0) := (others => '0');
  signal s_dout_pipe    : std_logic_vector(2 downto 0);
begin
  proc_clk : process
  begin
    while not s_done loop
      clk_tb <= '0';
      wait for C_TB_CLK_PERIOD / 2;
      clk_tb <= '1';
      wait for C_TB_CLK_PERIOD / 2;
    end loop;
    clk_tb <= '0';
    wait;
  end process proc_clk;

  inst_trunc : entity lm_math_fi_lib.lm_math_fi_format
    generic map(
      g_din_w => 4, g_din_binpnt => 2, g_dout_w => 3, g_dout_binpnt => 1,
      g_pipe_stages => 0, g_round_mode => C_LM_TRUNC_BITS,
      g_overflow => C_LM_WRAP, g_representation => C_LM_UNSIGNED)
    port map(clk_i => clk_tb, din_i => s_din_u, dout_o => s_dout_trunc);

  inst_round : entity lm_math_fi_lib.lm_math_fi_format
    generic map(
      g_din_w => 4, g_din_binpnt => 2, g_dout_w => 3, g_dout_binpnt => 1,
      g_pipe_stages => 0, g_round_mode => C_LM_ROUND_EVEN,
      g_overflow => C_LM_WRAP, g_representation => C_LM_UNSIGNED)
    port map(clk_i => clk_tb, din_i => s_din_u, dout_o => s_dout_round);

  inst_sat : entity lm_math_fi_lib.lm_math_fi_format
    generic map(
      g_din_w => 5, g_din_binpnt => 0, g_dout_w => 3, g_dout_binpnt => 0,
      g_pipe_stages => 0, g_round_mode => C_LM_TRUNC_BITS,
      g_overflow => C_LM_SATURATE, g_representation => C_LM_SIGNED)
    port map(clk_i => clk_tb, din_i => s_din_s, dout_o => s_dout_sat);

  inst_signed_round : entity lm_math_fi_lib.lm_math_fi_format
    generic map(
      g_din_w => 5, g_din_binpnt => 2, g_dout_w => 5, g_dout_binpnt => 1,
      g_pipe_stages => 0, g_round_mode => C_LM_ROUND_EVEN,
      g_overflow => C_LM_WRAP, g_representation => C_LM_SIGNED)
    port map(clk_i => clk_tb, din_i => s_din_s, dout_o => s_dout_round_s);

  inst_wrap : entity lm_math_fi_lib.lm_math_fi_format
    generic map(
      g_din_w => 5, g_din_binpnt => 0, g_dout_w => 3, g_dout_binpnt => 0,
      g_pipe_stages => 0, g_round_mode => C_LM_TRUNC_BITS,
      g_overflow => C_LM_WRAP, g_representation => C_LM_SIGNED)
    port map(clk_i => clk_tb, din_i => s_din_s, dout_o => s_dout_wrap);

  inst_pipe : entity lm_math_fi_lib.lm_math_fi_format
    generic map(
      g_din_w => 4, g_din_binpnt => 2, g_dout_w => 3, g_dout_binpnt => 1,
      g_pipe_stages => 2, g_round_mode => C_LM_ROUND_EVEN,
      g_overflow => C_LM_WRAP, g_representation => C_LM_UNSIGNED)
    port map(clk_i => clk_tb, ce_i => s_pipe_ce, din_i => s_din_pipe, dout_o => s_dout_pipe);

  proc_main : process
  begin
    s_din_u <= "1011";
    wait for 1 ns;
    p_check_slv(s_dout_trunc, "101", "unsigned truncation");
    p_check_slv(s_dout_round, "110", "unsigned round half to even up");

    s_din_u <= "1001";
    wait for 1 ns;
    p_check_slv(s_dout_round, "100", "unsigned round half to even down");

    s_din_s <= f_slv_s(-9, 5);
    wait for 1 ns;
    p_check_slv(s_dout_round_s, f_slv_s(-4, 5), "signed round half to even negative tie toward zero");

    s_din_s <= f_slv_s(-11, 5);
    wait for 1 ns;
    p_check_slv(s_dout_round_s, f_slv_s(-6, 5), "signed round half to even negative tie away from zero");

    s_din_s <= f_slv_s(9, 5);
    wait for 1 ns;
    p_check_slv(s_dout_round_s, f_slv_s(4, 5), "signed round half to even positive tie down");

    s_din_s <= f_slv_s(11, 5);
    wait for 1 ns;
    p_check_slv(s_dout_round_s, f_slv_s(6, 5), "signed round half to even positive tie up");

    s_din_s <= "01000";
    wait for 1 ns;
    p_check_slv(s_dout_sat, "011", "positive signed saturation");
    p_check_slv(s_dout_wrap, "000", "positive signed wrap");

    s_din_s <= "11000";
    wait for 1 ns;
    p_check_slv(s_dout_sat, "100", "negative signed saturation");
    p_check_slv(s_dout_wrap, "000", "negative signed wrap");

    s_din_pipe <= "1011";
    p_wait_cycles(clk_tb, 2);
    p_check_slv(s_dout_pipe, "110", "two-cycle formatter pipeline");

    s_pipe_ce  <= '0';
    s_din_pipe <= "0100";
    p_wait_cycles(clk_tb, 3);
    p_check_slv(s_dout_pipe, "110", "formatter pipeline clock enable hold");

    s_pipe_ce <= '1';
    p_wait_cycles(clk_tb, 2);
    p_check_slv(s_dout_pipe, "010", "formatter pipeline resumes after clock enable");

    report "TEST PASSED: tb_lm_math_fi_format (14 checks)" severity note;
    s_done <= true;
    wait;
  end process proc_main;
end architecture a_tb;
