// Copyright 2025 Maktab-e-Digital Systems Lahore.
// Licensed under the Apache License, Version 2.0, see LICENSE file for details.
// SPDX-License-Identifier: Apache-2.0
//
// Author: Javeria
// =============================================================================
// RISCV Processor Full-System Testbench
// =============================================================================

// RISCV Processor Full-System Testbench (Modified)
module tb_riscv_processor;

    logic clk, rst;
    int passed = 0, failed = 0, total = 0;
    logic is_vector;

    // Instantiate your DUT (Design Under Test)
    single_cycle_processor_top dut (
        .clk(clk),
        .is_vector(is_vector),
        .rst(rst)
    );

    // Clock generation
    always #5 clk = ~clk;

    // Test task to check expected instruction
    task check_instr(input [31:0] expected, input string msg);
        #1;
        total++;
        if (dut.instruction === expected) begin
            passed++;
            $display("[PASS] %s | PC = %h, Instr = %h", msg, dut.pc_next, dut.instruction);
        end else begin
            failed++;
            $display("[FAIL] %s | PC = %h, Instr = %h (expected %h)", msg, dut.pc_next, dut.instruction, expected);
        end
    endtask

    // Test sequence
    initial begin
        $display("=== RISCV Processor Test Start ===");
        clk = 0;
        rst = 1;
        #20;
        rst = 0;

        repeat (10) begin
            case (dut.pc_next)
                32'h00000000: check_instr(32'h00500093, "ADDI x1, x0, 5");
                32'h00000004: check_instr(32'h00600113, "ADDI x2, x0, 6");
                32'h00000008: check_instr(32'h002081b3, "ADD x3, x1, x2");
                32'h0000000C: check_instr(32'h0d007057, "vector_instruction");
                32'h00000010: check_instr(32'h00000013, "NOP");
                default:      check_instr(32'h00000013, "Default NOP");
            endcase
            #10;
        end

        $display("=== RISCV Processor Summary ===");
        $display("Total: %0d | Passed: %0d | Failed: %0d", total, passed, failed);
        if (failed == 0) $display("✅ All tests passed.");
        else $display("❌ Some tests failed.");
        $finish;
    end
endmodule