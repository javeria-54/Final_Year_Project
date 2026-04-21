// ============================================================
//  VIQ Testbench
//  Tests:
//    1. Basic enqueue → dequeue
//    2. Fill to full → stall_vec asserted
//    3. Dequeue from full → stall_vec de-asserted
//    4. Simultaneous enqueue + dequeue
//    5. Reset clears all state
// ============================================================

`timescale 1ns/1ps

module viq_tb;

    // ── Parameters (match DUT) ────────────────────────────────
    localparam DEPTH     = 8;
    localparam SEQ_W     = 8;
    localparam INSTR_W   = 32;
    localparam OPERAND_W = 32;

    // ── DUT signals ───────────────────────────────────────────
    logic                       clk;
    logic                       reset;

    logic                       vector_instr_valid;
    logic [SEQ_W-1:0]           instr_seq_i;
    logic [INSTR_W-1:0]         instruction_i;
    logic [OPERAND_W-1:0]       operand_rs1_i;
    logic [OPERAND_W-1:0]       operand_rs2_i;
    logic                       instr_is_vecmem_i;

    logic                       stall_vec;

    logic                       deq_ready;
    logic                       deq_valid;
    logic [SEQ_W-1:0]           instr_seq_o;
    logic [INSTR_W-1:0]         instruction_o;
    logic [OPERAND_W-1:0]       operand_rs1_o;
    logic [OPERAND_W-1:0]       operand_rs2_o;
    logic                       instr_is_vecmem_o;

    logic [$clog2(DEPTH):0]     num_instr;

    // ── DUT instantiation ─────────────────────────────────────
    viq #(
        .DEPTH      (DEPTH),
        .SEQ_W      (SEQ_W),
        .INSTR_W    (INSTR_W),
        .OPERAND_W  (OPERAND_W)
    ) dut (
        .clk                (clk),
        .reset              (reset),
        .vector_instr_valid (vector_instr_valid),
        .instr_seq_i        (instr_seq_i),
        .instruction_i      (instruction_i),
        .operand_rs1_i      (operand_rs1_i),
        .operand_rs2_i      (operand_rs2_i),
        .instr_is_vecmem_i  (instr_is_vecmem_i),
        .stall_vec          (stall_vec),
        .deq_ready          (deq_ready),
        .deq_valid          (deq_valid),
        .instr_seq_o        (instr_seq_o),
        .instruction_o      (instruction_o),
        .operand_rs1_o      (operand_rs1_o),
        .operand_rs2_o      (operand_rs2_o),
        .instr_is_vecmem_o  (instr_is_vecmem_o),
        .num_instr          (num_instr)
    );

    // ── Clock: 10 ns period ───────────────────────────────────
    initial clk = 0;
    always #5 clk = ~clk;

    // ── Pass/fail counter ─────────────────────────────────────
    int pass_cnt = 0;
    int fail_cnt = 0;

    // ── Task: drive one enqueue ───────────────────────────────
    task automatic enqueue(
        input logic [SEQ_W-1:0]     seq,
        input logic [INSTR_W-1:0]   instr,
        input logic [OPERAND_W-1:0] rs1,
        input logic [OPERAND_W-1:0] rs2,
        input logic                 is_mem
    );
        @(negedge clk);
        vector_instr_valid = 1;
        instr_seq_i        = seq;
        instruction_i      = instr;
        operand_rs1_i      = rs1;
        operand_rs2_i      = rs2;
        instr_is_vecmem_i  = is_mem;
        @(posedge clk); #1;
        vector_instr_valid = 0;
    endtask

    // ── Task: drive one dequeue ───────────────────────────────
    task automatic dequeue();
        @(negedge clk);
        deq_ready = 1;
        @(posedge clk); #1;
        deq_ready = 0;
    endtask

    // ── Task: assert check ────────────────────────────────────
    task automatic check(
        input string  label,
        input logic   got,
        input logic   exp
    );
        if (got === exp) begin
            $display("  PASS  [%0t] %s : got=%0b exp=%0b", $time, label, got, exp);
            pass_cnt++;
        end else begin
            $display("  FAIL  [%0t] %s : got=%0b exp=%0b", $time, label, got, exp);
            fail_cnt++;
        end
    endtask

    // ── Main test sequence ────────────────────────────────────
    initial begin
        // ── Default values ────────────────────────────────────
        reset              = 1;
        vector_instr_valid = 0;
        deq_ready          = 0;
        instr_seq_i        = '0;
        instruction_i      = '0;
        operand_rs1_i      = '0;
        operand_rs2_i      = '0;
        instr_is_vecmem_i  = 0;

        // ── Apply reset for 3 cycles ──────────────────────────
        repeat(3) @(posedge clk);
        @(negedge clk); reset = 0;

        $display("\n======================================");
        $display("  TEST 1: Basic enqueue then dequeue");
        $display("======================================");
        enqueue(8'hA1, 32'hDEAD_BEEF, 32'h1111_1111, 32'h2222_2222, 1'b0);
        @(negedge clk);
        check("deq_valid after 1 enq",  deq_valid,    1'b1);
        check("stall_vec after 1 enq",  stall_vec,    1'b0);
        check("num_instr == 1",         (num_instr == 1), 1'b1);
        check("instr_seq_o",            (instr_seq_o  == 8'hA1),          1'b1);
        check("instruction_o",          (instruction_o == 32'hDEAD_BEEF), 1'b1);
        check("operand_rs1_o",          (operand_rs1_o == 32'h1111_1111), 1'b1);
        check("operand_rs2_o",          (operand_rs2_o == 32'h2222_2222), 1'b1);
        check("instr_is_vecmem_o",      (instr_is_vecmem_o == 1'b0),      1'b1);

        dequeue();
        @(negedge clk);
        check("deq_valid after deq",    deq_valid,    1'b0);
        check("num_instr == 0",         (num_instr == 0), 1'b1);

        // ── TEST 2: Fill VIQ completely ───────────────────────
        $display("\n======================================");
        $display("  TEST 2: Fill VIQ → stall_vec check");
        $display("======================================");
        for (int i = 0; i < DEPTH; i++) begin
            enqueue(i, 32'hC0DE_0000 | i, 32'hAAAA_0000 | i, 32'hBBBB_0000 | i, (i % 2));
        end
        @(negedge clk);
        check("stall_vec asserted (full)",  stall_vec,          1'b1);
        check("num_instr == DEPTH",         (num_instr == DEPTH), 1'b1);

        // ── TEST 3: Enqueue while full → no entry added ───────
        $display("\n======================================");
        $display("  TEST 3: Enqueue while full → blocked");
        $display("======================================");
        enqueue(8'hFF, 32'hDEAD_0000, 32'hDEAD_0001, 32'hDEAD_0002, 1'b1);
        @(negedge clk);
        check("num_instr still DEPTH",  (num_instr == DEPTH), 1'b1);
        check("head seq still 0",       (instr_seq_o == 8'h00), 1'b1);

        // ── TEST 4: Dequeue from full → stall released ────────
        $display("\n======================================");
        $display("  TEST 4: Dequeue from full → stall released");
        $display("======================================");
        dequeue();
        @(negedge clk);
        check("stall_vec de-asserted",   stall_vec,              1'b0);
        check("num_instr == DEPTH-1",    (num_instr == DEPTH-1), 1'b1);
        check("next head seq == 1",      (instr_seq_o == 8'h01), 1'b1);

        // ── TEST 5: Simultaneous enqueue + dequeue ────────────
        $display("\n======================================");
        $display("  TEST 5: Simultaneous enqueue + dequeue");
        $display("======================================");
        // Drain to 1 entry first
        repeat(DEPTH-2) dequeue();
        @(negedge clk);
        check("num_instr == 1 before sim test", (num_instr == 1), 1'b1);

        @(negedge clk);
        // Drive both in same cycle
        vector_instr_valid = 1;
        instr_seq_i        = 8'hBB;
        instruction_i      = 32'hFACE_CAFE;
        operand_rs1_i      = 32'h1234_5678;
        operand_rs2_i      = 32'h8765_4321;
        instr_is_vecmem_i  = 1'b1;
        deq_ready          = 1;
        @(posedge clk); #1;
        vector_instr_valid = 0;
        deq_ready          = 0;
        @(negedge clk);
        check("num_instr == 1 after sim enq+deq", (num_instr == 1), 1'b1);
        check("new head seq == 0xBB",             (instr_seq_o == 8'hBB), 1'b1);
        check("new instr_is_vecmem_o == 1",       (instr_is_vecmem_o == 1'b1), 1'b1);

        // ── TEST 6: Reset clears everything ───────────────────
        $display("\n======================================");
        $display("  TEST 6: Reset clears all state");
        $display("======================================");
        @(negedge clk); reset = 1;
        repeat(2) @(posedge clk); #1;
        check("deq_valid == 0 after reset",  deq_valid,        1'b0);
        check("stall_vec == 0 after reset",  stall_vec,        1'b0);
        check("num_instr == 0 after reset",  (num_instr == 0), 1'b1);
        @(negedge clk); reset = 0;

        // ── Summary ───────────────────────────────────────────
        $display("\n======================================");
        $display("  RESULTS: %0d PASS  |  %0d FAIL", pass_cnt, fail_cnt);
        $display("======================================\n");

        if (fail_cnt == 0)
            $display("ALL TESTS PASSED");
        else
            $display("SOME TESTS FAILED — check above");

        $finish;
    end

    // ── Timeout watchdog ──────────────────────────────────────
    initial begin
        #10000;
        $display("TIMEOUT — simulation hung");
        $finish;
    end

    // ── Waveform dump ─────────────────────────────────────────
    initial begin
        $dumpfile("viq_tb.vcd");
        $dumpvars(0, viq_tb);
    end

endmodule