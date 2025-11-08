//`timescale 1ns/1ps

module tb_top;

    // Testbench signals
    logic clk;
    logic reset;
    logic [31:0] data_in_A, data_in_B;
    logic [1:0] sew;
    logic [1:0] count_16bit;
    logic [3:0] count_32bit;
    logic [7:0] mult1_A, mult1_B, mult2_A, mult2_B;
    logic enable_2bit, enable_4bit;

    // DUT instances
    multiplier uut (
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

    counter_2bit c2 (
        .clk(clk),
        .reset(reset),
        .enable_2bit(enable_2bit),
        .count_16bit(count_16bit)
    );

    counter_4bit c4 (
        .clk(clk),
        .reset(reset),
        .enable_4bit(enable_4bit),
        .count_32bit(count_32bit)
    );

    // Clock generation
    initial begin
        clk = 1;
        forever #5 clk = ~clk; // 10 ns clock
    end

    // Test stimulus
    initial begin
        // Initialize
        reset = 1;
        sew = 2'b00;
        data_in_A = 32'h11223344; // A3=11, A2=22, A1=33, A0=44
        data_in_B = 32'h55667788; // B3=55, B2=66, B1=77, B0=88
        enable_2bit = 0;
        enable_4bit = 0;

        // Release reset
        #12 reset = 0;

        // Test SEW = 00 (byte mode, enable_2bit counter)
        enable_2bit = 1;
        repeat(4) @(posedge clk);
        enable_2bit = 0;

        // Test SEW = 01 (halfword mode, still enable_2bit)
        sew = 2'b01;
        enable_2bit = 1;
        repeat(4) @(posedge clk);
        enable_2bit = 0;

        // Test SEW = 10 (word mode, enable_4bit counter)
        sew = 2'b10;
        enable_4bit = 1;
        repeat(16) @(posedge clk);
        enable_4bit = 0;

        // End simulation
        #20 $finish;
    end

    // Monitor
    initial begin
        $monitor("T=%0t | SEW=%b | C16=%b | C32=%b | mult1_A=%h mult1_B=%h mult2_A=%h mult2_B=%h",
                 $time, sew, count_16bit, count_32bit, mult1_A, mult1_B, mult2_A, mult2_B);
    end

endmodule
