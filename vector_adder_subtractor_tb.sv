`timescale 1ns/1ps
`include "vector_processor_defs.svh"

module tb_vector_adder_subtractor;

    logic Ctrl;
    logic sew_16_32;
    logic sew_32;

    logic signed [`MAX_VLEN-1:0] A;
    logic signed [`MAX_VLEN-1:0] B;
    logic signed [`MAX_VLEN-1:0] Sum;
    logic sum_done;

    // DUT
    vector_adder_subtractor dut (
        .Ctrl(Ctrl),
        .sew_16_32(sew_16_32),
        .sew_32(sew_32),
        .A(A),
        .B(B),
        .Sum(Sum),
        .sum_done(sum_done)
    );

    logic signed [`MAX_VLEN-1:0] expected;

    task run_test;
        input string test_name;
        begin
            #5;

            if (Ctrl == 0)
                expected = A + B;
            else
                expected = A - B;

            $display("--------------------------------------------------");
            $display("TEST: %s", test_name);
            $display("A        = %h", A);
            $display("B        = %h", B);
            $display("Expected = %h", expected);
            $display("Actual   = %h", Sum);

            if (expected === Sum)
                $display("RESULT: PASS\n");
            else
                $display("RESULT: FAIL\n");
        end
    endtask

    initial begin
        $display("Starting Vector Adder/Subtractor Testbench");

        // ---------------- 8-bit ADD ----------------
        Ctrl = 0;
        sew_16_32 = 0;
        sew_32 = 0;
        A = 4096'h01_02_03_04_05_06_07_08;
        B = 4096'h01_01_01_01_01_01_01_01;
        run_test("8-bit ADD");

        // ---------------- 8-bit SUB ----------------
        Ctrl = 1;
        sew_16_32 = 0;
        sew_32 = 0;
        A = 4096'h10_10_10_10_10_10_10_10;
        B = 4096'h01_01_01_01_01_01_01_01;
        run_test("8-bit SUB");

        // ---------------- 16-bit ADD ----------------
        Ctrl = 0;
        sew_16_32 = 1;
        sew_32 = 0;
        A = 4096'h00_02_00_04_00_06_00_08;
        B = 4096'h00_01_00_01_00_01_00_01;
        run_test("16-bit ADD");

        // ---------------- 32-bit ADD ----------------
        Ctrl = 0;
        sew_16_32 = 1;
        sew_32 = 1;
        A = 4096'h00_00_00_02_00_00_00_04;
        B = 4096'h00_00_00_01_00_00_00_01;
        run_test("32-bit ADD");

        // ---------------- 32-bit SUB ----------------
        Ctrl = 1;
        sew_16_32 = 1;
        sew_32 = 1;
        A = 4096'h00_00_00_08_00_00_00_06;
        B = 4096'h00_00_00_01_00_00_00_02;
        run_test("32-bit SUB");

        $display("All tests completed.");
        $finish;
    end

endmodule
