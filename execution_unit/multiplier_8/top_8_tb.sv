module tb_top;

    // Testbench signals
    logic clk;
    logic reset;
    logic [1:0] sew;
    logic count_0;
    logic start;
    logic [31:0] data_in_A1;
    logic [31:0] data_in_B1;
    logic [31:0] data_in_A2;
    logic [31:0] data_in_B2;
    logic [31:0] product_1;
    logic [31:0] product_2;
    logic [31:0] product_3;
    logic [31:0] product_4;

    // Instantiate DUT
    top dut (
        .clk(clk),
        .reset(reset),
        .sew(sew),
        .count_0(count_0),
        .start(start),
        .data_in_A1(data_in_A1),
        .data_in_B1(data_in_B1),
        .data_in_A2(data_in_A2),
        .data_in_B2(data_in_B2),
        .product_1(product_1),
        .product_2(product_2),
        .product_3(product_3),
        .product_4(product_4)
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
        count_0 = 0;
        data_in_A1 = 0;
        data_in_B1 = 0;
        data_in_A2 = 0;
        data_in_B2 = 0;
        #10;
        
        // Release reset
        reset = 0;
        #5;

        /*// Test 1: 16-bit mode (two 16x16 multiplications)
        start = 1;
        data_in_A1 = 32'h670432F8; // A_low=0x0008, A_high=0x0004
        data_in_B1 = 32'h1692ABC3; // B_low=0x0003, B_high=0x0002
        data_in_A2 = 32'h4564DEF8; // A_low=0x0008, A_high=0x0004
        data_in_B2 = 32'hCDA26783; // B_low=0x0003, B_high=0x0002
        sew = 2'b00;  // Example sew
        count_0 = 1'b0;
        #30;

        // Display results
        $display("Test1 -> A1=%h, B1=%h, A2=%h, B2=%h, Product1=%h, Product2=%h",
                  data_in_A1, data_in_B1, data_in_A2, data_in_B2, product_1, product_2);
*/
        // Test 2: 16-bit mode (two 16x16 multiplications)
        start = 1;
        data_in_A1 = 32'h670432F8; // A_low=0x0008, A_high=0x0004
        data_in_B1 = 32'h1692ABC3; // B_low=0x0003, B_high=0x0002
        data_in_A2 = 32'h4564DEF8; // A_low=0x0008, A_high=0x0004
        data_in_B2 = 32'hCDA26783; // B_low=0x0003, B_high=0x0002
        sew = 2'b01;  // Example sew
        count_0 = 1'b0;
        #30;

        // Display results
        $display("Test1 -> A1=%h, B1=%h, A2=%h, B2=%h, Product1=%h, Product2=%h",
                  data_in_A1, data_in_B1, data_in_A2, data_in_B2, product_1, product_2);

        // Test 3: 32-bit mode (single 32x32 multiply using chunks)
        data_in_A1 = 32'h1267_ABEF;
        data_in_B1 = 32'h3790_DAC2;
        data_in_A2 = 32'h5678_DEFF;
        data_in_B2 = 32'hABCD_2342;
        sew = 2'b10;
        count_0 = 0;
        #30;
        count_0 = 1;
        #30;


        $display("Test2 -> A1=%h, B1=%h, A2=%h, B2=%h, Product1=%h, Product2=%h",
                  data_in_A1, data_in_B1, data_in_A2, data_in_B2, product_1, product_2);

      /*// Test 3: Randomized values
        repeat (10) begin
            @(posedge clk);
            data_in_A1 = $urandom;
            data_in_B1 = $urandom;
            data_in_A2 = $urandom;
            data_in_B2 = $urandom;
            sew        = $urandom_range(0,2);

            if (sew == 2) begin
                count_0 = 1;
            end else begin
                count_0 = 0;
            end
            
            start = 1;
            #20;
            $display("Random Test -> A1=%h, B1=%h, A2=%h, B2=%h, sew=%b Product1=%h Product2=%h",
                      data_in_A1, data_in_B1, data_in_A2, data_in_B2,  sew, product_1, product_2);
        end 
*/
        // Finish
        #20;
        $finish;
    end

endmodule
