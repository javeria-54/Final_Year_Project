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


    logic [`XLEN-1:0]    inst_reg_instruction;     // Output instruction
    logic [`XLEN-1:0]    inst_reg_rs1_data;        // Output RS1 data
    logic [`XLEN-1:0]    inst_reg_rs2_data;         // Output RS2 data

    logic [`XLEN-1:0]    inst_reg_instruction_d;     // Output instruction
    logic [`XLEN-1:0]    inst_reg_rs1_data_d;        // Output RS1 data
    logic [`XLEN-1:0]    inst_reg_rs2_data_d;         // Output RS2 data

    logic [`XLEN-1:0]    instruction_o;     // Output instruction

    //==========================================================================
    // 1 Cycle Delay Register — bas itna hi chahiye
    //==========================================================================
    always_ff @(posedge clk) begin 
        if(vec_pro_ready) begin
            inst_reg_instruction_d  <= inst_reg_instruction;
            inst_reg_rs1_data_d     <= inst_reg_rs1_data;
            inst_reg_rs2_data_d     <= inst_reg_rs2_data;
        end 
    end

    assign inst_valid = is_vec;

    //==========================================================================
    // VECTOR PROCESSOR
    // instruction_d, rs1_data_d, rs2_data_d — 1 cycle delayed values
    //==========================================================================
    vector_processor VECTOR (
        .clk               (clk),
        .reset             (rst_n),
        .instruction        (inst_reg_instruction_d),      
        .rs1_data           (inst_reg_rs1_data_d   ),
        .rs2_data           (inst_reg_rs2_data_d   ),
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
        .instr_o        (instruction_o),     // direct — register mein jata hai upar
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

    instruction_data_queue INS_DATA_QUEUE(
        .clk                    (clk                ),
        .reset                  (reset              ),
        // Scaler Processor --> Queue 
        .inst_valid             (inst_valid         ), 
        .instruction            (instruction_o      ), 
        .rs1_data               (rs1_data           ), 
        .rs2_data               (rs2_data           ),  
        
        // VAL_READY_Controller --> Queue
        .vec_pro_ready          (vec_pro_ready      ),  
        
        // Queue --> Vector Processor
        .inst_reg_instruction   (inst_reg_instruction), 
        .inst_reg_rs1_data      (inst_reg_rs1_data   ), 
        .inst_reg_rs2_data      (inst_reg_rs2_data   )  
    );

endmodule

module instruction_data_queue #(

    parameter DEPTH = 5    // Queue depth
) (
    input  logic                clk,
    input  logic                reset,
    // Scaler Processor --> Queue 
    input  logic                inst_valid,       // Instruction valid
    input  logic [`XLEN-1:0]    instruction,      // Instruction input
    input  logic [`XLEN-1:0]    rs1_data,         // RS1 data
    input  logic [`XLEN-1:0]    rs2_data,         // RS2 data
    
     // VAL_READY_Controller --> Queue
    input  logic                 vec_pro_ready,   // Vector processor ready
    
    // Queue --> Vector Processor
    output logic [`XLEN-1:0]    inst_reg_instruction,     // Output instruction
    output logic [`XLEN-1:0]    inst_reg_rs1_data,        // Output RS1 data
    output logic [`XLEN-1:0]    inst_reg_rs2_data         // Output RS2 data
);

    logic [`XLEN-1:0]    inst_out_instruction;     // Dummy Output instruction
    logic [`XLEN-1:0]    inst_out_rs1_data;        // Dummy Output RS1 data
    logic [`XLEN-1:0]    inst_out_rs2_data;        // Dummy Output RS2 data

    // FIFO storage for instructions and data
    typedef struct packed {
        logic [`XLEN-1:0] instruction;
        logic [`XLEN-1:0] rs1_data;
        logic [`XLEN-1:0] rs2_data;
    } queue_entry_t;

    queue_entry_t fifo [DEPTH-1:0];

    logic [$clog2(DEPTH):0] write_ptr, read_ptr;
    logic [$clog2(DEPTH+1):0] count;

    // Status flags
    logic  full  = (count == DEPTH);
    logic  empty = (count == 0);

    // Handshake signal
    logic inst_accepted;
    logic inst_ready;

     // Bypass signals
    logic bypass;
    logic inst_valid_seen;  // Tracks whether inst_valid has been asserted

    always_ff @( posedge clk or negedge clk ) begin 
        if (!reset)begin
            inst_valid_seen <= 1'b0;
        end
        else begin
            if (inst_valid && !vec_pro_ready)begin
                inst_valid_seen <= 1'b1;
            end
            else begin
                inst_valid_seen <= 1'b0;
            end
        end
        
    end


    assign bypass = (inst_valid && vec_pro_ready && !inst_valid_seen);

    // Output logic with bypass handling
   always_ff @(posedge clk or negedge reset) begin
        if (!reset) begin
            inst_out_instruction <= 0;
            inst_out_rs1_data    <= 0;
            inst_out_rs2_data    <= 0;
            read_ptr             <= 0;
            write_ptr <= 0;
            count <= 0;
            inst_accepted <= 0;
        end else if (bypass) begin
            // Directly bypass the input instruction and data to output
            inst_out_instruction <= instruction;
            inst_out_rs1_data    <= rs1_data;
            inst_out_rs2_data    <= rs2_data;
        end else if (!empty && vec_pro_ready) begin
            // Update read pointer and prepare for next cycle
            read_ptr <= read_ptr + 1;
            count    <= count - 1;
        end else begin
            if (inst_valid && inst_ready && !inst_accepted) begin
                // Store the instruction and data in the queue
                fifo[write_ptr].instruction <= instruction;
                fifo[write_ptr].rs1_data    <= rs1_data;
                fifo[write_ptr].rs2_data    <= rs2_data;
                write_ptr <= write_ptr + 1;
                count <= count + 1;

                // Mark instruction as accepted
                inst_accepted <= 1;
            end else if (!inst_valid) begin
                // Reset the accepted flag when inst_valid deasserts
                inst_accepted <= 0;
            end
        end
    end

    // Combinational output logic for immediate dequeued data
    always_comb begin
        if (bypass) begin
            // Directly pass the input instruction and data to the output
            inst_reg_instruction = instruction;
            inst_reg_rs1_data    = rs1_data;
            inst_reg_rs2_data    = rs2_data;
        end else if (!empty && vec_pro_ready) begin
            // Directly use the data from the queue for immediate output
            inst_reg_instruction = fifo[read_ptr].instruction;
            inst_reg_rs1_data    = fifo[read_ptr].rs1_data;
            inst_reg_rs2_data    = fifo[read_ptr].rs2_data;
        end else begin
            // Hold the current values
            inst_reg_instruction = inst_out_instruction;
            inst_reg_rs1_data    = inst_out_rs1_data;
            inst_reg_rs2_data    = inst_out_rs2_data;
        end
    end

    assign inst_ready = !full && !vec_pro_ready;
    
endmodule









