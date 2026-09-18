-- SPDX-License-Identifier: Apache-2.0
-- Copyright 2026 LogiMentor
--
-- Positive half of the generic-domain gate.
--
-- Instantiates every entity across the full legal cross-product of its
-- discrete-domain generics and runs past time 0, so every concurrent
-- generic-domain assertion in src/ executes at least once with a legal value.
-- NO ASSERTION MAY FIRE. A predicate that wrongly rejected a legal value would
-- otherwise leave the rest of the regression green, because the directed
-- testbenches only touch a handful of generic combinations.
--
-- Outputs are left open on purpose. The internal logic still elaborates and
-- runs, so f_lm_quantize is exercised with every legal rounding and overflow
-- mode as well.
--
-- Legal domains, taken from src/lm_math_fi_pkg.vhd:
--   representation / *_type : C_LM_UNSIGNED (1) .. C_LM_SIGNED (2)
--   round mode              : C_LM_TRUNC_BITS (0) .. C_LM_ROUND_AWAY (8)
--   overflow                : C_LM_SATURATE (1) .. C_LM_WRAP (2)
--   g_direction (add_sub)   : C_LM_ADD (0) .. C_LM_ADDSUB (2)
--   g_add_sub (mult_add)    : C_LM_ADD (0) .. C_LM_SUB (1)
--
-- The four alias constants C_LM_TRUNC, C_LM_ROUND, C_LM_ROUND_NEAREST and
-- C_LM_ROUND_INF each share a value with one of the nine rounding modes, so
-- they cannot be reached by a loop over the range. They get their own explicit
-- instances below.
--
-- Width generics are positive, so 1 is the lower bound of their domain. The
-- minimum-width block at the end covers it.

library ieee;
use ieee.std_logic_1164.all;

library lm_math_fi_lib;
use lm_math_fi_lib.lm_math_fi_pkg.all;

entity tb_legal_sweep is
end entity tb_legal_sweep;

architecture a_tb of tb_legal_sweep is
  signal clk_tb : std_logic := '0';
  signal s_ce   : std_logic := '1';
  signal s_done : boolean   := false;

  signal s_d1 : std_logic_vector(0 downto 0) := "1";
  signal s_d4 : std_logic_vector(3 downto 0) := "1011";
  signal s_d6 : std_logic_vector(5 downto 0) := "101101";
  signal s_d8 : std_logic_vector(7 downto 0) := "10110110";
begin

  proc_clk : process
  begin
    while not s_done loop
      clk_tb <= '0';
      wait for 5 ns;
      clk_tb <= '1';
      wait for 5 ns;
    end loop;
    clk_tb <= '0';
    wait;
  end process proc_clk;

  -----------------------------------------------------------------------------
  -- lm_math_fi_delay : no discrete-domain generic; sweep the depth anyway
  -----------------------------------------------------------------------------
  gen_delay : for d in 0 to 3 generate
    inst : entity lm_math_fi_lib.lm_math_fi_delay
      generic map(g_delay => d, g_data_w => 4)
      port map(clk_i => clk_tb, ce_i => s_ce, din_i => s_d4, dout_o => open);
  end generate gen_delay;

  -----------------------------------------------------------------------------
  -- lm_math_fi_format : representation x round mode x overflow x pipe depth
  -----------------------------------------------------------------------------
  gen_fmt_a : for a in C_LM_UNSIGNED to C_LM_SIGNED generate
    gen_fmt_r : for r in C_LM_TRUNC_BITS to C_LM_ROUND_AWAY generate
      gen_fmt_o : for o in C_LM_SATURATE to C_LM_WRAP generate
        gen_fmt_p : for p in 0 to 1 generate
          inst : entity lm_math_fi_lib.lm_math_fi_format
            generic map(
              g_din_w => 6, g_din_binpnt => 2, g_dout_w => 4, g_dout_binpnt => 1,
              g_pipe_stages => p, g_round_mode => r,
              g_overflow => o, g_representation => a)
            port map(clk_i => clk_tb, ce_i => s_ce, din_i => s_d6, dout_o => open);
        end generate gen_fmt_p;
      end generate gen_fmt_o;
    end generate gen_fmt_r;
  end generate gen_fmt_a;

  -----------------------------------------------------------------------------
  -- lm_math_fi_format : the four documented alias spellings must be accepted
  -----------------------------------------------------------------------------
  inst_alias_trunc : entity lm_math_fi_lib.lm_math_fi_format
    generic map(g_din_w => 6, g_din_binpnt => 2, g_dout_w => 4, g_dout_binpnt => 1,
                g_pipe_stages => 0, g_round_mode => C_LM_TRUNC,
                g_overflow => C_LM_WRAP, g_representation => C_LM_SIGNED)
    port map(clk_i => clk_tb, ce_i => s_ce, din_i => s_d6, dout_o => open);

  inst_alias_round : entity lm_math_fi_lib.lm_math_fi_format
    generic map(g_din_w => 6, g_din_binpnt => 2, g_dout_w => 4, g_dout_binpnt => 1,
                g_pipe_stages => 0, g_round_mode => C_LM_ROUND,
                g_overflow => C_LM_WRAP, g_representation => C_LM_SIGNED)
    port map(clk_i => clk_tb, ce_i => s_ce, din_i => s_d6, dout_o => open);

  inst_alias_nearest : entity lm_math_fi_lib.lm_math_fi_format
    generic map(g_din_w => 6, g_din_binpnt => 2, g_dout_w => 4, g_dout_binpnt => 1,
                g_pipe_stages => 0, g_round_mode => C_LM_ROUND_NEAREST,
                g_overflow => C_LM_WRAP, g_representation => C_LM_SIGNED)
    port map(clk_i => clk_tb, ce_i => s_ce, din_i => s_d6, dout_o => open);

  inst_alias_inf : entity lm_math_fi_lib.lm_math_fi_format
    generic map(g_din_w => 6, g_din_binpnt => 2, g_dout_w => 4, g_dout_binpnt => 1,
                g_pipe_stages => 0, g_round_mode => C_LM_ROUND_INF,
                g_overflow => C_LM_WRAP, g_representation => C_LM_SIGNED)
    port map(clk_i => clk_tb, ce_i => s_ce, din_i => s_d6, dout_o => open);

  -----------------------------------------------------------------------------
  -- lm_math_fi_add_sub : direction x representation x round mode x input depth,
  -- across BOTH output branches (g_dout_w below and at/above C_RES_W)
  -----------------------------------------------------------------------------
  gen_as_d : for d in C_LM_ADD to C_LM_ADDSUB generate
    gen_as_a : for a in C_LM_UNSIGNED to C_LM_SIGNED generate
      gen_as_r : for r in C_LM_TRUNC_BITS to C_LM_ROUND_AWAY generate
        gen_as_pi : for pi in 0 to 1 generate
          -- narrow output: routes through the internal lm_math_fi_format
          inst_narrow : entity lm_math_fi_lib.lm_math_fi_add_sub
            generic map(
              g_direction => d, g_representation => a,
              g_pipeline_input => pi, g_pipeline_output => 1,
              g_din1_w => 4, g_din1_binpnt => 1, g_din2_w => 4, g_din2_binpnt => 1,
              g_dout_w => 3, g_dout_binpnt => 0, g_round_mode => r)
            port map(clk_i => clk_tb, ce_i => s_ce, sel_add_i => '1',
                     din1_i => s_d4, din2_i => s_d4, dout_o => open);

          -- wide output: routes through the internal lm_math_fi_delay
          inst_wide : entity lm_math_fi_lib.lm_math_fi_add_sub
            generic map(
              g_direction => d, g_representation => a,
              g_pipeline_input => pi, g_pipeline_output => 0,
              g_din1_w => 4, g_din1_binpnt => 1, g_din2_w => 4, g_din2_binpnt => 1,
              g_dout_w => 6, g_dout_binpnt => 1, g_round_mode => r)
            port map(clk_i => clk_tb, ce_i => s_ce, sel_add_i => '0',
                     din1_i => s_d4, din2_i => s_d4, dout_o => open);
        end generate gen_as_pi;
      end generate gen_as_r;
    end generate gen_as_a;
  end generate gen_as_d;

  -----------------------------------------------------------------------------
  -- lm_math_fi_mult : all three type generics x round mode x overflow
  -----------------------------------------------------------------------------
  gen_m_ta : for ta in C_LM_UNSIGNED to C_LM_SIGNED generate
    gen_m_tb : for tb in C_LM_UNSIGNED to C_LM_SIGNED generate
      gen_m_to : for tout in C_LM_UNSIGNED to C_LM_SIGNED generate
        gen_m_r : for r in C_LM_TRUNC_BITS to C_LM_ROUND_AWAY generate
          gen_m_o : for o in C_LM_SATURATE to C_LM_WRAP generate
            inst : entity lm_math_fi_lib.lm_math_fi_mult
              generic map(
                g_din_a_w => 4, g_din_a_binpnt => 1, g_din_b_w => 4, g_din_b_binpnt => 1,
                g_dout_w => 6, g_dout_binpnt => 1, g_round_mode => r,
                g_din_a_type => ta, g_din_b_type => tb, g_dout_type => tout,
                g_overflow => o, g_pipe_stages => 0)
              port map(clk_i => clk_tb, ce_i => s_ce,
                       din1_i => s_d4, din2_i => s_d4, dout_o => open);
          end generate gen_m_o;
        end generate gen_m_r;
      end generate gen_m_to;
    end generate gen_m_tb;
  end generate gen_m_ta;

  -----------------------------------------------------------------------------
  -- lm_math_fi_mult_add : add/sub x representation x round mode x overflow
  -----------------------------------------------------------------------------
  gen_ma_s : for s in C_LM_ADD to C_LM_SUB generate
    gen_ma_a : for a in C_LM_UNSIGNED to C_LM_SIGNED generate
      gen_ma_r : for r in C_LM_TRUNC_BITS to C_LM_ROUND_AWAY generate
        gen_ma_o : for o in C_LM_SATURATE to C_LM_WRAP generate
          inst : entity lm_math_fi_lib.lm_math_fi_mult_add
            generic map(
              g_din_a_w => 4, g_din_a_binpnt => 1, g_din_b_w => 4, g_din_b_binpnt => 1,
              g_din_c_w => 8, g_din_c_binpnt => 2, g_dout_w => 6, g_dout_binpnt => 1,
              g_add_sub => s, g_round_mode => r,
              g_representation => a, g_overflow => o, g_pipe_stages => 1)
            port map(clk_i => clk_tb, ce_i => s_ce,
                     din1_i => s_d4, din2_i => s_d4, din3_i => s_d8, dout_o => open);
        end generate gen_ma_o;
      end generate gen_ma_r;
    end generate gen_ma_a;
  end generate gen_ma_s;

  -----------------------------------------------------------------------------
  -- Minimum widths. Width generics are positive, so 1 is the lower bound of
  -- their domain and must elaborate and run like any other legal value.
  -----------------------------------------------------------------------------
  inst_min_delay : entity lm_math_fi_lib.lm_math_fi_delay
    generic map(g_delay => 1, g_data_w => 1)
    port map(clk_i => clk_tb, ce_i => s_ce, din_i => s_d1, dout_o => open);

  gen_min_fmt_a : for a in C_LM_UNSIGNED to C_LM_SIGNED generate
    gen_min_fmt_r : for r in C_LM_TRUNC_BITS to C_LM_ROUND_AWAY generate
      gen_min_fmt_o : for o in C_LM_SATURATE to C_LM_WRAP generate
        inst : entity lm_math_fi_lib.lm_math_fi_format
          generic map(
            g_din_w => 1, g_din_binpnt => 0, g_dout_w => 1, g_dout_binpnt => 0,
            g_pipe_stages => 0, g_round_mode => r,
            g_overflow => o, g_representation => a)
          port map(clk_i => clk_tb, ce_i => s_ce, din_i => s_d1, dout_o => open);
      end generate gen_min_fmt_o;
    end generate gen_min_fmt_r;
  end generate gen_min_fmt_a;

  gen_min_as : for a in C_LM_UNSIGNED to C_LM_SIGNED generate
    inst_narrow : entity lm_math_fi_lib.lm_math_fi_add_sub
      generic map(
        g_direction => C_LM_ADD, g_representation => a,
        g_pipeline_input => 1, g_pipeline_output => 1,
        g_din1_w => 1, g_din1_binpnt => 0, g_din2_w => 1, g_din2_binpnt => 0,
        g_dout_w => 1, g_dout_binpnt => 0, g_round_mode => C_LM_TRUNC_BITS)
      port map(clk_i => clk_tb, ce_i => s_ce, sel_add_i => '1',
               din1_i => s_d1, din2_i => s_d1, dout_o => open);

    inst_wide : entity lm_math_fi_lib.lm_math_fi_add_sub
      generic map(
        g_direction => C_LM_ADD, g_representation => a,
        g_pipeline_input => 0, g_pipeline_output => 0,
        g_din1_w => 1, g_din1_binpnt => 0, g_din2_w => 1, g_din2_binpnt => 0,
        g_dout_w => 2, g_dout_binpnt => 0, g_round_mode => C_LM_TRUNC_BITS)
      port map(clk_i => clk_tb, ce_i => s_ce, sel_add_i => '1',
               din1_i => s_d1, din2_i => s_d1, dout_o => open);
  end generate gen_min_as;

  gen_min_m_ta : for ta in C_LM_UNSIGNED to C_LM_SIGNED generate
    gen_min_m_tb : for tb in C_LM_UNSIGNED to C_LM_SIGNED generate
      gen_min_m_to : for tout in C_LM_UNSIGNED to C_LM_SIGNED generate
        inst : entity lm_math_fi_lib.lm_math_fi_mult
          generic map(
            g_din_a_w => 1, g_din_a_binpnt => 0, g_din_b_w => 1, g_din_b_binpnt => 0,
            g_dout_w => 1, g_dout_binpnt => 0, g_round_mode => C_LM_TRUNC_BITS,
            g_din_a_type => ta, g_din_b_type => tb, g_dout_type => tout,
            g_overflow => C_LM_SATURATE, g_pipe_stages => 0)
          port map(clk_i => clk_tb, ce_i => s_ce,
                   din1_i => s_d1, din2_i => s_d1, dout_o => open);
      end generate gen_min_m_to;
    end generate gen_min_m_tb;
  end generate gen_min_m_ta;

  gen_min_ma_s : for s in C_LM_ADD to C_LM_SUB generate
    gen_min_ma_a : for a in C_LM_UNSIGNED to C_LM_SIGNED generate
      inst : entity lm_math_fi_lib.lm_math_fi_mult_add
        generic map(
          g_din_a_w => 1, g_din_a_binpnt => 0, g_din_b_w => 1, g_din_b_binpnt => 0,
          g_din_c_w => 1, g_din_c_binpnt => 0, g_dout_w => 1, g_dout_binpnt => 0,
          g_add_sub => s, g_round_mode => C_LM_TRUNC_BITS,
          g_representation => a, g_overflow => C_LM_SATURATE, g_pipe_stages => 0)
        port map(clk_i => clk_tb, ce_i => s_ce,
                 din1_i => s_d1, din2_i => s_d1, din3_i => s_d1, dout_o => open);
    end generate gen_min_ma_a;
  end generate gen_min_ma_s;

  proc_main : process
  begin
    -- Exercise the clock-enable path too, so the pipelined instances toggle.
    wait for 100 ns;
    s_ce <= '0';
    wait for 50 ns;
    s_ce <= '1';
    wait for 100 ns;
    report "TEST PASSED: tb_legal_sweep (no generic-domain assertion fired)" severity note;
    s_done <= true;
    wait;
  end process proc_main;

end architecture a_tb;
