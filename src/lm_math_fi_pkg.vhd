-- SPDX-License-Identifier: Apache-2.0
-- Copyright 2026 LogiMentor
--
-- Module Name : lm_math_fi_pkg
-- Description : Fixed-point constants and conversion helper functions.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package lm_math_fi_pkg is

  constant C_LM_UNSIGNED      : integer := 1;
  constant C_LM_SIGNED        : integer := 2;

  constant C_LM_SATURATE      : integer := 1;
  constant C_LM_WRAP          : integer := 2;

  constant C_LM_TRUNC_BITS    : integer := 0;
  constant C_LM_ROUND_EVEN    : integer := 1;
  constant C_LM_CEIL          : integer := 2;
  constant C_LM_TRUNC_ZERO    : integer := 3;
  constant C_LM_FLOOR         : integer := 4;
  constant C_LM_ROUND_POS_INF : integer := 5;
  constant C_LM_ROUND_NEG_INF : integer := 6;
  constant C_LM_ROUND_ZERO    : integer := 7;
  constant C_LM_ROUND_AWAY    : integer := 8;

  constant C_LM_TRUNC         : integer := C_LM_TRUNC_BITS;
  constant C_LM_ROUND         : integer := C_LM_ROUND_EVEN;
  constant C_LM_ROUND_NEAREST : integer := C_LM_ROUND_EVEN;
  constant C_LM_ROUND_INF     : integer := C_LM_ROUND_AWAY;

  constant C_LM_ADD           : integer := 0;
  constant C_LM_SUB           : integer := 1;
  constant C_LM_ADDSUB        : integer := 2;

  function f_lm_max(l, r : integer) return integer;

  function f_lm_slv_to_uns(inp : std_logic_vector) return unsigned;
  function f_lm_uns_to_slv(inp : unsigned) return std_logic_vector;
  function f_lm_slv_to_sig(inp : std_logic_vector) return signed;
  function f_lm_sig_to_slv(inp : signed) return std_logic_vector;

  function f_lm_add_sig(l_vec : std_logic_vector; r_vec : std_logic_vector; res_w : natural) return std_logic_vector;
  function f_lm_sub_sig(l_vec : std_logic_vector; r_vec : std_logic_vector; res_w : natural) return std_logic_vector;
  function f_lm_add_uns(l_vec : std_logic_vector; r_vec : std_logic_vector; res_w : natural) return std_logic_vector;
  function f_lm_sub_uns(l_vec : std_logic_vector; r_vec : std_logic_vector; res_w : natural) return std_logic_vector;

  function f_lm_trunc_bits(inp : std_logic_vector;
                            old_width, old_bin_pt, old_arith,
                            new_width, new_bin_pt, new_arith : integer)
    return std_logic_vector;
  function f_lm_trunc_zero(inp : std_logic_vector;
                            old_width, old_bin_pt, old_arith,
                            new_width, new_bin_pt, new_arith : integer)
    return std_logic_vector;
  function f_lm_round_floor(inp : std_logic_vector;
                             old_width, old_bin_pt, old_arith,
                             new_width, new_bin_pt, new_arith : integer)
    return std_logic_vector;
  function f_lm_round_ceil(inp : std_logic_vector;
                            old_width, old_bin_pt, old_arith,
                            new_width, new_bin_pt, new_arith : integer)
    return std_logic_vector;
  function f_lm_round_even(inp : std_logic_vector;
                            old_width, old_bin_pt, old_arith,
                            new_width, new_bin_pt, new_arith : integer)
    return std_logic_vector;
  function f_lm_round_tie_pos(inp : std_logic_vector;
                              old_width, old_bin_pt, old_arith,
                              new_width, new_bin_pt, new_arith : integer)
    return std_logic_vector;
  function f_lm_round_tie_neg(inp : std_logic_vector;
                              old_width, old_bin_pt, old_arith,
                              new_width, new_bin_pt, new_arith : integer)
    return std_logic_vector;
  function f_lm_round_tie_zero(inp : std_logic_vector;
                               old_width, old_bin_pt, old_arith,
                               new_width, new_bin_pt, new_arith : integer)
    return std_logic_vector;
  function f_lm_round_tie_away(inp : std_logic_vector;
                               old_width, old_bin_pt, old_arith,
                               new_width, new_bin_pt, new_arith : integer)
    return std_logic_vector;

  function f_lm_quantize(inp : std_logic_vector;
                          new_width, new_bin_pt, new_arith,
                          old_width, old_bin_pt, old_arith,
                          quantization, overflow : integer)
    return std_logic_vector;

  function f_lm_align(inp : std_logic_vector;
                      new_width, new_bin_pt, old_bin_pt, arith : integer)
    return std_logic_vector;

  function f_lm_saturate(inp : std_logic_vector;
                          new_width, new_bin_pt, new_arith,
                          old_width, old_bin_pt, old_arith : integer)
    return std_logic_vector;

  function f_lm_wrap(inp : std_logic_vector;
                      new_width, new_bin_pt, new_arith,
                      old_width, old_bin_pt, old_arith : integer)
    return std_logic_vector;

  function f_lm_sign_ext(inp : std_logic_vector; new_width : integer) return std_logic_vector;
  function f_lm_zero_ext(inp : std_logic_vector; new_width : integer) return std_logic_vector;
  function f_lm_zero_ext(inp : std_logic; new_width : integer) return std_logic_vector;
  function f_lm_pad_lsb(inp : std_logic_vector; new_width : integer) return std_logic_vector;
  function f_lm_pad_lsb(inp : std_logic_vector; new_width, arith : integer) return std_logic_vector;
  function f_lm_extend_msb(inp : std_logic_vector; new_width, arith : integer) return std_logic_vector;

end package lm_math_fi_pkg;

package body lm_math_fi_pkg is

  function f_abs_int(value : integer) return integer is
  begin
    if value < 0 then
      return -value;
    end if;
    return value;
  end function;

  function f_min_int(l, r : integer) return integer is
  begin
    if l < r then
      return l;
    end if;
    return r;
  end function;

  function f_bit_value(inp : std_logic_vector; bit_index, arith : integer) return std_logic is
    constant C_WIDTH : integer := inp'length;
    variable v_word  : std_logic_vector(C_WIDTH - 1 downto 0);
  begin
    v_word := inp;

    if bit_index < 0 then
      return '0';
    elsif bit_index < C_WIDTH then
      return v_word(bit_index);
    elsif arith = C_LM_SIGNED then
      return v_word(C_WIDTH - 1);
    end if;

    return '0';
  end function;

  function f_any_one(inp : std_logic_vector; high_bit, low_bit, arith : integer) return boolean is
  begin
    if high_bit < low_bit then
      return false;
    end if;

    for bit_index in low_bit to high_bit loop
      if f_bit_value(inp, bit_index, arith) = '1' then
        return true;
      end if;
    end loop;

    return false;
  end function;

  function f_negative_value(inp : std_logic_vector; arith : integer) return boolean is
    constant C_WIDTH : integer := inp'length;
    variable v_word  : std_logic_vector(C_WIDTH - 1 downto 0);
  begin
    v_word := inp;
    return arith = C_LM_SIGNED and v_word(C_WIDTH - 1) = '1';
  end function;

  function f_plus_one(inp : std_logic_vector) return std_logic_vector is
    constant C_WIDTH : integer := inp'length;
    variable v_word  : std_logic_vector(C_WIDTH - 1 downto 0);
  begin
    v_word := inp;
    return std_logic_vector(unsigned(v_word) + 1);
  end function;

  function f_align_binary_point(inp : std_logic_vector; old_bin_pt,
                              new_width, new_bin_pt, arith : integer)
    return std_logic_vector
  is
    constant C_WIDTH       : integer := inp'length;
    constant C_POINT_DELTA : integer := new_bin_pt - old_bin_pt;
    variable v_word        : std_logic_vector(C_WIDTH - 1 downto 0);
    variable v_result      : std_logic_vector(new_width - 1 downto 0);
    variable v_source_bit  : integer;
  begin
    v_word := inp;

    for bit_index in 0 to new_width - 1 loop
      v_source_bit        := bit_index - C_POINT_DELTA;
      v_result(bit_index) := f_bit_value(v_word, v_source_bit, arith);
    end loop;

    return v_result;
  end function;

  function f_max_signed_word(width : integer) return std_logic_vector is
    variable v_result : std_logic_vector(width - 1 downto 0) := (others => '1');
  begin
    v_result(width - 1) := '0';
    return v_result;
  end function;

  function f_min_signed_word(width : integer) return std_logic_vector is
    variable v_result : std_logic_vector(width - 1 downto 0) := (others => '0');
  begin
    v_result(width - 1) := '1';
    return v_result;
  end function;

  function f_max_unsigned_word(width : integer) return std_logic_vector is
    variable v_result : std_logic_vector(width - 1 downto 0) := (others => '1');
  begin
    return v_result;
  end function;

  function f_fits_uns_width(inp : std_logic_vector; width : integer) return boolean is
    constant C_WIDTH : integer := inp'length;
    variable v_word  : std_logic_vector(C_WIDTH - 1 downto 0);
  begin
    v_word := inp;

    if C_WIDTH <= width then
      return true;
    end if;

    for bit_index in width to C_WIDTH - 1 loop
      if v_word(bit_index) = '1' then
        return false;
      end if;
    end loop;

    return true;
  end function;

  function f_fits_signed_width(inp : std_logic_vector; width : integer) return boolean is
    constant C_WIDTH : integer := inp'length;
    variable v_word  : std_logic_vector(C_WIDTH - 1 downto 0);
    variable v_sign  : std_logic;
  begin
    v_word := inp;

    if C_WIDTH <= width then
      return true;
    end if;

    v_sign := v_word(width - 1);
    for bit_index in width to C_WIDTH - 1 loop
      if v_word(bit_index) /= v_sign then
        return false;
      end if;
    end loop;

    return true;
  end function;

  function f_fits_uns_as_sig(inp : std_logic_vector; width : integer) return boolean is
  begin
    if width = 1 then
      return not f_any_one(inp, inp'length - 1, 0, C_LM_UNSIGNED);
    end if;

    return f_fits_uns_width(inp, width - 1);
  end function;

  function f_low_bits(inp : std_logic_vector; width, arith : integer) return std_logic_vector is
  begin
    if arith = C_LM_SIGNED then
      return f_lm_sign_ext(inp, width);
    end if;

    return f_lm_zero_ext(inp, width);
  end function;

  function f_nearest_quantized(inp : std_logic_vector; old_width, old_bin_pt, old_arith,
                             new_width, new_bin_pt, new_arith, tie_mode : integer)
    return std_logic_vector
  is
    constant C_DROPPED_BITS : integer := old_bin_pt - new_bin_pt;
    variable v_word         : std_logic_vector(old_width - 1 downto 0);
    variable v_base         : std_logic_vector(new_width - 1 downto 0);
    variable v_guard        : std_logic;
    variable v_sticky       : boolean;
    variable v_negative     : boolean;
    variable v_increment    : boolean;
  begin
    v_word      := inp;
    v_base      := f_align_binary_point(v_word, old_bin_pt, new_width, new_bin_pt, old_arith);
    v_increment := false;

    if C_DROPPED_BITS > 0 then
      v_guard   := f_bit_value(v_word, C_DROPPED_BITS - 1, old_arith);
      v_sticky  := f_any_one(v_word, C_DROPPED_BITS - 2, 0, old_arith);
      v_negative := f_negative_value(v_word, old_arith);

      if v_guard = '1' then
        if v_sticky then
          v_increment := true;
        elsif tie_mode = C_LM_ROUND_EVEN then
          v_increment := v_base(0) = '1';
        elsif tie_mode = C_LM_ROUND_POS_INF then
          v_increment := true;
        elsif tie_mode = C_LM_ROUND_NEG_INF then
          v_increment := false;
        elsif tie_mode = C_LM_ROUND_ZERO then
          v_increment := v_negative;
        elsif tie_mode = C_LM_ROUND_AWAY then
          v_increment := not v_negative;
        end if;
      end if;
    end if;

    if v_increment then
      return f_plus_one(v_base);
    end if;

    return v_base;
  end function;

  function f_lm_max(l, r : integer) return integer is
  begin
    if l > r then
      return l;
    end if;
    return r;
  end function;

  function f_lm_slv_to_uns(inp : std_logic_vector) return unsigned is
  begin
    return unsigned(inp);
  end function;

  function f_lm_uns_to_slv(inp : unsigned) return std_logic_vector is
  begin
    return std_logic_vector(inp);
  end function;

  function f_lm_slv_to_sig(inp : std_logic_vector) return signed is
  begin
    return signed(inp);
  end function;

  function f_lm_sig_to_slv(inp : signed) return std_logic_vector is
  begin
    return std_logic_vector(inp);
  end function;

  function f_lm_add_sig(l_vec : std_logic_vector; r_vec : std_logic_vector; res_w : natural) return std_logic_vector is
  begin
    return std_logic_vector(resize(signed(l_vec), res_w) + resize(signed(r_vec), res_w));
  end function;

  function f_lm_sub_sig(l_vec : std_logic_vector; r_vec : std_logic_vector; res_w : natural) return std_logic_vector is
  begin
    return std_logic_vector(resize(signed(l_vec), res_w) - resize(signed(r_vec), res_w));
  end function;

  function f_lm_add_uns(l_vec : std_logic_vector; r_vec : std_logic_vector; res_w : natural) return std_logic_vector is
  begin
    return std_logic_vector(resize(unsigned(l_vec), res_w) + resize(unsigned(r_vec), res_w));
  end function;

  function f_lm_sub_uns(l_vec : std_logic_vector; r_vec : std_logic_vector; res_w : natural) return std_logic_vector is
  begin
    return std_logic_vector(resize(unsigned(l_vec), res_w) - resize(unsigned(r_vec), res_w));
  end function;

  function f_lm_align(inp : std_logic_vector;
                       new_width, new_bin_pt, old_bin_pt, arith : integer)
    return std_logic_vector
  is
  begin
    return f_align_binary_point(inp, old_bin_pt, new_width, new_bin_pt, arith);
  end function;

  function f_lm_trunc_bits(inp : std_logic_vector; old_width, old_bin_pt, old_arith,
                            new_width, new_bin_pt, new_arith : integer)
    return std_logic_vector
  is
    variable v_word : std_logic_vector(old_width - 1 downto 0);
  begin
    v_word := inp;
    return f_align_binary_point(v_word, old_bin_pt, new_width, new_bin_pt, old_arith);
  end function;

  function f_lm_trunc_zero(inp : std_logic_vector; old_width, old_bin_pt, old_arith,
                            new_width, new_bin_pt, new_arith : integer)
    return std_logic_vector
  is
    constant C_DROPPED_BITS : integer := old_bin_pt - new_bin_pt;
    variable v_word         : std_logic_vector(old_width - 1 downto 0);
    variable v_result       : std_logic_vector(new_width - 1 downto 0);
  begin
    v_word   := inp;
    v_result := f_align_binary_point(v_word, old_bin_pt, new_width, new_bin_pt, old_arith);

    if C_DROPPED_BITS > 0 and f_negative_value(v_word, old_arith) and
       f_any_one(v_word, C_DROPPED_BITS - 1, 0, old_arith) then
      return f_plus_one(v_result);
    end if;

    return v_result;
  end function;

  function f_lm_round_floor(inp : std_logic_vector; old_width, old_bin_pt, old_arith,
                             new_width, new_bin_pt, new_arith : integer)
    return std_logic_vector
  is
    variable v_word : std_logic_vector(old_width - 1 downto 0);
  begin
    v_word := inp;
    return f_align_binary_point(v_word, old_bin_pt, new_width, new_bin_pt, old_arith);
  end function;

  function f_lm_round_ceil(inp : std_logic_vector; old_width, old_bin_pt, old_arith,
                            new_width, new_bin_pt, new_arith : integer)
    return std_logic_vector
  is
    constant C_DROPPED_BITS : integer := old_bin_pt - new_bin_pt;
    variable v_word         : std_logic_vector(old_width - 1 downto 0);
    variable v_result       : std_logic_vector(new_width - 1 downto 0);
  begin
    v_word   := inp;
    v_result := f_align_binary_point(v_word, old_bin_pt, new_width, new_bin_pt, old_arith);

    if C_DROPPED_BITS > 0 and f_any_one(v_word, C_DROPPED_BITS - 1, 0, old_arith) then
      return f_plus_one(v_result);
    end if;

    return v_result;
  end function;

  function f_lm_round_even(inp : std_logic_vector; old_width, old_bin_pt, old_arith,
                           new_width, new_bin_pt, new_arith : integer)
    return std_logic_vector
  is
  begin
    return f_nearest_quantized(inp, old_width, old_bin_pt, old_arith,
                               new_width, new_bin_pt, new_arith, C_LM_ROUND_EVEN);
  end function;

  function f_lm_round_tie_pos(inp : std_logic_vector; old_width, old_bin_pt, old_arith,
                              new_width, new_bin_pt, new_arith : integer)
    return std_logic_vector
  is
  begin
    return f_nearest_quantized(inp, old_width, old_bin_pt, old_arith,
                               new_width, new_bin_pt, new_arith, C_LM_ROUND_POS_INF);
  end function;

  function f_lm_round_tie_neg(inp : std_logic_vector; old_width, old_bin_pt, old_arith,
                              new_width, new_bin_pt, new_arith : integer)
    return std_logic_vector
  is
  begin
    return f_nearest_quantized(inp, old_width, old_bin_pt, old_arith,
                               new_width, new_bin_pt, new_arith, C_LM_ROUND_NEG_INF);
  end function;

  function f_lm_round_tie_zero(inp : std_logic_vector; old_width, old_bin_pt, old_arith,
                               new_width, new_bin_pt, new_arith : integer)
    return std_logic_vector
  is
  begin
    return f_nearest_quantized(inp, old_width, old_bin_pt, old_arith,
                               new_width, new_bin_pt, new_arith, C_LM_ROUND_ZERO);
  end function;

  function f_lm_round_tie_away(inp : std_logic_vector; old_width, old_bin_pt, old_arith,
                               new_width, new_bin_pt, new_arith : integer)
    return std_logic_vector
  is
  begin
    return f_nearest_quantized(inp, old_width, old_bin_pt, old_arith,
                               new_width, new_bin_pt, new_arith, C_LM_ROUND_AWAY);
  end function;

  function f_lm_saturate(inp : std_logic_vector;
                          new_width, new_bin_pt, new_arith,
                          old_width, old_bin_pt, old_arith : integer)
    return std_logic_vector
  is
    constant C_ALIGNED_WIDTH : integer := f_lm_max(new_width, old_width + f_abs_int(new_bin_pt - old_bin_pt) + 1);
    variable v_word          : std_logic_vector(old_width - 1 downto 0);
    variable v_aligned       : std_logic_vector(C_ALIGNED_WIDTH - 1 downto 0);
  begin
    v_word    := inp;
    v_aligned := f_align_binary_point(v_word, old_bin_pt, C_ALIGNED_WIDTH, new_bin_pt, old_arith);

    if new_arith = C_LM_SIGNED then
      if old_arith = C_LM_SIGNED then
        if f_fits_signed_width(v_aligned, new_width) then
          return f_lm_sign_ext(v_aligned, new_width);
        elsif v_aligned(C_ALIGNED_WIDTH - 1) = '1' then
          return f_min_signed_word(new_width);
        end if;

        return f_max_signed_word(new_width);
      end if;

      if f_fits_uns_as_sig(v_aligned, new_width) then
        return f_lm_zero_ext(v_aligned, new_width);
      end if;

      return f_max_signed_word(new_width);
    end if;

    if old_arith = C_LM_SIGNED and v_aligned(C_ALIGNED_WIDTH - 1) = '1' then
      return (new_width - 1 downto 0 => '0');
    elsif f_fits_uns_width(v_aligned, new_width) then
      return f_low_bits(v_aligned, new_width, old_arith);
    end if;

    return f_max_unsigned_word(new_width);
  end function;

  function f_lm_wrap(inp : std_logic_vector;
                      new_width, new_bin_pt, new_arith,
                      old_width, old_bin_pt, old_arith : integer)
    return std_logic_vector
  is
    variable v_word : std_logic_vector(old_width - 1 downto 0);
  begin
    v_word := inp;
    return f_align_binary_point(v_word, old_bin_pt, new_width, new_bin_pt, old_arith);
  end function;

  function f_lm_quantize(inp : std_logic_vector;
                          new_width, new_bin_pt, new_arith,
                          old_width, old_bin_pt, old_arith,
                          quantization, overflow : integer)
    return std_logic_vector
  is
    constant C_WORK_WIDTH : integer := f_lm_max(new_width + 1, old_width + f_abs_int(new_bin_pt - old_bin_pt) + 2);
    variable v_word       : std_logic_vector(old_width - 1 downto 0);
    variable v_quantized  : std_logic_vector(C_WORK_WIDTH - 1 downto 0);
  begin
    v_word := inp;

    case quantization is
      when C_LM_CEIL =>
        v_quantized := f_lm_round_ceil(v_word, old_width, old_bin_pt, old_arith,
                                       C_WORK_WIDTH, new_bin_pt, old_arith);
      when C_LM_FLOOR =>
        v_quantized := f_lm_round_floor(v_word, old_width, old_bin_pt, old_arith,
                                        C_WORK_WIDTH, new_bin_pt, old_arith);
      when C_LM_TRUNC_ZERO =>
        v_quantized := f_lm_trunc_zero(v_word, old_width, old_bin_pt, old_arith,
                                       C_WORK_WIDTH, new_bin_pt, old_arith);
      when C_LM_ROUND_EVEN =>
        v_quantized := f_lm_round_even(v_word, old_width, old_bin_pt, old_arith,
                                       C_WORK_WIDTH, new_bin_pt, old_arith);
      when C_LM_ROUND_POS_INF =>
        v_quantized := f_lm_round_tie_pos(v_word, old_width, old_bin_pt, old_arith,
                                          C_WORK_WIDTH, new_bin_pt, old_arith);
      when C_LM_ROUND_NEG_INF =>
        v_quantized := f_lm_round_tie_neg(v_word, old_width, old_bin_pt, old_arith,
                                          C_WORK_WIDTH, new_bin_pt, old_arith);
      when C_LM_ROUND_ZERO =>
        v_quantized := f_lm_round_tie_zero(v_word, old_width, old_bin_pt, old_arith,
                                           C_WORK_WIDTH, new_bin_pt, old_arith);
      when C_LM_ROUND_AWAY =>
        v_quantized := f_lm_round_tie_away(v_word, old_width, old_bin_pt, old_arith,
                                           C_WORK_WIDTH, new_bin_pt, old_arith);
      when others =>
        v_quantized := f_lm_trunc_bits(v_word, old_width, old_bin_pt, old_arith,
                                       C_WORK_WIDTH, new_bin_pt, old_arith);
    end case;

    if overflow = C_LM_SATURATE then
      return f_lm_saturate(v_quantized, new_width, new_bin_pt, new_arith,
                            C_WORK_WIDTH, new_bin_pt, old_arith);
    end if;

    return f_lm_wrap(v_quantized, new_width, new_bin_pt, new_arith,
                      C_WORK_WIDTH, new_bin_pt, old_arith);
  end function;

  function f_lm_sign_ext(inp : std_logic_vector; new_width : integer) return std_logic_vector is
    constant C_WIDTH : integer := inp'length;
    variable v_word  : std_logic_vector(C_WIDTH - 1 downto 0);
    variable v_result : std_logic_vector(new_width - 1 downto 0);
  begin
    v_word   := inp;
    v_result := (others => v_word(C_WIDTH - 1));

    for bit_index in 0 to f_min_int(C_WIDTH, new_width) - 1 loop
      v_result(bit_index) := v_word(bit_index);
    end loop;

    return v_result;
  end function;

  function f_lm_zero_ext(inp : std_logic_vector; new_width : integer) return std_logic_vector is
    constant C_WIDTH : integer := inp'length;
    variable v_word  : std_logic_vector(C_WIDTH - 1 downto 0);
    variable v_result : std_logic_vector(new_width - 1 downto 0) := (others => '0');
  begin
    v_word := inp;

    for bit_index in 0 to f_min_int(C_WIDTH, new_width) - 1 loop
      v_result(bit_index) := v_word(bit_index);
    end loop;

    return v_result;
  end function;

  function f_lm_zero_ext(inp : std_logic; new_width : integer) return std_logic_vector is
    variable v_result : std_logic_vector(new_width - 1 downto 0) := (others => '0');
  begin
    v_result(0) := inp;
    return v_result;
  end function;

  function f_lm_pad_lsb(inp : std_logic_vector; new_width : integer) return std_logic_vector is
    constant C_WIDTH : integer := inp'length;
    constant C_SHIFT : integer := new_width - C_WIDTH;
    variable v_word  : std_logic_vector(C_WIDTH - 1 downto 0);
    variable v_result : std_logic_vector(new_width - 1 downto 0);
    variable v_source : integer;
  begin
    v_word := inp;

    for bit_index in 0 to new_width - 1 loop
      v_source := bit_index - C_SHIFT;
      if v_source >= 0 and v_source < C_WIDTH then
        v_result(bit_index) := v_word(v_source);
      else
        v_result(bit_index) := '0';
      end if;
    end loop;

    return v_result;
  end function;

  function f_lm_pad_lsb(inp : std_logic_vector; new_width, arith : integer) return std_logic_vector is
    constant C_WIDTH : integer := inp'length;
    constant C_SHIFT : integer := new_width - C_WIDTH - 1;
    variable v_word  : std_logic_vector(C_WIDTH - 1 downto 0);
    variable v_result : std_logic_vector(new_width - 1 downto 0);
    variable v_source : integer;
  begin
    v_word := inp;

    for bit_index in 0 to new_width - 1 loop
      v_source := bit_index - C_SHIFT;
      if v_source < 0 then
        v_result(bit_index) := '0';
      elsif v_source < C_WIDTH then
        v_result(bit_index) := v_word(v_source);
      elsif arith = C_LM_SIGNED then
        v_result(bit_index) := v_word(C_WIDTH - 1);
      else
        v_result(bit_index) := '0';
      end if;
    end loop;

    return v_result;
  end function;

  function f_lm_extend_msb(inp : std_logic_vector; new_width, arith : integer) return std_logic_vector is
  begin
    if arith = C_LM_SIGNED then
      return f_lm_sign_ext(inp, new_width);
    end if;

    return f_lm_zero_ext(inp, new_width);
  end function;

end package body lm_math_fi_pkg;
