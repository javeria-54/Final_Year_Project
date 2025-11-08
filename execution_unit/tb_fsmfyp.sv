`timescale 1ns/1ps

module tb_bit_16;

    logic clk;
    logic rst;
    logic start;
    logic [15:0] mult_out1, mult_out2; // DUT inputs
    logic [15:0] product1, product2;   // DUT outputs

    // Test variables
    logic [15:0] A, B;
    logic [7:0] A_L, A_H, B_L, B_H;
    logic [15:0] partial_products [3:0];
    logic [31:0] expected_sum1, expected_sum2;

    // Instantiate DUT
    bit_16 uut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .mult_out1(mult_out1),
        .mult_out2(mult_out2),
        .product1(product1),
        .product2(product2)
    );

    // Clock generation
    always #5 clk = ~clk;

    initial begin
        integer k;

        // Init signals
        clk = 0;
        rst = 1;
        start = 0;
        mult_out1 = 0;
        mult_out2 = 0;
        expected_sum1 = 0;
        expected_sum2 = 0;

        // Example operands (8-bit chunks)
        A_L = 8'h78;
        A_H = 8'h56;
        B_L = 8'h34;
        B_H = 8'h12;

        // Make 16-bit numbers (for this TB, each mult_out is a PP pair)
        A = {A_H, A_L};
        B = {B_H, B_L};

        // Precompute partial products for 8×8 chunks
        // mult_out1 and mult_out2 will carry these in your FSM order
        partial_products[0] = A_L * B_L; // PP1 low
        partial_products[1] = A_L * B_H; // PP2
        partial_products[2] = A_H * B_L; // PP3
        partial_products[3] = A_H * B_H; // PP4

        // Release reset
        #10 rst = 0;
        @(posedge clk);
        start = 1;

        // Feed partial products into DUT over cycles
        for (k = 0; k < 4; k++) begin
            @(posedge clk);
            case (k)
                0: begin
                    mult_out1 <= partial_products[0];
                    mult_out2 <= partial_products[0]; // your design takes both
                end
                1: begin
                    mult_out1 <= partial_products[1];
                    mult_out2 <= partial_products[1];
                end
                2: begin
                    mult_out1 <= partial_products[2];
                    mult_out2 <= partial_products[2];
                end
                3: begin
                    mult_out1 <= partial_products[3];
                    mult_out2 <= partial_products[3];
                end
            endcase
        end

        // Stop providing data
        @(posedge clk);
        start = 0;

        // Let FSM complete
        repeat (5) @(posedge clk);

        $display("FINAL: product1 = %h | product2 = %h", product1, product2);
        $finish;
    end

endmodule
