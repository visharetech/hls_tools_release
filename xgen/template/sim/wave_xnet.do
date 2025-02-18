set scalar_bank     8
set array_bank      4
set cyclic_bank     4

onerror {resume}
quietly WaveActivateNextPane {} 0
set WildcardFilter [lsearch -not -all -inline $WildcardFilter Memory]

#TESTBENCH
add wave -noupdate -divider TESTBENCH
add wave -noupdate /tb_xnet/t
add wave -noupdate /tb_xnet/f
add wave -noupdate -group testbench /tb_xnet/*

#CUSTOM CONNECTION
add wave -noupdate -divider CUSTOM_CONNECT
add wave -noupdate -group custom_connection /tb_xnet/inst_custom_connection/*

#XEMEM
add wave -noupdate -divider XMEM
add wave -noupdate -group xmem_top    /tb_xnet/inst_xmem/*
add wave -noupdate -group bank_filter /tb_xnet/inst_xmem/inst_bank_filter/*
for {set b 0}  {$b < $scalar_bank} {incr b} {
	set scalar "SCALAR\[$b\]"
	set port0 "DP\[0\]"
	set port1 "DP\[1\]"
	add wave -noupdate -group scalar${b}_reqMux0 /tb_xnet/inst_xmem/$scalar/$port0/inst_reqMux_scalar/*
	add wave -noupdate -group scalar${b}_reqMux1 /tb_xnet/inst_xmem/$scalar/$port1/inst_reqMux_scalar/*
}
for {set b 0}  {$b < $array_bank} {incr b} {
	set array "ARRAY\[$b\]"
	add wave -noupdate -group array${b}_reqMux /tb_xnet/inst_xmem/$array/inst_reqMux_array/*
}
for {set b 0}  {$b < $cyclic_bank} {incr b} {
	set cyclic "CYCLIC\[$b\]"
	add wave -noupdate -group cyclic${b}_reqMux /tb_xnet/inst_xmem/$cyclic/inst_reqMux_cyclic/*
}	

TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 200
configure wave -valuecolwidth 200
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -timeline 0
configure wave -timelineunits ps
update