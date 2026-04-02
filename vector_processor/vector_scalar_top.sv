// ============================================================
// Vector + Scalar Top Module
// ============================================================

`include "vector_processor_defs.svh"
`include "axi_4_defs.svh"
`include "scalar_m_ext_defs.svh"
`include "scalar_a_ext_defs.svh"
`include "scalar_pcore_interface_defs.svh"

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

    assign inst_valid = is_vec;
    logic [31:0]  instr_read, instruction_o;

    logic [31:0]  addr_a;
    logic [511:0] wdata_a;
    logic [511:0] rdata_a;
    logic         wen_a;
    logic         ren_a;
    logic [63:0]  byte_en_a;

    logic        elem_mode_a;
    logic [1:0]  sew_a;

    //==========================================================================
    // VECTOR PROCESSOR
    // instruction_d, rs1_data_d, rs2_data_d — 1 cycle delayed values
    //==========================================================================
    vector_processor VECTOR (
        .clk               (clk),
        .reset             (rst_n),
        .instruction        (instr_read),      
        .rs1_data           (rs1_data   ),
        .rs2_data           (rs2_data   ),
        .inst_valid        (inst_valid),
        .scalar_pro_ready  (scalar_pro_ready),
        .is_vec            (is_vec),
        .error             (error),
        .csr_out           (csr_out),
        .vec_pro_ack       (vec_pro_ack),
        .vec_pro_ready     (vec_pro_ready)
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
        .instr_o        (instruction_o),     // direct — register mein jata hai upar
        .rs1_data_o     (rs1_data),
        .rs2_data_o     (rs2_data),
        .core2pipe_i    (core2pipe)
    );

    //==========================================================================
    // INSTRUCTION MEMORY
    //==========================================================================
    memory memory (
        .rst_n      (rst_n),
        .clk        (clk),
        .vec_pro_ack(vec_pro_ack),

        .if2mem_i   (if2mem),
        .mem2if_o   (mem2if),
        .instr_read (instr_read),

        .dmem_sel   (dmem_sel),
        .exe2mem_i  (dbus2mem),
        .mem2wrb_o  (mem2dbus),
        .addr_a(addr_a),
        .wdata_a(wdata_a),
        .rdata_a(rdata_a),
        .wen_a(wen_a),
        .ren_a(ren_a),
        .byte_en_a(byte_en_a),
        .elem_mode_a(elem_mode_a),
        .sew_a(sew_a)
    );

endmodule
