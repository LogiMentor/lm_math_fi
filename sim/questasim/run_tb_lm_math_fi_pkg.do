# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 LogiMentor

if {![info exists ::LM_MATH_FI_QUESTASIM_DIR]} {
    set ::LM_MATH_FI_QUESTASIM_DIR [file dirname [info script]]
    if {$::LM_MATH_FI_QUESTASIM_DIR eq "." || $::LM_MATH_FI_QUESTASIM_DIR eq ""} {
        set ::LM_MATH_FI_QUESTASIM_DIR [pwd]
    }
}
onerror {quit -code 1}
onbreak {quit -code 1}
do [file join $::LM_MATH_FI_QUESTASIM_DIR compile_lib.do]
vcom -2008 -work lm_math_fi_lib [file join $SIM_TB_DIR tb_lm_math_fi_pkg.vhd]
vsim -t ps -voptargs="+acc" lm_math_fi_lib.tb_lm_math_fi_pkg
run -all
