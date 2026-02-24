`include "vec_de_csr_defs.svh"
`include "vector_processor_defs.svh"
`include "vec_regfile_defs.svh"

// =============================================================================
// FILE: vector_multiplier.sv
// DESCRIPTION:
//   Vectorized integer multiplier supporting 8-bit, 16-bit, and 32-bit
//   element widths (SEW). Uses a pipeline of:
//     Stage 1 - multiplier_8:   Input preparation & absolute value extraction
//     Stage 2 - dadda_8:        Eight 8x8 Dadda multipliers (combinational)
//     Stage 3 - delay registers: 1-cycle stall to align data
//     Stage 4 - carry_save_8:   Carry-save accumulation FSM → final product
//   Instantiated 16x in vector_multiplier to handle 512-bit inputs.
// =============================================================================


// =============================================================================
// MODULE: multiplier_8
// DESCRIPTION:
//   Prepares 8-bit operand pairs for the eight Dadda multiplier instances.
//   Splits two 32-bit inputs (A, B) into four 8-bit chunks each (A0–A3, B0–B3).
//   In signed_mode, computes two's-complement absolute values at the granularity
//   dictated by SEW (8-bit, 16-bit, or 32-bit). Sign bits are passed out so
//   the final stage can restore the correct sign.
//
//   For SEW=32 (2'b10), a 2-bit cycle counter generates 'count_0' to select
//   between the lower (B0/B1) and upper (B2/B3) bytes of B across two cycles,
//   enabling time-multiplexed partial product generation.
//
// INPUTS:
//   clk, reset      - Clock and synchronous reset
//   data_in_A/B     - 32-bit operands
//   sew             - Element width: 00=8b, 01=16b, 10=32b
//   signed_mode     - Treat operands as signed (two's complement)
//
// OUTPUTS:
//   count_0         - Cycle flag: high when computing upper-byte partials (SEW=32)
//   mult[1–8]_A/B   - Byte-wide operand pairs routed to each Dadda instance
//   sign_A[0–3]     - MSB (sign) of each byte of A (used for sign restoration)
//   sign_B[0–3]     - MSB (sign) of each byte of B
// =============================================================================


// =============================================================================
// MODULE: dadda_8
// DESCRIPTION:
//   8×8-bit Dadda multiplier producing a 16-bit product.
//   Uses a tree of half-adders (HA) and carry-save adders (csa_dadda) to
//   reduce the 64 partial products in 5 stages down to a final sum.
//   Fully combinational (no registers).
//
//   Partial product array gen_pp[i][j] = B[i] & A[j].
//   Reduction stages target Dadda heights: 6 → 4 → 3 → 2 → 1.
//
// INPUTS:  A, B  - 8-bit unsigned operands (absolute values from multiplier_8)
// OUTPUT:  y     - 16-bit product
// =============================================================================


// =============================================================================
// MODULE: HA (Half Adder)
// DESCRIPTION:
//   Standard 1-bit half adder.
//   Sum  = a XOR b
//   Cout = a AND b
// =============================================================================


// =============================================================================
// MODULE: csa_dadda (Carry-Save Adder cell)
// DESCRIPTION:
//   1-bit full-adder used as the CSA cell in the Dadda multiplier tree.
//   Y    = A XOR B XOR Cin   (sum)
//   Cout = majority(A, B, Cin)
// =============================================================================


// =============================================================================
// MODULE: carry_save_8
// DESCRIPTION:
//   FSM-based carry-save accumulator that combines partial products from the
//   eight Dadda multipliers into a final 64-bit result (two 32-bit halves).
//
//   STATE MACHINE:
//     IDLE    - Waits for 'start'. Resets accumulators.
//     PP_8    - SEW=8:  Stores four 16-bit Dadda outputs directly → DONE.
//     PP_16   - SEW=16: CSA-reduces four partial products per 16-bit element
//                       into two 32-bit results → DONE.
//     PP1_32  - SEW=32, cycle 1: CSA-reduces eight partial products covering
//                       the low byte contributions → PP2_32.
//     PP2_32  - SEW=32, cycle 2: CSA-reduces the high byte contributions and
//                       combines with PP1_32 accumulators → DONE.
//     DONE    - Asserts mult_done for one cycle → IDLE.
//
//   Helper functions:
//     csa_3to2(a,b,c)         - 3:2 CSA returning {carry[7:0], sum[7:0]}
//     add_sum_carry(sum,carry) - Adds sum + (carry<<1), returns 10-bit result
//     add_carry_8bit(v,c1,c2,c3) - Adds 8-bit value with up to 3 carry bits
//
// INPUTS:
//   clk, reset           - Clock and reset
//   sew                  - Element width selector
//   start                - Pulse to begin a new multiplication
//   mult_out_[1–8]       - 16-bit partial products from the eight Dadda units
//
// OUTPUTS:
//   mult_done            - High for one cycle when result is valid
//   product_1            - Lower 32 bits of result  (or full result for SEW=8)
//   product_2            - Upper 32 bits of result
// =============================================================================


// =============================================================================
// MODULE: top_8
// DESCRIPTION:
//   Pipeline wrapper combining all four stages for one 32-bit processing element:
//     1. multiplier_8  - Operand prep / absolute value / byte routing
//     2. dadda_8 (×8)  - Eight parallel 8×8 multiplications
//     3. Delay regs    - 1-cycle pipeline register to align Dadda outputs
//                        with the carry_save_8 FSM start
//     4. carry_save_8  - Accumulates partial products → 64-bit product
//
//   Sign restoration (always_comb block at output):
//     After unsigned accumulation, applies two's-complement negation to the
//     result based on sign_A XOR sign_B for the appropriate element granularity.
//
// INPUTS:
//   clk, reset      - Clock / reset
//   sew             - Element width: 00=8b, 01=16b, 10=32b
//   start           - Begin new multiply
//   signed_mode     - Enable signed arithmetic
//   data_in_A/B     - 32-bit operand inputs
//
// OUTPUTS:
//   count_0         - Forwarded from multiplier_8 (SEW=32 cycle selector)
//   mult_done       - Multiplication complete
//   product         - 64-bit result (packed per SEW)
// =============================================================================


// =============================================================================
// MODULE: vector_multiplier
// DESCRIPTION:
//   Top-level 512-bit vector multiplier. Instantiates 16 'top_8' processing
//   elements (PEs), each handling a 32-bit slice of the input vectors.
//
//   Each PE operates independently on its 32-bit window of data_in_A/B.
//   The global mult_done is the AND of all 16 PE done signals (all must finish).
//   The global count_0 is the AND of all 16 PE count_0 signals.
//
//   Output packing:
//     For all SEW values, each PE contributes 64 bits of product packed
//     contiguously into the 1025-bit output bus (16 PEs × 64 bits = 1024 bits).
//
// PARAMETERS:
//   NUM_PES = 16  (512-bit input / 32 bits per PE)
//
// INPUTS:
//   clk, reset    - Clock / reset
//   start         - Start pulse
//   sew           - Element width selector
//   data_in_A/B   - 512-bit operand vectors
//   signed_mode   - Signed arithmetic enable
//
// OUTPUTS:
//   count_0       - Cycle phase flag (all PEs in sync)
//   mult_done     - All PEs have completed
//   product       - 1025-bit packed product vector
// =============================================================================
module multiplier_8 (
    input logic         clk,
    input logic         reset,
    input logic [31:0]  data_in_A,
    input logic [31:0]  data_in_B,
    input logic [1:0]   sew,
    input logic         signed_mode,

    output logic        count_0,    
    output logic [7:0]  mult1_A,
    output logic [7:0]  mult1_B,
    output logic [7:0]  mult2_A,
    output logic [7:0]  mult2_B,
    output logic [7:0]  mult3_A,
    output logic [7:0]  mult3_B,
    output logic [7:0]  mult4_A,
    output logic [7:0]  mult4_B,
    output logic [7:0]  mult5_A,
    output logic [7:0]  mult5_B,
    output logic [7:0]  mult6_A,
    output logic [7:0]  mult6_B,
    output logic [7:0]  mult7_A,
    output logic [7:0]  mult7_B,
    output logic [7:0]  mult8_A,
    output logic [7:0]  mult8_B,

    // Sign outputs for result adjustment
    output logic        sign_A0, sign_A1, sign_A2, sign_A3,
    output logic        sign_B0, sign_B1, sign_B2, sign_B3
);   
    
    logic [7:0] A0, A1, A2, A3;
    logic [7:0] B0, B1, B2, B3;
    logic [7:0] A0_abs, A1_abs, A2_abs, A3_abs;
    logic [7:0] B0_abs, B1_abs, B2_abs, B3_abs;
    logic sew_was_2;
    logic count_0_prev;
    
    // Extract 8-bit chunks
    assign A0 = data_in_A[7:0];
    assign A1 = data_in_A[15:8];
    assign A2 = data_in_A[23:16];
    assign A3 = data_in_A[31:24];
    assign B0 = data_in_B[7:0]; 
    assign B1 = data_in_B[15:8];
    assign B2 = data_in_B[23:16];
    assign B3 = data_in_B[31:24];

    assign sign_A0 = A0[7];
    assign sign_A1 = A1[7];
    assign sign_A2 = A2[7];
    assign sign_A3 = A3[7];
    assign sign_B0 = B0[7];
    assign sign_B1 = B1[7];
    assign sign_B2 = B2[7];
    assign sign_B3 = B3[7];

    // Compute absolute values based on SEW
    always_comb begin
        if (signed_mode) begin
            case (sew)
                2'b00: begin // 8-bit: individual two's complement
                    A0_abs = sign_A0 ? (~A0 + 8'd1) : A0;
                    A1_abs = sign_A1 ? (~A1 + 8'd1) : A1;
                    A2_abs = sign_A2 ? (~A2 + 8'd1) : A2;
                    A3_abs = sign_A3 ? (~A3 + 8'd1) : A3;
                
                    B0_abs = sign_B0 ? (~B0 + 8'd1) : B0;
                    B1_abs = sign_B1 ? (~B1 + 8'd1) : B1;
                    B2_abs = sign_B2 ? (~B2 + 8'd1) : B2;
                    B3_abs = sign_B3 ? (~B3 + 8'd1) : B3;
                end
                2'b01: begin // 16-bit: two's complement on 16-bit pairs
                    {A1_abs, A0_abs} = sign_A1 ? (~{A1, A0} + 16'd1) : {A1, A0};
                    {A3_abs, A2_abs} = sign_A3 ? (~{A3, A2} + 16'd1) : {A3, A2};
                
                    {B1_abs, B0_abs} = sign_B1 ? (~{B1, B0} + 16'd1) : {B1, B0};
                    {B3_abs, B2_abs} = sign_B3 ? (~{B3, B2} + 16'd1) : {B3, B2};
                end
                2'b10: begin // 32-bit: two's complement on full 32-bit
                    {A3_abs, A2_abs, A1_abs, A0_abs} = sign_A3 ?  (~data_in_A + 32'd1) : data_in_A;
                    {B3_abs, B2_abs, B1_abs, B0_abs} = sign_B3 ?  (~data_in_B + 32'd1) : data_in_B;
                end
                default: begin
                    A0_abs = A0; A1_abs = A1; A2_abs = A2; A3_abs = A3;
                    B0_abs = B0; B1_abs = B1; B2_abs = B2; B3_abs = B3;
                end
            endcase
        end
        else if (!signed_mode) begin
            A0_abs = A0;
            A1_abs = A1;
            A2_abs = A2;
            A3_abs = A3;
            B0_abs = B0;
            B1_abs = B1;
            B2_abs = B2;
            B3_abs = B3;
        end
        else begin
            A0_abs = A0;
            A1_abs = A1;
            A2_abs = A2;
            A3_abs = A3;
            B0_abs = B0;
            B1_abs = B1;
            B2_abs = B2;
            B3_abs = B3;
        end
    end

    logic [1:0] cycle_counter;
    logic [31:0] prev_data_in_A;
    logic [31:0] prev_data_in_B;
    logic new_transaction;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            cycle_counter <= 2'b00;
            count_0 <= 1'b0;
            prev_data_in_A <= 32'h0;
            prev_data_in_B <= 32'h0;
            new_transaction <= 1'b0;
        end
        else begin
            count_0 <= 1'b0;  
            new_transaction <= 1'b0;
            
            if ((data_in_A != prev_data_in_A) || (data_in_B != prev_data_in_B)) begin
                new_transaction <= 1'b1;
                prev_data_in_A <= data_in_A;
                prev_data_in_B <= data_in_B;
                cycle_counter <= 2'b00;
            end
            else if (sew == 2'b10) begin
                cycle_counter <= cycle_counter + 1'b1;
                if (cycle_counter == 2'b11)
                    cycle_counter <= 2'b00;
            end
            else begin
                cycle_counter <= 2'b00;
            end
            
            if (new_transaction && sew == 2'b10) begin
                count_0 <= 1'b0;  
            end
            else if (sew == 2'b10 && cycle_counter == 2'b00) begin
                count_0 <= 1'b1;  
            end
        end
    end

    assign mult1_A = A0_abs;
    assign mult2_A = A1_abs;
    assign mult3_A = (sew == 2'b01 ) ? A0_abs : A2_abs ;
    assign mult4_A = (sew == 2'b01 ) ? A1_abs : A3_abs ;
    assign mult5_A = (sew == 2'b01 ) ? A2_abs : A0_abs ;
    assign mult6_A = (sew == 2'b01 ) ? A3_abs : A1_abs ;
    assign mult7_A = A2_abs;
    assign mult8_A = A3_abs;

    logic [7:0] mux0_out, mux1_out;
    
    assign mux0_out = count_0 ? B2_abs : B0_abs;
    assign mux1_out = count_0 ? B3_abs : B1_abs;

    assign mult1_B = (sew == 2'b00) ? B0_abs :
                     (sew == 2'b01) ? B0_abs :
                     (sew == 2'b10) ? mux0_out : 8'b0;

    assign mult2_B = (sew == 2'b00) ? B1_abs :
                     (sew == 2'b01) ? B0_abs :
                     (sew == 2'b10) ? mux0_out : 8'b0;
    
    assign mult3_B = (sew == 2'b00) ? B2_abs :
                     (sew == 2'b01) ? B1_abs :
                     (sew == 2'b10) ? mux0_out : 8'b0;

    assign mult4_B = (sew == 2'b00) ? B3_abs :
                     (sew == 2'b01) ? B1_abs :
                     (sew == 2'b10) ? mux0_out : 8'b0;

    assign mult5_B = (sew == 2'b00) ? B0_abs :
                     (sew == 2'b01) ? B2_abs :
                     (sew == 2'b10) ? mux1_out : 8'b0;

    assign mult6_B = (sew == 2'b00) ? B1_abs :
                     (sew == 2'b01) ? B2_abs :
                     (sew == 2'b10) ? mux1_out : 8'b0;
    
    assign mult7_B = (sew == 2'b00) ? B2_abs :
                     (sew == 2'b01) ? B3_abs :
                     (sew == 2'b10) ? mux1_out : 8'b0;

    assign mult8_B = (sew == 2'b00) ? B3_abs :
                     (sew == 2'b01) ? B3_abs :
                     (sew == 2'b10) ? mux1_out : 8'b0;

endmodule


// dadda multiplier
// A - 8 bits , B - 8bits, y(output) - 16bits

module dadda_8(A,B,y);
    
    input [7:0] A;
    input [7:0] B;
    output wire [15:0] y;
    wire  gen_pp [0:7][7:0];
// stage-1 sum and carry
    wire [0:5]s1,c1;
// stage-2 sum and carry
    wire [0:13]s2,c2;   
// stage-3 sum and carry
    wire [0:9]s3,c3;
// stage-4 sum and carry
    wire [0:11]s4,c4;
// stage-5 sum and carry
    wire [0:13]s5,c5;

// generating partial products 
genvar i;
genvar j;

for(i = 0; i<8; i=i+1)begin

   for(j = 0; j<8;j = j+1)begin
      assign gen_pp[i][j] = A[j]*B[i];
end
end

//Reduction by stages.
// di_values = 2,3,4,6,8,13...

//Stage 1 - reducing fom 8 to 6  
    HA h1(.a(gen_pp[6][0]),.b(gen_pp[5][1]),.Sum(s1[0]),.Cout(c1[0]));
    HA h2(.a(gen_pp[4][3]),.b(gen_pp[3][4]),.Sum(s1[2]),.Cout(c1[2]));
    HA h3(.a(gen_pp[4][4]),.b(gen_pp[3][5]),.Sum(s1[4]),.Cout(c1[4]));

    csa_dadda c11(.A(gen_pp[7][0]),.B(gen_pp[6][1]),.Cin(gen_pp[5][2]),.Y(s1[1]),.Cout(c1[1]));
    csa_dadda c12(.A(gen_pp[7][1]),.B(gen_pp[6][2]),.Cin(gen_pp[5][3]),.Y(s1[3]),.Cout(c1[3]));     
    csa_dadda c13(.A(gen_pp[7][2]),.B(gen_pp[6][3]),.Cin(gen_pp[5][4]),.Y(s1[5]),.Cout(c1[5]));
    
//Stage 2 - reducing fom 6 to 4

    HA h4(.a(gen_pp[4][0]),.b(gen_pp[3][1]),.Sum(s2[0]),.Cout(c2[0]));
    HA h5(.a(gen_pp[2][3]),.b(gen_pp[1][4]),.Sum(s2[2]),.Cout(c2[2]));

    csa_dadda c21(.A(gen_pp[5][0]),.B(gen_pp[4][1]),.Cin(gen_pp[3][2]),.Y(s2[1]),.Cout(c2[1]));
    csa_dadda c22(.A(s1[0]),.B(gen_pp[4][2]),.Cin(gen_pp[3][3]),.Y(s2[3]),.Cout(c2[3]));
    csa_dadda c23(.A(gen_pp[2][4]),.B(gen_pp[1][5]),.Cin(gen_pp[0][6]),.Y(s2[4]),.Cout(c2[4]));
    csa_dadda c24(.A(s1[1]),.B(s1[2]),.Cin(c1[0]),.Y(s2[5]),.Cout(c2[5]));
    csa_dadda c25(.A(gen_pp[2][5]),.B(gen_pp[1][6]),.Cin(gen_pp[0][7]),.Y(s2[6]),.Cout(c2[6]));
    csa_dadda c26(.A(s1[3]),.B(s1[4]),.Cin(c1[1]),.Y(s2[7]),.Cout(c2[7]));
    csa_dadda c27(.A(c1[2]),.B(gen_pp[2][6]),.Cin(gen_pp[1][7]),.Y(s2[8]),.Cout(c2[8]));
    csa_dadda c28(.A(s1[5]),.B(c1[3]),.Cin(c1[4]),.Y(s2[9]),.Cout(c2[9]));
    csa_dadda c29(.A(gen_pp[4][5]),.B(gen_pp[3][6]),.Cin(gen_pp[2][7]),.Y(s2[10]),.Cout(c2[10]));
    csa_dadda c210(.A(gen_pp[7][3]),.B(c1[5]),.Cin(gen_pp[6][4]),.Y(s2[11]),.Cout(c2[11]));
    csa_dadda c211(.A(gen_pp[5][5]),.B(gen_pp[4][6]),.Cin(gen_pp[3][7]),.Y(s2[12]),.Cout(c2[12]));
    csa_dadda c212(.A(gen_pp[7][4]),.B(gen_pp[6][5]),.Cin(gen_pp[5][6]),.Y(s2[13]),.Cout(c2[13]));
    
//Stage 3 - reducing fom 4 to 3

    HA h6(.a(gen_pp[3][0]),.b(gen_pp[2][1]),.Sum(s3[0]),.Cout(c3[0]));

    csa_dadda c31(.A(s2[0]),.B(gen_pp[2][2]),.Cin(gen_pp[1][3]),.Y(s3[1]),.Cout(c3[1]));
    csa_dadda c32(.A(s2[1]),.B(s2[2]),.Cin(c2[0]),.Y(s3[2]),.Cout(c3[2]));
    csa_dadda c33(.A(c2[1]),.B(c2[2]),.Cin(s2[3]),.Y(s3[3]),.Cout(c3[3]));
    csa_dadda c34(.A(c2[3]),.B(c2[4]),.Cin(s2[5]),.Y(s3[4]),.Cout(c3[4]));
    csa_dadda c35(.A(c2[5]),.B(c2[6]),.Cin(s2[7]),.Y(s3[5]),.Cout(c3[5]));
    csa_dadda c36(.A(c2[7]),.B(c2[8]),.Cin(s2[9]),.Y(s3[6]),.Cout(c3[6]));
    csa_dadda c37(.A(c2[9]),.B(c2[10]),.Cin(s2[11]),.Y(s3[7]),.Cout(c3[7]));
    csa_dadda c38(.A(c2[11]),.B(c2[12]),.Cin(s2[13]),.Y(s3[8]),.Cout(c3[8]));
    csa_dadda c39(.A(gen_pp[7][5]),.B(gen_pp[6][6]),.Cin(gen_pp[5][7]),.Y(s3[9]),.Cout(c3[9]));

//Stage 4 - reducing fom 3 to 2

    HA h7(.a(gen_pp[2][0]),.b(gen_pp[1][1]),.Sum(s4[0]),.Cout(c4[0]));

    csa_dadda c41(.A(s3[0]),.B(gen_pp[1][2]),.Cin(gen_pp[0][3]),.Y(s4[1]),.Cout(c4[1]));
    csa_dadda c42(.A(c3[0]),.B(s3[1]),.Cin(gen_pp[0][4]),.Y(s4[2]),.Cout(c4[2]));
    csa_dadda c43(.A(c3[1]),.B(s3[2]),.Cin(gen_pp[0][5]),.Y(s4[3]),.Cout(c4[3]));
    csa_dadda c44(.A(c3[2]),.B(s3[3]),.Cin(s2[4]),.Y(s4[4]),.Cout(c4[4]));
    csa_dadda c45(.A(c3[3]),.B(s3[4]),.Cin(s2[6]),.Y(s4[5]),.Cout(c4[5]));
    csa_dadda c46(.A(c3[4]),.B(s3[5]),.Cin(s2[8]),.Y(s4[6]),.Cout(c4[6]));
    csa_dadda c47(.A(c3[5]),.B(s3[6]),.Cin(s2[10]),.Y(s4[7]),.Cout(c4[7]));
    csa_dadda c48(.A(c3[6]),.B(s3[7]),.Cin(s2[12]),.Y(s4[8]),.Cout(c4[8]));
    csa_dadda c49(.A(c3[7]),.B(s3[8]),.Cin(gen_pp[4][7]),.Y(s4[9]),.Cout(c4[9]));
    csa_dadda c410(.A(c3[8]),.B(s3[9]),.Cin(c2[13]),.Y(s4[10]),.Cout(c4[10]));
    csa_dadda c411(.A(c3[9]),.B(gen_pp[7][6]),.Cin(gen_pp[6][7]),.Y(s4[11]),.Cout(c4[11]));
    
//Stage 5 - reducing fom 2 to 1
    // adding total sum and carry to get final output

    HA h8(.a(gen_pp[1][0]),.b(gen_pp[0][1]),.Sum(y[1]),.Cout(c5[0]));

    csa_dadda c51(.A(s4[0]),.B(gen_pp[0][2]),.Cin(c5[0]),.Y(y[2]),.Cout(c5[1]));
    csa_dadda c52(.A(c4[0]),.B(s4[1]),.Cin(c5[1]),.Y(y[3]),.Cout(c5[2]));
    csa_dadda c54(.A(c4[1]),.B(s4[2]),.Cin(c5[2]),.Y(y[4]),.Cout(c5[3]));
    csa_dadda c55(.A(c4[2]),.B(s4[3]),.Cin(c5[3]),.Y(y[5]),.Cout(c5[4]));
    csa_dadda c56(.A(c4[3]),.B(s4[4]),.Cin(c5[4]),.Y(y[6]),.Cout(c5[5]));
    csa_dadda c57(.A(c4[4]),.B(s4[5]),.Cin(c5[5]),.Y(y[7]),.Cout(c5[6]));
    csa_dadda c58(.A(c4[5]),.B(s4[6]),.Cin(c5[6]),.Y(y[8]),.Cout(c5[7]));
    csa_dadda c59(.A(c4[6]),.B(s4[7]),.Cin(c5[7]),.Y(y[9]),.Cout(c5[8]));
    csa_dadda c510(.A(c4[7]),.B(s4[8]),.Cin(c5[8]),.Y(y[10]),.Cout(c5[9]));
    csa_dadda c511(.A(c4[8]),.B(s4[9]),.Cin(c5[9]),.Y(y[11]),.Cout(c5[10]));
    csa_dadda c512(.A(c4[9]),.B(s4[10]),.Cin(c5[10]),.Y(y[12]),.Cout(c5[11]));
    csa_dadda c513(.A(c4[10]),.B(s4[11]),.Cin(c5[11]),.Y(y[13]),.Cout(c5[12]));
    csa_dadda c514(.A(c4[11]),.B(gen_pp[7][7]),.Cin(c5[12]),.Y(y[14]),.Cout(c5[13]));

    assign y[0] =  gen_pp[0][0];
    assign y[15] = c5[13];
    
endmodule 

// Designing in Half Adder 
// Sum = a XOR b, Cout = a AND b


module HA(a, b, Sum, Cout);

input a, b; // a and b are inputs with size 1-bit
output Sum, Cout; // Sum and Cout are outputs with size 1-bit

assign Sum = a ^ b; 
assign Cout = a & b; 

endmodule

//carry save adder -- for implementing dadda multiplier
//csa for use of half adder and full adder.

module csa_dadda(A,B,Cin,Y,Cout);
input A,B,Cin;
output Y,Cout;
    
assign Y = A^B^Cin;
assign Cout = (A&B)|(A&Cin)|(B&Cin);
    
endmodule



module carry_save_8 (
    input  logic               clk,
    input  logic               reset,
    input  logic        [1:0]  sew,         // 0: 16-bit mode (2x16x16), 1: 32-bit mode (1x32x32)
    input  logic               start,
    input  logic signed [15:0] mult_out_1,  // Partial product for multiplier 1 
    input  logic signed [15:0] mult_out_2,  // Partial product for multiplier 2 
    input  logic signed [15:0] mult_out_3,  // Partial product for multiplier 3
    input  logic signed [15:0] mult_out_4,  // Partial product for multiplier 4
    input  logic signed [15:0] mult_out_5,  // Partial product for multiplier 5
    input  logic signed [15:0] mult_out_6,  // Partial product for multiplier 6
    input  logic signed [15:0] mult_out_7,  // Partial product for multiplier 7
    input  logic signed [15:0] mult_out_8,  // Partial product for multiplier 8
    output logic               mult_done,
    output logic signed [31:0] product_1,  // Final result for multiplier 1 (or low 32 bits in 32-bit mode)
    output logic signed [31:0] product_2   // Final result for multiplier 2 (or high 32 bits in 32-bit mode) 
);

// Internal registers
logic   signed [15:0]   sum16_0, sum16_1, sum16_2, sum16_3, sum16_4, sum16_5, sum16_6, sum16_7;  // 18-bit sums (for 16-bit mode)
logic   signed [15:0]   sum16_8, sum16_9, sum16_10, sum16_11, sum16_12, sum16_13;
logic   signed [15:0]   sum32_0, sum32_1, sum32_2, sum32_3, sum32_4, sum32_5, sum32_6, sum32_7; // 17-bit sums (for 32-bit mode)
logic   signed [15:0]   accum_0, accum_1, accum_2, accum_3;
logic   signed [15:0]   next_accum_0, next_accum_1, next_accum_2, next_accum_3 ;
logic   signed [7:0]    PP16_1_1A, PP16_1_1B, PP16_1_2A, PP16_1_2B, PP16_1_3A, PP16_1_3B, PP16_1_4A, PP16_1_4B ;
logic   signed [7:0]    PP16_2_1A, PP16_2_1B, PP16_2_2A, PP16_2_2B, PP16_2_3A, PP16_2_3B, PP16_2_4A, PP16_2_4B ;
logic   signed [7:0]    PP32_1A,  PP32_1B, PP32_2A, PP32_2B, PP32_3A, PP32_3B, PP32_4A, PP32_4B, 
                        PP32_5A,  PP32_5B, PP32_6A, PP32_6B, PP32_7A, PP32_7B, PP32_8A, PP32_8B;
logic   signed [7:0]    PP32_9A,  PP32_9B, PP32_10A, PP32_10B, PP32_11A, PP32_11B, PP32_12A, PP32_12B, 
                        PP32_13A,  PP32_13B, PP32_14A, PP32_14B, PP32_15A, PP32_15B, PP32_16A, PP32_16B; 
logic   signed [8:0]    carry_0, carry_1, carry_2, carry_3, carry_4;
logic   signed [16:0]   sum_accum_0, sum_accum_1, sum_accum_2, sum_accum_3;
logic   signed [9:0]    result_0, result_1, result_2, result_3;
logic   signed [9:0]    result_4, result_5, result_6, result_7;
logic   signed          accum_carry_0, accum_carry_1, accum_carry_2, accum_carry_3;

// Combined state definitions
typedef enum logic [2:0] {
    IDLE,
    PP_8,
    // 16-bit mode states
    PP_16, 
    // 32-bit mode states
    PP1_32, PP2_32,
    DONE    
} state_t;

state_t state, next_state;

// 3:2 CSA function - 8-bit inputs, 16-bit output {sum, carry}
function automatic [15:0] csa_3to2(input [7:0] a, b, c);
    reg [7:0] sum, carry;
    begin
        sum   = a ^ b ^ c;
        carry = (a & b) | (b & c) | (a & c);
        csa_3to2 = {carry, sum};
    end
endfunction

// Add sum + carry function - returns 9-bit result (1 extra bit for overflow)
function automatic [9:0] add_sum_carry(input [7:0] sum, carry);

    begin
        add_sum_carry = sum + {carry[7:0], 1'b0};  // carry left shift by 1
    end
endfunction

function automatic [8:0] add_carry_8bit(
    input logic [7:0] value,
    input logic [1:0] carry_in1, carry_in2, carry_in3
);
    logic [8:0] carry_out;
    begin
        carry_out = value + carry_in1 + carry_in2 + carry_in3;  // add carry to 8-bit value
        return carry_out;  // result[8] = carry_out, result[7:0] = sum
    end
endfunction

// Combinational logic for next state and outputs
always_comb begin
    // Default assignments
    next_accum_0 = accum_0;
    next_accum_1 = accum_1;
    next_accum_2 = accum_2;
    next_accum_3 = accum_3;

    sum16_0 = '0;           sum16_8 = '0;           sum32_0 = '0;                
    sum16_1 = '0;           sum16_9 = '0;           sum32_1 = '0;        
    sum16_2 = '0;           sum16_10 = '0;          sum32_2 = '0;       
    sum16_3 = '0;           sum16_11 = '0;          sum32_3 = '0;     
    sum16_4 = '0;           sum16_12 = '0;          sum32_4 = '0;      
    sum16_5 = '0;           sum16_13 = '0;          sum32_5 = '0;    
    sum16_6 = '0;                                   sum32_6 = '0;    
    sum16_7 = '0;                                   sum32_7 = '0;       

    PP16_1_1A  = '0;        PP16_2_1A  = '0;        PP16_1_1B  = '0;        PP16_2_1B  = '0;
    PP16_1_2A  = '0;        PP16_2_2A  = '0;        PP16_1_2B  = '0;        PP16_2_2B  = '0;
    PP16_1_3A  = '0;        PP16_2_3A  = '0;        PP16_1_3B  = '0;        PP16_2_3B  = '0;
    PP16_1_4A  = '0;        PP16_2_4A  = '0;        PP16_1_4B  = '0;        PP16_2_4B  = '0;

    PP32_1A   = '0;          PP32_1B   = '0;        PP32_2A   = '0;          PP32_2B   = '0;
    PP32_3A   = '0;          PP32_3B   = '0;        PP32_4A   = '0;          PP32_4B   = '0;
    PP32_5A   = '0;          PP32_5B   = '0;        PP32_6A   = '0;          PP32_6B   = '0;
    PP32_7A   = '0;          PP32_7B   = '0;        PP32_8A   = '0;          PP32_8B   = '0;
    PP32_9A   = '0;          PP32_9B   = '0;        PP32_10A  = '0;          PP32_10B  = '0;
    PP32_11A  = '0;          PP32_11B  = '0;        PP32_12A  = '0;          PP32_12B  = '0;
    PP32_13A  = '0;          PP32_13B  = '0;        PP32_14A  = '0;          PP32_14B  = '0;
    PP32_15A  = '0;          PP32_15B  = '0;        PP32_16A  = '0;          PP32_16B  = '0;

    carry_0 = '0;           carry_1 = '0;           carry_2 = '0;           carry_3 = '0;       carry_4 = '0;
    sum_accum_0 = '0;       sum_accum_1 = '0;       sum_accum_2 = '0;       sum_accum_3 = '0;
    result_0 = '0;          result_1 = '0;          result_2 = '0;          result_3 = '0;
    result_4 = '0;          result_5 = '0;          result_6 = '0;          result_7 = '0;
    accum_carry_0 = '0;     accum_carry_1 = '0;     accum_carry_2 = '0;     accum_carry_3 = '0;
    mult_done = 0;

    case (state)
        IDLE: begin
            if (start) begin
                next_accum_0 = 0;
                next_accum_1 = 0;
                next_accum_2 = 0;
                next_accum_3 = 0;
                next_state =    (sew == 2'b00) ? PP_8 :
                                (sew == 2'b01) ? PP_16:
                                (sew == 2'b10) ? PP1_32: IDLE;    
            end
            else begin
                next_accum_0 = 0;
                next_accum_1 = 0;
                next_accum_2 = 0;
                next_accum_3 = 0;
                next_state = IDLE;
                
            end
        end

        PP_8: begin
            next_accum_0 =  mult_out_1;
            next_accum_1 =  mult_out_2;
            next_accum_2 =  mult_out_3;
            next_accum_3 =  mult_out_4; 
            mult_done = 0;
            next_state = DONE;   
        end

        PP_16: begin   

            PP16_1_1A = mult_out_1[7:0];        PP16_1_1B = mult_out_1[15:8];
            PP16_1_2A = mult_out_2[7:0];        PP16_1_2B = mult_out_2[15:8];
            PP16_1_3A = mult_out_3[7:0];        PP16_1_3B = mult_out_3[15:8];
            PP16_1_4A = mult_out_4[7:0];        PP16_1_4B = mult_out_4[15:8];

            PP16_2_1A = mult_out_5[7:0];        PP16_2_1B = mult_out_5[15:8];
            PP16_2_2A = mult_out_6[7:0];        PP16_2_2B = mult_out_6[15:8];
            PP16_2_3A = mult_out_7[7:0];        PP16_2_3B = mult_out_7[15:8];
            PP16_2_4A = mult_out_8[7:0];        PP16_2_4B = mult_out_8[15:8];

            // CSA operations (output is 16-bit: {sum, carry})
            sum16_0 = {8'b0, PP16_1_1A};  // No CSA, so carry = 0
            sum16_1 = csa_3to2(PP16_1_1B, PP16_1_2A, PP16_1_3A);
            sum16_2 = csa_3to2(PP16_1_2B, PP16_1_3B, PP16_1_4A);
            sum16_3 = {8'b0, PP16_1_4B};  // No CSA, so carry = 0

            sum16_4 = {8'b0, PP16_2_1A};  // No CSA, so carry = 0
            sum16_5 = csa_3to2(PP16_2_1B, PP16_2_2A, PP16_2_3A);
            sum16_6 = csa_3to2(PP16_2_2B, PP16_2_3B, PP16_2_4A);
            sum16_7 = {8'b0, PP16_2_4B};  // No CSA, so carry = 0

            // Add sum + carry (9-bit results for overflow handling)
            result_0 = add_sum_carry(sum16_0[7:0],  sum16_0[15:8]);
            result_1 = add_sum_carry(sum16_1[7:0],  sum16_1[15:8]);
            result_2 = add_sum_carry(sum16_2[7:0],  sum16_2[15:8]);
            result_3 = add_sum_carry(sum16_3[7:0],  sum16_3[15:8]);

            result_4 = add_sum_carry(sum16_4[7:0],  sum16_4[15:8]);
            result_5 = add_sum_carry(sum16_5[7:0],  sum16_5[15:8]);
            result_6 = add_sum_carry(sum16_6[7:0],  sum16_6[15:8]);
            result_7 = add_sum_carry(sum16_7[7:0],  sum16_7[15:8]);

            sum16_8 = add_carry_8bit(result_1[7:0], result_0[9:8], 1'b0, 1'b0);
            sum16_9 = add_carry_8bit(result_2[7:0], result_1[9:8], sum16_8[8], 1'b0);
            sum16_10 = add_carry_8bit(result_3[7:0],result_2[9:8], sum16_9[8], 1'b0);

            sum16_11 = add_carry_8bit(result_5[7:0], result_4[9:8], 1'b0, 1'b0);
            sum16_12 = add_carry_8bit(result_6[7:0], result_5[9:8], sum16_11[8], 1'b0);
            sum16_13 = add_carry_8bit(result_7[7:0], result_6[9:8], sum16_12[8], 1'b0);
 
            next_accum_0 =  {sum16_8[7:0], result_0[7:0]};
            next_accum_1 =  {sum16_10[7:0], sum16_9[7:0]};
            next_accum_2 =  {sum16_11[7:0], result_4[7:0]};
            next_accum_3 =  {sum16_13[7:0], sum16_12[7:0]};
            mult_done = 0;
                      
            next_state = DONE ;            
        end

        PP1_32: begin 

            PP32_1A = mult_out_1[7:0];      PP32_1B = mult_out_1[15:8];
            PP32_2A = mult_out_2[7:0];      PP32_2B = mult_out_2[15:8];
            PP32_3A = mult_out_3[7:0];      PP32_3B = mult_out_3[15:8];
            PP32_4A = mult_out_4[7:0];      PP32_4B = mult_out_4[15:8];
            PP32_5A = mult_out_5[7:0];      PP32_5B = mult_out_5[15:8];
            PP32_6A = mult_out_6[7:0];      PP32_6B = mult_out_6[15:8];
            PP32_7A = mult_out_7[7:0];      PP32_7B = mult_out_7[15:8];
            PP32_8A = mult_out_8[7:0];      PP32_8B = mult_out_8[15:8];
                      
            sum32_0 = {8'b0, PP32_1A};
            sum32_1 = csa_3to2(PP32_1B , PP32_2A , PP32_5A);
            sum32_2 = csa_3to2(PP32_2B , PP32_3A , PP32_5B);
            sum32_3 = csa_3to2(PP32_3B , PP32_4A , PP32_6B);
            sum32_4 = csa_3to2(PP32_4B , PP32_7B , PP32_8A);
            sum32_5 = {8'b0, PP32_8B};
            
            // Add sum + carry (9-bit results for overflow handling)
            result_0 = add_sum_carry(sum32_0[7:0],  sum32_0[15:8]);
            result_1 = add_sum_carry(sum32_1[7:0],  sum32_1[15:8]);
            result_2 = add_sum_carry(sum32_2[7:0],  sum32_2[15:8]);
            result_3 = add_sum_carry(sum32_3[7:0],  sum32_3[15:8]);
            result_4 = add_sum_carry(sum32_4[7:0],  sum32_4[15:8]);
            result_5 = add_sum_carry(sum32_5[7:0],  sum32_5[15:8]);

            sum32_6 = csa_3to2(result_2[7:0], PP32_6A, 8'b0);
            sum32_7 = csa_3to2(result_3[7:0], PP32_7A, 8'b0);

            result_6 = add_sum_carry(sum32_6[7:0], sum32_6[15:8]);
            result_7 = add_sum_carry(sum32_7[7:0], sum32_7[15:8]);

            carry_0 = add_carry_8bit(result_1[7:0], result_0[9:8], 2'b0, 2'b0);
            carry_1 = add_carry_8bit(result_6[7:0], result_1[9:8], carry_0[8], 2'b0);
            carry_2 = add_carry_8bit(result_7[7:0], result_6[9:8], result_2[9:8], carry_1[8]);
            carry_3 = add_carry_8bit(result_4[7:0], result_7[9:8], carry_2[8], result_3[9:8]);
            carry_4 = add_carry_8bit(result_5[7:0], result_4[9:8], carry_3[8], 2'b0);

            next_accum_0 =  {carry_0[7:0], result_0[7:0]};
            next_accum_1 =  {carry_2[7:0], carry_1[7:0]};
            next_accum_2 =  {carry_4[7:0], carry_3[7:0]};
            next_accum_3 =  {15'b0        ,carry_4[8]};
            mult_done = 0;

            next_state = PP2_32;

        end 

        PP2_32: begin

            PP32_9A = mult_out_1[7:0];       PP32_9B = mult_out_1[15:8];
            PP32_10A = mult_out_2[7:0];      PP32_10B = mult_out_2[15:8];
            PP32_11A = mult_out_3[7:0];      PP32_11B = mult_out_3[15:8];
            PP32_12A = mult_out_4[7:0];      PP32_12B = mult_out_4[15:8];
            PP32_13A = mult_out_5[7:0];      PP32_13B = mult_out_5[15:8];
            PP32_14A = mult_out_6[7:0];      PP32_14B = mult_out_6[15:8];
            PP32_15A = mult_out_7[7:0];      PP32_15B = mult_out_7[15:8];
            PP32_16A = mult_out_8[7:0];      PP32_16B = mult_out_8[15:8];

            sum32_0 = {8'b0, PP32_9A};
            sum32_1 = csa_3to2(PP32_9B , PP32_10A , PP32_13A);
            sum32_2 = csa_3to2(PP32_10B , PP32_11A , PP32_13B);
            sum32_3 = csa_3to2(PP32_11B , PP32_12A , PP32_14B);
            sum32_4 = csa_3to2(PP32_12B , PP32_15B , PP32_16A);
            sum32_5 = {8'b0, PP32_16B};

            result_0 = add_sum_carry(sum32_0[7:0],  sum32_0[15:8]);
            result_1 = add_sum_carry(sum32_1[7:0],  sum32_1[15:8]);
            result_2 = add_sum_carry(sum32_2[7:0],  sum32_2[15:8]);
            result_3 = add_sum_carry(sum32_3[7:0],  sum32_3[15:8]);
            result_4 = add_sum_carry(sum32_4[7:0],  sum32_4[15:8]);
            result_5 = add_sum_carry(sum32_5[7:0],  sum32_5[15:8]);

            sum32_6 = csa_3to2(result_2[7:0], PP32_14A, 8'b0);
            sum32_7 = csa_3to2(result_3[7:0], PP32_15A, 8'b0);

            result_6 = add_sum_carry(sum32_6[7:0], sum32_6[15:8]);
            result_7 = add_sum_carry(sum32_7[7:0], sum32_7[15:8]);

            carry_0 = add_carry_8bit(result_1[7:0], result_0[9:8], 2'b0, 2'b0);
            carry_1 = add_carry_8bit(result_6[7:0], result_1[9:8], carry_0[8], 2'b0);
            carry_2 = add_carry_8bit(result_7[7:0], result_6[9:8], result_2[9:8], carry_1[8]);
            carry_3 = add_carry_8bit(result_4[7:0], result_7[9:8], carry_2[8], result_3[9:8]);
            carry_4 = add_carry_8bit(result_5[7:0], result_4[9:8], carry_3[8], 2'b0);

            sum_accum_0 = accum_0[15:0] + accum_carry_0; 
            sum_accum_1 = accum_1[15:0] + result_0[7:0] + {carry_0[7:0], 8'b0} + accum_carry_1 + sum_accum_0[16];
            sum_accum_2 = accum_2[15:0] + carry_1[7:0]  + {carry_2[7:0], 8'b0} + accum_carry_2 + sum_accum_1[16];
            sum_accum_3 = accum_3[15:0] + carry_3[7:0]  + {carry_4[7:0], 8'b0} + accum_carry_3 + sum_accum_2[16];

            next_accum_0 = sum_accum_0[15:0];
            next_accum_1 = sum_accum_1[15:0];
            next_accum_2 = sum_accum_2[15:0];
            next_accum_3 = sum_accum_3[15:0];
            mult_done = 0;

            next_state = DONE ;

        end 
        DONE: begin
            mult_done = 1;
            next_state = IDLE;
        
        end
    endcase
end
    always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
        accum_0 <= 0;
        accum_1 <= 0;
        accum_2 <= 0;
        accum_3 <= 0;
        state   <= IDLE;
    end else begin
        accum_0 <= next_accum_0;
        accum_1 <= next_accum_1;
        accum_2 <= next_accum_2;
        accum_3 <= next_accum_3;
        state   <= next_state;
    end
end

// Final product outputs
assign product_1 =  {accum_1, accum_0} ;
assign product_2 =  {accum_3, accum_2} ;

endmodule


module top_8(
    input  logic                clk,
    input  logic                reset,
    input  logic        [1:0]   sew,
    input  logic                start,
    input  logic                signed_mode,
    input  logic signed [31:0]  data_in_A,
    input  logic signed [31:0]  data_in_B,

    output logic                count_0, 
    output logic                mult_done,    
    output logic signed [63:0]  product
);

    // Multiplier inputs
    logic signed [7:0] mult1_A, mult2_A, mult3_A, mult4_A;
    logic signed [7:0] mult5_A, mult6_A, mult7_A, mult8_A;
    logic signed [7:0] mult1_B, mult2_B, mult3_B, mult4_B;
    logic signed [7:0] mult5_B, mult6_B, mult7_B, mult8_B;

    // Raw Dadda outputs
    logic signed [15:0] mult_out_1, mult_out_2, mult_out_3, mult_out_4;
    logic signed [15:0] mult_out_5, mult_out_6, mult_out_7, mult_out_8;

    //  1-cycle delayed (stalled) outputs
    logic signed [15:0] mult_out_1_delayed, mult_out_2_delayed, mult_out_3_delayed, mult_out_4_delayed;
    logic signed [15:0] mult_out_5_delayed, mult_out_6_delayed, mult_out_7_delayed, mult_out_8_delayed;

    logic                sign_A0, sign_A1, sign_A2, sign_A3;
    logic                sign_B0, sign_B1, sign_B2, sign_B3;
    logic signed [31:0]  product_1;
    logic signed [31:0]  product_2;

    logic signed [31:0] product_16sew_1, product_16sew_2;
    logic signed [15:0] product_8sew_1, product_8sew_2, product_8sew_3, product_8sew_4;
    logic signed [63:0] product_32sew;

    // ──────────────────────────────────────────────
    // Stage 1: Multiplier input preparation
    // ──────────────────────────────────────────────
    multiplier_8 mult (
        .clk(clk),
        .reset(reset),
        .data_in_A(data_in_A),
        .data_in_B(data_in_B),
        .sew(sew),
        .signed_mode(signed_mode),
        
        .count_0(count_0),
        .mult1_A(mult1_A),
        .mult2_A(mult2_A), 
        .mult3_A(mult3_A), 
        .mult4_A(mult4_A),
        .mult5_A(mult5_A), 
        .mult6_A(mult6_A), 
        .mult7_A(mult7_A), 
        .mult8_A(mult8_A),
        .mult1_B(mult1_B), 
        .mult2_B(mult2_B), 
        .mult3_B(mult3_B), 
        .mult4_B(mult4_B),
        .mult5_B(mult5_B), 
        .mult6_B(mult6_B), 
        .mult7_B(mult7_B), 
        .mult8_B(mult8_B),

        .sign_A0(sign_A0),
        .sign_A1(sign_A1),
        .sign_A2(sign_A2),
        .sign_A3(sign_A3),
        .sign_B0(sign_B0),
        .sign_B1(sign_B1),
        .sign_B2(sign_B2),
        .sign_B3(sign_B3)
    );

     // ──────────────────────────────────────────────
    // Stage 2: Dadda Multipliers (8 of them)
    // ──────────────────────────────────────────────
    dadda_8 dadda_1 (.A(mult1_A), .B(mult1_B), .y(mult_out_1));
    dadda_8 dadda_2 (.A(mult2_A), .B(mult2_B), .y(mult_out_2));
    dadda_8 dadda_3 (.A(mult3_A), .B(mult3_B), .y(mult_out_3));
    dadda_8 dadda_4 (.A(mult4_A), .B(mult4_B), .y(mult_out_4));
    dadda_8 dadda_5 (.A(mult5_A), .B(mult5_B), .y(mult_out_5));
    dadda_8 dadda_6 (.A(mult6_A), .B(mult6_B), .y(mult_out_6));
    dadda_8 dadda_7 (.A(mult7_A), .B(mult7_B), .y(mult_out_7));
    dadda_8 dadda_8 (.A(mult8_A), .B(mult8_B), .y(mult_out_8));
    
    // ──────────────────────────────────────────────
    //  Stage 3: 1-cycle delay (stall registers)
    // ──────────────────────────────────────────────
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            mult_out_1_delayed <= 0;
            mult_out_2_delayed <= 0;
            mult_out_3_delayed <= 0;
            mult_out_4_delayed <= 0;
            mult_out_5_delayed <= 0;
            mult_out_6_delayed <= 0;
            mult_out_7_delayed <= 0;
            mult_out_8_delayed <= 0;
        end else begin
            mult_out_1_delayed <= mult_out_1;
            mult_out_2_delayed <= mult_out_2;
            mult_out_3_delayed <= mult_out_3;
            mult_out_4_delayed <= mult_out_4;
            mult_out_5_delayed <= mult_out_5;
            mult_out_6_delayed <= mult_out_6;
            mult_out_7_delayed <= mult_out_7;
            mult_out_8_delayed <= mult_out_8;
        end
    end

    // ──────────────────────────────────────────────
    // Stage 4: Carry-Save Accumulator (gets delayed data)
    // ──────────────────────────────────────────────
    carry_save_8 cs (
        .clk(clk),
        .reset(reset),
        .sew(sew),
        .start(start),
        .mult_out_1(mult_out_1_delayed),
        .mult_out_2(mult_out_2_delayed),
        .mult_out_3(mult_out_3_delayed),
        .mult_out_4(mult_out_4_delayed),
        .mult_out_5(mult_out_5_delayed),
        .mult_out_6(mult_out_6_delayed),
        .mult_out_7(mult_out_7_delayed),
        .mult_out_8(mult_out_8_delayed),
        .mult_done(mult_done),
        .product_1(product_1),
        .product_2(product_2)
    );


// Compute absolute values based on SEW
always_comb begin
        product_8sew_1  = 16'h0;
        product_8sew_2  = 16'h0;
        product_8sew_3  = 16'h0;
        product_8sew_4  = 16'h0;
        product_16sew_1 = 32'h0;
        product_16sew_2 = 32'h0;
        product_32sew   = 64'h0;
        product         = 64'h0;
    case (sew)
        2'b00: begin // 8-bit: individual two's complement
            if (signed_mode) begin
                product_8sew_1 = (sign_A0 ^ sign_B0) ? (~product_1[15:0] + 8'd1) : product_1[15:0];
                product_8sew_2 = (sign_A1 ^ sign_B1) ? (~product_1[31:16] + 8'd1) : product_1[31:16];
                product_8sew_3 = (sign_A2 ^ sign_B2) ? (~product_2[15:0] + 8'd1) : product_2[15:0];
                product_8sew_4 = (sign_A3 ^ sign_B3) ? (~product_2[31:16] + 8'd1) : product_2[31:16];
                product        = {product_8sew_4, product_8sew_3, product_8sew_2, product_8sew_1};
                product_16sew_1 = 32'h0;
                product_16sew_2 = 32'h0;
                product_32sew = 64'h0;
            end
            else begin 
                product = {product_2,product_1};
                product_8sew_1 = 16'h0;
                product_8sew_2 = 16'h0;
                product_8sew_3 = 16'h0;
                product_8sew_4 = 16'h0;
                product_16sew_1 = 32'h0;
                product_16sew_2 = 32'h0;
                product_32sew = 64'h0;
            end

            end
        2'b01: begin // 16-bit: two's complement on 16-bit pairs
            if (signed_mode) begin
                product_16sew_1 = (sign_A1 ^ sign_B1) ? (~product_1 + 8'd1) : product_1;
                product_16sew_2 = (sign_A3 ^ sign_B3) ? (~product_2 + 8'd1) : product_2;
                product = {product_16sew_2, product_16sew_1};
                product_8sew_1 = 16'h0;
                product_8sew_2 = 16'h0;
                product_8sew_3 = 16'h0;
                product_8sew_4 = 16'h0;
                product_32sew = 64'h0;
            end
            else begin 
                product = {product_2,product_1};
                product_8sew_1  = 16'h0;
                product_8sew_2  = 16'h0;
                product_8sew_3  = 16'h0;
                product_8sew_4  = 16'h0;
                product_16sew_1 = 32'h0;
                product_16sew_2 = 32'h0;
                product_32sew   = 64'h0;
            end
               
            end
        2'b10: begin // 32-bit: two's complement on full 32-bit
            if (signed_mode) begin    
                product_32sew = (sign_A3 ^ sign_B3) ? (~{product_2 , product_1} + 8'd1) : {product_2, product_1};
                product = product_32sew;
                product_8sew_1 = 16'h0;
                product_8sew_2 = 16'h0;
                product_8sew_3 = 16'h0;
                product_8sew_4 = 16'h0;
                product_16sew_1 = 32'h0;
                product_16sew_2 = 32'h0;
            end
            else begin 
                product = {product_2,product_1};
                product_8sew_1  = 16'h0;
                product_8sew_2  = 16'h0;
                product_8sew_3  = 16'h0;
                product_8sew_4  = 16'h0;
                product_16sew_1 = 32'h0;
                product_16sew_2 = 32'h0;
                product_32sew   = 64'h0;
            end

            end
       default: begin
            product_8sew_1  = 16'h0;
            product_8sew_2  = 16'h0;
            product_8sew_3  = 16'h0;
            product_8sew_4  = 16'h0;
            product_16sew_1 = 32'h0;
            product_16sew_2 = 32'h0;
            product_32sew   = 64'h0;
            product = 64'h0;

            end
        endcase
    end

endmodule

// Top-level wrapper for 512-bit inputs
module vector_multiplier(
    input  logic                clk,
    input  logic                reset,start,
    input  logic        [1:0]   sew,           // 00=8-bit, 01=16-bit, 10=32-bit
    input  logic signed [`MAX_VLEN-1:0] data_in_A,     // 512-bit input A
    input  logic signed [`MAX_VLEN-1:0] data_in_B,     // 512-bit input B
    input  logic                signed_mode,
    output logic                count_0,
    output logic                mult_done,
    output logic signed [`MAX_VLEN*2+1:0] product       // 1024-bit result
);

    // Number of 32-bit processing elements
    localparam NUM_PES = 16;  // 512 / 32 = 16 PEs
    
    // Per-PE signals
    logic [NUM_PES-1:0] pe_count_0;
    logic [NUM_PES-1:0] pe_mult_done;           //  Separate done signal per PE
    logic signed [63:0] pe_product [NUM_PES-1:0];
    
    // Generate 16 processing elements
    genvar i;
    generate
        for (i = 0; i < NUM_PES; i++) begin : gen_processing_elements
            // Extract 32-bit slices for each PE
            localparam BASE = i * 32;
            
            top u_top_pe (
                .clk(clk),
                .reset(reset),
                .sew(sew),
                .mult_done(pe_mult_done[i]),        //  Individual done signal
                .signed_mode(signed_mode),
                .data_in_A(data_in_A[BASE +: 32]),  // Extract 32 bits
                .data_in_B(data_in_B[BASE +: 32]),
                .count_0(pe_count_0[i]),
                .product(pe_product[i])
            );
        end
    endgenerate
    
    //  Combine all mult_done signals (AND operation - all must be done)
    assign mult_done = &pe_mult_done;
    
    //  Combine all count_0 signals
    assign count_0 = &pe_count_0;
    
    //  Aggregate final product based on SEW
    always_comb begin
        case (sew)
            2'b00: begin  // 8-bit elements (64 elements)
                for (int j = 0; j < NUM_PES; j++) begin
                    product[j*64 +: 64] = pe_product[j];
                end
            end
            
            2'b01: begin  // 16-bit elements (32 elements)
                for (int j = 0; j < NUM_PES; j++) begin
                    product[j*64 +: 64] = pe_product[j];
                end
            end
            
            2'b10: begin  // 32-bit elements (16 elements)
                for (int j = 0; j < NUM_PES; j++) begin
                    product[j*64 +: 64] = pe_product[j];
                end
            end
            
            default: begin
                for (int j = 0; j < NUM_PES; j++) begin
                    product[j*64 +: 64] = pe_product[j];
                end
            end
        endcase
    end

endmodule
