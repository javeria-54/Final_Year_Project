module top(
    input  logic               clk,
    input  logic               reset,
    input  logic        [1:0]  sew,
    input  logic               start,
    input  logic signed [31:0] data_in_A1,
    input  logic signed [31:0] data_in_B1,
    //input  logic signed [31:0] data_in_A2,
    //input  logic signed [31:0] data_in_B2,
    output logic               count_0, 
    output logic signed [31:0] product_1,
    output logic signed [31:0] product_2,
    output logic signed [63:0] product
    //output logic signed [31:0] product_3,
    //output logic signed [31:0] product_4
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

    // ──────────────────────────────────────────────
    // Stage 1: Multiplier input preparation
    // ──────────────────────────────────────────────
    multiplier_8 mult (
        .clk(clk),
        .reset(reset),
        .data_in_A1(data_in_A1),
        .data_in_B1(data_in_B1),
        //.data_in_A2(data_in_A2),
        //.data_in_B2(data_in_B2),
        .sew(sew),
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
        .mult8_B(mult8_B)
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
        .product_1(product_1),
        .product_2(product_2)
        //.product_3(product_3),
        //.product_4(product_4)
    );

    assign product = {product_2, product_1};
    

endmodule