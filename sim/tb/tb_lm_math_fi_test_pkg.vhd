-- SPDX-License-Identifier: Apache-2.0
-- Copyright 2026 LogiMentor

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package tb_lm_math_fi_test_pkg is
  constant C_TB_CLK_PERIOD : time := 10 ns;

  function f_slv_u(value : natural; width : natural) return std_logic_vector;
  function f_slv_s(value : integer; width : natural) return std_logic_vector;

  procedure p_check_int(actual : integer; expected : integer; msg : string);
  procedure p_check_slv(actual : std_logic_vector; expected : std_logic_vector; msg : string);
  procedure p_wait_cycles(signal clk : in std_logic; cycles : natural);
end package tb_lm_math_fi_test_pkg;

package body tb_lm_math_fi_test_pkg is

  function f_slv_u(value : natural; width : natural) return std_logic_vector is
  begin
    return std_logic_vector(to_unsigned(value, width));
  end;

  function f_slv_s(value : integer; width : natural) return std_logic_vector is
  begin
    return std_logic_vector(to_signed(value, width));
  end;

  procedure p_check_int(actual : integer; expected : integer; msg : string) is
  begin
    assert actual = expected
      report msg & " expected=" & integer'image(expected) & " actual=" & integer'image(actual)
      severity failure;
  end procedure;

  procedure p_check_slv(actual : std_logic_vector; expected : std_logic_vector; msg : string) is
  begin
    assert actual'length = expected'length
      report msg & " length mismatch expected=" & integer'image(expected'length) & " actual=" & integer'image(actual'length)
      severity failure;
    assert actual = expected
      report msg & " expected=0x" & to_hstring(expected) & " actual=0x" & to_hstring(actual)
      severity failure;
  end procedure;

  procedure p_wait_cycles(signal clk : in std_logic; cycles : natural) is
  begin
    for i in 1 to cycles loop
      wait until rising_edge(clk);
    end loop;
    wait for 1 ns;
  end procedure;

end package body tb_lm_math_fi_test_pkg;
