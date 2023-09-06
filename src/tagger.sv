// Copyright 2023 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Diyou Shen   <dishen@student.ethz.ch>
// Hong Pang    <hopang@student.ethz.ch>

module tagger #(
  // width of data bus in bits
  parameter int unsigned DATA_WIDTH      = 64,
  // width of address bus in bits
  parameter int unsigned ADDR_WIDTH      = 64,
  // Number of partition supported
  parameter int unsigned MAXPARTITION    = 16,
  // LLC user signal offset
  parameter int unsigned AXI_USER_ID_MSB = 7,
  parameter int unsigned AXI_USER_ID_LSB = 0,
  // Granularity of configuration
  parameter int unsigned TAGGER_GRAN     = 0,
  // AXI request/response
  parameter type         axi_req_t       = logic,
  parameter type         axi_rsp_t       = logic,
  // register interface request/response
  parameter type         reg_req_t       = logic,
  parameter type         reg_rsp_t       = logic
) (
  // rising-edge clock
  input  logic     clk_i,
  // asynchronous reset, active low
  input  logic     rst_ni,
  // slave port
  input  axi_req_t slv_req_i,
  output axi_rsp_t slv_rsp_o,
  // master port
  output axi_req_t mst_req_o,
  input  axi_rsp_t mst_rsp_i,
  // configuration port
  input  reg_req_t cfg_req_i,
  output reg_rsp_t cfg_rsp_o
);

  import tagger_reg_reg_pkg::*;

  localparam int unsigned PATID_LEN = AXI_USER_ID_MSB - AXI_USER_ID_LSB + 1;

  reg_req_t cfg_req_mod;
  reg_rsp_t cfg_rsp_mod;
  // patid
  logic [PATID_LEN-1:0] patid_r, patid_w;
  // previous and current configure address
  logic [MAXPARTITION-1:0][ADDR_WIDTH-1:0]
    conf_addr_curr_r, conf_addr_curr_w, conf_addr_prev_r, conf_addr_prev_w;
  // match signals
  logic [MAXPARTITION-1:0] match_r, match_w;
  // current incoming address
  logic [ADDR_WIDTH-1:0] tagger_addr_r, tagger_addr_w;
  // counting the trailing zeros to determine the first match signal
  // if an address matches two or more tagger regions, which is a configuration error,
  // this algorithm will always select the lower partition
  logic [$clog2(MAXPARTITION)-1:0] trail_zero_r, trail_zero_w;
  logic empty_r, empty_w;

  typedef struct packed {
    // logic [7:0]      patid;
    logic [PATID_LEN-1:0] patid;
    logic [ADDR_WIDTH-1:0] addr;
    logic [1:0] conf;
  } tag_tab_t;

  tag_tab_t [MAXPARTITION-1:0] tag_tab;

  always_comb begin
    cfg_rsp_o   = cfg_rsp_mod;
    cfg_req_mod = cfg_req_i;
  end


  // To track the range information, we use a table to record current
  // configurtions of the partitions
  tagger_reg_reg_pkg::tagger_reg_hw2reg_t tagger_hw2reg;
  tagger_reg_reg_pkg::tagger_reg_reg2hw_t tagger_reg2hw;

  // register top
  tagger_regs_wrap #(
    .MAXPARTITION(MAXPARTITION),
    .PATID_LEN   (PATID_LEN),
    .reg_req_t   (reg_req_t),
    .reg_rsp_t   (reg_rsp_t),
    .tag_tab_t   (tag_tab_t)
  ) i_tagger_regs_top (
    .clk_i,
    .rst_ni,
    // register interface
    .reg_req_i(cfg_req_mod),
    .reg_rsp_o(cfg_rsp_mod),
    // from registers to hardware
    .tag_tab_o(tag_tab)
  );


  // Read Channel Tagging
  assign tagger_addr_r = slv_req_i.ar.addr;

  for (genvar i = 0; i < MAXPARTITION; i++) begin
    assign conf_addr_prev_r[i] = (i == 0) ? '0 : tag_tab[i-1].addr;
    assign conf_addr_curr_r[i] = tag_tab[i].addr;
    tagger_patid #(
      .ADDR_LEN    (ADDR_WIDTH),
      .MAXPARTITION(MAXPARTITION),
      .TAGGER_GRAN (TAGGER_GRAN)
    ) i_tagger_patid_r (
      .addr_i          (tagger_addr_r),
      .conf_addr_curr_i(conf_addr_curr_r[i]),
      .conf_addr_prev_i(conf_addr_prev_r[i]),
      .conf_addr_mode_i(tag_tab[i].conf),
      .match_o         (match_r[i])
    );
  end

  lzc #(
    .WIDTH(MAXPARTITION),
    .MODE (1'b0)
  ) i_lzc_r (
    .in_i   (match_r),
    .cnt_o  (trail_zero_r),
    .empty_o(empty_r)
  );

  // Write Channel Tagging
  always_comb begin
    tagger_addr_w = slv_req_i.aw.addr;

  end

  for (genvar i = 0; i < MAXPARTITION; i++) begin
    assign conf_addr_prev_w[i] = (i == 0) ? '0 : tag_tab[i-1].addr;
    assign conf_addr_curr_w[i] = tag_tab[i].addr;

    tagger_patid #(
      .ADDR_LEN    (ADDR_WIDTH),
      .MAXPARTITION(MAXPARTITION),
      .TAGGER_GRAN (TAGGER_GRAN)
    ) i_tagger_patid_w (
      .addr_i          (tagger_addr_w),
      .conf_addr_curr_i(conf_addr_curr_w[i]),
      .conf_addr_prev_i(conf_addr_prev_w[i]),
      .conf_addr_mode_i(tag_tab[i].conf),
      .match_o         (match_w[i])
    );
  end

  lzc #(
    .WIDTH(MAXPARTITION),
    .MODE (1'b0)
  ) i_lzc_w (
    .in_i   (match_w),
    .cnt_o  (trail_zero_w),
    .empty_o(empty_w)
  );


  // Register (cfg_rsp_mod) holds the table for range of each partition
  // Incoming addresses need to be checked and assigned to its corresponding
  // range, by giving a PatID in user field of aw/ar channel
  always_comb begin
    // Pass signals by default
    mst_req_o = slv_req_i;
    slv_rsp_o = mst_rsp_i;
    // Set user signal default to zero
    patid_r   = '0;
    patid_w   = '0;

    if (~empty_r) begin
      patid_r = tag_tab[trail_zero_r].patid;
    end

    if (~empty_w) begin
      patid_w = tag_tab[trail_zero_w].patid;
    end

    mst_req_o.ar.user[AXI_USER_ID_MSB:AXI_USER_ID_LSB] = patid_r;
    mst_req_o.aw.user[AXI_USER_ID_MSB:AXI_USER_ID_LSB] = patid_w;
  end

endmodule
