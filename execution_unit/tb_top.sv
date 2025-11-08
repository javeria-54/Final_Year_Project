`timescale 1ns/1ps

module tb_top_multiplier;

    // Testbench signals
    logic clk;
    logic reset;

    // DUT I/O
    // Since your DUT doesn't have direct inputs for A/B in ports, 
    // you'll need to drive them indirectly via `data_in_A` / `data_in_B` inside.
    top_multiplier dut (
        .clk(clk),
        .reset(reset)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100MHz clock (10ns period)
    end

    // Reset sequence
    initial begin
        reset = 1;
        #20;
        reset = 0;
    end

    // Stimulus
    initial begin
        // Wait for reset deassert
        @(negedge reset);

        // Example: Set SEW, load data into loader modules
        dut.sew         = 3'b010;         // Example SEW mode
        dut.data_in_A   = 32'h0004_0003;  // Example operand A
        dut.data_in_B   = 32'h0002_0001;  // Example operand B

        // Simulate starting multiplier
        dut.start       = 1;
        dut.mode_32bit  = 1;  // 32-bit mode
        #10;
        dut.start       = 0;

        // Let it run for some cycles
        repeat (20) @(posedge clk);

        // Change mode to 16-bit example
        dut.mode_32bit  = 0;
        dut.data_in_A   = 32'h0008_0007;
        dut.data_in_B   = 32'h0006_0005;
        dut.start       = 1;
        #10;
        dut.start       = 0;

        repeat (30) @(posedge clk);

        // Finish simulation
        $display("Simulation finished");
        $stop;
    end

    // Monitor outputs
    initial begin
        $monitor("[%0t] start=%b mode_32bit=%b product1=%h product2=%h done=%b",
                 $time, dut.start, dut.mode_32bit, dut.product_1, dut.product_2, dut.done);
    end

endmodule
