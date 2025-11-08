`timescale 1ns/1ps

module tb_bit_32;

    logic clk;
    logic reset;
    logic start;
    logic [15:0] mult_out;   // FSM input
    logic [63:0] product;    // FSM final product

    // 32-bit operands
    logic [31:0] A, B;
    logic [7:0]  A_bytes [3:0];
    logic [7:0]  B_bytes [3:0];
    logic [15:0] partial_products [15:0];
    
    logic [15:0] pp_pipe1;
    logic [63:0] expected_sum; // Running software model

    // Instantiate DUT (now with start)
    bit_32 uut (
        .clk(clk),
        .reset(reset),
        .start(start),       // connected to TB start
        .mult_out(mult_out),
        .product(product)
    );

    // Clock generation
    always #5 clk = ~clk;

    initial begin
        int row, col, k;

        clk = 0;
        reset = 1;
        start = 0;
        mult_out = 0;
       
        pp_pipe1 = 0;
        A = 32'h12345678;
        B = 32'h9ABCDEF0;
        expected_sum = 64'd0;

        // Break into 8-bit chunks
        A_bytes[0] = A[7:0];
        A_bytes[1] = A[15:8];
        A_bytes[2] = A[23:16];
        A_bytes[3] = A[31:24];

        B_bytes[0] = B[7:0];
        B_bytes[1] = B[15:8];
        B_bytes[2] = B[23:16];
        B_bytes[3] = B[31:24];

        // Precompute raw 8-bit×8-bit products
        partial_products[0]  = A_bytes[0] * B_bytes[0]; //16'h7080; 
        partial_products[1]  = A_bytes[1] * B_bytes[0]; //16'h50A0;
        partial_products[2]  = A_bytes[2] * B_bytes[0]; //16'h30C0;
        partial_products[3]  = A_bytes[3] * B_bytes[0]; //16'h10E0;
        partial_products[4]  = A_bytes[0] * B_bytes[1]; //16'h6810;
        partial_products[5]  = A_bytes[1] * B_bytes[1]; //16'h4A9A; 
        partial_products[6]  = A_bytes[2] * B_bytes[1]; //16'h2D18;
        partial_products[7]  = A_bytes[3] * B_bytes[1]; //16'h0F9C;
        partial_products[8]  = A_bytes[0] * B_bytes[2]; //16'h5820; 
        partial_products[9]  = A_bytes[1] * B_bytes[2]; //16'h3F28;
        partial_products[10] = A_bytes[2] * B_bytes[2]; //16'h2630;
        partial_products[11] = A_bytes[3] * B_bytes[2]; //16'h0D38;
        partial_products[12] = A_bytes[0] * B_bytes[3]; //16'h4830; 
        partial_products[13] = A_bytes[1] * B_bytes[3]; //16'h33BC; 
        partial_products[14] = A_bytes[2] * B_bytes[3]; //16'h1F48;
        partial_products[15] = A_bytes[3] * B_bytes[3]; //16'h0AD4; 

        // Release reset
        #10 reset = 0;
        @(posedge clk);
        start = 1;  // tell FSM to begin

        /*// Loop over partial products
        for (k = 0; k < 18; k++) begin
            @(posedge clk);
            mult_out <= partial_products[k];
            row = k / 4;
            col = k % 4;
            expected_sum += partial_products[k] << ((row + col) * 8);

            $display("Cycle %0d | PP%0d = %h | Expected = %016h | FSM = %016h",
                     k, k+1, mult_out, expected_sum, product);
        end
        */
         for (k = 0; k < 18; k++) begin
            @(posedge clk);

    // Feed new PP for first 16 cycles
            if (k < 16)
                mult_out <= partial_products[k];
            else
                mult_out <= 0;

    // Shift register delay for expected calculation
            
            pp_pipe1 <= mult_out;

    // Update expected_sum from pp_pipe2 (2-cycle delayed)
            if (k > 1 && (k-2) < 16) begin
                row = (k-2) / 4;
                col = (k-2) % 4;
                expected_sum += pp_pipe1 << ((row + col) * 8);
            end

            $display("Cycle %0d | PP = %h | Expected = %016h | FSM = %016h",
             k, mult_out, expected_sum, product);
        end

        // Stop feeding inputs
        @(posedge clk);
        start = 0;

        // Let FSM reach DONE
         @(posedge clk);

        $display("FINAL RESULT: Expected = %016h | FSM = %016h", expected_sum, product);
        $finish;
    end

endmodule

