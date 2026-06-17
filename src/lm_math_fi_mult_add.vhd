-- SPDX-License-Identifier: Apache-2.0
-- Copyright 2026 LogiMentor
--
-- Module Name : lm_math_fi_mult_add
-- Description : Fixed-point multiply-add/subtract block.
-- Reset       : No reset port; outputs are valid after the pipeline is filled.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library lm_math_fi_lib;
use lm_math_fi_lib.lm_math_fi_pkg.all;

entity lm_math_fi_mult_add is
  generic(
    g_din_a_w          : natural   := 24;   -- Input A width
    g_din_a_binpnt     : natural   := 15;   -- Input A binary point
    g_din_b_w          : natural   := 18;   -- Input B width
    g_din_b_binpnt     : natural   := 12;   -- Input B binary point
    g_din_c_w          : natural   := 46;   -- Input C width
    g_din_c_binpnt     : natural   := 27;   -- Input C binary point
    g_dout_w           : natural   := 46;   -- Output width
    g_dout_binpnt      : natural   := 27;   -- Output binary point
    g_add_sub          : natural   := C_LM_ADD;    -- C_LM_ADD or C_LM_SUB
    g_round_mode       : integer   := C_LM_ROUND_EVEN;   -- Output rounding mode
    g_representation   : integer   := C_LM_SIGNED;  -- Numeric representation
    g_overflow         : natural   := C_LM_WRAP;    -- Overflow style: C_LM_SATURATE or C_LM_WRAP
    -- Extra stages after the product/addend register; total latency is g_pipe_stages + 1 clocks
    g_pipe_stages      : natural   := 3
    );
  port(
    clk_i  : in  std_logic;             -- Clock
    ce_i   : in  std_logic := '1';      -- Clock enable
    din1_i : in  std_logic_vector(g_din_a_w - 1 downto 0);  -- Input A
    din2_i : in  std_logic_vector(g_din_b_w - 1 downto 0);  -- Input B
    din3_i : in  std_logic_vector(g_din_c_w - 1 downto 0);  -- Input C
    dout_o : out std_logic_vector(g_dout_w - 1 downto 0)    -- Result
    );

end lm_math_fi_mult_add;

architecture a_rtl of lm_math_fi_mult_add is

  constant C_MULT_BINPNT  : natural := g_din_a_binpnt + g_din_b_binpnt;
  constant C_MULT_WIDTH   : natural := g_din_a_w + g_din_b_w;
  constant C_SUM_BINPNT   : natural := f_lm_max(C_MULT_BINPNT, g_din_c_binpnt);
  constant C_MULT_INT_W   : natural := C_MULT_WIDTH - C_MULT_BINPNT;
  constant C_ADDEND_INT_W : natural := g_din_c_w - g_din_c_binpnt;
  constant C_SUM_W        : natural := f_lm_max(C_MULT_INT_W, C_ADDEND_INT_W) + C_SUM_BINPNT + 1;

  type t_pipe is array (0 to g_pipe_stages) of std_logic_vector(C_SUM_W - 1 downto 0);

  signal s_prod           : std_logic_vector(C_MULT_WIDTH - 1 downto 0);
  signal s_din3           : std_logic_vector(g_din_c_w - 1 downto 0);
  signal s_sum            : std_logic_vector(C_SUM_W - 1 downto 0);
  signal s_pipe_reg       : t_pipe;
begin

  proc_mult : process(clk_i)
  begin
    if rising_edge(clk_i) then
      if ce_i = '1' then
        if g_representation = C_LM_SIGNED then
          s_prod <= std_logic_vector(signed(din1_i) * signed(din2_i)) ;
        else
          s_prod <= std_logic_vector(unsigned(din1_i) * unsigned(din2_i));
        end if;

        s_din3 <= din3_i;
      end if;
    end if;
  end process proc_mult;

  gen_add : if g_add_sub = C_LM_ADD generate
    gen_signed_sum : if g_representation = C_LM_SIGNED generate
      s_sum <= std_logic_vector(
        signed(f_lm_quantize(s_prod,
                             C_SUM_W, C_SUM_BINPNT, g_representation,
                             C_MULT_WIDTH, C_MULT_BINPNT, g_representation,
                             C_LM_TRUNC_BITS, C_LM_WRAP))
        + signed(f_lm_quantize(s_din3,
                               C_SUM_W, C_SUM_BINPNT, g_representation,
                               g_din_c_w, g_din_c_binpnt, g_representation,
                               C_LM_TRUNC_BITS, C_LM_WRAP))
      );
    end generate gen_signed_sum;
    gen_unsigned_sum : if g_representation = C_LM_UNSIGNED generate
      s_sum <= std_logic_vector(
        unsigned(f_lm_quantize(s_prod,
                               C_SUM_W, C_SUM_BINPNT, g_representation,
                               C_MULT_WIDTH, C_MULT_BINPNT, g_representation,
                               C_LM_TRUNC_BITS, C_LM_WRAP))
        + unsigned(f_lm_quantize(s_din3,
                                 C_SUM_W, C_SUM_BINPNT, g_representation,
                                 g_din_c_w, g_din_c_binpnt, g_representation,
                                 C_LM_TRUNC_BITS, C_LM_WRAP))
      );
    end generate gen_unsigned_sum;
  end generate gen_add;

  gen_sub : if g_add_sub = C_LM_SUB generate
    gen_signed_sub : if g_representation = C_LM_SIGNED generate
      s_sum <= std_logic_vector(
        signed(f_lm_quantize(s_prod,
                             C_SUM_W, C_SUM_BINPNT, g_representation,
                             C_MULT_WIDTH, C_MULT_BINPNT, g_representation,
                             C_LM_TRUNC_BITS, C_LM_WRAP))
        - signed(f_lm_quantize(s_din3,
                               C_SUM_W, C_SUM_BINPNT, g_representation,
                               g_din_c_w, g_din_c_binpnt, g_representation,
                               C_LM_TRUNC_BITS, C_LM_WRAP))
      );
    end generate gen_signed_sub;
    gen_unsigned_sub : if g_representation = C_LM_UNSIGNED generate
      s_sum <= std_logic_vector(
        unsigned(f_lm_quantize(s_prod,
                               C_SUM_W, C_SUM_BINPNT, g_representation,
                               C_MULT_WIDTH, C_MULT_BINPNT, g_representation,
                               C_LM_TRUNC_BITS, C_LM_WRAP))
        - unsigned(f_lm_quantize(s_din3,
                                 C_SUM_W, C_SUM_BINPNT, g_representation,
                                 g_din_c_w, g_din_c_binpnt, g_representation,
                                 C_LM_TRUNC_BITS, C_LM_WRAP))
      );
    end generate gen_unsigned_sub;
  end generate gen_sub;

  s_pipe_reg(0) <= s_sum;
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
                           g_dout_w, g_dout_binpnt, g_representation,
                           C_SUM_W, C_SUM_BINPNT, g_representation,
                           g_round_mode, g_overflow);

end a_rtl;
