onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb_cabac_enc/Clk
add wave -noupdate /tb_cabac_enc/Input
add wave -noupdate /tb_cabac_enc/InputLen
add wave -noupdate /tb_cabac_enc/ctxIdx
add wave -noupdate /tb_cabac_enc/SliceQPY
add wave -noupdate /tb_cabac_enc/initType
add wave -noupdate /tb_cabac_enc/Resetn
add wave -noupdate /tb_cabac_enc/Start
add wave -noupdate /tb_cabac_enc/Output
add wave -noupdate /tb_cabac_enc/OutputLen
add wave -noupdate /tb_cabac_enc/BypassI
add wave -noupdate /tb_cabac_enc/BypassO
add wave -noupdate /tb_cabac_enc/TermI
add wave -noupdate /tb_cabac_enc/TermO
add wave -noupdate /tb_cabac_enc/Finished
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {2269420 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 197
configure wave -valuecolwidth 40
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ps
update
WaveRestoreZoom {0 ps} {3955759 ps}
