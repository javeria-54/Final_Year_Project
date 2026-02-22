`timescale 1ns/1ps

`include "vector_multiply_add_unit.sv"
`include "vec_regfile_defs.svh"

module vector_multiply_add_unit_tb;

    logic clk;
    logic reset;

    logic [`MAX_VLEN-1:0] data_A;
    logic [`MAX_VLEN-1:0] data_B;
    logic [`MAX_VLEN-1:0] data_C;

    logic [2:0] accum_op;
    logic [1:0] sew;
    logic signed_mode;
    logic Ctrl;
    logic sew_16_32;
    logic sew_32;
    logic count_0;

    logic [`MAX_VLEN-1:0] sum_product_result;
    logic product_sum_done;

    //---------------------------------
    // DUT
    //---------------------------------
    vector_multiply_add_unit dut (
        .clk(clk),
        .reset(reset),
        .data_A(data_A),
        .data_B(data_B),
        .data_C(data_C),
        .accum_op(accum_op),
        .sew(sew),
        .signed_mode(signed_mode),
        .Ctrl(Ctrl),
        .sew_16_32(sew_16_32),
        .sew_32(sew_32),
        .count_0(count_0),
        .sum_product_result(sum_product_result),
        .product_sum_done(product_sum_done)
    );

    //---------------------------------
    // Clock generation
    //---------------------------------
    initial clk = 0;
    always #5 clk = ~clk;

    //---------------------------------
    // Reset
    //---------------------------------
    task apply_reset();
        begin
            reset = 1;
            #20;
            reset = 0;
        end
    endtask

    //---------------------------------
    // Stimulus Task
    //---------------------------------
    task run_test(
        input [2:0] op,
        input [31:0] A,
        input [31:0] B,
        input [31:0] C
    );
        begin
            accum_op = op;

            data_A = '0;
            data_B = '0;
            data_C = '0;

            data_A[31:0] = A;
            data_B[31:0] = B;
            data_C[31:0] = C;

            @(posedge clk);

            wait(product_sum_done);

            $display("-----------------------------------");
            $display("TIME=%0t", $time);
            $display("OP=%0d A=%0d B=%0d C=%0d",
                     op, A, B, C);
            $display("RESULT=%0d",
                     sum_product_result[31:0]);
            $display("-----------------------------------");
        end
    endtask

    //---------------------------------
    // Test sequence
    //---------------------------------
    initial begin
        $display("Starting Simulation...");

        sew = 2'b10;        // 32-bit mode
        signed_mode = 0;
        Ctrl = 0;
        sew_16_32 = 0;
        sew_32 = 1;

        apply_reset();

        // VMACC → (A * B) + C
        run_test(3'b000, 5, 3, 2);

        // VNMSAC → -(A * B) + C
        Ctrl = 1;
        run_test(3'b010, 4, 2, 10);

        // VMADD → (A * C) + B
        Ctrl = 0;
        run_test(3'b100, 6, 3, 2);

        // VNMSUB → -(A * C) + B
        Ctrl = 1;
        run_test(3'b110, 7, 2, 3);

        #100;
        $finish;
    end

endmodule
