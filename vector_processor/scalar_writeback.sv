// Copyright 2023 University of Engineering and Technology Lahore.
// Licensed under the Apache License, Version 2.0, see LICENSE file for details.
// SPDX-License-Identifier: Apache-2.0
//
// Description: The writeback stage of the pipeline.
//
// Author: Muhammad Tahir, UET Lahore
// Date: 11.8.2022

`include "scalar_m_ext_defs.svh"

module writeback (

    input   logic                            rst_n,                    // reset
    input   logic                            clk,                      // clock

    // LSU <---> Writeback interface
    input wire type_lsu2wrb_data_s           lsu2wrb_data_i,
    input wire type_lsu2wrb_ctrl_s           lsu2wrb_ctrl_i,

    // CSR <---> Writeback interface
    input wire type_csr2wrb_data_s           csr2wrb_data_i,

    // M-extension <---> Writeback interface
    input wire type_div2wrb_s                div2wrb_i,

    // Writeback <---> ID interface for feedback signals
    output type_wrb2id_fb_s                  wrb2id_fb_o,

    input logic rob_commit_valid_i,
    input logic [`REG_ADDR_W-1:0] rob_commit_rd_i,
    input logic [`XLEN-1:0] rob_commit_scalar_result_i,
    input logic rob_commit_is_vec_i,

    // Writeback <---> EXE interface for feedback signals
    output logic [`XLEN-1:0]                 wrb2exe_fb_rd_data_o,

    // Writeback <---> Forward_stall interface for forwarding
    output type_wrb2fwd_s                    wrb2fwd_o
);

// Local signals
type_lsu2wrb_data_s            lsu2wrb_data;
type_lsu2wrb_ctrl_s            lsu2wrb_ctrl;
type_csr2wrb_data_s            csr2wrb_data;
type_div2wrb_s                 div2wrb;

type_wrb2id_fb_s               wrb2id_fb;
logic [`XLEN-1:0]              wrb_rd_data;

// Assign appropriate values to the output signals
assign lsu2wrb_data = lsu2wrb_data_i;
assign lsu2wrb_ctrl = lsu2wrb_ctrl_i;
assign csr2wrb_data = csr2wrb_data_i;
assign div2wrb      = div2wrb_i;
 
// Writeback MUX for output signal selection

always_comb begin
    wrb_rd_data = '0;
    
    if (rob_commit_valid_i && !rob_commit_is_vec_i) begin
        case (lsu2wrb_ctrl.rd_wrb_sel)
            RD_WRB_ALU    : wrb_rd_data = rob_commit_scalar_result_i;
            RD_WRB_INC_PC : wrb_rd_data = rob_commit_scalar_result_i;
            RD_WRB_DMEM   : wrb_rd_data = rob_commit_scalar_result_i;
            RD_WRB_CSR    : wrb_rd_data = rob_commit_scalar_result_i;
            RD_WRB_D_ALU  : wrb_rd_data = rob_commit_scalar_result_i;
            default       : wrb_rd_data = '0;
        endcase
    end
end

// rd_addr aur rd_wr_req ab ROB commit se aaye ga
assign wrb2id_fb.rd_data   = wrb_rd_data;
assign wrb2id_fb.rd_addr   = rob_commit_rd_i;
assign wrb2id_fb.rd_wr_req = rob_commit_valid_i && !rob_commit_is_vec_i;

// Forwarding module ko batao — commit hua, yeh rd_addr hai
assign wrb2fwd_o.rd_addr    = rob_commit_rd_i;
assign wrb2fwd_o.rd_wr_req  = rob_commit_valid_i && !rob_commit_is_vec_i;

// Execute stage ko result forward karo (commit wala result)
assign wrb2exe_fb_rd_data_o = wrb_rd_data;  // yeh same rahega — wrb_rd_data ab ROB se aa raha hai

assign wrb2id_fb_o          = wrb2id_fb;

endmodule : writeback

