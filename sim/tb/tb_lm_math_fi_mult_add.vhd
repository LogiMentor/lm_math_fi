-- SPDX-License-Identifier: Apache-2.0
-- Copyright 2026 LogiMentor

library ieee;
use ieee.std_logic_1164.all;

library lm_math_fi_lib;
use lm_math_fi_lib.lm_math_fi_pkg.all;
use lm_math_fi_lib.tb_lm_math_fi_test_pkg.all;

entity tb_lm_math_fi_mult_add is
end entity tb_lm_math_fi_mult_add;

architecture a_tb of tb_lm_math_fi_mult_add is
  signal s_done : boolean := false;
  signal clk_tb : std_logic := '0';

  signal s_u_a : std_logic_vector(3 downto 0) := (others => '0');
  signal s_u_b : std_logic_vector(3 downto 0) := (others => '0');
  signal s_u_c : std_logic_vector(8 downto 0) := (others => '0');
  signal s_u_o : std_logic_vector(8 downto 0);

  signal s_wide_a : std_logic_vector(3 downto 0) := (others => '0');
  signal s_wide_b : std_logic_vector(3 downto 0) := (others => '0');
  signal s_wide_c : std_logic_vector(11 downto 0) := (others => '0');
  signal s_wide_o : std_logic_vector(11 downto 0);

  signal s_signed_a     : std_logic_vector(3 downto 0) := (others => '0');
  signal s_signed_b     : std_logic_vector(3 downto 0) := (others => '0');
  signal s_signed_c     : std_logic_vector(8 downto 0) := (others => '0');
  signal s_signed_add_o : std_logic_vector(8 downto 0);
  signal s_signed_sub_o : std_logic_vector(8 downto 0);

  signal s_sat_a : std_logic_vector(3 downto 0) := (others => '0');
  signal s_sat_b : std_logic_vector(3 downto 0) := (others => '0');
  signal s_sat_c : std_logic_vector(8 downto 0) := (others => '0');
  signal s_sat_o : std_logic_vector(3 downto 0);

  signal s_frac_a : std_logic_vector(3 downto 0) := (others => '0');
  signal s_frac_b : std_logic_vector(3 downto 0) := (others => '0');
  signal s_frac_c : std_logic_vector(5 downto 0) := (others => '0');
  signal s_frac_o : std_logic_vector(5 downto 0);

  signal s_c_frac_a : std_logic_vector(3 downto 0) := (others => '0');
  signal s_c_frac_b : std_logic_vector(3 downto 0) := (others => '0');
  signal s_c_frac_c : std_logic_vector(3 downto 0) := (others => '0');
  signal s_c_frac_o : std_logic_vector(7 downto 0);

  signal s_pipe_ce : std_logic := '1';
  signal s_pipe_a  : std_logic_vector(3 downto 0) := (others => '0');
  signal s_pipe_b  : std_logic_vector(3 downto 0) := (others => '0');
  signal s_pipe_c  : std_logic_vector(8 downto 0) := (others => '0');
  signal s_pipe_o  : std_logic_vector(8 downto 0);
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

  inst_unsigned_add : entity lm_math_fi_lib.lm_math_fi_mult_add
    generic map(
      g_din_a_w => 4, g_din_a_binpnt => 0, g_din_b_w => 4, g_din_b_binpnt => 0,
      g_din_c_w => 9, g_din_c_binpnt => 0, g_dout_w => 9, g_dout_binpnt => 0,
      g_add_sub => C_LM_ADD, g_round_mode => C_LM_TRUNC_BITS,
      g_representation => C_LM_UNSIGNED, g_overflow => C_LM_WRAP, g_pipe_stages => 0)
    port map(clk_i => clk_tb, din1_i => s_u_a, din2_i => s_u_b, din3_i => s_u_c, dout_o => s_u_o);

  inst_wide_c : entity lm_math_fi_lib.lm_math_fi_mult_add
    generic map(
      g_din_a_w => 4, g_din_a_binpnt => 0, g_din_b_w => 4, g_din_b_binpnt => 0,
      g_din_c_w => 12, g_din_c_binpnt => 0, g_dout_w => 12, g_dout_binpnt => 0,
      g_add_sub => C_LM_ADD, g_round_mode => C_LM_TRUNC_BITS,
      g_representation => C_LM_UNSIGNED, g_overflow => C_LM_WRAP, g_pipe_stages => 0)
    port map(clk_i => clk_tb, din1_i => s_wide_a, din2_i => s_wide_b,
             din3_i => s_wide_c, dout_o => s_wide_o);

  inst_signed_add : entity lm_math_fi_lib.lm_math_fi_mult_add
    generic map(
      g_din_a_w => 4, g_din_a_binpnt => 0, g_din_b_w => 4, g_din_b_binpnt => 0,
      g_din_c_w => 9, g_din_c_binpnt => 0, g_dout_w => 9, g_dout_binpnt => 0,
      g_add_sub => C_LM_ADD, g_round_mode => C_LM_TRUNC_BITS,
      g_representation => C_LM_SIGNED, g_overflow => C_LM_WRAP, g_pipe_stages => 0)
    port map(clk_i => clk_tb, din1_i => s_signed_a, din2_i => s_signed_b,
             din3_i => s_signed_c, dout_o => s_signed_add_o);

  inst_signed_sub : entity lm_math_fi_lib.lm_math_fi_mult_add
    generic map(
      g_din_a_w => 4, g_din_a_binpnt => 0, g_din_b_w => 4, g_din_b_binpnt => 0,
      g_din_c_w => 9, g_din_c_binpnt => 0, g_dout_w => 9, g_dout_binpnt => 0,
      g_add_sub => C_LM_SUB, g_round_mode => C_LM_TRUNC_BITS,
      g_representation => C_LM_SIGNED, g_overflow => C_LM_WRAP, g_pipe_stages => 0)
    port map(clk_i => clk_tb, din1_i => s_signed_a, din2_i => s_signed_b,
             din3_i => s_signed_c, dout_o => s_signed_sub_o);

  inst_saturate : entity lm_math_fi_lib.lm_math_fi_mult_add
    generic map(
      g_din_a_w => 4, g_din_a_binpnt => 0, g_din_b_w => 4, g_din_b_binpnt => 0,
      g_din_c_w => 9, g_din_c_binpnt => 0, g_dout_w => 4, g_dout_binpnt => 0,
      g_add_sub => C_LM_ADD, g_round_mode => C_LM_TRUNC_BITS,
      g_representation => C_LM_SIGNED, g_overflow => C_LM_SATURATE, g_pipe_stages => 0)
    port map(clk_i => clk_tb, din1_i => s_sat_a, din2_i => s_sat_b, din3_i => s_sat_c, dout_o => s_sat_o);

  inst_fractional : entity lm_math_fi_lib.lm_math_fi_mult_add
    generic map(
      g_din_a_w => 4, g_din_a_binpnt => 2, g_din_b_w => 4, g_din_b_binpnt => 2,
      g_din_c_w => 6, g_din_c_binpnt => 2, g_dout_w => 6, g_dout_binpnt => 2,
      g_add_sub => C_LM_ADD, g_round_mode => C_LM_ROUND_EVEN,
      g_representation => C_LM_UNSIGNED, g_overflow => C_LM_WRAP, g_pipe_stages => 0)
    port map(clk_i => clk_tb, din1_i => s_frac_a, din2_i => s_frac_b, din3_i => s_frac_c, dout_o => s_frac_o);

  inst_c_fraction : entity lm_math_fi_lib.lm_math_fi_mult_add
    generic map(
      g_din_a_w => 4, g_din_a_binpnt => 0, g_din_b_w => 4, g_din_b_binpnt => 0,
      g_din_c_w => 4, g_din_c_binpnt => 2, g_dout_w => 8, g_dout_binpnt => 2,
      g_add_sub => C_LM_ADD, g_round_mode => C_LM_TRUNC_BITS,
      g_representation => C_LM_UNSIGNED, g_overflow => C_LM_WRAP, g_pipe_stages => 0)
    port map(clk_i => clk_tb, din1_i => s_c_frac_a, din2_i => s_c_frac_b,
             din3_i => s_c_frac_c, dout_o => s_c_frac_o);

  inst_pipe : entity lm_math_fi_lib.lm_math_fi_mult_add
    generic map(
      g_din_a_w => 4, g_din_a_binpnt => 0, g_din_b_w => 4, g_din_b_binpnt => 0,
      g_din_c_w => 9, g_din_c_binpnt => 0, g_dout_w => 9, g_dout_binpnt => 0,
      g_add_sub => C_LM_ADD, g_round_mode => C_LM_TRUNC_BITS,
      g_representation => C_LM_UNSIGNED, g_overflow => C_LM_WRAP, g_pipe_stages => 2)
    port map(clk_i => clk_tb, ce_i => s_pipe_ce, din1_i => s_pipe_a,
             din2_i => s_pipe_b, din3_i => s_pipe_c, dout_o => s_pipe_o);

  proc_main : process
  begin
    s_u_a <= f_slv_u(3, 4);
    s_u_b <= f_slv_u(4, 4);
    s_u_c <= f_slv_u(5, 9);

    s_wide_a <= f_slv_u(1, 4);
    s_wide_b <= f_slv_u(1, 4);
    s_wide_c <= f_slv_u(2048, 12);

    s_signed_a <= f_slv_s(-3, 4);
    s_signed_b <= f_slv_s(4, 4);
    s_signed_c <= f_slv_s(5, 9);

    s_sat_a <= f_slv_s(4, 4);
    s_sat_b <= f_slv_s(4, 4);
    s_sat_c <= f_slv_s(0, 9);

    s_frac_a <= f_slv_u(6, 4);
    s_frac_b <= f_slv_u(3, 4);
    s_frac_c <= f_slv_u(1, 6);

    s_c_frac_a <= f_slv_u(1, 4);
    s_c_frac_b <= f_slv_u(1, 4);
    s_c_frac_c <= f_slv_u(5, 4);

    s_pipe_a <= f_slv_u(3, 4);
    s_pipe_b <= f_slv_u(5, 4);
    s_pipe_c <= f_slv_u(2, 9);

    p_wait_cycles(clk_tb, 1);
    p_check_slv(s_u_o, f_slv_u(17, 9), "unsigned multiply-add");
    p_check_slv(s_wide_o, f_slv_u(2049, 12), "multiply-add preserves wide addend integer bits");
    p_check_slv(s_signed_add_o, f_slv_s(-7, 9), "signed multiply-add");
    p_check_slv(s_signed_sub_o, f_slv_s(-17, 9), "signed multiply-subtract");
    p_check_slv(s_sat_o, f_slv_s(7, 4), "positive signed saturation");
    p_check_slv(s_frac_o, f_slv_u(6, 6), "fractional multiply-add round half to even");
    p_check_slv(s_c_frac_o, f_slv_u(9, 8), "multiply-add preserves addend fractional bits");

    s_sat_a <= f_slv_s(-8, 4);
    s_sat_b <= f_slv_s(4, 4);
    p_wait_cycles(clk_tb, 1);
    p_check_slv(s_sat_o, f_slv_s(-8, 4), "negative signed saturation");

    p_wait_cycles(clk_tb, 2);
    p_check_slv(s_pipe_o, f_slv_u(17, 9), "multiply-add pipeline latency");

    s_pipe_ce <= '0';
    s_pipe_a  <= f_slv_u(7, 4);
    s_pipe_b  <= f_slv_u(6, 4);
    s_pipe_c  <= f_slv_u(1, 9);
    p_wait_cycles(clk_tb, 4);
    p_check_slv(s_pipe_o, f_slv_u(17, 9), "multiply-add clock enable hold");

    s_pipe_ce <= '1';
    p_wait_cycles(clk_tb, 3);
    p_check_slv(s_pipe_o, f_slv_u(43, 9), "multiply-add resumes after clock enable");

    report "TEST PASSED: tb_lm_math_fi_mult_add (11 checks)" severity note;
    s_done <= true;
    wait;
  end process proc_main;
end architecture a_tb;
