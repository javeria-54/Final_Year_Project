`timescale 1ns/1ps

// Self-checking test bench for 8x8 Dadda multiplier
module dadda_8TB();

    parameter M = 8, N = 8;

    // Inputs
    reg  [N-1:0] mult1_A;
    reg  [M-1:0] mult1_B;

    // Output
    wire [N+M-1:0] mult_out_1;

    // ---- Instantiation of main test module ----
    dadda_8 UUT (
        .A(mult1_A),
        .B(mult1_B),
        .y(mult_out_1)
    );

    // Stimulus and self-checking
    initial begin
        repeat(15) begin
            #10  mult1_A = $random; 
                 mult1_B = $random;

            #100; // wait for operation to settle

            if ((mult1_A * mult1_B) !== mult_out_1) 
                $error("Mismatch! A=%0d, B=%0d, Expected=%0d, Got=%0d", 
                        mult1_A, mult1_B, mult1_A * mult1_B, mult_out_1);

        end
        $finish;
    end

endmodule
