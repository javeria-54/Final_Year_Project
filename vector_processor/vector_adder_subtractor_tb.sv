`timescale 1ns/1ps
`include "vector_processor_defs.svh"

module tb_vector_adder_subtractor;

    logic Ctrl;
    logic sew_16_32;
    logic sew_32;

    logic signed [`VLEN-1:0] A;
    logic signed [`VLEN-1:0] B;
    logic signed [`VLEN-1:0] Sum;
    logic sum_done;

    logic [63:0] carry_out;

    logic signed [`VLEN-1:0] expected;

    int pass_count = 0;
    int fail_count = 0;
    int total_tests = 0;

    // DUT
    vector_adder_subtractor dut (
        .Ctrl(Ctrl),
        .sew_16_32(sew_16_32),
        .sew_32(sew_32),
        .A(A),
        .B(B),
        .Sum(Sum),
        .carry_out(carry_out),
        .sum_done(sum_done)
    );

    // ---------------------------------------------------
    // TASK : RUN TEST
    // ---------------------------------------------------

    task run_test(input string name);

        int i;

        begin

            #1;

            expected = '0;

            //---------------------------------------------
            // 8 BIT MODE
            //---------------------------------------------
            if(sew_16_32==0 && sew_32==0) begin

                for(i=0;i<64;i++) begin

                    if(Ctrl)
                        expected[i*8 +:8] = A[i*8 +:8] - B[i*8 +:8];
                    else
                        expected[i*8 +:8] = A[i*8 +:8] + B[i*8 +:8];

                end

            end

            //---------------------------------------------
            // 16 BIT MODE
            //---------------------------------------------
            else if(sew_16_32==1 && sew_32==0) begin

                for(i=0;i<32;i++) begin

                    if(Ctrl)
                        expected[i*16 +:16] = A[i*16 +:16] - B[i*16 +:16];
                    else
                        expected[i*16 +:16] = A[i*16 +:16] + B[i*16 +:16];

                end

            end

            //---------------------------------------------
            // 32 BIT MODE
            //---------------------------------------------
            else if(sew_16_32==1 && sew_32==1) begin

                for(i=0;i<16;i++) begin

                    if(Ctrl)
                        expected[i*32 +:32] = A[i*32 +:32] - B[i*32 +:32];
                    else
                        expected[i*32 +:32] = A[i*32 +:32] + B[i*32 +:32];

                end

            end

            //---------------------------------------------
            // RESULT CHECK
            //---------------------------------------------

            total_tests++;

            if(Sum === expected) begin
                pass_count++;
                $display("PASS  | %s",name);
            end
            else begin

                fail_count++;

                $display("FAIL  | %s",name);
                $display("A = %h",A);
                $display("B = %h",B);
                $display("Expected = %h",expected);
                $display("Got = %h",Sum);

            end

        end

    endtask


    //-----------------------------------------------------
    // MAIN TEST
    //-----------------------------------------------------

    initial begin

        $display("Starting Vector Adder/Subtractor Testbench");

        // ---------------- 8-bit RANDOM TESTS ----------------

        sew_16_32 = 0;
        sew_32    = 0;

        repeat(10000) begin

            Ctrl = $urandom_range(0,1);

            A = {$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,
                 $urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom};

            B = {$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,
                 $urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom};

            if(Ctrl)
                run_test("8-bit RANDOM SUB");
            else
                run_test("8-bit RANDOM ADD");

        end


        // ---------------- 16-bit RANDOM TESTS ----------------

        sew_16_32 = 1;
        sew_32    = 0;

        repeat(10000) begin

            Ctrl = $urandom_range(0,1);

            A = {$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,
                 $urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom};

            B = {$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,
                 $urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom};

            if(Ctrl)
                run_test("16-bit RANDOM SUB");
            else
                run_test("16-bit RANDOM ADD");

        end


        // ---------------- 32-bit RANDOM TESTS ----------------

        sew_16_32 = 1;
        sew_32    = 1;

        repeat(10000) begin

            Ctrl = $urandom_range(0,1);

            A = {$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,
                 $urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom};

            B = {$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,
                 $urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom};

            if(Ctrl)
                run_test("32-bit RANDOM SUB");
            else
                run_test("32-bit RANDOM ADD");

        end


        //-----------------------------------------------------
        // FINAL SUMMARY
        //-----------------------------------------------------

        $display("=================================");
        $display("TOTAL TESTS : %0d", total_tests);
        $display("PASS TESTS  : %0d", pass_count);
        $display("FAIL TESTS  : %0d", fail_count);
        $display("=================================");

        $finish;

    end

endmodule