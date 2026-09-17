-- SPDX-License-Identifier: Apache-2.0
-- Copyright 2026 LogiMentor
--
-- Module Name : lm_math_fi_format
-- Description : Fixed-point format conversion block.
-- Reset       : No reset port; outputs are valid after the pipeline is filled.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library lm_math_fi_lib;
use lm_math_fi_lib.lm_math_fi_pkg.all;

entity lm_math_fi_format is
  generic(
    -- Input width
    g_din_w          : natural := 18;
    -- Input binary point
    g_din_binpnt     : natural := 17;
    -- Output width
    g_dout_w         : natural := 18;
    -- Output binary point
    g_dout_binpnt    : natural := 17;
    -- Number of output register stages
    g_pipe_stages    : natural   := 1;
    -- Output rounding mode
    g_round_mode     : natural   := C_LM_ROUND_EVEN;
    -- Overflow style: C_LM_SATURATE or C_LM_WRAP
    g_overflow       : natural   := C_LM_SATURATE;
    -- Numeric representation
    g_representation : natural   := C_LM_SIGNED
    );
  port(
    -- Clock
    clk_i  : in  std_logic;
    -- Clock enable
    ce_i   : in  std_logic := '1';
    -- Input
    din_i  : in  std_logic_vector(g_din_w - 1 downto 0);
    -- Result
    dout_o : out std_logic_vector(g_dout_w - 1 downto 0)
    );
end lm_math_fi_format;

architecture a_rtl of lm_math_fi_format is
  signal s_dout : std_logic_vector(g_dout_w - 1 downto 0);

begin

  -----------------------------------------------------------------------------
  -- Generic-domain checks
  --
  -- Every condition below depends on generics only, so each is decided once
  -- when the instance starts and never re-evaluated on a clock edge. A failure
  -- here means the generic map is wrong, not that the data was wrong.
  -----------------------------------------------------------------------------
  assert f_lm_valid_representation(g_representation)
    report "lm_math_fi_format: generic g_representation = " & integer'image(g_representation)
         & " is not a supported value."
         & " Set g_representation to " & f_lm_representation_values & "."
    severity failure;

  assert f_lm_valid_round_mode(g_round_mode)
    report "lm_math_fi_format: generic g_round_mode = " & integer'image(g_round_mode)
         & " is not a supported value."
         & " Set g_round_mode to one of " & f_lm_round_mode_values & "."
    severity failure;

  assert f_lm_valid_overflow(g_overflow)
    report "lm_math_fi_format: generic g_overflow = " & integer'image(g_overflow)
         & " is not a supported value."
         & " Set g_overflow to " & f_lm_overflow_values & "."
    severity failure;

  s_dout <= f_lm_quantize(din_i,
                           g_dout_w, g_dout_binpnt, g_representation,
                           g_din_w, g_din_binpnt, g_representation,
                           g_round_mode, g_overflow);


  gen_pipe : if g_pipe_stages > 0 generate
    inst_output_pipe : entity lm_math_fi_lib.lm_math_fi_delay
    generic map(
      g_delay   => g_pipe_stages,
      g_data_w  => g_dout_w
      )
    port map(
      clk_i  => clk_i,
      ce_i   => ce_i,
      din_i  => s_dout,
      dout_o => dout_o
      );
  end generate gen_pipe;

  gen_no_pipe : if g_pipe_stages = 0 generate
    dout_o <= s_dout;
  end generate gen_no_pipe;

end a_rtl;
