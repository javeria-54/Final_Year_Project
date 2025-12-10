module tb_top;

    // Testbench signals
    logic clk;
    logic reset;
    logic [1:0] sew;
    logic count_0;
    logic start;
    logic [31:0] data_in_A;
    logic [31:0] data_in_B;
    logic [31:0] product_1;
    logic [31:0] product_2;
    logic [63:0] product;

    // Instantiate DUT
    top dut (
        .clk(clk),
        .reset(reset),
        .sew(sew),
        .count_0(count_0),
        .start(start),
        .data_in_A(data_in_A),
        .data_in_B(data_in_B),
        .product_1(product_1),
        .product_2(product_2),
        .product(product)
    );

    // Clock generation (10ns period)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Stimulus
    initial begin
        // Initialize
        reset = 1;
        start = 0;
        sew = 2'b00;
        data_in_A = 0;
        data_in_B = 0;
        #10;
        
        // Release reset
        reset = 0;
        #5;

        // Test 2: 16-bit mode (two 16x16 multiplications)
        start = 1;
        data_in_A = 32'hFFFFFFFF; // A_low=0x0008, A_high=0x0004
        data_in_B = 32'hFFFFFFFF; // B_low=0x0003, B_high=0x0002
        sew = 2'b01;  // Example sew
        #30;

        // Display results
        $display("Test1 -> A1=%h, B1=%h, Product1=%h, Product2=%h",
                  data_in_A, data_in_B, product_1, product_2);

        // Finish
        #20;
        $finish;
    end

endmodule
