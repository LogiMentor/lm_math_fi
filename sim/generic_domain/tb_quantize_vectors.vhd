-- SPDX-License-Identifier: Apache-2.0
-- Copyright 2026 LogiMentor
--
-- Replays f_lm_quantize_vectors.txt against the current lm_math_fi_pkg.
--
-- The committed vectors pin the arithmetic of f_lm_quantize across the format
-- domain, including the degenerate binary points: equal to the width, above the
-- width, bit weights disjoint in either direction, one bit of overlap, and
-- width 1. A generic-domain check that wrongly rejected a legal value, or an
-- edit that changed a result for a legal configuration, fails here. See the
-- header of the vector file for how the values were produced and when it is
-- legitimate to regenerate them.
--
-- Each vector carries its own geometry, so one file covers many formats.
--
-- The runner copies the vector file next to the work library before running, so
-- the default file name below is resolved relative to the simulation directory.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

library lm_math_fi_lib;
use lm_math_fi_lib.lm_math_fi_pkg.all;

entity tb_quantize_vectors is
  generic(
    g_vector_file : string := "f_lm_quantize_vectors.txt"
    );
end entity tb_quantize_vectors;

architecture a_tb of tb_quantize_vectors is
begin

  proc_main : process
    -- Widest format this testbench supports. Every vector's widths are checked
    -- against it, so a wider vector fails loudly instead of being truncated.
    constant C_MAX_W : integer := 32;

    file     f_vec      : text;
    variable v_stat     : file_open_status;
    variable v_line     : line;
    variable v_ok       : boolean;

    variable v_old_w     : integer;
    variable v_old_bp    : integer;
    variable v_old_arith : integer;
    variable v_new_w     : integer;
    variable v_new_bp    : integer;
    variable v_new_arith : integer;
    variable v_round     : integer;
    variable v_overflow  : integer;
    variable v_value     : integer;
    variable v_expected  : integer;

    -- Sized to the maximum; only the low v_old_w / v_new_w bits are ever used,
    -- because f_lm_quantize takes unconstrained vectors and is handed a slice.
    variable v_in  : std_logic_vector(C_MAX_W - 1 downto 0) := (others => '0');
    variable v_exp : std_logic_vector(C_MAX_W - 1 downto 0) := (others => '0');
    variable v_act : std_logic_vector(C_MAX_W - 1 downto 0) := (others => '0');

    variable v_checked  : integer := 0;
    variable v_mismatch : integer := 0;

    procedure read_field(variable l : inout line; variable v : out integer;
                         constant what : string) is
      variable v_got : boolean;
    begin
      read(l, v, v_got);
      assert v_got
        report "tb_quantize_vectors: malformed vector line, could not read " & what
        severity failure;
    end procedure;
  begin
    file_open(v_stat, f_vec, g_vector_file, read_mode);
    assert v_stat = open_ok
      report "tb_quantize_vectors: cannot open vector file '" & g_vector_file & "'"
      severity failure;

    while not endfile(f_vec) loop
      readline(f_vec, v_line);

      -- Skip blank lines and comments.
      if v_line'length = 0 then
        next;
      end if;
      if v_line(v_line'left) = '#' then
        next;
      end if;

      read_field(v_line, v_old_w,     "old_width");
      read_field(v_line, v_old_bp,    "old_binpnt");
      read_field(v_line, v_old_arith, "old_arith");
      read_field(v_line, v_new_w,     "new_width");
      read_field(v_line, v_new_bp,    "new_binpnt");
      read_field(v_line, v_new_arith, "new_arith");
      read_field(v_line, v_round,     "rounding");
      read_field(v_line, v_overflow,  "overflow");
      read_field(v_line, v_value,     "value");
      read_field(v_line, v_expected,  "expected");

      assert v_old_w > 0 and v_old_w <= C_MAX_W
         and v_new_w > 0 and v_new_w <= C_MAX_W
        report "tb_quantize_vectors: a vector's width is outside the range this"
             & " testbench supports (1 to " & integer'image(C_MAX_W) & " bits)"
        severity failure;

      v_in(v_old_w - 1 downto 0)  := std_logic_vector(to_unsigned(v_value, v_old_w));
      v_exp(v_new_w - 1 downto 0) := std_logic_vector(to_unsigned(v_expected, v_new_w));

      v_act(v_new_w - 1 downto 0) := f_lm_quantize(v_in(v_old_w - 1 downto 0),
                                                   v_new_w, v_new_bp, v_new_arith,
                                                   v_old_w, v_old_bp, v_old_arith,
                                                   v_round, v_overflow);

      v_checked := v_checked + 1;
      if v_act(v_new_w - 1 downto 0) /= v_exp(v_new_w - 1 downto 0) then
        v_mismatch := v_mismatch + 1;
        report "tb_quantize_vectors: MISMATCH ("
             & integer'image(v_old_w) & "," & integer'image(v_old_bp) & ")->("
             & integer'image(v_new_w) & "," & integer'image(v_new_bp) & ")"
             & " old_arith=" & integer'image(v_old_arith)
             & " new_arith=" & integer'image(v_new_arith)
             & " rounding=" & integer'image(v_round)
             & " overflow=" & integer'image(v_overflow)
             & " value=" & integer'image(v_value)
             & " expected=" & to_string(v_exp(v_new_w - 1 downto 0))
             & " actual=" & to_string(v_act(v_new_w - 1 downto 0))
          severity error;
      end if;
    end loop;

    file_close(f_vec);

    assert v_checked > 0
      report "tb_quantize_vectors: vector file contained no vectors"
      severity failure;
    assert v_mismatch = 0
      report "tb_quantize_vectors: " & integer'image(v_mismatch) & " of "
           & integer'image(v_checked) & " vectors do not match"
      severity failure;

    report "TEST PASSED: tb_quantize_vectors (" & integer'image(v_checked)
         & " f_lm_quantize vectors)" severity note;
    wait;
  end process proc_main;

end architecture a_tb;
