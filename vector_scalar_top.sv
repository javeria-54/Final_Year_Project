// Copyright 2025 Maktab-e-Digital Systems Lahore.
// Licensed under the Apache License, Version 2.0, see LICENSE file for details.
// SPDX-License-Identifier: Apache-2.0
//
// Author: Javeria
// =============================================================================
// System Top — Scalar + Vector Processor Integration
// =============================================================================

import axi_4_pkg::*;

`include "vector_processor_defs.svh"
`include "axi_4_defs.svh"

module system_top (
    input  logic clk,
    input  logic rst
);

    //==========================================================================
    // Scalar Processor Internal Signals
    //==========================================================================
    logic        is_vector;
    logic [31:0] instruction_fwd;
    logic [31:0] rs1_data_fwd;
    logic [31:0] rs2_data_fwd;
    logic pc_enable;

    //==========================================================================
    // Handshaking Signals
    //==========================================================================
    logic        inst_valid;
    logic        scalar_pro_ready;
    logic        vec_pro_ready;
    logic        vec_pro_ack;

    //==========================================================================
    // Vector Processor Output Signals
    //==========================================================================
    logic        is_vec;
    logic        error;
    logic [31:0] csr_out;

    //==========================================================================
    // AXI Signals
    //==========================================================================
    logic s_arready, m_arvalid;
    logic s_rvalid,  m_rready;
    logic s_awready, m_awvalid;
    logic s_wready,  m_wvalid;
    logic s_bvalid,  m_bready;
    logic ld_req_reg, st_req_reg;

    read_write_address_channel_t  re_wr_addr_channel;
    write_data_channel_t          wr_data_channel;
    read_data_channel_t           re_data_channel;
    write_response_channel_t      wr_resp_channel;

    assign pc_enable = ~is_vector | vec_pro_ready;

    //==========================================================================
    // SCALAR PROCESSOR
    //==========================================================================
    single_cycle_processor_top SCALAR (
        .clk      (clk),
        .rst      (!rst),
        .pc_enable(pc_enable), 
        .is_vector(is_vector)
    );

    //==========================================================================
    // FORWARDING LOGIC — Scalar se Vector ko
    //==========================================================================
    assign instruction_fwd = SCALAR.instruction;
    assign rs1_data_fwd    = SCALAR.rdataA;
    assign rs2_data_fwd    = SCALAR.rdataB;

    // inst_valid: vector instruction detect ho aur vector ready ho
    assign inst_valid = is_vector & vec_pro_ready;

    // scalar_pro_ready: vec_pro_ack aane ke baad scalar ready signal
    always_ff @(posedge clk or negedge rst) begin
        if (!rst)
            scalar_pro_ready <= 1'b0;
        else if (vec_pro_ack && !scalar_pro_ready)
            scalar_pro_ready <= 1'b1;
        else if (scalar_pro_ready && !vec_pro_ack)
            scalar_pro_ready <= 1'b0;
    end

    //==========================================================================
    // VECTOR PROCESSOR (val_ready_controller andar hai)
    //==========================================================================
    vector_processor VECTOR (
        .clk              (clk),
        .reset            (rst),
        .instruction      (instruction_fwd),   // ✅ scalar se forward
        .rs1_data         (rs1_data_fwd),      // ✅ scalar register se
        .rs2_data         (rs2_data_fwd),      // ✅ scalar register se
        .inst_valid       (inst_valid),
        .scalar_pro_ready (scalar_pro_ready),
        .is_vec           (is_vec),
        .error            (error),
        .csr_out          (csr_out),
        .vec_pro_ack      (vec_pro_ack),
        .vec_pro_ready    (vec_pro_ready),
        .s_arready        (s_arready),
        .m_arvalid        (m_arvalid),
        .s_rvalid         (s_rvalid),
        .m_rready         (m_rready),
        .s_awready        (s_awready),
        .m_awvalid        (m_awvalid),
        .s_wready         (s_wready),
        .m_wvalid         (m_wvalid),
        .s_bvalid         (s_bvalid),
        .m_bready         (m_bready),
        .ld_req_reg       (ld_req_reg),
        .st_req_reg       (st_req_reg),
        .re_wr_addr_channel(re_wr_addr_channel),
        .wr_data_channel  (wr_data_channel),
        .re_data_channel  (re_data_channel),
        .wr_resp_channel  (wr_resp_channel)
    );

    //==========================================================================
    // AXI SLAVE MEMORY
    //==========================================================================
    axi4_slave_mem AXI_SLAVE (
        .clk              (clk),
        .reset            (rst),
        .ld_req           (ld_req_reg),
        .st_req           (st_req_reg),
        .s_arready        (s_arready),
        .m_arvalid        (m_arvalid),
        .s_rvalid         (s_rvalid),
        .m_rready         (m_rready),
        .s_awready        (s_awready),
        .m_awvalid        (m_awvalid),
        .s_wready         (s_wready),
        .m_wvalid         (m_wvalid),
        .s_bvalid         (s_bvalid),
        .m_bready         (m_bready),
        .re_wr_addr_channel(re_wr_addr_channel),
        .wr_data_channel  (wr_data_channel),
        .re_data_channel  (re_data_channel),
        .wr_resp_channel  (wr_resp_channel)
    );

endmodule