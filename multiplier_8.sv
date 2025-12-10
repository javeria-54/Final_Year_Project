module multiplier_8 (
    input logic clk,
    input logic reset,
    input logic [31:0] data_in_A,
    input logic [31:0] data_in_B,
    input logic [1:0] sew,

    output logic count_0,    
    output logic [7:0] mult1_A,
    output logic [7:0] mult1_B,
    output logic [7:0] mult2_A,
    output logic [7:0] mult2_B,
    output logic [7:0] mult3_A,
    output logic [7:0] mult3_B,
    output logic [7:0] mult4_A,
    output logic [7:0] mult4_B,
    output logic [7:0] mult5_A,
    output logic [7:0] mult5_B,
    output logic [7:0] mult6_A,
    output logic [7:0] mult6_B,
    output logic [7:0] mult7_A,
    output logic [7:0] mult7_B,
    output logic [7:0] mult8_A,
    output logic [7:0] mult8_B,

    // Sign outputs for result adjustment
    output logic sign_A0, sign_A1, sign_A2, sign_A3,
    output logic sign_B0, sign_B1, sign_B2, sign_B3
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