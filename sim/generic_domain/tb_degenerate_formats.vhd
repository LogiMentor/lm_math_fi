-- SPDX-License-Identifier: Apache-2.0
-- Copyright 2026 LogiMentor
--
-- GENERATED FILE - do not edit by hand.
-- Produced by scripts/gen_format_vectors.py; the generic-domain gate runs that
-- script with --check on every invocation, so an edit here fails the gate.
--
-- Value checks for every quantizing entity at degenerate binary points.
--
-- A binary point equal to or greater than its width is a legal fixed-point
-- format: every bit is fractional and the point sits outside the word. Nothing
-- constrains a binary point against a width, so every module must produce the
-- right answer for one, not merely elaborate. tb_legal_sweep covers elaboration;
-- this testbench covers the results.
--
-- COVERAGE, derived from the cases below:
--   lm_math_fi_format
--     families: ordinary, bp_equals_width, bp_above_width_src, bp_above_width_dst, disjoint_dst_above, disjoint_dst_below, one_bit_overlap, width_1
--     width-1 signedness: S, U
--   lm_math_fi_mult
--     families: ordinary, bp_equals_width, bp_above_width_src, bp_above_width_dst, disjoint_dst_above, disjoint_dst_below, one_bit_overlap, width_1
--     width-1 signedness: S, U
--   lm_math_fi_add_sub
--     families: ordinary, bp_equals_width, bp_above_width_src, bp_above_width_dst, disjoint_dst_above, disjoint_dst_below, one_bit_overlap, width_1
--     width-1 signedness: S, U
--   lm_math_fi_mult_add
--     families: ordinary, bp_equals_width, bp_above_width_src, bp_above_width_dst, disjoint_dst_above, disjoint_dst_below, one_bit_overlap, width_1
--     width-1 signedness: S, U
--
-- HOW THE EXPECTED VALUES WERE PRODUCED
--   By scripts/gen_format_vectors.py, which computes the arithmetic from the
--   documented semantics using arbitrary-precision integers and fractions. It
--   implements the whole path from input decoding to emitted expectation twice,
--   in two pipelines that share no arithmetic, and refuses to emit unless both
--   agree. It imports nothing from src/, model/ or js/.
--
--   For the three arithmetic modules the reference also models each module's own
--   internal intermediate format, because that is part of the library's defined
--   behaviour: operands are aligned into the internal format and the accumulator
--   wraps there. That is what makes an unsigned subtraction that goes negative
--   wrap rather than clamp, which sim/tb/tb_lm_math_fi_add_sub.vhd already
--   relies on. Both references necessarily model that structure the same way;
--   the doubling catches an arithmetic slip, not a shared misreading.

library ieee;
use ieee.std_logic_1164.all;

library lm_math_fi_lib;
use lm_math_fi_lib.lm_math_fi_pkg.all;
use lm_math_fi_lib.tb_lm_math_fi_test_pkg.all;

entity tb_degenerate_formats is
end entity tb_degenerate_formats;

architecture a_tb of tb_degenerate_formats is
  signal s_done  : boolean := false;
  signal clk_tb  : std_logic := '0';

  signal s_f_ordinary_u_din  : std_logic_vector(5 downto 0) := (others => '0');
  signal s_f_ordinary_u_dout : std_logic_vector(3 downto 0);
  signal s_f_ordinary_s_din  : std_logic_vector(5 downto 0) := (others => '0');
  signal s_f_ordinary_s_dout : std_logic_vector(3 downto 0);
  signal s_f_bpeq_u_din  : std_logic_vector(3 downto 0) := (others => '0');
  signal s_f_bpeq_u_dout : std_logic_vector(3 downto 0);
  signal s_f_bpeq_s_din  : std_logic_vector(3 downto 0) := (others => '0');
  signal s_f_bpeq_s_dout : std_logic_vector(3 downto 0);
  signal s_f_bpgt_src_u_din  : std_logic_vector(3 downto 0) := (others => '0');
  signal s_f_bpgt_src_u_dout : std_logic_vector(3 downto 0);
  signal s_f_bpgt_src_s_din  : std_logic_vector(3 downto 0) := (others => '0');
  signal s_f_bpgt_src_s_dout : std_logic_vector(3 downto 0);
  signal s_f_bpgt_dst_u_din  : std_logic_vector(3 downto 0) := (others => '0');
  signal s_f_bpgt_dst_u_dout : std_logic_vector(3 downto 0);
  signal s_f_bpgt_dst_s_din  : std_logic_vector(3 downto 0) := (others => '0');
  signal s_f_bpgt_dst_s_dout : std_logic_vector(3 downto 0);
  signal s_f_bpgt_both_s_din  : std_logic_vector(3 downto 0) := (others => '0');
  signal s_f_bpgt_both_s_dout : std_logic_vector(3 downto 0);
  signal s_f_disj_above_s_din  : std_logic_vector(3 downto 0) := (others => '0');
  signal s_f_disj_above_s_dout : std_logic_vector(3 downto 0);
  signal s_f_disj_below_u_din  : std_logic_vector(3 downto 0) := (others => '0');
  signal s_f_disj_below_u_dout : std_logic_vector(3 downto 0);
  signal s_f_overlap1_u_din  : std_logic_vector(3 downto 0) := (others => '0');
  signal s_f_overlap1_u_dout : std_logic_vector(3 downto 0);
  signal s_f_w1_u_din  : std_logic_vector(0 downto 0) := (others => '0');
  signal s_f_w1_u_dout : std_logic_vector(0 downto 0);
  signal s_f_w1_s_din  : std_logic_vector(0 downto 0) := (others => '0');
  signal s_f_w1_s_dout : std_logic_vector(0 downto 0);
  signal s_f_w1_from_wide_s_din  : std_logic_vector(3 downto 0) := (others => '0');
  signal s_f_w1_from_wide_s_dout : std_logic_vector(0 downto 0);
  signal s_f_w1_to_wide_s_din  : std_logic_vector(0 downto 0) := (others => '0');
  signal s_f_w1_to_wide_s_dout : std_logic_vector(3 downto 0);
  signal s_m_ordinary_s_a    : std_logic_vector(3 downto 0) := (others => '0');
  signal s_m_ordinary_s_b    : std_logic_vector(3 downto 0) := (others => '0');
  signal s_m_ordinary_s_dout : std_logic_vector(5 downto 0);
  signal s_m_bpeq_u_a    : std_logic_vector(3 downto 0) := (others => '0');
  signal s_m_bpeq_u_b    : std_logic_vector(3 downto 0) := (others => '0');
  signal s_m_bpeq_u_dout : std_logic_vector(3 downto 0);
  signal s_m_bpeq_s_a    : std_logic_vector(3 downto 0) := (others => '0');
  signal s_m_bpeq_s_b    : std_logic_vector(3 downto 0) := (others => '0');
  signal s_m_bpeq_s_dout : std_logic_vector(3 downto 0);
  signal s_m_bpgt_s_a    : std_logic_vector(3 downto 0) := (others => '0');
  signal s_m_bpgt_s_b    : std_logic_vector(3 downto 0) := (others => '0');
  signal s_m_bpgt_s_dout : std_logic_vector(3 downto 0);
  signal s_m_bpgt_dst_u_a    : std_logic_vector(3 downto 0) := (others => '0');
  signal s_m_bpgt_dst_u_b    : std_logic_vector(3 downto 0) := (others => '0');
  signal s_m_bpgt_dst_u_dout : std_logic_vector(3 downto 0);
  signal s_m_disj_below_u_a    : std_logic_vector(3 downto 0) := (others => '0');
  signal s_m_disj_below_u_b    : std_logic_vector(3 downto 0) := (others => '0');
  signal s_m_disj_below_u_dout : std_logic_vector(3 downto 0);
  signal s_m_disj_above_s_a    : std_logic_vector(3 downto 0) := (others => '0');
  signal s_m_disj_above_s_b    : std_logic_vector(3 downto 0) := (others => '0');
  signal s_m_disj_above_s_dout : std_logic_vector(3 downto 0);
  signal s_m_overlap1_u_a    : std_logic_vector(3 downto 0) := (others => '0');
  signal s_m_overlap1_u_b    : std_logic_vector(3 downto 0) := (others => '0');
  signal s_m_overlap1_u_dout : std_logic_vector(3 downto 0);
  signal s_m_w1_u_a    : std_logic_vector(0 downto 0) := (others => '0');
  signal s_m_w1_u_b    : std_logic_vector(0 downto 0) := (others => '0');
  signal s_m_w1_u_dout : std_logic_vector(0 downto 0);
  signal s_m_w1_s_a    : std_logic_vector(0 downto 0) := (others => '0');
  signal s_m_w1_s_b    : std_logic_vector(0 downto 0) := (others => '0');
  signal s_m_w1_s_dout : std_logic_vector(0 downto 0);
  signal s_a_ordinary_s_a    : std_logic_vector(3 downto 0) := (others => '0');
  signal s_a_ordinary_s_b    : std_logic_vector(3 downto 0) := (others => '0');
  signal s_a_ordinary_s_dout : std_logic_vector(5 downto 0);
  signal s_a_bpeq_u_a    : std_logic_vector(3 downto 0) := (others => '0');
  signal s_a_bpeq_u_b    : std_logic_vector(3 downto 0) := (others => '0');
  signal s_a_bpeq_u_dout : std_logic_vector(3 downto 0);
  signal s_a_bpeq_s_a    : std_logic_vector(3 downto 0) := (others => '0');
  signal s_a_bpeq_s_b    : std_logic_vector(3 downto 0) := (others => '0');
  signal s_a_bpeq_s_dout : std_logic_vector(3 downto 0);
  signal s_a_bpgt_s_a    : std_logic_vector(3 downto 0) := (others => '0');
  signal s_a_bpgt_s_b    : std_logic_vector(3 downto 0) := (others => '0');
  signal s_a_bpgt_s_dout : std_logic_vector(3 downto 0);
  signal s_a_bpgt_src_u_a    : std_logic_vector(3 downto 0) := (others => '0');
  signal s_a_bpgt_src_u_b    : std_logic_vector(3 downto 0) := (others => '0');
  signal s_a_bpgt_src_u_dout : std_logic_vector(3 downto 0);
  signal s_a_disj_below_u_a    : std_logic_vector(3 downto 0) := (others => '0');
  signal s_a_disj_below_u_b    : std_logic_vector(3 downto 0) := (others => '0');
  signal s_a_disj_below_u_dout : std_logic_vector(3 downto 0);
  signal s_a_disj_above_s_a    : std_logic_vector(3 downto 0) := (others => '0');
  signal s_a_disj_above_s_b    : std_logic_vector(3 downto 0) := (others => '0');
  signal s_a_disj_above_s_dout : std_logic_vector(3 downto 0);
  signal s_a_overlap1_u_a    : std_logic_vector(3 downto 0) := (others => '0');
  signal s_a_overlap1_u_b    : std_logic_vector(3 downto 0) := (others => '0');
  signal s_a_overlap1_u_dout : std_logic_vector(3 downto 0);
  signal s_a_w1_u_a    : std_logic_vector(0 downto 0) := (others => '0');
  signal s_a_w1_u_b    : std_logic_vector(0 downto 0) := (others => '0');
  signal s_a_w1_u_dout : std_logic_vector(0 downto 0);
  signal s_a_w1_s_a    : std_logic_vector(0 downto 0) := (others => '0');
  signal s_a_w1_s_b    : std_logic_vector(0 downto 0) := (others => '0');
  signal s_a_w1_s_dout : std_logic_vector(0 downto 0);
  signal s_ma_bpeq_u_a    : std_logic_vector(3 downto 0) := (others => '0');
  signal s_ma_bpeq_u_b    : std_logic_vector(3 downto 0) := (others => '0');
  signal s_ma_bpeq_u_c    : std_logic_vector(7 downto 0) := (others => '0');
  signal s_ma_bpeq_u_dout : std_logic_vector(7 downto 0);
  signal s_ma_bpeq_s_a    : std_logic_vector(3 downto 0) := (others => '0');
  signal s_ma_bpeq_s_b    : std_logic_vector(3 downto 0) := (others => '0');
  signal s_ma_bpeq_s_c    : std_logic_vector(7 downto 0) := (others => '0');
  signal s_ma_bpeq_s_dout : std_logic_vector(7 downto 0);
  signal s_ma_bpgt_ops_s_a    : std_logic_vector(3 downto 0) := (others => '0');
  signal s_ma_bpgt_ops_s_b    : std_logic_vector(3 downto 0) := (others => '0');
  signal s_ma_bpgt_ops_s_c    : std_logic_vector(7 downto 0) := (others => '0');
  signal s_ma_bpgt_ops_s_dout : std_logic_vector(7 downto 0);
  signal s_ma_bpgt_addend_s_a    : std_logic_vector(3 downto 0) := (others => '0');
  signal s_ma_bpgt_addend_s_b    : std_logic_vector(3 downto 0) := (others => '0');
  signal s_ma_bpgt_addend_s_c    : std_logic_vector(7 downto 0) := (others => '0');
  signal s_ma_bpgt_addend_s_dout : std_logic_vector(7 downto 0);
  signal s_ma_bpgt_all_u_a    : std_logic_vector(3 downto 0) := (others => '0');
  signal s_ma_bpgt_all_u_b    : std_logic_vector(3 downto 0) := (others => '0');
  signal s_ma_bpgt_all_u_c    : std_logic_vector(7 downto 0) := (others => '0');
  signal s_ma_bpgt_all_u_dout : std_logic_vector(7 downto 0);
  signal s_ma_bpgt_out_s_a    : std_logic_vector(3 downto 0) := (others => '0');
  signal s_ma_bpgt_out_s_b    : std_logic_vector(3 downto 0) := (others => '0');
  signal s_ma_bpgt_out_s_c    : std_logic_vector(7 downto 0) := (others => '0');
  signal s_ma_bpgt_out_s_dout : std_logic_vector(3 downto 0);
  signal s_ma_disj_below_u_a    : std_logic_vector(3 downto 0) := (others => '0');
  signal s_ma_disj_below_u_b    : std_logic_vector(3 downto 0) := (others => '0');
  signal s_ma_disj_below_u_c    : std_logic_vector(7 downto 0) := (others => '0');
  signal s_ma_disj_below_u_dout : std_logic_vector(3 downto 0);
  signal s_ma_disj_above_s_a    : std_logic_vector(3 downto 0) := (others => '0');
  signal s_ma_disj_above_s_b    : std_logic_vector(3 downto 0) := (others => '0');
  signal s_ma_disj_above_s_c    : std_logic_vector(7 downto 0) := (others => '0');
  signal s_ma_disj_above_s_dout : std_logic_vector(3 downto 0);
  signal s_ma_overlap1_u_a    : std_logic_vector(3 downto 0) := (others => '0');
  signal s_ma_overlap1_u_b    : std_logic_vector(3 downto 0) := (others => '0');
  signal s_ma_overlap1_u_c    : std_logic_vector(7 downto 0) := (others => '0');
  signal s_ma_overlap1_u_dout : std_logic_vector(3 downto 0);
  signal s_ma_w1_u_a    : std_logic_vector(0 downto 0) := (others => '0');
  signal s_ma_w1_u_b    : std_logic_vector(0 downto 0) := (others => '0');
  signal s_ma_w1_u_c    : std_logic_vector(0 downto 0) := (others => '0');
  signal s_ma_w1_u_dout : std_logic_vector(0 downto 0);
  signal s_ma_w1_s_a    : std_logic_vector(0 downto 0) := (others => '0');
  signal s_ma_w1_s_b    : std_logic_vector(0 downto 0) := (others => '0');
  signal s_ma_w1_s_c    : std_logic_vector(0 downto 0) := (others => '0');
  signal s_ma_w1_s_dout : std_logic_vector(0 downto 0);

  -- Settle long enough for the modules with a registered stage (mult and
  -- mult_add are one clock; format and add_sub are combinational here).
  procedure p_settle(signal clk : in std_logic) is
  begin
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    wait for 1 ns;
  end procedure;

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

  inst_f_ordinary_u : entity lm_math_fi_lib.lm_math_fi_format
    generic map(g_din_w => 6, g_din_binpnt => 2,
                g_dout_w => 4, g_dout_binpnt => 1,
                g_pipe_stages => 0, g_round_mode => C_LM_ROUND_EVEN,
                g_overflow => C_LM_SATURATE,
                g_representation => C_LM_UNSIGNED)
    port map(clk_i => clk_tb, ce_i => '1', din_i => s_f_ordinary_u_din, dout_o => s_f_ordinary_u_dout);

  inst_f_ordinary_s : entity lm_math_fi_lib.lm_math_fi_format
    generic map(g_din_w => 6, g_din_binpnt => 2,
                g_dout_w => 4, g_dout_binpnt => 1,
                g_pipe_stages => 0, g_round_mode => C_LM_ROUND_EVEN,
                g_overflow => C_LM_SATURATE,
                g_representation => C_LM_SIGNED)
    port map(clk_i => clk_tb, ce_i => '1', din_i => s_f_ordinary_s_din, dout_o => s_f_ordinary_s_dout);

  inst_f_bpeq_u : entity lm_math_fi_lib.lm_math_fi_format
    generic map(g_din_w => 4, g_din_binpnt => 4,
                g_dout_w => 4, g_dout_binpnt => 4,
                g_pipe_stages => 0, g_round_mode => C_LM_ROUND_EVEN,
                g_overflow => C_LM_SATURATE,
                g_representation => C_LM_UNSIGNED)
    port map(clk_i => clk_tb, ce_i => '1', din_i => s_f_bpeq_u_din, dout_o => s_f_bpeq_u_dout);

  inst_f_bpeq_s : entity lm_math_fi_lib.lm_math_fi_format
    generic map(g_din_w => 4, g_din_binpnt => 4,
                g_dout_w => 4, g_dout_binpnt => 4,
                g_pipe_stages => 0, g_round_mode => C_LM_ROUND_EVEN,
                g_overflow => C_LM_SATURATE,
                g_representation => C_LM_SIGNED)
    port map(clk_i => clk_tb, ce_i => '1', din_i => s_f_bpeq_s_din, dout_o => s_f_bpeq_s_dout);

  inst_f_bpgt_src_u : entity lm_math_fi_lib.lm_math_fi_format
    generic map(g_din_w => 4, g_din_binpnt => 8,
                g_dout_w => 4, g_dout_binpnt => 2,
                g_pipe_stages => 0, g_round_mode => C_LM_TRUNC_BITS,
                g_overflow => C_LM_WRAP,
                g_representation => C_LM_UNSIGNED)
    port map(clk_i => clk_tb, ce_i => '1', din_i => s_f_bpgt_src_u_din, dout_o => s_f_bpgt_src_u_dout);

  inst_f_bpgt_src_s : entity lm_math_fi_lib.lm_math_fi_format
    generic map(g_din_w => 4, g_din_binpnt => 8,
                g_dout_w => 4, g_dout_binpnt => 2,
                g_pipe_stages => 0, g_round_mode => C_LM_TRUNC_BITS,
                g_overflow => C_LM_WRAP,
                g_representation => C_LM_SIGNED)
    port map(clk_i => clk_tb, ce_i => '1', din_i => s_f_bpgt_src_s_din, dout_o => s_f_bpgt_src_s_dout);

  inst_f_bpgt_dst_u : entity lm_math_fi_lib.lm_math_fi_format
    generic map(g_din_w => 4, g_din_binpnt => 2,
                g_dout_w => 4, g_dout_binpnt => 8,
                g_pipe_stages => 0, g_round_mode => C_LM_ROUND_AWAY,
                g_overflow => C_LM_SATURATE,
                g_representation => C_LM_UNSIGNED)
    port map(clk_i => clk_tb, ce_i => '1', din_i => s_f_bpgt_dst_u_din, dout_o => s_f_bpgt_dst_u_dout);

  inst_f_bpgt_dst_s : entity lm_math_fi_lib.lm_math_fi_format
    generic map(g_din_w => 4, g_din_binpnt => 2,
                g_dout_w => 4, g_dout_binpnt => 8,
                g_pipe_stages => 0, g_round_mode => C_LM_ROUND_AWAY,
                g_overflow => C_LM_SATURATE,
                g_representation => C_LM_SIGNED)
    port map(clk_i => clk_tb, ce_i => '1', din_i => s_f_bpgt_dst_s_din, dout_o => s_f_bpgt_dst_s_dout);

  inst_f_bpgt_both_s : entity lm_math_fi_lib.lm_math_fi_format
    generic map(g_din_w => 4, g_din_binpnt => 8,
                g_dout_w => 4, g_dout_binpnt => 6,
                g_pipe_stages => 0, g_round_mode => C_LM_ROUND_EVEN,
                g_overflow => C_LM_SATURATE,
                g_representation => C_LM_SIGNED)
    port map(clk_i => clk_tb, ce_i => '1', din_i => s_f_bpgt_both_s_din, dout_o => s_f_bpgt_both_s_dout);

  inst_f_disj_above_s : entity lm_math_fi_lib.lm_math_fi_format
    generic map(g_din_w => 4, g_din_binpnt => 8,
                g_dout_w => 4, g_dout_binpnt => 0,
                g_pipe_stages => 0, g_round_mode => C_LM_ROUND_AWAY,
                g_overflow => C_LM_SATURATE,
                g_representation => C_LM_SIGNED)
    port map(clk_i => clk_tb, ce_i => '1', din_i => s_f_disj_above_s_din, dout_o => s_f_disj_above_s_dout);

  inst_f_disj_below_u : entity lm_math_fi_lib.lm_math_fi_format
    generic map(g_din_w => 4, g_din_binpnt => 0,
                g_dout_w => 4, g_dout_binpnt => 8,
                g_pipe_stages => 0, g_round_mode => C_LM_TRUNC_BITS,
                g_overflow => C_LM_SATURATE,
                g_representation => C_LM_UNSIGNED)
    port map(clk_i => clk_tb, ce_i => '1', din_i => s_f_disj_below_u_din, dout_o => s_f_disj_below_u_dout);

  inst_f_overlap1_u : entity lm_math_fi_lib.lm_math_fi_format
    generic map(g_din_w => 4, g_din_binpnt => 4,
                g_dout_w => 4, g_dout_binpnt => 1,
                g_pipe_stages => 0, g_round_mode => C_LM_ROUND_EVEN,
                g_overflow => C_LM_WRAP,
                g_representation => C_LM_UNSIGNED)
    port map(clk_i => clk_tb, ce_i => '1', din_i => s_f_overlap1_u_din, dout_o => s_f_overlap1_u_dout);

  inst_f_w1_u : entity lm_math_fi_lib.lm_math_fi_format
    generic map(g_din_w => 1, g_din_binpnt => 1,
                g_dout_w => 1, g_dout_binpnt => 1,
                g_pipe_stages => 0, g_round_mode => C_LM_ROUND_EVEN,
                g_overflow => C_LM_SATURATE,
                g_representation => C_LM_UNSIGNED)
    port map(clk_i => clk_tb, ce_i => '1', din_i => s_f_w1_u_din, dout_o => s_f_w1_u_dout);

  inst_f_w1_s : entity lm_math_fi_lib.lm_math_fi_format
    generic map(g_din_w => 1, g_din_binpnt => 1,
                g_dout_w => 1, g_dout_binpnt => 1,
                g_pipe_stages => 0, g_round_mode => C_LM_ROUND_EVEN,
                g_overflow => C_LM_SATURATE,
                g_representation => C_LM_SIGNED)
    port map(clk_i => clk_tb, ce_i => '1', din_i => s_f_w1_s_din, dout_o => s_f_w1_s_dout);

  inst_f_w1_from_wide_s : entity lm_math_fi_lib.lm_math_fi_format
    generic map(g_din_w => 4, g_din_binpnt => 3,
                g_dout_w => 1, g_dout_binpnt => 1,
                g_pipe_stages => 0, g_round_mode => C_LM_ROUND_EVEN,
                g_overflow => C_LM_SATURATE,
                g_representation => C_LM_SIGNED)
    port map(clk_i => clk_tb, ce_i => '1', din_i => s_f_w1_from_wide_s_din, dout_o => s_f_w1_from_wide_s_dout);

  inst_f_w1_to_wide_s : entity lm_math_fi_lib.lm_math_fi_format
    generic map(g_din_w => 1, g_din_binpnt => 3,
                g_dout_w => 4, g_dout_binpnt => 1,
                g_pipe_stages => 0, g_round_mode => C_LM_ROUND_EVEN,
                g_overflow => C_LM_SATURATE,
                g_representation => C_LM_SIGNED)
    port map(clk_i => clk_tb, ce_i => '1', din_i => s_f_w1_to_wide_s_din, dout_o => s_f_w1_to_wide_s_dout);

  inst_m_ordinary_s : entity lm_math_fi_lib.lm_math_fi_mult
    generic map(g_din_a_w => 4, g_din_a_binpnt => 1,
                g_din_b_w => 4, g_din_b_binpnt => 1,
                g_dout_w => 6, g_dout_binpnt => 2,
                g_round_mode => C_LM_ROUND_EVEN,
                g_din_a_type => C_LM_SIGNED,
                g_din_b_type => C_LM_SIGNED,
                g_dout_type => C_LM_SIGNED,
                g_overflow => C_LM_SATURATE, g_pipe_stages => 0)
    port map(clk_i => clk_tb, ce_i => '1', din1_i => s_m_ordinary_s_a, din2_i => s_m_ordinary_s_b,
             dout_o => s_m_ordinary_s_dout);

  inst_m_bpeq_u : entity lm_math_fi_lib.lm_math_fi_mult
    generic map(g_din_a_w => 4, g_din_a_binpnt => 4,
                g_din_b_w => 4, g_din_b_binpnt => 4,
                g_dout_w => 4, g_dout_binpnt => 4,
                g_round_mode => C_LM_ROUND_EVEN,
                g_din_a_type => C_LM_UNSIGNED,
                g_din_b_type => C_LM_UNSIGNED,
                g_dout_type => C_LM_UNSIGNED,
                g_overflow => C_LM_SATURATE, g_pipe_stages => 0)
    port map(clk_i => clk_tb, ce_i => '1', din1_i => s_m_bpeq_u_a, din2_i => s_m_bpeq_u_b,
             dout_o => s_m_bpeq_u_dout);

  inst_m_bpeq_s : entity lm_math_fi_lib.lm_math_fi_mult
    generic map(g_din_a_w => 4, g_din_a_binpnt => 4,
                g_din_b_w => 4, g_din_b_binpnt => 4,
                g_dout_w => 4, g_dout_binpnt => 4,
                g_round_mode => C_LM_ROUND_EVEN,
                g_din_a_type => C_LM_SIGNED,
                g_din_b_type => C_LM_SIGNED,
                g_dout_type => C_LM_SIGNED,
                g_overflow => C_LM_SATURATE, g_pipe_stages => 0)
    port map(clk_i => clk_tb, ce_i => '1', din1_i => s_m_bpeq_s_a, din2_i => s_m_bpeq_s_b,
             dout_o => s_m_bpeq_s_dout);

  inst_m_bpgt_s : entity lm_math_fi_lib.lm_math_fi_mult
    generic map(g_din_a_w => 4, g_din_a_binpnt => 6,
                g_din_b_w => 4, g_din_b_binpnt => 6,
                g_dout_w => 4, g_dout_binpnt => 8,
                g_round_mode => C_LM_TRUNC_BITS,
                g_din_a_type => C_LM_SIGNED,
                g_din_b_type => C_LM_SIGNED,
                g_dout_type => C_LM_SIGNED,
                g_overflow => C_LM_WRAP, g_pipe_stages => 0)
    port map(clk_i => clk_tb, ce_i => '1', din1_i => s_m_bpgt_s_a, din2_i => s_m_bpgt_s_b,
             dout_o => s_m_bpgt_s_dout);

  inst_m_bpgt_dst_u : entity lm_math_fi_lib.lm_math_fi_mult
    generic map(g_din_a_w => 4, g_din_a_binpnt => 1,
                g_din_b_w => 4, g_din_b_binpnt => 1,
                g_dout_w => 4, g_dout_binpnt => 9,
                g_round_mode => C_LM_ROUND_EVEN,
                g_din_a_type => C_LM_UNSIGNED,
                g_din_b_type => C_LM_UNSIGNED,
                g_dout_type => C_LM_UNSIGNED,
                g_overflow => C_LM_SATURATE, g_pipe_stages => 0)
    port map(clk_i => clk_tb, ce_i => '1', din1_i => s_m_bpgt_dst_u_a, din2_i => s_m_bpgt_dst_u_b,
             dout_o => s_m_bpgt_dst_u_dout);

  inst_m_disj_below_u : entity lm_math_fi_lib.lm_math_fi_mult
    generic map(g_din_a_w => 4, g_din_a_binpnt => 0,
                g_din_b_w => 4, g_din_b_binpnt => 0,
                g_dout_w => 4, g_dout_binpnt => 12,
                g_round_mode => C_LM_TRUNC_BITS,
                g_din_a_type => C_LM_UNSIGNED,
                g_din_b_type => C_LM_UNSIGNED,
                g_dout_type => C_LM_UNSIGNED,
                g_overflow => C_LM_SATURATE, g_pipe_stages => 0)
    port map(clk_i => clk_tb, ce_i => '1', din1_i => s_m_disj_below_u_a, din2_i => s_m_disj_below_u_b,
             dout_o => s_m_disj_below_u_dout);

  inst_m_disj_above_s : entity lm_math_fi_lib.lm_math_fi_mult
    generic map(g_din_a_w => 4, g_din_a_binpnt => 8,
                g_din_b_w => 4, g_din_b_binpnt => 8,
                g_dout_w => 4, g_dout_binpnt => 0,
                g_round_mode => C_LM_ROUND_AWAY,
                g_din_a_type => C_LM_SIGNED,
                g_din_b_type => C_LM_SIGNED,
                g_dout_type => C_LM_SIGNED,
                g_overflow => C_LM_SATURATE, g_pipe_stages => 0)
    port map(clk_i => clk_tb, ce_i => '1', din1_i => s_m_disj_above_s_a, din2_i => s_m_disj_above_s_b,
             dout_o => s_m_disj_above_s_dout);

  inst_m_overlap1_u : entity lm_math_fi_lib.lm_math_fi_mult
    generic map(g_din_a_w => 4, g_din_a_binpnt => 4,
                g_din_b_w => 4, g_din_b_binpnt => 4,
                g_dout_w => 4, g_dout_binpnt => 1,
                g_round_mode => C_LM_ROUND_EVEN,
                g_din_a_type => C_LM_UNSIGNED,
                g_din_b_type => C_LM_UNSIGNED,
                g_dout_type => C_LM_UNSIGNED,
                g_overflow => C_LM_WRAP, g_pipe_stages => 0)
    port map(clk_i => clk_tb, ce_i => '1', din1_i => s_m_overlap1_u_a, din2_i => s_m_overlap1_u_b,
             dout_o => s_m_overlap1_u_dout);

  inst_m_w1_u : entity lm_math_fi_lib.lm_math_fi_mult
    generic map(g_din_a_w => 1, g_din_a_binpnt => 1,
                g_din_b_w => 1, g_din_b_binpnt => 1,
                g_dout_w => 1, g_dout_binpnt => 1,
                g_round_mode => C_LM_ROUND_EVEN,
                g_din_a_type => C_LM_UNSIGNED,
                g_din_b_type => C_LM_UNSIGNED,
                g_dout_type => C_LM_UNSIGNED,
                g_overflow => C_LM_SATURATE, g_pipe_stages => 0)
    port map(clk_i => clk_tb, ce_i => '1', din1_i => s_m_w1_u_a, din2_i => s_m_w1_u_b,
             dout_o => s_m_w1_u_dout);

  inst_m_w1_s : entity lm_math_fi_lib.lm_math_fi_mult
    generic map(g_din_a_w => 1, g_din_a_binpnt => 1,
                g_din_b_w => 1, g_din_b_binpnt => 1,
                g_dout_w => 1, g_dout_binpnt => 1,
                g_round_mode => C_LM_ROUND_EVEN,
                g_din_a_type => C_LM_SIGNED,
                g_din_b_type => C_LM_SIGNED,
                g_dout_type => C_LM_SIGNED,
                g_overflow => C_LM_SATURATE, g_pipe_stages => 0)
    port map(clk_i => clk_tb, ce_i => '1', din1_i => s_m_w1_s_a, din2_i => s_m_w1_s_b,
             dout_o => s_m_w1_s_dout);

  inst_a_ordinary_s : entity lm_math_fi_lib.lm_math_fi_add_sub
    generic map(g_direction => C_LM_ADD,
                g_representation => C_LM_SIGNED,
                g_pipeline_input => 0, g_pipeline_output => 0,
                g_din1_w => 4, g_din1_binpnt => 1,
                g_din2_w => 4, g_din2_binpnt => 1,
                g_dout_w => 6, g_dout_binpnt => 2,
                g_round_mode => C_LM_ROUND_EVEN)
    port map(clk_i => clk_tb, ce_i => '1', sel_add_i => '1',
             din1_i => s_a_ordinary_s_a, din2_i => s_a_ordinary_s_b, dout_o => s_a_ordinary_s_dout);

  inst_a_bpeq_u : entity lm_math_fi_lib.lm_math_fi_add_sub
    generic map(g_direction => C_LM_ADD,
                g_representation => C_LM_UNSIGNED,
                g_pipeline_input => 0, g_pipeline_output => 0,
                g_din1_w => 4, g_din1_binpnt => 4,
                g_din2_w => 4, g_din2_binpnt => 4,
                g_dout_w => 4, g_dout_binpnt => 4,
                g_round_mode => C_LM_ROUND_EVEN)
    port map(clk_i => clk_tb, ce_i => '1', sel_add_i => '1',
             din1_i => s_a_bpeq_u_a, din2_i => s_a_bpeq_u_b, dout_o => s_a_bpeq_u_dout);

  inst_a_bpeq_s : entity lm_math_fi_lib.lm_math_fi_add_sub
    generic map(g_direction => C_LM_ADD,
                g_representation => C_LM_SIGNED,
                g_pipeline_input => 0, g_pipeline_output => 0,
                g_din1_w => 4, g_din1_binpnt => 4,
                g_din2_w => 4, g_din2_binpnt => 4,
                g_dout_w => 4, g_dout_binpnt => 4,
                g_round_mode => C_LM_ROUND_EVEN)
    port map(clk_i => clk_tb, ce_i => '1', sel_add_i => '1',
             din1_i => s_a_bpeq_s_a, din2_i => s_a_bpeq_s_b, dout_o => s_a_bpeq_s_dout);

  inst_a_bpgt_s : entity lm_math_fi_lib.lm_math_fi_add_sub
    generic map(g_direction => C_LM_SUB,
                g_representation => C_LM_SIGNED,
                g_pipeline_input => 0, g_pipeline_output => 0,
                g_din1_w => 4, g_din1_binpnt => 8,
                g_din2_w => 4, g_din2_binpnt => 6,
                g_dout_w => 4, g_dout_binpnt => 9,
                g_round_mode => C_LM_ROUND_EVEN)
    port map(clk_i => clk_tb, ce_i => '1', sel_add_i => '1',
             din1_i => s_a_bpgt_s_a, din2_i => s_a_bpgt_s_b, dout_o => s_a_bpgt_s_dout);

  inst_a_bpgt_src_u : entity lm_math_fi_lib.lm_math_fi_add_sub
    generic map(g_direction => C_LM_ADD,
                g_representation => C_LM_UNSIGNED,
                g_pipeline_input => 0, g_pipeline_output => 0,
                g_din1_w => 4, g_din1_binpnt => 6,
                g_din2_w => 4, g_din2_binpnt => 6,
                g_dout_w => 4, g_dout_binpnt => 2,
                g_round_mode => C_LM_TRUNC_BITS)
    port map(clk_i => clk_tb, ce_i => '1', sel_add_i => '1',
             din1_i => s_a_bpgt_src_u_a, din2_i => s_a_bpgt_src_u_b, dout_o => s_a_bpgt_src_u_dout);

  inst_a_disj_below_u : entity lm_math_fi_lib.lm_math_fi_add_sub
    generic map(g_direction => C_LM_ADD,
                g_representation => C_LM_UNSIGNED,
                g_pipeline_input => 0, g_pipeline_output => 0,
                g_din1_w => 4, g_din1_binpnt => 0,
                g_din2_w => 4, g_din2_binpnt => 0,
                g_dout_w => 4, g_dout_binpnt => 10,
                g_round_mode => C_LM_TRUNC_BITS)
    port map(clk_i => clk_tb, ce_i => '1', sel_add_i => '1',
             din1_i => s_a_disj_below_u_a, din2_i => s_a_disj_below_u_b, dout_o => s_a_disj_below_u_dout);

  inst_a_disj_above_s : entity lm_math_fi_lib.lm_math_fi_add_sub
    generic map(g_direction => C_LM_ADD,
                g_representation => C_LM_SIGNED,
                g_pipeline_input => 0, g_pipeline_output => 0,
                g_din1_w => 4, g_din1_binpnt => 8,
                g_din2_w => 4, g_din2_binpnt => 8,
                g_dout_w => 4, g_dout_binpnt => 0,
                g_round_mode => C_LM_ROUND_AWAY)
    port map(clk_i => clk_tb, ce_i => '1', sel_add_i => '1',
             din1_i => s_a_disj_above_s_a, din2_i => s_a_disj_above_s_b, dout_o => s_a_disj_above_s_dout);

  inst_a_overlap1_u : entity lm_math_fi_lib.lm_math_fi_add_sub
    generic map(g_direction => C_LM_ADD,
                g_representation => C_LM_UNSIGNED,
                g_pipeline_input => 0, g_pipeline_output => 0,
                g_din1_w => 4, g_din1_binpnt => 4,
                g_din2_w => 4, g_din2_binpnt => 4,
                g_dout_w => 4, g_dout_binpnt => 1,
                g_round_mode => C_LM_ROUND_EVEN)
    port map(clk_i => clk_tb, ce_i => '1', sel_add_i => '1',
             din1_i => s_a_overlap1_u_a, din2_i => s_a_overlap1_u_b, dout_o => s_a_overlap1_u_dout);

  inst_a_w1_u : entity lm_math_fi_lib.lm_math_fi_add_sub
    generic map(g_direction => C_LM_ADD,
                g_representation => C_LM_UNSIGNED,
                g_pipeline_input => 0, g_pipeline_output => 0,
                g_din1_w => 1, g_din1_binpnt => 1,
                g_din2_w => 1, g_din2_binpnt => 1,
                g_dout_w => 1, g_dout_binpnt => 1,
                g_round_mode => C_LM_ROUND_EVEN)
    port map(clk_i => clk_tb, ce_i => '1', sel_add_i => '1',
             din1_i => s_a_w1_u_a, din2_i => s_a_w1_u_b, dout_o => s_a_w1_u_dout);

  inst_a_w1_s : entity lm_math_fi_lib.lm_math_fi_add_sub
    generic map(g_direction => C_LM_ADD,
                g_representation => C_LM_SIGNED,
                g_pipeline_input => 0, g_pipeline_output => 0,
                g_din1_w => 1, g_din1_binpnt => 1,
                g_din2_w => 1, g_din2_binpnt => 1,
                g_dout_w => 1, g_dout_binpnt => 1,
                g_round_mode => C_LM_ROUND_EVEN)
    port map(clk_i => clk_tb, ce_i => '1', sel_add_i => '1',
             din1_i => s_a_w1_s_a, din2_i => s_a_w1_s_b, dout_o => s_a_w1_s_dout);

  inst_ma_bpeq_u : entity lm_math_fi_lib.lm_math_fi_mult_add
    generic map(g_din_a_w => 4, g_din_a_binpnt => 4,
                g_din_b_w => 4, g_din_b_binpnt => 4,
                g_din_c_w => 8, g_din_c_binpnt => 8,
                g_dout_w => 8, g_dout_binpnt => 8,
                g_add_sub => C_LM_ADD,
                g_round_mode => C_LM_ROUND_EVEN,
                g_representation => C_LM_UNSIGNED,
                g_overflow => C_LM_SATURATE, g_pipe_stages => 0)
    port map(clk_i => clk_tb, ce_i => '1', din1_i => s_ma_bpeq_u_a, din2_i => s_ma_bpeq_u_b,
             din3_i => s_ma_bpeq_u_c, dout_o => s_ma_bpeq_u_dout);

  inst_ma_bpeq_s : entity lm_math_fi_lib.lm_math_fi_mult_add
    generic map(g_din_a_w => 4, g_din_a_binpnt => 4,
                g_din_b_w => 4, g_din_b_binpnt => 4,
                g_din_c_w => 8, g_din_c_binpnt => 8,
                g_dout_w => 8, g_dout_binpnt => 8,
                g_add_sub => C_LM_ADD,
                g_round_mode => C_LM_ROUND_EVEN,
                g_representation => C_LM_SIGNED,
                g_overflow => C_LM_SATURATE, g_pipe_stages => 0)
    port map(clk_i => clk_tb, ce_i => '1', din1_i => s_ma_bpeq_s_a, din2_i => s_ma_bpeq_s_b,
             din3_i => s_ma_bpeq_s_c, dout_o => s_ma_bpeq_s_dout);

  inst_ma_bpgt_ops_s : entity lm_math_fi_lib.lm_math_fi_mult_add
    generic map(g_din_a_w => 4, g_din_a_binpnt => 6,
                g_din_b_w => 4, g_din_b_binpnt => 6,
                g_din_c_w => 8, g_din_c_binpnt => 2,
                g_dout_w => 8, g_dout_binpnt => 4,
                g_add_sub => C_LM_ADD,
                g_round_mode => C_LM_ROUND_EVEN,
                g_representation => C_LM_SIGNED,
                g_overflow => C_LM_SATURATE, g_pipe_stages => 0)
    port map(clk_i => clk_tb, ce_i => '1', din1_i => s_ma_bpgt_ops_s_a, din2_i => s_ma_bpgt_ops_s_b,
             din3_i => s_ma_bpgt_ops_s_c, dout_o => s_ma_bpgt_ops_s_dout);

  inst_ma_bpgt_addend_s : entity lm_math_fi_lib.lm_math_fi_mult_add
    generic map(g_din_a_w => 4, g_din_a_binpnt => 1,
                g_din_b_w => 4, g_din_b_binpnt => 1,
                g_din_c_w => 8, g_din_c_binpnt => 12,
                g_dout_w => 8, g_dout_binpnt => 4,
                g_add_sub => C_LM_SUB,
                g_round_mode => C_LM_ROUND_EVEN,
                g_representation => C_LM_SIGNED,
                g_overflow => C_LM_SATURATE, g_pipe_stages => 0)
    port map(clk_i => clk_tb, ce_i => '1', din1_i => s_ma_bpgt_addend_s_a, din2_i => s_ma_bpgt_addend_s_b,
             din3_i => s_ma_bpgt_addend_s_c, dout_o => s_ma_bpgt_addend_s_dout);

  inst_ma_bpgt_all_u : entity lm_math_fi_lib.lm_math_fi_mult_add
    generic map(g_din_a_w => 4, g_din_a_binpnt => 6,
                g_din_b_w => 4, g_din_b_binpnt => 6,
                g_din_c_w => 8, g_din_c_binpnt => 12,
                g_dout_w => 8, g_dout_binpnt => 14,
                g_add_sub => C_LM_ADD,
                g_round_mode => C_LM_ROUND_AWAY,
                g_representation => C_LM_UNSIGNED,
                g_overflow => C_LM_WRAP, g_pipe_stages => 0)
    port map(clk_i => clk_tb, ce_i => '1', din1_i => s_ma_bpgt_all_u_a, din2_i => s_ma_bpgt_all_u_b,
             din3_i => s_ma_bpgt_all_u_c, dout_o => s_ma_bpgt_all_u_dout);

  inst_ma_bpgt_out_s : entity lm_math_fi_lib.lm_math_fi_mult_add
    generic map(g_din_a_w => 4, g_din_a_binpnt => 1,
                g_din_b_w => 4, g_din_b_binpnt => 1,
                g_din_c_w => 8, g_din_c_binpnt => 1,
                g_dout_w => 4, g_dout_binpnt => 9,
                g_add_sub => C_LM_ADD,
                g_round_mode => C_LM_ROUND_EVEN,
                g_representation => C_LM_SIGNED,
                g_overflow => C_LM_SATURATE, g_pipe_stages => 0)
    port map(clk_i => clk_tb, ce_i => '1', din1_i => s_ma_bpgt_out_s_a, din2_i => s_ma_bpgt_out_s_b,
             din3_i => s_ma_bpgt_out_s_c, dout_o => s_ma_bpgt_out_s_dout);

  inst_ma_disj_below_u : entity lm_math_fi_lib.lm_math_fi_mult_add
    generic map(g_din_a_w => 4, g_din_a_binpnt => 0,
                g_din_b_w => 4, g_din_b_binpnt => 0,
                g_din_c_w => 8, g_din_c_binpnt => 0,
                g_dout_w => 4, g_dout_binpnt => 14,
                g_add_sub => C_LM_ADD,
                g_round_mode => C_LM_TRUNC_BITS,
                g_representation => C_LM_UNSIGNED,
                g_overflow => C_LM_SATURATE, g_pipe_stages => 0)
    port map(clk_i => clk_tb, ce_i => '1', din1_i => s_ma_disj_below_u_a, din2_i => s_ma_disj_below_u_b,
             din3_i => s_ma_disj_below_u_c, dout_o => s_ma_disj_below_u_dout);

  inst_ma_disj_above_s : entity lm_math_fi_lib.lm_math_fi_mult_add
    generic map(g_din_a_w => 4, g_din_a_binpnt => 8,
                g_din_b_w => 4, g_din_b_binpnt => 8,
                g_din_c_w => 8, g_din_c_binpnt => 10,
                g_dout_w => 4, g_dout_binpnt => 0,
                g_add_sub => C_LM_ADD,
                g_round_mode => C_LM_ROUND_AWAY,
                g_representation => C_LM_SIGNED,
                g_overflow => C_LM_SATURATE, g_pipe_stages => 0)
    port map(clk_i => clk_tb, ce_i => '1', din1_i => s_ma_disj_above_s_a, din2_i => s_ma_disj_above_s_b,
             din3_i => s_ma_disj_above_s_c, dout_o => s_ma_disj_above_s_dout);

  inst_ma_overlap1_u : entity lm_math_fi_lib.lm_math_fi_mult_add
    generic map(g_din_a_w => 4, g_din_a_binpnt => 4,
                g_din_b_w => 4, g_din_b_binpnt => 4,
                g_din_c_w => 8, g_din_c_binpnt => 8,
                g_dout_w => 4, g_dout_binpnt => 5,
                g_add_sub => C_LM_ADD,
                g_round_mode => C_LM_ROUND_EVEN,
                g_representation => C_LM_UNSIGNED,
                g_overflow => C_LM_WRAP, g_pipe_stages => 0)
    port map(clk_i => clk_tb, ce_i => '1', din1_i => s_ma_overlap1_u_a, din2_i => s_ma_overlap1_u_b,
             din3_i => s_ma_overlap1_u_c, dout_o => s_ma_overlap1_u_dout);

  inst_ma_w1_u : entity lm_math_fi_lib.lm_math_fi_mult_add
    generic map(g_din_a_w => 1, g_din_a_binpnt => 1,
                g_din_b_w => 1, g_din_b_binpnt => 1,
                g_din_c_w => 1, g_din_c_binpnt => 1,
                g_dout_w => 1, g_dout_binpnt => 1,
                g_add_sub => C_LM_ADD,
                g_round_mode => C_LM_ROUND_EVEN,
                g_representation => C_LM_UNSIGNED,
                g_overflow => C_LM_SATURATE, g_pipe_stages => 0)
    port map(clk_i => clk_tb, ce_i => '1', din1_i => s_ma_w1_u_a, din2_i => s_ma_w1_u_b,
             din3_i => s_ma_w1_u_c, dout_o => s_ma_w1_u_dout);

  inst_ma_w1_s : entity lm_math_fi_lib.lm_math_fi_mult_add
    generic map(g_din_a_w => 1, g_din_a_binpnt => 1,
                g_din_b_w => 1, g_din_b_binpnt => 1,
                g_din_c_w => 1, g_din_c_binpnt => 1,
                g_dout_w => 1, g_dout_binpnt => 1,
                g_add_sub => C_LM_ADD,
                g_round_mode => C_LM_ROUND_EVEN,
                g_representation => C_LM_SIGNED,
                g_overflow => C_LM_SATURATE, g_pipe_stages => 0)
    port map(clk_i => clk_tb, ce_i => '1', din1_i => s_ma_w1_s_a, din2_i => s_ma_w1_s_b,
             din3_i => s_ma_w1_s_c, dout_o => s_ma_w1_s_dout);

  proc_main : process
  begin
    -- ordinary narrowing: U(6,2) -> (4,1)
    s_f_ordinary_u_din <= "000000";
    p_settle(clk_tb);
    p_check_slv(s_f_ordinary_u_dout, "0000", "ordinary narrowing U(6,2) -> (4,1) in=0");
    s_f_ordinary_u_din <= "000001";
    p_settle(clk_tb);
    p_check_slv(s_f_ordinary_u_dout, "0000", "ordinary narrowing U(6,2) -> (4,1) in=1");
    s_f_ordinary_u_din <= "010110";
    p_settle(clk_tb);
    p_check_slv(s_f_ordinary_u_dout, "1011", "ordinary narrowing U(6,2) -> (4,1) in=22");
    s_f_ordinary_u_din <= "100101";
    p_settle(clk_tb);
    p_check_slv(s_f_ordinary_u_dout, "1111", "ordinary narrowing U(6,2) -> (4,1) in=37");
    s_f_ordinary_u_din <= "111111";
    p_settle(clk_tb);
    p_check_slv(s_f_ordinary_u_dout, "1111", "ordinary narrowing U(6,2) -> (4,1) in=63");

    -- ordinary narrowing: S(6,2) -> (4,1)
    s_f_ordinary_s_din <= "000000";
    p_settle(clk_tb);
    p_check_slv(s_f_ordinary_s_dout, "0000", "ordinary narrowing S(6,2) -> (4,1) in=0");
    s_f_ordinary_s_din <= "000001";
    p_settle(clk_tb);
    p_check_slv(s_f_ordinary_s_dout, "0000", "ordinary narrowing S(6,2) -> (4,1) in=1");
    s_f_ordinary_s_din <= "010110";
    p_settle(clk_tb);
    p_check_slv(s_f_ordinary_s_dout, "0111", "ordinary narrowing S(6,2) -> (4,1) in=22");
    s_f_ordinary_s_din <= "100101";
    p_settle(clk_tb);
    p_check_slv(s_f_ordinary_s_dout, "1000", "ordinary narrowing S(6,2) -> (4,1) in=37");
    s_f_ordinary_s_din <= "111111";
    p_settle(clk_tb);
    p_check_slv(s_f_ordinary_s_dout, "0000", "ordinary narrowing S(6,2) -> (4,1) in=63");

    -- binary point equal to the width: U(4,4) -> (4,4)
    s_f_bpeq_u_din <= "0000";
    p_settle(clk_tb);
    p_check_slv(s_f_bpeq_u_dout, "0000", "binary point equal to the width U(4,4) -> (4,4) in=0");
    s_f_bpeq_u_din <= "0001";
    p_settle(clk_tb);
    p_check_slv(s_f_bpeq_u_dout, "0001", "binary point equal to the width U(4,4) -> (4,4) in=1");
    s_f_bpeq_u_din <= "0101";
    p_settle(clk_tb);
    p_check_slv(s_f_bpeq_u_dout, "0101", "binary point equal to the width U(4,4) -> (4,4) in=5");
    s_f_bpeq_u_din <= "0111";
    p_settle(clk_tb);
    p_check_slv(s_f_bpeq_u_dout, "0111", "binary point equal to the width U(4,4) -> (4,4) in=7");
    s_f_bpeq_u_din <= "1000";
    p_settle(clk_tb);
    p_check_slv(s_f_bpeq_u_dout, "1000", "binary point equal to the width U(4,4) -> (4,4) in=8");
    s_f_bpeq_u_din <= "1111";
    p_settle(clk_tb);
    p_check_slv(s_f_bpeq_u_dout, "1111", "binary point equal to the width U(4,4) -> (4,4) in=15");

    -- binary point equal to the width: S(4,4) -> (4,4)
    s_f_bpeq_s_din <= "0000";
    p_settle(clk_tb);
    p_check_slv(s_f_bpeq_s_dout, "0000", "binary point equal to the width S(4,4) -> (4,4) in=0");
    s_f_bpeq_s_din <= "0001";
    p_settle(clk_tb);
    p_check_slv(s_f_bpeq_s_dout, "0001", "binary point equal to the width S(4,4) -> (4,4) in=1");
    s_f_bpeq_s_din <= "0101";
    p_settle(clk_tb);
    p_check_slv(s_f_bpeq_s_dout, "0101", "binary point equal to the width S(4,4) -> (4,4) in=5");
    s_f_bpeq_s_din <= "0111";
    p_settle(clk_tb);
    p_check_slv(s_f_bpeq_s_dout, "0111", "binary point equal to the width S(4,4) -> (4,4) in=7");
    s_f_bpeq_s_din <= "1000";
    p_settle(clk_tb);
    p_check_slv(s_f_bpeq_s_dout, "1000", "binary point equal to the width S(4,4) -> (4,4) in=8");
    s_f_bpeq_s_din <= "1111";
    p_settle(clk_tb);
    p_check_slv(s_f_bpeq_s_dout, "1111", "binary point equal to the width S(4,4) -> (4,4) in=15");

    -- binary point above the width, source: U(4,8) -> (4,2)
    s_f_bpgt_src_u_din <= "0000";
    p_settle(clk_tb);
    p_check_slv(s_f_bpgt_src_u_dout, "0000", "binary point above the width, source U(4,8) -> (4,2) in=0");
    s_f_bpgt_src_u_din <= "0001";
    p_settle(clk_tb);
    p_check_slv(s_f_bpgt_src_u_dout, "0000", "binary point above the width, source U(4,8) -> (4,2) in=1");
    s_f_bpgt_src_u_din <= "0101";
    p_settle(clk_tb);
    p_check_slv(s_f_bpgt_src_u_dout, "0000", "binary point above the width, source U(4,8) -> (4,2) in=5");
    s_f_bpgt_src_u_din <= "0111";
    p_settle(clk_tb);
    p_check_slv(s_f_bpgt_src_u_dout, "0000", "binary point above the width, source U(4,8) -> (4,2) in=7");
    s_f_bpgt_src_u_din <= "1000";
    p_settle(clk_tb);
    p_check_slv(s_f_bpgt_src_u_dout, "0000", "binary point above the width, source U(4,8) -> (4,2) in=8");
    s_f_bpgt_src_u_din <= "1111";
    p_settle(clk_tb);
    p_check_slv(s_f_bpgt_src_u_dout, "0000", "binary point above the width, source U(4,8) -> (4,2) in=15");

    -- binary point above the width, source: S(4,8) -> (4,2)
    s_f_bpgt_src_s_din <= "0000";
    p_settle(clk_tb);
    p_check_slv(s_f_bpgt_src_s_dout, "0000", "binary point above the width, source S(4,8) -> (4,2) in=0");
    s_f_bpgt_src_s_din <= "0001";
    p_settle(clk_tb);
    p_check_slv(s_f_bpgt_src_s_dout, "0000", "binary point above the width, source S(4,8) -> (4,2) in=1");
    s_f_bpgt_src_s_din <= "0101";
    p_settle(clk_tb);
    p_check_slv(s_f_bpgt_src_s_dout, "0000", "binary point above the width, source S(4,8) -> (4,2) in=5");
    s_f_bpgt_src_s_din <= "0111";
    p_settle(clk_tb);
    p_check_slv(s_f_bpgt_src_s_dout, "0000", "binary point above the width, source S(4,8) -> (4,2) in=7");
    s_f_bpgt_src_s_din <= "1000";
    p_settle(clk_tb);
    p_check_slv(s_f_bpgt_src_s_dout, "1111", "binary point above the width, source S(4,8) -> (4,2) in=8");
    s_f_bpgt_src_s_din <= "1111";
    p_settle(clk_tb);
    p_check_slv(s_f_bpgt_src_s_dout, "1111", "binary point above the width, source S(4,8) -> (4,2) in=15");

    -- binary point above the width, destination: U(4,2) -> (4,8)
    s_f_bpgt_dst_u_din <= "0000";
    p_settle(clk_tb);
    p_check_slv(s_f_bpgt_dst_u_dout, "0000", "binary point above the width, destination U(4,2) -> (4,8) in=0");
    s_f_bpgt_dst_u_din <= "0001";
    p_settle(clk_tb);
    p_check_slv(s_f_bpgt_dst_u_dout, "1111", "binary point above the width, destination U(4,2) -> (4,8) in=1");
    s_f_bpgt_dst_u_din <= "0101";
    p_settle(clk_tb);
    p_check_slv(s_f_bpgt_dst_u_dout, "1111", "binary point above the width, destination U(4,2) -> (4,8) in=5");
    s_f_bpgt_dst_u_din <= "0111";
    p_settle(clk_tb);
    p_check_slv(s_f_bpgt_dst_u_dout, "1111", "binary point above the width, destination U(4,2) -> (4,8) in=7");
    s_f_bpgt_dst_u_din <= "1000";
    p_settle(clk_tb);
    p_check_slv(s_f_bpgt_dst_u_dout, "1111", "binary point above the width, destination U(4,2) -> (4,8) in=8");
    s_f_bpgt_dst_u_din <= "1111";
    p_settle(clk_tb);
    p_check_slv(s_f_bpgt_dst_u_dout, "1111", "binary point above the width, destination U(4,2) -> (4,8) in=15");

    -- binary point above the width, destination: S(4,2) -> (4,8)
    s_f_bpgt_dst_s_din <= "0000";
    p_settle(clk_tb);
    p_check_slv(s_f_bpgt_dst_s_dout, "0000", "binary point above the width, destination S(4,2) -> (4,8) in=0");
    s_f_bpgt_dst_s_din <= "0001";
    p_settle(clk_tb);
    p_check_slv(s_f_bpgt_dst_s_dout, "0111", "binary point above the width, destination S(4,2) -> (4,8) in=1");
    s_f_bpgt_dst_s_din <= "0101";
    p_settle(clk_tb);
    p_check_slv(s_f_bpgt_dst_s_dout, "0111", "binary point above the width, destination S(4,2) -> (4,8) in=5");
    s_f_bpgt_dst_s_din <= "0111";
    p_settle(clk_tb);
    p_check_slv(s_f_bpgt_dst_s_dout, "0111", "binary point above the width, destination S(4,2) -> (4,8) in=7");
    s_f_bpgt_dst_s_din <= "1000";
    p_settle(clk_tb);
    p_check_slv(s_f_bpgt_dst_s_dout, "1000", "binary point above the width, destination S(4,2) -> (4,8) in=8");
    s_f_bpgt_dst_s_din <= "1111";
    p_settle(clk_tb);
    p_check_slv(s_f_bpgt_dst_s_dout, "1000", "binary point above the width, destination S(4,2) -> (4,8) in=15");

    -- binary point above the width, both sides: S(4,8) -> (4,6)
    s_f_bpgt_both_s_din <= "0000";
    p_settle(clk_tb);
    p_check_slv(s_f_bpgt_both_s_dout, "0000", "binary point above the width, both sides S(4,8) -> (4,6) in=0");
    s_f_bpgt_both_s_din <= "0001";
    p_settle(clk_tb);
    p_check_slv(s_f_bpgt_both_s_dout, "0000", "binary point above the width, both sides S(4,8) -> (4,6) in=1");
    s_f_bpgt_both_s_din <= "0101";
    p_settle(clk_tb);
    p_check_slv(s_f_bpgt_both_s_dout, "0001", "binary point above the width, both sides S(4,8) -> (4,6) in=5");
    s_f_bpgt_both_s_din <= "0111";
    p_settle(clk_tb);
    p_check_slv(s_f_bpgt_both_s_dout, "0010", "binary point above the width, both sides S(4,8) -> (4,6) in=7");
    s_f_bpgt_both_s_din <= "1000";
    p_settle(clk_tb);
    p_check_slv(s_f_bpgt_both_s_dout, "1110", "binary point above the width, both sides S(4,8) -> (4,6) in=8");
    s_f_bpgt_both_s_din <= "1111";
    p_settle(clk_tb);
    p_check_slv(s_f_bpgt_both_s_dout, "0000", "binary point above the width, both sides S(4,8) -> (4,6) in=15");

    -- disjoint weights, destination above source: S(4,8) -> (4,0)
    s_f_disj_above_s_din <= "0000";
    p_settle(clk_tb);
    p_check_slv(s_f_disj_above_s_dout, "0000", "disjoint weights, destination above source S(4,8) -> (4,0) in=0");
    s_f_disj_above_s_din <= "0001";
    p_settle(clk_tb);
    p_check_slv(s_f_disj_above_s_dout, "0000", "disjoint weights, destination above source S(4,8) -> (4,0) in=1");
    s_f_disj_above_s_din <= "0101";
    p_settle(clk_tb);
    p_check_slv(s_f_disj_above_s_dout, "0000", "disjoint weights, destination above source S(4,8) -> (4,0) in=5");
    s_f_disj_above_s_din <= "0111";
    p_settle(clk_tb);
    p_check_slv(s_f_disj_above_s_dout, "0000", "disjoint weights, destination above source S(4,8) -> (4,0) in=7");
    s_f_disj_above_s_din <= "1000";
    p_settle(clk_tb);
    p_check_slv(s_f_disj_above_s_dout, "0000", "disjoint weights, destination above source S(4,8) -> (4,0) in=8");
    s_f_disj_above_s_din <= "1111";
    p_settle(clk_tb);
    p_check_slv(s_f_disj_above_s_dout, "0000", "disjoint weights, destination above source S(4,8) -> (4,0) in=15");

    -- disjoint weights, destination below source: U(4,0) -> (4,8)
    s_f_disj_below_u_din <= "0000";
    p_settle(clk_tb);
    p_check_slv(s_f_disj_below_u_dout, "0000", "disjoint weights, destination below source U(4,0) -> (4,8) in=0");
    s_f_disj_below_u_din <= "0001";
    p_settle(clk_tb);
    p_check_slv(s_f_disj_below_u_dout, "1111", "disjoint weights, destination below source U(4,0) -> (4,8) in=1");
    s_f_disj_below_u_din <= "0101";
    p_settle(clk_tb);
    p_check_slv(s_f_disj_below_u_dout, "1111", "disjoint weights, destination below source U(4,0) -> (4,8) in=5");
    s_f_disj_below_u_din <= "0111";
    p_settle(clk_tb);
    p_check_slv(s_f_disj_below_u_dout, "1111", "disjoint weights, destination below source U(4,0) -> (4,8) in=7");
    s_f_disj_below_u_din <= "1000";
    p_settle(clk_tb);
    p_check_slv(s_f_disj_below_u_dout, "1111", "disjoint weights, destination below source U(4,0) -> (4,8) in=8");
    s_f_disj_below_u_din <= "1111";
    p_settle(clk_tb);
    p_check_slv(s_f_disj_below_u_dout, "1111", "disjoint weights, destination below source U(4,0) -> (4,8) in=15");

    -- exactly one bit of weight overlap: U(4,4) -> (4,1)
    s_f_overlap1_u_din <= "0000";
    p_settle(clk_tb);
    p_check_slv(s_f_overlap1_u_dout, "0000", "exactly one bit of weight overlap U(4,4) -> (4,1) in=0");
    s_f_overlap1_u_din <= "0001";
    p_settle(clk_tb);
    p_check_slv(s_f_overlap1_u_dout, "0000", "exactly one bit of weight overlap U(4,4) -> (4,1) in=1");
    s_f_overlap1_u_din <= "0101";
    p_settle(clk_tb);
    p_check_slv(s_f_overlap1_u_dout, "0001", "exactly one bit of weight overlap U(4,4) -> (4,1) in=5");
    s_f_overlap1_u_din <= "0111";
    p_settle(clk_tb);
    p_check_slv(s_f_overlap1_u_dout, "0001", "exactly one bit of weight overlap U(4,4) -> (4,1) in=7");
    s_f_overlap1_u_din <= "1000";
    p_settle(clk_tb);
    p_check_slv(s_f_overlap1_u_dout, "0001", "exactly one bit of weight overlap U(4,4) -> (4,1) in=8");
    s_f_overlap1_u_din <= "1111";
    p_settle(clk_tb);
    p_check_slv(s_f_overlap1_u_dout, "0010", "exactly one bit of weight overlap U(4,4) -> (4,1) in=15");

    -- width 1 unsigned, binary point equal to the width: U(1,1) -> (1,1)
    s_f_w1_u_din <= "0";
    p_settle(clk_tb);
    p_check_slv(s_f_w1_u_dout, "0", "width 1 unsigned, binary point equal to the width U(1,1) -> (1,1) in=0");
    s_f_w1_u_din <= "1";
    p_settle(clk_tb);
    p_check_slv(s_f_w1_u_dout, "1", "width 1 unsigned, binary point equal to the width U(1,1) -> (1,1) in=1");

    -- width 1 signed, binary point equal to the width: S(1,1) -> (1,1)
    s_f_w1_s_din <= "0";
    p_settle(clk_tb);
    p_check_slv(s_f_w1_s_dout, "0", "width 1 signed, binary point equal to the width S(1,1) -> (1,1) in=0");
    s_f_w1_s_din <= "1";
    p_settle(clk_tb);
    p_check_slv(s_f_w1_s_dout, "1", "width 1 signed, binary point equal to the width S(1,1) -> (1,1) in=1");

    -- width 1 signed destination from a wider source: S(4,3) -> (1,1)
    s_f_w1_from_wide_s_din <= "0000";
    p_settle(clk_tb);
    p_check_slv(s_f_w1_from_wide_s_dout, "0", "width 1 signed destination from a wider source S(4,3) -> (1,1) in=0");
    s_f_w1_from_wide_s_din <= "0001";
    p_settle(clk_tb);
    p_check_slv(s_f_w1_from_wide_s_dout, "0", "width 1 signed destination from a wider source S(4,3) -> (1,1) in=1");
    s_f_w1_from_wide_s_din <= "0101";
    p_settle(clk_tb);
    p_check_slv(s_f_w1_from_wide_s_dout, "0", "width 1 signed destination from a wider source S(4,3) -> (1,1) in=5");
    s_f_w1_from_wide_s_din <= "0111";
    p_settle(clk_tb);
    p_check_slv(s_f_w1_from_wide_s_dout, "0", "width 1 signed destination from a wider source S(4,3) -> (1,1) in=7");
    s_f_w1_from_wide_s_din <= "1000";
    p_settle(clk_tb);
    p_check_slv(s_f_w1_from_wide_s_dout, "1", "width 1 signed destination from a wider source S(4,3) -> (1,1) in=8");
    s_f_w1_from_wide_s_din <= "1111";
    p_settle(clk_tb);
    p_check_slv(s_f_w1_from_wide_s_dout, "0", "width 1 signed destination from a wider source S(4,3) -> (1,1) in=15");

    -- width 1 signed source into a wider destination: S(1,3) -> (4,1)
    s_f_w1_to_wide_s_din <= "0";
    p_settle(clk_tb);
    p_check_slv(s_f_w1_to_wide_s_dout, "0000", "width 1 signed source into a wider destination S(1,3) -> (4,1) in=0");
    s_f_w1_to_wide_s_din <= "1";
    p_settle(clk_tb);
    p_check_slv(s_f_w1_to_wide_s_dout, "0000", "width 1 signed source into a wider destination S(1,3) -> (4,1) in=1");

    -- ordinary narrowing: S(4,1)x(4,1) -> (6,2)
    s_m_ordinary_s_a <= "0000"; s_m_ordinary_s_b <= "0001";
    p_settle(clk_tb);
    p_check_slv(s_m_ordinary_s_dout, "000000", "ordinary narrowing S(4,1)x(4,1) -> (6,2) in=0/1");
    s_m_ordinary_s_a <= "0000"; s_m_ordinary_s_b <= "1111";
    p_settle(clk_tb);
    p_check_slv(s_m_ordinary_s_dout, "000000", "ordinary narrowing S(4,1)x(4,1) -> (6,2) in=0/15");
    s_m_ordinary_s_a <= "0001"; s_m_ordinary_s_b <= "0001";
    p_settle(clk_tb);
    p_check_slv(s_m_ordinary_s_dout, "000001", "ordinary narrowing S(4,1)x(4,1) -> (6,2) in=1/1");
    s_m_ordinary_s_a <= "0001"; s_m_ordinary_s_b <= "1111";
    p_settle(clk_tb);
    p_check_slv(s_m_ordinary_s_dout, "111111", "ordinary narrowing S(4,1)x(4,1) -> (6,2) in=1/15");
    s_m_ordinary_s_a <= "0111"; s_m_ordinary_s_b <= "0001";
    p_settle(clk_tb);
    p_check_slv(s_m_ordinary_s_dout, "000111", "ordinary narrowing S(4,1)x(4,1) -> (6,2) in=7/1");
    s_m_ordinary_s_a <= "0111"; s_m_ordinary_s_b <= "1111";
    p_settle(clk_tb);
    p_check_slv(s_m_ordinary_s_dout, "111001", "ordinary narrowing S(4,1)x(4,1) -> (6,2) in=7/15");
    s_m_ordinary_s_a <= "1000"; s_m_ordinary_s_b <= "0001";
    p_settle(clk_tb);
    p_check_slv(s_m_ordinary_s_dout, "111000", "ordinary narrowing S(4,1)x(4,1) -> (6,2) in=8/1");
    s_m_ordinary_s_a <= "1000"; s_m_ordinary_s_b <= "1111";
    p_settle(clk_tb);
    p_check_slv(s_m_ordinary_s_dout, "001000", "ordinary narrowing S(4,1)x(4,1) -> (6,2) in=8/15");
    s_m_ordinary_s_a <= "1111"; s_m_ordinary_s_b <= "0001";
    p_settle(clk_tb);
    p_check_slv(s_m_ordinary_s_dout, "111111", "ordinary narrowing S(4,1)x(4,1) -> (6,2) in=15/1");
    s_m_ordinary_s_a <= "1111"; s_m_ordinary_s_b <= "1111";
    p_settle(clk_tb);
    p_check_slv(s_m_ordinary_s_dout, "000001", "ordinary narrowing S(4,1)x(4,1) -> (6,2) in=15/15");

    -- binary point equal to the width: U(4,4)x(4,4) -> (4,4)
    s_m_bpeq_u_a <= "0000"; s_m_bpeq_u_b <= "0000";
    p_settle(clk_tb);
    p_check_slv(s_m_bpeq_u_dout, "0000", "binary point equal to the width U(4,4)x(4,4) -> (4,4) in=0/0");
    s_m_bpeq_u_a <= "0000"; s_m_bpeq_u_b <= "0101";
    p_settle(clk_tb);
    p_check_slv(s_m_bpeq_u_dout, "0000", "binary point equal to the width U(4,4)x(4,4) -> (4,4) in=0/5");
    s_m_bpeq_u_a <= "0000"; s_m_bpeq_u_b <= "1111";
    p_settle(clk_tb);
    p_check_slv(s_m_bpeq_u_dout, "0000", "binary point equal to the width U(4,4)x(4,4) -> (4,4) in=0/15");
    s_m_bpeq_u_a <= "0011"; s_m_bpeq_u_b <= "0000";
    p_settle(clk_tb);
    p_check_slv(s_m_bpeq_u_dout, "0000", "binary point equal to the width U(4,4)x(4,4) -> (4,4) in=3/0");
    s_m_bpeq_u_a <= "0011"; s_m_bpeq_u_b <= "0101";
    p_settle(clk_tb);
    p_check_slv(s_m_bpeq_u_dout, "0001", "binary point equal to the width U(4,4)x(4,4) -> (4,4) in=3/5");
    s_m_bpeq_u_a <= "0011"; s_m_bpeq_u_b <= "1111";
    p_settle(clk_tb);
    p_check_slv(s_m_bpeq_u_dout, "0011", "binary point equal to the width U(4,4)x(4,4) -> (4,4) in=3/15");
    s_m_bpeq_u_a <= "1111"; s_m_bpeq_u_b <= "0000";
    p_settle(clk_tb);
    p_check_slv(s_m_bpeq_u_dout, "0000", "binary point equal to the width U(4,4)x(4,4) -> (4,4) in=15/0");
    s_m_bpeq_u_a <= "1111"; s_m_bpeq_u_b <= "0101";
    p_settle(clk_tb);
    p_check_slv(s_m_bpeq_u_dout, "0101", "binary point equal to the width U(4,4)x(4,4) -> (4,4) in=15/5");
    s_m_bpeq_u_a <= "1111"; s_m_bpeq_u_b <= "1111";
    p_settle(clk_tb);
    p_check_slv(s_m_bpeq_u_dout, "1110", "binary point equal to the width U(4,4)x(4,4) -> (4,4) in=15/15");

    -- binary point equal to the width: S(4,4)x(4,4) -> (4,4)
    s_m_bpeq_s_a <= "0000"; s_m_bpeq_s_b <= "0000";
    p_settle(clk_tb);
    p_check_slv(s_m_bpeq_s_dout, "0000", "binary point equal to the width S(4,4)x(4,4) -> (4,4) in=0/0");
    s_m_bpeq_s_a <= "0000"; s_m_bpeq_s_b <= "0101";
    p_settle(clk_tb);
    p_check_slv(s_m_bpeq_s_dout, "0000", "binary point equal to the width S(4,4)x(4,4) -> (4,4) in=0/5");
    s_m_bpeq_s_a <= "0000"; s_m_bpeq_s_b <= "1111";
    p_settle(clk_tb);
    p_check_slv(s_m_bpeq_s_dout, "0000", "binary point equal to the width S(4,4)x(4,4) -> (4,4) in=0/15");
    s_m_bpeq_s_a <= "0011"; s_m_bpeq_s_b <= "0000";
    p_settle(clk_tb);
    p_check_slv(s_m_bpeq_s_dout, "0000", "binary point equal to the width S(4,4)x(4,4) -> (4,4) in=3/0");
    s_m_bpeq_s_a <= "0011"; s_m_bpeq_s_b <= "0101";
    p_settle(clk_tb);
    p_check_slv(s_m_bpeq_s_dout, "0001", "binary point equal to the width S(4,4)x(4,4) -> (4,4) in=3/5");
    s_m_bpeq_s_a <= "0011"; s_m_bpeq_s_b <= "1111";
    p_settle(clk_tb);
    p_check_slv(s_m_bpeq_s_dout, "0000", "binary point equal to the width S(4,4)x(4,4) -> (4,4) in=3/15");
    s_m_bpeq_s_a <= "1111"; s_m_bpeq_s_b <= "0000";
    p_settle(clk_tb);
    p_check_slv(s_m_bpeq_s_dout, "0000", "binary point equal to the width S(4,4)x(4,4) -> (4,4) in=15/0");
    s_m_bpeq_s_a <= "1111"; s_m_bpeq_s_b <= "0101";
    p_settle(clk_tb);
    p_check_slv(s_m_bpeq_s_dout, "0000", "binary point equal to the width S(4,4)x(4,4) -> (4,4) in=15/5");
    s_m_bpeq_s_a <= "1111"; s_m_bpeq_s_b <= "1111";
    p_settle(clk_tb);
    p_check_slv(s_m_bpeq_s_dout, "0000", "binary point equal to the width S(4,4)x(4,4) -> (4,4) in=15/15");

    -- binary point above the width: S(4,6)x(4,6) -> (4,8)
    s_m_bpgt_s_a <= "0000"; s_m_bpgt_s_b <= "0001";
    p_settle(clk_tb);
    p_check_slv(s_m_bpgt_s_dout, "0000", "binary point above the width S(4,6)x(4,6) -> (4,8) in=0/1");
    s_m_bpgt_s_a <= "0000"; s_m_bpgt_s_b <= "1111";
    p_settle(clk_tb);
    p_check_slv(s_m_bpgt_s_dout, "0000", "binary point above the width S(4,6)x(4,6) -> (4,8) in=0/15");
    s_m_bpgt_s_a <= "0001"; s_m_bpgt_s_b <= "0001";
    p_settle(clk_tb);
    p_check_slv(s_m_bpgt_s_dout, "0000", "binary point above the width S(4,6)x(4,6) -> (4,8) in=1/1");
    s_m_bpgt_s_a <= "0001"; s_m_bpgt_s_b <= "1111";
    p_settle(clk_tb);
    p_check_slv(s_m_bpgt_s_dout, "1111", "binary point above the width S(4,6)x(4,6) -> (4,8) in=1/15");
    s_m_bpgt_s_a <= "0111"; s_m_bpgt_s_b <= "0001";
    p_settle(clk_tb);
    p_check_slv(s_m_bpgt_s_dout, "0000", "binary point above the width S(4,6)x(4,6) -> (4,8) in=7/1");
    s_m_bpgt_s_a <= "0111"; s_m_bpgt_s_b <= "1111";
    p_settle(clk_tb);
    p_check_slv(s_m_bpgt_s_dout, "1111", "binary point above the width S(4,6)x(4,6) -> (4,8) in=7/15");
    s_m_bpgt_s_a <= "1000"; s_m_bpgt_s_b <= "0001";
    p_settle(clk_tb);
    p_check_slv(s_m_bpgt_s_dout, "1111", "binary point above the width S(4,6)x(4,6) -> (4,8) in=8/1");
    s_m_bpgt_s_a <= "1000"; s_m_bpgt_s_b <= "1111";
    p_settle(clk_tb);
    p_check_slv(s_m_bpgt_s_dout, "0000", "binary point above the width S(4,6)x(4,6) -> (4,8) in=8/15");

    -- binary point above the width, destination: U(4,1)x(4,1) -> (4,9)
    s_m_bpgt_dst_u_a <= "0000"; s_m_bpgt_dst_u_b <= "0001";
    p_settle(clk_tb);
    p_check_slv(s_m_bpgt_dst_u_dout, "0000", "binary point above the width, destination U(4,1)x(4,1) -> (4,9) in=0/1");
    s_m_bpgt_dst_u_a <= "0000"; s_m_bpgt_dst_u_b <= "1111";
    p_settle(clk_tb);
    p_check_slv(s_m_bpgt_dst_u_dout, "0000", "binary point above the width, destination U(4,1)x(4,1) -> (4,9) in=0/15");
    s_m_bpgt_dst_u_a <= "0001"; s_m_bpgt_dst_u_b <= "0001";
    p_settle(clk_tb);
    p_check_slv(s_m_bpgt_dst_u_dout, "1111", "binary point above the width, destination U(4,1)x(4,1) -> (4,9) in=1/1");
    s_m_bpgt_dst_u_a <= "0001"; s_m_bpgt_dst_u_b <= "1111";
    p_settle(clk_tb);
    p_check_slv(s_m_bpgt_dst_u_dout, "1111", "binary point above the width, destination U(4,1)x(4,1) -> (4,9) in=1/15");
    s_m_bpgt_dst_u_a <= "1111"; s_m_bpgt_dst_u_b <= "0001";
    p_settle(clk_tb);
    p_check_slv(s_m_bpgt_dst_u_dout, "1111", "binary point above the width, destination U(4,1)x(4,1) -> (4,9) in=15/1");
    s_m_bpgt_dst_u_a <= "1111"; s_m_bpgt_dst_u_b <= "1111";
    p_settle(clk_tb);
    p_check_slv(s_m_bpgt_dst_u_dout, "1111", "binary point above the width, destination U(4,1)x(4,1) -> (4,9) in=15/15");

    -- disjoint weights, destination below source: U(4,0)x(4,0) -> (4,12)
    s_m_disj_below_u_a <= "0000"; s_m_disj_below_u_b <= "0001";
    p_settle(clk_tb);
    p_check_slv(s_m_disj_below_u_dout, "0000", "disjoint weights, destination below source U(4,0)x(4,0) -> (4,12) in=0/1");
    s_m_disj_below_u_a <= "0000"; s_m_disj_below_u_b <= "1111";
    p_settle(clk_tb);
    p_check_slv(s_m_disj_below_u_dout, "0000", "disjoint weights, destination below source U(4,0)x(4,0) -> (4,12) in=0/15");
    s_m_disj_below_u_a <= "0001"; s_m_disj_below_u_b <= "0001";
    p_settle(clk_tb);
    p_check_slv(s_m_disj_below_u_dout, "1111", "disjoint weights, destination below source U(4,0)x(4,0) -> (4,12) in=1/1");
    s_m_disj_below_u_a <= "0001"; s_m_disj_below_u_b <= "1111";
    p_settle(clk_tb);
    p_check_slv(s_m_disj_below_u_dout, "1111", "disjoint weights, destination below source U(4,0)x(4,0) -> (4,12) in=1/15");
    s_m_disj_below_u_a <= "1111"; s_m_disj_below_u_b <= "0001";
    p_settle(clk_tb);
    p_check_slv(s_m_disj_below_u_dout, "1111", "disjoint weights, destination below source U(4,0)x(4,0) -> (4,12) in=15/1");
    s_m_disj_below_u_a <= "1111"; s_m_disj_below_u_b <= "1111";
    p_settle(clk_tb);
    p_check_slv(s_m_disj_below_u_dout, "1111", "disjoint weights, destination below source U(4,0)x(4,0) -> (4,12) in=15/15");

    -- disjoint weights, destination above source: S(4,8)x(4,8) -> (4,0)
    s_m_disj_above_s_a <= "0000"; s_m_disj_above_s_b <= "0001";
    p_settle(clk_tb);
    p_check_slv(s_m_disj_above_s_dout, "0000", "disjoint weights, destination above source S(4,8)x(4,8) -> (4,0) in=0/1");
    s_m_disj_above_s_a <= "0000"; s_m_disj_above_s_b <= "1111";
    p_settle(clk_tb);
    p_check_slv(s_m_disj_above_s_dout, "0000", "disjoint weights, destination above source S(4,8)x(4,8) -> (4,0) in=0/15");
    s_m_disj_above_s_a <= "0001"; s_m_disj_above_s_b <= "0001";
    p_settle(clk_tb);
    p_check_slv(s_m_disj_above_s_dout, "0000", "disjoint weights, destination above source S(4,8)x(4,8) -> (4,0) in=1/1");
    s_m_disj_above_s_a <= "0001"; s_m_disj_above_s_b <= "1111";
    p_settle(clk_tb);
    p_check_slv(s_m_disj_above_s_dout, "0000", "disjoint weights, destination above source S(4,8)x(4,8) -> (4,0) in=1/15");
    s_m_disj_above_s_a <= "1000"; s_m_disj_above_s_b <= "0001";
    p_settle(clk_tb);
    p_check_slv(s_m_disj_above_s_dout, "0000", "disjoint weights, destination above source S(4,8)x(4,8) -> (4,0) in=8/1");
    s_m_disj_above_s_a <= "1000"; s_m_disj_above_s_b <= "1111";
    p_settle(clk_tb);
    p_check_slv(s_m_disj_above_s_dout, "0000", "disjoint weights, destination above source S(4,8)x(4,8) -> (4,0) in=8/15");
    s_m_disj_above_s_a <= "1111"; s_m_disj_above_s_b <= "0001";
    p_settle(clk_tb);
    p_check_slv(s_m_disj_above_s_dout, "0000", "disjoint weights, destination above source S(4,8)x(4,8) -> (4,0) in=15/1");
    s_m_disj_above_s_a <= "1111"; s_m_disj_above_s_b <= "1111";
    p_settle(clk_tb);
    p_check_slv(s_m_disj_above_s_dout, "0000", "disjoint weights, destination above source S(4,8)x(4,8) -> (4,0) in=15/15");

    -- exactly one bit of weight overlap: U(4,4)x(4,4) -> (4,1)
    s_m_overlap1_u_a <= "0000"; s_m_overlap1_u_b <= "0101";
    p_settle(clk_tb);
    p_check_slv(s_m_overlap1_u_dout, "0000", "exactly one bit of weight overlap U(4,4)x(4,4) -> (4,1) in=0/5");
    s_m_overlap1_u_a <= "0000"; s_m_overlap1_u_b <= "1111";
    p_settle(clk_tb);
    p_check_slv(s_m_overlap1_u_dout, "0000", "exactly one bit of weight overlap U(4,4)x(4,4) -> (4,1) in=0/15");
    s_m_overlap1_u_a <= "0011"; s_m_overlap1_u_b <= "0101";
    p_settle(clk_tb);
    p_check_slv(s_m_overlap1_u_dout, "0000", "exactly one bit of weight overlap U(4,4)x(4,4) -> (4,1) in=3/5");
    s_m_overlap1_u_a <= "0011"; s_m_overlap1_u_b <= "1111";
    p_settle(clk_tb);
    p_check_slv(s_m_overlap1_u_dout, "0000", "exactly one bit of weight overlap U(4,4)x(4,4) -> (4,1) in=3/15");
    s_m_overlap1_u_a <= "1111"; s_m_overlap1_u_b <= "0101";
    p_settle(clk_tb);
    p_check_slv(s_m_overlap1_u_dout, "0001", "exactly one bit of weight overlap U(4,4)x(4,4) -> (4,1) in=15/5");
    s_m_overlap1_u_a <= "1111"; s_m_overlap1_u_b <= "1111";
    p_settle(clk_tb);
    p_check_slv(s_m_overlap1_u_dout, "0010", "exactly one bit of weight overlap U(4,4)x(4,4) -> (4,1) in=15/15");

    -- width 1 unsigned: U(1,1)x(1,1) -> (1,1)
    s_m_w1_u_a <= "0"; s_m_w1_u_b <= "0";
    p_settle(clk_tb);
    p_check_slv(s_m_w1_u_dout, "0", "width 1 unsigned U(1,1)x(1,1) -> (1,1) in=0/0");
    s_m_w1_u_a <= "0"; s_m_w1_u_b <= "1";
    p_settle(clk_tb);
    p_check_slv(s_m_w1_u_dout, "0", "width 1 unsigned U(1,1)x(1,1) -> (1,1) in=0/1");
    s_m_w1_u_a <= "1"; s_m_w1_u_b <= "0";
    p_settle(clk_tb);
    p_check_slv(s_m_w1_u_dout, "0", "width 1 unsigned U(1,1)x(1,1) -> (1,1) in=1/0");
    s_m_w1_u_a <= "1"; s_m_w1_u_b <= "1";
    p_settle(clk_tb);
    p_check_slv(s_m_w1_u_dout, "0", "width 1 unsigned U(1,1)x(1,1) -> (1,1) in=1/1");

    -- width 1 signed: S(1,1)x(1,1) -> (1,1)
    s_m_w1_s_a <= "0"; s_m_w1_s_b <= "0";
    p_settle(clk_tb);
    p_check_slv(s_m_w1_s_dout, "0", "width 1 signed S(1,1)x(1,1) -> (1,1) in=0/0");
    s_m_w1_s_a <= "0"; s_m_w1_s_b <= "1";
    p_settle(clk_tb);
    p_check_slv(s_m_w1_s_dout, "0", "width 1 signed S(1,1)x(1,1) -> (1,1) in=0/1");
    s_m_w1_s_a <= "1"; s_m_w1_s_b <= "0";
    p_settle(clk_tb);
    p_check_slv(s_m_w1_s_dout, "0", "width 1 signed S(1,1)x(1,1) -> (1,1) in=1/0");
    s_m_w1_s_a <= "1"; s_m_w1_s_b <= "1";
    p_settle(clk_tb);
    p_check_slv(s_m_w1_s_dout, "0", "width 1 signed S(1,1)x(1,1) -> (1,1) in=1/1");

    -- ordinary narrowing: S(4,1)+(4,1) -> (6,2)
    s_a_ordinary_s_a <= "0000"; s_a_ordinary_s_b <= "0001";
    p_settle(clk_tb);
    p_check_slv(s_a_ordinary_s_dout, "000010", "ordinary narrowing S(4,1)+(4,1) -> (6,2) in=0/1");
    s_a_ordinary_s_a <= "0000"; s_a_ordinary_s_b <= "0111";
    p_settle(clk_tb);
    p_check_slv(s_a_ordinary_s_dout, "001110", "ordinary narrowing S(4,1)+(4,1) -> (6,2) in=0/7");
    s_a_ordinary_s_a <= "0000"; s_a_ordinary_s_b <= "1111";
    p_settle(clk_tb);
    p_check_slv(s_a_ordinary_s_dout, "111110", "ordinary narrowing S(4,1)+(4,1) -> (6,2) in=0/15");
    s_a_ordinary_s_a <= "0001"; s_a_ordinary_s_b <= "0001";
    p_settle(clk_tb);
    p_check_slv(s_a_ordinary_s_dout, "000100", "ordinary narrowing S(4,1)+(4,1) -> (6,2) in=1/1");
    s_a_ordinary_s_a <= "0001"; s_a_ordinary_s_b <= "0111";
    p_settle(clk_tb);
    p_check_slv(s_a_ordinary_s_dout, "010000", "ordinary narrowing S(4,1)+(4,1) -> (6,2) in=1/7");
    s_a_ordinary_s_a <= "0001"; s_a_ordinary_s_b <= "1111";
    p_settle(clk_tb);
    p_check_slv(s_a_ordinary_s_dout, "000000", "ordinary narrowing S(4,1)+(4,1) -> (6,2) in=1/15");
    s_a_ordinary_s_a <= "1000"; s_a_ordinary_s_b <= "0001";
    p_settle(clk_tb);
    p_check_slv(s_a_ordinary_s_dout, "110010", "ordinary narrowing S(4,1)+(4,1) -> (6,2) in=8/1");
    s_a_ordinary_s_a <= "1000"; s_a_ordinary_s_b <= "0111";
    p_settle(clk_tb);
    p_check_slv(s_a_ordinary_s_dout, "111110", "ordinary narrowing S(4,1)+(4,1) -> (6,2) in=8/7");
    s_a_ordinary_s_a <= "1000"; s_a_ordinary_s_b <= "1111";
    p_settle(clk_tb);
    p_check_slv(s_a_ordinary_s_dout, "101110", "ordinary narrowing S(4,1)+(4,1) -> (6,2) in=8/15");
    s_a_ordinary_s_a <= "1111"; s_a_ordinary_s_b <= "0001";
    p_settle(clk_tb);
    p_check_slv(s_a_ordinary_s_dout, "000000", "ordinary narrowing S(4,1)+(4,1) -> (6,2) in=15/1");
    s_a_ordinary_s_a <= "1111"; s_a_ordinary_s_b <= "0111";
    p_settle(clk_tb);
    p_check_slv(s_a_ordinary_s_dout, "001100", "ordinary narrowing S(4,1)+(4,1) -> (6,2) in=15/7");
    s_a_ordinary_s_a <= "1111"; s_a_ordinary_s_b <= "1111";
    p_settle(clk_tb);
    p_check_slv(s_a_ordinary_s_dout, "111100", "ordinary narrowing S(4,1)+(4,1) -> (6,2) in=15/15");

    -- binary point equal to the width: U(4,4)+(4,4) -> (4,4)
    s_a_bpeq_u_a <= "0000"; s_a_bpeq_u_b <= "0000";
    p_settle(clk_tb);
    p_check_slv(s_a_bpeq_u_dout, "0000", "binary point equal to the width U(4,4)+(4,4) -> (4,4) in=0/0");
    s_a_bpeq_u_a <= "0000"; s_a_bpeq_u_b <= "0111";
    p_settle(clk_tb);
    p_check_slv(s_a_bpeq_u_dout, "0111", "binary point equal to the width U(4,4)+(4,4) -> (4,4) in=0/7");
    s_a_bpeq_u_a <= "0000"; s_a_bpeq_u_b <= "1111";
    p_settle(clk_tb);
    p_check_slv(s_a_bpeq_u_dout, "1111", "binary point equal to the width U(4,4)+(4,4) -> (4,4) in=0/15");
    s_a_bpeq_u_a <= "0001"; s_a_bpeq_u_b <= "0000";
    p_settle(clk_tb);
    p_check_slv(s_a_bpeq_u_dout, "0001", "binary point equal to the width U(4,4)+(4,4) -> (4,4) in=1/0");
    s_a_bpeq_u_a <= "0001"; s_a_bpeq_u_b <= "0111";
    p_settle(clk_tb);
    p_check_slv(s_a_bpeq_u_dout, "1000", "binary point equal to the width U(4,4)+(4,4) -> (4,4) in=1/7");
    s_a_bpeq_u_a <= "0001"; s_a_bpeq_u_b <= "1111";
    p_settle(clk_tb);
    p_check_slv(s_a_bpeq_u_dout, "0000", "binary point equal to the width U(4,4)+(4,4) -> (4,4) in=1/15");
    s_a_bpeq_u_a <= "1111"; s_a_bpeq_u_b <= "0000";
    p_settle(clk_tb);
    p_check_slv(s_a_bpeq_u_dout, "1111", "binary point equal to the width U(4,4)+(4,4) -> (4,4) in=15/0");
    s_a_bpeq_u_a <= "1111"; s_a_bpeq_u_b <= "0111";
    p_settle(clk_tb);
    p_check_slv(s_a_bpeq_u_dout, "0110", "binary point equal to the width U(4,4)+(4,4) -> (4,4) in=15/7");
    s_a_bpeq_u_a <= "1111"; s_a_bpeq_u_b <= "1111";
    p_settle(clk_tb);
    p_check_slv(s_a_bpeq_u_dout, "1110", "binary point equal to the width U(4,4)+(4,4) -> (4,4) in=15/15");

    -- binary point equal to the width: S(4,4)+(4,4) -> (4,4)
    s_a_bpeq_s_a <= "0000"; s_a_bpeq_s_b <= "0000";
    p_settle(clk_tb);
    p_check_slv(s_a_bpeq_s_dout, "0000", "binary point equal to the width S(4,4)+(4,4) -> (4,4) in=0/0");
    s_a_bpeq_s_a <= "0000"; s_a_bpeq_s_b <= "0111";
    p_settle(clk_tb);
    p_check_slv(s_a_bpeq_s_dout, "0111", "binary point equal to the width S(4,4)+(4,4) -> (4,4) in=0/7");
    s_a_bpeq_s_a <= "0000"; s_a_bpeq_s_b <= "1111";
    p_settle(clk_tb);
    p_check_slv(s_a_bpeq_s_dout, "1111", "binary point equal to the width S(4,4)+(4,4) -> (4,4) in=0/15");
    s_a_bpeq_s_a <= "0001"; s_a_bpeq_s_b <= "0000";
    p_settle(clk_tb);
    p_check_slv(s_a_bpeq_s_dout, "0001", "binary point equal to the width S(4,4)+(4,4) -> (4,4) in=1/0");
    s_a_bpeq_s_a <= "0001"; s_a_bpeq_s_b <= "0111";
    p_settle(clk_tb);
    p_check_slv(s_a_bpeq_s_dout, "1000", "binary point equal to the width S(4,4)+(4,4) -> (4,4) in=1/7");
    s_a_bpeq_s_a <= "0001"; s_a_bpeq_s_b <= "1111";
    p_settle(clk_tb);
    p_check_slv(s_a_bpeq_s_dout, "0000", "binary point equal to the width S(4,4)+(4,4) -> (4,4) in=1/15");
    s_a_bpeq_s_a <= "1111"; s_a_bpeq_s_b <= "0000";
    p_settle(clk_tb);
    p_check_slv(s_a_bpeq_s_dout, "1111", "binary point equal to the width S(4,4)+(4,4) -> (4,4) in=15/0");
    s_a_bpeq_s_a <= "1111"; s_a_bpeq_s_b <= "0111";
    p_settle(clk_tb);
    p_check_slv(s_a_bpeq_s_dout, "0110", "binary point equal to the width S(4,4)+(4,4) -> (4,4) in=15/7");
    s_a_bpeq_s_a <= "1111"; s_a_bpeq_s_b <= "1111";
    p_settle(clk_tb);
    p_check_slv(s_a_bpeq_s_dout, "1110", "binary point equal to the width S(4,4)+(4,4) -> (4,4) in=15/15");

    -- binary point above the width: S(4,8)-(4,6) -> (4,9)
    s_a_bpgt_s_a <= "0000"; s_a_bpgt_s_b <= "0001";
    p_settle(clk_tb);
    p_check_slv(s_a_bpgt_s_dout, "1000", "binary point above the width S(4,8)-(4,6) -> (4,9) in=0/1");
    s_a_bpgt_s_a <= "0000"; s_a_bpgt_s_b <= "1111";
    p_settle(clk_tb);
    p_check_slv(s_a_bpgt_s_dout, "1000", "binary point above the width S(4,8)-(4,6) -> (4,9) in=0/15");
    s_a_bpgt_s_a <= "0001"; s_a_bpgt_s_b <= "0001";
    p_settle(clk_tb);
    p_check_slv(s_a_bpgt_s_dout, "1010", "binary point above the width S(4,8)-(4,6) -> (4,9) in=1/1");
    s_a_bpgt_s_a <= "0001"; s_a_bpgt_s_b <= "1111";
    p_settle(clk_tb);
    p_check_slv(s_a_bpgt_s_dout, "1010", "binary point above the width S(4,8)-(4,6) -> (4,9) in=1/15");
    s_a_bpgt_s_a <= "1000"; s_a_bpgt_s_b <= "0001";
    p_settle(clk_tb);
    p_check_slv(s_a_bpgt_s_dout, "1000", "binary point above the width S(4,8)-(4,6) -> (4,9) in=8/1");
    s_a_bpgt_s_a <= "1000"; s_a_bpgt_s_b <= "1111";
    p_settle(clk_tb);
    p_check_slv(s_a_bpgt_s_dout, "1000", "binary point above the width S(4,8)-(4,6) -> (4,9) in=8/15");
    s_a_bpgt_s_a <= "1111"; s_a_bpgt_s_b <= "0001";
    p_settle(clk_tb);
    p_check_slv(s_a_bpgt_s_dout, "0110", "binary point above the width S(4,8)-(4,6) -> (4,9) in=15/1");
    s_a_bpgt_s_a <= "1111"; s_a_bpgt_s_b <= "1111";
    p_settle(clk_tb);
    p_check_slv(s_a_bpgt_s_dout, "0110", "binary point above the width S(4,8)-(4,6) -> (4,9) in=15/15");

    -- binary point above the width, source: U(4,6)+(4,6) -> (4,2)
    s_a_bpgt_src_u_a <= "0000"; s_a_bpgt_src_u_b <= "0001";
    p_settle(clk_tb);
    p_check_slv(s_a_bpgt_src_u_dout, "0000", "binary point above the width, source U(4,6)+(4,6) -> (4,2) in=0/1");
    s_a_bpgt_src_u_a <= "0000"; s_a_bpgt_src_u_b <= "1111";
    p_settle(clk_tb);
    p_check_slv(s_a_bpgt_src_u_dout, "0000", "binary point above the width, source U(4,6)+(4,6) -> (4,2) in=0/15");
    s_a_bpgt_src_u_a <= "0001"; s_a_bpgt_src_u_b <= "0001";
    p_settle(clk_tb);
    p_check_slv(s_a_bpgt_src_u_dout, "0000", "binary point above the width, source U(4,6)+(4,6) -> (4,2) in=1/1");
    s_a_bpgt_src_u_a <= "0001"; s_a_bpgt_src_u_b <= "1111";
    p_settle(clk_tb);
    p_check_slv(s_a_bpgt_src_u_dout, "0001", "binary point above the width, source U(4,6)+(4,6) -> (4,2) in=1/15");
    s_a_bpgt_src_u_a <= "1111"; s_a_bpgt_src_u_b <= "0001";
    p_settle(clk_tb);
    p_check_slv(s_a_bpgt_src_u_dout, "0001", "binary point above the width, source U(4,6)+(4,6) -> (4,2) in=15/1");
    s_a_bpgt_src_u_a <= "1111"; s_a_bpgt_src_u_b <= "1111";
    p_settle(clk_tb);
    p_check_slv(s_a_bpgt_src_u_dout, "0001", "binary point above the width, source U(4,6)+(4,6) -> (4,2) in=15/15");

    -- disjoint weights, destination below source: U(4,0)+(4,0) -> (4,10)
    s_a_disj_below_u_a <= "0000"; s_a_disj_below_u_b <= "0001";
    p_settle(clk_tb);
    p_check_slv(s_a_disj_below_u_dout, "0000", "disjoint weights, destination below source U(4,0)+(4,0) -> (4,10) in=0/1");
    s_a_disj_below_u_a <= "0000"; s_a_disj_below_u_b <= "1111";
    p_settle(clk_tb);
    p_check_slv(s_a_disj_below_u_dout, "0000", "disjoint weights, destination below source U(4,0)+(4,0) -> (4,10) in=0/15");
    s_a_disj_below_u_a <= "0001"; s_a_disj_below_u_b <= "0001";
    p_settle(clk_tb);
    p_check_slv(s_a_disj_below_u_dout, "0000", "disjoint weights, destination below source U(4,0)+(4,0) -> (4,10) in=1/1");
    s_a_disj_below_u_a <= "0001"; s_a_disj_below_u_b <= "1111";
    p_settle(clk_tb);
    p_check_slv(s_a_disj_below_u_dout, "0000", "disjoint weights, destination below source U(4,0)+(4,0) -> (4,10) in=1/15");
    s_a_disj_below_u_a <= "1111"; s_a_disj_below_u_b <= "0001";
    p_settle(clk_tb);
    p_check_slv(s_a_disj_below_u_dout, "0000", "disjoint weights, destination below source U(4,0)+(4,0) -> (4,10) in=15/1");
    s_a_disj_below_u_a <= "1111"; s_a_disj_below_u_b <= "1111";
    p_settle(clk_tb);
    p_check_slv(s_a_disj_below_u_dout, "0000", "disjoint weights, destination below source U(4,0)+(4,0) -> (4,10) in=15/15");

    -- disjoint weights, destination above source: S(4,8)+(4,8) -> (4,0)
    s_a_disj_above_s_a <= "0000"; s_a_disj_above_s_b <= "0001";
    p_settle(clk_tb);
    p_check_slv(s_a_disj_above_s_dout, "0000", "disjoint weights, destination above source S(4,8)+(4,8) -> (4,0) in=0/1");
    s_a_disj_above_s_a <= "0000"; s_a_disj_above_s_b <= "1111";
    p_settle(clk_tb);
    p_check_slv(s_a_disj_above_s_dout, "0000", "disjoint weights, destination above source S(4,8)+(4,8) -> (4,0) in=0/15");
    s_a_disj_above_s_a <= "0001"; s_a_disj_above_s_b <= "0001";
    p_settle(clk_tb);
    p_check_slv(s_a_disj_above_s_dout, "0000", "disjoint weights, destination above source S(4,8)+(4,8) -> (4,0) in=1/1");
    s_a_disj_above_s_a <= "0001"; s_a_disj_above_s_b <= "1111";
    p_settle(clk_tb);
    p_check_slv(s_a_disj_above_s_dout, "0000", "disjoint weights, destination above source S(4,8)+(4,8) -> (4,0) in=1/15");
    s_a_disj_above_s_a <= "1000"; s_a_disj_above_s_b <= "0001";
    p_settle(clk_tb);
    p_check_slv(s_a_disj_above_s_dout, "0000", "disjoint weights, destination above source S(4,8)+(4,8) -> (4,0) in=8/1");
    s_a_disj_above_s_a <= "1000"; s_a_disj_above_s_b <= "1111";
    p_settle(clk_tb);
    p_check_slv(s_a_disj_above_s_dout, "0000", "disjoint weights, destination above source S(4,8)+(4,8) -> (4,0) in=8/15");
    s_a_disj_above_s_a <= "1111"; s_a_disj_above_s_b <= "0001";
    p_settle(clk_tb);
    p_check_slv(s_a_disj_above_s_dout, "0000", "disjoint weights, destination above source S(4,8)+(4,8) -> (4,0) in=15/1");
    s_a_disj_above_s_a <= "1111"; s_a_disj_above_s_b <= "1111";
    p_settle(clk_tb);
    p_check_slv(s_a_disj_above_s_dout, "0000", "disjoint weights, destination above source S(4,8)+(4,8) -> (4,0) in=15/15");

    -- exactly one bit of weight overlap: U(4,4)+(4,4) -> (4,1)
    s_a_overlap1_u_a <= "0000"; s_a_overlap1_u_b <= "0101";
    p_settle(clk_tb);
    p_check_slv(s_a_overlap1_u_dout, "0001", "exactly one bit of weight overlap U(4,4)+(4,4) -> (4,1) in=0/5");
    s_a_overlap1_u_a <= "0000"; s_a_overlap1_u_b <= "1111";
    p_settle(clk_tb);
    p_check_slv(s_a_overlap1_u_dout, "0010", "exactly one bit of weight overlap U(4,4)+(4,4) -> (4,1) in=0/15");
    s_a_overlap1_u_a <= "0011"; s_a_overlap1_u_b <= "0101";
    p_settle(clk_tb);
    p_check_slv(s_a_overlap1_u_dout, "0001", "exactly one bit of weight overlap U(4,4)+(4,4) -> (4,1) in=3/5");
    s_a_overlap1_u_a <= "0011"; s_a_overlap1_u_b <= "1111";
    p_settle(clk_tb);
    p_check_slv(s_a_overlap1_u_dout, "0010", "exactly one bit of weight overlap U(4,4)+(4,4) -> (4,1) in=3/15");
    s_a_overlap1_u_a <= "1111"; s_a_overlap1_u_b <= "0101";
    p_settle(clk_tb);
    p_check_slv(s_a_overlap1_u_dout, "0010", "exactly one bit of weight overlap U(4,4)+(4,4) -> (4,1) in=15/5");
    s_a_overlap1_u_a <= "1111"; s_a_overlap1_u_b <= "1111";
    p_settle(clk_tb);
    p_check_slv(s_a_overlap1_u_dout, "0100", "exactly one bit of weight overlap U(4,4)+(4,4) -> (4,1) in=15/15");

    -- width 1 unsigned: U(1,1)+(1,1) -> (1,1)
    s_a_w1_u_a <= "0"; s_a_w1_u_b <= "0";
    p_settle(clk_tb);
    p_check_slv(s_a_w1_u_dout, "0", "width 1 unsigned U(1,1)+(1,1) -> (1,1) in=0/0");
    s_a_w1_u_a <= "0"; s_a_w1_u_b <= "1";
    p_settle(clk_tb);
    p_check_slv(s_a_w1_u_dout, "1", "width 1 unsigned U(1,1)+(1,1) -> (1,1) in=0/1");
    s_a_w1_u_a <= "1"; s_a_w1_u_b <= "0";
    p_settle(clk_tb);
    p_check_slv(s_a_w1_u_dout, "1", "width 1 unsigned U(1,1)+(1,1) -> (1,1) in=1/0");
    s_a_w1_u_a <= "1"; s_a_w1_u_b <= "1";
    p_settle(clk_tb);
    p_check_slv(s_a_w1_u_dout, "0", "width 1 unsigned U(1,1)+(1,1) -> (1,1) in=1/1");

    -- width 1 signed: S(1,1)+(1,1) -> (1,1)
    s_a_w1_s_a <= "0"; s_a_w1_s_b <= "0";
    p_settle(clk_tb);
    p_check_slv(s_a_w1_s_dout, "0", "width 1 signed S(1,1)+(1,1) -> (1,1) in=0/0");
    s_a_w1_s_a <= "0"; s_a_w1_s_b <= "1";
    p_settle(clk_tb);
    p_check_slv(s_a_w1_s_dout, "1", "width 1 signed S(1,1)+(1,1) -> (1,1) in=0/1");
    s_a_w1_s_a <= "1"; s_a_w1_s_b <= "0";
    p_settle(clk_tb);
    p_check_slv(s_a_w1_s_dout, "1", "width 1 signed S(1,1)+(1,1) -> (1,1) in=1/0");
    s_a_w1_s_a <= "1"; s_a_w1_s_b <= "1";
    p_settle(clk_tb);
    p_check_slv(s_a_w1_s_dout, "0", "width 1 signed S(1,1)+(1,1) -> (1,1) in=1/1");

    -- binary point equal to the width everywhere: U(4,4)x(4,4)+(8,8) -> (8,8)
    s_ma_bpeq_u_a <= "0000"; s_ma_bpeq_u_b <= "0000"; s_ma_bpeq_u_c <= "00000000";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpeq_u_dout, "00000000", "binary point equal to the width everywhere U(4,4)x(4,4)+(8,8) -> (8,8) in=0/0/0");
    s_ma_bpeq_u_a <= "0000"; s_ma_bpeq_u_b <= "0000"; s_ma_bpeq_u_c <= "10000001";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpeq_u_dout, "10000001", "binary point equal to the width everywhere U(4,4)x(4,4)+(8,8) -> (8,8) in=0/0/129");
    s_ma_bpeq_u_a <= "0000"; s_ma_bpeq_u_b <= "0000"; s_ma_bpeq_u_c <= "11111111";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpeq_u_dout, "11111111", "binary point equal to the width everywhere U(4,4)x(4,4)+(8,8) -> (8,8) in=0/0/255");
    s_ma_bpeq_u_a <= "0000"; s_ma_bpeq_u_b <= "1111"; s_ma_bpeq_u_c <= "00000000";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpeq_u_dout, "00000000", "binary point equal to the width everywhere U(4,4)x(4,4)+(8,8) -> (8,8) in=0/15/0");
    s_ma_bpeq_u_a <= "0000"; s_ma_bpeq_u_b <= "1111"; s_ma_bpeq_u_c <= "10000001";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpeq_u_dout, "10000001", "binary point equal to the width everywhere U(4,4)x(4,4)+(8,8) -> (8,8) in=0/15/129");
    s_ma_bpeq_u_a <= "0000"; s_ma_bpeq_u_b <= "1111"; s_ma_bpeq_u_c <= "11111111";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpeq_u_dout, "11111111", "binary point equal to the width everywhere U(4,4)x(4,4)+(8,8) -> (8,8) in=0/15/255");
    s_ma_bpeq_u_a <= "0011"; s_ma_bpeq_u_b <= "0000"; s_ma_bpeq_u_c <= "00000000";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpeq_u_dout, "00000000", "binary point equal to the width everywhere U(4,4)x(4,4)+(8,8) -> (8,8) in=3/0/0");
    s_ma_bpeq_u_a <= "0011"; s_ma_bpeq_u_b <= "0000"; s_ma_bpeq_u_c <= "10000001";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpeq_u_dout, "10000001", "binary point equal to the width everywhere U(4,4)x(4,4)+(8,8) -> (8,8) in=3/0/129");
    s_ma_bpeq_u_a <= "0011"; s_ma_bpeq_u_b <= "0000"; s_ma_bpeq_u_c <= "11111111";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpeq_u_dout, "11111111", "binary point equal to the width everywhere U(4,4)x(4,4)+(8,8) -> (8,8) in=3/0/255");
    s_ma_bpeq_u_a <= "0011"; s_ma_bpeq_u_b <= "1111"; s_ma_bpeq_u_c <= "00000000";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpeq_u_dout, "00101101", "binary point equal to the width everywhere U(4,4)x(4,4)+(8,8) -> (8,8) in=3/15/0");
    s_ma_bpeq_u_a <= "0011"; s_ma_bpeq_u_b <= "1111"; s_ma_bpeq_u_c <= "10000001";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpeq_u_dout, "10101110", "binary point equal to the width everywhere U(4,4)x(4,4)+(8,8) -> (8,8) in=3/15/129");
    s_ma_bpeq_u_a <= "0011"; s_ma_bpeq_u_b <= "1111"; s_ma_bpeq_u_c <= "11111111";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpeq_u_dout, "11111111", "binary point equal to the width everywhere U(4,4)x(4,4)+(8,8) -> (8,8) in=3/15/255");
    s_ma_bpeq_u_a <= "1111"; s_ma_bpeq_u_b <= "0000"; s_ma_bpeq_u_c <= "00000000";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpeq_u_dout, "00000000", "binary point equal to the width everywhere U(4,4)x(4,4)+(8,8) -> (8,8) in=15/0/0");
    s_ma_bpeq_u_a <= "1111"; s_ma_bpeq_u_b <= "0000"; s_ma_bpeq_u_c <= "10000001";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpeq_u_dout, "10000001", "binary point equal to the width everywhere U(4,4)x(4,4)+(8,8) -> (8,8) in=15/0/129");
    s_ma_bpeq_u_a <= "1111"; s_ma_bpeq_u_b <= "0000"; s_ma_bpeq_u_c <= "11111111";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpeq_u_dout, "11111111", "binary point equal to the width everywhere U(4,4)x(4,4)+(8,8) -> (8,8) in=15/0/255");
    s_ma_bpeq_u_a <= "1111"; s_ma_bpeq_u_b <= "1111"; s_ma_bpeq_u_c <= "00000000";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpeq_u_dout, "11100001", "binary point equal to the width everywhere U(4,4)x(4,4)+(8,8) -> (8,8) in=15/15/0");
    s_ma_bpeq_u_a <= "1111"; s_ma_bpeq_u_b <= "1111"; s_ma_bpeq_u_c <= "10000001";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpeq_u_dout, "11111111", "binary point equal to the width everywhere U(4,4)x(4,4)+(8,8) -> (8,8) in=15/15/129");
    s_ma_bpeq_u_a <= "1111"; s_ma_bpeq_u_b <= "1111"; s_ma_bpeq_u_c <= "11111111";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpeq_u_dout, "11111111", "binary point equal to the width everywhere U(4,4)x(4,4)+(8,8) -> (8,8) in=15/15/255");

    -- binary point equal to the width everywhere: S(4,4)x(4,4)+(8,8) -> (8,8)
    s_ma_bpeq_s_a <= "0000"; s_ma_bpeq_s_b <= "0000"; s_ma_bpeq_s_c <= "00000000";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpeq_s_dout, "00000000", "binary point equal to the width everywhere S(4,4)x(4,4)+(8,8) -> (8,8) in=0/0/0");
    s_ma_bpeq_s_a <= "0000"; s_ma_bpeq_s_b <= "0000"; s_ma_bpeq_s_c <= "10000001";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpeq_s_dout, "10000001", "binary point equal to the width everywhere S(4,4)x(4,4)+(8,8) -> (8,8) in=0/0/129");
    s_ma_bpeq_s_a <= "0000"; s_ma_bpeq_s_b <= "0000"; s_ma_bpeq_s_c <= "11111111";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpeq_s_dout, "11111111", "binary point equal to the width everywhere S(4,4)x(4,4)+(8,8) -> (8,8) in=0/0/255");
    s_ma_bpeq_s_a <= "0000"; s_ma_bpeq_s_b <= "1111"; s_ma_bpeq_s_c <= "00000000";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpeq_s_dout, "00000000", "binary point equal to the width everywhere S(4,4)x(4,4)+(8,8) -> (8,8) in=0/15/0");
    s_ma_bpeq_s_a <= "0000"; s_ma_bpeq_s_b <= "1111"; s_ma_bpeq_s_c <= "10000001";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpeq_s_dout, "10000001", "binary point equal to the width everywhere S(4,4)x(4,4)+(8,8) -> (8,8) in=0/15/129");
    s_ma_bpeq_s_a <= "0000"; s_ma_bpeq_s_b <= "1111"; s_ma_bpeq_s_c <= "11111111";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpeq_s_dout, "11111111", "binary point equal to the width everywhere S(4,4)x(4,4)+(8,8) -> (8,8) in=0/15/255");
    s_ma_bpeq_s_a <= "0011"; s_ma_bpeq_s_b <= "0000"; s_ma_bpeq_s_c <= "00000000";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpeq_s_dout, "00000000", "binary point equal to the width everywhere S(4,4)x(4,4)+(8,8) -> (8,8) in=3/0/0");
    s_ma_bpeq_s_a <= "0011"; s_ma_bpeq_s_b <= "0000"; s_ma_bpeq_s_c <= "10000001";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpeq_s_dout, "10000001", "binary point equal to the width everywhere S(4,4)x(4,4)+(8,8) -> (8,8) in=3/0/129");
    s_ma_bpeq_s_a <= "0011"; s_ma_bpeq_s_b <= "0000"; s_ma_bpeq_s_c <= "11111111";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpeq_s_dout, "11111111", "binary point equal to the width everywhere S(4,4)x(4,4)+(8,8) -> (8,8) in=3/0/255");
    s_ma_bpeq_s_a <= "0011"; s_ma_bpeq_s_b <= "1111"; s_ma_bpeq_s_c <= "00000000";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpeq_s_dout, "11111101", "binary point equal to the width everywhere S(4,4)x(4,4)+(8,8) -> (8,8) in=3/15/0");
    s_ma_bpeq_s_a <= "0011"; s_ma_bpeq_s_b <= "1111"; s_ma_bpeq_s_c <= "10000001";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpeq_s_dout, "10000000", "binary point equal to the width everywhere S(4,4)x(4,4)+(8,8) -> (8,8) in=3/15/129");
    s_ma_bpeq_s_a <= "0011"; s_ma_bpeq_s_b <= "1111"; s_ma_bpeq_s_c <= "11111111";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpeq_s_dout, "11111100", "binary point equal to the width everywhere S(4,4)x(4,4)+(8,8) -> (8,8) in=3/15/255");
    s_ma_bpeq_s_a <= "1111"; s_ma_bpeq_s_b <= "0000"; s_ma_bpeq_s_c <= "00000000";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpeq_s_dout, "00000000", "binary point equal to the width everywhere S(4,4)x(4,4)+(8,8) -> (8,8) in=15/0/0");
    s_ma_bpeq_s_a <= "1111"; s_ma_bpeq_s_b <= "0000"; s_ma_bpeq_s_c <= "10000001";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpeq_s_dout, "10000001", "binary point equal to the width everywhere S(4,4)x(4,4)+(8,8) -> (8,8) in=15/0/129");
    s_ma_bpeq_s_a <= "1111"; s_ma_bpeq_s_b <= "0000"; s_ma_bpeq_s_c <= "11111111";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpeq_s_dout, "11111111", "binary point equal to the width everywhere S(4,4)x(4,4)+(8,8) -> (8,8) in=15/0/255");
    s_ma_bpeq_s_a <= "1111"; s_ma_bpeq_s_b <= "1111"; s_ma_bpeq_s_c <= "00000000";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpeq_s_dout, "00000001", "binary point equal to the width everywhere S(4,4)x(4,4)+(8,8) -> (8,8) in=15/15/0");
    s_ma_bpeq_s_a <= "1111"; s_ma_bpeq_s_b <= "1111"; s_ma_bpeq_s_c <= "10000001";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpeq_s_dout, "10000010", "binary point equal to the width everywhere S(4,4)x(4,4)+(8,8) -> (8,8) in=15/15/129");
    s_ma_bpeq_s_a <= "1111"; s_ma_bpeq_s_b <= "1111"; s_ma_bpeq_s_c <= "11111111";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpeq_s_dout, "00000000", "binary point equal to the width everywhere S(4,4)x(4,4)+(8,8) -> (8,8) in=15/15/255");

    -- binary point above the width on the operands: S(4,6)x(4,6)+(8,2) -> (8,4)
    s_ma_bpgt_ops_s_a <= "0000"; s_ma_bpgt_ops_s_b <= "0001"; s_ma_bpgt_ops_s_c <= "00000000";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpgt_ops_s_dout, "00000000", "binary point above the width on the operands S(4,6)x(4,6)+(8,2) -> (8,4) in=0/1/0");
    s_ma_bpgt_ops_s_a <= "0000"; s_ma_bpgt_ops_s_b <= "0001"; s_ma_bpgt_ops_s_c <= "11001000";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpgt_ops_s_dout, "10000000", "binary point above the width on the operands S(4,6)x(4,6)+(8,2) -> (8,4) in=0/1/200");
    s_ma_bpgt_ops_s_a <= "0000"; s_ma_bpgt_ops_s_b <= "1111"; s_ma_bpgt_ops_s_c <= "00000000";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpgt_ops_s_dout, "00000000", "binary point above the width on the operands S(4,6)x(4,6)+(8,2) -> (8,4) in=0/15/0");
    s_ma_bpgt_ops_s_a <= "0000"; s_ma_bpgt_ops_s_b <= "1111"; s_ma_bpgt_ops_s_c <= "11001000";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpgt_ops_s_dout, "10000000", "binary point above the width on the operands S(4,6)x(4,6)+(8,2) -> (8,4) in=0/15/200");
    s_ma_bpgt_ops_s_a <= "0001"; s_ma_bpgt_ops_s_b <= "0001"; s_ma_bpgt_ops_s_c <= "00000000";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpgt_ops_s_dout, "00000000", "binary point above the width on the operands S(4,6)x(4,6)+(8,2) -> (8,4) in=1/1/0");
    s_ma_bpgt_ops_s_a <= "0001"; s_ma_bpgt_ops_s_b <= "0001"; s_ma_bpgt_ops_s_c <= "11001000";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpgt_ops_s_dout, "10000000", "binary point above the width on the operands S(4,6)x(4,6)+(8,2) -> (8,4) in=1/1/200");
    s_ma_bpgt_ops_s_a <= "0001"; s_ma_bpgt_ops_s_b <= "1111"; s_ma_bpgt_ops_s_c <= "00000000";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpgt_ops_s_dout, "00000000", "binary point above the width on the operands S(4,6)x(4,6)+(8,2) -> (8,4) in=1/15/0");
    s_ma_bpgt_ops_s_a <= "0001"; s_ma_bpgt_ops_s_b <= "1111"; s_ma_bpgt_ops_s_c <= "11001000";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpgt_ops_s_dout, "10000000", "binary point above the width on the operands S(4,6)x(4,6)+(8,2) -> (8,4) in=1/15/200");
    s_ma_bpgt_ops_s_a <= "1000"; s_ma_bpgt_ops_s_b <= "0001"; s_ma_bpgt_ops_s_c <= "00000000";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpgt_ops_s_dout, "00000000", "binary point above the width on the operands S(4,6)x(4,6)+(8,2) -> (8,4) in=8/1/0");
    s_ma_bpgt_ops_s_a <= "1000"; s_ma_bpgt_ops_s_b <= "0001"; s_ma_bpgt_ops_s_c <= "11001000";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpgt_ops_s_dout, "10000000", "binary point above the width on the operands S(4,6)x(4,6)+(8,2) -> (8,4) in=8/1/200");
    s_ma_bpgt_ops_s_a <= "1000"; s_ma_bpgt_ops_s_b <= "1111"; s_ma_bpgt_ops_s_c <= "00000000";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpgt_ops_s_dout, "00000000", "binary point above the width on the operands S(4,6)x(4,6)+(8,2) -> (8,4) in=8/15/0");
    s_ma_bpgt_ops_s_a <= "1000"; s_ma_bpgt_ops_s_b <= "1111"; s_ma_bpgt_ops_s_c <= "11001000";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpgt_ops_s_dout, "10000000", "binary point above the width on the operands S(4,6)x(4,6)+(8,2) -> (8,4) in=8/15/200");
    s_ma_bpgt_ops_s_a <= "1111"; s_ma_bpgt_ops_s_b <= "0001"; s_ma_bpgt_ops_s_c <= "00000000";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpgt_ops_s_dout, "00000000", "binary point above the width on the operands S(4,6)x(4,6)+(8,2) -> (8,4) in=15/1/0");
    s_ma_bpgt_ops_s_a <= "1111"; s_ma_bpgt_ops_s_b <= "0001"; s_ma_bpgt_ops_s_c <= "11001000";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpgt_ops_s_dout, "10000000", "binary point above the width on the operands S(4,6)x(4,6)+(8,2) -> (8,4) in=15/1/200");
    s_ma_bpgt_ops_s_a <= "1111"; s_ma_bpgt_ops_s_b <= "1111"; s_ma_bpgt_ops_s_c <= "00000000";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpgt_ops_s_dout, "00000000", "binary point above the width on the operands S(4,6)x(4,6)+(8,2) -> (8,4) in=15/15/0");
    s_ma_bpgt_ops_s_a <= "1111"; s_ma_bpgt_ops_s_b <= "1111"; s_ma_bpgt_ops_s_c <= "11001000";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpgt_ops_s_dout, "10000000", "binary point above the width on the operands S(4,6)x(4,6)+(8,2) -> (8,4) in=15/15/200");

    -- binary point above the width on the addend, subtract: S(4,1)x(4,1)-(8,12) -> (8,4)
    s_ma_bpgt_addend_s_a <= "0000"; s_ma_bpgt_addend_s_b <= "0001"; s_ma_bpgt_addend_s_c <= "00000000";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpgt_addend_s_dout, "00000000", "binary point above the width on the addend, subtract S(4,1)x(4,1)-(8,12) -> (8,4) in=0/1/0");
    s_ma_bpgt_addend_s_a <= "0000"; s_ma_bpgt_addend_s_b <= "0001"; s_ma_bpgt_addend_s_c <= "10000001";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpgt_addend_s_dout, "00000000", "binary point above the width on the addend, subtract S(4,1)x(4,1)-(8,12) -> (8,4) in=0/1/129");
    s_ma_bpgt_addend_s_a <= "0000"; s_ma_bpgt_addend_s_b <= "0001"; s_ma_bpgt_addend_s_c <= "11111111";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpgt_addend_s_dout, "00000000", "binary point above the width on the addend, subtract S(4,1)x(4,1)-(8,12) -> (8,4) in=0/1/255");
    s_ma_bpgt_addend_s_a <= "0000"; s_ma_bpgt_addend_s_b <= "1111"; s_ma_bpgt_addend_s_c <= "00000000";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpgt_addend_s_dout, "00000000", "binary point above the width on the addend, subtract S(4,1)x(4,1)-(8,12) -> (8,4) in=0/15/0");
    s_ma_bpgt_addend_s_a <= "0000"; s_ma_bpgt_addend_s_b <= "1111"; s_ma_bpgt_addend_s_c <= "10000001";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpgt_addend_s_dout, "00000000", "binary point above the width on the addend, subtract S(4,1)x(4,1)-(8,12) -> (8,4) in=0/15/129");
    s_ma_bpgt_addend_s_a <= "0000"; s_ma_bpgt_addend_s_b <= "1111"; s_ma_bpgt_addend_s_c <= "11111111";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpgt_addend_s_dout, "00000000", "binary point above the width on the addend, subtract S(4,1)x(4,1)-(8,12) -> (8,4) in=0/15/255");
    s_ma_bpgt_addend_s_a <= "0001"; s_ma_bpgt_addend_s_b <= "0001"; s_ma_bpgt_addend_s_c <= "00000000";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpgt_addend_s_dout, "00000100", "binary point above the width on the addend, subtract S(4,1)x(4,1)-(8,12) -> (8,4) in=1/1/0");
    s_ma_bpgt_addend_s_a <= "0001"; s_ma_bpgt_addend_s_b <= "0001"; s_ma_bpgt_addend_s_c <= "10000001";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpgt_addend_s_dout, "00000100", "binary point above the width on the addend, subtract S(4,1)x(4,1)-(8,12) -> (8,4) in=1/1/129");
    s_ma_bpgt_addend_s_a <= "0001"; s_ma_bpgt_addend_s_b <= "0001"; s_ma_bpgt_addend_s_c <= "11111111";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpgt_addend_s_dout, "00000100", "binary point above the width on the addend, subtract S(4,1)x(4,1)-(8,12) -> (8,4) in=1/1/255");
    s_ma_bpgt_addend_s_a <= "0001"; s_ma_bpgt_addend_s_b <= "1111"; s_ma_bpgt_addend_s_c <= "00000000";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpgt_addend_s_dout, "11111100", "binary point above the width on the addend, subtract S(4,1)x(4,1)-(8,12) -> (8,4) in=1/15/0");
    s_ma_bpgt_addend_s_a <= "0001"; s_ma_bpgt_addend_s_b <= "1111"; s_ma_bpgt_addend_s_c <= "10000001";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpgt_addend_s_dout, "11111100", "binary point above the width on the addend, subtract S(4,1)x(4,1)-(8,12) -> (8,4) in=1/15/129");
    s_ma_bpgt_addend_s_a <= "0001"; s_ma_bpgt_addend_s_b <= "1111"; s_ma_bpgt_addend_s_c <= "11111111";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpgt_addend_s_dout, "11111100", "binary point above the width on the addend, subtract S(4,1)x(4,1)-(8,12) -> (8,4) in=1/15/255");
    s_ma_bpgt_addend_s_a <= "1000"; s_ma_bpgt_addend_s_b <= "0001"; s_ma_bpgt_addend_s_c <= "00000000";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpgt_addend_s_dout, "11100000", "binary point above the width on the addend, subtract S(4,1)x(4,1)-(8,12) -> (8,4) in=8/1/0");
    s_ma_bpgt_addend_s_a <= "1000"; s_ma_bpgt_addend_s_b <= "0001"; s_ma_bpgt_addend_s_c <= "10000001";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpgt_addend_s_dout, "11100000", "binary point above the width on the addend, subtract S(4,1)x(4,1)-(8,12) -> (8,4) in=8/1/129");
    s_ma_bpgt_addend_s_a <= "1000"; s_ma_bpgt_addend_s_b <= "0001"; s_ma_bpgt_addend_s_c <= "11111111";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpgt_addend_s_dout, "11100000", "binary point above the width on the addend, subtract S(4,1)x(4,1)-(8,12) -> (8,4) in=8/1/255");
    s_ma_bpgt_addend_s_a <= "1000"; s_ma_bpgt_addend_s_b <= "1111"; s_ma_bpgt_addend_s_c <= "00000000";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpgt_addend_s_dout, "00100000", "binary point above the width on the addend, subtract S(4,1)x(4,1)-(8,12) -> (8,4) in=8/15/0");
    s_ma_bpgt_addend_s_a <= "1000"; s_ma_bpgt_addend_s_b <= "1111"; s_ma_bpgt_addend_s_c <= "10000001";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpgt_addend_s_dout, "00100000", "binary point above the width on the addend, subtract S(4,1)x(4,1)-(8,12) -> (8,4) in=8/15/129");
    s_ma_bpgt_addend_s_a <= "1000"; s_ma_bpgt_addend_s_b <= "1111"; s_ma_bpgt_addend_s_c <= "11111111";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpgt_addend_s_dout, "00100000", "binary point above the width on the addend, subtract S(4,1)x(4,1)-(8,12) -> (8,4) in=8/15/255");

    -- binary point above the width everywhere: U(4,6)x(4,6)+(8,12) -> (8,14)
    s_ma_bpgt_all_u_a <= "0000"; s_ma_bpgt_all_u_b <= "0001"; s_ma_bpgt_all_u_c <= "00000000";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpgt_all_u_dout, "00000000", "binary point above the width everywhere U(4,6)x(4,6)+(8,12) -> (8,14) in=0/1/0");
    s_ma_bpgt_all_u_a <= "0000"; s_ma_bpgt_all_u_b <= "0001"; s_ma_bpgt_all_u_c <= "11111111";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpgt_all_u_dout, "11111100", "binary point above the width everywhere U(4,6)x(4,6)+(8,12) -> (8,14) in=0/1/255");
    s_ma_bpgt_all_u_a <= "0000"; s_ma_bpgt_all_u_b <= "1111"; s_ma_bpgt_all_u_c <= "00000000";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpgt_all_u_dout, "00000000", "binary point above the width everywhere U(4,6)x(4,6)+(8,12) -> (8,14) in=0/15/0");
    s_ma_bpgt_all_u_a <= "0000"; s_ma_bpgt_all_u_b <= "1111"; s_ma_bpgt_all_u_c <= "11111111";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpgt_all_u_dout, "11111100", "binary point above the width everywhere U(4,6)x(4,6)+(8,12) -> (8,14) in=0/15/255");
    s_ma_bpgt_all_u_a <= "0001"; s_ma_bpgt_all_u_b <= "0001"; s_ma_bpgt_all_u_c <= "00000000";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpgt_all_u_dout, "00000100", "binary point above the width everywhere U(4,6)x(4,6)+(8,12) -> (8,14) in=1/1/0");
    s_ma_bpgt_all_u_a <= "0001"; s_ma_bpgt_all_u_b <= "0001"; s_ma_bpgt_all_u_c <= "11111111";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpgt_all_u_dout, "00000000", "binary point above the width everywhere U(4,6)x(4,6)+(8,12) -> (8,14) in=1/1/255");
    s_ma_bpgt_all_u_a <= "0001"; s_ma_bpgt_all_u_b <= "1111"; s_ma_bpgt_all_u_c <= "00000000";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpgt_all_u_dout, "00111100", "binary point above the width everywhere U(4,6)x(4,6)+(8,12) -> (8,14) in=1/15/0");
    s_ma_bpgt_all_u_a <= "0001"; s_ma_bpgt_all_u_b <= "1111"; s_ma_bpgt_all_u_c <= "11111111";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpgt_all_u_dout, "00111000", "binary point above the width everywhere U(4,6)x(4,6)+(8,12) -> (8,14) in=1/15/255");
    s_ma_bpgt_all_u_a <= "1111"; s_ma_bpgt_all_u_b <= "0001"; s_ma_bpgt_all_u_c <= "00000000";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpgt_all_u_dout, "00111100", "binary point above the width everywhere U(4,6)x(4,6)+(8,12) -> (8,14) in=15/1/0");
    s_ma_bpgt_all_u_a <= "1111"; s_ma_bpgt_all_u_b <= "0001"; s_ma_bpgt_all_u_c <= "11111111";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpgt_all_u_dout, "00111000", "binary point above the width everywhere U(4,6)x(4,6)+(8,12) -> (8,14) in=15/1/255");
    s_ma_bpgt_all_u_a <= "1111"; s_ma_bpgt_all_u_b <= "1111"; s_ma_bpgt_all_u_c <= "00000000";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpgt_all_u_dout, "10000100", "binary point above the width everywhere U(4,6)x(4,6)+(8,12) -> (8,14) in=15/15/0");
    s_ma_bpgt_all_u_a <= "1111"; s_ma_bpgt_all_u_b <= "1111"; s_ma_bpgt_all_u_c <= "11111111";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpgt_all_u_dout, "10000000", "binary point above the width everywhere U(4,6)x(4,6)+(8,12) -> (8,14) in=15/15/255");

    -- binary point above the width on the output only: S(4,1)x(4,1)+(8,1) -> (4,9)
    s_ma_bpgt_out_s_a <= "0000"; s_ma_bpgt_out_s_b <= "0001"; s_ma_bpgt_out_s_c <= "00000000";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpgt_out_s_dout, "0000", "binary point above the width on the output only S(4,1)x(4,1)+(8,1) -> (4,9) in=0/1/0");
    s_ma_bpgt_out_s_a <= "0000"; s_ma_bpgt_out_s_b <= "0001"; s_ma_bpgt_out_s_c <= "11001000";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpgt_out_s_dout, "1000", "binary point above the width on the output only S(4,1)x(4,1)+(8,1) -> (4,9) in=0/1/200");
    s_ma_bpgt_out_s_a <= "0000"; s_ma_bpgt_out_s_b <= "1111"; s_ma_bpgt_out_s_c <= "00000000";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpgt_out_s_dout, "0000", "binary point above the width on the output only S(4,1)x(4,1)+(8,1) -> (4,9) in=0/15/0");
    s_ma_bpgt_out_s_a <= "0000"; s_ma_bpgt_out_s_b <= "1111"; s_ma_bpgt_out_s_c <= "11001000";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpgt_out_s_dout, "1000", "binary point above the width on the output only S(4,1)x(4,1)+(8,1) -> (4,9) in=0/15/200");
    s_ma_bpgt_out_s_a <= "0001"; s_ma_bpgt_out_s_b <= "0001"; s_ma_bpgt_out_s_c <= "00000000";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpgt_out_s_dout, "0111", "binary point above the width on the output only S(4,1)x(4,1)+(8,1) -> (4,9) in=1/1/0");
    s_ma_bpgt_out_s_a <= "0001"; s_ma_bpgt_out_s_b <= "0001"; s_ma_bpgt_out_s_c <= "11001000";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpgt_out_s_dout, "1000", "binary point above the width on the output only S(4,1)x(4,1)+(8,1) -> (4,9) in=1/1/200");
    s_ma_bpgt_out_s_a <= "0001"; s_ma_bpgt_out_s_b <= "1111"; s_ma_bpgt_out_s_c <= "00000000";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpgt_out_s_dout, "1000", "binary point above the width on the output only S(4,1)x(4,1)+(8,1) -> (4,9) in=1/15/0");
    s_ma_bpgt_out_s_a <= "0001"; s_ma_bpgt_out_s_b <= "1111"; s_ma_bpgt_out_s_c <= "11001000";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpgt_out_s_dout, "1000", "binary point above the width on the output only S(4,1)x(4,1)+(8,1) -> (4,9) in=1/15/200");
    s_ma_bpgt_out_s_a <= "1000"; s_ma_bpgt_out_s_b <= "0001"; s_ma_bpgt_out_s_c <= "00000000";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpgt_out_s_dout, "1000", "binary point above the width on the output only S(4,1)x(4,1)+(8,1) -> (4,9) in=8/1/0");
    s_ma_bpgt_out_s_a <= "1000"; s_ma_bpgt_out_s_b <= "0001"; s_ma_bpgt_out_s_c <= "11001000";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpgt_out_s_dout, "1000", "binary point above the width on the output only S(4,1)x(4,1)+(8,1) -> (4,9) in=8/1/200");
    s_ma_bpgt_out_s_a <= "1000"; s_ma_bpgt_out_s_b <= "1111"; s_ma_bpgt_out_s_c <= "00000000";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpgt_out_s_dout, "0111", "binary point above the width on the output only S(4,1)x(4,1)+(8,1) -> (4,9) in=8/15/0");
    s_ma_bpgt_out_s_a <= "1000"; s_ma_bpgt_out_s_b <= "1111"; s_ma_bpgt_out_s_c <= "11001000";
    p_settle(clk_tb);
    p_check_slv(s_ma_bpgt_out_s_dout, "1000", "binary point above the width on the output only S(4,1)x(4,1)+(8,1) -> (4,9) in=8/15/200");

    -- disjoint weights, destination below source: U(4,0)x(4,0)+(8,0) -> (4,14)
    s_ma_disj_below_u_a <= "0000"; s_ma_disj_below_u_b <= "0001"; s_ma_disj_below_u_c <= "00000000";
    p_settle(clk_tb);
    p_check_slv(s_ma_disj_below_u_dout, "0000", "disjoint weights, destination below source U(4,0)x(4,0)+(8,0) -> (4,14) in=0/1/0");
    s_ma_disj_below_u_a <= "0000"; s_ma_disj_below_u_b <= "0001"; s_ma_disj_below_u_c <= "11111111";
    p_settle(clk_tb);
    p_check_slv(s_ma_disj_below_u_dout, "1111", "disjoint weights, destination below source U(4,0)x(4,0)+(8,0) -> (4,14) in=0/1/255");
    s_ma_disj_below_u_a <= "0000"; s_ma_disj_below_u_b <= "1111"; s_ma_disj_below_u_c <= "00000000";
    p_settle(clk_tb);
    p_check_slv(s_ma_disj_below_u_dout, "0000", "disjoint weights, destination below source U(4,0)x(4,0)+(8,0) -> (4,14) in=0/15/0");
    s_ma_disj_below_u_a <= "0000"; s_ma_disj_below_u_b <= "1111"; s_ma_disj_below_u_c <= "11111111";
    p_settle(clk_tb);
    p_check_slv(s_ma_disj_below_u_dout, "1111", "disjoint weights, destination below source U(4,0)x(4,0)+(8,0) -> (4,14) in=0/15/255");
    s_ma_disj_below_u_a <= "0001"; s_ma_disj_below_u_b <= "0001"; s_ma_disj_below_u_c <= "00000000";
    p_settle(clk_tb);
    p_check_slv(s_ma_disj_below_u_dout, "1111", "disjoint weights, destination below source U(4,0)x(4,0)+(8,0) -> (4,14) in=1/1/0");
    s_ma_disj_below_u_a <= "0001"; s_ma_disj_below_u_b <= "0001"; s_ma_disj_below_u_c <= "11111111";
    p_settle(clk_tb);
    p_check_slv(s_ma_disj_below_u_dout, "1111", "disjoint weights, destination below source U(4,0)x(4,0)+(8,0) -> (4,14) in=1/1/255");
    s_ma_disj_below_u_a <= "0001"; s_ma_disj_below_u_b <= "1111"; s_ma_disj_below_u_c <= "00000000";
    p_settle(clk_tb);
    p_check_slv(s_ma_disj_below_u_dout, "1111", "disjoint weights, destination below source U(4,0)x(4,0)+(8,0) -> (4,14) in=1/15/0");
    s_ma_disj_below_u_a <= "0001"; s_ma_disj_below_u_b <= "1111"; s_ma_disj_below_u_c <= "11111111";
    p_settle(clk_tb);
    p_check_slv(s_ma_disj_below_u_dout, "1111", "disjoint weights, destination below source U(4,0)x(4,0)+(8,0) -> (4,14) in=1/15/255");
    s_ma_disj_below_u_a <= "1111"; s_ma_disj_below_u_b <= "0001"; s_ma_disj_below_u_c <= "00000000";
    p_settle(clk_tb);
    p_check_slv(s_ma_disj_below_u_dout, "1111", "disjoint weights, destination below source U(4,0)x(4,0)+(8,0) -> (4,14) in=15/1/0");
    s_ma_disj_below_u_a <= "1111"; s_ma_disj_below_u_b <= "0001"; s_ma_disj_below_u_c <= "11111111";
    p_settle(clk_tb);
    p_check_slv(s_ma_disj_below_u_dout, "1111", "disjoint weights, destination below source U(4,0)x(4,0)+(8,0) -> (4,14) in=15/1/255");
    s_ma_disj_below_u_a <= "1111"; s_ma_disj_below_u_b <= "1111"; s_ma_disj_below_u_c <= "00000000";
    p_settle(clk_tb);
    p_check_slv(s_ma_disj_below_u_dout, "1111", "disjoint weights, destination below source U(4,0)x(4,0)+(8,0) -> (4,14) in=15/15/0");
    s_ma_disj_below_u_a <= "1111"; s_ma_disj_below_u_b <= "1111"; s_ma_disj_below_u_c <= "11111111";
    p_settle(clk_tb);
    p_check_slv(s_ma_disj_below_u_dout, "1111", "disjoint weights, destination below source U(4,0)x(4,0)+(8,0) -> (4,14) in=15/15/255");

    -- disjoint weights, destination above source: S(4,8)x(4,8)+(8,10) -> (4,0)
    s_ma_disj_above_s_a <= "0000"; s_ma_disj_above_s_b <= "0001"; s_ma_disj_above_s_c <= "00000000";
    p_settle(clk_tb);
    p_check_slv(s_ma_disj_above_s_dout, "0000", "disjoint weights, destination above source S(4,8)x(4,8)+(8,10) -> (4,0) in=0/1/0");
    s_ma_disj_above_s_a <= "0000"; s_ma_disj_above_s_b <= "0001"; s_ma_disj_above_s_c <= "11111111";
    p_settle(clk_tb);
    p_check_slv(s_ma_disj_above_s_dout, "0000", "disjoint weights, destination above source S(4,8)x(4,8)+(8,10) -> (4,0) in=0/1/255");
    s_ma_disj_above_s_a <= "0000"; s_ma_disj_above_s_b <= "1111"; s_ma_disj_above_s_c <= "00000000";
    p_settle(clk_tb);
    p_check_slv(s_ma_disj_above_s_dout, "0000", "disjoint weights, destination above source S(4,8)x(4,8)+(8,10) -> (4,0) in=0/15/0");
    s_ma_disj_above_s_a <= "0000"; s_ma_disj_above_s_b <= "1111"; s_ma_disj_above_s_c <= "11111111";
    p_settle(clk_tb);
    p_check_slv(s_ma_disj_above_s_dout, "0000", "disjoint weights, destination above source S(4,8)x(4,8)+(8,10) -> (4,0) in=0/15/255");
    s_ma_disj_above_s_a <= "0001"; s_ma_disj_above_s_b <= "0001"; s_ma_disj_above_s_c <= "00000000";
    p_settle(clk_tb);
    p_check_slv(s_ma_disj_above_s_dout, "0000", "disjoint weights, destination above source S(4,8)x(4,8)+(8,10) -> (4,0) in=1/1/0");
    s_ma_disj_above_s_a <= "0001"; s_ma_disj_above_s_b <= "0001"; s_ma_disj_above_s_c <= "11111111";
    p_settle(clk_tb);
    p_check_slv(s_ma_disj_above_s_dout, "0000", "disjoint weights, destination above source S(4,8)x(4,8)+(8,10) -> (4,0) in=1/1/255");
    s_ma_disj_above_s_a <= "0001"; s_ma_disj_above_s_b <= "1111"; s_ma_disj_above_s_c <= "00000000";
    p_settle(clk_tb);
    p_check_slv(s_ma_disj_above_s_dout, "0000", "disjoint weights, destination above source S(4,8)x(4,8)+(8,10) -> (4,0) in=1/15/0");
    s_ma_disj_above_s_a <= "0001"; s_ma_disj_above_s_b <= "1111"; s_ma_disj_above_s_c <= "11111111";
    p_settle(clk_tb);
    p_check_slv(s_ma_disj_above_s_dout, "0000", "disjoint weights, destination above source S(4,8)x(4,8)+(8,10) -> (4,0) in=1/15/255");
    s_ma_disj_above_s_a <= "1000"; s_ma_disj_above_s_b <= "0001"; s_ma_disj_above_s_c <= "00000000";
    p_settle(clk_tb);
    p_check_slv(s_ma_disj_above_s_dout, "0000", "disjoint weights, destination above source S(4,8)x(4,8)+(8,10) -> (4,0) in=8/1/0");
    s_ma_disj_above_s_a <= "1000"; s_ma_disj_above_s_b <= "0001"; s_ma_disj_above_s_c <= "11111111";
    p_settle(clk_tb);
    p_check_slv(s_ma_disj_above_s_dout, "0000", "disjoint weights, destination above source S(4,8)x(4,8)+(8,10) -> (4,0) in=8/1/255");
    s_ma_disj_above_s_a <= "1000"; s_ma_disj_above_s_b <= "1111"; s_ma_disj_above_s_c <= "00000000";
    p_settle(clk_tb);
    p_check_slv(s_ma_disj_above_s_dout, "0000", "disjoint weights, destination above source S(4,8)x(4,8)+(8,10) -> (4,0) in=8/15/0");
    s_ma_disj_above_s_a <= "1000"; s_ma_disj_above_s_b <= "1111"; s_ma_disj_above_s_c <= "11111111";
    p_settle(clk_tb);
    p_check_slv(s_ma_disj_above_s_dout, "0000", "disjoint weights, destination above source S(4,8)x(4,8)+(8,10) -> (4,0) in=8/15/255");

    -- exactly one bit of weight overlap: U(4,4)x(4,4)+(8,8) -> (4,5)
    s_ma_overlap1_u_a <= "0000"; s_ma_overlap1_u_b <= "0101"; s_ma_overlap1_u_c <= "00000000";
    p_settle(clk_tb);
    p_check_slv(s_ma_overlap1_u_dout, "0000", "exactly one bit of weight overlap U(4,4)x(4,4)+(8,8) -> (4,5) in=0/5/0");
    s_ma_overlap1_u_a <= "0000"; s_ma_overlap1_u_b <= "0101"; s_ma_overlap1_u_c <= "11111111";
    p_settle(clk_tb);
    p_check_slv(s_ma_overlap1_u_dout, "0000", "exactly one bit of weight overlap U(4,4)x(4,4)+(8,8) -> (4,5) in=0/5/255");
    s_ma_overlap1_u_a <= "0000"; s_ma_overlap1_u_b <= "1111"; s_ma_overlap1_u_c <= "00000000";
    p_settle(clk_tb);
    p_check_slv(s_ma_overlap1_u_dout, "0000", "exactly one bit of weight overlap U(4,4)x(4,4)+(8,8) -> (4,5) in=0/15/0");
    s_ma_overlap1_u_a <= "0000"; s_ma_overlap1_u_b <= "1111"; s_ma_overlap1_u_c <= "11111111";
    p_settle(clk_tb);
    p_check_slv(s_ma_overlap1_u_dout, "0000", "exactly one bit of weight overlap U(4,4)x(4,4)+(8,8) -> (4,5) in=0/15/255");
    s_ma_overlap1_u_a <= "0011"; s_ma_overlap1_u_b <= "0101"; s_ma_overlap1_u_c <= "00000000";
    p_settle(clk_tb);
    p_check_slv(s_ma_overlap1_u_dout, "0010", "exactly one bit of weight overlap U(4,4)x(4,4)+(8,8) -> (4,5) in=3/5/0");
    s_ma_overlap1_u_a <= "0011"; s_ma_overlap1_u_b <= "0101"; s_ma_overlap1_u_c <= "11111111";
    p_settle(clk_tb);
    p_check_slv(s_ma_overlap1_u_dout, "0010", "exactly one bit of weight overlap U(4,4)x(4,4)+(8,8) -> (4,5) in=3/5/255");
    s_ma_overlap1_u_a <= "0011"; s_ma_overlap1_u_b <= "1111"; s_ma_overlap1_u_c <= "00000000";
    p_settle(clk_tb);
    p_check_slv(s_ma_overlap1_u_dout, "0110", "exactly one bit of weight overlap U(4,4)x(4,4)+(8,8) -> (4,5) in=3/15/0");
    s_ma_overlap1_u_a <= "0011"; s_ma_overlap1_u_b <= "1111"; s_ma_overlap1_u_c <= "11111111";
    p_settle(clk_tb);
    p_check_slv(s_ma_overlap1_u_dout, "0110", "exactly one bit of weight overlap U(4,4)x(4,4)+(8,8) -> (4,5) in=3/15/255");
    s_ma_overlap1_u_a <= "1111"; s_ma_overlap1_u_b <= "0101"; s_ma_overlap1_u_c <= "00000000";
    p_settle(clk_tb);
    p_check_slv(s_ma_overlap1_u_dout, "1001", "exactly one bit of weight overlap U(4,4)x(4,4)+(8,8) -> (4,5) in=15/5/0");
    s_ma_overlap1_u_a <= "1111"; s_ma_overlap1_u_b <= "0101"; s_ma_overlap1_u_c <= "11111111";
    p_settle(clk_tb);
    p_check_slv(s_ma_overlap1_u_dout, "1001", "exactly one bit of weight overlap U(4,4)x(4,4)+(8,8) -> (4,5) in=15/5/255");
    s_ma_overlap1_u_a <= "1111"; s_ma_overlap1_u_b <= "1111"; s_ma_overlap1_u_c <= "00000000";
    p_settle(clk_tb);
    p_check_slv(s_ma_overlap1_u_dout, "1100", "exactly one bit of weight overlap U(4,4)x(4,4)+(8,8) -> (4,5) in=15/15/0");
    s_ma_overlap1_u_a <= "1111"; s_ma_overlap1_u_b <= "1111"; s_ma_overlap1_u_c <= "11111111";
    p_settle(clk_tb);
    p_check_slv(s_ma_overlap1_u_dout, "1100", "exactly one bit of weight overlap U(4,4)x(4,4)+(8,8) -> (4,5) in=15/15/255");

    -- width 1 unsigned everywhere: U(1,1)x(1,1)+(1,1) -> (1,1)
    s_ma_w1_u_a <= "0"; s_ma_w1_u_b <= "0"; s_ma_w1_u_c <= "0";
    p_settle(clk_tb);
    p_check_slv(s_ma_w1_u_dout, "0", "width 1 unsigned everywhere U(1,1)x(1,1)+(1,1) -> (1,1) in=0/0/0");
    s_ma_w1_u_a <= "0"; s_ma_w1_u_b <= "0"; s_ma_w1_u_c <= "1";
    p_settle(clk_tb);
    p_check_slv(s_ma_w1_u_dout, "1", "width 1 unsigned everywhere U(1,1)x(1,1)+(1,1) -> (1,1) in=0/0/1");
    s_ma_w1_u_a <= "0"; s_ma_w1_u_b <= "1"; s_ma_w1_u_c <= "0";
    p_settle(clk_tb);
    p_check_slv(s_ma_w1_u_dout, "0", "width 1 unsigned everywhere U(1,1)x(1,1)+(1,1) -> (1,1) in=0/1/0");
    s_ma_w1_u_a <= "0"; s_ma_w1_u_b <= "1"; s_ma_w1_u_c <= "1";
    p_settle(clk_tb);
    p_check_slv(s_ma_w1_u_dout, "1", "width 1 unsigned everywhere U(1,1)x(1,1)+(1,1) -> (1,1) in=0/1/1");
    s_ma_w1_u_a <= "1"; s_ma_w1_u_b <= "0"; s_ma_w1_u_c <= "0";
    p_settle(clk_tb);
    p_check_slv(s_ma_w1_u_dout, "0", "width 1 unsigned everywhere U(1,1)x(1,1)+(1,1) -> (1,1) in=1/0/0");
    s_ma_w1_u_a <= "1"; s_ma_w1_u_b <= "0"; s_ma_w1_u_c <= "1";
    p_settle(clk_tb);
    p_check_slv(s_ma_w1_u_dout, "1", "width 1 unsigned everywhere U(1,1)x(1,1)+(1,1) -> (1,1) in=1/0/1");
    s_ma_w1_u_a <= "1"; s_ma_w1_u_b <= "1"; s_ma_w1_u_c <= "0";
    p_settle(clk_tb);
    p_check_slv(s_ma_w1_u_dout, "0", "width 1 unsigned everywhere U(1,1)x(1,1)+(1,1) -> (1,1) in=1/1/0");
    s_ma_w1_u_a <= "1"; s_ma_w1_u_b <= "1"; s_ma_w1_u_c <= "1";
    p_settle(clk_tb);
    p_check_slv(s_ma_w1_u_dout, "1", "width 1 unsigned everywhere U(1,1)x(1,1)+(1,1) -> (1,1) in=1/1/1");

    -- width 1 signed everywhere: S(1,1)x(1,1)+(1,1) -> (1,1)
    s_ma_w1_s_a <= "0"; s_ma_w1_s_b <= "0"; s_ma_w1_s_c <= "0";
    p_settle(clk_tb);
    p_check_slv(s_ma_w1_s_dout, "0", "width 1 signed everywhere S(1,1)x(1,1)+(1,1) -> (1,1) in=0/0/0");
    s_ma_w1_s_a <= "0"; s_ma_w1_s_b <= "0"; s_ma_w1_s_c <= "1";
    p_settle(clk_tb);
    p_check_slv(s_ma_w1_s_dout, "1", "width 1 signed everywhere S(1,1)x(1,1)+(1,1) -> (1,1) in=0/0/1");
    s_ma_w1_s_a <= "0"; s_ma_w1_s_b <= "1"; s_ma_w1_s_c <= "0";
    p_settle(clk_tb);
    p_check_slv(s_ma_w1_s_dout, "0", "width 1 signed everywhere S(1,1)x(1,1)+(1,1) -> (1,1) in=0/1/0");
    s_ma_w1_s_a <= "0"; s_ma_w1_s_b <= "1"; s_ma_w1_s_c <= "1";
    p_settle(clk_tb);
    p_check_slv(s_ma_w1_s_dout, "1", "width 1 signed everywhere S(1,1)x(1,1)+(1,1) -> (1,1) in=0/1/1");
    s_ma_w1_s_a <= "1"; s_ma_w1_s_b <= "0"; s_ma_w1_s_c <= "0";
    p_settle(clk_tb);
    p_check_slv(s_ma_w1_s_dout, "0", "width 1 signed everywhere S(1,1)x(1,1)+(1,1) -> (1,1) in=1/0/0");
    s_ma_w1_s_a <= "1"; s_ma_w1_s_b <= "0"; s_ma_w1_s_c <= "1";
    p_settle(clk_tb);
    p_check_slv(s_ma_w1_s_dout, "1", "width 1 signed everywhere S(1,1)x(1,1)+(1,1) -> (1,1) in=1/0/1");
    s_ma_w1_s_a <= "1"; s_ma_w1_s_b <= "1"; s_ma_w1_s_c <= "0";
    p_settle(clk_tb);
    p_check_slv(s_ma_w1_s_dout, "0", "width 1 signed everywhere S(1,1)x(1,1)+(1,1) -> (1,1) in=1/1/0");
    s_ma_w1_s_a <= "1"; s_ma_w1_s_b <= "1"; s_ma_w1_s_c <= "1";
    p_settle(clk_tb);
    p_check_slv(s_ma_w1_s_dout, "0", "width 1 signed everywhere S(1,1)x(1,1)+(1,1) -> (1,1) in=1/1/1");

    report "TEST PASSED: tb_degenerate_formats (370 checks)" severity note;
    s_done <= true;
    wait;
  end process proc_main;

end architecture a_tb;
