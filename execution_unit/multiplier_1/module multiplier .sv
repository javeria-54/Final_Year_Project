module multiplier_2 (
    input logic clk,
    input logic reset,
    input logic [31:0] data_in_A,
    input logic [31:0] data_in_B,
    input logic [1:0] sew, 
    input logic [1:0] count_16bit,
    input logic [3:0] count_32bit, 

    output logic [7:0] mult1_A,
    output logic [7:0] mult1_B,
    output logic [7:0] mult2_A,
    output logic [7:0] mult2_B
);

    logic [7:0] A0, A1, A2, A3;
    logic [7:0] B0, B1, B2, B3;
    
    assign A0 = data_in_A [7:0];
    assign A1 = data_in_A [15:8];
    assign A2 = data_in_A [23:16];
    assign A3 = data_in_A [31:24];
    assign B0 = data_in_B [7:0]; 
    assign B1 = data_in_B [15:8];
    assign B2 = data_in_B [23:16];
    assign B3 = data_in_B [31:24];
    
    logic enable_2bit;
    logic enable_4bit;

    always_comb begin
    
        enable_2bit = 0;
        enable_4bit = 0;

        case (sew) 
            2'b00: enable_2bit = 1;
            2'b01: enable_2bit = 1;
            2'b10: enable_4bit = 1;
            default begin end
        endcase
    end

    logic count_0_16bit, count_1_16bit ;
    logic [1:0] count_0_32bit, count_1_32bit ;
    logic [7:0] mux0_out, mux1_out, mux2_out, mux3_out, mux4_out, mux5_out, mux6_out, mux7_out, mux8_out, mux9_out ;

    assign count_0_16bit = count_16bit [0];
    assign count_1_16bit = count_16bit [1]; 
    assign count_0_32bit = count_32bit [1:0];
    assign count_1_32bit = count_32bit [3:2];

    assign mux0_out = count_0_16bit ? A1 : A0 ;
    assign mux1_out = count_0_16bit ? A3 : A2 ;
    assign mux2_out = count_1_16bit ? B1 : B0 ;
    assign mux3_out = count_1_16bit ? B3 : B2 ;
    
    assign mux4_out = (count_0_32bit == 2'b00) ? A0 :
           (count_0_32bit == 2'b01) ? A1 :
           (count_0_32bit == 2'b10) ? A2 : A3;

    assign mux5_out = (count_1_32bit == 2'b00) ? B0 :
           (count_1_32bit == 2'b01) ? B1 :
           (count_1_32bit == 2'b10) ? B2 : B3;

    assign mux6_out = count_0_16bit ? A1 : A0;
    assign mux7_out = count_0_16bit ? A3 : A2;
    assign mux8_out = count_0_16bit ? B1 : B0;
    assign mux9_out = count_0_16bit ? B3 : B2;

    assign mult1_A = (sew == 2'b00) ? mux6_out :
           (sew == 2'b01) ? mux0_out :
           (sew == 2'b10) ? mux4_out : 8'b0;

    assign mult1_B = (sew == 2'b00) ? mux8_out :
           (sew == 2'b01) ? mux2_out :
           (sew == 2'b10) ? mux5_out : 8'b0;  

    assign mult2_A = sew ? mux1_out : mux7_out ;
    assign mult2_B = sew ? mux3_out : mux9_out ;
 

endmodule
