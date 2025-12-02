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
    output logic [7:0] mult8_B
);
    logic [7:0] A0, A1, A2, A3;
    logic [7:0] B0, B1, B2, B3;
    logic sew_was_2;
    
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
    assign A0 = data_in_A [7:0];
    assign A1 = data_in_A [15:8];
    assign A2 = data_in_A [23:16];
    assign A3 = data_in_A [31:24];
    assign B0 = data_in_B [7:0]; 
    assign B1 = data_in_B [15:8];
    assign B2 = data_in_B [23:16];
    assign B3 = data_in_B [31:24];

    assign mult1_A = A0;
    assign mult2_A = A1;
    assign mult3_A = A2;
    assign mult4_A = A3;
    assign mult5_A = A0;
    assign mult6_A = A1;
    assign mult7_A = A2;
    assign mult8_A = A3;

    logic [7:0] mux0_out, mux1_out ;
    
    assign mux0_out = count_0 ? B2 : B0 ;
    assign mux1_out = count_0 ? B3 : B1 ;

    assign mult1_B = (sew == 2'b00) ? B0 :
           (sew == 2'b01) ? B0 :
           (sew == 2'b10) ? mux0_out : 8'b0;

    assign mult2_B = (sew == 2'b00) ? B1 :
           (sew == 2'b01) ? B0 :
           (sew == 2'b10) ? mux0_out : 8'b0;
    
    assign mult3_B = (sew == 2'b00) ? B2 :
           (sew == 2'b01) ? B2 :
           (sew == 2'b10) ? mux0_out : 8'b0;

    assign mult4_B = (sew == 2'b00) ? B3 :
           (sew == 2'b01) ? B2 :
           (sew == 2'b10) ? mux0_out : 8'b0;

    assign mult5_B = (sew == 2'b00) ? B0 :
           (sew == 2'b01) ? B1 :
           (sew == 2'b10) ? mux1_out : 8'b0;

    assign mult6_B = (sew == 2'b00) ? B1 :
           (sew == 2'b01) ? B1 :
           (sew == 2'b10) ? mux1_out : 8'b0;
    
    assign mult7_B = (sew == 2'b00) ? B2 :
           (sew == 2'b01) ? B3 :
           (sew == 2'b10) ? mux1_out : 8'b0;

    assign mult8_B = (sew == 2'b00) ? B3 :
           (sew == 2'b01) ? B3 :
           (sew == 2'b10) ? mux1_out : 8'b0;

endmodule