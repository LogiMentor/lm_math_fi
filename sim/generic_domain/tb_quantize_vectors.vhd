-- SPDX-License-Identifier: Apache-2.0
-- Copyright 2026 LogiMentor
--
-- Replays f_lm_quantize_vectors.txt against the current lm_math_fi_pkg.
--
-- The committed vectors pin the arithmetic of f_lm_quantize for every legal
-- combination of its rounding and overflow arguments. A generic-domain check
-- that wrongly rejected a legal value, or an edit that changed a result for a
-- legal configuration, fails here. See the header of the vector file for how
-- the values were produced and when it is legitimate to regenerate them.
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
    -- Widest geometry this testbench supports. The geometry line in the vector
    -- file is checked against it, so the two cannot drift apart silently.
    constant C_MAX_W : integer := 32;

    file     f_vec      : text;
    variable v_stat     : file_open_status;
    variable v_line     : line;
    variable v_ok       : boolean;

    variable v_old_w    : integer := 0;
    variable v_old_bp   : integer := 0;
    variable v_new_w    : integer := 0;
    variable v_new_bp   : integer := 0;
    variable v_have_geo : boolean := false;

    variable v_value     : integer;
    variable v_old_arith : integer;
    variable v_new_arith : integer;
    variable v_round     : integer;
    variable v_overflow  : integer;
    variable v_expected  : integer;

    -- Sized to the maximum; only the low v_old_w / v_new_w bits are ever used,
    -- because f_lm_quantize takes unconstrained vectors and is handed a slice.
    variable v_in  : std_logic_vector(C_MAX_W - 1 downto 0) := (others => '0');
    variable v_exp : std_logic_vector(C_MAX_W - 1 downto 0) := (others => '0');
    variable v_act : std_logic_vector(C_MAX_W - 1 downto 0) := (others => '0');

    variable v_checked  : integer := 0;
    variable v_mismatch : integer := 0;
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

      if not v_have_geo then
        read(v_line, v_old_w, v_ok);
        assert v_ok report "tb_quantize_vectors: malformed geometry line" severity failure;
        read(v_line, v_old_bp, v_ok);
        assert v_ok report "tb_quantize_vectors: malformed geometry line" severity failure;
        read(v_line, v_new_w, v_ok);
        assert v_ok report "tb_quantize_vectors: malformed geometry line" severity failure;
        read(v_line, v_new_bp, v_ok);
        assert v_ok report "tb_quantize_vectors: malformed geometry line" severity failure;

        assert v_old_w > 0 and v_old_w <= C_MAX_W and v_new_w > 0 and v_new_w <= C_MAX_W
          report "tb_quantize_vectors: geometry in the vector file is outside the range"
               & " this testbench supports (1 to " & integer'image(C_MAX_W) & " bits)"
          severity failure;

        v_have_geo := true;
        next;
      end if;

      read(v_line, v_value, v_ok);
      assert v_ok report "tb_quantize_vectors: malformed vector line" severity failure;
      read(v_line, v_old_arith, v_ok);
      assert v_ok report "tb_quantize_vectors: malformed vector line" severity failure;
      read(v_line, v_new_arith, v_ok);
      assert v_ok report "tb_quantize_vectors: malformed vector line" severity failure;
      read(v_line, v_round, v_ok);
      assert v_ok report "tb_quantize_vectors: malformed vector line" severity failure;
      read(v_line, v_overflow, v_ok);
      assert v_ok report "tb_quantize_vectors: malformed vector line" severity failure;
      read(v_line, v_expected, v_ok);
      assert v_ok report "tb_quantize_vectors: malformed vector line" severity failure;

      v_in(v_old_w - 1 downto 0)  := std_logic_vector(to_unsigned(v_value, v_old_w));
      v_exp(v_new_w - 1 downto 0) := std_logic_vector(to_unsigned(v_expected, v_new_w));

      v_act(v_new_w - 1 downto 0) := f_lm_quantize(v_in(v_old_w - 1 downto 0),
                                                   v_new_w, v_new_bp, v_new_arith,
                                                   v_old_w, v_old_bp, v_old_arith,
                                                   v_round, v_overflow);

      v_checked := v_checked + 1;
      if v_act(v_new_w - 1 downto 0) /= v_exp(v_new_w - 1 downto 0) then
        v_mismatch := v_mismatch + 1;
        report "tb_quantize_vectors: MISMATCH value=" & integer'image(v_value)
             & " old_arith=" & integer'image(v_old_arith)
             & " new_arith=" & integer'image(v_new_arith)
             & " rounding=" & integer'image(v_round)
             & " overflow=" & integer'image(v_overflow)
             & " expected=" & to_string(v_exp(v_new_w - 1 downto 0))
             & " actual=" & to_string(v_act(v_new_w - 1 downto 0))
          severity error;
      end if;
    end loop;

    file_close(f_vec);

    assert v_have_geo
      report "tb_quantize_vectors: vector file contained no geometry line"
      severity failure;
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
