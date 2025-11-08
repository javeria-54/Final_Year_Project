module top_multiplier(
    input logic clk,
    input logic reset,
    input logic sew,
    input logic enable_2bit, enable_4bit,
    input logic start,
    input logic mode_32bit,
    input logic [7:0] data_in_A,
    input logic [7:0] data_in_B,
    output logic [31:0] product_1,
    output logic [31:0] product_2,
    output logic done    
);
    logic [1:0] count_16bit;
    logic [3:0] count_32bit;
    logic [7:0] mult1_A, mult1_B, mult2_A, mult2_B;    
    logic [15:0] mult_out_1;
    logic [15:0] mult_out_2;
    

    multiplier_2 mult(
            .clk(clk),
            .reset(reset),
            .data_in_A(data_in_A),
            .data_in_B(data_in_B),
            .sew(sew), 
            .count_16bit(count_16bit),
            .count_32bit(count_32bit), 
            .mult1_A(mult1_A),
            .mult1_B(mult1_B),
            .mult2_A(mult2_A),
            .mult2_B(mult2_B)
    );
    counter_2bit count_2(
            .clk(clk),
            .reset(reset),
            .enable_2bit(enable_2bit),
            .count_16bit(count_16bit)
);
    counter_4bit count_4(
            .clk(clk),
            .reset(reset),
            .enable_4bit(enable_4bit),
            .count_32bit(count_32bit)
);
    dadda_8 dadda0(
            .A(mult1_A),
            .B(mult1_B),
            .y(mult_out_1)
    );
    dadda_8 dadda1(
            .A(mult2_A),
            .B(mult2_B),
            .y(mult_out_2)
    );
    combined_accumulator acc(
            .clk(clk),
            .rst(reset),
            .start(start),
            .mode_32bit(mode_32bit),  
            .mult_out_1(mult_out_1),  
            .mult_out_2(mult_out_2),  
            .product_1(product_1),  
            .product_2(product_2),  
            .done(done)              
);
    
endmodule 