-- SPDX-License-Identifier: Apache-2.0
-- Copyright 2026 LogiMentor
--
-- Module Name : lm_math_fi_mult
-- Description : Fixed-point multiplier.
-- Reset       : No reset port; outputs are valid after the pipeline is filled.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library lm_math_fi_lib;
use lm_math_fi_lib.lm_math_fi_pkg.all;

entity lm_math_fi_mult is
  generic(
    g_din_a_w      : natural   := 24;   -- Input A width
    g_din_a_binpnt : natural   := 0;    -- Input A binary point
    g_din_b_w      : natural   := 24;   -- Input B width
    g_din_b_binpnt : natural   := 0;    -- Input B binary point
    g_dout_w       : natural   := 48;   -- Output width
    g_dout_binpnt  : natural   := 0;    -- Output binary point
    g_round_mode   : integer   := C_LM_TRUNC_BITS;   -- Output rounding mode
    g_din_a_type   : integer   := C_LM_SIGNED;  -- Input A representation
    g_din_b_type   : integer   := C_LM_SIGNED;  -- Input B representation
    g_dout_type    : integer   := C_LM_SIGNED;  -- Output representation
    g_overflow     : natural   := C_LM_WRAP;    -- Overflow style: C_LM_SATURATE or C_LM_WRAP
    -- Extra stages after the product register; total latency is g_pipe_stages + 1 clocks
    g_pipe_stages  : integer   := 3
    );
  port(
    clk_i  : in  std_logic;             -- Clock
    ce_i   : in  std_logic := '1';      -- Clock enable
    din1_i : in  std_logic_vector(g_din_a_w - 1 downto 0);  -- Input A
    din2_i : in  std_logic_vector(g_din_b_w - 1 downto 0);  -- Input B
    dout_o : out std_logic_vector(g_dout_w - 1 downto 0)    -- Result
    );

end lm_math_fi_mult;

architecture a_rtl of lm_math_fi_mult is

  constant C_MULT_WIDTH  : natural := g_din_a_w + g_din_b_w;

  type t_pipe is array (0 to g_pipe_stages) of std_logic_vector(C_MULT_WIDTH - 1 downto 0);

  signal s_pipe_reg      : t_pipe;
  signal s_dout_reg      : std_logic_vector(C_MULT_WIDTH - 1 downto 0);
  signal s_prod_type     : integer range C_LM_UNSIGNED to C_LM_SIGNED;

begin

  s_prod_type <= C_LM_UNSIGNED when (g_din_a_type = C_LM_UNSIGNED and g_din_b_type = C_LM_UNSIGNED)
                 else C_LM_SIGNED;

  proc_mult : process(clk_i)
    variable v_sig_prod   : signed(C_MULT_WIDTH - 1 downto 0);
    variable v_uns_prod   : unsigned(C_MULT_WIDTH - 1 downto 0);
    variable v_mixed_prod : signed(C_MULT_WIDTH + 1 downto 0);
  begin
    if rising_edge(clk_i) then
      if ce_i = '1' then
        if g_din_a_type = C_LM_SIGNED and g_din_b_type = C_LM_SIGNED then
          v_sig_prod := signed(din1_i) * signed(din2_i);
          s_dout_reg <= std_logic_vector(v_sig_prod);
        elsif g_din_a_type = C_LM_SIGNED and g_din_b_type = C_LM_UNSIGNED then
          v_mixed_prod := resize(signed(din1_i), g_din_a_w + 1) * signed('0' & din2_i);
          s_dout_reg   <= std_logic_vector(resize(v_mixed_prod, C_MULT_WIDTH));
        elsif g_din_a_type = C_LM_UNSIGNED and g_din_b_type = C_LM_SIGNED then
          v_mixed_prod := signed('0' & din1_i) * resize(signed(din2_i), g_din_b_w + 1);
          s_dout_reg   <= std_logic_vector(resize(v_mixed_prod, C_MULT_WIDTH));
        else
          v_uns_prod := unsigned(din1_i) * unsigned(din2_i);
          s_dout_reg <= std_logic_vector(v_uns_prod);
        end if;
      end if;
    end if;
  end process proc_mult;

  s_pipe_reg(0) <= s_dout_reg;
  gen_pipe_regs : for i in 1 to g_pipe_stages generate
    proc_pipe : process(clk_i)
    begin
      if rising_edge(clk_i) then
        if ce_i = '1' then
          s_pipe_reg(i) <= s_pipe_reg(i - 1);
        end if;
      end if;
    end process proc_pipe;
  end generate gen_pipe_regs;

  dout_o <= f_lm_quantize(s_pipe_reg(g_pipe_stages),
                           g_dout_w, g_dout_binpnt, g_dout_type,
                           C_MULT_WIDTH, g_din_a_binpnt + g_din_b_binpnt, s_prod_type,
                           g_round_mode, g_overflow);

end a_rtl;
