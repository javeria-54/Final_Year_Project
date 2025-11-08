`timescale 1ns/1ps

module tb_multiplier_8;

    // DUT inputs
    logic clk;
    logic reset;
    logic [31:0] data_in_A1;
    logic [31:0] data_in_B1;
    logic [31:0] data_in_A2;
    logic [31:0] data_in_B2;
    logic [1:0] sew;
    logic count_0;

    // DUT outputs
    logic [7:0] mult1_A, mult2_A, mult3_A, mult4_A;
    logic [7:0] mult5_A, mult6_A, mult7_A, mult8_A;
    logic [7:0] mult1_B, mult2_B, mult3_B, mult4_B;
    logic [7:0] mult5_B, mult6_B, mult7_B, mult8_B;

    // Instantiate DUT
    multiplier_8 dut (
        .clk(clk),
        .reset(reset),
        .data_in_A1(data_in_A1),
        .data_in_B1(data_in_B1),
        .data_in_A2(data_in_A2),
        .data_in_B2(data_in_B2),
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

    // Clock generation
    initial begin
        clk = 1;
        forever #5 clk = ~clk;  // 100 MHz clock
    end

    // Stimulus
    initial begin
        $display("===== Starting Simulation =====");
        data_in_A1 = 32'h11223344;   // A0=44, A1=33, A2=22, A3=11
        data_in_B1 = 32'hAABBCCDD;   // B0=DD, B1=CC, B2=BB, B3=AA
        data_in_A2 = 32'h55667788;   // A0=44, A1=33, A2=22, A3=11
        data_in_B2 = 32'h9900FF11;   // B0=DD, B1=CC, B2=BB, B3=AA
        reset = 0;

        // Case 1: sew=00
        #10 sew = 2'b00; count_0 = 0;
        print_outputs("Case 1: sew=00, count_0=0");

        // Case 2: sew=01
        #10 sew = 2'b01; count_0 = 0;
        print_outputs("Case 2: sew=01, count_0=0");

        // Case 3: sew=10, count_0=0
        #10 sew = 2'b10; count_0 = 0;
        print_outputs("Case 3: sew=10, count_0=0");

        // Case 4: sew=10, count_0=1
        #10 sew = 2'b10; count_0 = 1;
        print_outputs("Case 4: sew=10, count_0=1");

        // Finish simulation
        $display("===== Simulation Finished =====");
        $stop;
    end

    // Task to print outputs
    task print_outputs(string label);
        $display("\n--- %s ---", label);
        $display("A: %h %h %h %h %h %h %h %h", 
                 mult1_A, mult2_A, mult3_A, mult4_A,
                 mult5_A, mult6_A, mult7_A, mult8_A);
        $display("B: %h %h %h %h %h %h %h %h", 
                 mult1_B, mult2_B, mult3_B, mult4_B,
                 mult5_B, mult6_B, mult7_B, mult8_B);
    endtask

endmodule
