onerror {resume}
quietly WaveActivateNextPane {} 0
set WildcardFilter [lsearch -not -all -inline $$WildcardFilter Memory]

# Testbnech
add wave -noupdate -group Testbench /tb_top/*

# Top
add wave -noupdate -group TOP /tb_top/inst_top/*

# RISCV interface
add wave -noupdate -group RISCV_ITF /tb_top/inst_top/inst_ap_ctrl_bus/*

# Cache model
add wave -noupdate -group cache_model /tb_top/cache/*

# HLS
${observe_signal}
