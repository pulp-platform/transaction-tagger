// Copyright 2023 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Diyou Shen 	<dishen@student.ethz.ch>

module tagger_regs_wrap #(
	parameter int unsigned MAXPARTITION = 2,
    parameter int unsigned PATID_LEN 	= 8,
	parameter type reg_req_t = logic,
	parameter type reg_rsp_t = logic,
	parameter type tag_tab_t = logic
) (
	input 	logic 							clk_i,
	input 	logic 							rst_ni,
	input  	reg_req_t 						reg_req_i,
	output 	reg_rsp_t 						reg_rsp_o,
	// To HW
	output 	tag_tab_t [MAXPARTITION-1:0] 	tag_tab_o
);
	import tagger_reg_reg_pkg::* ;
	// localparam int PATID_SIZE = AXI_USER_ID_MSB - AXI_USER_ID_LSB + 1;
	// To track the range information, we use a table to record current 
	// configurtions of the partitions
	tagger_reg_reg_pkg::tagger_reg_hw2reg_t tagger_hw2reg;
	tagger_reg_reg_pkg::tagger_reg_reg2hw_t tagger_reg2hw;

	
	// The following parameters are used to correctly decode the register values and put
	// them into tables for quicker access later.
	
	localparam int unsigned NUM_ENTRY_PER_REG 	= 32/PATID_LEN;
	localparam int unsigned PATID_REG_LEN 		= NUM_ENTRY_PER_REG*PATID_LEN;

	localparam int unsigned NUM_PATID_REG 	= (MAXPARTITION % NUM_ENTRY_PER_REG == 0) ?
											  (MAXPARTITION/NUM_ENTRY_PER_REG) : (MAXPARTITION/NUM_ENTRY_PER_REG+1);
	localparam int unsigned NUM_CONF_REG 	= (MAXPARTITION % 16 == 0) ?
											  (MAXPARTITION/16) : (MAXPARTITION/16+1);
	

	// register top
	tagger_reg_reg_top #(
		.reg_req_t 	( reg_req_t			),
		.reg_rsp_t 	( reg_rsp_t			)
	) i_tagger_reg_top (
		.clk_i,
		.rst_ni,
		// register interface
		.reg_req_i 	( reg_req_i			),
		.reg_rsp_o 	( reg_rsp_o			),
		// from registers to hardware 
		.reg2hw  	( tagger_reg2hw		),
		.hw2reg 	( tagger_hw2reg  	),
		.devmode_i 	( '1 				)
	);

	// pipeline the register configurations
	tag_tab_t [MAXPARTITION-1:0] tag_tab_d, tag_tab_q;
	logic [NUM_CONF_REG*32-1:0] conf_table,conf_temp;

	// Length of patid will be determined by the assigned user bits
	// `patid_table` is used to handle the possible empty spaces in the register
	// These calculations will decode the registers for easier use in other
	// modules
	logic [PATID_REG_LEN*NUM_PATID_REG-1:0] patid_table, patid_temp;

	// Serilize the patid registers
	always_comb begin
		for (int unsigned i = 0; i < NUM_PATID_REG; i++) begin
			// i = 0 => PATID_REG_LEN-1:0; i = 1 => PATID_REG_LEN*2-1:PATID_REG_LEN
			patid_table[(PATID_REG_LEN*(i+1)-1)-:PATID_REG_LEN] = tagger_reg2hw.patid[i].q[PATID_REG_LEN-1:0];
		end
	end

	// Serilize the conf registers
	always_comb begin
		for (int unsigned i = 0; i < NUM_CONF_REG; i++) begin
			conf_table[(32*(i+1)-1)-:32] = tagger_reg2hw.addr_conf[i].q;
		end
	end

	always_comb begin
		tag_tab_d = tag_tab_q;
		// only pass the signal when commit is high
		if (tagger_reg2hw.pat_commit[0].q) begin
			for (int unsigned k = 0; k < MAXPARTITION; k++) begin 
				// shift the corresponding patid and conf to the LSB position
				patid_temp 	= (patid_table 	>> (PATID_LEN*k));
				conf_temp 	= (conf_table 	>> (2*k));
				// 4-byte default size
				tag_tab_d[k].addr[33:2] = tagger_reg2hw.pat_addr[k].q[31:0];
				// read the LSB position patid and conf out	
				tag_tab_d[k].patid 		= patid_temp[PATID_LEN-1:0];
				tag_tab_d[k].conf 		= conf_temp[1:0];
			end
			// clear the commit signal after reading
			tagger_hw2reg.pat_commit[0].de = 1;
			tagger_hw2reg.pat_commit[0].d = 0;
		end
	end

	always_ff @(posedge clk_i, negedge rst_ni) begin
		if (!rst_ni) begin
			tag_tab_q <= 0;
		end else begin
			tag_tab_q <= tag_tab_d;
		end
	end

	assign tag_tab_o = tag_tab_q;

endmodule
