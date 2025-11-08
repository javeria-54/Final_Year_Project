`timescale 1ns/1ps

module tb_combined_accumulator;

    // TB signals
    logic clk;
    logic rst;
    logic start;
    logic mode_32bit;
    logic [15:0] mult_out_1;
    logic [15:0] mult_out_2;
    logic [31:0] product_1;
    logic [31:0] product_2;
    logic done;

    // Instantiate DUT
    combined_accumulator uut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .mode_32bit(mode_32bit),
        .mult_out_1(mult_out_1),
        .mult_out_2(mult_out_2),
        .product_1(product_1),
        .product_2(product_2),
        .done(done)
    );

    // Clock generation (100MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Task to run one mode
    task run_mode(input logic mode);
        integer cycle;
        begin
            mode_32bit = mode;
            start = 1;
            mult_out_1 = 16'h0102; // test pattern
            mult_out_2 = 16'h0304; // only used in 16-bit mode
            @(posedge clk);
            start = 0;

            // For a realistic test, change partial products each cycle
            for (cycle = 0; cycle < 20; cycle++) begin
                mult_out_1 = mult_out_1 + 16'h1111;
                mult_out_2 = mult_out_2 + 16'h0101;
                @(posedge clk);
                if (done) begin
                    $display("Mode %0d complete at t=%0t", mode, $time);
                    $display("Product_1 = %h, Product_2 = %h", product_1, product_2);
                    
                end
            end
        end
    endtask

    // Stimulus
    initial begin
        // Init
        rst = 1;
        start = 0;
        mode_32bit = 0;
        mult_out_1 = 0;
        mult_out_2 = 0;
        #20 rst = 0;

        // Run 16-bit mode
        $display("\n--- Running 16-bit mode ---");
        run_mode(0);

        // Run 32-bit mode
        #20;
        $display("\n--- Running 32-bit mode ---");
        run_mode(1);

        #50 $finish;
    end

    // Monitor
    initial begin
        $monitor("t=%0t | state: mode=%b start=%b done=%b | P1=%h P2=%h",
                  $time, mode_32bit, start, done, product_1, product_2);
    end

endmodule
