-- SPDX-License-Identifier: Apache-2.0
-- Copyright 2026 LogiMentor

library ieee;
use ieee.std_logic_1164.all;

library lm_math_fi_lib;
use lm_math_fi_lib.lm_math_fi_pkg.all;
use lm_math_fi_lib.tb_lm_math_fi_test_pkg.all;

entity tb_lm_math_fi_add_sub is
end entity tb_lm_math_fi_add_sub;

architecture a_tb of tb_lm_math_fi_add_sub is
  signal s_done : boolean := false;
  signal clk_tb : std_logic := '0';

  signal s_add_a : std_logic_vector(3 downto 0) := (others => '0');
  signal s_add_b : std_logic_vector(3 downto 0) := (others => '0');
  signal s_add_o : std_logic_vector(4 downto 0);

  signal s_sub_a : std_logic_vector(3 downto 0) := (others => '0');
  signal s_sub_b : std_logic_vector(3 downto 0) := (others => '0');
  signal s_sub_o : std_logic_vector(4 downto 0);

  signal s_pipe_ce  : std_logic := '1';
  signal s_pipe_sel : std_logic := '1';
  signal s_pipe_a   : std_logic_vector(3 downto 0) := (others => '0');
  signal s_pipe_b   : std_logic_vector(3 downto 0) := (others => '0');
  signal s_pipe_o   : std_logic_vector(4 downto 0);

  signal s_narrow_a : std_logic_vector(3 downto 0) := (others => '0');
  signal s_narrow_b : std_logic_vector(3 downto 0) := (others => '0');
  signal s_narrow_o : std_logic_vector(2 downto 0);

  signal s_signed_round_a : std_logic_vector(4 downto 0) := (others => '0');
  signal s_signed_round_b : std_logic_vector(4 downto 0) := (others => '0');
  signal s_signed_round_o : std_logic_vector(4 downto 0);

  signal s_out_ce : std_logic := '1';
  signal s_out_a  : std_logic_vector(3 downto 0) := (others => '0');
  signal s_out_b  : std_logic_vector(3 downto 0) := (others => '0');
  signal s_out_o  : std_logic_vector(4 downto 0);
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

  inst_unsigned_add : entity lm_math_fi_lib.lm_math_fi_add_sub
    generic map(
      g_direction => C_LM_ADD, g_representation => C_LM_UNSIGNED,
      g_pipeline_input => 0, g_pipeline_output => 0,
      g_din1_w => 4, g_din1_binpnt => 1, g_din2_w => 4, g_din2_binpnt => 1,
      g_dout_w => 5, g_dout_binpnt => 1, g_round_mode => C_LM_TRUNC_BITS)
    port map(clk_i => clk_tb, ce_i => '1', sel_add_i => '1', din1_i => s_add_a, din2_i => s_add_b, dout_o => s_add_o);

  inst_unsigned_sub : entity lm_math_fi_lib.lm_math_fi_add_sub
    generic map(
      g_direction => C_LM_SUB, g_representation => C_LM_UNSIGNED,
      g_pipeline_input => 0, g_pipeline_output => 0,
      g_din1_w => 4, g_din1_binpnt => 1, g_din2_w => 4, g_din2_binpnt => 1,
      g_dout_w => 5, g_dout_binpnt => 1, g_round_mode => C_LM_TRUNC_BITS)
    port map(clk_i => clk_tb, ce_i => '1', sel_add_i => '1', din1_i => s_sub_a, din2_i => s_sub_b, dout_o => s_sub_o);

  inst_s_addsub_pipe : entity lm_math_fi_lib.lm_math_fi_add_sub
    generic map(
      g_direction => C_LM_ADDSUB, g_representation => C_LM_SIGNED,
      g_pipeline_input => 1, g_pipeline_output => 1,
      g_din1_w => 4, g_din1_binpnt => 1, g_din2_w => 4, g_din2_binpnt => 1,
      g_dout_w => 5, g_dout_binpnt => 1, g_round_mode => C_LM_TRUNC_BITS)
    port map(clk_i => clk_tb, ce_i => s_pipe_ce, sel_add_i => s_pipe_sel,
             din1_i => s_pipe_a, din2_i => s_pipe_b, dout_o => s_pipe_o);

  inst_narrow_round : entity lm_math_fi_lib.lm_math_fi_add_sub
    generic map(
      g_direction => C_LM_ADD, g_representation => C_LM_UNSIGNED,
      g_pipeline_input => 0, g_pipeline_output => 0,
      g_din1_w => 4, g_din1_binpnt => 2, g_din2_w => 4, g_din2_binpnt => 2,
      g_dout_w => 3, g_dout_binpnt => 1, g_round_mode => C_LM_ROUND_EVEN)
    port map(clk_i => clk_tb, ce_i => '1', sel_add_i => '1',
             din1_i => s_narrow_a, din2_i => s_narrow_b, dout_o => s_narrow_o);

  inst_signed_round : entity lm_math_fi_lib.lm_math_fi_add_sub
    generic map(
      g_direction => C_LM_ADD, g_representation => C_LM_SIGNED,
      g_pipeline_input => 0, g_pipeline_output => 0,
      g_din1_w => 5, g_din1_binpnt => 2, g_din2_w => 5, g_din2_binpnt => 2,
      g_dout_w => 5, g_dout_binpnt => 1, g_round_mode => C_LM_ROUND_EVEN)
    port map(clk_i => clk_tb, ce_i => '1', sel_add_i => '1',
             din1_i => s_signed_round_a, din2_i => s_signed_round_b, dout_o => s_signed_round_o);

  inst_output_ce : entity lm_math_fi_lib.lm_math_fi_add_sub
    generic map(
      g_direction => C_LM_ADD, g_representation => C_LM_UNSIGNED,
      g_pipeline_input => 0, g_pipeline_output => 1,
      g_din1_w => 4, g_din1_binpnt => 0, g_din2_w => 4, g_din2_binpnt => 0,
      g_dout_w => 5, g_dout_binpnt => 0, g_round_mode => C_LM_TRUNC_BITS)
    port map(clk_i => clk_tb, ce_i => s_out_ce, sel_add_i => '1',
             din1_i => s_out_a, din2_i => s_out_b, dout_o => s_out_o);

  proc_main : process
  begin
    s_add_a <= f_slv_u(3, 4);
    s_add_b <= f_slv_u(5, 4);
    s_sub_a <= f_slv_u(1, 4);
    s_sub_b <= f_slv_u(3, 4);
    s_narrow_a <= "0011";
    s_narrow_b <= "0010";
    s_signed_round_a <= f_slv_s(-5, 5);
    s_signed_round_b <= f_slv_s(-4, 5);
    s_out_a <= f_slv_u(2, 4);
    s_out_b <= f_slv_u(3, 4);
    wait for 1 ns;

    p_check_slv(s_add_o, f_slv_u(8, 5), "unsigned add standard case");
    p_check_slv(s_sub_o, f_slv_u(30, 5), "unsigned sub underflow wraps in full precision");
    p_check_slv(s_narrow_o, "010", "narrow rounded add half-even case");
    p_check_slv(s_signed_round_o, f_slv_s(-4, 5), "signed add round half-even negative tie toward zero");

    s_signed_round_a <= f_slv_s(-7, 5);
    s_signed_round_b <= f_slv_s(-4, 5);
    wait for 1 ns;
    p_check_slv(s_signed_round_o, f_slv_s(-6, 5), "signed add round half-even negative tie away from zero");

    s_signed_round_a <= f_slv_s(5, 5);
    s_signed_round_b <= f_slv_s(4, 5);
    wait for 1 ns;
    p_check_slv(s_signed_round_o, f_slv_s(4, 5), "signed add round half-even positive tie down");

    p_wait_cycles(clk_tb, 1);
    p_check_slv(s_out_o, f_slv_u(5, 5), "output-only pipeline samples when clock enable is high");

    s_out_ce <= '0';
    s_out_a  <= f_slv_u(7, 4);
    s_out_b  <= f_slv_u(1, 4);
    p_wait_cycles(clk_tb, 3);
    p_check_slv(s_out_o, f_slv_u(5, 5), "output-only pipeline clock enable hold");

    s_out_ce <= '1';
    p_wait_cycles(clk_tb, 1);
    p_check_slv(s_out_o, f_slv_u(8, 5), "output-only pipeline resumes after clock enable");

    s_pipe_a   <= f_slv_s(-4, 4);
    s_pipe_b   <= f_slv_s(3, 4);
    s_pipe_sel <= '1';
    p_wait_cycles(clk_tb, 3);
    p_check_slv(s_pipe_o, f_slv_s(-1, 5), "signed add/sub add path with pipeline");

    s_pipe_sel <= '0';
    p_wait_cycles(clk_tb, 3);
    p_check_slv(s_pipe_o, f_slv_s(-7, 5), "signed add/sub sub path with pipeline");

    s_pipe_ce  <= '0';
    s_pipe_sel <= '1';
    s_pipe_a   <= f_slv_s(6, 4);
    s_pipe_b   <= f_slv_s(1, 4);
    p_wait_cycles(clk_tb, 3);
    p_check_slv(s_pipe_o, f_slv_s(-7, 5), "input clock enable holds registered operands");

    report "TEST PASSED: tb_lm_math_fi_add_sub (12 checks)" severity note;
    s_done <= true;
    wait;
  end process proc_main;
end architecture a_tb;
