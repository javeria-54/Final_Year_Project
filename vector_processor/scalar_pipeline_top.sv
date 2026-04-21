// Copyright 2023 University of Engineering and Technology Lahore.
// Licensed under the Apache License, Version 2.0, see LICENSE file for details.
// SPDX-License-Identifier: Apache-2.0
//
// Description: The pipeline top module.
//
// Author: Muhammad Tahir, UET Lahore
// Date: 11.8.2022



`include "scalar_m_ext_defs.svh"
`include "scalar_a_ext_defs.svh"

`default_nettype wire

module pipeline_top (

    input   wire                        rst_n,                    // reset
    input   wire                        clk,                      // clock
    

   // IF <---> IMEM interface
    output type_if2imem_s                if2mem_o,              // Instruction memory request
    input wire type_imem2if_s            mem2if_i,              // Instruction memory response

   // Data bus interface
    output type_lsu2dbus_s              lsu2dbus_o,                // Signal to data bus 
    input  wire type_dbus2lsu_s         dbus2lsu_i,
    output logic                        lsu_flush_o,

   // Memory mapped timer interface
   input wire type_clint2csr_s          clint2csr_i,

    // pipeline_top.sv mein add karo ports mein:
    output logic [31:0]     instr_o,      // fetch stage se
    output logic [31:0]     rs1_data_o,   // decode stage se  
    output logic [31:0]     rs2_data_o,    // decode stage se

    input  logic                        vec_pro_ack,
    output  logic                       is_vector, 
    output  logic                       scalar_pro_ready,
    output  logic                       inst_valid,          
    output  logic                       scalar_pro_ack,  

   // IRQ interface
   input wire type_pipe2csr_s           core2pipe_i


 //  input wire type_debug_port_s         debug_port_i 
);


// Local signals

type_if2id_data_s                       if2id_data, if2id_data_next;
type_if2id_ctrl_s                       if2id_ctrl, if2id_ctrl_next;

type_id2exe_ctrl_s                      id2exe_ctrl, id2exe_ctrl_next;
type_id2exe_data_s                      id2exe_data, id2exe_data_next;

type_exe2lsu_ctrl_s                     exe2lsu_ctrl, exe2lsu_ctrl_next;
type_exe2lsu_data_s                     exe2lsu_data, exe2lsu_data_next;

// M-extension related signals
type_exe2div_s                          exe2div;

// Interfaces for CSR module
type_exe2csr_data_s                     exe2csr_data, exe2csr_data_next;
type_exe2csr_ctrl_s                     exe2csr_ctrl, exe2csr_ctrl_next;
type_lsu2csr_data_s                     lsu2csr_data;
type_lsu2csr_ctrl_s                     lsu2csr_ctrl;

// Interfaces for AMO module
type_amo2lsu_data_s                     amo2lsu_data; 
type_amo2lsu_ctrl_s                     amo2lsu_ctrl;             
type_lsu2amo_data_s                     lsu2amo_data;
type_lsu2amo_ctrl_s                     lsu2amo_ctrl;

// Interfaces for data bus 
type_lsu2dbus_s                         lsu2dbus;               // Signal to data memory 
type_dbus2lsu_s                         dbus2lsu; 

// Interfaces for instruction memory 
type_if2imem_s                        if2mem;              
type_imem2if_s                        mem2if;

// Interfaces for writeback module
type_lsu2wrb_ctrl_s                     lsu2wrb_ctrl;
type_lsu2wrb_data_s                     lsu2wrb_data;
type_csr2wrb_data_s                     csr2wrb_data;
type_div2wrb_s                          div2wrb;

type_lsu2wrb_data_s                     lsu2wrb_data_next;
type_lsu2wrb_ctrl_s                     lsu2wrb_ctrl_next;
type_csr2wrb_data_s                     csr2wrb_data_next;
type_div2wrb_s                          div2wrb_next;

// Interfaces for feedback signals
type_csr2if_fb_s                        csr2if_fb;
type_csr2id_fb_s                        csr2id_fb;
type_exe2if_fb_s                        exe2if_fb;
type_wrb2id_fb_s                        wrb2id_fb;

logic [`XLEN-1:0]                       lsu2exe_fb_alu_result;
logic [`XLEN-1:0]                       wrb2exe_fb_rd_data;
//logic                                   if2fwd_stall;

// Interfaces for forwarding module
// To forwarding module
type_exe2fwd_s                          exe2fwd;
type_wrb2fwd_s                          wrb2fwd;
type_lsu2fwd_s                          lsu2fwd;
type_csr2fwd_s                          csr2fwd;
type_div2fwd_s                          div2fwd;

// From forwarding module
type_fwd2exe_s                          fwd2exe;
type_fwd2if_s                           fwd2if;
type_fwd2csr_s                          fwd2csr;
type_fwd2lsu_s                          fwd2lsu;
type_fwd2ptop_s                         fwd2ptop;


// Inputs assignment to local signals
assign dbus2lsu  = dbus2lsu_i; 
assign mem2if = mem2if_i;
assign instr_o    = id2exe_data.instr;
assign rs1_data_o = id2exe_data.rs1_data;
assign rs2_data_o = id2exe_data.rs2_data;


//================================= Fetch to decode interface ==================================//

// Instruction Fetch module instantiation
fetch fetch_module (
    .rst_n                      (rst_n),
    .clk                        (clk),

    // IF module interface signals 
    .if2mem_o                (if2mem),
    .mem2if_i                (mem2if),

    .if2id_data_o               (if2id_data),
    .if2id_ctrl_o               (if2id_ctrl),
    .exe2if_fb_i                (exe2if_fb),
    .csr2if_fb_i                (csr2if_fb),
    .fwd2if_i                   (fwd2if)
 //   .if2fwd_stall_o             (if2fwd_stall)
);

// Fetch <-----> Decode pipeline/nopipeline  
`ifdef IF2ID_PIPELINE_STAGE
type_if2id_data_s                       if2id_data_pipe_ff;
type_if2id_ctrl_s                       if2id_ctrl_pipe_ff;

always_ff @(posedge clk) begin
    if (~rst_n) begin
        if2id_data_pipe_ff.instr   <= 32'h00000013;
        if2id_data_pipe_ff.pc      <= '0;
        if2id_data_pipe_ff.pc_next <= '0;
        if2id_data_pipe_ff.instr_flushed <= 1'b0;
        if2id_data_pipe_ff.exc_code <= EXC_CODE_NO_EXCEPTION;

        if2id_ctrl_pipe_ff <= '0;
    end else begin
        if2id_data_pipe_ff <= if2id_data_next;
        if2id_ctrl_pipe_ff <= if2id_ctrl_next;
        
    end
end

always_comb begin
    if2id_data_next = if2id_data;
    if2id_ctrl_next = if2id_ctrl;

    if (fwd2ptop.if2id_pipe_flush) begin
        if2id_data_next.instr         = `INSTR_NOP;
        if2id_data_next.instr_flushed = 1'b1;
        if2id_ctrl_next.exc_req       = 1'b0;
        if2id_ctrl_next.irq_req       = 1'b0;
        if2id_data_next.exc_code      = EXC_CODE_NO_EXCEPTION;

    end else if (fwd2ptop.if2id_pipe_stall) begin
        if2id_data_next = if2id_data_pipe_ff;
        if2id_ctrl_next = if2id_ctrl_pipe_ff;
    end   
end 
`endif // IF2ID_PIPELINE_STAGE


// Instruction Decode module instantiation
decode decode_module (
    .rst_n                      (rst_n),
    .clk                        (clk),
    .is_vector                  (is_vector),
    .rob_instr(rob_instr),
    .rob_seq_num(rob_seq_num),

    // ID module interface signals 
`ifdef IF2ID_PIPELINE_STAGE
    .if2id_data_i               (if2id_data_pipe_ff),
    .if2id_ctrl_i               (if2id_ctrl_pipe_ff),
`else
    .if2id_data_i               (if2id_data),
    .if2id_ctrl_i               (if2id_ctrl),
`endif
    .id2exe_ctrl_o              (id2exe_ctrl),
    .id2exe_data_o              (id2exe_data),
    .csr2id_fb_i                (csr2id_fb),
    .wrb2id_fb_i                (wrb2id_fb)
   // .debug_port_i               (debug_port_i)
);


//================================= Decode to execute interface ==================================//
// Instruction Execute module instantiation
execute execute_module (
    .rst_n                      (rst_n),
    .clk                        (clk),

    // Decode <---> EXE module interface signals 
    .id2exe_data_i              (id2exe_data),
    .id2exe_ctrl_i              (id2exe_ctrl),

    // EXE <---> M-Extension interface signals
    .exe2div_o                  (exe2div),

    // EXE <---> LSU module interface signals
    .exe2lsu_ctrl_o             (exe2lsu_ctrl),
    .exe2lsu_data_o             (exe2lsu_data),

    // EXE <---> CSR module interface signals
    .exe2csr_ctrl_o             (exe2csr_ctrl),
    .exe2csr_data_o             (exe2csr_data),

    // EXE <---> Forward_stall interface
    .fwd2exe_i                  (fwd2exe),
    .exe2fwd_o                  (exe2fwd),    

    // EXE module feedback signal to instruction fetch signal
    .exe2if_fb_o                (exe2if_fb),

    // LSU/WB <---> EXE feedback interface
    .lsu2exe_fb_alu_result_i    (lsu2exe_fb_alu_result),
    .wrb2exe_fb_rd_data_i       (wrb2exe_fb_rd_data)
 
);


//================================= Execute to LSU interface ==================================//
// Execute <-----> LSU pipeline/nopipeline  
`ifdef EXE2LSU_PIPELINE_STAGE
type_exe2lsu_data_s                     exe2lsu_data_pipe_ff;
type_exe2lsu_ctrl_s                     exe2lsu_ctrl_pipe_ff;
type_exe2csr_data_s                     exe2csr_data_pipe_ff;
type_exe2csr_ctrl_s                     exe2csr_ctrl_pipe_ff;

always_ff @(posedge clk) begin
    if (~rst_n) begin
        exe2lsu_data_pipe_ff <= '0;
        exe2lsu_ctrl_pipe_ff <= '0;         
        exe2csr_data_pipe_ff <= '0;
        exe2csr_ctrl_pipe_ff <= '0;
     end else begin
        exe2lsu_data_pipe_ff <= exe2lsu_data_next;
        exe2lsu_ctrl_pipe_ff <= exe2lsu_ctrl_next;
        exe2csr_data_pipe_ff <= exe2csr_data_next;
        exe2csr_ctrl_pipe_ff <= exe2csr_ctrl_next;
    end
end

always_comb begin
    exe2csr_data_next = exe2csr_data;
    exe2lsu_ctrl_next = exe2lsu_ctrl;
    exe2csr_ctrl_next = exe2csr_ctrl; 
    exe2lsu_data_next = exe2lsu_data;
     
    if (fwd2ptop.exe2lsu_pipe_flush) begin
        exe2lsu_ctrl_next = '0;
        exe2csr_ctrl_next = '0;
        exe2csr_data_next.instr_flushed = 1'b1;
        exe2lsu_data_next.alu_result = exe2lsu_data_pipe_ff.alu_result;
    end else if (fwd2ptop.exe2lsu_pipe_stall) begin  // Stall the exe2lsu/csr stage
        exe2lsu_ctrl_next = exe2lsu_ctrl_pipe_ff;
        exe2csr_ctrl_next = exe2csr_ctrl_pipe_ff;
        exe2lsu_data_next = exe2lsu_data_pipe_ff;
    end 
end 
`endif // EXE2LSU_PIPELINE_STAGE

// Load-store module instantiation
lsu lsu_module (
    .rst_n                      (rst_n),
    .clk                        (clk),

    // Input interface signals from execution module  
`ifdef EXE2LSU_PIPELINE_STAGE
    .exe2lsu_ctrl_i             (exe2lsu_ctrl_pipe_ff),
    .exe2lsu_data_i             (exe2lsu_data_pipe_ff),

`else
    .exe2lsu_ctrl_i             (exe2lsu_ctrl),
    .exe2lsu_data_i             (exe2lsu_data),
`endif

    // CSR module interface signals 
    .lsu2csr_ctrl_o             (lsu2csr_ctrl),
    .lsu2csr_data_o             (lsu2csr_data),

    // Writeback module interface signals 
    .lsu2wrb_ctrl_o             (lsu2wrb_ctrl),
    .lsu2wrb_data_o             (lsu2wrb_data),

    .lsu2exe_fb_alu_result_o    (lsu2exe_fb_alu_result),

    // Forward_stall interface
    .lsu2fwd_o                  (lsu2fwd),
    .fwd2lsu_i                  (fwd2lsu),

    // LSU to data bus interface
    .lsu2dbus_o                 (lsu2dbus),      
    .dbus2lsu_i                 (dbus2lsu),
    .lsu_flush_o                (lsu_flush_o),

    // LSU to AMO interface
    .lsu2amo_data_o             (lsu2amo_data),      
    .lsu2amo_ctrl_o             (lsu2amo_ctrl),

    // AMO to LSU interface
    .amo2lsu_data_i             (amo2lsu_data),
    .amo2lsu_ctrl_i             (amo2lsu_ctrl)
);
  
// CSR module instantiation
csr csr_module (
    .rst_n                      (rst_n),
    .clk                        (clk),

    // Execution module interface signals 
`ifdef EXE2LSU_PIPELINE_STAGE
    .exe2csr_ctrl_i             (exe2csr_ctrl_pipe_ff),
    .exe2csr_data_i             (exe2csr_data_pipe_ff),
`else
    .exe2csr_ctrl_i             (exe2csr_ctrl),
    .exe2csr_data_i             (exe2csr_data),
`endif

    // LSU module interface signals 
    .lsu2csr_ctrl_i             (lsu2csr_ctrl),
    .lsu2csr_data_i             (lsu2csr_data),

    // Writeback module interface signals 
    .csr2wrb_data_o             (csr2wrb_data),

    .clint2csr_i                (clint2csr_i),

    .pipe2csr_i                 (core2pipe_i),
    .fwd2csr_i                  (fwd2csr),
    .csr2fwd_o                  (csr2fwd),
    .csr2id_fb_o                (csr2id_fb),
    .csr2if_fb_o                (csr2if_fb)
);

//============================ LSU/M-extension to writeback interface =============================//
// Writeback module instantiation
writeback writeback_module (
    .rst_n                      (rst_n),
    .clk                        (clk),

    // Writeback module interface signals
    .lsu2wrb_ctrl_i             (lsu2wrb_ctrl),
    .lsu2wrb_data_i             (lsu2wrb_data),
    .csr2wrb_data_i             (csr2wrb_data),
    .div2wrb_i                  (div2wrb),

    .wrb2id_fb_o                (wrb2id_fb),
    .wrb2exe_fb_rd_data_o       (wrb2exe_fb_rd_data),
    .wrb2fwd_o                  (wrb2fwd)
);

// Forward_stall module instantiation
forward_stall forward_stall_module (
    .rst_n                      (rst_n),
    .clk                        (clk),

    // Forward_stall module interface signals 
    .wrb2fwd_i                  (wrb2fwd),
    .lsu2fwd_i                  (lsu2fwd),
    .csr2fwd_i                  (csr2fwd),
    .div2fwd_i                  (div2fwd),
    .exe2fwd_i                  (exe2fwd),
 //   .if2fwd_stall_i             (if2fwd_stall),

    .fwd2if_o                   (fwd2if),
    .fwd2exe_o                  (fwd2exe),
    .fwd2csr_o                  (fwd2csr),
    .fwd2lsu_o                  (fwd2lsu),
    .fwd2ptop_o                 (fwd2ptop)
);

//============================ divtiply/divide moulde for M-extension ============================//
divide divide_module(
    .rst_n                      (rst_n        ),            // reset
    .clk                        (clk          ),            // clock

    // EXE <---> M-extension interface
    .exe2div_i                  (exe2div), 

    // Stall and Flush signals
    .fwd2div_stall_i            (fwd2ptop.exe2lsu_pipe_stall),
    .fwd2div_flush_i            (fwd2ptop.exe2lsu_pipe_flush | fwd2ptop.lsu2wrb_pipe_flush),

    // M-extension <---> Forward-stall interface
    .div2fwd_o                  (div2fwd),
    .div_done                   (div_done),

    // M-extension <---> Writeback interface
    .div2wrb_o                  (div2wrb)
);


//============================ AMO moulde for A-extension ============================//
amo amo_module (
    .rst_n                      (rst_n),
    .clk                        (clk),

    // LSU to AMO interface
    .lsu2amo_data_i             (lsu2amo_data),      
    .lsu2amo_ctrl_i             (lsu2amo_ctrl),

    // AMO to LSU interface
    .amo2lsu_data_o             (amo2lsu_data),
    .amo2lsu_ctrl_o             (amo2lsu_ctrl)

);

single_cycle_val_ready_controller scalar_valid_ready(
    
    .clk(clk),
    .reset(rst_n),

    .is_vector(is_vector),

    .inst_valid(inst_valid),        
    .vec_pro_ack(vec_pro_ack),      
    
    .scalar_pro_ready(scalar_pro_ready),         
    .scalar_pro_ack(scalar_pro_ack)           
);

rob rob(
    .clk                        (clk),
    .rst_n                      (rst_n),

    .fetch_instr_i              (mem2if.rdata),
    .fetch_valid_i              (mem2if.ack), 

    .rob_full_o                 (rob_full_o),         
    .rob_seq_num_o              (rob_seq_num), 

    .rob_instr_o                (rob_instr),
    .de_valid_i                 (de_valid),
    .de_seq_num_i               (id2exe_data.seq_num),       
    .de_is_vector_i             (is_vector),     
    .de_scalar_store_i          (is_scalar_store),  
    .de_vector_store_i          (is_vector_store), 
    .de_scalar_load_i           (is_scalar_load),  
    .de_vector_load_i           (is_vector_load), 
    .de_rs1_data_i              (id2exe_data.rs1_data),      
    .de_rs2_data_i              (id2exe_data.rs2_data),      
    .de_instr_i                 (id2exe_data.instr),  

    .fwd_rs1_hit_o              (fwd_rs1_hit_o),      
    .fwd_rs1_val_o              (fwd_rs1_val_o),      
    .fwd_rs2_hit_o              (fwd_rs2_hit_o),     
    .fwd_rs2_val_o              (fwd_rs2_hit_o), 

    .fwd_vs1_hit_o              (fwd_vs1_hit_o),      
    .fwd_vs1_val_o              (fwd_vs1_val_o),      
    .fwd_vs2_hit_o              (fwd_vs2_hit_o),      
    .fwd_vs2_val_o              (fwd_vs2_val_o), 

    .fwd_rs1_data_o             (fwd_rs1_data_o),     
    .fwd_rs2_data_o             (fwd_rs2_data_o), 

    .fwd_vs1_data_o             (fwd_vs1_data_o),     
    .fwd_vs2_data_o             (fwd_vs2_data_o),

    .scalar_done_i              (div_done | exe_done | lsu_done),
    .scalar_seq_num_i           (),  
    .scalar_rd_addr_i           (id2rf_rd_addr_i),   
    .scalar_result_i            (exe2lsu_data.alu_result),    
    .scalar_mem_addr_i          (lsu2dbus.addr),    
    .scalar_mem_data_i          (dbus2lsu.r_data), 
    .scalar_mem_data_o          (lsu2dbus.wdata),     

    .vector_done_i              (execution_done | is_stored | is loaded ),
    .vector_seq_num_i           (),   
    .vector_vd_addr_i           (vec_write_addr),   
    .vector_result_i            (execution_result),    //checkit
    .vector_mem_addr_i          (mem_addr),    
    .vector_mem_data_i          (mem_rdata), 
    .vector_mem_data_o          (mem_wrdata),   

    .viq_src1_reg_i             (viq_src1_reg_i),
    .viq_src2_reg_i             (viq_src2_reg_i),

    .stall_vec_raw_o            (stall_vec_raw),    
    .stall_scalar_mem_o         (stall_scalar_mem), 
    .stall_vector_mem_o         (stall_vector_mem),

    .commit_valid_o             (rob_commit_valid),
    .commit_vector_seq_num_o    (rob_commit_vector_seq),
    .commit_scalar_seq_num_o    (rob_commit_scalar_seq),
    .commit_is_vector_o         (rob_commit_is_vec),
    .commit_scalar_store_o      (rob_commit_scalar_store),
    .commit_vector_store_o      (rob_commit_vector_store),
    .commit_rd_o                (rob_commit_rd),        
    .commit_vd_o                (rob_commit_vd),        
    .commit_scalar_result_o     (rob_commit_scalar_result),
    .commit_vector_result_o     (rob_commit_vector_result),
    .commit_mem_addr_o          (rob_commit_mem_addr),
    .commit_mem_data_o          (rob_commit_mem_data),  
    .commit_scalar_mem_data_o   (rob_commit_scalar_mem_data), 

    .flush_valid_i,
    .flush_seq_i

);

    viq #(
        .DEPTH     (VIQ_DEPTH),
        .SEQ_W     (SEQ_W),
        .INSTR_W   (INSTR_W),
        .OPERAND_W (OPERAND_W)
    ) u_viq (
        .clk                (clk),
        .reset              (reset),
        .vector_instr_valid (viq_instr_valid_i),
        .instr_seq_i        (viq_instr_seq_i),
        .instruction_i      (viq_instruction_i),
        .operand_rs1_i      (viq_operand_rs1_i),
        .operand_rs2_i      (viq_operand_rs2_i),
        .instr_is_vecmem_i  (viq_instr_is_vecmem_i),
        .stall_vec          (viq_stall_o),
        .num_instr          (viq_num_instr_o),
        .deq_ready          (viq_deq_ready),
        .deq_valid          (viq_deq_valid_int),
        .instr_seq_o        (viq_deq_seq_o),
        .instruction_o      (viq_deq_instr_o),
        .operand_rs1_o      (viq_deq_rs1_o),
        .operand_rs2_o      (viq_deq_rs2_o),
        .instr_is_vecmem_o  (viq_deq_is_vecmem_int)
    );

    vector_processor_datapth DATAPATH(
        
        .clk                (clk                 ),
        .reset              (reset               ),
        
        // Inputs from the scaler processor  --> vector processor
        .instruction        (instruction),      
        .rs1_data           (rs1_data   ),
        .rs2_data           (rs2_data   ),

        // Outputs from vector rocessor --> scaler processor
        .is_vec             (is_vec              ),
        .error              (error               ),
        
        .st_req(st_req),
        .ld_req(ld_req),
        .seq_num(viq_deq_seq_o),
        
        .mem_addr           (mem_addr                   ),
        .mem_wdata          (mem_wdata                  ),
        .mem_wdata_unit     (mem_wdata_unit             ),
        .mem_byte_en        (mem_byte_en                ),
        .mem_wen            (mem_wen                    ),
        .mem_ren            (mem_ren                    ),
        .mem_elem_mode      (mem_elem_mode              ),
        .mem_sew_enc        (mem_sew_enc                ),
        .mem_rdata          (mem_rdata                  ),
      
        // csr_regfile -> scalar_processor
        .csr_out            (csr_out             ),

        // datapth  --> val_ready_controller
        .inst_done          (inst_done           ),            

        // Inputs from the controller --> datapath
        .sew_eew_sel        (sew_eew_sel         ),
        .vlmax_evlmax_sel   (vlmax_evlmax_sel    ),
        .emul_vlmul_sel     (emul_vlmul_sel      ),

        // vec_control_signals -> vec_decode
        .vl_sel             (vl_sel              ),
        .vtype_sel          (vtype_sel           ),
        .lumop_sel          (lumop_sel           ),
        .rs1rd_de           (rs1rd_de            ),
        
        // vec_control_signals -> vec_csr_regs
        .csrwr_en           (csrwr_en            ),

        // vec_control_signals -> vec_register_file
        .vec_reg_wr_en      (vec_reg_wr_en       ),
        .mask_operation     (mask_operation      ),
        .mask_wr_en         (mask_wr_en          ),
        .data_mux1_sel      (data_mux1_sel       ),
        .data_mux2_sel      (data_mux2_sel       ),
        .data_mux3_sel      (data_mux3_sel       ),
        .offset_vec_en      (offset_vec_en       ),

        // vec_control_signals -> vec_lsu
        .stride_sel         (stride_sel          ),
        .ld_inst            (ld_inst             ),
        .st_inst            (st_inst             ),
        .index_str          (index_str           ), 
        .index_unordered    (index_unordered     ),

        .vec_wr_data        (vec_wr_data),
        
        .Ctrl               (Ctrl),
        .execution_op       (execution_op),
        .mul_high           (mul_high),
        .mul_low            (mul_low),
        .execution_inst     (execution_inst),
        .reverse_sub_inst   (reverse_sub_inst),
        .add_inst           (add_inst),
        .sub_inst           (sub_inst),
        .signed_mode        (signed_mode),
        .bitwise_op         (bitwise_op),
        .op_type            (op_type),
        .cmp_op             (cmp_op),
        .accum_op           (accum_op),
        .mask_op            (mask_op),
        .start              (start),
        .shift_op           (shift_op)
    );


    //==========================================================================//
    //                  MAIN CONTROLLER INSTANTIATION                           //
    //==========================================================================//


    vector_processor_controller CONTROLLER(
        
        // scalar_processor -> vector_extension
        .vec_inst           (instruction),

        // Output from  controller --> datapath

        // vec_control_signals -> vec_decode
        .vl_sel             (vl_sel         ),
        .vtype_sel          (vtype_sel      ),
        .lumop_sel          (lumop_sel      ),
        
        // vec_control_signals -> vec_csr_regs
        .csrwr_en           (csrwr_en        ),
        .sew_eew_sel        (sew_eew_sel     ),
        .vlmax_evlmax_sel   (vlmax_evlmax_sel),
        .emul_vlmul_sel     (emul_vlmul_sel  ),
        .rs1rd_de           (rs1rd_de       ),

        // vec_control_signals -> vec_register_file
        .vec_reg_wr_en              (vec_reg_wr_en  ),
        .mask_operation             (mask_operation ),
        .mask_wr_en                 (mask_wr_en     ),
        .data_mux1_sel              (data_mux1_sel  ),
        .data_mux2_sel              (data_mux2_sel  ),
        .data_mux3_sel              (data_mux3_sel  ),
        .offset_vec_en              (offset_vec_en  ),

        // vec_control_signals -> vec_lsu
        .stride_sel                 (stride_sel     ),
        .ld_inst                    (ld_inst        ),
        .st_inst                    (st_inst        ),
        .index_str                  (index_str      ),
        .index_unordered            (index_unordered),

        .execution_op               (execution_op),
        
        .signed_mode                (signed_mode),
        .Ctrl                       (Ctrl),
        .mul_low                    (mul_low), 
        .mul_high                   (mul_high),
        .start(start),

        .add_inst                   (add_inst), 
        .sub_inst                   (sub_inst), 
        .reverse_sub_inst           (reverse_sub_inst), 
        .shift_left_logical_inst    (shift_left_logical_inst), 
        .shift_right_arith_inst     (shift_right_arith_inst), 
        .shift_right_logical_inst   (shift_right_logical_inst),
        .execution_inst             (execution_inst),
        .mul_inst                   (mul_inst),
        .equal_inst                 (equal_inst), 
        .not_equal_inst             (not_equal_inst),
        .less_or_equal_unsigned_inst(less_or_equal_unsigned_inst),
        .less_or_equal_signed_inst  (less_or_equal_signed_inst), 
        .less_unsinged_inst         (less_unsinged_inst),
        .greater_unsigned_inst      (greater_unsigned_inst),
        .less_signed_inst           (less_signed_inst), 
        .greater_signed_inst        (greater_signed_inst), 
        .mul_add_dest_inst          (mul_add_dest_inst), 
        .mul_sub_dest_inst          (mul_sub_dest_inst), 
        .mul_add_source_inst        (mul_add_source_inst), 
        .mul_sub_source_inst        (mul_sub_source_inst),   
        .mask_and_inst              (mask_and_inst), 
        .mask_nand_inst             (mask_nand_inst), 
        .mask_and_not_inst          (mask_and_not_inst), 
        .mask_xor_inst              (mask_xor_inst), 
        .mask_or_inst               (mask_or_inst), 
        .mask_nor_inst              (mask_nor_inst),
        .mask_or_not_inst           (mask_or_not_inst) , 
        .mask_xnor_inst             (mask_xnor_inst), 
        .red_sum_inst               (red_sum_inst), 
        .red_max_unsigned_inst      (red_max_unsigned_inst), 
        .red_max_signed_inst        (red_max_signed_inst),
        .red_min_signed_inst        (red_min_signed_inst), 
        .red_min_unsigned_inst      (red_min_unsigned_inst), 
        .red_and_inst               (red_and_inst) , 
        .red_or_inst                (red_or_inst), 
        .red_xor_inst               (red_xor_inst),
        .signed_min_inst            (signed_min_inst),
        .unsigned_min_inst          (unsigned_min_inst), 
        .signed_max_inst            (signed_max_inst), 
        .unsigned_max_inst          (unsigned_max_inst), 
        .move_inst                  (move_inst), 
        .wid_add_signed_inst        (wid_add_signed_inst), 
        .wid_add_unsigned_inst      (wid_add_unsigned_inst), 
        .wid_sub_signed_inst        (wid_sub_signed_inst), 
        .wid_sub_unsigned_inst      (wid_sub_unsigned_inst), 
        .add_carry_inst_inst        (add_carry_inst_inst), 
        .sub_borrow_inst            (sub_borrow_inst), 
        .add_carry_masked_inst      (add_carry_masked_inst), 
        .sub_borrow_masked_inst     (sub_borrow_masked_inst), 
        .sat_add_signed_inst        (sat_add_signed_inst), 
        .sat_add_unsigned_inst      (sat_add_unsigned_inst), 
        .sat_sub_signed_inst        (sat_sub_signed_inst), 
        .sat_sub_unsigned_inst      (sat_sub_unsigned_inst),
        .and_inst                   (and_inst), 
        .or_inst                    (or_inst), 
        .xor_inst                   (xor_inst),
        .mask_op                    (mask_op),
        .bitwise_op                 (bitwise_op),
        .op_type                    (op_type),
        .cmp_op                     (cmp_op),
        .shift_op                   (shift_op),
        .accum_op                    (accum_op)

    );

    //==========================================================================//
    //                  VAL READY INTERFACE INSTANTIATION                       //
    //==========================================================================//


    val_ready_controller VAL_READY_INTERFACE(
        
        .clk                (clk                ),
        .reset              (reset              ),

        // scaler_procssor  --> val_ready_controller
        .inst_valid         (inst_valid         ),             // tells data comming from the saler processor is valid
        .scalar_pro_ready   (scalar_pro_ready   ),       // tells that scaler processor is ready to take output
        
        // val_ready_controller --> scaler_processor
        .vec_pro_ready      (vec_pro_ready      ),          // tells that vector processor is ready to take the instruction
        .vec_pro_ack        (vec_pro_ack        ),             // tells that the data comming from the vec_procssor is valid and done with the implementation of instruction 

        // datapath -->   val_ready_controller 
        .inst_done          (inst_done          )
    );

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
        .addr_a     (addr_a),
        .wdata_a    (wdata_a),
        .rdata_a    (rdata_a),
        .wen_a      (wen_a),
        .ren_a      (ren_a),
        .byte_en_a  (byte_en_a),
        .elem_mode_a(elem_mode_a),
        .sew_a      (sew_a)
    );



assign lsu2dbus_o   = lsu2dbus;
assign if2mem_o     = if2mem;

endmodule : pipeline_top
