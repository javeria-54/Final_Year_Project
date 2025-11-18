// ============================================
// 512-bit Parallel Wrapper Module
// 16 top modules running simultaneously
// ============================================
module top_wrapper_512(
    input  logic                 clk,
    input  logic                 reset,
    input  logic          [1:0]  sew,        // Common sew for all modules
    input  logic                 start,      // Common start for all modules
    input  logic signed [511:0]  data_in_A,  // 512-bit input A
    input  logic signed [511:0]  data_in_B,  // 512-bit input B
    output logic          [15:0] count_0,    // 16 count_0 signals (one per module)
    output logic signed [1023:0] product     // 1024-bit output (16×64-bit)
);

    // ========================================
    // Internal Wires - 16 modules ke signals
    // ========================================
    
    // Input chunks (32-bit each)
    logic signed [31:0] data_A_chunk [0:15];
    logic signed [31:0] data_B_chunk [0:15];
    
    // Output from each module
    logic signed [31:0] product_1_out [0:15];
    logic signed [31:0] product_2_out [0:15];

    // ========================================
    // Step 1: Input Distribution (512 → 16×32)
    // ========================================
    generate
        genvar i;
        for (i = 0; i < 16; i++) begin : gen_input_split
            // Extract 32-bit chunks from 512-bit input
            // Module 0: bits [31:0]
            // Module 1: bits [63:32]
            // Module 2: bits [95:64]
            // ... and so on
            assign data_A_chunk[i] = data_in_A[(32*i) +: 32];
            assign data_B_chunk[i] = data_in_B[(32*i) +: 32];
        end
    endgenerate

    // ========================================
    // Step 2: Instantiate 16 parallel top modules
    // ========================================
    generate
        genvar j;
        for (j = 0; j < 16; j++) begin : gen_top_modules
            top top_inst (
                // Common signals
                .clk        (clk),
                .reset      (reset),
                .sew        (sew),
                .start      (start),
                
                // Unique inputs for each module
                .data_in_A1 (data_A_chunk[j]),
                .data_in_B1 (data_B_chunk[j]),
                
                // Outputs from each module
                .count_0    (count_0[j]),
                .product_1  (product_1_out[j]),
                .product_2  (product_2_out[j])
            );
        end
    endgenerate

    // ========================================
    // Step 3: Output Collection (16×64 → 1024)
    // ========================================
    generate
        genvar k;
        for (k = 0; k < 16; k++) begin : gen_output_merge
            // Each module produces 64-bit output (product_2 || product_1)
            // Module 0: product[63:0]
            // Module 1: product[127:64]
            // Module 2: product[191:128]
            // ... and so on
            assign product[(64*k) +: 64] = {product_2_out[k], product_1_out[k]};
        end
    endgenerate

endmodule

