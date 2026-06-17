# =============================================================================
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 LogiMentor
# Compile script for the lm_math_fi_lib library
# Usage   : do compile_lib.do
# Sources : ../../src/*.vhd
# =============================================================================

if {[info exists ::LM_MATH_FI_QUESTASIM_DIR]} {
    set SCRIPT_DIR $::LM_MATH_FI_QUESTASIM_DIR
} else {
    set SCRIPT_DIR [file dirname [info script]]
    if {$SCRIPT_DIR eq "." || $SCRIPT_DIR eq ""} {
        set SCRIPT_DIR [pwd]
    }
}
set REPO_ROOT  [file join $SCRIPT_DIR ../..]
set SRC        [file join $REPO_ROOT src]
set SIM_TB_DIR [file join $REPO_ROOT sim tb]
set BUILD_DIR  [file join $REPO_ROOT build questasim]

file mkdir $BUILD_DIR
cd $BUILD_DIR

foreach lib [list lm_math_fi_lib work] {
    if {[file exists $lib]} {
        if {[catch {vdel -all -lib $lib} msg]} {
            puts "compile_lib.do: removing stale library '$lib' after vdel failed: $msg"
            file delete -force $lib
        }
    }
}

vlib lm_math_fi_lib
vmap lm_math_fi_lib lm_math_fi_lib
vlib work

vcom -2008 -work lm_math_fi_lib $SRC/lm_math_fi_pkg.vhd
vcom -2008 -work lm_math_fi_lib $SRC/lm_math_fi_delay.vhd
vcom -2008 -work lm_math_fi_lib $SRC/lm_math_fi_format.vhd
vcom -2008 -work lm_math_fi_lib $SRC/lm_math_fi_add_sub.vhd
vcom -2008 -work lm_math_fi_lib $SRC/lm_math_fi_mult.vhd
vcom -2008 -work lm_math_fi_lib $SRC/lm_math_fi_mult_add.vhd
vcom -2008 -work lm_math_fi_lib [file join $SIM_TB_DIR tb_lm_math_fi_test_pkg.vhd]

puts "compile_lib.do: lm_math_fi_lib compiled."
