// Copyright 2023 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Authors:
// - Diyou Shen <dishen@student.ethz.ch>
//
// Description: Testbench of the tagger module.

/****************************************/
// Take a page from testbench of axi_llc
module tb_tagger #(
	/// width of data bus in bits
    parameter int unsigned TbAxiDataWidthFull   = 32'd64,
    /// width of address bus in bits
    parameter int unsigned TbAxiAddrWidthFull   = 32'd48,
    /// ID width of the Full AXI slave port, master port has ID `AxiIdWidthFull + 32'd1`
  	parameter int unsigned TbAxiIdWidthFull  	= 32'd6,
    /// propagate awuser signal
    parameter int unsigned TbAxiUserWidthFull   = 32'd8,
    /// Number of partition supported
    parameter int unsigned TbMaxPartition   = 8,
    /// User signal offset
    parameter int unsigned TbAxiUserIdMsb 	= 7,
    parameter int unsigned TbAxiUserIdLsb 	= 4,
    /// Granularity of configuration
    parameter int unsigned TbTaggerGran 	= 3,
    /// Cycle time for the TB clock generator
	parameter time         TbCyclTime       = 10ns,
	/// Application time to the DUT
	parameter time         TbApplTime       = 2ns,
	/// Test time of the DUT
	parameter time         TbTestTime       = 8ns,
	parameter int unsigned TbNumAddrConf 	= 4
);

	// Config register addresses
	typedef enum logic [31:0] {
		CommitCfg 	= 32'h00,
		CfgAddr0 	= 32'h04,
		CfgAddr1 	= 32'h08,
		CfgAddr2 	= 32'h0c,
		CfgAddr3 	= 32'h10,
		CfgAddr4 	= 32'h14,
		CfgAddr5 	= 32'h18,
		CfgAddr6 	= 32'h1c,
		CfgAddr7 	= 32'h20,
		CfgPatid0 	= 32'h24,
		CfgConf0 	= 32'h28
	} tagger_cfg_addr_e;

	/////////////////////////////
  	// Axi channel definitions //
  	/////////////////////////////
  	`include "axi/typedef.svh"
  	`include "axi/assign.svh"
  	`include "register_interface/typedef.svh"
  	`include "register_interface/assign.svh"

  	localparam int unsigned TbAxiStrbWidthFull = TbAxiDataWidthFull / 32'd8;

	typedef logic [TbAxiIdWidthFull-1:0]     axi_id_t;
	typedef logic [TbAxiAddrWidthFull-1:0]   axi_addr_t;
	typedef logic [TbAxiDataWidthFull-1:0]   axi_data_t;
	typedef logic [TbAxiStrbWidthFull-1:0]   axi_strb_t;
	typedef logic [TbAxiUserWidthFull-1:0]   axi_user_t;

	`AXI_TYPEDEF_AW_CHAN_T(axi_aw_t, axi_addr_t, axi_id_t, axi_user_t)
	`AXI_TYPEDEF_W_CHAN_T(axi_w_t, axi_data_t, axi_strb_t, axi_user_t)
	`AXI_TYPEDEF_B_CHAN_T(axi_b_t, axi_id_t, axi_user_t)
	`AXI_TYPEDEF_AR_CHAN_T(axi_ar_t, axi_addr_t, axi_id_t, axi_user_t)
	`AXI_TYPEDEF_R_CHAN_T(axi_r_t, axi_data_t, axi_id_t, axi_user_t)

	`AXI_TYPEDEF_REQ_T(axi_req_t, axi_aw_t, axi_w_t, axi_ar_t)
	`AXI_TYPEDEF_RESP_T(axi_resp_t, axi_b_t, axi_r_t)

	`REG_BUS_TYPEDEF_ALL(conf, logic [31:0], logic [31:0], logic [3:0])

	typedef logic [7:0] byte_t;

	typedef struct packed {
		axi_addr_t 		addr;
		logic [31:0]	size;
		axi_user_t 		patid;
	} addr_conf_t;

	logic 		  	aw_error, ar_error;
	logic [1:0] 	addr_mode;
	axi_user_t 		aw_patid_ref, aw_patid_act, ar_patid_ref, ar_patid_act;
	

	////////////////////////////////
	// Stimuli generator typedefs //
	////////////////////////////////
	typedef axi_test::axi_rand_master #(
	.AW                   ( TbAxiAddrWidthFull ),
	.DW                   ( TbAxiDataWidthFull ),
	.IW                   ( TbAxiIdWidthFull   ),
	.UW                   ( TbAxiUserWidthFull ),
	.TA                   ( TbApplTime         ),
	.TT                   ( TbTestTime         ),
	.MAX_READ_TXNS        ( 5                  ),
	.MAX_WRITE_TXNS       ( 5                  ),
	.AX_MIN_WAIT_CYCLES   ( 0                  ),
	.AX_MAX_WAIT_CYCLES   ( 50                 ),
	.W_MIN_WAIT_CYCLES    ( 0                  ),
	.W_MAX_WAIT_CYCLES    ( 0                  ),
	.RESP_MIN_WAIT_CYCLES ( 0                  ),
	.RESP_MAX_WAIT_CYCLES ( 0                  ),
	.AXI_BURST_FIXED      ( 1'b0               ),
	.AXI_BURST_INCR       ( 1'b1               ),
	.AXI_BURST_WRAP       ( 1'b0               )
	) axi_rand_master_t;

	typedef axi_test::axi_rand_slave #(
	.AW                   ( TbAxiAddrWidthFull        ),
	.DW                   ( TbAxiDataWidthFull        ),
	.IW                   ( TbAxiIdWidthFull		  ),
	.UW                   ( TbAxiUserWidthFull        ),
	.TA                   ( TbApplTime                ),
	.TT                   ( TbTestTime                ),
	.AX_MIN_WAIT_CYCLES   ( 0                         ),
	.AX_MAX_WAIT_CYCLES   ( 50                        ),
	.R_MIN_WAIT_CYCLES    ( 10                        ),
	.R_MAX_WAIT_CYCLES    ( 20                        ),
	.RESP_MIN_WAIT_CYCLES ( 10                        ),
	.RESP_MAX_WAIT_CYCLES ( 20                        ),
	.MAPPED               ( 1'b1                      )
	) axi_rand_slave_t;

	// Standard 32-bit RegBus
	typedef reg_test::reg_driver #(
	.AW ( 32'd32      ),
	.DW ( 32'd32      ),
	.TA ( TbApplTime  ),
	.TT ( TbTestTime  )
	) regbus_conf_driver_t;

	typedef axi_test::axi_scoreboard #(
	.IW( TbAxiIdWidthFull   ),
	.AW( TbAxiAddrWidthFull ),
	.DW( TbAxiDataWidthFull ),
	.UW( TbAxiUserWidthFull ),
	.TT( TbTestTime         )
	) axi_scoreboard_cpu_t;

	typedef axi_test::axi_scoreboard #(
	.IW( TbAxiIdWidthFull   ),
	.AW( TbAxiAddrWidthFull ),
	.DW( TbAxiDataWidthFull ),
	.UW( TbAxiUserWidthFull ),
	.TT( TbTestTime         )
	) axi_scoreboard_mem_t;

  	/////////////////
	// Dut signals //
	/////////////////
	logic clk, rst_n, test;

	// AXI channels
	axi_req_t  axi_cpu_req, axi_mem_req;
	axi_resp_t axi_cpu_rsp, axi_mem_rsp;
	conf_req_t     reg_cfg_req;
	conf_rsp_t     reg_cfg_rsp;
	// Tb signals
	logic enable_counters, print_counters, enable_progress;

	addr_conf_t [TbNumAddrConf-1:0] addr_conf;

	localparam int unsigned TbTorAddr0 		= 32'h2000_0000;
	localparam int unsigned TbTorAddr1 		= 32'h4000_0000;
	localparam int unsigned TbTorAddr2 		= 32'h6000_0000;
	localparam int unsigned TbTorAddr3 		= 32'h8000_0000;
	localparam int unsigned TbNapotAddr0 	= 32'h2000_0000;
	localparam int unsigned TbNapotAddr1 	= 32'h4000_0000;
	localparam int unsigned TbNapotAddr2 	= 32'h6000_0000;
	localparam int unsigned TbNapotAddr3 	= 32'h8000_0000;
	localparam int unsigned TbNapotSize0 	= 32'h07FF_FFFF;
	localparam int unsigned TbNapotSize1 	= 32'h03FF_FFFF;
	localparam int unsigned TbNapotSize2 	= 32'h07FF_FFFF;
	localparam int unsigned TbNapotSize3 	= 32'h07FF_FFFF;

	

	///////////////////////
	// AXI DV interfaces //
	///////////////////////
	AXI_BUS_DV #(
		.AXI_ADDR_WIDTH ( TbAxiAddrWidthFull ),
		.AXI_DATA_WIDTH ( TbAxiDataWidthFull ),
		.AXI_ID_WIDTH   ( TbAxiIdWidthFull   ),
		.AXI_USER_WIDTH ( TbAxiUserWidthFull )
	) axi_cpu_intf_dv (
		.clk_i ( clk )
	);

	AXI_BUS_DV #(
		.AXI_ADDR_WIDTH ( TbAxiAddrWidthFull ),
		.AXI_DATA_WIDTH ( TbAxiDataWidthFull ),
		.AXI_ID_WIDTH   ( TbAxiIdWidthFull   ),
		.AXI_USER_WIDTH ( TbAxiUserWidthFull )
	) score_cpu_intf_dv (
		.clk_i ( clk )
	);

	AXI_BUS_DV #(
		.AXI_ADDR_WIDTH ( TbAxiAddrWidthFull ),
		.AXI_DATA_WIDTH ( TbAxiDataWidthFull ),
		.AXI_ID_WIDTH   ( TbAxiIdWidthFull   ),
		.AXI_USER_WIDTH ( TbAxiUserWidthFull )
	) axi_mem_intf_dv (
		.clk_i ( clk )
	);

	AXI_BUS_DV #(
		.AXI_ADDR_WIDTH ( TbAxiAddrWidthFull ),
		.AXI_DATA_WIDTH ( TbAxiDataWidthFull ),
		.AXI_ID_WIDTH   ( TbAxiIdWidthFull 	 ),
		.AXI_USER_WIDTH ( TbAxiUserWidthFull )
	) score_mem_intf_dv (
		.clk_i ( clk )
	);

	REG_BUS #(
		.ADDR_WIDTH ( 32'd32 ),
		.DATA_WIDTH ( 32'd32 )
	) reg_cfg_intf (
		.clk_i ( clk )
	);

	`AXI_ASSIGN_TO_REQ(axi_cpu_req, axi_cpu_intf_dv)
	`AXI_ASSIGN_FROM_RESP(axi_cpu_intf_dv, axi_cpu_rsp)

	`AXI_ASSIGN_FROM_REQ(axi_mem_intf_dv, axi_mem_req)
	`AXI_ASSIGN_TO_RESP(axi_mem_rsp, axi_mem_intf_dv)

	`AXI_ASSIGN_MONITOR(score_cpu_intf_dv, axi_cpu_intf_dv)
	`AXI_ASSIGN_MONITOR(score_mem_intf_dv, axi_mem_intf_dv)

	`REG_BUS_ASSIGN_TO_REQ(reg_cfg_req, reg_cfg_intf)
	`REG_BUS_ASSIGN_FROM_RSP(reg_cfg_intf, reg_cfg_rsp)

	////////////////////
	// Address Ranges //
	////////////////////
	localparam axi_addr_t AddrStart = axi_addr_t'(0);
	localparam axi_addr_t AddrLen	= axi_addr_t'(32'h8000_0000);
  	/////////////////////////
	// Clock and Reset gen //
	/////////////////////////
	clk_rst_gen #(
		.ClkPeriod     ( TbCyclTime ),
		.RstClkCycles  ( 32'd5    )
	) i_clk_rst_gen (
		.clk_o  ( clk   ),
		.rst_no ( rst_n )
	);
	assign test = 1'b0;

	/////////////////////////
	// Main Test 		   //
	/////////////////////////

	initial begin : proc_sim_crtl
		automatic axi_scoreboard_cpu_t   cpu_scoreboard  = new( score_cpu_intf_dv );
	    automatic axi_scoreboard_mem_t   mem_scoreboard  = new( score_mem_intf_dv );
	    automatic axi_rand_master_t      axi_master      = new( axi_cpu_intf_dv   );
	    automatic regbus_conf_driver_t   reg_conf_driver = new( reg_cfg_intf      );
	    // Variables for the RegBus configuration transactions.
	    automatic logic[31:0]     cfg_addr    = 32'd0;
	    automatic logic[31:0]     cfg_data    = 32'd0;
	    automatic logic[ 3:0]     cfg_wstrb   =  4'd0;
	    automatic logic           cfg_error   =  1'b0;


		addr_conf = '0;
		addr_mode = '0;
		

	    // Reset the AXI drivers and scoreboards
	    cpu_scoreboard.reset();
	    mem_scoreboard.reset();
	    axi_master.reset();
	    reg_conf_driver.reset_master();
	    enable_counters = 1'b0;
	    print_counters  = 1'b0;
	    enable_progress = 1'b0;

	    axi_master.add_memory_region(AddrStart,AddrLen,
                                 	 axi_pkg::NORMAL_NONCACHEABLE_BUFFERABLE);

	    cpu_scoreboard.enable_all_checks();
    	mem_scoreboard.enable_all_checks();

	    @(posedge rst_n);
	    cpu_scoreboard.monitor();
	    mem_scoreboard.monitor();
	    enable_counters = 1'b1;
	    enable_progress = 1'b1;

	    $info("Start NAPOT test");
	    addr_conf[0].addr |= TbNapotAddr0;
		addr_conf[1].addr |= TbNapotAddr1;
		addr_conf[2].addr |= TbNapotAddr2;
		addr_conf[3].addr |= TbNapotAddr3;

		addr_conf[0].size |= TbNapotSize0;
		addr_conf[1].size |= TbNapotSize1;
		addr_conf[2].size |= TbNapotSize2;
		addr_conf[3].size |= TbNapotSize3;

		addr_conf[0].patid |= 8'd0;
		addr_conf[1].patid |= 8'd1;
		addr_conf[2].patid |= 8'd2;
		addr_conf[3].patid |= 8'd3;

	    addr_mode = 2'b11;

	    napot_test(reg_conf_driver);
	    // Randomize patid and test 0
		$info("Random read and write");
		axi_master.run(100, 100);
		addr_mode = 2'b00;
		addr_conf = '0;
		

		$info("Start TOR test");
		addr_conf[0].addr |= TbTorAddr0;
		addr_conf[1].addr |= TbTorAddr1;
		addr_conf[2].addr |= TbTorAddr2;
		addr_conf[3].addr |= TbTorAddr3;

		addr_conf[0].patid |= 8'd7;
		addr_conf[1].patid |= 8'd6;
		addr_conf[2].patid |= 8'd5;
		addr_conf[3].patid |= 8'd4;

		addr_mode = 2'b01;
		
	    tor_test(reg_conf_driver);
	    // Randomize patid and test 1
		$info("Random read and write");
		axi_master.run(100, 100);
		addr_mode = 2'b00;
		addr_conf = '0;

		$display("Tests ended!");
		$finish();
	end

	initial begin : proc_sim_mem
    	automatic axi_rand_slave_t axi_slave = new( axi_mem_intf_dv );
    	axi_slave.reset();
    	@(posedge rst_n);
    	axi_slave.run();
  	end


	task napot_test(regbus_conf_driver_t reg_conf_driver);
		automatic logic 		cfg_error;
		automatic logic[31:0]	addr0 = ((TbNapotAddr0+TbNapotSize0)>>2);
		automatic logic[31:0] 	addr1 = ((TbNapotAddr1+TbNapotSize1)>>2);
		automatic logic[31:0]	addr2 = ((TbNapotAddr2+TbNapotSize2)>>2);
		automatic logic[31:0] 	addr3 = ((TbNapotAddr3+TbNapotSize3)>>2);
		automatic logic[31:0]	patid = 32'h7654_3210;
		automatic logic[31:0] 	conf = 32'h0000_00FF;
		automatic logic[31:0] 	commit = 32'd1;
		$info("Configuring registers for NAPOT mode!");
		reg_conf_driver.send_write(CfgAddr0, 	addr0, 		4'hF, cfg_error);
		reg_conf_driver.send_write(CfgAddr1, 	addr1, 		4'hF, cfg_error);
		reg_conf_driver.send_write(CfgAddr2, 	addr2, 		4'hF, cfg_error);
		reg_conf_driver.send_write(CfgAddr3, 	addr3, 		4'hF, cfg_error);
		reg_conf_driver.send_write(CfgPatid0, 	patid, 		4'hF, cfg_error);
		reg_conf_driver.send_write(CfgConf0, 	conf, 		4'hF, cfg_error);
		$info("Committing changes...");
		reg_conf_driver.send_write(CommitCfg, 	commit, 	4'hF, cfg_error);
		$info("Finished partitioning configuration!");
	endtask:napot_test

	task tor_test(regbus_conf_driver_t reg_conf_driver);
		automatic logic 		cfg_error;

		automatic logic[31:0]	addr0 = (TbTorAddr0>>2);
		automatic logic[31:0] 	addr1 = (TbTorAddr1>>2);
		automatic logic[31:0]	addr2 = (TbTorAddr2>>2);
		automatic logic[31:0] 	addr3 = (TbTorAddr3>>2);
		automatic logic[31:0]	patid = 32'h0123_4567;
		automatic logic[31:0] 	conf = 32'h0000_0055;
		automatic logic[31:0] 	commit = 32'd1;
		$info("Configuring registers for NAPOT mode!");
		reg_conf_driver.send_write(CfgAddr0, 	addr0, 		4'hF, cfg_error);
		reg_conf_driver.send_write(CfgAddr1, 	addr1, 		4'hF, cfg_error);
		reg_conf_driver.send_write(CfgAddr2, 	addr2, 		4'hF, cfg_error);
		reg_conf_driver.send_write(CfgAddr3, 	addr3, 		4'hF, cfg_error);
		reg_conf_driver.send_write(CfgPatid0, 	patid, 		4'hF, cfg_error);
		reg_conf_driver.send_write(CfgConf0, 	conf, 		4'hF, cfg_error);
		$info("Committing changes...");
		reg_conf_driver.send_write(CommitCfg, 	commit, 	4'hF, cfg_error);
		$info("Finished partitioning configuration!");
	endtask : tor_test

	assert property (@(posedge clk) rst_n |-> aw_error == '0);
	assert property (@(posedge clk) rst_n |-> ar_error == '0);

	///////////////////////
	// Design under test //
	///////////////////////
	tagger #(
		.DATA_WIDTH       	( TbAxiDataWidthFull  	),
		.ADDR_WIDTH       	( TbAxiAddrWidthFull    ),
		.ID_WIDTH         	( TbAxiIdWidthFull		),
		.USER_WIDTH       	( TbAxiUserWidthFull    ),
		.MAXPARTITION     	( TbMaxPartition    	),
		.AXI_USER_ID_MSB  	( TbAxiUserIdMsb   		),
		.AXI_USER_ID_LSB  	( TbAxiUserIdLsb 		),
		.TAGGER_GRAN      	( TbTaggerGran      	),
		.axi_req_t        	( axi_req_t     		),
		.axi_rsp_t        	( axi_resp_t     		),
		.reg_req_t        	( conf_req_t         	),
		.reg_rsp_t        	( conf_rsp_t         	)
	) i_tagger_dut (
		.clk_i				( clk 				),
		.rst_ni				( rst_n 			),
		.slv_req_i  		( axi_cpu_req   	),
		.slv_rsp_o  		( axi_cpu_rsp   	),
		.mst_req_o  		( axi_mem_req   	),
		.mst_rsp_i  		( axi_mem_rsp   	),
		.cfg_req_i  		( reg_cfg_req		),
		.cfg_rsp_o  		( reg_cfg_rsp  		)
	);

	user_checker #(
	    .AXI_USER_ID_MSB 	( TbAxiUserIdMsb 	),
	    .AXI_USER_ID_LSB 	( TbAxiUserIdLsb 	),
	    .NUM_ADDR_CONF		( TbNumAddrConf 	),
	    .axi_req_t      	( axi_req_t 		),
	    .axi_user_t 		( axi_user_t 		),
	    .axi_addr_t 		( axi_addr_t 		),
	    .addr_conf_t 		( addr_conf_t 		)
	) i_patid_check (
		.clk_i				( clk 				),
		.rst_ni				( rst_n 			),
		.slv_req_i 			( axi_mem_req 		),
    	.mode_i				( addr_mode			),
	    .addr_conf_i  		( addr_conf 		),
   		.aw_error_o			( aw_error 			),
   		.aw_patid_ref_o 	( aw_patid_ref 		),
		.aw_patid_act_o		( aw_patid_act 		),
    	.ar_error_o			( ar_error 			),
    	.ar_patid_ref_o 	( ar_patid_ref 		),
		.ar_patid_act_o		( ar_patid_act 		)
	);
endmodule
