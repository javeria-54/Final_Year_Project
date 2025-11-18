module tb_top;

    // Testbench signals
    logic clk;
    logic reset;
    logic [1:0] sew;
    logic count_0;
    logic start;
    logic [31:0] data_in_A1;
    logic [31:0] data_in_B1;
    //logic [31:0] data_in_A2;
    //logic [31:0] data_in_B2;
    logic [31:0] product_1;
    logic [31:0] product_2;
    logic [63:0] prduct;
    //logic [31:0] product_3;
    //logic [31:0] product_4;

    // Instantiate DUT
    top dut (
        .clk(clk),
        .reset(reset),
        .sew(sew),
        .count_0(count_0),
        .start(start),
        .data_in_A1(data_in_A1),
        .data_in_B1(data_in_B1),
        //.data_in_A2(data_in_A2),
        //.data_in_B2(data_in_B2),
        .product_1(product_1),
        .product_2(product_2),
        .product(product)
        //.product_3(product_3),
        //.product_4(product_4)
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
        sew = 2'b01;
        data_in_A1 = 0;
        data_in_B1 = 0;
        //data_in_A2 = 0;
        //data_in_B2 = 0;
        #10;
        
        // Release reset
        reset = 0;
        #5;

        // Test 2: 16-bit mode (two 16x16 multiplications)
        start = 1;
        //data_in_A2 = 32'h01234567; // A_low=0x0008, A_high=0x0004
        //data_in_B2 = 32'h89ABCDEF; // B_low=0x0003, B_high=0x0002
        data_in_A1 = 32'h01234567; // A_low=0x0008, A_high=0x0004
        data_in_B1 = 32'h89ABCDEF; // B_low=0x0003, B_high=0x0002
        sew = 2'b01;  // Example sew
        #30;

        // Display results
        $display("Test1 -> A1=%h, B1=%h, Product1=%h, Product2=%h",
                  data_in_A1, data_in_B1, product_1, product_2);

        // Finish
        #20;
        $finish;
    end

endmodule
