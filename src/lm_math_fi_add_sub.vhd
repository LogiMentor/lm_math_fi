-- SPDX-License-Identifier: Apache-2.0
-- Copyright 2026 LogiMentor
--
-- Module Name : lm_math_fi_add_sub
-- Description : Fixed-point adder/subtractor.
-- Reset       : No reset port; outputs are valid after the pipeline is filled.

library ieee;
use ieee.std_logic_1164.all;
library lm_math_fi_lib;
use lm_math_fi_lib.lm_math_fi_pkg.all;

entity lm_math_fi_add_sub is
  generic(
    -- C_LM_ADD, C_LM_SUB, or C_LM_ADDSUB with sel_add_i
    g_direction       : integer   := C_LM_ADD;
    -- Numeric representation
    g_representation  : natural   := C_LM_SIGNED;
    -- Optional input register stage
    g_pipeline_input  : natural   := 0;
    -- Number of output register stages
    g_pipeline_output : natural   := 1;
    -- Input 1 width
    g_din1_w          : natural   := 8;
    -- Input 1 binary point
    g_din1_binpnt     : natural   := 2;
    -- Input 2 width
    g_din2_w          : natural   := 8;
    -- Input 2 binary point
    g_din2_binpnt     : natural   := 2;
    -- Output width
    g_dout_w          : natural   := 9;
    -- Output binary point
    g_dout_binpnt     : natural   := 2;
    -- Output rounding mode
    g_round_mode      : natural   := C_LM_TRUNC_BITS
    );
  port(
    -- Clock
    clk_i     : in  std_logic;
    -- Clock enable
    ce_i      : in  std_logic := '1';
    -- Dynamic selector used when g_direction = C_LM_ADDSUB
    sel_add_i : in  std_logic := '1';
    -- Input 1
    din1_i    : in  std_logic_vector(g_din1_w - 1 downto 0);
    -- Input 2
    din2_i    : in  std_logic_vector(g_din2_w - 1 downto 0);
    -- Result
    dout_o    : out std_logic_vector(g_dout_w - 1 downto 0)
    );
end lm_math_fi_add_sub;

-------------------------------------------------------------------------------
-- ARCHITECTURE
-------------------------------------------------------------------------------
architecture a_rtl of lm_math_fi_add_sub is

  constant C_RES_BINPNT : natural := f_lm_max(g_din1_binpnt, g_din2_binpnt);
  constant C_RES_W      : natural := f_lm_max(g_din1_w - g_din1_binpnt, g_din2_w - g_din2_binpnt) + C_RES_BINPNT + 1;

  signal s_din1_p       : std_logic_vector(din1_i'range);
  signal s_din2_p       : std_logic_vector(din2_i'range);
  signal s_in_add       : std_logic;
  signal s_sel_add_i_p  : std_logic;
  signal s_din1_tmp     : std_logic_vector(C_RES_W - 1 downto 0);
  signal s_din2_tmp     : std_logic_vector(C_RES_W - 1 downto 0);
  signal s_result_inf_p : std_logic_vector(C_RES_W - 1 downto 0);
  signal s_result_tmp   : std_logic_vector(C_RES_W - 1 downto 0);

begin

  s_in_add <= '1' when g_direction = C_LM_ADD or (g_direction = C_LM_ADDSUB and sel_add_i = '1') else '0';

  gen_no_input_reg : if g_pipeline_input = 0 generate
    s_din1_p      <= din1_i;
    s_din2_p      <= din2_i;
    s_sel_add_i_p <= s_in_add;
  end generate gen_no_input_reg;

  gen_input_reg : if g_pipeline_input > 0 generate
    proc_reg : process(clk_i)
    begin
      if rising_edge(clk_i) then
        if ce_i = '1' then
          s_din1_p      <= din1_i;
          s_din2_p      <= din2_i;
          s_sel_add_i_p <= s_in_add;
        end if;
      end if;
    end process proc_reg;
  end generate gen_input_reg;

  s_din1_tmp <= f_lm_quantize(s_din1_p,
                               C_RES_W, C_RES_BINPNT, g_representation,
                               g_din1_w, g_din1_binpnt, g_representation,
                               g_round_mode, C_LM_WRAP);

  s_din2_tmp <= f_lm_quantize(s_din2_p,
                               C_RES_W, C_RES_BINPNT, g_representation,
                               g_din2_w, g_din2_binpnt, g_representation,
                               g_round_mode, C_LM_WRAP);

  gen_signed : if g_representation = C_LM_SIGNED generate
    s_result_tmp <= f_lm_add_sig(s_din1_tmp, s_din2_tmp, C_RES_W) when s_sel_add_i_p = '1'
    else f_lm_sub_sig(s_din1_tmp, s_din2_tmp, C_RES_W);
  end generate gen_signed;
  gen_unsigned : if g_representation = C_LM_UNSIGNED generate
    s_result_tmp <= f_lm_add_uns(s_din1_tmp, s_din2_tmp, C_RES_W) when s_sel_add_i_p = '1'
    else f_lm_sub_uns(s_din1_tmp, s_din2_tmp, C_RES_W);
  end generate gen_unsigned;

  gen_pipe_format : if g_dout_w < C_RES_W generate
    inst_format_result : entity lm_math_fi_lib.lm_math_fi_format
      generic map(
        g_din_w          => C_RES_W,
        g_din_binpnt     => C_RES_BINPNT,
        g_dout_w         => g_dout_w,
        g_pipe_stages    => g_pipeline_output,
        g_dout_binpnt    => g_dout_binpnt,
        g_round_mode     => g_round_mode,
        g_overflow       => C_LM_WRAP,
        g_representation => g_representation
      )
      port map(
        clk_i  => clk_i,
        ce_i   => ce_i,
        din_i  => s_result_tmp,
        dout_o => dout_o
      );
  end generate gen_pipe_format;

  gen_format_pipe : if g_dout_w >= C_RES_W generate
    inst_out_format : entity lm_math_fi_lib.lm_math_fi_delay
      generic map(
        g_delay  => g_pipeline_output,
        g_data_w => C_RES_W
      )
      port map(
        clk_i  => clk_i,
        ce_i   => ce_i,
        din_i  => s_result_tmp,
        dout_o => s_result_inf_p
      );

    dout_o <= f_lm_quantize(s_result_inf_p,
                             g_dout_w, g_dout_binpnt, g_representation,
                             C_RES_W, C_RES_BINPNT, g_representation,
                             g_round_mode, C_LM_WRAP);
  end generate gen_format_pipe;

end a_rtl;
