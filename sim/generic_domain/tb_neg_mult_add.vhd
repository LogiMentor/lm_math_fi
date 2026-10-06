-- SPDX-License-Identifier: Apache-2.0
-- Copyright 2026 LogiMentor
--
-- Generic-domain negative testbench for lm_math_fi_mult_add.
--
-- THIS DESIGN IS EXPECTED TO FAIL, once per case.
--
-- The generics below mirror lm_math_fi_mult_add's own generics: same names, same subtypes,
-- and defaults that are all legal. A case is selected by overriding exactly one
-- of them from the command line, for example:
--
--   ghdl -r tb_neg_mult_add -g<generic>=<illegal value>
--
-- Run with no override, every value is legal and the guard process reports
-- GENERIC DOMAIN TB COMPLETED. scripts/run_ghdl_generic_domain_tests.py uses
-- that run to prove the defaults really are legal, then uses one run per case
-- to prove each illegal value is rejected.
--
-- These units are deliberately not part of scripts/run_ghdl_tests.py or
-- sim/questasim/run_all.do and must never be added to either.

library ieee;
use ieee.std_logic_1164.all;

library lm_math_fi_lib;
use lm_math_fi_lib.lm_math_fi_pkg.all;

entity tb_neg_mult_add is
  generic(
    g_din_a_w        : positive := 4;
    g_din_a_binpnt   : natural  := 0;
    g_din_b_w        : positive := 4;
    g_din_b_binpnt   : natural  := 0;
    g_din_c_w        : positive := 9;
    g_din_c_binpnt   : natural  := 0;
    g_dout_w         : positive := 9;
    g_dout_binpnt    : natural  := 0;
    g_add_sub        : natural  := C_LM_ADD;
    g_round_mode     : natural  := C_LM_TRUNC_BITS;
    g_representation : natural  := C_LM_UNSIGNED;
    g_overflow       : natural  := C_LM_WRAP;
    g_pipe_stages    : natural  := 0
    );
end entity tb_neg_mult_add;

architecture a_tb of tb_neg_mult_add is
  signal clk_tb : std_logic := '0';
  signal s_din1 : std_logic_vector(g_din_a_w - 1 downto 0) := (others => '1');
  signal s_din2 : std_logic_vector(g_din_b_w - 1 downto 0) := (others => '1');
  signal s_din3 : std_logic_vector(g_din_c_w - 1 downto 0) := (others => '0');
  signal s_dout : std_logic_vector(g_dout_w - 1 downto 0);
begin

  clk_tb <= not clk_tb after 5 ns;

  dut : entity lm_math_fi_lib.lm_math_fi_mult_add
    generic map(
      g_din_a_w => g_din_a_w, g_din_a_binpnt => g_din_a_binpnt,
      g_din_b_w => g_din_b_w, g_din_b_binpnt => g_din_b_binpnt,
      g_din_c_w => g_din_c_w, g_din_c_binpnt => g_din_c_binpnt,
      g_dout_w => g_dout_w, g_dout_binpnt => g_dout_binpnt,
      g_add_sub => g_add_sub, g_round_mode => g_round_mode,
      g_representation => g_representation, g_overflow => g_overflow,
      g_pipe_stages => g_pipe_stages)
    port map(clk_i => clk_tb, ce_i => '1',
             din1_i => s_din1, din2_i => s_din2, din3_i => s_din3, dout_o => s_dout);

  -- Emitted at the first simulation delta. A case that is supposed to be
  -- rejected by a generic's subtype must never reach this: the design does
  -- not elaborate, so simulation never starts. The runner uses the absence
  -- of this marker as its phase check, independently of anything the
  -- simulator chooses to print.
  proc_started : process
  begin
    report "GENERIC DOMAIN TB STARTED: tb_neg_mult_add" severity note;
    wait;
  end process proc_started;

  proc_guard : process
  begin
    wait for 50 ns;
    report "GENERIC DOMAIN TB COMPLETED: tb_neg_mult_add" severity note;
    wait;
  end process proc_guard;

end architecture a_tb;
