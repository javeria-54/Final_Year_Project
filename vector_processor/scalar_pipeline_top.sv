// Copyright 2023 University of Engineering and Technology Lahore.
// Licensed under the Apache License, Version 2.0, see LICENSE file for details.
// SPDX-License-Identifier: Apache-2.0
//
// Description: The pipeline top module — fixed version.
//
// Author: Muhammad Tahir, UET Lahore
// Date: 11.8.2022
import pcore_types_pkg::*;
`include "scalar_m_ext_defs.svh"
`include "scalar_a_ext_defs.svh"
`include "vector_processor_defs.svh"

module pipeline_top (
    input   wire                        rst_n,
    input   wire                        clk
);

// ============================================================
// Pipeline stage interfaces
// ============================================================

// Instruction memory
type_if2imem_s                          if2mem;
type_imem2if_s                          mem2if;

type_if2id_data_s                       if2id_data, if2id_data_next;
type_if2id_ctrl_s                       if2id_ctrl, if2id_ctrl_next;

type_id2exe_ctrl_s                      id2exe_ctrl;
type_id2exe_data_s                      id2exe_data;

type_exe2lsu_ctrl_s                     exe2lsu_ctrl;
type_exe2lsu_data_s                     exe2lsu_data;

// M-extension
type_exe2div_s                          exe2div;

// CSR interfaces
type_exe2csr_data_s                     exe2csr_data;
type_exe2csr_ctrl_s                     exe2csr_ctrl;
type_lsu2csr_data_s                     lsu2csr_data;
type_lsu2csr_ctrl_s                     lsu2csr_ctrl;

// Data bus
type_lsu2dbus_s                         lsu2dbus;
type_dbus2lsu_s                         dbus2lsu;

logic [`XLEN-1:0]                       lsu2exe_fb_alu_result;
logic [`XLEN-1:0]                       wrb2exe_fb_rd_data;

// Writeback interfaces
type_lsu2wrb_ctrl_s                     lsu2wrb_ctrl;
type_lsu2wrb_data_s                     lsu2wrb_data;
type_csr2wrb_data_s                     csr2wrb_data;
type_div2wrb_s                          div2wrb;

// AMO interfaces
type_amo2lsu_data_s                     amo2lsu_data;
type_amo2lsu_ctrl_s                     amo2lsu_ctrl;
type_lsu2amo_data_s                     lsu2amo_data;
type_lsu2amo_ctrl_s                     lsu2amo_ctrl;

// Feedback signals
type_csr2if_fb_s                        csr2if_fb;
type_csr2id_fb_s                        csr2id_fb;
type_exe2if_fb_s                        exe2if_fb;
type_wrb2id_fb_s                        wrb2id_fb;

// Forwarding interfaces
type_exe2fwd_s                          exe2fwd;
type_wrb2fwd_s                          wrb2fwd;
type_lsu2fwd_s                          lsu2fwd;
type_csr2fwd_s                          csr2fwd;
type_div2fwd_s                          div2fwd;
type_fwd2exe_s                          fwd2exe;
type_fwd2if_s                           fwd2if;
type_fwd2csr_s                          fwd2csr;
type_fwd2lsu_s                          fwd2lsu;
type_fwd2ptop_s                         fwd2ptop;

// FIX #2: clint2csr_i internal signal — port se drive hoga
type_clint2csr_s                        clint2csr_i;

type_id2exe_ctrl_s                      id2exe_ctrl_next;
type_id2exe_data_s                      id2exe_data_next;

type_exe2lsu_ctrl_s                     exe2lsu_ctrl_next;
type_exe2lsu_data_s                     exe2lsu_data_next;

// Interfaces for CSR module
type_exe2csr_data_s                     exe2csr_data_next;
type_exe2csr_ctrl_s                     exe2csr_ctrl_next;

// ============================================================
// Peripheral bus signals
// ============================================================
type_peri2dbus_s                        uart2dbus;
type_peri2dbus_s                        clint2dbus;
type_peri2dbus_s                        plic2dbus;
type_peri2dbus_s                        spi2dbus;
type_peri2dbus_s                        gpio2dbus;

// Peripheral stubs — tied to 0
assign uart2dbus  = '0;
assign clint2dbus = '0;
assign plic2dbus  = '0;
assign spi2dbus   = '0;
assign gpio2dbus  = '0;

// FIX #3: clint2csr_i ko port se assign karo
assign clint2csr_i = 'b0;

// Selection lines from dbus interconnect
logic                                   dmem_sel;
logic                                   uart0_sel;
logic                                   uart1_sel;
logic                                   clint_sel;
logic                                   plic_sel;
logic                                   spi0_sel;
logic                                   spi1_sel;
logic                                   gpioA_sel;
logic                                   gpioB_sel;
logic                                   gpioC_sel;
logic                                   gpsw_sel;
logic                                   gpled_sel;

type_dbus2peri_s                        dbus2peri;
type_peri2dbus_s                        mem2dbus;

// ============================================================
// Divide done signal
// ============================================================
logic                                   div_done;

// ============================================================
// ROB signals
// ============================================================
logic                                   de_valid;
logic [`XLEN-1:0]                       rob_de_instr;
logic [`Tag_Width-1:0]                  rob_de_seq_num;

logic                                   stall_vec_raw;
logic                                   stall_fetch;
logic                                   stall_viq_full;
logic                                   stall_scalar_raw;

// Decode-stage flags
logic                                   is_scalar_store;
logic                                   is_vector_store;
logic                                   is_scalar_load;
logic                                   is_vector_load;
logic                                   is_vector;

// RF addresses from decode
logic [`RF_AWIDTH-1:0]                  id2rf_rs1_addr;
logic [`RF_AWIDTH-1:0]                  id2rf_rs2_addr;
logic [`XLEN-1:0]                       rf2id_rs1_data;
logic [`XLEN-1:0]                       rf2id_rs2_data;

// ROB scalar done path
logic                                   exe_done;
logic                                   lsu_done;

// FIX #4: lsu_flush declare kiya
logic                                   lsu_flush;

logic [`REG_ADDR_W-1:0]                 id2rf_rd_addr;

// ROB scalar forwarding outputs
logic [`XLEN-1:0]                       fwd_rs1_data, fwd_rs2_data;

// ROB vector forwarding outputs
logic [`VLEN-1:0]                       fwd_vs1_data, fwd_vs2_data;

// ROB commit outputs
logic                                   rob_commit_valid;
logic [`Tag_Width-1:0]                  rob_commit_vector_seq;
logic [`Tag_Width-1:0]                  rob_commit_scalar_seq;
logic                                   rob_commit_is_vec;
logic [`REG_ADDR_W-1:0]                 rob_commit_rd;
logic [`VREG_ADDR_W-1:0]                rob_commit_vd;
logic [`XLEN-1:0]                       rob_commit_scalar_result;
logic [`MAX_VLEN-1:0]                   rob_commit_vector_result;

// FIX #5: rob_commit_mem_addr / rob_commit_mem_data —
//         yeh aliases the, inka kaam vector mem signals se hoga
// (memory module mein directly vector mem signals use karo — neeche dekho)

logic [`XLEN-1:0]                       rob_commit_scalar_mem_data;
logic [`XLEN-1:0]                       rob_commit_scalar_mem_addr;
logic [`XLEN-1:0]                       rob_commit_vector_mem_addr;
logic [`VLEN-1:0]                       rob_commit_vector_mem_data;

// FIX #6: ROB commit vector memory control signals declare kiye
logic                                   rob_commit_vec_mem_wen;
logic [63:0]                            rob_commit_vec_mem_byte_en;
logic                                   rob_commit_vec_mem_elem_mode;
logic [1:0]                             rob_commit_vec_mem_sew_enc;

// FIX #7: ROB commit scalar store signals declare kiye
type_st_ops_e                           rob_commit_scalar_store_op;
logic                                   rob_commit_scalar_rd_wr_req;

// ROB flush interface
logic                                   flush_valid;
logic [`Tag_Width-1:0]                  flush_seq;

// ============================================================
// VIQ signals
// ============================================================
logic                                   viq_full;
logic                                   viq_stall;
logic [`VIQ_tag_width-1:0]             viq_num_instr;
logic                                   viq_deq_valid_int;
logic [`Tag_Width-1:0]                  viq_deq_seq;
logic [`INSTR_W-1:0]                    viq_deq_instr;
logic [`OPERAND_W-1:0]                  viq_deq_rs1;
logic [`OPERAND_W-1:0]                  viq_deq_rs2;
logic                                   viq_deq_is_vec_int;

// VIQ dispatch from ROB
logic                                   viq_dispatch_valid;
logic [`XLEN-1:0]                       viq_dispatch_instr;
logic [`Tag_Width-1:0]                  viq_dispatch_seq_num;
logic [`XLEN-1:0]                       viq_dispatch_rs1_data;
logic [`XLEN-1:0]                       viq_dispatch_rs2_data;

// FIX #8: viq_dispatch_is_load / viq_dispatch_is_store declare kiye
//         ROB se yeh flags aane chahiye — filhaal decode flags se drive
logic                                   viq_dispatch_is_load;
logic                                   viq_dispatch_is_store;
logic                                   viq_dispatch_is_vec;

assign viq_dispatch_is_load  = is_vector_load;
assign viq_dispatch_is_store = is_vector_store;

// ============================================================
// Vector datapath / controller signals
// ============================================================
logic [`MAX_VLEN-1:0]                   execution_result;
logic                                   execution_done;
logic                                   is_stored;
logic                                   is_loaded;
logic                                   data_written;
logic                                   csr_done;
logic [`XLEN-1:0]                       csr_out;
logic [`MAX_VLEN-1:0]                   vec_wr_data;
logic                                   inst_done;
logic                                   error;

// FIX #9: execution_inst declare kiya
logic                                   execution_inst;

// Vector register file addresses
logic [4:0]                             vec_read_addr_1;
// FIX #10: TYPO fix — vec_read_Addr_2 → vec_read_addr_2 (lowercase 'a')
logic [4:0]                             vec_read_addr_2;
logic [4:0]                             vec_write_addr;

// FIX #11: Vector memory signals declare kiye
logic [`XLEN-1:0]                       vec_mem_addr;
logic [`VLEN-1:0]                       vec_mem_wdata;
logic [`VLEN-1:0]                       vec_mem_wdata_unit;   // processor output, unused by ROB
logic [63:0]                            vec_mem_byte_en;
logic                                   vec_mem_wen;
logic                                   vec_mem_elem_mode;
logic [1:0]                             vec_mem_sew_enc;
logic                                   vec_mem_ren;
logic [`VLEN-1:0]                       vec_mem_rdata;

// Vector handshake
logic                                   vec_pro_ack;
logic                                   vec_pro_ready;
logic                                   scalar_pro_ready;
logic                                   inst_valid;
logic                                   scalar_pro_ack;

// Done signals
logic                                   scalar_done, vector_done;
logic [`XLEN-1:0]                       if2rob_instr;

logic [`Tag_Width-1:0]                  vec_seq_num;
logic [`RF_AWIDTH-1:0]                  exe2rob_rd_addr;
logic exe_done_delay, lsu_done_delay;

assign scalar_done = div_done | exe_done_delay | lsu_done_delay;
assign vector_done = execution_done | is_stored | csr_done | is_loaded;

always_ff @(posedge clk) begin
    exe_done_delay <= exe_done;
    lsu_done_delay <= lsu_done;
end

// ============================================================
// Key assignments
// ============================================================

assign de_valid = mem2if.ack; //| vec_decode_done; //left logic 

// rd address from execute stage
assign id2rf_rd_addr = exe2lsu_ctrl.rd_addr;

// Flush
//assign flush_valid = 'b0;
assign flush_valid =    exe2csr_data.instr_flushed | csr2fwd.irq_flush_lsu |
                        fwd2ptop.if2id_pipe_flush   | fwd2ptop.id2exe_pipe_flush  |     //if2id_pipe_flush,id2exe,exe2lsu
                        fwd2ptop.exe2lsu_pipe_flush | fwd2ptop.lsu2wrb_pipe_flush |
                        fwd2lsu.lsu_flush;
assign flush_seq   = '0;

// Scalar result MUX → ROB
logic [`XLEN-1:0]       scalar_result_to_rob;
logic [`Tag_Width-1:0]  scalar_seq_to_rob;
logic [`REG_ADDR_W-1:0] scalar_rd_addr_to_rob;

always_comb begin
    if (div_done) begin
        scalar_result_to_rob  = div2wrb.alu_d_result;
        scalar_seq_to_rob     = div2wrb.seq_num;
        scalar_rd_addr_to_rob = div2wrb.rd_addr;
    end else if (lsu_done) begin
        scalar_result_to_rob  = lsu2wrb_data.r_data;
        scalar_seq_to_rob     = lsu2wrb_data.seq_num;
        scalar_rd_addr_to_rob = lsu2wrb_data.rd_addr;
    end else begin
        scalar_result_to_rob  = exe2lsu_data.alu_result;
        scalar_seq_to_rob     = exe2lsu_data.seq_num;
        scalar_rd_addr_to_rob = exe2lsu_ctrl.rd_addr;
    end
end

// ============================================================
//                FETCH MODULE
// ============================================================
fetch fetch_module (
    .rst_n        (rst_n),
    .clk          (clk),
    .if2mem_o     (if2mem),
    .mem2if_i     (mem2if),
    .if2id_data_o (if2id_data),
    .if2id_ctrl_o (if2id_ctrl),
    .exe2if_fb_i  (exe2if_fb),
    .csr2if_fb_i  (csr2if_fb),
    .stall_fetch  (stall_fetch),
    .instr_word   (if2rob_instr),
    .fwd2if_i     (fwd2if)
);

`ifdef IF2ID_PIPELINE_STAGE
type_if2id_data_s  if2id_data_pipe_ff;
type_if2id_ctrl_s  if2id_ctrl_pipe_ff;

always_ff @(posedge clk) begin
    if (~rst_n) begin
        if2id_data_pipe_ff.instr         <= 32'h00000013;
        if2id_data_pipe_ff.pc            <= '0;
        if2id_data_pipe_ff.pc_next       <= '0;
        if2id_data_pipe_ff.instr_flushed <= 1'b0;
        if2id_data_pipe_ff.exc_code      <= EXC_CODE_NO_EXCEPTION;
        if2id_ctrl_pipe_ff               <= '0;
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
logic [`XLEN-1:0]          rob_de_instr_ff;
logic [`Tag_Width-1:0]     rob_de_seq_num_ff;
logic                      de_valid_ff;

always_ff @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
        rob_de_instr_ff   <= 32'h00000013;  // NOP
        rob_de_seq_num_ff <= '0;
        de_valid_ff       <= 1'b0;
    end else if (!stall_fetch) begin        // stall ka khayal rakho
        rob_de_instr_ff   <= rob_de_instr;
        rob_de_seq_num_ff <= rob_de_seq_num;
        de_valid_ff       <= de_valid;
    end
end
`endif

decode decode_module (
    .rst_n           (rst_n),
    .clk             (clk),
    .is_vector       (is_vector),
    .rob_instr       (rob_de_instr_ff),
    .rob_seq_num     (rob_de_seq_num_ff),
    .is_scalar_store (is_scalar_store),
    .is_scalar_load  (is_scalar_load),
    .is_vector_store (is_vector_store),
    .is_vector_load  (is_vector_load),
    .id2rf_rs1_addr  (id2rf_rs1_addr),
    .id2rf_rs2_addr  (id2rf_rs2_addr),
    .rf2id_rs1_data  (rf2id_rs1_data),
    .rf2id_rs2_data  (rf2id_rs2_data),
`ifdef IF2ID_PIPELINE_STAGE
    .if2id_data_i    (if2id_data_pipe_ff),
    .if2id_ctrl_i    (if2id_ctrl_pipe_ff),
`else
    .if2id_data_i    (if2id_data),
    .if2id_ctrl_i    (if2id_ctrl),
`endif
    .id2exe_ctrl_o   (id2exe_ctrl),
    .id2exe_data_o   (id2exe_data),
    .csr2id_fb_i     (csr2id_fb),
    .wrb2id_fb_i     (wrb2id_fb)
);

execute execute_module (
    .rst_n                   (rst_n),
    .clk                     (clk),
    .id2exe_data_i           (id2exe_data),
    .id2exe_ctrl_i           (id2exe_ctrl),
    .exe2div_o               (exe2div),
    .exe2lsu_ctrl_o          (exe2lsu_ctrl),
    .exe2lsu_data_o          (exe2lsu_data),
    .exe2csr_ctrl_o          (exe2csr_ctrl),
    .exe2csr_data_o          (exe2csr_data),
    .fwd2exe_i               (fwd2exe),
    .exe2fwd_o               (exe2fwd),
    .rd_addr                 (exe2rob_rd_addr),
    .exe2if_fb_o             (exe2if_fb),
    .lsu2exe_fb_alu_result_i (lsu2exe_fb_alu_result),
    .exe_done_o              (exe_done),
    .wrb2exe_fb_rd_data_i    (wrb2exe_fb_rd_data)
);

// Execute <-----> LSU pipeline register
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
        exe2lsu_ctrl_next               = '0;
        exe2csr_ctrl_next               = '0;
        exe2csr_data_next.instr_flushed = 1'b1;
        exe2lsu_data_next.alu_result    = exe2lsu_data_pipe_ff.alu_result;
    end else if (fwd2ptop.exe2lsu_pipe_stall) begin
        exe2lsu_ctrl_next = exe2lsu_ctrl_pipe_ff;
        exe2csr_ctrl_next = exe2csr_ctrl_pipe_ff;
        exe2lsu_data_next = exe2lsu_data_pipe_ff;
    end
end
`endif

lsu lsu_module (
    .rst_n                      (rst_n),
    .clk                        (clk),
    .rob_commit_scalar_mem_addr    (rob_commit_scalar_mem_addr),
    .rob_commit_scalar_mem_data (rob_commit_scalar_mem_data),
    // FIX #18: Scalar store signals connected
    .rob_commit_scalar_store_op    (rob_commit_scalar_store_op),
    .rob_commit_scalar_rd_wr_req     (rob_commit_scalar_rd_wr_req),
`ifdef EXE2LSU_PIPELINE_STAGE
    .exe2lsu_ctrl_i             (exe2lsu_ctrl_pipe_ff),
    .exe2lsu_data_i             (exe2lsu_data_pipe_ff),
`else
    .exe2lsu_ctrl_i             (exe2lsu_ctrl),
    .exe2lsu_data_i             (exe2lsu_data),
`endif
    .lsu2csr_ctrl_o             (lsu2csr_ctrl),
    .lsu2csr_data_o             (lsu2csr_data),
    .lsu2wrb_ctrl_o             (lsu2wrb_ctrl),
    .lsu2wrb_data_o             (lsu2wrb_data),
    .lsu2exe_fb_alu_result_o    (lsu2exe_fb_alu_result),
    .lsu2fwd_o                  (lsu2fwd),
    .fwd2lsu_i                  (fwd2lsu),
    .lsu2dbus_o                 (lsu2dbus),
    .dbus2lsu_i                 (dbus2lsu),
    // FIX #13: lsu_flush ab declared signal se connected
    .lsu_flush_o                (lsu_flush),
    .lsu2amo_data_o             (lsu2amo_data),
    .lsu2amo_ctrl_o             (lsu2amo_ctrl),
    .lsu_done_o                 (lsu_done),
    .amo2lsu_data_i             (amo2lsu_data),
    .amo2lsu_ctrl_i             (amo2lsu_ctrl)
);

csr csr_module (
    .rst_n                      (rst_n),
    .clk                        (clk),
`ifdef EXE2LSU_PIPELINE_STAGE
    .exe2csr_ctrl_i             (exe2csr_ctrl_pipe_ff),
    .exe2csr_data_i             (exe2csr_data_pipe_ff),
`else
    .exe2csr_ctrl_i             (exe2csr_ctrl),
    .exe2csr_data_i             (exe2csr_data),
`endif
    .lsu2csr_ctrl_i             (lsu2csr_ctrl),
    .lsu2csr_data_i             (lsu2csr_data),
    .csr2wrb_data_o             (csr2wrb_data),
    // FIX #14: clint2csr_i ab internal signal se ja raha hai
    .clint2csr_i                (clint2csr_i),
    // FIX #15: core2pipe_i / pipe2csr_i — port se driven
    .pipe2csr_i                 (core2pipe_i),
    .fwd2csr_i                  (fwd2csr),
    .csr2fwd_o                  (csr2fwd),
    .csr2id_fb_o                (csr2id_fb),
    .csr2if_fb_o                (csr2if_fb)
);

writeback writeback_module (
    .rst_n                      (rst_n),
    .clk                        (clk),
    .lsu2wrb_ctrl_i             (lsu2wrb_ctrl),
    .lsu2wrb_data_i             (lsu2wrb_data),
    .csr2wrb_data_i             (csr2wrb_data),
    .div2wrb_i                  (div2wrb),
    .rob_commit_valid_i         (rob_commit_valid),
    .rob_commit_rd_i            (rob_commit_rd),
    .rob_commit_scalar_result_i (rob_commit_scalar_result),
    .rob_commit_is_vec_i        (rob_commit_is_vec),
    .wrb2id_fb_o                (wrb2id_fb),
    .wrb2exe_fb_rd_data_o       (wrb2exe_fb_rd_data),
    .wrb2fwd_o                  (wrb2fwd)
);

forward_stall forward_stall_module (
    .rst_n      (rst_n),
    .clk        (clk),
    .wrb2fwd_i  (wrb2fwd),
    .lsu2fwd_i  (lsu2fwd),
    .csr2fwd_i  (csr2fwd),
    .div2fwd_i  (div2fwd),
    .exe2fwd_i  (exe2fwd),
    .fwd2if_o   (fwd2if),
    .fwd2exe_o  (fwd2exe),
    .fwd2csr_o  (fwd2csr),
    .fwd2lsu_o  (fwd2lsu),
    .fwd2ptop_o (fwd2ptop)
);

divide divide_module (
    .rst_n           (rst_n),
    .clk             (clk),
    .exe2div_i       (exe2div),
    .fwd2div_stall_i (fwd2ptop.exe2lsu_pipe_stall),
    .fwd2div_flush_i (fwd2ptop.exe2lsu_pipe_flush | fwd2ptop.lsu2wrb_pipe_flush),
    .div2fwd_o       (div2fwd),
    .div_done        (div_done),
    .div2wrb_o       (div2wrb)
);

amo amo_module (
    .rst_n          (rst_n),
    .clk            (clk),
    .lsu2amo_data_i (lsu2amo_data),
    .lsu2amo_ctrl_i (lsu2amo_ctrl),
    .amo2lsu_data_o (amo2lsu_data),
    .amo2lsu_ctrl_o (amo2lsu_ctrl)
);

single_cycle_val_ready_controller scalar_valid_ready (
    .clk             (clk),
    .reset           (rst_n),
    .is_vector       (is_vector),
    .inst_valid      (inst_valid),
    .vec_pro_ack     (vec_pro_ack),
    .scalar_pro_ready(scalar_pro_ready),
    .scalar_pro_ack  (scalar_pro_ack)
);

rob rob (
    .clk                     (clk),
    .rst_n                   (rst_n),

    .fetch_instr_i           (if2rob_instr),
    .fetch_valid_i           (mem2if.ack),

    .rob_de_instr_o          (rob_de_instr),
    .rob_de_seq_num_o        (rob_de_seq_num),

    .de_valid_i              (de_valid_ff),
    .de_seq_num_i            (id2exe_data.seq_num),
    .de_is_vector_i          (is_vector),
    .de_scalar_store_i       (is_scalar_store),
    .de_vector_store_i       (is_vector_store),
    .de_scalar_load_i        (is_scalar_load),
    .de_vector_load_i        (is_vector_load),

    .de_scalar_rd_addr_i     (exe2rob_rd_addr),
    .de_vector_vd_addr_i     (vec_write_addr),
    .de_rs1_addr_i           (id2rf_rs1_addr),
    .de_rs2_addr_i           (id2rf_rs2_addr),
    .de_vs1_addr_i           (id2rf_rs1_addr),
    .de_vs2_addr_i           (id2rf_rs2_addr),

    .fwd_rs1_data_o          (fwd_rs1_data),
    .fwd_rs2_data_o          (fwd_rs2_data),
    .fwd_vs1_data_o          (fwd_vs1_data),
    .fwd_vs2_data_o          (fwd_vs2_data),

    .scalar_done_i           (scalar_done),
    .scalar_seq_num_i        (scalar_seq_to_rob),
    .scalar_rd_addr_i        (scalar_rd_addr_to_rob),
    .scalar_result_i         (scalar_result_to_rob),
    .scalar_mem_addr_i       (exe2lsu_data.alu_result),
    .scalar_mem_data_i       (exe2lsu_data.rs2_data),
    .scalar_store_op_i       (exe2lsu_ctrl.st_ops),
    .scalar_rd_wr_req        (exe2lsu_ctrl.rd_wr_req),

    .vector_done_i           (vector_done),
    .vector_seq_num_i        (vec_seq_num),
    .vector_vd_addr_i        (vec_write_addr),
    .vector_result_i         (execution_inst ? vec_wr_data : csr_out),
    .vector_mem_addr_i       (vec_mem_addr),
    .vector_mem_data_i       (vec_mem_wdata),
    .mem_byte_en             (vec_mem_byte_en),
    .mem_wen                 (vec_mem_wen),
    .mem_elem_mode           (vec_mem_elem_mode),
    .mem_sew_enc             (vec_mem_sew_enc),

    .stall_vec_raw_o         (stall_vec_raw),
    .stall_fetch_o           (stall_fetch),

    .commit_valid_o          (rob_commit_valid),
    .commit_vector_seq_num_o (rob_commit_vector_seq),
    .commit_vd_o             (rob_commit_vd),
    .commit_vector_result_o  (rob_commit_vector_result),
    .commit_vec_mem_addr_o       (rob_commit_vector_mem_addr),
    .commit_vector_mem_data_o(rob_commit_vector_mem_data),
    // FIX #17: Newly declared signals connected
    .commit_vector_mem_byte_en   (rob_commit_vec_mem_byte_en),
    .commit_vector_mem_wen       (rob_commit_vec_mem_wen),
    .commit_vector_mem_elem_mode (rob_commit_vec_mem_elem_mode),
    .commit_vector_mem_sew_enc   (rob_commit_vec_mem_sew_enc),

    .commit_scalar_seq_num_o (rob_commit_scalar_seq),
    .commit_rd_o             (rob_commit_rd),
    .commit_scalar_result_o  (rob_commit_scalar_result),
    .commit_scalar_mem_addr_o    (rob_commit_scalar_mem_addr),
    .commit_scalar_mem_data_o(rob_commit_scalar_mem_data),
    // FIX #18: Scalar store signals connected
    .commit_scalar_store_op_o    (rob_commit_scalar_store_op),
    .commit_scalar_rd_wr_req_o     (rob_commit_scalar_rd_wr_req),
    .rob_commit_is_vec_o        (rob_commit_is_vec),

    .viq_dispatch_valid_o    (viq_dispatch_valid),
    .viq_dispatch_instr_o    (viq_dispatch_instr),
    .viq_dispatch_seq_num_o  (viq_dispatch_seq_num),
    .viq_full_i              (viq_full),
    .stall_viq_full_o        (stall_viq_full),
    .viq_dispatch_rs1_data_o (viq_dispatch_rs1_data),
    .viq_dispatch_rs2_data_o (viq_dispatch_rs2_data),
    .stall_scalar_raw_o      (stall_scalar_raw),
    .viq_dispatch_is_vec_o   (viq_dispatch_is_vec),
    .rf2rob_vs1_scalar_data_i(rf2id_rs1_data),

    .rf2rob_rs1_data_i       (rf2id_rs1_data),
    .rf2rob_rs2_data_i       (rf2id_rs2_data),

    .flush_valid_i           (flush_valid),
    .flush_seq_i             (flush_seq)
);

// ============================================================
//                VIQ MODULE
// ============================================================
viq viq (
    .clk                (clk),
    .reset              (rst_n),
    .vector_instr_valid (viq_dispatch_valid),
    .instr_seq_i        (viq_dispatch_seq_num),
    .instruction_i      (viq_dispatch_instr),
    .operand_rs1_i      (viq_dispatch_rs1_data),
    .operand_rs2_i      (viq_dispatch_rs2_data),
    // FIX #19: viq_dispatch_is_load/store ab declared aur driven hain
    .instr_is_vec_i     (viq_dispatch_is_vec),
    .stall_vec          (viq_stall),
    .num_instr          (viq_num_instr),
    .deq_ready          (vec_pro_ready),
    .viq_full           (viq_full),
    .deq_valid          (viq_deq_valid_int),
    .instr_seq_o        (viq_deq_seq),
    .instruction_o      (viq_deq_instr),
    .operand_rs1_o      (viq_deq_rs1),
    .operand_rs2_o      (viq_deq_rs2),
    .instr_is_vec_o     (viq_deq_is_vec_int)
);

// ============================================================
//                VECTOR PROCESSOR
// ============================================================
vector_processor vector (
    .clk                (clk),
    .reset              (rst_n),
    .seq_num_i          (viq_deq_seq),
    .instruction        (viq_deq_instr),
    .rs1_data           (viq_deq_rs1),
    .rs2_data           (viq_deq_rs2),
    .is_vec             (viq_deq_is_vec_int),

    .inst_valid         (inst_valid),
    .scalar_pro_ready   (scalar_pro_ready),
    .vec_pro_ack        (vec_pro_ack),
    .vec_pro_ready      (vec_pro_ready),

    .seq_num_o          (vec_seq_num),
    .vec_read_addr_1    (vec_read_addr_1),
    // FIX #21: TYPO fix — lowercase vec_read_addr_2
    .vec_read_addr_2    (vec_read_addr_2),
    .vec_write_addr     (vec_write_addr),

    .error              (error),
    .csr_out            (csr_out),
    .vec_wr_data        (vec_wr_data),
    // FIX #22: execution_inst ab declared signal
    .execution_inst     (execution_inst),

    .rob_commit_vd           (rob_commit_vd),
    .rob_commit_vector_result (rob_commit_vector_result),
    .rob_commit_valid_i         (rob_commit_valid),

    .execution_done(execution_done),
    .csr_done(csr_done),
    .is_stored(is_stored),
    .is_loaded(is_loaded),
    .execution_result(execution_result),

    .mem_addr               (vec_mem_addr),
    .mem_wdata              (vec_mem_wdata),
    .mem_wdata_unit         (vec_mem_wdata_unit),
    .mem_byte_en            (vec_mem_byte_en),
    .mem_wen                (vec_mem_wen),
    .mem_elem_mode          (vec_mem_elem_mode),
    .mem_sew_enc            (vec_mem_sew_enc),
    .mem_ren                (vec_mem_ren),
    .mem_rdata              (vec_mem_rdata)
);

// ============================================================
//          VECTOR VAL/READY CONTROLLER
// ============================================================
val_ready_controller val_ready (
    .clk             (clk),
    .reset           (rst_n),
    .inst_valid      (inst_valid),
    .scalar_pro_ready(scalar_pro_ready),
    .vec_pro_ready   (vec_pro_ready),
    .vec_pro_ack     (vec_pro_ack),
    .inst_done       (inst_done)
);

// ============================================================
//          MEMORY MODULE
// ============================================================
// FIX #23: rob_commit_mem_addr / rob_commit_mem_data alias hata diye
//          Direct rob_commit_vector_mem_addr / _data use karo
memory memory (
    .rst_n       (rst_n),
    .clk         (clk),
    .vec_pro_ack (vec_pro_ack),
    .if2mem_i    (if2mem),
    .mem2if_o    (mem2if),
    .dmem_sel    (dmem_sel),
    .exe2mem_i   (dbus2peri),
    .mem2wrb_o   (mem2dbus),

    .ren_a       (vec_mem_ren),
    .rdata_a     (vec_mem_rdata),
    // FIX #24: Direct vector commit signals use kiye — no undefined aliases
    .addr_a      (rob_commit_vector_mem_addr),
    .wdata_a     (rob_commit_vector_mem_data),
    .wen_a       (rob_commit_vec_mem_wen),
    .byte_en_a   (rob_commit_vec_mem_byte_en),
    .elem_mode_a (rob_commit_vec_mem_elem_mode),
    .sew_a       (rob_commit_vec_mem_sew_enc)
);

// ============================================================
//          DBUS INTERCONNECT
// ============================================================
dbus_interconnect dbus (
    .rst_n        (rst_n),
    .clk          (clk),
    .lsu2dbus_i   (lsu2dbus),
    .dbus2lsu_o   (dbus2lsu),
    .mem2dbus_i   (mem2dbus),
    .uart2dbus_i  (uart2dbus),
    .clint2dbus_i (clint2dbus),
    .plic2dbus_i  (plic2dbus),
    .spi2dbus_i   (spi2dbus),
    .gpio2dbus_i  (gpio2dbus),
    .dmem_sel_o   (dmem_sel),
    .uart0_sel_o  (uart0_sel),
    .uart1_sel_o  (uart1_sel),
    .clint_sel_o  (clint_sel),
    .plic_sel_o   (plic_sel),
    .spi0_sel_o   (spi0_sel),
    .spi1_sel_o   (spi1_sel),
    .gpioA_sel_o  (gpioA_sel),
    .gpioB_sel_o  (gpioB_sel),
    .gpioC_sel_o  (gpioC_sel),
    .gpsw_sel_o   (gpsw_sel),
    .gpled_sel_o  (gpled_sel),
    .dbus2peri_o  (dbus2peri)
);

// ============================================================
//          OUTPUT ASSIGNMENTS
// FIX #25: Yeh ab valid port assignments hain (port list mein declare hain)
// ============================================================
assign lsu2dbus_o = lsu2dbus;
assign if2mem_o   = if2mem;

endmodule : pipeline_top