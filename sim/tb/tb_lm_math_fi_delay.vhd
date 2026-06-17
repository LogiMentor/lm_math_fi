-- SPDX-License-Identifier: Apache-2.0
-- Copyright 2026 LogiMentor

library ieee;
use ieee.std_logic_1164.all;

library lm_math_fi_lib;
use lm_math_fi_lib.tb_lm_math_fi_test_pkg.all;

entity tb_lm_math_fi_delay is
end entity tb_lm_math_fi_delay;

architecture a_tb of tb_lm_math_fi_delay is
  signal s_done   : boolean := false;
  signal clk_tb   : std_logic := '0';
  signal s_ce     : std_logic := '1';
  signal s_din    : std_logic_vector(3 downto 0) := (others => '0');
  signal s_dout_0 : std_logic_vector(3 downto 0);
  signal s_dout_1 : std_logic_vector(3 downto 0);
  signal s_dout_3 : std_logic_vector(3 downto 0);
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

  inst_delay_0 : entity lm_math_fi_lib.lm_math_fi_delay
    generic map(g_delay => 0, g_data_w => 4)
    port map(clk_i => clk_tb, ce_i => s_ce, din_i => s_din, dout_o => s_dout_0);

  inst_delay_1 : entity lm_math_fi_lib.lm_math_fi_delay
    generic map(g_delay => 1, g_data_w => 4)
    port map(clk_i => clk_tb, ce_i => s_ce, din_i => s_din, dout_o => s_dout_1);

  inst_delay_3 : entity lm_math_fi_lib.lm_math_fi_delay
    generic map(g_delay => 3, g_data_w => 4)
    port map(clk_i => clk_tb, ce_i => s_ce, din_i => s_din, dout_o => s_dout_3);

  proc_main : process
  begin
    s_din <= x"1";
    wait for 1 ns;
    p_check_slv(s_dout_0, x"1", "zero-delay path follows input");

    p_wait_cycles(clk_tb, 1);
    p_check_slv(s_dout_1, x"1", "one-cycle delay first sample");

    s_din <= x"2";
    p_wait_cycles(clk_tb, 1);
    p_check_slv(s_dout_1, x"2", "one-cycle delay second sample");

    s_din <= x"3";
    p_wait_cycles(clk_tb, 1);
    p_check_slv(s_dout_3, x"1", "three-cycle delay first delayed sample");

    s_ce  <= '0';
    s_din <= x"9";
    p_wait_cycles(clk_tb, 1);
    p_check_slv(s_dout_1, x"3", "clock enable holds one-cycle delay");
    p_check_slv(s_dout_3, x"1", "clock enable holds delay line");

    s_ce  <= '1';
    s_din <= x"4";
    p_wait_cycles(clk_tb, 1);
    p_check_slv(s_dout_1, x"4", "delay resumes after clock enable");
    p_check_slv(s_dout_3, x"2", "delay line resumes after clock enable");

    s_din <= x"5";
    p_wait_cycles(clk_tb, 1);
    p_check_slv(s_dout_3, x"3", "delay line emits next valid sample after resume");

    report "TEST PASSED: tb_lm_math_fi_delay (9 checks)" severity note;
    s_done <= true;
    wait;
  end process proc_main;
end architecture a_tb;
