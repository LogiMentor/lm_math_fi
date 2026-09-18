-- SPDX-License-Identifier: Apache-2.0
-- Copyright 2026 LogiMentor
--
-- Replays f_lm_quantize_vectors.txt against the current lm_math_fi_pkg.
--
-- The committed vectors pin the arithmetic of f_lm_quantize across the format
-- domain, including the degenerate binary points: equal to the width, above the
-- width, bit weights disjoint in either direction, one bit of overlap, and
-- width 1. A generic-domain check that wrongly rejected a legal value, or an
-- edit that changed a result for a legal configuration, fails here.
--
-- THE BENCH PROTECTS ITS OWN COVERAGE.
--   Checking every vector it happens to read would leave the gate green if the
--   file were truncated, thinned, or had its degenerate-format lines dropped.
--   So the file carries a manifest, emitted by the same generator that emits the
--   vectors, and this bench enforces it:
--
--     #! 0 <total>                                   expected number of vectors
--     #! 1 <old_w> <old_bp> <new_w> <new_bp> <count> expected vectors per geometry
--
--   The bench fails if the manifest is absent, if the total does not match what
--   it actually consumed, if any declared geometry is short or over-supplied, or
--   if a vector turns up whose geometry was never declared. Losing every
--   degenerate-format line therefore fails even if the total is kept whole by
--   duplicating others, because that geometry's own count would drop to zero.
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
    constant C_MAX_W    : integer := 32;
    -- Most geometries the manifest may declare.
    constant C_MAX_GEOM : integer := 64;

    type t_geometry is record
      old_w    : integer;
      old_bp   : integer;
      new_w    : integer;
      new_bp   : integer;
      declared : integer;
      seen     : integer;
    end record;
    type t_geometry_array is array (0 to C_MAX_GEOM - 1) of t_geometry;

    file     f_vec      : text;
    variable v_stat     : file_open_status;
    variable v_line     : line;
    variable v_char     : character;

    variable v_geoms       : t_geometry_array;
    variable v_geom_count  : integer := 0;
    variable v_declared    : integer := -1;   -- -1 until the total directive is seen
    variable v_directive   : integer;

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
    variable v_index    : integer;
    variable v_short    : integer := 0;

    procedure read_field(variable l : inout line; variable v : out integer;
                         constant what : string) is
      variable v_got : boolean;
    begin
      read(l, v, v_got);
      assert v_got
        report "tb_quantize_vectors: malformed line, could not read " & what
        severity failure;
    end procedure;
  begin
    file_open(v_stat, f_vec, g_vector_file, read_mode);
    assert v_stat = open_ok
      report "tb_quantize_vectors: cannot open vector file '" & g_vector_file & "'"
      severity failure;

    while not endfile(f_vec) loop
      readline(f_vec, v_line);

      if v_line'length = 0 then
        next;
      end if;

      if v_line(v_line'left) = '#' then
        -- A manifest directive is '#!'; anything else beginning with '#' is prose.
        if v_line'length < 2 or v_line(v_line'left + 1) /= '!' then
          next;
        end if;
        read(v_line, v_char);          -- '#'
        read(v_line, v_char);          -- '!'
        read_field(v_line, v_directive, "manifest directive");
        if v_directive = 0 then
          read_field(v_line, v_declared, "manifest total");
        elsif v_directive = 1 then
          assert v_geom_count < C_MAX_GEOM
            report "tb_quantize_vectors: more geometries declared than this "
                 & "testbench supports (" & integer'image(C_MAX_GEOM) & ")"
            severity failure;
          read_field(v_line, v_geoms(v_geom_count).old_w,    "geometry old_width");
          read_field(v_line, v_geoms(v_geom_count).old_bp,   "geometry old_binpnt");
          read_field(v_line, v_geoms(v_geom_count).new_w,    "geometry new_width");
          read_field(v_line, v_geoms(v_geom_count).new_bp,   "geometry new_binpnt");
          read_field(v_line, v_geoms(v_geom_count).declared, "geometry count");
          v_geoms(v_geom_count).seen := 0;
          v_geom_count := v_geom_count + 1;
        else
          report "tb_quantize_vectors: unknown manifest directive "
               & integer'image(v_directive)
            severity failure;
        end if;
        next;
      end if;

      -- The manifest sits above the vectors, so by the first vector it has
      -- either been read or it is not there at all.
      assert v_declared >= 0 and v_geom_count > 0
        report "tb_quantize_vectors: the vector file carries vectors but is "
             & "missing its manifest, so its coverage cannot be trusted"
        severity failure;

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

      -- Attribute the vector to a declared geometry.
      v_index := -1;
      for g in 0 to v_geom_count - 1 loop
        if v_geoms(g).old_w = v_old_w and v_geoms(g).old_bp = v_old_bp
           and v_geoms(g).new_w = v_new_w and v_geoms(g).new_bp = v_new_bp then
          v_index := g;
        end if;
      end loop;
      assert v_index >= 0
        report "tb_quantize_vectors: a vector has geometry ("
             & integer'image(v_old_w) & "," & integer'image(v_old_bp) & ")->("
             & integer'image(v_new_w) & "," & integer'image(v_new_bp) & ")"
             & " which the manifest does not declare"
        severity failure;
      v_geoms(v_index).seen := v_geoms(v_index).seen + 1;

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

    -- Coverage self-protection, before any result is reported.
    assert v_declared >= 0
      report "tb_quantize_vectors: the vector file declares no total; it is "
           & "missing its manifest, so its coverage cannot be trusted"
      severity failure;
    assert v_geom_count > 0
      report "tb_quantize_vectors: the vector file declares no geometries; it is "
           & "missing its manifest, so its coverage cannot be trusted"
      severity failure;
    assert v_checked = v_declared
      report "tb_quantize_vectors: consumed " & integer'image(v_checked)
           & " vectors but the manifest declares " & integer'image(v_declared)
           & "; the vector file has been truncated or padded"
      severity failure;

    for g in 0 to v_geom_count - 1 loop
      if v_geoms(g).seen /= v_geoms(g).declared then
        v_short := v_short + 1;
        report "tb_quantize_vectors: geometry ("
             & integer'image(v_geoms(g).old_w) & "," & integer'image(v_geoms(g).old_bp)
             & ")->(" & integer'image(v_geoms(g).new_w) & ","
             & integer'image(v_geoms(g).new_bp) & ") declares "
             & integer'image(v_geoms(g).declared) & " vectors but "
             & integer'image(v_geoms(g).seen) & " were present"
          severity note;
      end if;
    end loop;
    assert v_short = 0
      report "tb_quantize_vectors: " & integer'image(v_short)
           & " geometries do not carry the number of vectors the manifest declares"
      severity failure;

    assert v_mismatch = 0
      report "tb_quantize_vectors: " & integer'image(v_mismatch) & " of "
           & integer'image(v_checked) & " vectors do not match"
      severity failure;

    report "TEST PASSED: tb_quantize_vectors (" & integer'image(v_checked)
         & " f_lm_quantize vectors over " & integer'image(v_geom_count)
         & " declared geometries)" severity note;
    wait;
  end process proc_main;

end architecture a_tb;
