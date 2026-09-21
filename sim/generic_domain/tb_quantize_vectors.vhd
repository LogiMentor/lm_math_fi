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
-- THE BENCH STATES THE COVERAGE POLICY. THE FILE ONLY SUPPLIES DATA.
--   A manifest derived from the rows can only detect a file inconsistent with
--   its own declarations. It cannot detect a file that was consistently reduced
--   - regenerated to enumerate a single input value, say, with every geometry
--   still declared and every count still matching. So the requirements below are
--   written here, not taken from the file:
--
--     1. every declared geometry must carry all 2**old_width DISTINCT input
--        values, counted as distinct values rather than as rows;
--     2. the declared geometries must between them cover all eight geometry
--        families this bench names, classified here from each geometry's own
--        widths and binary points;
--     3. no geometry may be wider than this bench can enumerate, so that
--        requirement 1 is always checkable rather than quietly skipped;
--     4. every geometry must carry every rounding mode THE PACKAGE DEFINES;
--     5. every geometry must carry every overflow mode THE PACKAGE DEFINES.
--
--   Requirements 4 and 5 are asked of lm_math_fi_pkg, not of the file and not
--   of a list written here: this bench sweeps a window of integers, asks
--   f_lm_valid_round_mode and f_lm_valid_overflow which of them the package
--   accepts, and requires a vector for each. Add a tenth rounding mode to the
--   package and this testbench demands vectors for it on the next run. It also
--   refuses to run if a valid mode sits at the edge of the window it sweeps,
--   since a mode outside the window would otherwise go unnoticed.
--
--   The manifest is still enforced on top of that, because it catches a file
--   inconsistent with itself:
--     #! 0 <total>                                   expected number of rows
--     #! 1 <old_w> <old_bp> <new_w> <new_bp> <count> expected rows per geometry
--
--   Between them: truncating the file, padding it, dropping a geometry, deleting
--   the manifest, regenerating a reduced-but-consistent set, and regenerating
--   with the rounding or overflow sweep collapsed all fail.
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

  -- The families a geometry can belong to. A geometry may be in several.
  type t_family is (ORDINARY, BP_EQUALS_WIDTH, BP_ABOVE_WIDTH_SRC, BP_ABOVE_WIDTH_DST,
                    DISJOINT_DST_ABOVE, DISJOINT_DST_BELOW, ONE_BIT_OVERLAP, WIDTH_1);
  type t_family_set is array (t_family) of boolean;

  function f_families(ow, obp, nw, nbp : integer) return t_family_set is
    variable v : t_family_set := (others => false);
    variable v_lo, v_hi : integer;
  begin
    if obp < ow and nbp < nw then
      v(ORDINARY) := true;
    end if;
    if obp = ow or nbp = nw then
      v(BP_EQUALS_WIDTH) := true;
    end if;
    if obp > ow then
      v(BP_ABOVE_WIDTH_SRC) := true;
    end if;
    if nbp > nw then
      v(BP_ABOVE_WIDTH_DST) := true;
    end if;
    -- Bit weights: the source spans exponents -obp .. ow-1-obp.
    if -nbp > ow - 1 - obp then
      v(DISJOINT_DST_ABOVE) := true;
    end if;
    if -obp > nw - 1 - nbp then
      v(DISJOINT_DST_BELOW) := true;
    end if;
    v_lo := f_lm_max(-obp, -nbp);
    v_hi := ow - obp;
    if nw - nbp < v_hi then
      v_hi := nw - nbp;
    end if;
    if v_hi - v_lo = 1 then
      v(ONE_BIT_OVERLAP) := true;
    end if;
    if ow = 1 or nw = 1 then
      v(WIDTH_1) := true;
    end if;
    return v;
  end function;

  function f_family_name(f : t_family) return string is
  begin
    case f is
      when ORDINARY            => return "ordinary";
      when BP_EQUALS_WIDTH     => return "binary point equal to the width";
      when BP_ABOVE_WIDTH_SRC  => return "binary point above the width, source";
      when BP_ABOVE_WIDTH_DST  => return "binary point above the width, destination";
      when DISJOINT_DST_ABOVE  => return "disjoint weights, destination above";
      when DISJOINT_DST_BELOW  => return "disjoint weights, destination below";
      when ONE_BIT_OVERLAP     => return "exactly one bit of weight overlap";
      when WIDTH_1             => return "width 1";
    end case;
  end function;

  -- REQUIREMENTS 4 AND 5: WHICH MODES ARE REQUIRED IS THE PACKAGE'S ANSWER.
  -- The window below is swept and each value put to the package's own domain
  -- predicate. Nothing here lists the modes, so nothing here can fall behind
  -- the package: a mode added to lm_math_fi_pkg becomes required immediately.
  constant C_MODE_LO : integer := -32;
  constant C_MODE_HI : integer := 255;
  type t_mode_set is array (C_MODE_LO to C_MODE_HI) of boolean;

  function f_valid_round_modes return t_mode_set is
    variable v : t_mode_set := (others => false);
  begin
    for m in C_MODE_LO to C_MODE_HI loop
      v(m) := f_lm_valid_round_mode(m);
    end loop;
    return v;
  end function;

  function f_valid_overflow_modes return t_mode_set is
    variable v : t_mode_set := (others => false);
  begin
    for m in C_MODE_LO to C_MODE_HI loop
      v(m) := f_lm_valid_overflow(m);
    end loop;
    return v;
  end function;

  function f_mode_count(s : t_mode_set) return integer is
    variable v : integer := 0;
  begin
    for m in C_MODE_LO to C_MODE_HI loop
      if s(m) then
        v := v + 1;
      end if;
    end loop;
    return v;
  end function;

  constant C_REQUIRED_ROUNDS : t_mode_set := f_valid_round_modes;
  constant C_REQUIRED_OVFS   : t_mode_set := f_valid_overflow_modes;

begin

  proc_main : process
    -- Widest format this testbench supports at all.
    constant C_MAX_W      : integer := 32;
    -- Widest source a geometry may have, so that its whole input space can be
    -- enumerated and requirement 1 stays checkable.
    constant C_MAX_SRC_W  : integer := 12;
    constant C_MAX_VALUES : integer := 2 ** C_MAX_SRC_W;
    constant C_MAX_GEOM   : integer := 32;

    type t_seen is array (0 to C_MAX_VALUES - 1) of boolean;
    type t_geometry is record
      old_w    : integer;
      old_bp   : integer;
      new_w    : integer;
      new_bp   : integer;
      declared : integer;
      rows     : integer;
      distinct : integer;
    end record;
    type t_geometry_array is array (0 to C_MAX_GEOM - 1) of t_geometry;
    type t_seen_array is array (0 to C_MAX_GEOM - 1) of t_seen;
    type t_mode_seen_array is array (0 to C_MAX_GEOM - 1) of t_mode_set;

    file     f_vec      : text;
    variable v_stat     : file_open_status;
    variable v_line     : line;
    variable v_char     : character;

    variable v_geoms      : t_geometry_array;
    variable v_seen       : t_seen_array := (others => (others => false));
    variable v_round_seen : t_mode_seen_array := (others => (others => false));
    variable v_ovf_seen   : t_mode_seen_array := (others => (others => false));
    variable v_geom_count : integer := 0;
    variable v_declared   : integer := -1;
    variable v_directive  : integer;
    variable v_covered    : t_family_set := (others => false);
    variable v_fams       : t_family_set;

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

    variable v_in  : std_logic_vector(C_MAX_W - 1 downto 0) := (others => '0');
    variable v_exp : std_logic_vector(C_MAX_W - 1 downto 0) := (others => '0');
    variable v_act : std_logic_vector(C_MAX_W - 1 downto 0) := (others => '0');

    variable v_checked  : integer := 0;
    variable v_mismatch : integer := 0;
    variable v_index    : integer;
    variable v_short    : integer := 0;
    variable v_thin     : integer := 0;
    variable v_absent   : integer := 0;
    variable v_no_round : integer := 0;
    variable v_no_ovf   : integer := 0;

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
    -- The swept window must strictly contain the package's valid modes.
    -- If a valid mode sits on the edge, a mode beyond the edge could exist and
    -- go unrequired, which is exactly the silence requirements 4 and 5 exist to
    -- prevent.
    assert not C_REQUIRED_ROUNDS(C_MODE_LO) and not C_REQUIRED_ROUNDS(C_MODE_HI)
       and not C_REQUIRED_OVFS(C_MODE_LO) and not C_REQUIRED_OVFS(C_MODE_HI)
      report "tb_quantize_vectors: a mode the package accepts sits at the edge of"
           & " the window this testbench sweeps (" & integer'image(C_MODE_LO) & " to "
           & integer'image(C_MODE_HI) & "); widen C_MODE_LO/C_MODE_HI, because a"
           & " mode outside the window would not be required of the vectors"
      severity failure;
    assert f_mode_count(C_REQUIRED_ROUNDS) > 0 and f_mode_count(C_REQUIRED_OVFS) > 0
      report "tb_quantize_vectors: the package accepts no rounding or no overflow"
           & " mode in the swept window, so requirements 4 and 5 would be vacuous"
      severity failure;

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
          v_geoms(v_geom_count).rows := 0;
          v_geoms(v_geom_count).distinct := 0;

          -- Requirement 3, checked as the geometry is declared.
          assert v_geoms(v_geom_count).old_w > 0
             and v_geoms(v_geom_count).old_w <= C_MAX_SRC_W
            report "tb_quantize_vectors: geometry source width "
                 & integer'image(v_geoms(v_geom_count).old_w)
                 & " is outside 1 to " & integer'image(C_MAX_SRC_W)
                 & ", so its input space cannot be enumerated and the coverage "
                 & "requirement could not be checked"
            severity failure;

          -- Requirement 2 accumulates here, from the geometry itself.
          v_fams := f_families(v_geoms(v_geom_count).old_w, v_geoms(v_geom_count).old_bp,
                               v_geoms(v_geom_count).new_w, v_geoms(v_geom_count).new_bp);
          for f in t_family loop
            v_covered(f) := v_covered(f) or v_fams(f);
          end loop;

          v_geom_count := v_geom_count + 1;
        else
          report "tb_quantize_vectors: unknown manifest directive "
               & integer'image(v_directive)
            severity failure;
        end if;
        next;
      end if;

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
      assert v_round >= C_MODE_LO and v_round <= C_MODE_HI
         and v_overflow >= C_MODE_LO and v_overflow <= C_MODE_HI
        report "tb_quantize_vectors: a vector carries rounding mode "
             & integer'image(v_round) & " or overflow mode "
             & integer'image(v_overflow) & ", outside the window this testbench"
             & " sweeps (" & integer'image(C_MODE_LO) & " to "
             & integer'image(C_MODE_HI) & ")"
        severity failure;
      v_round_seen(v_index)(v_round)   := true;
      v_ovf_seen(v_index)(v_overflow)  := true;

      v_geoms(v_index).rows := v_geoms(v_index).rows + 1;
      if not v_seen(v_index)(v_value) then
        v_seen(v_index)(v_value) := true;
        v_geoms(v_index).distinct := v_geoms(v_index).distinct + 1;
      end if;

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

    -- Manifest consistency ---------------------------------------------------
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
      if v_geoms(g).rows /= v_geoms(g).declared then
        v_short := v_short + 1;
        report "tb_quantize_vectors: geometry ("
             & integer'image(v_geoms(g).old_w) & "," & integer'image(v_geoms(g).old_bp)
             & ")->(" & integer'image(v_geoms(g).new_w) & ","
             & integer'image(v_geoms(g).new_bp) & ") declares "
             & integer'image(v_geoms(g).declared) & " rows but "
             & integer'image(v_geoms(g).rows) & " were present"
          severity note;
      end if;
    end loop;
    assert v_short = 0
      report "tb_quantize_vectors: " & integer'image(v_short)
           & " geometries do not carry the number of rows the manifest declares"
      severity failure;

    -- Requirement 1: distinct input values, not rows --------------------------
    for g in 0 to v_geom_count - 1 loop
      if v_geoms(g).distinct /= 2 ** v_geoms(g).old_w then
        v_thin := v_thin + 1;
        report "tb_quantize_vectors: geometry ("
             & integer'image(v_geoms(g).old_w) & "," & integer'image(v_geoms(g).old_bp)
             & ")->(" & integer'image(v_geoms(g).new_w) & ","
             & integer'image(v_geoms(g).new_bp) & ") carries "
             & integer'image(v_geoms(g).distinct) & " distinct input values, but a "
             & integer'image(v_geoms(g).old_w) & "-bit source has "
             & integer'image(2 ** v_geoms(g).old_w)
          severity note;
      end if;
    end loop;
    assert v_thin = 0
      report "tb_quantize_vectors: " & integer'image(v_thin)
           & " geometries do not enumerate their whole input space; the vector set "
           & "has been reduced"
      severity failure;

    -- Requirement 2: the families this bench requires --------------------------
    for f in t_family loop
      if not v_covered(f) then
        v_absent := v_absent + 1;
        report "tb_quantize_vectors: no declared geometry covers the family '"
             & f_family_name(f) & "'"
          severity note;
      end if;
    end loop;
    assert v_absent = 0
      report "tb_quantize_vectors: " & integer'image(v_absent)
           & " of the geometry families this testbench requires are not covered by "
           & "any declared geometry"
      severity failure;

    -- Requirements 4 and 5: every mode the PACKAGE defines, per geometry ------
    for g in 0 to v_geom_count - 1 loop
      for m in C_MODE_LO to C_MODE_HI loop
        if C_REQUIRED_ROUNDS(m) and not v_round_seen(g)(m) then
          v_no_round := v_no_round + 1;
          report "tb_quantize_vectors: geometry ("
               & integer'image(v_geoms(g).old_w) & "," & integer'image(v_geoms(g).old_bp)
               & ")->(" & integer'image(v_geoms(g).new_w) & ","
               & integer'image(v_geoms(g).new_bp) & ") carries no vector with"
               & " rounding mode " & integer'image(m) & ", which the package accepts"
            severity note;
        end if;
        if C_REQUIRED_OVFS(m) and not v_ovf_seen(g)(m) then
          v_no_ovf := v_no_ovf + 1;
          report "tb_quantize_vectors: geometry ("
               & integer'image(v_geoms(g).old_w) & "," & integer'image(v_geoms(g).old_bp)
               & ")->(" & integer'image(v_geoms(g).new_w) & ","
               & integer'image(v_geoms(g).new_bp) & ") carries no vector with"
               & " overflow mode " & integer'image(m) & ", which the package accepts"
            severity note;
        end if;
      end loop;
    end loop;
    assert v_no_round = 0
      report "tb_quantize_vectors: " & integer'image(v_no_round)
           & " (geometry, rounding mode) pairs are missing; the package defines "
           & integer'image(f_mode_count(C_REQUIRED_ROUNDS))
           & " rounding modes and every geometry must exercise all of them"
      severity failure;
    assert v_no_ovf = 0
      report "tb_quantize_vectors: " & integer'image(v_no_ovf)
           & " (geometry, overflow mode) pairs are missing; the package defines "
           & integer'image(f_mode_count(C_REQUIRED_OVFS))
           & " overflow modes and every geometry must exercise all of them"
      severity failure;

    assert v_mismatch = 0
      report "tb_quantize_vectors: " & integer'image(v_mismatch) & " of "
           & integer'image(v_checked) & " vectors do not match"
      severity failure;

    report "TEST PASSED: tb_quantize_vectors (" & integer'image(v_checked)
         & " f_lm_quantize vectors over " & integer'image(v_geom_count)
         & " geometries, every input space enumerated, all "
         & integer'image(t_family'pos(t_family'high) + 1)
         & " required families covered, all "
         & integer'image(f_mode_count(C_REQUIRED_ROUNDS)) & " rounding and "
         & integer'image(f_mode_count(C_REQUIRED_OVFS))
         & " overflow modes the package defines present per geometry)" severity note;
    wait;
  end process proc_main;

end architecture a_tb;
