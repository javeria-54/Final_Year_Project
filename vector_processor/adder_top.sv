`include "vector_processor_defs.svh"
`include "vector_execution_unit.svh"
module vector_adder_subtractor (
    input  logic                            Ctrl,       // 0=Add, 1=Subtract
    input  logic                            sew_16_32,  // 1=16 or 32-bit, 0=8-bit
    input  logic                            sew_32,     // 1=32-bit mode
    input  logic signed [`VLEN-1:0]         A,          // Full vector operand A
    input  logic signed [`VLEN-1:0]         B,          // Full vector operand B
    output logic signed [`VLEN-1:0]         Sum,        // Full vector result
    output logic        [(`VLEN/8)-1:0]     carry_out,
    output logic                            sum_done    // All slices valid
);

    logic [`NUM_ELEMENT_SEW32-1:0] sum_done_array;

    genvar i;
    generate
        for (i = 0; i < `NUM_ELEMENT_SEW32; i++) begin : units

            // Instantiate one 32-bit adder/subtractor per slice
            // Each slice handles 32 bits of A and B independently
            adder_subtractor_32bit units (
                .Ctrl      (Ctrl),
                .sew_16_32 (sew_16_32),
                .sew_32    (sew_32),
                .A         (A[i*32 +: 32]),         // 32-bit slice of A
                .B         (B[i*32 +: 32]),         // 32-bit slice of B
                .Sum       (Sum[i*32 +: 32]),       // 32-bit result slice
                .carry_out (carry_out[i*4 +:4]),
                .sum_done  (sum_done_array[i])      // Per-slice valid flag
            );
        end
    endgenerate

    // Global sum_done: asserted only when ALL slices report valid output
    // Uses reduction AND operator (&) across the sum_done_array
    assign sum_done = &sum_done_array;

endmodule
