-- SPDX-License-Identifier: Apache-2.0
-- Copyright 2026 LogiMentor
--
-- Module Name : lm_math_fi_delay
-- Description : Fixed delay line for std_logic_vector signals.
-- Reset       : No reset port; outputs are valid after the pipeline is filled.

library ieee;
use ieee.std_logic_1164.all;

entity lm_math_fi_delay is
  generic(
    g_delay  : natural := 1;
    g_data_w : natural := 1
    );
  port(
    clk_i  : in  std_logic;
    ce_i   : in  std_logic := '1';
    din_i  : in  std_logic_vector(g_data_w - 1 downto 0);
    dout_o : out std_logic_vector(g_data_w - 1 downto 0)
    );
end lm_math_fi_delay;

architecture a_rtl of lm_math_fi_delay is
begin

  gen_no_delay : if g_delay = 0 generate
    dout_o <= din_i;
  end generate gen_no_delay;

  gen_unit_delay : if g_delay = 1 generate
    proc_unit_delay : process(clk_i)
    begin
      if rising_edge(clk_i) then
        if ce_i = '1' then
          dout_o <= din_i;
        end if;
      end if;
    end process proc_unit_delay;
  end generate gen_unit_delay;

  gen_delay : if g_delay > 1 generate
    type t_delay_line is array (0 to g_delay - 1) of std_logic_vector(g_data_w - 1 downto 0);
    signal s_delay_line : t_delay_line;
  begin
    proc_delay : process(clk_i)
    begin
      if rising_edge(clk_i) then
        if ce_i = '1' then
          s_delay_line(0) <= din_i;
          for i in 1 to g_delay - 1 loop
            s_delay_line(i) <= s_delay_line(i - 1);
          end loop;
        end if;
      end if;
    end process proc_delay;

    dout_o <= s_delay_line(g_delay - 1);
  end generate gen_delay;

end architecture a_rtl;
