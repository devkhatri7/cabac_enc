# Assuming you are standing in cabac_enc/sim directory

# cabac_enc
vlib cabac_enc
vmap cabac_enc cabac_enc
vcom -2008 -work cabac_enc  ../src/cabac_enc_pkg.vhd
vcom -2008 -work cabac_enc  ../src/cabac_enc.vhd

# tb
vcom -2008 -work cabac_enc  ../tb/tb_cabac_enc.vhd

# simulation
onerror {abort all}
vsim  cabac_enc.tb_cabac_enc
add log -r /*
source ../script/tb_cabac_enc.do
run -all