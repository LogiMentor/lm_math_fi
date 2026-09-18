-- SPDX-License-Identifier: Apache-2.0
-- Copyright 2026 LogiMentor
--
-- Generic-domain negative testbench for lm_math_fi_pkg.f_lm_quantize.
--
-- THIS DESIGN IS EXPECTED TO FAIL, once per case.
--
-- The generics below mirror the rounding and overflow arguments of
-- f_lm_quantize, with legal defaults. A case is selected by overriding exactly one
-- of them from the command line, for example:
--
--   ghdl -r tb_neg_pkg -g<generic>=<illegal value>
--
-- Run with no override, every value is legal and the guard process reports
-- GENERIC DOMAIN TB COMPLETED. scripts/run_ghdl_generic_domain_tests.py uses
-- that run to prove the defaults really are legal, then uses one run per case
-- to prove each illegal value is rejected.
--
-- These units are deliberately not part of scripts/run_ghdl_tests.py or
-- sim/questasim/run_all.do and must never be added to either.

library ieee;
use ieee.std_logic_1164.all;

library lm_math_fi_lib;
use lm_math_fi_lib.lm_math_fi_pkg.all;

entity tb_neg_pkg is
  generic(
    g_round_mode : natural := C_LM_TRUNC_BITS;
    g_overflow   : natural := C_LM_WRAP
    );
end entity tb_neg_pkg;

architecture a_tb of tb_neg_pkg is
  signal s_result : std_logic_vector(3 downto 0);
begin

  -- Calls the package function directly rather than through an entity, so the
  -- package diagnostic is observed on its own instead of being pre-empted by an
  -- entity-level assertion that would see the same value first.
  s_result <= f_lm_quantize("101101",
                            4, 1, C_LM_UNSIGNED,
                            6, 2, C_LM_UNSIGNED,
                            g_round_mode, g_overflow);

  -- Emitted at the first simulation delta. A case that is supposed to be
  -- rejected by a generic's subtype must never reach this: the design does
  -- not elaborate, so simulation never starts. The runner uses the absence
  -- of this marker as its phase check, independently of anything the
  -- simulator chooses to print.
  proc_started : process
  begin
    report "GENERIC DOMAIN TB STARTED: tb_neg_pkg" severity note;
    wait;
  end process proc_started;

  proc_guard : process
  begin
    wait for 50 ns;
    report "GENERIC DOMAIN TB COMPLETED: tb_neg_pkg" severity note;
    wait;
  end process proc_guard;

end architecture a_tb;
