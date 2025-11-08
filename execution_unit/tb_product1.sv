`timescale 1ns/1ps

module tb_product1;

    // Testbench signals
    logic [7:0] A, B;
    logic [15:0] product_dut; // from DUT
    logic [15:0] expected;    // calculated in TB

    // Instantiate DUT
    product1 dut (
        .mult1_A(A),
        .mult1_B(B),
        .mult_out_1(product_dut)
    );

    // Task for checking results
    task check_result;
        input [7:0] a_val, b_val;
        begin
            A = a_val;
            B = b_val;
            #1; // small delay to settle signals
            expected = a_val * b_val;

            if (product_dut !== expected) begin
                $display("❌ FAIL: A=%0d (0x%0h), B=%0d (0x%0h) => DUT=%0d (0x%0h), Expected=%0d (0x%0h)",
                         a_val, a_val, b_val, b_val,
                         product_dut, product_dut, expected, expected);
            end else begin
                $display("✅ PASS: A=%0d (0x%0h), B=%0d (0x%0h) => Product=%0d (0x%0h)",
                         a_val, a_val, b_val, b_val,
                         product_dut, product_dut);
            end
        end
    endtask

    // Main test procedure
    initial begin
        $display("==== Starting product1 Testbench ====");

        // Directed tests
        check_result(8'd0,   8'd0);   // 0 × 0
        check_result(8'd0,   8'd255); // 0 × max
        check_result(8'd1,   8'd1);   // 1 × 1
        check_result(8'd1,   8'd200); // 1 × value
        check_result(8'd255, 8'd255); // max × max
        check_result(8'd128, 8'd2);   // power of two
        check_result(8'd100, 8'd50);  // mid value

        // Random tests
        repeat (10) begin
            check_result($urandom_range(0,255), $urandom_range(0,255));
        end

        $display("==== Testbench completed ====");
        $finish;
    end

endmodule
