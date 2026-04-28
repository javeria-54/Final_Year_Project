//=============================================================
//  rob_tb.sv  —  Testbench for Fixed ROB  (FIXED)
//  Compatible with: Questa / ModelSim / VCS / Xcelium
//=============================================================

`timescale 1ns/1ps

`include "pcore_types_pkg.sv"
import pcore_types_pkg::*;
`include "vector_processor_defs.svh"
`include "scalar_pcore_interface_defs.svh"

module rob_tb;

    // ---------------------------------------------------------
    //  Local parameters matching DUT
    // ---------------------------------------------------------
    localparam int XLEN        = `XLEN;
    localparam int VLEN        = `VLEN;
    localparam int MAX_VLEN    = `MAX_VLEN;
    localparam int TAG_W       = `Tag_Width;
    localparam int ROB_DEPTH   = `ROB_DEPTH;
    localparam int REG_AW      = `REG_ADDR_W;
    localparam int VREG_AW     = `VREG_ADDR_W;
    localparam int RF_AW       = `RF_AWIDTH;

    // FIX 1: Was  XLEN'h0000_0013  — parametric width cast on a literal
    //        is not legal in all tools. Use a plain 32-bit literal instead.
    localparam logic [31:0] NOP_INSTR = 32'h0000_0013;
    localparam int CLK_HALF    = 5; // 10 ns period

    // ---------------------------------------------------------
    //  Clock & reset
    // ---------------------------------------------------------
    logic clk   = 0;
    logic rst_n = 0;
    always #CLK_HALF clk = ~clk;

    // ---------------------------------------------------------
    //  DUT port signals
    // ---------------------------------------------------------
    // Fetch
    logic                   fetch_valid_i  = 0;
    logic [XLEN-1:0]        fetch_instr_i  = 0;

    // To Decode
    logic [XLEN-1:0]        rob_de_instr_o;
    logic [TAG_W-1:0]       rob_de_seq_num_o;

    // From Decode
    logic                   de_valid_i          = 0;
    logic [TAG_W-1:0]       de_seq_num_i        = 0;
    logic                   de_is_vector_i      = 0;
    logic                   de_scalar_store_i   = 0;
    logic                   de_vector_store_i   = 0;
    logic                   de_scalar_load_i    = 0;
    logic                   de_vector_load_i    = 0;
    logic [REG_AW-1:0]      de_scalar_rd_addr_i = 0;
    logic [VREG_AW-1:0]     de_vector_vd_addr_i = 0;
    logic [RF_AW-1:0]       de_rs1_addr_i       = 0;
    logic [RF_AW-1:0]       de_rs2_addr_i       = 0;
    logic [VREG_AW-1:0]     de_vs1_addr_i       = 0;
    logic [VREG_AW-1:0]     de_vs2_addr_i       = 0;

    type_st_ops_e            scalar_store_op_i   = type_st_ops_e'(0);
    logic                   scalar_rd_wr_req     = 0;

    // Reg-file
    logic [XLEN-1:0]        rf2rob_rs1_data_i        = 0;
    logic [XLEN-1:0]        rf2rob_rs2_data_i        = 0;
    logic [XLEN-1:0]        rf2rob_vs1_scalar_data_i = 0;

    // Forwarding (outputs)
    logic [XLEN-1:0]        fwd_rs1_data_o;
    logic [XLEN-1:0]        fwd_rs2_data_o;
    logic [VLEN-1:0]        fwd_vs1_data_o;
    logic [VLEN-1:0]        fwd_vs2_data_o;

    // Stalls
    logic                   stall_scalar_raw_o;
    logic                   stall_viq_full_o;
    logic                   stall_vec_raw_o;
    logic                   stall_fetch_o;

    // VIQ dispatch
    logic                   viq_dispatch_valid_o;
    logic [XLEN-1:0]        viq_dispatch_instr_o;
    logic [TAG_W-1:0]       viq_dispatch_seq_num_o;
    logic [XLEN-1:0]        viq_dispatch_rs1_data_o;
    logic [XLEN-1:0]        viq_dispatch_rs2_data_o;
    logic                   viq_dispatch_is_vec_o;
    logic                   viq_full_i              = 0;

    // Scalar writeback
    logic                   scalar_done_i       = 0;
    logic [TAG_W-1:0]       scalar_seq_num_i    = 0;
    logic [VREG_AW-1:0]     scalar_rd_addr_i    = 0;
    logic [XLEN-1:0]        scalar_result_i     = 0;
    logic [XLEN-1:0]        scalar_mem_addr_i   = 0;
    logic [XLEN-1:0]        scalar_mem_data_i   = 0;

    // Vector writeback
    logic                   vector_done_i       = 0;
    logic [TAG_W-1:0]       vector_seq_num_i    = 0;
    logic [VREG_AW-1:0]     vector_vd_addr_i    = 0;
    logic [MAX_VLEN-1:0]    vector_result_i     = 0;
    logic [XLEN-1:0]        vector_mem_addr_i   = 0;
    logic [VLEN-1:0]        vector_mem_data_i   = 0;
    logic [63:0]            mem_byte_en         = 0;
    logic                   mem_wen             = 0;
    logic                   mem_elem_mode       = 0;
    logic [1:0]             mem_sew_enc         = 0;

    // Commit outputs
    logic                   commit_valid_o;
    logic [TAG_W-1:0]       commit_scalar_seq_num_o;
    logic [TAG_W-1:0]       commit_vector_seq_num_o;
    logic [REG_AW-1:0]      commit_rd_o;
    logic [VREG_AW-1:0]     commit_vd_o;
    logic [XLEN-1:0]        commit_scalar_result_o;
    logic [MAX_VLEN-1:0]    commit_vector_result_o;
    logic [XLEN-1:0]        commit_scalar_mem_addr_o;
    logic [XLEN-1:0]        commit_vec_mem_addr_o;
    logic [XLEN-1:0]        commit_scalar_mem_data_o;
    logic [VLEN-1:0]        commit_vector_mem_data_o;
    logic [63:0]            commit_vector_mem_byte_en;
    logic                   commit_vector_mem_wen;
    logic                   commit_vector_mem_elem_mode;
    logic [1:0]             commit_vector_mem_sew_enc;
    type_st_ops_e            commit_scalar_store_op_o;
    logic                   commit_scalar_rd_wr_req_o;

    // Flush
    logic                   flush_valid_i = 0;
    logic [TAG_W-1:0]       flush_seq_i   = 0;

    // ---------------------------------------------------------
    //  DUT instantiation
    // ---------------------------------------------------------
    rob dut (.*);

    // ---------------------------------------------------------
    //  Test statistics
    // ---------------------------------------------------------
    int pass_cnt = 0;
    int fail_cnt = 0;

    // ---------------------------------------------------------
    //  Helper tasks
    // ---------------------------------------------------------
    task automatic tick(int n = 1);
        repeat(n) @(posedge clk);
        #1; // small delay so outputs settle
    endtask

    task automatic reset_dut();
        rst_n = 0;
        tick(3);
        rst_n = 1;
        tick(1);
    endtask

    // Clear all inputs to safe defaults
    task automatic clear_inputs();
        fetch_valid_i          = 0;
        fetch_instr_i          = 0;
        de_valid_i             = 0;
        de_seq_num_i           = 0;
        de_is_vector_i         = 0;
        de_scalar_store_i      = 0;
        de_vector_store_i      = 0;
        de_scalar_load_i       = 0;
        de_vector_load_i       = 0;
        de_scalar_rd_addr_i    = 0;
        de_vector_vd_addr_i    = 0;
        de_rs1_addr_i          = 0;
        de_rs2_addr_i          = 0;
        de_vs1_addr_i          = 0;
        de_vs2_addr_i          = 0;
        scalar_store_op_i      = type_st_ops_e'(0);
        scalar_rd_wr_req       = 0;
        rf2rob_rs1_data_i      = 0;
        rf2rob_rs2_data_i      = 0;
        rf2rob_vs1_scalar_data_i = 0;
        viq_full_i             = 0;
        scalar_done_i          = 0;
        scalar_seq_num_i       = 0;
        scalar_rd_addr_i       = 0;
        scalar_result_i        = 0;
        scalar_mem_addr_i      = 0;
        scalar_mem_data_i      = 0;
        vector_done_i          = 0;
        vector_seq_num_i       = 0;
        vector_vd_addr_i       = 0;
        vector_result_i        = 0;
        vector_mem_addr_i      = 0;
        vector_mem_data_i      = 0;
        mem_byte_en            = 0;
        mem_wen                = 0;
        mem_elem_mode          = 0;
        mem_sew_enc            = 0;
        flush_valid_i          = 0;
        flush_seq_i            = 0;
    endtask

    // Unified check macro — keeps file/line info
    `define CHECK(label, got, exp) \
        if ((got) === (exp)) begin \
            $display("[PASS] %s", label); \
            pass_cnt++; \
        end else begin \
            $display("[FAIL] %s  got=0x%0h  expected=0x%0h", label, got, exp); \
            fail_cnt++; \
        end

    // Fetch one instruction and return its seq_num
    task automatic do_fetch(
        input  logic [XLEN-1:0] instr,
        output logic [TAG_W-1:0] seq_num
    );
        fetch_valid_i = 1;
        fetch_instr_i = instr;
        @(posedge clk); #1;
        seq_num = rob_de_seq_num_o;
        fetch_valid_i = 0;
        fetch_instr_i = 0;
    endtask

    // Drive decode info for one cycle
    task automatic do_decode(
        input logic [TAG_W-1:0]   seq,
        input logic               is_vec,
        input logic [REG_AW-1:0]  rd,
        input logic [VREG_AW-1:0] vd,
        input logic [RF_AW-1:0]   rs1, rs2,
        input logic [VREG_AW-1:0] vs1, vs2,
        input logic               sc_store, vec_store,
        input logic               sc_load,  vec_load
    );
        de_valid_i          = 1;
        de_seq_num_i        = seq;
        de_is_vector_i      = is_vec;
        de_scalar_rd_addr_i = rd;
        de_vector_vd_addr_i = vd;
        de_rs1_addr_i       = rs1;
        de_rs2_addr_i       = rs2;
        de_vs1_addr_i       = vs1;
        de_vs2_addr_i       = vs2;
        de_scalar_store_i   = sc_store;
        de_vector_store_i   = vec_store;
        de_scalar_load_i    = sc_load;
        de_vector_load_i    = vec_load;
        @(posedge clk); #1;
        de_valid_i          = 0;
        de_scalar_store_i   = 0;
        de_vector_store_i   = 0;
        de_scalar_load_i    = 0;
        de_vector_load_i    = 0;
        de_is_vector_i      = 0;
    endtask

    // Scalar writeback for one cycle
    task automatic scalar_wb(
        input logic [TAG_W-1:0]   seq,
        input logic [VREG_AW-1:0] rd,
        input logic [XLEN-1:0]    result,
        input logic [XLEN-1:0]    mem_addr = 0,
        input logic [XLEN-1:0]    mem_data = 0
    );
        scalar_done_i     = 1;
        scalar_seq_num_i  = seq;
        scalar_rd_addr_i  = rd;
        scalar_result_i   = result;
        scalar_mem_addr_i = mem_addr;
        scalar_mem_data_i = mem_data;
        @(posedge clk); #1;
        scalar_done_i = 0;
    endtask

    // Vector writeback for one cycle
    task automatic vector_wb(
        input logic [TAG_W-1:0]    seq,
        input logic [VREG_AW-1:0]  vd,
        input logic [MAX_VLEN-1:0] result,
        input logic [XLEN-1:0]     maddr  = 0,
        input logic [VLEN-1:0]     mdata  = 0,
        input logic [63:0]         byt_en = '1,
        input logic                wen    = 0,
        input logic                emode  = 0,
        input logic [1:0]          sew    = 0
    );
        vector_done_i     = 1;
        vector_seq_num_i  = seq;
        vector_vd_addr_i  = vd;
        vector_result_i   = result;
        vector_mem_addr_i = maddr;
        vector_mem_data_i = mdata;
        mem_byte_en       = byt_en;
        mem_wen           = wen;
        mem_elem_mode     = emode;
        mem_sew_enc       = sew;
        @(posedge clk); #1;
        vector_done_i = 0;
    endtask

    // =========================================================
    //  TESTS
    // =========================================================

    // ---------------------------------------------------------
    //  TEST 1: Reset Sanity
    // ---------------------------------------------------------
    task automatic test1_reset_sanity();
        $display("\n=== TEST 1: Reset Sanity ===");
        reset_dut();
        clear_inputs();
        tick(2);
        `CHECK("commit_valid after reset",    commit_valid_o,    1'b0)
        `CHECK("stall_fetch after reset",     stall_fetch_o,     1'b0)
        `CHECK("stall_scalar_raw after reset",stall_scalar_raw_o,1'b0)
        `CHECK("viq_dispatch_valid after rst",viq_dispatch_valid_o,1'b0)
    endtask

    // ---------------------------------------------------------
    //  TEST 2: Fetch → Decode path
    // ---------------------------------------------------------
    task automatic test2_fetch_decode();
        logic [TAG_W-1:0] seq;
        $display("\n=== TEST 2: Fetch -> Decode path ===");
        reset_dut(); clear_inputs();

        fetch_valid_i = 1;
        fetch_instr_i = 32'hDEAD_BEEF;
        @(posedge clk); #1;
        `CHECK("rob_de_instr forwarded", rob_de_instr_o, 32'hDEAD_BEEF)
        seq = rob_de_seq_num_o;
        fetch_valid_i = 0;
        @(posedge clk); #1;
        `CHECK("commit_valid stays 0 (not written back)", commit_valid_o, 1'b0)
    endtask

    // ---------------------------------------------------------
    //  TEST 3: Scalar full pipeline (fetch → decode → wb → commit)
    // ---------------------------------------------------------
    task automatic test3_scalar_pipeline();
        logic [TAG_W-1:0] seq;
        $display("\n=== TEST 3: Scalar full pipeline ===");
        reset_dut(); clear_inputs();

        // FIX 2: was 32'hadd00001 — valid hex, kept as-is
        do_fetch(32'hADD0_0001, seq);

        do_decode(.seq(seq), .is_vec(0), .rd(3), .vd(0),
                  .rs1(1), .rs2(2), .vs1(0), .vs2(0),
                  .sc_store(0), .vec_store(0),
                  .sc_load(0), .vec_load(0));

        `CHECK("no commit before writeback", commit_valid_o, 1'b0)

        scalar_wb(.seq(seq), .rd(3), .result(32'hCAFE_0001));

        `CHECK("commit_valid after writeback",  commit_valid_o,        1'b1)
        `CHECK("commit rd",                     commit_rd_o,           REG_AW'(3))
        `CHECK("commit scalar result",          commit_scalar_result_o,32'hCAFE_0001)
        `CHECK("commit scalar seq_num",         commit_scalar_seq_num_o, seq)

        tick(1);
        `CHECK("commit cleared next cycle", commit_valid_o, 1'b0)
    endtask

    // ---------------------------------------------------------
    //  TEST 4: Vector dispatch & commit
    // ---------------------------------------------------------
    task automatic test4_vector_dispatch();
        logic [TAG_W-1:0]    seq;
        logic [MAX_VLEN-1:0] vresult;
        $display("\n=== TEST 4: Vector dispatch & commit ===");
        reset_dut(); clear_inputs();
        vresult = MAX_VLEN'(128'hDEAD_BEEF_CAFE_1234_5678_9ABC_DEF0_0123);

        do_fetch(32'h1234_5678, seq);

        de_valid_i               = 1;
        de_seq_num_i             = seq;
        de_is_vector_i           = 1;
        de_scalar_rd_addr_i      = 0;
        de_vector_vd_addr_i      = 4;
        de_rs1_addr_i            = 1;
        de_rs2_addr_i            = 2;
        de_vs1_addr_i            = 2;
        de_vs2_addr_i            = 3;
        de_scalar_store_i        = 0;
        de_vector_store_i        = 0;
        de_scalar_load_i         = 0;
        de_vector_load_i         = 0;
        rf2rob_rs1_data_i        = 32'hAAAA_1111;
        rf2rob_rs2_data_i        = 32'hBBBB_2222;
        rf2rob_vs1_scalar_data_i = 32'hAAAA_1111;
        @(posedge clk); #1;

        `CHECK("viq_dispatch_valid",   viq_dispatch_valid_o, 1'b1)
        `CHECK("viq_dispatch_is_vec",  viq_dispatch_is_vec_o,1'b1)
        `CHECK("viq_dispatch_seq_num", viq_dispatch_seq_num_o, seq)

        de_valid_i     = 0;
        de_is_vector_i = 0;
        clear_inputs();

        vector_wb(.seq(seq), .vd(4), .result(vresult));

        `CHECK("vector commit_valid",  commit_valid_o, 1'b1)
        `CHECK("commit vd",            commit_vd_o,    VREG_AW'(4))
        `CHECK("commit vector result[31:0]",
               commit_vector_result_o[31:0], vresult[31:0])
        `CHECK("commit vector seq_num",commit_vector_seq_num_o, seq)

        tick(1);
        `CHECK("commit cleared after vector", commit_valid_o, 1'b0)
    endtask

    // ---------------------------------------------------------
    //  TEST 5: Scalar RAW stall
    // ---------------------------------------------------------
    task automatic test5_scalar_raw_stall();
        logic [TAG_W-1:0] seq;
        $display("\n=== TEST 5: Scalar RAW stall ===");
        reset_dut(); clear_inputs();

        do_fetch(32'h0020_81B3, seq);   // ADD x3,x1,x2 — real encoding

        do_decode(.seq(seq), .is_vec(0), .rd(3), .vd(0),
                  .rs1(1), .rs2(2), .vs1(0), .vs2(0),
                  .sc_store(0), .vec_store(0),
                  .sc_load(0), .vec_load(0));

        de_valid_i    = 1;
        de_is_vector_i= 0;
        de_rs1_addr_i = 3;   // RAW on x3
        de_rs2_addr_i = 0;
        de_seq_num_i  = seq;
        #1;
        `CHECK("stall_scalar_raw asserted", stall_scalar_raw_o, 1'b1)

        de_valid_i    = 0;
        de_rs1_addr_i = 0;

        scalar_wb(.seq(seq), .rd(3), .result(32'hABCD_0000));

        de_valid_i    = 1;
        de_rs1_addr_i = 3;
        #1;
        `CHECK("stall_scalar_raw cleared after wb", stall_scalar_raw_o, 1'b0)
        de_valid_i    = 0;
        de_rs1_addr_i = 0;
    endtask

    // ---------------------------------------------------------
    //  TEST 6: Scalar forwarding
    // ---------------------------------------------------------
    task automatic test6_scalar_forwarding();
        logic [TAG_W-1:0] seq;
        $display("\n=== TEST 6: Scalar forwarding ===");
        reset_dut(); clear_inputs();

        do_fetch(32'hAABB_CCDD, seq);
        do_decode(.seq(seq), .is_vec(0), .rd(5), .vd(0),
                  .rs1(0), .rs2(0), .vs1(0), .vs2(0),
                  .sc_store(0), .vec_store(0),
                  .sc_load(0), .vec_load(0));

        scalar_wb(.seq(seq), .rd(5), .result(32'hDEAD_1234));

        de_valid_i        = 1;
        de_rs1_addr_i     = 5;
        de_rs2_addr_i     = 0;
        rf2rob_rs1_data_i = 32'h0;   // reg-file gives stale 0
        #1;
        `CHECK("fwd_rs1 = forwarded result", fwd_rs1_data_o, 32'hDEAD_1234)
        de_valid_i    = 0;
        de_rs1_addr_i = 0;
    endtask

    // ---------------------------------------------------------
    //  TEST 7: VIQ full stall
    //  FIX: was 32'hVECT_0001 — not valid hex.
    //       Replaced with 32'hAECF_0001 (arbitrary valid vector-like opcode).
    // ---------------------------------------------------------
    task automatic test7_viq_full_stall();
        logic [TAG_W-1:0] seq;
        $display("\n=== TEST 7: VIQ full stall ===");
        reset_dut(); clear_inputs();

        do_fetch(32'hAECF_0001, seq);   // arbitrary vector instruction word

        viq_full_i = 1;

        de_valid_i     = 1;
        de_is_vector_i = 1;
        de_seq_num_i   = seq;
        #1;
        `CHECK("stall_viq_full asserted",         stall_viq_full_o,      1'b1)
        `CHECK("viq_dispatch_valid=0 when full",  viq_dispatch_valid_o,  1'b0)

        viq_full_i = 0;
        #1;
        `CHECK("stall_viq_full cleared",          stall_viq_full_o,      1'b0)
        de_valid_i     = 0;
        de_is_vector_i = 0;
    endtask

    // ---------------------------------------------------------
    //  TEST 8: ROB full — fetch stalled
    // ---------------------------------------------------------
    task automatic test8_rob_full();
        logic [TAG_W-1:0] seq;
        $display("\n=== TEST 8: ROB full ===");
        reset_dut(); clear_inputs();

        for (int i = 0; i < ROB_DEPTH; i++) begin
            fetch_valid_i = 1;
            fetch_instr_i = 32'h1000_0000 + XLEN'(i);
            @(posedge clk); #1;
        end
        fetch_valid_i = 0;

        fetch_valid_i = 1;
        fetch_instr_i = 32'hDEAD_DEAD;
        @(posedge clk); #1;
        fetch_valid_i = 0;
        `CHECK("ROB full - fetch stalled (de_instr not DEAD_DEAD)",
               rob_de_instr_o == 32'hDEAD_DEAD, 1'b0)
    endtask

    // ---------------------------------------------------------
    //  TEST 9: Flush
    // ---------------------------------------------------------
    task automatic test9_flush();
        logic [TAG_W-1:0] seq0, seq1, seq2;
        $display("\n=== TEST 9: Flush ===");
        reset_dut(); clear_inputs();

        // FIX: was 32'hAAAA_0001 etc — valid hex, kept as-is
        do_fetch(32'hAAAA_0001, seq0);
        do_fetch(32'hBBBB_0002, seq1);
        do_fetch(32'hCCCC_0003, seq2);

        flush_valid_i = 1;
        flush_seq_i   = {1'b0, seq1};
        @(posedge clk); #1;
        flush_valid_i = 0;
        @(posedge clk); #1;

        scalar_wb(.seq(seq0), .rd(1), .result(32'hF00D_0000));
        `CHECK("seq0 still commitable after flush", commit_valid_o, 1'b1)
        tick(1);

        `CHECK("commit_valid=0 after seq0 commit (seq1/seq2 flushed)",
               commit_valid_o, 1'b0)
    endtask

    // ---------------------------------------------------------
    //  TEST 10: Scalar store commit
    //  FIX: was 32'hSW_INSTR — not valid hex.
    //       SW x2,0(x1) encodes as 32'h0020_A023.
    // ---------------------------------------------------------
    task automatic test10_scalar_store();
        logic [TAG_W-1:0] seq;
        $display("\n=== TEST 10: Scalar store commit ===");
        reset_dut(); clear_inputs();

        do_fetch(32'h0020_A023, seq);   // SW x2, 0(x1)

        de_valid_i          = 1;
        de_seq_num_i        = seq;
        de_is_vector_i      = 0;
        de_scalar_store_i   = 1;
        de_scalar_rd_addr_i = 0;
        de_rs1_addr_i       = 1;
        de_rs2_addr_i       = 2;
        scalar_store_op_i   = type_st_ops_e'(1);
        scalar_rd_wr_req    = 1;
        @(posedge clk); #1;
        de_valid_i        = 0;
        de_scalar_store_i = 0;
        scalar_rd_wr_req  = 0;

        scalar_wb(.seq(seq), .rd(0),
                  .result(0),
                  .mem_addr(32'hBEEF_0100),
                  .mem_data(32'hCAFE_BABE));

        `CHECK("store commit_valid",         commit_valid_o,           1'b1)
        `CHECK("store mem_addr",             commit_scalar_mem_addr_o, 32'hBEEF_0100)
        `CHECK("store mem_data",             commit_scalar_mem_data_o, 32'hCAFE_BABE)
        `CHECK("commit_scalar_rd_wr_req",    commit_scalar_rd_wr_req_o,1'b1)
    endtask

    // ---------------------------------------------------------
    //  TEST 11: NOP — no ROB entry, no tag advance
    //  FIX: was 32'hadd_instr — not valid hex.
    //       Using a distinct real instruction: ADDI x1,x0,1 = 32'h0000_0093
    // ---------------------------------------------------------
    task automatic test11_nop_no_entry();
        logic [TAG_W-1:0] seq_before, seq_after;
        $display("\n=== TEST 11: NOP - no ROB entry allocated ===");
        reset_dut(); clear_inputs();

        do_fetch(32'h0000_0093, seq_before);   // ADDI x1, x0, 1

        scalar_wb(.seq(seq_before), .rd(1), .result(32'h0000_0001));
        tick(1); // commit

        fetch_valid_i = 1;
        fetch_instr_i = NOP_INSTR;   // 32'h0000_0013
        @(posedge clk); #1;
        fetch_valid_i = 0;
        `CHECK("NOP: commit_valid stays 0", commit_valid_o, 1'b0)

        do_fetch(32'hCCCC_CCCC, seq_after);
        `CHECK("NOP: tag not consumed by NOP",
               seq_after, TAG_W'(seq_before + TAG_W'(1)))
    endtask

    // ---------------------------------------------------------
    //  TEST 12: Vector RAW stall
    //  FIX: was 32'hVEC_PROD — not valid hex.
    //       Using 32'h5700_0057 (arbitrary vector-like encoding).
    // ---------------------------------------------------------
    task automatic test12_vector_raw_stall();
        logic [TAG_W-1:0] seq;
        $display("\n=== TEST 12: Vector RAW stall ===");
        reset_dut(); clear_inputs();

        do_fetch(32'h5700_0057, seq);   // arbitrary vector opcode
        do_decode(.seq(seq), .is_vec(1), .rd(0), .vd(4),
                  .rs1(0), .rs2(0), .vs1(1), .vs2(2),
                  .sc_store(0), .vec_store(0),
                  .sc_load(0), .vec_load(0));

        de_valid_i     = 1;
        de_is_vector_i = 1;
        de_vs1_addr_i  = 4;   // RAW on v4
        de_vs2_addr_i  = 0;
        #1;
        `CHECK("stall_vec_raw asserted", stall_vec_raw_o, 1'b1)
        de_valid_i    = 0;

        vector_wb(.seq(seq), .vd(4), .result(MAX_VLEN'(128'hCAFE_0000)));

        de_valid_i    = 1;
        de_vs1_addr_i = 4;
        #1;
        `CHECK("stall_vec_raw cleared after wb", stall_vec_raw_o, 1'b0)
        de_valid_i    = 0;
    endtask

    // ---------------------------------------------------------
    //  TEST 13: VS1 forwarding from ROB (vector result)
    //  FIX: was 32'hVEC_INSTR — not valid hex.
    //       Using 32'h5720_0057.
    // ---------------------------------------------------------
    task automatic test13_vs1_forwarding_from_rob();
        logic [TAG_W-1:0]    seq;
        logic [MAX_VLEN-1:0] vres;
        $display("\n=== TEST 13: VS1 forwarding from ROB ===");
        reset_dut(); clear_inputs();
        vres = MAX_VLEN'(128'hDEAD_CAFE_1234_5678_0000_0000_0000_0000);

        do_fetch(32'h5720_0057, seq);   // arbitrary vector opcode
        do_decode(.seq(seq), .is_vec(1), .rd(0), .vd(6),
                  .rs1(0), .rs2(0), .vs1(0), .vs2(0),
                  .sc_store(0), .vec_store(0),
                  .sc_load(0), .vec_load(0));

        vector_wb(.seq(seq), .vd(6), .result(vres));

        de_valid_i    = 1;
        de_vs1_addr_i = 6;
        #1;
        `CHECK("fwd_vs1 from ROB vector result",
               fwd_vs1_data_o, vres[VLEN-1:0])
        de_valid_i    = 0;
    endtask

    // ---------------------------------------------------------
    //  TEST 14: Simultaneous scalar + vector writeback
    //  FIX: was 32'hSCALAR_OP / 32'hVECTOR_OP — not valid hex.
    //       Using 32'h0010_0133 (ADD x2,x0,x1) and 32'h5740_0057.
    // ---------------------------------------------------------
    task automatic test14_simultaneous_wb();
        logic [TAG_W-1:0] sseq, vseq;
        $display("\n=== TEST 14: Simultaneous scalar + vector writeback ===");
        reset_dut(); clear_inputs();

        do_fetch(32'h0010_0133, sseq);   // ADD x2, x0, x1
        do_fetch(32'h5740_0057, vseq);   // arbitrary vector opcode

        do_decode(.seq(sseq), .is_vec(0), .rd(2), .vd(0),
                  .rs1(0), .rs2(0), .vs1(0), .vs2(0),
                  .sc_store(0), .vec_store(0),
                  .sc_load(0), .vec_load(0));

        do_decode(.seq(vseq), .is_vec(1), .rd(0), .vd(7),
                  .rs1(0), .rs2(0), .vs1(0), .vs2(0),
                  .sc_store(0), .vec_store(0),
                  .sc_load(0), .vec_load(0));

        // Both writebacks in same cycle
        scalar_done_i    = 1;
        scalar_seq_num_i = sseq;
        scalar_rd_addr_i = 2;
        scalar_result_i  = 32'h1111_2222;
        vector_done_i    = 1;
        vector_seq_num_i = vseq;
        vector_vd_addr_i = 7;
        vector_result_i  = MAX_VLEN'(128'hCAFE_BABE_0000_0000_0000_0000_0000_0000);
        @(posedge clk); #1;
        scalar_done_i = 0;
        vector_done_i = 0;

        `CHECK("simultaneous wb: scalar commits first",
               commit_valid_o, 1'b1)
        `CHECK("simultaneous wb: scalar rd=2",
               commit_rd_o, REG_AW'(2))
        `CHECK("simultaneous wb: scalar result",
               commit_scalar_result_o, 32'h1111_2222)
        tick(1);
        `CHECK("simultaneous wb: vector commits second",
               commit_valid_o, 1'b1)
        `CHECK("simultaneous wb: vector vd=7",
               commit_vd_o, VREG_AW'(7))
    endtask

    // ---------------------------------------------------------
    //  TEST 15: Scalar memory stall (stall_fetch when mem in flight)
    //  FIX: was 32'hLW_INSTR — not valid hex.
    //       LW x4, 0(x1) encodes as 32'h0000_A203.
    // ---------------------------------------------------------
    task automatic test15_mem_stall_fetch();
        logic [TAG_W-1:0] seq;
        $display("\n=== TEST 15: stall_fetch when scalar mem in-flight ===");
        reset_dut(); clear_inputs();

        do_fetch(32'h0000_A203, seq);   // LW x4, 0(x1)

        de_valid_i          = 1;
        de_seq_num_i        = seq;
        de_is_vector_i      = 0;
        de_scalar_load_i    = 1;
        de_scalar_rd_addr_i = 4;
        @(posedge clk); #1;
        de_valid_i       = 0;
        de_scalar_load_i = 0;

        #1;
        `CHECK("stall_fetch asserted on scalar load", stall_fetch_o, 1'b1)

        scalar_wb(.seq(seq), .rd(4), .result(32'hDADA_DADA),
                  .mem_addr(32'h0000_1000), .mem_data(32'hDADA_DADA));
        tick(1);
        `CHECK("stall_fetch cleared after commit", stall_fetch_o, 1'b0)
    endtask

    // ---------------------------------------------------------
    //  TEST 16: VIQ not re-dispatched (viq_dispatched flag)
    //  FIX: was 32'hVEC_SINGLE — not valid hex.
    //       Using 32'h5760_0057.
    // ---------------------------------------------------------
    task automatic test16_no_redispatch();
        logic [TAG_W-1:0] seq;
        $display("\n=== TEST 16: VIQ no re-dispatch ===");
        reset_dut(); clear_inputs();

        do_fetch(32'h5760_0057, seq);   // arbitrary vector opcode

        de_valid_i          = 1;
        de_seq_num_i        = seq;
        de_is_vector_i      = 1;
        de_vector_vd_addr_i = 3;
        de_vs1_addr_i       = 0;
        de_vs2_addr_i       = 0;
        @(posedge clk); #1;
        `CHECK("1st dispatch: viq_dispatch_valid=1",
               viq_dispatch_valid_o, 1'b1)

        @(posedge clk); #1;
        `CHECK("2nd decode of same seq: no redispatch",
               viq_dispatch_valid_o, 1'b0)

        de_valid_i     = 0;
        de_is_vector_i = 0;
    endtask

    // ---------------------------------------------------------
    //  TEST 17: Scalar forwarding for x0 (zero reg — no fwd)
    //  FIX: was 32'hADD_X0 — not valid hex (underscore mid-field).
    //       ADDI x0,x0,0 (a NOP variant) — use a distinct instr:
    //       ADD x0,x1,x2 = 32'h0020_8033.
    //       Note: ROB may not allocate rd=x0 result; that is the
    //       point of this test.
    // ---------------------------------------------------------
    task automatic test17_x0_no_forward();
        logic [TAG_W-1:0] seq;
        $display("\n=== TEST 17: x0 no forwarding ===");
        reset_dut(); clear_inputs();

        do_fetch(32'h0020_8033, seq);   // ADD x0, x1, x2
        do_decode(.seq(seq), .is_vec(0), .rd(0)/*x0*/, .vd(0),
                  .rs1(0), .rs2(0), .vs1(0), .vs2(0),
                  .sc_store(0), .vec_store(0),
                  .sc_load(0), .vec_load(0));

        scalar_wb(.seq(seq), .rd(0), .result(32'hDEAD_DEAD));

        de_valid_i        = 1;
        de_rs1_addr_i     = 0;
        rf2rob_rs1_data_i = 32'h0;   // reg-file always 0 for x0
        #1;
        `CHECK("x0 fwd suppressed (returns rf value=0)",
               fwd_rs1_data_o, 32'h0)
        de_valid_i    = 0;
        de_rs1_addr_i = 0;
    endtask

    // =========================================================
    //  MAIN
    // =========================================================
    initial begin
        $timeformat(-9, 0, " ns", 8);
        clear_inputs();

        test1_reset_sanity();
        test2_fetch_decode();
        test3_scalar_pipeline();
        test4_vector_dispatch();
        test5_scalar_raw_stall();
        test6_scalar_forwarding();
        test7_viq_full_stall();
        test8_rob_full();
        test9_flush();
        test10_scalar_store();
        test11_nop_no_entry();
        test12_vector_raw_stall();
        test13_vs1_forwarding_from_rob();
        test14_simultaneous_wb();
        test15_mem_stall_fetch();
        test16_no_redispatch();
        test17_x0_no_forward();

        // Final summary
        $display("\n========================================");
        $display("  ROB TESTBENCH RESULTS");
        $display("  PASSED : %0d", pass_cnt);
        $display("  FAILED : %0d", fail_cnt);
        $display("========================================");
        if (fail_cnt == 0)
            $display(">>> ALL TESTS PASSED <<<");
        else
            $display(">>> %0d TEST(S) FAILED <<<", fail_cnt);

        $finish;
    end

    // Timeout watchdog — 50 000 ns max
    initial begin
        #50000;
        $display("[ERROR] Simulation timeout!");
        $finish;
    end

endmodule