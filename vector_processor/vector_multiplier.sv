`include "vector_processor_defs.svh"

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
    
    // Intermediate signals for two's complement
    logic [15:0] A_low_16, A_high_16, B_low_16, B_high_16;
    logic [31:0] A_32, B_32;
    logic [15:0] A_low_16_comp, A_high_16_comp;
    logic [15:0] B_low_16_comp, B_high_16_comp;
    logic [31:0] A_32_comp, B_32_comp;
    
    // Extract 8-bit chunks
    assign A0 = data_in_A[7:0];
    assign A1 = data_in_A[15:8];
    assign A2 = data_in_A[23:16];
    assign A3 = data_in_A[31:24];
    assign B0 = data_in_B[7:0]; 
    assign B1 = data_in_B[15:8];
    assign B2 = data_in_B[23:16];
    assign B3 = data_in_B[31:24];

    // Group elements based on SEW for two's complement
    assign A_low_16 = {A1, A0};
    assign A_high_16 = {A3, A2};
    assign B_low_16 = {B1, B0};
    assign B_high_16 = {B3, B2};
    assign A_32 = data_in_A;
    assign B_32 = data_in_B;
    
    // Two's complement for 16-bit and 32-bit
    assign A_low_16_comp = ~A_low_16 + 16'd1;
    assign A_high_16_comp = ~A_high_16 + 16'd1;
    assign B_low_16_comp = ~B_low_16 + 16'd1;
    assign B_high_16_comp = ~B_high_16 + 16'd1;
    assign A_32_comp = ~A_32 + 32'd1;
    assign B_32_comp = ~B_32 + 32'd1;

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
                    {A1_abs, A0_abs} = sign_A0 ? A_low_16_comp : A_low_16;
                    {A3_abs, A2_abs} = sign_A2 ? A_high_16_comp : A_high_16;
                
                    {B1_abs, B0_abs} = sign_B0 ? B_low_16_comp : B_low_16;
                    {B3_abs, B2_abs} = sign_B2 ? B_high_16_comp : B_high_16;
                end
                2'b10: begin // 32-bit: two's complement on full 32-bit
                    {A3_abs, A2_abs, A1_abs, A0_abs} = sign_A0 ? A_32_comp : A_32;
                    {B3_abs, B2_abs, B1_abs, B0_abs} = sign_B0 ? B_32_comp : B_32;
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

    // Count logic for 32-bit mode
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            sew_was_2 <= 1'b0;
            count_0 <= 1'b0;
        end else if (sew == 2'b10) begin
            sew_was_2 <= 1'b1;
            count_0 <= sew_was_2;
        end else begin
            sew_was_2 <= 1'b0;
            count_0 <= 1'b0;
        end
    end

    // Multiplier A inputs (using absolute values)
    assign mult1_A = A0_abs;
    assign mult2_A = A1_abs;
    assign mult3_A = A2_abs;
    assign mult4_A = A3_abs;
    assign mult5_A = A0_abs;
    assign mult6_A = A1_abs;
    assign mult7_A = A2_abs;
    assign mult8_A = A3_abs;

    logic [7:0] mux0_out, mux1_out;
    
    assign mux0_out = count_0 ? B2_abs : B0_abs;
    assign mux1_out = count_0 ? B3_abs : B1_abs;

    // Multiplier B inputs (using absolute values)
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


`default_nettype none

module wallaceTreeMultiplier8Bit (result, a, b);
    output logic [15:0] result;
    input logic [7:0] a;
    input logic [7:0] b;

    logic [7:0] wallaceTree[7:0];
    integer i, j;

    always_comb begin
        for(i = 0;i < 8;i = i+1)
            for(j = 0;j < 8;j = j+1)
                wallaceTree[i][j] = a[i] & b[j];
    end
    
    // result[0]
    assign result[0] = wallaceTree[0][0];

    // result[1]
    logic result1_c;
    
    HA result1_HA_1(result1_c, result[1], wallaceTree[0][1], wallaceTree[1][0]);

    // result[2]
    logic result2_c_temp_1, result2_c, result2_temp_1;
    FA result2_FA_1(result2_c_temp_1, result2_temp_1, wallaceTree[0][2], wallaceTree[1][1], result1_c);
    HA result2_HA_1(result2_c, result[2], wallaceTree[2][0], result2_temp_1);

    // result[3]
    logic result3_c_temp_1, result3_c_temp_2, result3_c, result3_temp_1, result3_temp_2;
    FA result3_FA_1(result3_c_temp_1, result3_temp_1, wallaceTree[0][3], wallaceTree[1][2], result2_c);
    FA result3_FA_2(result3_c_temp_2, result3_temp_2, wallaceTree[2][1], result3_temp_1, result2_c_temp_1);
    HA result3_HA_1(result3_c, result[3], wallaceTree[3][0], result3_temp_2);

    // result[4]
    logic result4_c_temp_1, result4_c_temp_2, result4_c_temp_3, result4_c, result4_temp_1, result4_temp_2, result4_temp_3;
    FA result4_FA_1(result4_c_temp_1, result4_temp_1, wallaceTree[0][4], wallaceTree[1][3], result3_c);
    FA result4_FA_2(result4_c_temp_2, result4_temp_2, wallaceTree[2][2], result4_temp_1, result3_c_temp_1);
    FA result4_FA_3(result4_c_temp_3, result4_temp_3, wallaceTree[3][1], result4_temp_2, result3_c_temp_2);
    HA result4_HA_1(result4_c, result[4], wallaceTree[4][0], result4_temp_3);

    // result[5]
    logic result5_c_temp_1, result5_c_temp_2, result5_c_temp_3, result5_c_temp_4, result5_c, result5_temp_1, result5_temp_2, result5_temp_3, result5_temp_4;
    FA result5_FA_1(result5_c_temp_1, result5_temp_1, wallaceTree[0][5], wallaceTree[1][4], result4_c);
    FA result5_FA_2(result5_c_temp_2, result5_temp_2, wallaceTree[2][3], result5_temp_1, result4_c_temp_1);
    FA result5_FA_3(result5_c_temp_3, result5_temp_3, wallaceTree[3][2], result5_temp_2, result4_c_temp_2);
    FA result5_FA_4(result5_c_temp_4, result5_temp_4, wallaceTree[4][1], result5_temp_3, result4_c_temp_3);
    HA result5_HA_1(result5_c, result[5], wallaceTree[5][0], result5_temp_4);

    // result[6]
    logic result6_c_temp_1, result6_c_temp_2, result6_c_temp_3, result6_c_temp_4, result6_c_temp_5, result6_c, result6_temp_1, result6_temp_2, result6_temp_3, result6_temp_4, result6_temp_5;
    FA result6_FA_1(result6_c_temp_1, result6_temp_1, wallaceTree[0][6], wallaceTree[1][5], result5_c);
    FA result6_FA_2(result6_c_temp_2, result6_temp_2, wallaceTree[2][4], result6_temp_1, result5_c_temp_1);
    FA result6_FA_3(result6_c_temp_3, result6_temp_3, wallaceTree[3][3], result6_temp_2, result5_c_temp_2);
    FA result6_FA_4(result6_c_temp_4, result6_temp_4, wallaceTree[4][2], result6_temp_3, result5_c_temp_3);
    FA result6_FA_5(result6_c_temp_5, result6_temp_5, wallaceTree[5][1], result6_temp_4, result5_c_temp_4);
    HA result6_HA_1(result6_c, result[6], wallaceTree[6][0], result6_temp_5);

    // result[7]
    logic result7_c_temp_1, result7_c_temp_2, result7_c_temp_3, result7_c_temp_4, result7_c_temp_5, result7_c_temp_6, result7_c, result7_temp_1, result7_temp_2, result7_temp_3, result7_temp_4, result7_temp_5, result7_temp_6;
    FA result7_FA_1(result7_c_temp_1, result7_temp_1, wallaceTree[0][7], wallaceTree[1][6], result6_c);
    FA result7_FA_2(result7_c_temp_2, result7_temp_2, wallaceTree[2][5], result7_temp_1, result6_c_temp_1);
    FA result7_FA_3(result7_c_temp_3, result7_temp_3, wallaceTree[3][4], result7_temp_2, result6_c_temp_2);
    FA result7_FA_4(result7_c_temp_4, result7_temp_4, wallaceTree[4][3], result7_temp_3, result6_c_temp_3);
    FA result7_FA_5(result7_c_temp_5, result7_temp_5, wallaceTree[5][2], result7_temp_4, result6_c_temp_4);
    FA result7_FA_6(result7_c_temp_6, result7_temp_6, wallaceTree[6][1], result7_temp_5, result6_c_temp_5);
    HA result7_HA_1(result7_c, result[7], wallaceTree[7][0], result7_temp_6);

    // result[8]
    logic result8_c_temp_1, result8_c_temp_2, result8_c_temp_3, result8_c_temp_4, result8_c_temp_5, result8_c_temp_6, result8_c, result8_temp_1, result8_temp_2, result8_temp_3, result8_temp_4, result8_temp_5, result8_temp_6;
    FA result8_FA_1(result8_c_temp_1, result8_temp_1, wallaceTree[1][7], wallaceTree[2][6], result7_c);
    FA result8_FA_2(result8_c_temp_2, result8_temp_2, wallaceTree[3][5], result8_temp_1, result7_c_temp_1);
    FA result8_FA_3(result8_c_temp_3, result8_temp_3, wallaceTree[4][4], result8_temp_2, result7_c_temp_2);
    FA result8_FA_4(result8_c_temp_4, result8_temp_4, wallaceTree[5][3], result8_temp_3, result7_c_temp_3);
    FA result8_FA_5(result8_c_temp_5, result8_temp_5, wallaceTree[6][2], result8_temp_4, result7_c_temp_4);
    FA result8_FA_6(result8_c_temp_6, result8_temp_6, wallaceTree[7][1], result8_temp_5, result7_c_temp_5);
    HA result8_HA_1(result8_c, result[8], result8_temp_6, result7_c_temp_6);

    // result[9]
    logic result9_c_temp_1, result9_c_temp_2, result9_c_temp_3, result9_c_temp_4, result9_c_temp_5, result9_c, result9_temp_1, result9_temp_2, result9_temp_3, result9_temp_4, result9_temp_5;
    FA result9_FA_1(result9_c_temp_1, result9_temp_1, wallaceTree[2][7], wallaceTree[3][6], result8_c);
    FA result9_FA_2(result9_c_temp_2, result9_temp_2, wallaceTree[4][5], result9_temp_1, result8_c_temp_1);
    FA result9_FA_3(result9_c_temp_3, result9_temp_3, wallaceTree[5][4], result9_temp_2, result8_c_temp_2);
    FA result9_FA_4(result9_c_temp_4, result9_temp_4, wallaceTree[6][3], result9_temp_3, result8_c_temp_3);
    FA result9_FA_5(result9_c_temp_5, result9_temp_5, wallaceTree[7][2], result9_temp_4, result8_c_temp_4);
    FA result9_FA_6(result9_c, result[9], result9_temp_5, result8_c_temp_5, result8_c_temp_6);

    // result[10]
    logic result10_c_temp_1, result10_c_temp_2, result10_c_temp_3, result10_c_temp_4, result10_c, result10_temp_1, result10_temp_2, result10_temp_3, result10_temp_4;
    FA result10_FA_1(result10_c_temp_1, result10_temp_1, wallaceTree[3][7], wallaceTree[4][6], result9_c);
    FA result10_FA_2(result10_c_temp_2, result10_temp_2, wallaceTree[5][5], result10_temp_1, result9_c_temp_1);
    FA result10_FA_3(result10_c_temp_3, result10_temp_3, wallaceTree[6][4], result10_temp_2, result9_c_temp_2);
    FA result10_FA_4(result10_c_temp_4, result10_temp_4, wallaceTree[7][3], result10_temp_3, result9_c_temp_3);
    FA result10_FA_5(result10_c, result[10], result10_temp_4, result9_c_temp_4, result9_c_temp_5);

    // result[11]
    logic result11_c_temp_1, result11_c_temp_2, result11_c_temp_3, result11_c, result11_temp_1, result11_temp_2, result11_temp_3;
    FA result11_FA_1(result11_c_temp_1, result11_temp_1, wallaceTree[4][7], wallaceTree[5][6], result10_c);
    FA result11_FA_2(result11_c_temp_2, result11_temp_2, wallaceTree[6][5], result11_temp_1, result10_c_temp_1);
    FA result11_FA_3(result11_c_temp_3, result11_temp_3, wallaceTree[7][4], result11_temp_2, result10_c_temp_2);
    FA result11_FA_4(result11_c, result[11], result11_temp_3, result10_c_temp_3, result10_c_temp_4);

    // result[12]
    logic result12_c_temp_1, result12_c_temp_2, result12_c, result12_temp_1, result12_temp_2;
    FA result12_FA_1(result12_c_temp_1, result12_temp_1, wallaceTree[5][7], wallaceTree[6][6], result11_c);
    FA result12_FA_2(result12_c_temp_2, result12_temp_2, wallaceTree[7][5], result12_temp_1, result11_c_temp_1);
    FA result12_FA_3(result12_c, result[12], result12_temp_2, result11_c_temp_2, result11_c_temp_3);

    // result[13]
    logic result13_c_temp_1, result13_c, result13_temp_1;
    FA result13_FA_1(result13_c_temp_1, result13_temp_1, wallaceTree[6][7], wallaceTree[7][6], result12_c);
    FA result13_FA_2(result13_c, result[13], result13_temp_1, result12_c_temp_2, result12_c_temp_1);

    // result[14]
    logic result14_c;
    FA result14_FA_1(result14_c, result[14], wallaceTree[7][7], result13_c, result13_c_temp_1);

    // result[15]
    assign result[15] = result14_c;
endmodule

`default_nettype none

module nBitCarryLookAheadAdder #(parameter n = 4)(total, A, B);
    output logic [n:0] total;
    input logic [n-1:0] A;
    input logic [n-1:0] B;

    logic[n-1:0] gi, pi, sum;
    logic[n:0] ci;

    assign ci[0] = 1'b0;

    genvar i;
    generate
        for(i = 0;i < n;i = i+1) begin: giAndpi
            assign gi[i] = A[i]&B[i];
            assign pi[i] = A[i]^B[i];
            assign ci[i+1] = gi[i]|(pi[i]&ci[i]);
        end
    endgenerate

    genvar j;
    generate
        for(j = 0;j < n;j = j+1) begin: calculation
            FA adder(.Cout(), .sum(sum[j]), .A(A[j]), .B(B[j]), .Cin(ci[j]));
        end
    endgenerate

    assign total = {ci[n], sum[n-1:0]};
endmodule


module HA (carry, sum, A, B);
    output logic carry;
    output logic sum;
    input logic A;
    input logic B;

    // instantiating sum and carry primitives
    outSum s(sum, A, B);
    outCarry c(carry, A, B);
endmodule


module FA (Cout, sum, A, B, Cin);
    output logic Cout;
    output logic sum;
    input logic A;
    input logic B;
    input logic Cin;

    logic temp_sum, temp_carry1, temp_carry2;

    // Sum = A XOR B XOR Cin
    assign temp_sum = A ^ B;
    assign sum = temp_sum ^ Cin;

    // Cout = (A AND B) OR (Cin AND (A XOR B))
    assign temp_carry1 = A & B;
    assign temp_carry2 = Cin & temp_sum;
    assign Cout = temp_carry1 | temp_carry2;
endmodule


module outSum (sum, A, B);
    output logic sum;
    input logic A;
    input logic B;

    assign sum = A ^ B;
endmodule

module outCarry (carry, A, B);
    output logic carry;
    input logic A;
    input logic B;

    assign carry = A & B;
endmodule

module carry_save_8 (
    input  logic               clk,
    input  logic               reset,
    input  logic               start,
    input  logic        [1:0]  sew,         // 0: 16-bit mode (2x16x16), 1: 32-bit mode (1x32x32)
    input  logic signed [15:0] mult_out_1,  // Partial product for multiplier 1 
    input  logic signed [15:0] mult_out_2,  // Partial product for multiplier 2 
    input  logic signed [15:0] mult_out_3,  // Partial product for multiplier 3
    input  logic signed [15:0] mult_out_4,  // Partial product for multiplier 4
    input  logic signed [15:0] mult_out_5,  // Partial product for multiplier 5
    input  logic signed [15:0] mult_out_6,  // Partial product for multiplier 6
    input  logic signed [15:0] mult_out_7,  // Partial product for multiplier 7
    input  logic signed [15:0] mult_out_8,  // Partial product for multiplier 8
    input logic                sign_A0, sign_A1, sign_A2, sign_A3,
    input logic                sign_B0, sign_B1, sign_B2, sign_B3,
    output logic signed [31:0] product_1,  // Final result for multiplier 1 (or low 32 bits in 32-bit mode)
    output logic signed [31:0] product_2,   // Final result for multiplier 2 (or high 32 bits in 32-bit mode) 
    output logic signed [31:0] product_16sew_1, product_16sew_2,
    output logic signed [15:0] product_8sew_1, product_8sew_2, product_8sew_3, product_8sew_4,
    output logic signed [63:0] product_32sew, product    
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
    PP1_32, PP2_32    
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

    case (state)
        IDLE: begin
            //next_done = 0;
            if (start) begin
                next_accum_0 = 0;
                next_accum_1 = 0;
                next_accum_2 = 0;
                next_accum_3 = 0;

                next_state = (sew == 2'b00) ? PP_8 :
                                    (sew == 2'b01) ? PP_16:
                                    (sew == 2'b10) ? PP1_32: IDLE;               
                end
        end

        PP_8: begin
            next_accum_0 =  mult_out_1;
            next_accum_1 =  mult_out_2;
            next_accum_2 =  mult_out_3;
            next_accum_3 =  mult_out_4; 
            next_state = IDLE;   
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
            sum16_9 = add_carry_8bit(result_2[7:0], result_1[9:8], 1'b0, 1'b0);
            sum16_10 = add_carry_8bit(result_3[7:0],result_2[9:8], 1'b0, 1'b0);

            sum16_11 = add_carry_8bit(result_5[7:0], result_4[9:8], 1'b0, 1'b0);
            sum16_12 = add_carry_8bit(result_6[7:0], result_5[9:8], 1'b0, 1'b0);
            sum16_13 = add_carry_8bit(result_7[7:0], result_6[9:8], 1'b0, 1'b0);
 
            next_accum_0 =  {sum16_8[7:0], result_0[7:0]};
            next_accum_1 =  {sum16_10[7:0], sum16_9[7:0]};
            next_accum_2 =  {sum16_11[7:0], result_4[7:0]};
            next_accum_3 =  {sum16_13[7:0], sum16_12[7:0]};
                      
            next_state = IDLE ;            
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

            {accum_carry_0, next_accum_0} =  {carry_0[7:0], result_0[7:0]};
            {accum_carry_1, next_accum_1} =  {carry_2[7:0], carry_1[7:0]};
            {accum_carry_2, next_accum_2} =  {carry_4[7:0], carry_3[7:0]};
            {accum_carry_3, next_accum_3} =  {15'b0        ,carry_4[8]};

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

            next_state = IDLE ;

        end 
        default:
            next_state = IDLE;
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


// Compute absolute values based on SEW
always_comb begin
        product_8sew_1  = 16'h0;
        product_8sew_2  = 16'h0;
        product_8sew_3  = 16'h0;
        product_8sew_4  = 16'h0;
        product_16sew_1 = 32'h0;
        product_16sew_2 = 32'h0;
        product_32sew   = 64'h0;
        product         = 0;
    case (sew)
        2'b00: begin // 8-bit: individual two's complement

            product_8sew_1 = (sign_A0 ^ sign_B0) ? (~product_1[15:0] + 8'd1) : product_1[15:0];
            product_8sew_2 = (sign_A1 ^ sign_B1) ? (~product_1[31:16] + 8'd1) : product_1[31:16];
            product_8sew_3 = (sign_A2 ^ sign_B2) ? (~product_2[15:0] + 8'd1) : product_2[15:0];
            product_8sew_4 = (sign_A3 ^ sign_B3) ? (~product_2[31:16] + 8'd1) : product_2[31:16];
            product        = {product_8sew_4, product_8sew_3, product_8sew_2, product_8sew_1};

            end
        2'b01: begin // 16-bit: two's complement on 16-bit pairs

            product_16sew_1 = (sign_A1 ^ sign_B1) ? (~product_1 + 8'd1) : product_1;
            product_16sew_2 = (sign_A3 ^ sign_B3) ? (~product_2 + 8'd1) : product_2;
            product = {product_16sew_2, product_16sew_1};
               
            end
        2'b10: begin // 32-bit: two's complement on full 32-bit
                
            product_32sew = (sign_A3 ^ sign_B3) ? (~{product_2 , product_1} + 8'd1) : {product_2, product_1};
            product = product_32sew;

            end
       default: begin
            product_8sew_1  = 16'h0;
            product_8sew_2  = 16'h0;
            product_8sew_3  = 16'h0;
            product_8sew_4  = 16'h0;
            product_16sew_1 = 32'h0;
            product_16sew_2 = 32'h0;
            product_32sew   = 64'h0;

            product = {product_2 , product_1};

            end
        endcase
    end

endmodule

module multiplier_top(
    input  logic                clk,
    input  logic                reset,
    input  logic        [1:0]   sew,
    input  logic                start,
    input  logic signed [31:0]  data_in_A,
    input  logic signed [31:0]  data_in_B,
    input logic                 signed_mode,
    output logic                count_0, 
    output logic signed [31:0]  product_1,
    output logic signed [31:0]  product_2,
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

    // Sign outputs for result adjustment
    logic sign_A0, sign_A1, sign_A2, sign_A3;
    logic sign_B0, sign_B1, sign_B2, sign_B3;

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
        .count_0(count_0),
        .signed_mode(signed_mode),
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
    wallaceTreeMultiplier8Bit wallace_1 (.a(mult1_A), .b(mult1_B), .result(mult_out_1));
    wallaceTreeMultiplier8Bit wallace_2 (.a(mult2_A), .b(mult2_B), .result(mult_out_2));
    wallaceTreeMultiplier8Bit wallace_3 (.a(mult3_A), .b(mult3_B), .result(mult_out_3));
    wallaceTreeMultiplier8Bit wallace_4 (.a(mult4_A), .b(mult4_B), .result(mult_out_4));
    wallaceTreeMultiplier8Bit wallace_5 (.a(mult5_A), .b(mult5_B), .result(mult_out_5));
    wallaceTreeMultiplier8Bit wallace_6 (.a(mult6_A), .b(mult6_B), .result(mult_out_6));
    wallaceTreeMultiplier8Bit wallace_7 (.a(mult7_A), .b(mult7_B), .result(mult_out_7));
    wallaceTreeMultiplier8Bit wallace_8 (.a(mult8_A), .b(mult8_B), .result(mult_out_8));

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
        .start(start),
        .sew(sew),
        .mult_out_1(mult_out_1_delayed),
        .mult_out_2(mult_out_2_delayed),
        .mult_out_3(mult_out_3_delayed),
        .mult_out_4(mult_out_4_delayed),
        .mult_out_5(mult_out_5_delayed),
        .mult_out_6(mult_out_6_delayed),
        .mult_out_7(mult_out_7_delayed),
        .mult_out_8(mult_out_8_delayed),
        .sign_A0(sign_A0),
        .sign_A1(sign_A1),
        .sign_A2(sign_A2),
        .sign_A3(sign_A3),
        .sign_B0(sign_B0),
        .sign_B1(sign_B1),
        .sign_B2(sign_B2),
        .sign_B3(sign_B3),
        .product_1(product_1),
        .product_2(product_2),
        .product_8sew_1(product_8sew_1),
        .product_8sew_2(product_8sew_2),
        .product_8sew_3(product_8sew_3),
        .product_8sew_4(product_8sew_4),
        .product_16sew_1(product_16sew_1),
        .product_16sew_2(product_16sew_2),
        .product_32sew(product_32sew),
        .product(product)
    );


endmodule

// ============================================================================
// 512-bit Vector Multiplier with Configurable SEW (OOP-based Design)
// ============================================================================

// Top-level wrapper for 512-bit inputs
module vector_multiplier(
    input  logic               clk,
    input  logic               reset,
    input  logic        [1:0]  sew,           // 00=8-bit, 01=16-bit, 10=32-bit
    input  logic               start,
    input  logic signed [`VLEN-1:0] data_in_A,    // 512-bit input A
    input  logic signed [`VLEN-1:0] data_in_B,    // 512-bit input B
    input  logic                signed_mode,
    output logic               count_0,
    output logic signed [`2*VLEN-1:0] product      // 1024-bit result
);

    // Number of 32-bit processing elements
    localparam NUM_PES = (`VLEN / 32); 
    
    logic [NUM_PES-1:0] pe_count_0;
    logic signed [31:0] pe_product_1 [NUM_PES-1:0];
    logic signed [31:0] pe_product_2 [NUM_PES-1:0];
    logic signed [63:0] pe_product [NUM_PES-1:0];
    
    genvar i;
    generate
        for (i = 0; i < NUM_PES; i++) begin : gen_processing_elements
            localparam BASE = i * 32;
            
            multiplier_top u_top_pe (
                .clk(clk),
                .reset(reset),
                .sew(sew),
                .start(start),
                .signed_mode(signed_mode),
                .data_in_A(data_in_A[BASE +: 32]),  
                .data_in_B(data_in_B[BASE +: 32]),
                .count_0(pe_count_0[i]),
                .product_1(pe_product_1[i]),
                .product_2(pe_product_2[i]),
                .product(pe_product[i])
            );
        end
    endgenerate
    
    always_comb begin
        count_0 = &pe_count_0;  // AND all count_0 signals
        
        case (sew)
            2'b00: begin  // 8-bit elements (64 elements)
                // Each PE produces 4x 16-bit results
                for (int j = 0; j < NUM_PES; j++) begin
                    product[j*64 +: 64] = pe_product[j];
                end
            end
            
            2'b01: begin  // 16-bit elements (32 elements)
                // Each PE produces 2x 32-bit results
                for (int j = 0; j < NUM_PES; j++) begin
                    product[j*64 +: 64] = pe_product[j];
                end
            end
            
            2'b10: begin  // 32-bit elements (16 elements)
                // Each PE produces 1x 64-bit result
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

