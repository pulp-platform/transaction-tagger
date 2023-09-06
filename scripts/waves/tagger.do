add wave -position insertpoint  \
sim:/tb_tagger/i_tagger_dut/clk_i
add wave -position insertpoint  \
sim:/tb_tagger/i_tagger_dut/rst_ni
add wave -position insertpoint  \
sim:/tb_tagger/i_tagger_dut/mst_req_o.aw.user
add wave -position insertpoint  \
sim:/tb_tagger/i_tagger_dut/mst_req_o.ar.user
add wave -position insertpoint  \
sim:/tb_tagger/i_tagger_dut/AXI_USER_ID_MSB
add wave -position insertpoint  \
sim:/tb_tagger/i_tagger_dut/AXI_USER_ID_LSB
add wave -position insertpoint  \
sim:/tb_tagger/i_tagger_dut/tag_tab
add wave -position insertpoint  \
sim:/tb_tagger/i_tagger_dut/patid_r
add wave -position insertpoint  \
sim:/tb_tagger/i_tagger_dut/patid_w
add wave -position insertpoint  \
sim:/tb_tagger/i_tagger_dut/match_r
add wave -position insertpoint  \
sim:/tb_tagger/i_tagger_dut/match_w
add wave -position insertpoint  \
sim:/tb_tagger/i_tagger_dut/mst_req_o.ar.user
add wave -position insertpoint  \
sim:/tb_tagger/i_tagger_dut/mst_req_o.ar.addr
add wave -position insertpoint  \
sim:/tb_tagger/i_tagger_dut/mst_req_o.aw.user
add wave -position insertpoint  \
sim:/tb_tagger/i_tagger_dut/mst_req_o.aw.addr


add wave -position insertpoint  \
sim:/tb_tagger/i_patid_check/ar_error_o
add wave -position insertpoint  \
sim:/tb_tagger/i_patid_check/ar_patid_ref_o \
sim:/tb_tagger/i_patid_check/ar_patid_act_o

add wave -position insertpoint  \
sim:/tb_tagger/i_patid_check/aw_error_o
add wave -position insertpoint  \
sim:/tb_tagger/i_patid_check/aw_patid_ref_o \
sim:/tb_tagger/i_patid_check/aw_patid_act_o