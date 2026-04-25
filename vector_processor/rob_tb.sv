// ============================================================
// Testbench for ROB (Reorder Buffer) module
// Compatible with ModelSim / QuestaSim
// ============================================================

`timescale 1ns/1ps

// ---- Minimal macro definitions (match your actual defs) ----
`ifndef XLEN
  `define XLEN        32
`endif
`ifndef VLEN
  `define VLEN        512
`endif
`ifndef Tag_Width
  `define Tag_Width   4
`endif
`ifndef ROB_DEPTH
  `define ROB_DEPTH   16
`endif
`ifndef REG_ADDR_W
  `define REG_ADDR_W  5
`endif
`ifndef VREG_ADDR_W
  `define VREG_ADDR_W 5
`endif
`ifndef RF_AWIDTH
  `define RF_AWIDTH   5
`endif

module rob_tb;

    // --------------------------------------------------------
    // Clock & Reset
    // --------------------------------------------------------
    logic clk;
    logic rst_n;

    always #5 clk = ~clk; // 100 MHz clock

    // --------------------------------------------------------
    // DUT port signals
    // --------------------------------------------------------

    // Fetch interface
    logic                           fetch_valid_i;
    logic [`XLEN-1:0]               fetch_instr_i;
    logic                           rob_full_o;

    // ROB → Decode
    logic                           rob_de_valid_o;
    logic [`XLEN-1:0]               rob_de_instr_o;
    logic [`Tag_Width-1:0]          rob_de_seq_num_o;

    // Decode → ROB
    logic                           de_valid_i;
    logic [`Tag_Width-1:0]          de_seq_num_i;
    logic                           de_is_vector_i;
    logic                           de_scalar_store_i;
    logic                           de_vector_store_i;
    logic                           de_scalar_load_i;
    logic                           de_vector_load_i;
    logic [4:0]                     de_scalar_rd_addr_i;
    logic [`VREG_ADDR_W-1:0]        de_vector_vd_addr_i;
    logic [`RF_AWIDTH-1:0]          de_rs1_addr_i;
    logic [`RF_AWIDTH-1:0]          de_rs2_addr_i;
    logic [`VREG_ADDR_W-1:0]        de_vs1_addr_i;
    logic [`VREG_ADDR_W-1:0]        de_vs2_addr_i;

    // Register file read data
    logic [`XLEN-1:0]               rf2rob_rs1_data_i;
    logic [`XLEN-1:0]               rf2rob_rs2_data_i;

    // Scalar forwarding outputs
    logic                           fwd_rs1_hit_o;
    logic [`XLEN-1:0]               fwd_rs1_val_o;
    logic                           fwd_rs2_hit_o;
    logic [`XLEN-1:0]               fwd_rs2_val_o;
    logic [`XLEN-1:0]               fwd_rs1_data_o;
    logic [`XLEN-1:0]               fwd_rs2_data_o;

    // Vector forwarding outputs
    logic                           fwd_vs1_hit_o;
    logic [`VLEN-1:0]               fwd_vs1_val_o;
    logic                           fwd_vs2_hit_o;
    logic [`VLEN-1:0]               fwd_vs2_val_o;
    logic [`VLEN-1:0]               fwd_vs1_data_o;
    logic [`VLEN-1:0]               fwd_vs2_data_o;

    // VIQ dispatch interface
    logic                           viq_dispatch_valid_o;
    logic [`XLEN-1:0]               viq_dispatch_instr_o;
    logic [`Tag_Width-1:0]          viq_dispatch_seq_num_o;
    logic [`VREG_ADDR_W-1:0]        viq_dispatch_vd_o;
    logic [`VREG_ADDR_W-1:0]        viq_dispatch_vs1_o;
    logic [`VREG_ADDR_W-1:0]        viq_dispatch_vs2_o;
    logic [`XLEN-1:0]               viq_dispatch_rs1_data_o;
    logic [`XLEN-1:0]               viq_dispatch_rs2_data_o;
    logic                           viq_dispatch_is_load_o;
    logic                           viq_dispatch_is_store_o;
    logic                           viq_full_i;
    logic                           stall_viq_full_o;
    logic                           stall_scalar_raw_o;

    // Scalar writeback
    logic                           scalar_done_i;
    logic [`Tag_Width-1:0]          scalar_seq_num_i;
    logic [`REG_ADDR_W-1:0]         scalar_rd_addr_i;
    logic [`XLEN-1:0]               scalar_result_i;
    logic [`XLEN-1:0]               scalar_mem_addr_i;
    logic [`XLEN-1:0]               scalar_mem_data_i;
    logic                           scalar_exception_i;
    logic [`XLEN-1:0]               scalar_mem_data_o;

    // Vector writeback
    logic                           vector_done_i;
    logic [`Tag_Width-1:0]          vector_seq_num_i;
    logic [`VREG_ADDR_W-1:0]        vector_vd_addr_i;
    logic [`VLEN-1:0]               vector_result_i;
    logic [`XLEN-1:0]               vector_mem_addr_i;
    logic [`VLEN-1:0]               vector_mem_data_i;
    logic                           vector_exception_i;
    logic [`VLEN-1:0]               vector_mem_data_o;

    // Vector RAW stall
    logic [`VREG_ADDR_W-1:0]        viq_src1_reg_i;
    logic [`VREG_ADDR_W-1:0]        viq_src2_reg_i;
    logic                           stall_vec_raw_o;

    // Memory ordering stalls
    logic                           stall_fetch_o;
    logic                           stall_scalar_mem_o;
    logic                           stall_vector_mem_o;

    // Commit interface
    logic                           commit_valid_o;
    logic [`Tag_Width-1:0]          commit_vector_seq_num_o;
    logic [`Tag_Width-1:0]          commit_scalar_seq_num_o;
    logic                           commit_is_vector_o;
    logic                           commit_scalar_store_o;
    logic                           commit_vector_store_o;
    logic [`REG_ADDR_W-1:0]         commit_rd_o;
    logic [`VREG_ADDR_W-1:0]        commit_vd_o;
    logic [`XLEN-1:0]               commit_scalar_result_o;
    logic [`VLEN-1:0]               commit_vector_result_o;
    logic [`XLEN-1:0]               commit_mem_addr_o;
    logic [`VLEN-1:0]               commit_mem_data_o;
    logic [`XLEN-1:0]               commit_scalar_mem_data_o;
    logic                           commit_exception_o;

    // Flush interface
    logic                           flush_valid_i;
    logic [`Tag_Width-1:0]          flush_seq_i;

    // --------------------------------------------------------
    // DUT Instantiation
    // --------------------------------------------------------
    rob dut (
        .clk                    (clk),
        .rst_n                  (rst_n),

        .fetch_valid_i          (fetch_valid_i),
        .fetch_instr_i          (fetch_instr_i),
        .rob_full_o             (rob_full_o),

        .rob_de_valid_o         (rob_de_valid_o),
        .rob_de_instr_o         (rob_de_instr_o),
        .rob_de_seq_num_o       (rob_de_seq_num_o),

        .de_valid_i             (de_valid_i),
        .de_seq_num_i           (de_seq_num_i),
        .de_is_vector_i         (de_is_vector_i),
        .de_scalar_store_i      (de_scalar_store_i),
        .de_vector_store_i      (de_vector_store_i),
        .de_scalar_load_i       (de_scalar_load_i),
        .de_vector_load_i       (de_vector_load_i),
        .de_scalar_rd_addr_i    (de_scalar_rd_addr_i),
        .de_vector_vd_addr_i    (de_vector_vd_addr_i),
        .de_rs1_addr_i          (de_rs1_addr_i),
        .de_rs2_addr_i          (de_rs2_addr_i),
        .de_vs1_addr_i          (de_vs1_addr_i),
        .de_vs2_addr_i          (de_vs2_addr_i),

        .rf2rob_rs1_data_i      (rf2rob_rs1_data_i),
        .rf2rob_rs2_data_i      (rf2rob_rs2_data_i),

        .fwd_rs1_hit_o          (fwd_rs1_hit_o),
        .fwd_rs1_val_o          (fwd_rs1_val_o),
        .fwd_rs2_hit_o          (fwd_rs2_hit_o),
        .fwd_rs2_val_o          (fwd_rs2_val_o),
        .fwd_rs1_data_o         (fwd_rs1_data_o),
        .fwd_rs2_data_o         (fwd_rs2_data_o),

        .fwd_vs1_hit_o          (fwd_vs1_hit_o),
        .fwd_vs1_val_o          (fwd_vs1_val_o),
        .fwd_vs2_hit_o          (fwd_vs2_hit_o),
        .fwd_vs2_val_o          (fwd_vs2_val_o),
        .fwd_vs1_data_o         (fwd_vs1_data_o),
        .fwd_vs2_data_o         (fwd_vs2_data_o),

        .viq_dispatch_valid_o   (viq_dispatch_valid_o),
        .viq_dispatch_instr_o   (viq_dispatch_instr_o),
        .viq_dispatch_seq_num_o (viq_dispatch_seq_num_o),
        .viq_dispatch_vd_o      (viq_dispatch_vd_o),
        .viq_dispatch_vs1_o     (viq_dispatch_vs1_o),
        .viq_dispatch_vs2_o     (viq_dispatch_vs2_o),
        .viq_dispatch_rs1_data_o(viq_dispatch_rs1_data_o),
        .viq_dispatch_rs2_data_o(viq_dispatch_rs2_data_o),
        .viq_dispatch_is_load_o (viq_dispatch_is_load_o),
        .viq_dispatch_is_store_o(viq_dispatch_is_store_o),
        .viq_full_i             (viq_full_i),
        .stall_viq_full_o       (stall_viq_full_o),
        .stall_scalar_raw_o     (stall_scalar_raw_o),

        .scalar_done_i          (scalar_done_i),
        .scalar_seq_num_i       (scalar_seq_num_i),
        .scalar_rd_addr_i       (scalar_rd_addr_i),
        .scalar_result_i        (scalar_result_i),
        .scalar_mem_addr_i      (scalar_mem_addr_i),
        .scalar_mem_data_i      (scalar_mem_data_i),
        .scalar_exception_i     (scalar_exception_i),
        .scalar_mem_data_o      (scalar_mem_data_o),

        .vector_done_i          (vector_done_i),
        .vector_seq_num_i       (vector_seq_num_i),
        .vector_vd_addr_i       (vector_vd_addr_i),
        .vector_result_i        (vector_result_i),
        .vector_mem_addr_i      (vector_mem_addr_i),
        .vector_mem_data_i      (vector_mem_data_i),
        .vector_exception_i     (vector_exception_i),
        .vector_mem_data_o      (vector_mem_data_o),

        .viq_src1_reg_i         (viq_src1_reg_i),
        .viq_src2_reg_i         (viq_src2_reg_i),
        .stall_vec_raw_o        (stall_vec_raw_o),

        .stall_fetch_o          (stall_fetch_o),
        .stall_scalar_mem_o     (stall_scalar_mem_o),
        .stall_vector_mem_o     (stall_vector_mem_o),

        .commit_valid_o         (commit_valid_o),
        .commit_vector_seq_num_o(commit_vector_seq_num_o),
        .commit_scalar_seq_num_o(commit_scalar_seq_num_o),
        .commit_is_vector_o     (commit_is_vector_o),
        .commit_scalar_store_o  (commit_scalar_store_o),
        .commit_vector_store_o  (commit_vector_store_o),
        .commit_rd_o            (commit_rd_o),
        .commit_vd_o            (commit_vd_o),
        .commit_scalar_result_o (commit_scalar_result_o),
        .commit_vector_result_o (commit_vector_result_o),
        .commit_mem_addr_o      (commit_mem_addr_o),
        .commit_mem_data_o      (commit_mem_data_o),
        .commit_scalar_mem_data_o(commit_scalar_mem_data_o),
        .commit_exception_o     (commit_exception_o),

        .flush_valid_i          (flush_valid_i),
        .flush_seq_i            (flush_seq_i)
    );

    // --------------------------------------------------------
    // Helper task: reset all inputs
    // --------------------------------------------------------
    task reset_inputs();
        fetch_valid_i       = 0;
        fetch_instr_i       = 0;
        de_valid_i          = 0;
        de_seq_num_i        = 0;
        de_is_vector_i      = 0;
        de_scalar_store_i   = 0;
        de_vector_store_i   = 0;
        de_scalar_load_i    = 0;
        de_vector_load_i    = 0;
        de_scalar_rd_addr_i = 0;
        de_vector_vd_addr_i = 0;
        de_rs1_addr_i       = 0;
        de_rs2_addr_i       = 0;
        de_vs1_addr_i       = 0;
        de_vs2_addr_i       = 0;
        rf2rob_rs1_data_i   = 0;
        rf2rob_rs2_data_i   = 0;
        viq_full_i          = 0;
        scalar_done_i       = 0;
        scalar_seq_num_i    = 0;
        scalar_rd_addr_i    = 0;
        scalar_result_i     = 0;
        scalar_mem_addr_i   = 0;
        scalar_mem_data_i   = 0;
        scalar_exception_i  = 0;
        vector_done_i       = 0;
        vector_seq_num_i    = 0;
        vector_vd_addr_i    = 0;
        vector_result_i     = 0;
        vector_mem_addr_i   = 0;
        vector_mem_data_i   = 0;
        vector_exception_i  = 0;
        viq_src1_reg_i      = 0;
        viq_src2_reg_i      = 0;
        flush_valid_i       = 0;
        flush_seq_i         = 0;
    endtask

    // --------------------------------------------------------
    // Helper task: send one fetch + one decode cycle
    // --------------------------------------------------------
    task automatic fetch_and_decode(
        input logic [31:0]              instr,
        input logic [4:0]               rd_addr,
        input logic [`Tag_Width-1:0]    seq_num,
        input logic                     is_vec,
        input logic [4:0]               vd, vs1, vs2,
        input logic [4:0]               rs1, rs2,
        input logic [31:0]              rs1_data, rs2_data
    );
        // FETCH cycle
        @(negedge clk);
        fetch_valid_i       = 1;
        fetch_instr_i       = instr;

        @(negedge clk);
        fetch_valid_i       = 0;

        // DECODE cycle
        de_valid_i          = 1;
        de_seq_num_i        = seq_num;
        de_is_vector_i      = is_vec;
        de_scalar_rd_addr_i = rd_addr;
        de_vector_vd_addr_i = vd;
        de_vs1_addr_i       = vs1;
        de_vs2_addr_i       = vs2;
        de_rs1_addr_i       = rs1;
        de_rs2_addr_i       = rs2;
        rf2rob_rs1_data_i   = rs1_data;
        rf2rob_rs2_data_i   = rs2_data;
        de_scalar_store_i   = 0;
        de_vector_store_i   = 0;
        de_scalar_load_i    = 0;
        de_vector_load_i    = 0;

        @(negedge clk);
        de_valid_i = 0;
    endtask

    // --------------------------------------------------------
    // Helper task: scalar writeback
    // --------------------------------------------------------
    task automatic scalar_writeback(
        input logic [`Tag_Width-1:0]  seq,
        input logic [4:0]             rd,
        input logic [31:0]            result
    );
        @(negedge clk);
        scalar_done_i      = 1;
        scalar_seq_num_i   = seq;
        scalar_rd_addr_i   = rd;
        scalar_result_i    = result;
        scalar_exception_i = 0;
        scalar_mem_addr_i  = 0;
        scalar_mem_data_i  = 0;

        @(negedge clk);
        scalar_done_i = 0;
    endtask

    // --------------------------------------------------------
    // Helper task: check and print pass/fail
    // --------------------------------------------------------
    int pass_count;
    int fail_count;

    task automatic check(
        input string   test_name,
        input logic    condition
    );
        if (condition) begin
            $display("[PASS] %s", test_name);
            pass_count++;
        end else begin
            $display("[FAIL] %s  <--- FAILED", test_name);
            fail_count++;
        end
    endtask

    // --------------------------------------------------------
    // MAIN TEST
    // --------------------------------------------------------
    initial begin
        clk        = 0;
        rst_n      = 0;
        pass_count = 0;
        fail_count = 0;

        reset_inputs();
        $display("=== ROB Testbench Starting ===");

        // Apply reset for 3 cycles
        repeat (3) @(negedge clk);
        rst_n = 1;
        @(negedge clk);

        // ==================================================
        // TEST 1: Reset — ROB should be empty, not full
        // ==================================================
        $display("\n--- TEST 1: Reset State ---");
        check("rob_full_o = 0 after reset",    rob_full_o    == 1'b0);
        check("commit_valid_o = 0 after reset", commit_valid_o == 1'b0);
        check("rob_de_valid_o = 0 after reset", rob_de_valid_o == 1'b0);

        // ==================================================
        // TEST 2: Fetch one scalar instruction
        // ==================================================
        $display("\n--- TEST 2: Fetch Scalar Instruction ---");
        @(negedge clk);
        fetch_valid_i = 1;
        fetch_instr_i = 32'hDEAD_BEEF; // Dummy scalar ADD instr
        @(posedge clk); #1;
        check("rob_de_valid_o rises after fetch", rob_de_valid_o == 1'b1);
        check("rob_de_instr_o = fetched instr",   rob_de_instr_o == 32'hDEAD_BEEF);
        @(negedge clk);
        fetch_valid_i = 0;

        // ==================================================
        // TEST 3: Decode fills the ROB entry
        // ==================================================
        $display("\n--- TEST 3: Decode Fill ---");
        @(negedge clk);
        de_valid_i          = 1;
        de_seq_num_i        = rob_de_seq_num_o; // use seq from ROB
        de_is_vector_i      = 0;
        de_scalar_rd_addr_i = 5'd3;  // rd = x3
        de_rs1_addr_i       = 5'd1;
        de_rs2_addr_i       = 5'd2;
        rf2rob_rs1_data_i   = 32'hAAAA_1111;
        rf2rob_rs2_data_i   = 32'hBBBB_2222;
        de_scalar_store_i   = 0;
        de_scalar_load_i    = 0;
        @(negedge clk);
        de_valid_i = 0;
        // commit_valid should still be 0 (not done yet)
        check("commit_valid_o = 0 before writeback", commit_valid_o == 1'b0);

        // ==================================================
        // TEST 4: Scalar Writeback -> commit fires
        // ==================================================
        $display("\n--- TEST 4: Scalar Writeback & Commit ---");
        @(negedge clk);
        scalar_done_i      = 1;
        scalar_seq_num_i   = de_seq_num_i;
        scalar_rd_addr_i   = 5'd3;
        scalar_result_i    = 32'hCAFE_BABE;
        scalar_exception_i = 0;
        @(negedge clk);
        scalar_done_i = 0;
        @(posedge clk); #1;
        check("commit_valid_o = 1 after writeback",       commit_valid_o == 1'b1);
        check("commit_is_vector_o = 0 (scalar)",          commit_is_vector_o == 1'b0);
        check("commit_scalar_result = 0xCAFEBABE",        commit_scalar_result_o == 32'hCAFE_BABE);
        check("commit_rd_o = x3",                         commit_rd_o == 5'd3);

        repeat(2) @(negedge clk);

        // ==================================================
        // TEST 5: Scalar Forwarding
        //   - Fetch instr A -> writes rd=x5
        //   - Fetch instr B -> reads rs1=x5 (should hit ROB)
        // ==================================================
        $display("\n--- TEST 5: Scalar Forwarding (ROB hit) ---");
        reset_inputs();
        @(negedge clk);

        // Fetch instr A
        fetch_valid_i = 1;
        fetch_instr_i = 32'hAAAA_0001;
        @(negedge clk);
        fetch_valid_i = 0;

        // Decode instr A — scalar, rd=x5
        de_valid_i          = 1;
        de_seq_num_i        = rob_de_seq_num_o;
        de_is_vector_i      = 0;
        de_scalar_rd_addr_i = 5'd5;
        @(negedge clk);
        de_valid_i = 0;

        // Writeback instr A — result = 0x1234_5678
        scalar_done_i      = 1;
        scalar_seq_num_i   = 4'd0; // assume first entry
        scalar_rd_addr_i   = 5'd5;
        scalar_result_i    = 32'h1234_5678;
        scalar_exception_i = 0;
        @(negedge clk);
        scalar_done_i = 0;

        // Now fetch instr B which reads rs1=x5
        fetch_valid_i = 1;
        fetch_instr_i = 32'hBBBB_0002;
        @(negedge clk);
        fetch_valid_i = 0;

        de_valid_i          = 1;
        de_seq_num_i        = rob_de_seq_num_o;
        de_is_vector_i      = 0;
        de_scalar_rd_addr_i = 5'd6;
        de_rs1_addr_i       = 5'd5;  // depends on x5
        de_rs2_addr_i       = 5'd0;
        rf2rob_rs1_data_i   = 32'hDEAD_DEAD; // stale reg file value
        @(posedge clk); #1;

        check("fwd_rs1_hit_o = 1 (ROB has x5 done)",  fwd_rs1_hit_o  == 1'b1);
        check("fwd_rs1_val_o = 0x12345678",            fwd_rs1_val_o  == 32'h1234_5678);
        check("fwd_rs1_data_o uses ROB val not regfile", fwd_rs1_data_o == 32'h1234_5678);
        @(negedge clk);
        de_valid_i = 0;

        repeat(2) @(negedge clk);

        // ==================================================
        // TEST 6: Vector Instruction Dispatch to VIQ
        // ==================================================
        $display("\n--- TEST 6: Vector Dispatch to VIQ ---");
        reset_inputs();
        rst_n = 0;
        repeat(2) @(negedge clk);
        rst_n = 1;
        @(negedge clk);

        fetch_valid_i = 1;
        fetch_instr_i = 32'hCCCC_0003; // Fake vector instr
        @(negedge clk);
        fetch_valid_i = 0;

        viq_full_i          = 0;  // VIQ has space
        de_valid_i          = 1;
        de_seq_num_i        = rob_de_seq_num_o;
        de_is_vector_i      = 1;  // IS vector
        de_vector_vd_addr_i = 5'd4;
        de_vs1_addr_i       = 5'd1;
        de_vs2_addr_i       = 5'd2;
        de_rs1_addr_i       = 5'd0;
        de_rs2_addr_i       = 5'd0;
        rf2rob_rs1_data_i   = 32'hABCD_0001;
        rf2rob_rs2_data_i   = 32'hABCD_0002;
        de_vector_load_i    = 0;
        de_vector_store_i   = 0;

        @(posedge clk); #1;
        check("viq_dispatch_valid_o = 1 for vector instr", viq_dispatch_valid_o == 1'b1);
        check("viq_dispatch_vd_o = v4",                    viq_dispatch_vd_o    == 5'd4);
        check("viq_dispatch_vs1_o = v1",                   viq_dispatch_vs1_o   == 5'd1);
        check("viq_dispatch_vs2_o = v2",                   viq_dispatch_vs2_o   == 5'd2);
        @(negedge clk);
        de_valid_i = 0;

        // ==================================================
        // TEST 7: VIQ Full — dispatch should stall
        // ==================================================
        $display("\n--- TEST 7: VIQ Full Stall ---");
        viq_full_i = 1;

        fetch_valid_i = 1;
        fetch_instr_i = 32'hDDDD_0004;
        @(negedge clk);
        fetch_valid_i = 0;

        de_valid_i     = 1;
        de_is_vector_i = 1;
        de_seq_num_i   = rob_de_seq_num_o;
        @(posedge clk); #1;
        check("stall_viq_full_o = 1 when VIQ full",      stall_viq_full_o    == 1'b1);
        check("viq_dispatch_valid_o = 0 when VIQ full",  viq_dispatch_valid_o == 1'b0);
        @(negedge clk);
        de_valid_i = 0;
        viq_full_i = 0;

        // ==================================================
        // TEST 8: Vector Writeback & Commit
        // ==================================================
        $display("\n--- TEST 8: Vector Writeback & Commit ---");
        reset_inputs();
        rst_n = 0;
        repeat(2) @(negedge clk);
        rst_n = 1;
        @(negedge clk);

        fetch_valid_i = 1;
        fetch_instr_i = 32'hEEEE_0005;
        @(negedge clk);
        fetch_valid_i = 0;

        de_valid_i          = 1;
        de_seq_num_i        = rob_de_seq_num_o;
        de_is_vector_i      = 1;
        de_vector_vd_addr_i = 5'd7;
        @(negedge clk);
        de_valid_i = 0;

        // Vector done
        vector_done_i       = 1;
        vector_seq_num_i    = 4'd0;
        vector_vd_addr_i    = 5'd7;
        vector_result_i     = {`VLEN{1'b1}}; // all-1s result
        vector_exception_i  = 0;
        @(negedge clk);
        vector_done_i = 0;

        @(posedge clk); #1;
        check("commit_valid_o = 1 after vector writeback", commit_valid_o     == 1'b1);
        check("commit_is_vector_o = 1",                    commit_is_vector_o == 1'b1);
        check("commit_vd_o = v7",                          commit_vd_o        == 5'd7);

        repeat(2) @(negedge clk);

        // ==================================================
        // TEST 9: Flush
        // ==================================================
        $display("\n--- TEST 9: Flush ---");
        reset_inputs();
        @(negedge clk);

        // Fetch 3 instructions
        repeat(3) begin
            fetch_valid_i = 1;
            fetch_instr_i = $urandom;
            @(negedge clk);
        end
        fetch_valid_i = 0;
        @(negedge clk);

        // Flush from seq 1 onward
        flush_valid_i = 1;
        flush_seq_i   = 4'd1;
        @(negedge clk);
        flush_valid_i = 0;
        @(posedge clk); #1;
        check("rob_de_valid_o = 0 after flush", rob_de_valid_o == 1'b0);
        check("rob not full after flush",        rob_full_o     == 1'b0);

        repeat(2) @(negedge clk);

        // ==================================================
        // TEST 10: Vector RAW stall
        // ==================================================
        $display("\n--- TEST 10: Vector RAW Stall ---");
        reset_inputs();
        rst_n = 0;
        repeat(2) @(negedge clk);
        rst_n = 1;
        @(negedge clk);

        // Fetch + decode vector instr writing vd=v3 (not done)
        fetch_valid_i = 1;
        fetch_instr_i = 32'hFF00_0001;
        @(negedge clk);
        fetch_valid_i = 0;

        de_valid_i          = 1;
        de_seq_num_i        = rob_de_seq_num_o;
        de_is_vector_i      = 1;
        de_vector_vd_addr_i = 5'd3;
        @(negedge clk);
        de_valid_i = 0;

        // Now check RAW stall: next instr reads vs1=v3
        viq_src1_reg_i = 5'd3;
        viq_src2_reg_i = 5'd0;
        @(posedge clk); #1;
        check("stall_vec_raw_o = 1 when vd=v3 in-flight", stall_vec_raw_o == 1'b1);

        // After vector done, stall should clear
        vector_done_i      = 1;
        vector_seq_num_i   = 4'd0;
        vector_vd_addr_i   = 5'd3;
        vector_result_i    = '0;
        vector_exception_i = 0;
        @(negedge clk);
        vector_done_i = 0;
        @(posedge clk); #1;
        check("stall_vec_raw_o = 0 after vector done", stall_vec_raw_o == 1'b0);

        repeat(2) @(negedge clk);

        // ==================================================
        // SUMMARY
        // ==================================================
        $display("\n=========================================");
        $display("  RESULTS: %0d PASSED, %0d FAILED", pass_count, fail_count);
        $display("=========================================");
        if (fail_count == 0)
            $display("  ALL TESTS PASSED");
        else
            $display("  SOME TESTS FAILED — check above");

        $finish;
    end

    // --------------------------------------------------------
    // Waveform dump (optional — comment out if not needed)
    // --------------------------------------------------------
    initial begin
        $dumpfile("rob_tb.vcd");
        $dumpvars(0, rob_tb);
    end

    // --------------------------------------------------------
    // Timeout watchdog
    // --------------------------------------------------------
    initial begin
        #50000;
        $display("[TIMEOUT] Simulation exceeded limit");
        $finish;
    end

endmodule