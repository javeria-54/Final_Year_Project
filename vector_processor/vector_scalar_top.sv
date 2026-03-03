// ============================================================
// Vector + Scalar Top Module
// ============================================================

import axi_4_pkg::*;

`include "vector_processor_defs.svh"
`include "axi_4_defs.svh"
`include "single_cycle_m_ext_defs.svh"
`include "single_cycle_a_ext_defs.svh"
`include "single_cycle_pcore_interface_defs.svh"

`default_nettype wire

module vector_scalar_top (
    input logic clk,
    input logic rst_n          
);

    //==========================================================================
    // Scalar Processor Internal Signals
    //==========================================================================
    logic [31:0] instruction;      // direct from pipeline
    logic [31:0] rs1_data;
    logic [31:0] rs2_data;

    // 1 cycle delayed signals — yeh vector processor ko jayenge
    logic [31:0] instruction_d;
    logic [31:0] rs1_data_d;
    logic [31:0] rs2_data_d;

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

    //==========================================================================
    // Memory Interface Signals
    //==========================================================================
    type_if2imem_s    if2mem;
    type_imem2if_s    mem2if;
    type_lsu2dbus_s   lsu2dbus;
    type_dbus2lsu_s   dbus2lsu;
    type_dbus2peri_s  dbus2mem;
    type_peri2dbus_s  mem2dbus;
    type_clint2csr_s  clint2csr;
    type_pipe2csr_s   core2pipe;
    logic             lsu_flush;
    logic             dmem_sel;

    //==========================================================================
    // 1 Cycle Delay Register — bas itna hi chahiye
    //==========================================================================
    always_comb begin 
        if(vec_pro_ack) begin
            instruction_d = instruction;
            rs1_data_d    = rs1_data;
            rs2_data_d    = rs2_data;
        end 
        else begin
            instruction_d = 'b0;
            rs1_data_d    = 'b0;
            rs2_data_d    = 'b0;
        end 
        
    end

    //==========================================================================
    // VECTOR PROCESSOR
    // instruction_d, rs1_data_d, rs2_data_d — 1 cycle delayed values
    //==========================================================================
    vector_processor VECTOR (
        .clk               (clk),
        .reset             (rst_n),
        .instruction       (instruction_d),   // 1 cycle delayed
        .rs1_data          (rs1_data_d),      // 1 cycle delayed
        .rs2_data          (rs2_data_d),      // 1 cycle delayed
        .inst_valid        (inst_valid),
        .scalar_pro_ready  (scalar_pro_ready),
        .is_vec            (is_vec),
        .error             (error),
        .csr_out           (csr_out),
        .vec_pro_ack       (vec_pro_ack),
        .vec_pro_ready     (vec_pro_ready),
        .s_arready         (s_arready),
        .m_arvalid         (m_arvalid),
        .s_rvalid          (s_rvalid),
        .m_rready          (m_rready),
        .s_awready         (s_awready),
        .m_awvalid         (m_awvalid),
        .s_wready          (s_wready),
        .m_wvalid          (m_wvalid),
        .s_bvalid          (s_bvalid),
        .m_bready          (m_bready),
        .ld_req_reg        (ld_req_reg),
        .st_req_reg        (st_req_reg),
        .re_wr_addr_channel(re_wr_addr_channel),
        .wr_data_channel   (wr_data_channel),
        .re_data_channel   (re_data_channel),
        .wr_resp_channel   (wr_resp_channel)
    );

    //==========================================================================
    // AXI SLAVE MEMORY
    //==========================================================================
    axi4_slave_mem AXI_SLAVE (
        .clk               (clk),
        .reset             (rst_n),
        .ld_req            (ld_req_reg),
        .st_req            (st_req_reg),
        .s_arready         (s_arready),
        .m_arvalid         (m_arvalid),
        .s_rvalid          (s_rvalid),
        .m_rready          (m_rready),
        .s_awready         (s_awready),
        .m_awvalid         (m_awvalid),
        .s_wready          (s_wready),
        .m_wvalid          (m_wvalid),
        .s_bvalid          (s_bvalid),
        .m_bready          (m_bready),
        .re_wr_addr_channel(re_wr_addr_channel),
        .wr_data_channel   (wr_data_channel),
        .re_data_channel   (re_data_channel),
        .wr_resp_channel   (wr_resp_channel)
    );

    //==========================================================================
    // SCALAR PIPELINE
    //==========================================================================
    pipeline_top SCALAR (
        .rst_n          (rst_n),
        .clk            (clk),
        .is_vector      (is_vec),
        .scalar_pro_ready(scalar_pro_ready),

        .if2mem_o       (if2mem),
        .mem2if_i       (mem2if),

        .lsu2dbus_o     (lsu2dbus),
        .dbus2lsu_i     (dbus2lsu),
        .lsu_flush_o    (lsu_flush),

        .clint2csr_i    (clint2csr),
        .instr_o        (instruction),     // direct — register mein jata hai upar
        .rs1_data_o     (rs1_data),
        .rs2_data_o     (rs2_data),
        .core2pipe_i    (core2pipe)
    );

    //==========================================================================
    // INSTRUCTION MEMORY
    //==========================================================================
    memory mem_module (
        .rst_n      (rst_n),
        .clk        (clk),
        .vec_pro_ack(vec_pro_ack),

        .if2mem_i   (if2mem),
        .mem2if_o   (mem2if),

        .dmem_sel   (dmem_sel),
        .exe2mem_i  (dbus2mem),
        .mem2wrb_o  (mem2dbus)
    );

endmodule : vector_scalar_top