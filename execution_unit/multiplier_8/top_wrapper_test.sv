
// ============================================
// Complete Testbench
// ============================================
module tb_top_wrapper_512;

    // Testbench signals
    logic                 clk;
    logic                 reset;
    logic          [1:0]  sew;
    logic                 start;
    logic signed [511:0]  data_in_A;
    logic signed [511:0]  data_in_B;
    logic          [15:0] count_0;
    logic signed [1023:0] product;

    // DUT instantiation
    top_wrapper_512 dut (
        .clk       (clk),
        .reset     (reset),
        .sew       (sew),
        .start     (start),
        .data_in_A (data_in_A),
        .data_in_B (data_in_B),
        .count_0   (count_0),
        .product   (product)
    );

    // ========================================
    // Clock generation (100MHz = 10ns period)
    // ========================================
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // ========================================
    // Test sequence
    // ========================================
    initial begin
        // Initialize
        reset = 1;
        start = 0;
        sew = 2'b00;  // 8-bit elements
        data_in_A = 512'h0;
        data_in_B = 512'h0;
        
        // Reset pulse
        #20 reset = 0;
        #10;
        
        // ========================================
        // Test Case 1: Simple multiplication
        // ========================================
        $display("\n=== Test Case 1: Simple Values ===");
        
        // Load data: 16 chunks of 32-bit data
        data_in_A = {
            32'h0000_0001,  // Module 15
            32'h0000_0002,  // Module 14
            32'h0000_0003,  // Module 13
            32'h0000_0004,  // Module 12
            32'h0000_0005,  // Module 11
            32'h0000_0006,  // Module 10
            32'h0000_0007,  // Module 9
            32'h0000_0008,  // Module 8
            32'h0000_0009,  // Module 7
            32'h0000_000A,  // Module 6
            32'h0000_000B,  // Module 5
            32'h0000_000C,  // Module 4
            32'h0000_000D,  // Module 3
            32'h0000_000E,  // Module 2
            32'h0000_000F,  // Module 1
            32'h0000_0010   // Module 0
        };
        
        data_in_B = {
            32'h0000_0002,  // Module 15
            32'h0000_0002,  // Module 14
            32'h0000_0002,  // Module 13
            32'h0000_0002,  // Module 12
            32'h0000_0002,  // Module 11
            32'h0000_0002,  // Module 10
            32'h0000_0002,  // Module 9
            32'h0000_0002,  // Module 8
            32'h0000_0002,  // Module 7
            32'h0000_0002,  // Module 6
            32'h0000_0002,  // Module 5
            32'h0000_0002,  // Module 4
            32'h0000_0002,  // Module 3
            32'h0000_0002,  // Module 2
            32'h0000_0002,  // Module 1
            32'h0000_0002   // Module 0
        };
        
        // Start computation
        start = 1;
        #10 start = 0;
        
        // Wait for all modules to complete
        wait(&count_0);  // Wait until all count_0 bits are high
        #50;
        
        $display("All modules completed!");
        $display("count_0 status: %b", count_0);
        
        // Display results for each module
        for (int i = 0; i < 16; i++) begin
            $display("Module %2d: Product = %h", i, product[(64*i) +: 64]);
        end
        
        // ========================================
        // Test Case 2: Different SEW mode
        // ========================================
        #100;
        $display("\n=== Test Case 2: Different SEW ===");
        
        reset = 1;
        #20 reset = 0;
        #10;
        
        sew = 2'b01;  // 16-bit elements
        data_in_A = 512'h1234_5678_9ABC_DEF0_1111_2222_3333_4444_5555_6666_7777_8888_9999_AAAA_BBBB_CCCC;
        data_in_B = 512'h0002_0002_0002_0002_0002_0002_0002_0002_0002_0002_0002_0002_0002_0002_0002_0002;
        
        start = 1;
        #10 start = 0;
        
        wait(&count_0);
        #50;
        
        $display("Results with SEW=01:");
        for (int i = 0; i < 4; i++) begin
            $display("Chunk %d: %h", i, product[(256*i) +: 256]);
        end
        
        // ========================================
        // End simulation
        // ========================================
        #100;
        $display("\n=== Simulation Complete ===");
        $finish;
    end
    
    // ========================================
    // Monitor changes
    // ========================================
    initial begin
        $monitor("Time=%0t | count_0=%b | start=%b", $time, count_0, start);
    end
    
    // Optional: Waveform dump
    initial begin
        $dumpfile("top_wrapper_512.vcd");
        $dumpvars(0, tb_top_wrapper_512);
    end

endmodule