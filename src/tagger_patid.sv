// Copyright 2023 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Diyou Shen 	<dishen@student.ethz.ch>

/****************************************/
// Take a page from testbench of axi-io-pmp pmp_entry.sv

module tagger_patid #(
	// width of data bus in bits
    parameter int unsigned ADDR_LEN       	= 48,
    // Number of partition supported
    parameter int unsigned MAXPARTITION   	= 8,
    parameter int unsigned TAGGER_GRAN 		= 2
) (
    input  logic 	[ADDR_LEN-1:0] 		addr_i,
    input  logic	[ADDR_LEN-1:0]		conf_addr_prev_i,
    input  logic 	[ADDR_LEN-1:0] 		conf_addr_curr_i,
    input  logic 	[1:0]  				conf_addr_mode_i,
    output logic 						match_o
);
	// This module will compare the incoming address and return the corresponding patid from 
	// registers

	localparam int unsigned OFF = 2'b00;
	localparam int unsigned TOR = 2'b01;
	localparam int unsigned NA4 = 2'b10;
	localparam int unsigned NAPOT = 2'b11;

	logic [ADDR_LEN-1:0] conf_addr_curr_i_mod, conf_addr_prev_i_mod;

	always_comb begin
		conf_addr_curr_i_mod = conf_addr_curr_i;
		conf_addr_prev_i_mod = conf_addr_prev_i;

		if(conf_addr_mode_i == OFF | conf_addr_mode_i == TOR) begin  // OFF or TOR -> force 0 for bits [G-1:0] where G is the granularity
			conf_addr_curr_i_mod[TAGGER_GRAN-1:0] = {TAGGER_GRAN{1'b0}};
			conf_addr_prev_i_mod[TAGGER_GRAN-1:0] = {TAGGER_GRAN{1'b0}};

		end else if (conf_addr_mode_i == NAPOT) begin // NAPOT -> force 1 for bits [G-2:0] where G is the granularity
			conf_addr_curr_i_mod[TAGGER_GRAN-2:0] = {(TAGGER_GRAN-1) {1'b1}};
		end
	end

	logic [$clog2(ADDR_LEN)-1:0] trail_ones;
	logic [ADDR_LEN-1:0] conf_addr_curr_n;
	assign conf_addr_curr_n = ~conf_addr_curr_i_mod;

	lzc #(
		.WIDTH(ADDR_LEN),
		.MODE (1'b0)
	) i_lzc (
		.in_i   (conf_addr_curr_n),
		.cnt_o  (trail_ones),
		.empty_o()
	);

	always_comb begin
		match_o = 1'b0;
		case (conf_addr_mode_i)
			TOR: begin
				if ((conf_addr_prev_i_mod <= addr_i) && (addr_i < conf_addr_curr_i_mod)) begin
					match_o = 1'b1;
				end else begin
					match_o = 1'b0;
				end

				if (match_o == 0) begin
					assert (addr_i >= conf_addr_curr_i_mod || addr_i <  conf_addr_prev_i_mod);
				end else begin
					assert (addr_i <  conf_addr_curr_i_mod && addr_i >= conf_addr_prev_i_mod);
				end
			end

			NA4, NAPOT: begin
				if (conf_addr_mode_i == NA4 && TAGGER_GRAN > 2) begin
					match_o = 1'b0;
				end else begin
					logic [ADDR_LEN-1:0] base;
					logic [ADDR_LEN-1:0] mask;
					int unsigned size;

					if (conf_addr_mode_i == NA4) begin
						size = 0; // NA4 only
					end else begin
						size = trail_ones + 1;
					end

					mask = '1 << size;
					base = (conf_addr_curr_i_mod) & mask;
					match_o = ((addr_i & mask) == base) ? 1'b1: 1'b0;
				
					assert (size >= 0);
					if (conf_addr_mode_i == NAPOT) begin
						assert (size > 0);
						for (int i = 0; i < ADDR_LEN; i ++) begin
							if (size > 1 && i <= size-2) begin
								assert (conf_addr_curr_i_mod[i] == 1);
							end
						end
					end

					if (base + 2 ** size > base) begin  // check for overflow
						if (match_o == 0) begin
							assert (addr_i >= base + 2 ** size || addr_i <  base);
						end else begin
							assert (addr_i <  base + 2 ** size && addr_i >= base);
						end
					end else begin
						if (match_o == 0) begin
							assert (addr_i - 2 ** size >= base || addr_i <  base);
						end else begin
							assert (addr_i - 2 ** size <  base && addr_i >= base);
						end
					end
				end
			end

			default: match_o = 1'b0;

		endcase

	end

endmodule
