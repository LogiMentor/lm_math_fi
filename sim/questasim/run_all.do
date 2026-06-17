# =============================================================================
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 LogiMentor
# Run every testbench in sequence. Every TB is self-checking and ends with
# "TEST PASSED" (severity note) or stops simulation with severity failure.
# See TESTPLAN.md for the coverage matrix.
#
# Usage from repository root:
# repo_root="$(pwd -P)"
# mkdir -p "$repo_root/build/questasim"
# vsim -c -l "$repo_root/build/questasim/transcript" -wlf "$repo_root/build/questasim/vsim.wlf" -do "set ::LM_MATH_FI_QUESTASIM_DIR {$repo_root/sim/questasim}; do {$repo_root/sim/questasim/run_all.do}; quit -f"
# =============================================================================

if {![info exists ::LM_MATH_FI_QUESTASIM_DIR]} {
    set ::LM_MATH_FI_QUESTASIM_DIR [file dirname [info script]]
    if {$::LM_MATH_FI_QUESTASIM_DIR eq "." || $::LM_MATH_FI_QUESTASIM_DIR eq ""} {
        set ::LM_MATH_FI_QUESTASIM_DIR [pwd]
    }
}

set TB_LIST [list \
    tb_lm_math_fi_pkg      \
    tb_lm_math_fi_delay    \
    tb_lm_math_fi_format   \
    tb_lm_math_fi_add_sub  \
    tb_lm_math_fi_mult     \
    tb_lm_math_fi_mult_add \
]

onerror {quit -code 1}
onbreak {quit -code 1}

do [file join $::LM_MATH_FI_QUESTASIM_DIR compile_lib.do]

foreach tb $TB_LIST {
    puts "==================================================================="
    puts "== Running $tb"
    puts "==================================================================="
    vcom -2008 -work lm_math_fi_lib [file join $SIM_TB_DIR $tb.vhd]
    vsim -t ps -voptargs="+acc" lm_math_fi_lib.$tb
    run -all
    quit -sim
}

puts "==================================================================="
puts "run_all.do: all testbenches completed. Each TB must emit TEST PASSED."
puts "==================================================================="
