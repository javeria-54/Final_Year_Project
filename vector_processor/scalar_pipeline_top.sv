// Copyright 2023 University of Engineering and Technology Lahore.
// Licensed under the Apache License, Version 2.0, see LICENSE file for details.
// SPDX-License-Identifier: Apache-2.0
//
// Description: The pipeline top module — cleaned & fixed version.
//
// Author: Muhammad Tahir, UET Lahore
// Date: 11.8.2022

`include "scalar_m_ext_defs.svh"
`include "scalar_a_ext_defs.svh"
`include "vector_processor_defs.svh"

`default_nettype wire

module pipeline_top (

    input   wire                        rst_n,
    input   wire                        clk
);

// ============================================================
// Pipeline stage interfaces
// ============================================================
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

// AMO interfaces
type_amo2lsu_data_s                     amo2lsu_data;
type_amo2lsu_ctrl_s                     amo2lsu_ctrl;
type_lsu2amo_data_s                     lsu2amo_data;
type_lsu2amo_ctrl_s                     lsu2amo_ctrl;

// Data bus
type_lsu2dbus_s                         lsu2dbus;
type_dbus2lsu_s                         dbus2lsu;

// Instruction memory
type_if2imem_s                          if2mem;
type_imem2if_s                          mem2if;

// Writeback interfaces
type_lsu2wrb_ctrl_s                     lsu2wrb_ctrl;
type_lsu2wrb_data_s                     lsu2wrb_data;
type_csr2wrb_data_s                     csr2wrb_data;
type_div2wrb_s                          div2wrb;

// Feedback signals
type_csr2if_fb_s                        csr2if_fb;
type_csr2id_fb_s                        csr2id_fb;
type_exe2if_fb_s                        exe2if_fb;
type_wrb2id_fb_s                        wrb2id_fb;

logic [`XLEN-1:0]                       lsu2exe_fb_alu_result;
logic [`XLEN-1:0]                       wrb2exe_fb_rd_data;

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

type_clint2csr_s        clint2csr_i;

type_pipe2csr_s         core2pipe_i;

// ============================================================
// Peripheral bus signals — stubbed (not used in simulation)
// ============================================================
type_peri2dbus_s                        uart2dbus;
type_peri2dbus_s                        clint2dbus;
type_peri2dbus_s                        plic2dbus;
type_peri2dbus_s                        spi2dbus;
type_peri2dbus_s                        gpio2dbus;

// Peripheral stubs — all tied to 0 to prevent X propagation
assign uart2dbus  = '0;
assign clint2dbus = '0;
assign plic2dbus  = '0;
assign spi2dbus   = '0;
assign gpio2dbus  = '0;

//assign dbus2lsu = dbus2lsu_i;
//assign mem2if   = mem2if_i;

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
//type_dbus2peri_s                        dbus2mem;
type_peri2dbus_s                        mem2dbus;

// ============================================================
// Divide done signal
// ============================================================
logic                                   div_done;

// ============================================================
// ROB signals
// ============================================================
logic                                   de_valid;
logic                                   rob_de_valid;
logic [`XLEN-1:0]                       rob_de_instr;
logic [`Tag_Width-1:0]                  rob_de_seq_num;

logic                                   rob_full_o;
logic                                   stall_vec_raw;
logic                                   stall_scalar_mem;
logic                                   stall_vector_mem;
logic                                   stall_fetch;
logic                                   stall_viq_full;
logic                                   stall_scalar_raw;

// Decode-stage flags → ROB
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
logic [`REG_ADDR_W-1:0]                 id2rf_rd_addr;

// ROB scalar forwarding outputs
logic                                   fwd_rs1_hit_o, fwd_rs2_hit_o;
logic [`XLEN-1:0]                       fwd_rs1_val_o, fwd_rs2_val_o;
logic [`XLEN-1:0]                       fwd_rs1_data_o, fwd_rs2_data_o;

// ROB vector forwarding outputs
logic                                   fwd_vs1_hit_o, fwd_vs2_hit_o;
logic [`VLEN-1:0]                       fwd_vs1_val_o, fwd_vs2_val_o;
logic [`VLEN-1:0]                       fwd_vs1_data_o, fwd_vs2_data_o;

// ROB commit outputs
logic                                   rob_commit_valid;
logic [`Tag_Width-1:0]                  rob_commit_vector_seq;
logic [`Tag_Width-1:0]                  rob_commit_scalar_seq;
logic                                   rob_commit_is_vec;
logic                                   rob_commit_scalar_store;
logic                                   rob_commit_vector_store;
logic [`REG_ADDR_W-1:0]                 rob_commit_rd;
logic [`VREG_ADDR_W-1:0]                rob_commit_vd;
logic [`XLEN-1:0]                       rob_commit_scalar_result;
logic [`MAX_VLEN-1:0]                   rob_commit_vector_result;
logic [`XLEN-1:0]                       rob_commit_mem_addr;
logic [`VLEN-1:0]                       rob_commit_mem_data;
logic [`XLEN-1:0]                       rob_commit_scalar_mem_data;
logic [`XLEN-1:0]                       rob_scalar_mem_data_out;

// ROB flush interface
logic                                   flush_valid;
logic [`Tag_Width-1:0]                  flush_seq;

// ============================================================
// VIQ signals
// ============================================================
logic                                   viq_full;
logic                                   viq_stall_o;
logic [`VIQ_tag_width-1:0]              viq_num_instr_o;
logic                                   viq_deq_valid_int;
logic [`Tag_Width-1:0]                  viq_deq_seq_o;
logic [`INSTR_W-1:0]                    viq_deq_instr_o;
logic [`OPERAND_W-1:0]                  viq_deq_rs1_o;
logic [`OPERAND_W-1:0]                  viq_deq_rs2_o;
logic                                   viq_deq_is_vecmem_int;

// VIQ dispatch from ROB
logic                                   viq_dispatch_valid;
logic [`XLEN-1:0]                       viq_dispatch_instr;
logic [`Tag_Width-1:0]                  viq_dispatch_seq_num;
logic [`VREG_ADDR_W-1:0]                viq_dispatch_vd;
logic [`VREG_ADDR_W-1:0]                viq_dispatch_vs1;
logic [`VREG_ADDR_W-1:0]                viq_dispatch_vs2;
logic                                   viq_dispatch_is_load;
logic                                   viq_dispatch_is_store;
logic [`XLEN-1:0]                       viq_dispatch_rs1_data;
logic [`XLEN-1:0]                       viq_dispatch_rs2_data;

// ============================================================
// Vector datapath / controller signals
// ============================================================
logic [`MAX_VLEN-1:0]                   execution_result;
logic                                   execution_done;
logic                                   is_stored;
logic                                   data_written;
logic                                   csr_done;
logic [`XLEN-1:0]                       csr_out;
logic [`MAX_VLEN-1:0]                   vec_wr_data;
logic                                   ld_req, st_req;
logic                                   inst_done;
logic                                   error;

// Vector register file addresses
logic [4:0]                             vec_read_addr_1, vec_read_addr_2, vec_write_addr;

// Vector memory interface
logic [31:0]                            addr_a;
logic [`VLEN-1:0]                       wdata_a;
logic [`VLEN-1:0]                       rdata_a;
logic [`VLEN-1:0]                       mem_rdata;
logic [`VLEN-1:0]                       mem_wdata;
logic [`VLEN-1:0]                       mem_wdata_unit;
logic [63:0]                            mem_byte_en;
logic                                   mem_wen, mem_ren;
logic                                   mem_elem_mode;
logic [1:0]                             mem_sew_enc;

// Connect memory read data to datapath
assign mem_rdata = rdata_a;

// Controller → Datapath signals
logic                                   vl_sel, vtype_sel, lumop_sel, rs1rd_de;
logic                                   csrwr_en, sew_eew_sel, vlmax_evlmax_sel, emul_vlmul_sel;
logic                                   vec_reg_wr_en, mask_operation, mask_wr_en;
logic [1:0]                             data_mux1_sel;
logic                                   data_mux2_sel, data_mux3_sel;
logic                                   offset_vec_en;
logic                                   stride_sel, ld_inst, st_inst, index_str, index_unordered;
logic                                   Ctrl, start;
logic [2:0]                             execution_op;
logic                                   signed_mode;
logic                                   mul_low, mul_high;
logic                                   execution_inst;
logic                                   add_inst, sub_inst, reverse_sub_inst;
logic                                   shift_left_logical_inst, shift_right_arith_inst, shift_right_logical_inst;
logic                                   mul_inst;
logic                                   equal_inst, not_equal_inst;
logic                                   less_or_equal_unsigned_inst, less_or_equal_signed_inst;
logic                                   less_unsinged_inst, greater_unsigned_inst;
logic                                   less_signed_inst, greater_signed_inst;
logic                                   mul_add_dest_inst, mul_sub_dest_inst;
logic                                   mul_add_source_inst, mul_sub_source_inst;
logic                                   mask_and_inst, mask_nand_inst, mask_and_not_inst;
logic                                   mask_xor_inst, mask_or_inst, mask_nor_inst;
logic                                   mask_or_not_inst, mask_xnor_inst;
logic                                   red_sum_inst, red_max_unsigned_inst, red_max_signed_inst;
logic                                   red_min_signed_inst, red_min_unsigned_inst;
logic                                   red_and_inst, red_or_inst, red_xor_inst;
logic                                   signed_min_inst, unsigned_min_inst;
logic                                   signed_max_inst, unsigned_max_inst;
logic                                   move_inst;
logic                                   wid_add_signed_inst, wid_add_unsigned_inst;
logic                                   wid_sub_signed_inst, wid_sub_unsigned_inst;
logic                                   add_carry_inst_inst, sub_borrow_inst;
logic                                   add_carry_masked_inst, sub_borrow_masked_inst;
logic                                   sat_add_signed_inst, sat_add_unsigned_inst;
logic                                   sat_sub_signed_inst, sat_sub_unsigned_inst;
logic                                   and_inst, or_inst, xor_inst;
logic [4:0]                             bitwise_op;
logic [3:0]                             mask_op;
logic [2:0]                             cmp_op, accum_op, shift_op;
logic [1:0]                             op_type;

// Vector handshake
logic                                   vec_pro_ack;
logic                                   vec_pro_ready;
logic                                   scalar_pro_ready;
logic                                   inst_valid;
logic                                   scalar_pro_ack;

// Done signals
logic                                   scalar_done, vector_done;

assign scalar_done = div_done | exe_done | lsu_done;
assign vector_done = execution_done | is_stored | csr_done;

// ============================================================
// Key assignments
// ============================================================

// de_valid — 1 cycle delayed from ROB fetch output (breaks combinational loop)
logic de_valid_d;
always_ff @(posedge clk) begin
    if (!rst_n) de_valid_d <= 1'b0;
    else        de_valid_d <= rob_de_valid;
end
assign de_valid = de_valid_d;

// rd address from execute stage
assign id2rf_rd_addr = exe2lsu_ctrl.rd_addr;

// Flush — only on real exception/branch, not pipeline stalls
assign flush_valid =    exe2csr_data.instr_flushed | csr2fwd.irq_flush_lsu | fwd2ptop.if2id_pipe_flush | 
                        fwd2ptop.id2exe_pipe_flush | fwd2ptop.exe2lsu_pipe_flush | fwd2ptop.lsu2wrb_pipe_flush | 
                        fwd2lsu.lsu_flush ;
assign flush_seq   = '0;

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
    .fwd2if_i     (fwd2if)
);

// ============================================================
//          FETCH -> DECODE PIPELINE REGISTER
// ============================================================
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
`endif

// ============================================================
//                DECODE MODULE
// ============================================================
decode decode_module (
    .rst_n           (rst_n),
    .clk             (clk),
    .is_vector       (is_vector),
    .rob_instr       (rob_de_instr),
    .rob_seq_num     (rob_de_seq_num),
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

// ============================================================
//                EXECUTE MODULE
// ============================================================
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
    .exe2if_fb_o             (exe2if_fb),
    .lsu2exe_fb_alu_result_i (lsu2exe_fb_alu_result),
    .exe_done_o              (exe_done),
    .wrb2exe_fb_rd_data_i    (wrb2exe_fb_rd_data)
);

// ============================================================
//                LSU MODULE
// ============================================================
lsu lsu_module (
    .rst_n                   (rst_n),
    .clk                     (clk),
    .exe2lsu_ctrl_i          (exe2lsu_ctrl),
    .exe2lsu_data_i          (exe2lsu_data),
    .lsu2csr_ctrl_o          (lsu2csr_ctrl),
    .lsu2csr_data_o          (lsu2csr_data),
    .lsu2wrb_ctrl_o          (lsu2wrb_ctrl),
    .lsu2wrb_data_o          (lsu2wrb_data),
    .lsu2exe_fb_alu_result_o (lsu2exe_fb_alu_result),
    .lsu2fwd_o               (lsu2fwd),
    .fwd2lsu_i               (fwd2lsu),
    .lsu2dbus_o              (lsu2dbus),
    .dbus2lsu_i              (dbus2lsu),
    .lsu_flush_o             (lsu_flush_o),
    .lsu_done_o              (lsu_done),
    .lsu2amo_data_o          (lsu2amo_data),
    .lsu2amo_ctrl_o          (lsu2amo_ctrl),
    .amo2lsu_data_i          (amo2lsu_data),
    .amo2lsu_ctrl_i          (amo2lsu_ctrl)
);

// ============================================================
//                CSR MODULE
// ============================================================
csr csr_module (
    .rst_n          (rst_n),
    .clk            (clk),
    .exe2csr_ctrl_i (exe2csr_ctrl),
    .exe2csr_data_i (exe2csr_data),
    .lsu2csr_ctrl_i (lsu2csr_ctrl),
    .lsu2csr_data_i (lsu2csr_data),
    .csr2wrb_data_o (csr2wrb_data),
    .clint2csr_i    (clint2csr_i),
    .pipe2csr_i     (core2pipe_i),
    .fwd2csr_i      (fwd2csr),
    .csr2fwd_o      (csr2fwd),
    .csr2id_fb_o    (csr2id_fb),
    .csr2if_fb_o    (csr2if_fb)
);

// ============================================================
//                WRITEBACK MODULE
// ============================================================
writeback writeback_module (
    .rst_n                (rst_n),
    .clk                  (clk),
    .lsu2wrb_ctrl_i       (lsu2wrb_ctrl),
    .lsu2wrb_data_i       (lsu2wrb_data),
    .csr2wrb_data_i       (csr2wrb_data),
    .div2wrb_i            (div2wrb),
    .wrb2id_fb_o          (wrb2id_fb),
    .wrb2exe_fb_rd_data_o (wrb2exe_fb_rd_data),
    .wrb2fwd_o            (wrb2fwd)
);

// ============================================================
//                FORWARD/STALL MODULE
// ============================================================
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

// ============================================================
//                DIVIDE MODULE (M-extension)
// ============================================================
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

// ============================================================
//                AMO MODULE (A-extension)
// ============================================================
amo amo_module (
    .rst_n          (rst_n),
    .clk            (clk),
    .lsu2amo_data_i (lsu2amo_data),
    .lsu2amo_ctrl_i (lsu2amo_ctrl),
    .amo2lsu_data_o (amo2lsu_data),
    .amo2lsu_ctrl_o (amo2lsu_ctrl)
);

// ============================================================
//          SCALAR VAL/READY CONTROLLER
// ============================================================
single_cycle_val_ready_controller scalar_valid_ready (
    .clk             (clk),
    .reset           (rst_n),
    .is_vector       (is_vector),
    .inst_valid      (inst_valid),
    .vec_pro_ack     (vec_pro_ack),
    .scalar_pro_ready(scalar_pro_ready),
    .scalar_pro_ack  (scalar_pro_ack)
);

// ============================================================
//                ROB MODULE
// ============================================================
rob rob (
    .clk                     (clk),
    .rst_n                   (rst_n),

    // Fetch interface
    .fetch_instr_i           (mem2if.r_data),
    .fetch_valid_i           (mem2if.ack),
    .rob_full_o              (rob_full_o),

    // ROB → Decode
    .rob_de_valid_o          (rob_de_valid),
    .rob_de_instr_o          (rob_de_instr),
    .rob_de_seq_num_o        (rob_de_seq_num),

    // Decode → ROB metadata (1-cycle delayed de_valid)
    .de_valid_i              (de_valid_d),
    .de_seq_num_i            (id2exe_data.seq_num),
    .de_is_vector_i          (is_vector),
    .de_scalar_store_i       (is_scalar_store),
    .de_vector_store_i       (is_vector_store),
    .de_scalar_load_i        (is_scalar_load),
    .de_vector_load_i        (is_vector_load),
    .de_scalar_rd_addr_i     (exe2lsu_ctrl.rd_addr),
    .de_vector_vd_addr_i     (vec_write_addr),
    .de_rs1_addr_i           (id2rf_rs1_addr),
    .de_rs2_addr_i           (id2rf_rs2_addr),
    .de_vs1_addr_i           (vec_read_addr_1),
    .de_vs2_addr_i           (vec_read_addr_2),

    // Scalar forwarding outputs
    .fwd_rs1_hit_o           (fwd_rs1_hit_o),
    .fwd_rs1_val_o           (fwd_rs1_val_o),
    .fwd_rs2_hit_o           (fwd_rs2_hit_o),
    .fwd_rs2_val_o           (fwd_rs2_val_o),
    .fwd_rs1_data_o          (fwd_rs1_data_o),
    .fwd_rs2_data_o          (fwd_rs2_data_o),

    // Vector forwarding outputs
    .fwd_vs1_hit_o           (fwd_vs1_hit_o),
    .fwd_vs1_val_o           (fwd_vs1_val_o),
    .fwd_vs2_hit_o           (fwd_vs2_hit_o),
    .fwd_vs2_val_o           (fwd_vs2_val_o),
    .fwd_vs1_data_o          (fwd_vs1_data_o),
    .fwd_vs2_data_o          (fwd_vs2_data_o),

    // Scalar execution writeback
    .scalar_done_i           (scalar_done),
    .scalar_seq_num_i        (exe2lsu_data.seq_num),
    .scalar_rd_addr_i        (id2rf_rd_addr),
    .scalar_result_i         (exe2lsu_data.alu_result),
    .scalar_mem_addr_i       (lsu2dbus.addr),
    .scalar_mem_data_i       (dbus2lsu.r_data),
    .scalar_mem_data_o       (rob_scalar_mem_data_out),

    // Vector execution writeback
    .vector_done_i           (vector_done),
    .vector_seq_num_i        (viq_deq_seq_o),
    .vector_vd_addr_i        (vec_write_addr),
    .vector_result_i         (execution_result),
    .vector_mem_addr_i       (addr_a),
    .vector_mem_data_i       (rdata_a),
    .vector_mem_data_o       (wdata_a),

    // Vector RAW stall
    .stall_vec_raw_o         (stall_vec_raw),

    // Memory ordering stalls
    .stall_fetch_o           (stall_fetch),
    .stall_scalar_mem_o      (stall_scalar_mem),
    .stall_vector_mem_o      (stall_vector_mem),

    // Commit interface
    .commit_valid_o          (rob_commit_valid),
    .commit_vector_seq_num_o (rob_commit_vector_seq),
    .commit_scalar_seq_num_o (rob_commit_scalar_seq),
    .commit_is_vector_o      (rob_commit_is_vec),
    .commit_scalar_store_o   (rob_commit_scalar_store),
    .commit_vector_store_o   (rob_commit_vector_store),
    .commit_rd_o             (rob_commit_rd),
    .commit_vd_o             (rob_commit_vd),
    .commit_scalar_result_o  (rob_commit_scalar_result),
    .commit_vector_result_o  (rob_commit_vector_result),
    .commit_mem_addr_o       (rob_commit_mem_addr),
    .commit_mem_data_o       (rob_commit_mem_data),
    .commit_scalar_mem_data_o(rob_commit_scalar_mem_data),

    // VIQ dispatch
    .viq_dispatch_valid_o    (viq_dispatch_valid),
    .viq_dispatch_instr_o    (viq_dispatch_instr),
    .viq_dispatch_seq_num_o  (viq_dispatch_seq_num),
    .viq_dispatch_vd_o       (viq_dispatch_vd),
    .viq_dispatch_vs1_o      (viq_dispatch_vs1),
    .viq_dispatch_vs2_o      (viq_dispatch_vs2),
    .viq_dispatch_is_load_o  (viq_dispatch_is_load),
    .viq_dispatch_is_store_o (viq_dispatch_is_store),
    .viq_full_i              (viq_full),
    .stall_viq_full_o        (stall_viq_full),
    .viq_dispatch_rs1_data_o (viq_dispatch_rs1_data),
    .viq_dispatch_rs2_data_o (viq_dispatch_rs2_data),
    .stall_scalar_raw_o      (stall_scalar_raw),

    // Register file data (for ROB forwarding)
    .rf2rob_rs1_data_i       (rf2id_rs1_data),
    .rf2rob_rs2_data_i       (rf2id_rs2_data),

    // Flush interface
    .flush_valid_i           (flush_valid),
    .flush_seq_i             (flush_seq)
);

// ============================================================
//                VIQ MODULE
// ============================================================
viq u_viq (
    .clk                (clk),
    .reset              (rst_n),
    .vector_instr_valid (viq_dispatch_valid),
    .instr_seq_i        (viq_dispatch_seq_num),
    .instruction_i      (viq_dispatch_instr),
    .operand_rs1_i      (viq_dispatch_rs1_data),
    .operand_rs2_i      (viq_dispatch_rs2_data),
    .instr_is_vecmem_i  (viq_dispatch_is_load | viq_dispatch_is_store),
    .stall_vec          (viq_stall_o),
    .num_instr          (viq_num_instr_o),
    .deq_ready          (vec_pro_ready),
    .viq_full           (viq_full),
    .deq_valid          (viq_deq_valid_int),
    .instr_seq_o        (viq_deq_seq_o),
    .instruction_o      (viq_deq_instr_o),
    .operand_rs1_o      (viq_deq_rs1_o),
    .operand_rs2_o      (viq_deq_rs2_o),
    .instr_is_vecmem_o  (viq_deq_is_vecmem_int)
);

// ============================================================
//          VECTOR DATAPATH
// ============================================================
vector_processor_datapth DATAPATH (
    .clk             (clk),
    .reset           (rst_n),
    .instruction     (viq_deq_instr_o),
    .rs1_data        (viq_deq_rs1_o),
    .rs2_data        (viq_deq_rs2_o),
    .seq_num         (viq_deq_seq_o),
    .is_vec          (is_vector),
    .error           (error),
    .st_req          (st_req),
    .ld_req          (ld_req),
    .execution_done  (execution_done),
    .data_written    (data_written),
    .csr_done        (csr_done),
    .is_stored       (is_stored),
    .mem_addr        (addr_a),
    .mem_wdata       (mem_wdata),
    .mem_wdata_unit  (mem_wdata_unit),
    .mem_byte_en     (mem_byte_en),
    .mem_wen         (mem_wen),
    .mem_ren         (mem_ren),
    .mem_elem_mode   (mem_elem_mode),
    .mem_sew_enc     (mem_sew_enc),
    .mem_rdata       (mem_rdata),
    .csr_out         (csr_out),
    .inst_done       (inst_done),
    .vec_read_addr_1 (vec_read_addr_1),
    .vec_read_addr_2 (vec_read_addr_2),
    .vec_write_addr  (vec_write_addr),
    .sew_eew_sel        (sew_eew_sel),
    .vlmax_evlmax_sel   (vlmax_evlmax_sel),
    .emul_vlmul_sel     (emul_vlmul_sel),
    .vl_sel             (vl_sel),
    .vtype_sel          (vtype_sel),
    .lumop_sel          (lumop_sel),
    .csrwr_en           (csrwr_en),
    .rs1rd_de           (rs1rd_de),
    .vec_reg_wr_en      (vec_reg_wr_en),
    .mask_operation     (mask_operation),
    .mask_wr_en         (mask_wr_en),
    .data_mux1_sel      (data_mux1_sel),
    .data_mux2_sel      (data_mux2_sel),
    .data_mux3_sel      (data_mux3_sel),
    .offset_vec_en      (offset_vec_en),
    .stride_sel         (stride_sel),
    .ld_inst            (ld_inst),
    .st_inst            (st_inst),
    .index_str          (index_str),
    .index_unordered    (index_unordered),
    .execution_result   (execution_result),
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

// ============================================================
//          VECTOR CONTROLLER
// ============================================================
vector_processor_controller CONTROLLER (
    .vec_inst                    (viq_deq_instr_o),
    .vl_sel                      (vl_sel),
    .vtype_sel                   (vtype_sel),
    .lumop_sel                   (lumop_sel),
    .csrwr_en                    (csrwr_en),
    .sew_eew_sel                 (sew_eew_sel),
    .vlmax_evlmax_sel            (vlmax_evlmax_sel),
    .emul_vlmul_sel              (emul_vlmul_sel),
    .rs1rd_de                    (rs1rd_de),
    .vec_reg_wr_en               (vec_reg_wr_en),
    .mask_operation              (mask_operation),
    .mask_wr_en                  (mask_wr_en),
    .data_mux1_sel               (data_mux1_sel),
    .data_mux2_sel               (data_mux2_sel),
    .data_mux3_sel               (data_mux3_sel),
    .offset_vec_en               (offset_vec_en),
    .stride_sel                  (stride_sel),
    .ld_inst                     (ld_inst),
    .st_inst                     (st_inst),
    .index_str                   (index_str),
    .index_unordered             (index_unordered),
    .execution_op                (execution_op),
    .signed_mode                 (signed_mode),
    .Ctrl                        (Ctrl),
    .mul_low                     (mul_low),
    .mul_high                    (mul_high),
    .start                       (start),
    .add_inst                    (add_inst),
    .sub_inst                    (sub_inst),
    .reverse_sub_inst            (reverse_sub_inst),
    .shift_left_logical_inst     (shift_left_logical_inst),
    .shift_right_arith_inst      (shift_right_arith_inst),
    .shift_right_logical_inst    (shift_right_logical_inst),
    .execution_inst              (execution_inst),
    .mul_inst                    (mul_inst),
    .equal_inst                  (equal_inst),
    .not_equal_inst              (not_equal_inst),
    .less_or_equal_unsigned_inst (less_or_equal_unsigned_inst),
    .less_or_equal_signed_inst   (less_or_equal_signed_inst),
    .less_unsinged_inst          (less_unsinged_inst),
    .greater_unsigned_inst       (greater_unsigned_inst),
    .less_signed_inst            (less_signed_inst),
    .greater_signed_inst         (greater_signed_inst),
    .mul_add_dest_inst           (mul_add_dest_inst),
    .mul_sub_dest_inst           (mul_sub_dest_inst),
    .mul_add_source_inst         (mul_add_source_inst),
    .mul_sub_source_inst         (mul_sub_source_inst),
    .mask_and_inst               (mask_and_inst),
    .mask_nand_inst              (mask_nand_inst),
    .mask_and_not_inst           (mask_and_not_inst),
    .mask_xor_inst               (mask_xor_inst),
    .mask_or_inst                (mask_or_inst),
    .mask_nor_inst               (mask_nor_inst),
    .mask_or_not_inst            (mask_or_not_inst),
    .mask_xnor_inst              (mask_xnor_inst),
    .red_sum_inst                (red_sum_inst),
    .red_max_unsigned_inst       (red_max_unsigned_inst),
    .red_max_signed_inst         (red_max_signed_inst),
    .red_min_signed_inst         (red_min_signed_inst),
    .red_min_unsigned_inst       (red_min_unsigned_inst),
    .red_and_inst                (red_and_inst),
    .red_or_inst                 (red_or_inst),
    .red_xor_inst                (red_xor_inst),
    .signed_min_inst             (signed_min_inst),
    .unsigned_min_inst           (unsigned_min_inst),
    .signed_max_inst             (signed_max_inst),
    .unsigned_max_inst           (unsigned_max_inst),
    .move_inst                   (move_inst),
    .wid_add_signed_inst         (wid_add_signed_inst),
    .wid_add_unsigned_inst       (wid_add_unsigned_inst),
    .wid_sub_signed_inst         (wid_sub_signed_inst),
    .wid_sub_unsigned_inst       (wid_sub_unsigned_inst),
    .add_carry_inst_inst         (add_carry_inst_inst),
    .sub_borrow_inst             (sub_borrow_inst),
    .add_carry_masked_inst       (add_carry_masked_inst),
    .sub_borrow_masked_inst      (sub_borrow_masked_inst),
    .sat_add_signed_inst         (sat_add_signed_inst),
    .sat_add_unsigned_inst       (sat_add_unsigned_inst),
    .sat_sub_signed_inst         (sat_sub_signed_inst),
    .sat_sub_unsigned_inst       (sat_sub_unsigned_inst),
    .and_inst                    (and_inst),
    .or_inst                     (or_inst),
    .xor_inst                    (xor_inst),
    .mask_op                     (mask_op),
    .bitwise_op                  (bitwise_op),
    .op_type                     (op_type),
    .cmp_op                      (cmp_op),
    .shift_op                    (shift_op),
    .accum_op                    (accum_op)
);

// ============================================================
//          VECTOR VAL/READY CONTROLLER
// ============================================================
val_ready_controller VAL_READY_INTERFACE (
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
memory memory (
    .rst_n       (rst_n),
    .clk         (clk),
    .vec_pro_ack (vec_pro_ack),
    .if2mem_i    (if2mem),
    .mem2if_o    (mem2if),
    .dmem_sel    (dmem_sel),
    .exe2mem_i   (dbus2peri),//(dbus2mem),
    .mem2wrb_o   (mem2dbus),
    .addr_a      (addr_a),
    .wdata_a     (wdata_a),
    .rdata_a     (rdata_a),
    .wen_a       (mem_wen),
    .ren_a       (mem_ren),
    .byte_en_a   (mem_byte_en),
    .elem_mode_a (mem_elem_mode),
    .sew_a       (mem_sew_enc)
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
// ============================================================
assign lsu2dbus_o = lsu2dbus;
assign if2mem_o   = if2mem;

endmodule : pipeline_top