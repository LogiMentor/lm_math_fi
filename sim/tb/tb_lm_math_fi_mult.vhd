-- SPDX-License-Identifier: Apache-2.0
-- Copyright 2026 LogiMentor

library ieee;
use ieee.std_logic_1164.all;

library lm_math_fi_lib;
use lm_math_fi_lib.lm_math_fi_pkg.all;
use lm_math_fi_lib.tb_lm_math_fi_test_pkg.all;

entity tb_lm_math_fi_mult is
end entity tb_lm_math_fi_mult;

architecture a_tb of tb_lm_math_fi_mult is
  signal s_done : boolean := false;
  signal clk_tb : std_logic := '0';

  signal s_u_a      : std_logic_vector(3 downto 0) := (others => '0');
  signal s_u_b      : std_logic_vector(3 downto 0) := (others => '0');
  signal s_u_o      : std_logic_vector(7 downto 0);
  signal s_u_wrap_o : std_logic_vector(3 downto 0);
  signal s_u_sat_o  : std_logic_vector(3 downto 0);

  signal s_ss_a : std_logic_vector(3 downto 0) := (others => '0');
  signal s_ss_b : std_logic_vector(3 downto 0) := (others => '0');
  signal s_ss_o : std_logic_vector(7 downto 0);

  signal s_su_a : std_logic_vector(3 downto 0) := (others => '0');
  signal s_su_b : std_logic_vector(3 downto 0) := (others => '0');
  signal s_su_o : std_logic_vector(7 downto 0);

  signal s_us_a : std_logic_vector(3 downto 0) := (others => '0');
  signal s_us_b : std_logic_vector(3 downto 0) := (others => '0');
  signal s_us_o : std_logic_vector(7 downto 0);

  signal s_round_a : std_logic_vector(3 downto 0) := (others => '0');
  signal s_round_b : std_logic_vector(3 downto 0) := (others => '0');
  signal s_round_o : std_logic_vector(7 downto 0);

  signal s_signed_round_a : std_logic_vector(3 downto 0) := (others => '0');
  signal s_signed_round_b : std_logic_vector(3 downto 0) := (others => '0');
  signal s_signed_round_o : std_logic_vector(7 downto 0);

  signal s_pipe_ce : std_logic := '1';
  signal s_pipe_a  : std_logic_vector(3 downto 0) := (others => '0');
  signal s_pipe_b  : std_logic_vector(3 downto 0) := (others => '0');
  signal s_pipe_o  : std_logic_vector(7 downto 0);
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

  inst_unsigned : entity lm_math_fi_lib.lm_math_fi_mult
    generic map(
      g_din_a_w => 4, g_din_a_binpnt => 0, g_din_b_w => 4, g_din_b_binpnt => 0,
      g_dout_w => 8, g_dout_binpnt => 0, g_round_mode => C_LM_TRUNC_BITS,
      g_din_a_type => C_LM_UNSIGNED, g_din_b_type => C_LM_UNSIGNED, g_dout_type => C_LM_UNSIGNED,
      g_pipe_stages => 0)
    port map(clk_i => clk_tb, din1_i => s_u_a, din2_i => s_u_b, dout_o => s_u_o);

  inst_unsigned_wrap : entity lm_math_fi_lib.lm_math_fi_mult
    generic map(
      g_din_a_w => 4, g_din_a_binpnt => 0, g_din_b_w => 4, g_din_b_binpnt => 0,
      g_dout_w => 4, g_dout_binpnt => 0, g_round_mode => C_LM_TRUNC_BITS,
      g_din_a_type => C_LM_UNSIGNED, g_din_b_type => C_LM_UNSIGNED, g_dout_type => C_LM_UNSIGNED,
      g_pipe_stages => 0)
    port map(clk_i => clk_tb, din1_i => s_u_a, din2_i => s_u_b, dout_o => s_u_wrap_o);

  inst_u_saturate : entity lm_math_fi_lib.lm_math_fi_mult
    generic map(
      g_din_a_w => 4, g_din_a_binpnt => 0, g_din_b_w => 4, g_din_b_binpnt => 0,
      g_dout_w => 4, g_dout_binpnt => 0, g_round_mode => C_LM_TRUNC_BITS,
      g_din_a_type => C_LM_UNSIGNED, g_din_b_type => C_LM_UNSIGNED, g_dout_type => C_LM_UNSIGNED,
      g_overflow => C_LM_SATURATE, g_pipe_stages => 0)
    port map(clk_i => clk_tb, din1_i => s_u_a, din2_i => s_u_b, dout_o => s_u_sat_o);

  inst_signed_signed : entity lm_math_fi_lib.lm_math_fi_mult
    generic map(
      g_din_a_w => 4, g_din_a_binpnt => 0, g_din_b_w => 4, g_din_b_binpnt => 0,
      g_dout_w => 8, g_dout_binpnt => 0, g_round_mode => C_LM_TRUNC_BITS,
      g_din_a_type => C_LM_SIGNED, g_din_b_type => C_LM_SIGNED, g_dout_type => C_LM_SIGNED,
      g_pipe_stages => 0)
    port map(clk_i => clk_tb, din1_i => s_ss_a, din2_i => s_ss_b, dout_o => s_ss_o);

  inst_signed_unsigned : entity lm_math_fi_lib.lm_math_fi_mult
    generic map(
      g_din_a_w => 4, g_din_a_binpnt => 0, g_din_b_w => 4, g_din_b_binpnt => 0,
      g_dout_w => 8, g_dout_binpnt => 0, g_round_mode => C_LM_TRUNC_BITS,
      g_din_a_type => C_LM_SIGNED, g_din_b_type => C_LM_UNSIGNED, g_dout_type => C_LM_SIGNED,
      g_pipe_stages => 0)
    port map(clk_i => clk_tb, din1_i => s_su_a, din2_i => s_su_b, dout_o => s_su_o);

  inst_unsigned_signed : entity lm_math_fi_lib.lm_math_fi_mult
    generic map(
      g_din_a_w => 4, g_din_a_binpnt => 0, g_din_b_w => 4, g_din_b_binpnt => 0,
      g_dout_w => 8, g_dout_binpnt => 0, g_round_mode => C_LM_TRUNC_BITS,
      g_din_a_type => C_LM_UNSIGNED, g_din_b_type => C_LM_SIGNED, g_dout_type => C_LM_SIGNED,
      g_pipe_stages => 0)
    port map(clk_i => clk_tb, din1_i => s_us_a, din2_i => s_us_b, dout_o => s_us_o);

  inst_round : entity lm_math_fi_lib.lm_math_fi_mult
    generic map(
      g_din_a_w => 4, g_din_a_binpnt => 2, g_din_b_w => 4, g_din_b_binpnt => 2,
      g_dout_w => 8, g_dout_binpnt => 2, g_round_mode => C_LM_ROUND_EVEN,
      g_din_a_type => C_LM_UNSIGNED, g_din_b_type => C_LM_UNSIGNED, g_dout_type => C_LM_UNSIGNED,
      g_pipe_stages => 0)
    port map(clk_i => clk_tb, din1_i => s_round_a, din2_i => s_round_b, dout_o => s_round_o);

  inst_signed_round : entity lm_math_fi_lib.lm_math_fi_mult
    generic map(
      g_din_a_w => 4, g_din_a_binpnt => 2, g_din_b_w => 4, g_din_b_binpnt => 2,
      g_dout_w => 8, g_dout_binpnt => 2, g_round_mode => C_LM_ROUND_EVEN,
      g_din_a_type => C_LM_SIGNED, g_din_b_type => C_LM_SIGNED, g_dout_type => C_LM_SIGNED,
      g_pipe_stages => 0)
    port map(clk_i => clk_tb, din1_i => s_signed_round_a, din2_i => s_signed_round_b, dout_o => s_signed_round_o);

  inst_pipe : entity lm_math_fi_lib.lm_math_fi_mult
    generic map(
      g_din_a_w => 4, g_din_a_binpnt => 0, g_din_b_w => 4, g_din_b_binpnt => 0,
      g_dout_w => 8, g_dout_binpnt => 0, g_round_mode => C_LM_TRUNC_BITS,
      g_din_a_type => C_LM_UNSIGNED, g_din_b_type => C_LM_UNSIGNED, g_dout_type => C_LM_UNSIGNED,
      g_pipe_stages => 2)
    port map(clk_i => clk_tb, ce_i => s_pipe_ce, din1_i => s_pipe_a, din2_i => s_pipe_b, dout_o => s_pipe_o);

  proc_main : process
  begin
    s_u_a <= f_slv_u(15, 4);
    s_u_b <= f_slv_u(15, 4);
    s_ss_a <= f_slv_s(-3, 4);
    s_ss_b <= f_slv_s(5, 4);
    s_su_a <= f_slv_s(-3, 4);
    s_su_b <= f_slv_u(15, 4);
    s_us_a <= f_slv_u(15, 4);
    s_us_b <= f_slv_s(-3, 4);
    s_round_a <= f_slv_u(2, 4);
    s_round_b <= f_slv_u(7, 4);
    s_signed_round_a <= f_slv_s(-2, 4);
    s_signed_round_b <= f_slv_s(5, 4);
    s_pipe_a <= f_slv_u(3, 4);
    s_pipe_b <= f_slv_u(5, 4);

    p_wait_cycles(clk_tb, 1);
    p_check_slv(s_u_o, f_slv_u(225, 8), "unsigned multiply max operands");
    p_check_slv(s_u_wrap_o, f_slv_u(1, 4), "unsigned multiply overflow wraps");
    p_check_slv(s_u_sat_o, f_slv_u(15, 4), "unsigned multiply overflow saturates");
    p_check_slv(s_ss_o, f_slv_s(-15, 8), "signed signed multiply");
    p_check_slv(s_su_o, f_slv_s(-45, 8), "signed unsigned multiply with unsigned MSB high");
    p_check_slv(s_us_o, f_slv_s(-45, 8), "unsigned signed multiply with unsigned MSB high");
    p_check_slv(s_round_o, f_slv_u(4, 8), "multiply round half to even up");
    p_check_slv(s_signed_round_o, f_slv_s(-2, 8), "signed multiply round half-even negative tie toward zero");

    s_ss_a <= f_slv_s(-8, 4);
    s_ss_b <= f_slv_s(1, 4);
    s_signed_round_a <= f_slv_s(-2, 4);
    s_signed_round_b <= f_slv_s(7, 4);
    p_wait_cycles(clk_tb, 1);
    p_check_slv(s_ss_o, f_slv_s(-8, 8), "signed signed multiply minimum operand");
    p_check_slv(s_signed_round_o, f_slv_s(-4, 8), "signed multiply round half-even negative tie away from zero");

    p_wait_cycles(clk_tb, 2);
    p_check_slv(s_pipe_o, f_slv_u(15, 8), "multiplier internal pipeline latency");

    s_pipe_ce <= '0';
    s_pipe_a  <= f_slv_u(7, 4);
    s_pipe_b  <= f_slv_u(6, 4);
    p_wait_cycles(clk_tb, 4);
    p_check_slv(s_pipe_o, f_slv_u(15, 8), "multiplier clock enable hold");

    s_pipe_ce <= '1';
    p_wait_cycles(clk_tb, 3);
    p_check_slv(s_pipe_o, f_slv_u(42, 8), "multiplier resumes after clock enable");

    report "TEST PASSED: tb_lm_math_fi_mult (13 checks)" severity note;
    s_done <= true;
    wait;
  end process proc_main;
end architecture a_tb;
