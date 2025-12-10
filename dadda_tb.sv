`timescale 1ns/1ps

// Self-checking test bench for 8x8 Dadda multiplier
module dadda_8TB();
    parameter M = 8, N = 8;
    
    // Inputs
    logic signed [N-1:0] mult1_A;
    logic signed [M-1:0] mult1_B;
    
    // Output
    logic signed [N+M-1:0] mult_out_1;
    
    // Expected result
    logic signed [N+M-1:0] expected;
    
    // Test counter
    integer test_num;
    integer pass_count, fail_count;
    
    // Instantiation of main test module
    dadda_8 UUT (
        .A(mult1_A),
        .B(mult1_B),
        .y(mult_out_1)
    );
    
    // Task to check result
    task check_result(input string test_name, input logic signed [15:0] expected_val);
        begin
            #1; // Small delay for output to stabilize
            if (mult_out_1 === expected_val) begin
                $display("PASS Test %0d: %s | %0d × %0d = %0d ✓", 
                         test_num, test_name, mult1_A, mult1_B, mult_out_1);
                pass_count++;
            end else begin
                $display("FAIL Test %0d: %s | %0d × %0d = %0d (expected %0d) ✗", 
                         test_num, test_name, mult1_A, mult1_B, mult_out_1, expected_val);
                fail_count++;
            end
            test_num++;
        end
    endtask
    
    // Stimulus and self-checking
    initial begin
        test_num = 1;
        pass_count = 0;
        fail_count = 0;
        
        $display("\n========== Dadda Multiplier Self-Checking Tests ==========\n");
        
        // Positive × Positive
        #10 mult1_A = 8'sd4;    mult1_B = 8'sd3;    check_result("Positive × Positive", 16'sd12);
        
        // Positive × Negative
        #10 mult1_A = 8'sd4;    mult1_B = -8'sd3;   check_result("Positive × Negative", -16'sd12);
        
        // Negative × Positive
        #10 mult1_A = -8'sd4;   mult1_B = 8'sd3;    check_result("Negative × Positive", -16'sd12);
        
        // Negative × Negative
        #10 mult1_A = -8'sd4;   mult1_B = -8'sd3;   check_result("Negative × Negative", 16'sd12);
        
        // Edge case: max negative × 2
        #10 mult1_A = -8'sd128; mult1_B = 8'sd2;    check_result("Min × 2", -16'sd256);
        
        // Edge case: -128 × -128 (overflow scenario)
        #10 mult1_A = -8'sd128; mult1_B = -8'sd128; check_result("Min × Min", 16'sd16384);
        
        // Edge case: max positive × max positive
        #10 mult1_A = 8'sd127;  mult1_B = 8'sd127;  check_result("Max × Max", 16'sd16129);
        
        // Edge case: max positive × min negative
        #10 mult1_A = 8'sd127;  mult1_B = -8'sd128; check_result("Max × Min", -16'sd16256);
        
        // Small number × 0
        #10 mult1_A = 8'sd45;   mult1_B = 8'sd0;    check_result("Positive × Zero", 16'sd0);
        
        // Zero × Negative
        #10 mult1_A = 8'sd0;    mult1_B = -8'sd100; check_result("Zero × Negative", 16'sd0);
        
        // Random mid-range: 25 × -10
        #10 mult1_A = 8'sd25;   mult1_B = -8'sd10;  check_result("25 × -10", -16'sd250);
        
        // Random mid-range: -50 × -20
        #10 mult1_A = -8'sd50;  mult1_B = -8'sd20;  check_result("-50 × -20", 16'sd1000);
        
        // Random: -7 × 15
        #10 mult1_A = -8'sd7;   mult1_B = 8'sd15;   check_result("-7 × 15", -16'sd105);
        
        // Edge: 1 × -128
        #10 mult1_A = 8'sd1;    mult1_B = -8'sd128; check_result("1 × Min", -16'sd128);
        
        // Edge: -1 × 127
        #10 mult1_A = -8'sd1;   mult1_B = 8'sd127;  check_result("-1 × Max", -16'sd127);
        
        // Edge: -1 × -128
        #10 mult1_A = -8'sd1;   mult1_B = -8'sd128; check_result("-1 × Min", 16'sd128);
        
        // Additional edge cases
        #10 mult1_A = 8'sd127;  mult1_B = 8'sd126;  check_result("127 × 126", 16'sd16002);
        
        #10 mult1_A = -8'sd127;     mult1_B = -8'sd127; check_result("-127 × -127", 16'sd16129);
        
        #10 mult1_A = 8'sd100;  mult1_B = -8'sd100; check_result("100 × -100", -16'sd10000);

        // Edge: -1 × 127
        #10 mult1_A = -8'sd126;     mult1_B = 8'sd126;  check_result("-126 × -126", -16'sd15876);
        
        // Edge: -1 × -128
        #10 mult1_A = 8'sd126;    mult1_B = 8'sd126;    check_result("126 × 126", 16'sd15876);
        
        // Additional edge cases
        #10 mult1_A = 8'sd125;    mult1_B = 8'sd125;    check_result("125 × 125", 16'sd15625);
        
        #10 mult1_A = -8'sd125;   mult1_B = -8'sd125;   check_result("-125 × -125", 16'sd15625);
        
        #10 mult1_A = 8'sd88;     mult1_B = -8'sd88;    check_result("88 × -88", -16'sd7744);

                // -------------------------------------------------------
        // Additional directed edge/boundary tests
        // -------------------------------------------------------
        #10 mult1_A = 8'sd2;   mult1_B = 8'sd2;     check_result("2 × 2", 16'sd4);
        #10 mult1_A = 8'sd2;   mult1_B = -8'sd2;    check_result("2 × -2", -16'sd4);
        #10 mult1_A = -8'sd2;  mult1_B = -8'sd2;    check_result("-2 × -2", 16'sd4);
        #10 mult1_A = 8'sd8;   mult1_B = 8'sd8;     check_result("8 × 8", 16'sd64);
        #10 mult1_A = -8'sd8;  mult1_B = 8'sd8;     check_result("-8 × 8", -16'sd64);
        #10 mult1_A = -8'sd8;  mult1_B = -8'sd8;    check_result("-8 × -8", 16'sd64);
        #10 mult1_A = 8'sd16;  mult1_B = 8'sd4;     check_result("16 × 4", 16'sd64);
        #10 mult1_A = -8'sd16; mult1_B = 8'sd4;     check_result("-16 × 4", -16'sd64);
        #10 mult1_A = 8'sd32;  mult1_B = 8'sd2;     check_result("32 × 2", 16'sd64);
        #10 mult1_A = 8'sd64;  mult1_B = 8'sd2;     check_result("64 × 2", 16'sd128);
        #10 mult1_A = -8'sd64; mult1_B = 8'sd2;     check_result("-64 × 2", -16'sd128);
        #10 mult1_A = 8'sd64;  mult1_B = -8'sd1;    check_result("64 × -1", -16'sd64);
        #10 mult1_A = -8'sd64; mult1_B = -8'sd1;    check_result("-64 × -1", 16'sd64);

        // -------------------------------------------------------
        // Special prime/random values
        // -------------------------------------------------------
        #10 mult1_A = 8'sd13;  mult1_B = 8'sd7;     check_result("13 × 7", 16'sd91);
        #10 mult1_A = -8'sd13; mult1_B = 8'sd7;     check_result("-13 × 7", -16'sd91);
        #10 mult1_A = 8'sd23;  mult1_B = -8'sd11;   check_result("23 × -11", -16'sd253);
        #10 mult1_A = -8'sd23; mult1_B = -8'sd11;   check_result("-23 × -11", 16'sd253);
        #10 mult1_A = 8'sd37;  mult1_B = 8'sd5;     check_result("37 × 5", 16'sd185);
        #10 mult1_A = -8'sd37; mult1_B = 8'sd5;     check_result("-37 × 5", -16'sd185);

        
        // -------------------------------------------------------
        // Stress tests with powers of two
        // -------------------------------------------------------
        #10 mult1_A = 8'sd1;    mult1_B = 8'sd64;   check_result("1 × 64", 16'sd64);
        #10 mult1_A = -8'sd1;   mult1_B = 8'sd64;   check_result("-1 × 64", -16'sd64);
        #10 mult1_A = 8'sd2;    mult1_B = 8'sd32;   check_result("2 × 32", 16'sd64);
        #10 mult1_A = -8'sd2;   mult1_B = -8'sd32;  check_result("-2 × -32", 16'sd64);
        #10 mult1_A = 8'sd4;    mult1_B = 8'sd16;   check_result("4 × 16", 16'sd64);
        #10 mult1_A = 8'sd8;    mult1_B = 8'sd8;    check_result("8 × 8", 16'sd64);

        // -------------------------------------------------------
        // Additional negatives and mixed
        // -------------------------------------------------------
        #10 mult1_A = -8'sd100; mult1_B = 8'sd50;   check_result("-100 × 50", -16'sd5000);
        #10 mult1_A = 8'sd50;   mult1_B = -8'sd100; check_result("50 × -100", -16'sd5000);
        #10 mult1_A = -8'sd90;  mult1_B = -8'sd90;  check_result("-90 × -90", 16'sd8100);
        #10 mult1_A = 8'sd77;   mult1_B = -8'sd66;  check_result("77 × -66", -16'sd5082);
        #10 mult1_A = -8'sd77;  mult1_B = -8'sd66;  check_result("-77 × -66", 16'sd5082);

        // -------------------------------------------------------
        // Randomized deterministic tests (reproducible)
        // -------------------------------------------------------
        repeat (46) begin
            #10;
            mult1_A = $random % 128;  // range -127..127
            mult1_B = $random % 128;
            expected = mult1_A * mult1_B;
            check_result($sformatf("Random %0d × %0d", mult1_A, mult1_B), expected);
        end

        
        // Summary
        #10
        $display("\n========== Test Summary ==========");
        $display("Total Tests: %0d", test_num - 1);
        $display("Passed: %0d", pass_count);
        $display("Failed: %0d", fail_count);
        if (fail_count == 0)
            $display("All tests PASSED! ✓✓✓\n");
        else
            $display("Some tests FAILED! ✗✗✗\n");
        
        $finish;
    end
    
endmodule