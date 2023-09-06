// Copyright 2023 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Authors:
// - Diyou Shen <dishen@student.ethz.ch>
//
// Description: Used in tb to compare check the functionality of tagger

module user_checker #(
  // LLC user signal offset
  parameter int unsigned AXI_USER_ID_MSB = 7,
  parameter int unsigned AXI_USER_ID_LSB = 0,
  parameter int unsigned NUM_ADDR_CONF   = 4,
  // AXI request/response
  parameter type         axi_req_t       = logic,
  parameter type         axi_user_t      = logic,
  parameter type         axi_addr_t      = logic,
  parameter type         addr_conf_t     = logic
) (
  // rising-edge clock
  input  logic                           clk_i,
  // asynchronous reset, active low
  input  logic                           rst_ni,
  // slave port
  input  axi_req_t                       slv_req_i,
  // tagger mode
  input  logic       [              1:0] mode_i,
  // configured addr and patid
  input  addr_conf_t [NUM_ADDR_CONF-1:0] addr_conf_i,
  // mismatch flag for aw channel
  output logic                           aw_error_o,
  // reference aw patid
  output axi_user_t                      aw_patid_ref_o,
  // tagger aw patid
  output axi_user_t                      aw_patid_act_o,
  // mismatch flag for ar channel
  output logic                           ar_error_o,
  // reference ar patid
  output axi_user_t                      ar_patid_ref_o,
  // tagger ar patid
  output axi_user_t                      ar_patid_act_o
);
  localparam int unsigned PATID_LEN = AXI_USER_ID_MSB - AXI_USER_ID_LSB + 1;
  axi_user_t aw_user, ar_user;
  axi_addr_t aw_addr, ar_addr;

  axi_user_t aw_patid_ref_d, aw_patid_ref_q, aw_patid_act_d, aw_patid_act_q;
  axi_user_t ar_patid_ref_d, ar_patid_ref_q, ar_patid_act_d, ar_patid_act_q;
  logic aw_error_d, aw_error_q, ar_error_d, ar_error_q;

  // Currently only support TOR and NAPOT modes, which are the most interesting ones

  // AW Channel
  always_comb begin
    aw_user = '0;
    aw_user[PATID_LEN-1:0] = slv_req_i.aw.user[AXI_USER_ID_MSB:AXI_USER_ID_LSB];
    aw_addr = slv_req_i.aw.addr;
    aw_error_d = 1'b0;
    aw_patid_ref_d = '0;
    aw_patid_act_d = '0;

    if (slv_req_i.aw_valid) begin
      case (mode_i)
        2'b01: begin  // TOR
          for (int unsigned i = 0; i < NUM_ADDR_CONF; i++) begin
            if (aw_addr <= addr_conf_i[i].addr) begin
              if (aw_user != addr_conf_i[i].patid) begin
                aw_error_d = 1'b1;
                aw_patid_ref_d = addr_conf_i[i].patid;
                aw_patid_act_d = aw_user;
              end
              break;
            end
          end
        end

        2'b11: begin  // NAPOT
          for (int unsigned i = 0; i < NUM_ADDR_CONF; i++) begin
            if ((aw_addr >= addr_conf_i[i].addr) && (aw_addr <= addr_conf_i[i].addr+addr_conf_i[i].size)) begin
              if (aw_user != addr_conf_i[i].patid) begin
                aw_error_d = 1'b1;
                aw_patid_ref_d = addr_conf_i[i].patid;
                aw_patid_act_d = aw_user;
              end
              break;
            end
          end
        end

        default: aw_error_d = 1'b0;
      endcase
    end
  end

  // use flip-flops to avoid unstable changes (0->0 will cause assertion error without FFs)
  always_ff @(posedge clk_i, negedge rst_ni) begin
    if (~rst_ni) begin
      aw_error_q <= '0;
      aw_patid_ref_q <= '0;
      aw_patid_act_q <= '0;
    end else begin
      aw_error_q <= aw_error_d;
      aw_patid_ref_q <= aw_patid_ref_d;
      aw_patid_act_q <= aw_patid_act_d;
    end
  end

  assign aw_error_o = aw_error_q;
  assign aw_patid_ref_o = aw_patid_ref_q;
  assign aw_patid_act_o = aw_patid_act_q;


  // AR Channel
  always_comb begin
    ar_user = '0;
    ar_user[PATID_LEN-1:0] = slv_req_i.ar.user[AXI_USER_ID_MSB:AXI_USER_ID_LSB];
    ar_addr = slv_req_i.ar.addr;
    ar_error_d = 1'b0;
    ar_patid_ref_d = '0;
    ar_patid_act_d = '0;

    if (slv_req_i.ar_valid) begin
      case (mode_i)
        2'b01: begin  // TOR
          for (int unsigned i = 0; i < NUM_ADDR_CONF; i++) begin
            if (ar_addr <= addr_conf_i[i].addr) begin
              if (ar_user != addr_conf_i[i].patid) begin
                ar_error_d = 1'b1;
                ar_patid_ref_d = addr_conf_i[i].patid;
                ar_patid_act_d = ar_user;
              end
              break;
            end
          end
        end

        2'b11: begin  // NAPOT
          for (int unsigned i = 0; i < NUM_ADDR_CONF; i++) begin
            if ((ar_addr >= addr_conf_i[i].addr) && (ar_addr <= addr_conf_i[i].addr+addr_conf_i[i].size)) begin
              if (ar_user != addr_conf_i[i].patid) begin
                ar_error_d = 1'b1;
                ar_patid_ref_d = addr_conf_i[i].patid;
                ar_patid_act_d = ar_user;
              end
              break;
            end
          end
        end

        default: ar_error_d = 1'b0;
      endcase
    end
  end

  always_ff @(posedge clk_i, negedge rst_ni) begin
    if (~rst_ni) begin
      ar_error_q <= '0;
      ar_patid_ref_q <= '0;
      ar_patid_act_q <= '0;
    end else begin
      ar_error_q <= ar_error_d;
      ar_patid_ref_q <= ar_patid_ref_d;
      ar_patid_act_q <= ar_patid_act_d;
    end
  end

  assign ar_error_o = ar_error_q;
  assign ar_patid_ref_o = ar_patid_ref_q;
  assign ar_patid_act_o = ar_patid_act_q;

endmodule
