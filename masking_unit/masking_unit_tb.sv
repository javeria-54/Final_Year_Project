//////////////////////////////////////////////////////////////////////////////////
// Testbench: tb_vector_mask_unit
//
// Tests:
//   1. No masking (mask_en=0) - bypass test
//   2. SEW=8,  body active elements with mask_reg[i]=1
//   3. SEW=8,  inactive body elements with vma=0 (undisturbed)
//   4. SEW=8,  inactive body elements with vma=1 (agnostic → all 1s)
//   5. SEW=8,  tail elements with vta=0 (undisturbed)
//   6. SEW=8,  tail elements with vta=1 (agnostic → all 1s)
//   7. SEW=16, basic mask test
//   8. SEW=32, basic mask test
//   9. SEW=64, basic mask test
//  10. Prestart elements test
//  11. mask_reg_en=1: mask register update via vmand
//  12. mask_reg_en=1: mask register update via vmor
//////////////////////////////////////////////////////////////////////////////////

`timescale 1ns/1ps
`define VLEN 512

module tb_vector_mask_unit;

    // ----------------------------------------------------------------
    // DUT Signals
    // ----------------------------------------------------------------
    logic [4095:0] lanes_data_out;
    logic [4095:0] destination_data;
    logic [2:0]    mask_op;
    logic          mask_en;
    logic          mask_reg_en;
    logic          vta;
    logic          vma;
    logic [31:0]   vstart;
    logic [31:0]   vl;
    logic [6:0]    sew;
    logic [511:0]  vs1;
    logic [511:0]  vs2;
    logic [511:0]  v0;
    logic [1:0]    sew_sel;
    logic [63:0]   carry_out;

    logic [4095:0] mask_unit_output;
    logic [511:0]  mask_reg_updated;

    // ----------------------------------------------------------------
    // Test tracking
    // ----------------------------------------------------------------
    int test_num  = 0;
    int pass_cnt  = 0;
    int fail_cnt  = 0;

    // ----------------------------------------------------------------
    // DUT Instantiation
    // ----------------------------------------------------------------
    vector_mask_unit DUT (
        .lanes_data_out  (lanes_data_out),
        .destination_data(destination_data),
        .mask_op         (mask_op),
        .mask_en         (mask_en),
        .mask_reg_en     (mask_reg_en),
        .vta             (vta),
        .vma             (vma),
        .vstart          (vstart),
        .vl              (vl),
        .sew             (sew),
        .vs1             (vs1),
        .vs2             (vs2),
        .v0              (v0),
        .sew_sel         (sew_sel),
        .carry_out       (carry_out),
        .mask_unit_output(mask_unit_output),
        .mask_reg_updated(mask_reg_updated)
    );

    // ----------------------------------------------------------------
    // Task: check_result
    // ----------------------------------------------------------------
    task automatic check_result(
        input string       test_name,
        input logic [4095:0] got,
        input logic [4095:0] expected
    );
        test_num++;
        #1; // let combinational logic settle
        if (got === expected) begin
            $display("[PASS] Test %0d: %s", test_num, test_name);
            pass_cnt++;
        end else begin
            $display("[FAIL] Test %0d: %s", test_num, test_name);
            $display("       Expected: 0x%0h", expected);
            $display("       Got     : 0x%0h", got);
            fail_cnt++;
        end
    endtask

    // ----------------------------------------------------------------
    // Task: check_mask_reg
    // ----------------------------------------------------------------
    task automatic check_mask_reg(
        input string      test_name,
        input logic [511:0] got,
        input logic [511:0] expected
    );
        test_num++;
        #1;
        if (got === expected) begin
            $display("[PASS] Test %0d: %s", test_num, test_name);
            pass_cnt++;
        end else begin
            $display("[FAIL] Test %0d: %s", test_num, test_name);
            $display("       Expected: 0x%0h", expected);
            $display("       Got     : 0x%0h", got);
            fail_cnt++;
        end
    endtask

    // ----------------------------------------------------------------
    // Helper: reset all inputs to safe defaults
    // ----------------------------------------------------------------
    task automatic reset_inputs();
        lanes_data_out   = '0;
        destination_data = '0;
        mask_op          = 3'b000;
        mask_en          = 1'b0;
        mask_reg_en      = 1'b0;
        vta              = 1'b0;
        vma              = 1'b0;
        vstart           = 32'd0;
        vl               = 32'd0;
        sew              = 7'b0000100; // SEW=8 default
        vs1              = '0;
        vs2              = '0;
        v0               = '0;
    endtask

    // ----------------------------------------------------------------
    // MAIN TEST
    // ----------------------------------------------------------------
    initial begin
        $display("====================================================");
        $display("   vector_mask_unit Testbench Starting");
        $display("====================================================\n");

        reset_inputs();
        #10;

        // ============================================================
        // TEST 1: mask_en=0 → bypass, output = lanes_data_out directly
        // ============================================================
        $display("--- Group 1: Bypass (mask_en=0) ---");
        lanes_data_out   = 4096'hDEADBEEF_CAFEBABE;
        destination_data = 4096'hAAAAAAAA_AAAAAAAA;
        mask_en          = 1'b0;
        sew              = 7'b0000100; // SEW=8
        vl               = 32'd4;
        vstart           = 32'd0;
        v0               = 512'hFF;
        #5;
        check_result("mask_en=0 bypass", mask_unit_output, lanes_data_out);

        // ============================================================
        // TEST 2: SEW=8, mask_en=1, active body elements (mask_reg[i]=1)
        //         vstart=0, vl=4 → elements 0,1,2,3 are body
        //         v0[3:0]=4'b1111 → all active → output = lanes_data_out
        // ============================================================
        $display("\n--- Group 2: SEW=8 Active Body Elements ---");
        reset_inputs();
        sew              = 7'b0000100; // SEW=8
        mask_en          = 1'b1;
        mask_reg_en      = 1'b0;
        vstart           = 32'd0;
        vl               = 32'd4;
        vta              = 1'b0;
        vma              = 1'b0;
        v0               = 512'hF;           // bits [3:0] = 1 → elements 0-3 active
        // Element 0 = 8'hAA, Element 1 = 8'hBB, Element 2 = 8'hCC, Element 3 = 8'hDD
        lanes_data_out   = {4088'h0, 8'hDD, 8'hCC, 8'hBB, 8'hAA};
        destination_data = {4096{1'b1}};     // All 1s (should NOT appear for active)
        #5;
        // Expected: elements 0-3 from lanes, rest from destination (all 1s)
        begin
            logic [4095:0] exp;
            exp = destination_data;
            exp[0*8 +: 8] = 8'hAA;
            exp[1*8 +: 8] = 8'hBB;
            exp[2*8 +: 8] = 8'hCC;
            exp[3*8 +: 8] = 8'hDD;
            check_result("SEW=8 body active (mask=1111)", mask_unit_output, exp);
        end

        // ============================================================
        // TEST 3: SEW=8, inactive body (mask_reg[i]=0), vma=0 (undisturbed)
        //         vstart=0, vl=4, v0[3:0]=4'b0000 → all inactive body
        //         Output should be destination_data for elements 0-3
        // ============================================================
        $display("\n--- Group 3: SEW=8 Inactive Body vma=0 (undisturbed) ---");
        reset_inputs();
        sew              = 7'b0000100;
        mask_en          = 1'b1;
        mask_reg_en      = 1'b0;
        vstart           = 32'd0;
        vl               = 32'd4;
        vta              = 1'b0;
        vma              = 1'b0;             // undisturbed
        v0               = 512'h0;           // all mask bits = 0 → all inactive
        lanes_data_out   = {4096{1'b1}};     // All 1s (should NOT appear)
        destination_data = {4088'h0, 8'h11, 8'h22, 8'h33, 8'h44};
        #5;
        begin
            logic [4095:0] exp;
            exp = destination_data; // tail elements also undisturbed (vta=0)
            check_result("SEW=8 body inactive vma=0", mask_unit_output, exp);
        end

        // ============================================================
        // TEST 4: SEW=8, inactive body (mask_reg[i]=0), vma=1 (agnostic)
        //         Elements 0-3 body, all inactive → should get 8'hFF each
        // ============================================================
        $display("\n--- Group 4: SEW=8 Inactive Body vma=1 (agnostic=all 1s) ---");
        reset_inputs();
        sew              = 7'b0000100;
        mask_en          = 1'b1;
        mask_reg_en      = 1'b0;
        vstart           = 32'd0;
        vl               = 32'd4;
        vta              = 1'b0;
        vma              = 1'b1;             // agnostic → write all 1s
        v0               = 512'h0;           // all mask bits = 0
        lanes_data_out   = '0;
        destination_data = '0;
        #5;
        begin
            logic [4095:0] exp;
            exp = '0;
            exp[0*8 +: 8] = 8'hFF;
            exp[1*8 +: 8] = 8'hFF;
            exp[2*8 +: 8] = 8'hFF;
            exp[3*8 +: 8] = 8'hFF;
            check_result("SEW=8 body inactive vma=1", mask_unit_output, exp);
        end

        // ============================================================
        // TEST 5: SEW=8, tail elements vta=0 (undisturbed)
        //         vl=2 → elements 2+ are tail, should keep destination
        // ============================================================
        $display("\n--- Group 5: SEW=8 Tail vta=0 (undisturbed) ---");
        reset_inputs();
        sew              = 7'b0000100;
        mask_en          = 1'b1;
        mask_reg_en      = 1'b0;
        vstart           = 32'd0;
        vl               = 32'd2;            // only 2 active elements
        vta              = 1'b0;             // undisturbed tail
        vma              = 1'b0;
        v0               = 512'hFF;          // elements 0,1 active
        lanes_data_out   = {4088'h0, 8'hBB, 8'hAA};
        destination_data = {4088'h0, 8'hDD, 8'hCC, 8'hBB, 8'hAA};
        #5;
        begin
            logic [4095:0] exp;
            exp = destination_data;          // tail = destination (undisturbed)
            exp[0*8 +: 8] = 8'hAA;          // body element 0
            exp[1*8 +: 8] = 8'hBB;          // body element 1
            check_result("SEW=8 tail vta=0", mask_unit_output, exp);
        end

        // ============================================================
        // TEST 6: SEW=8, tail elements vta=1 (agnostic → all 1s)
        //         vl=2 → elements 2+ should get 8'hFF
        // ============================================================
        $display("\n--- Group 6: SEW=8 Tail vta=1 (agnostic=all 1s) ---");
        reset_inputs();
        sew              = 7'b0000100;
        mask_en          = 1'b1;
        mask_reg_en      = 1'b0;
        vstart           = 32'd0;
        vl               = 32'd2;
        vta              = 1'b1;             // agnostic → tail = all 1s
        vma              = 1'b0;
        v0               = 512'hFF;
        lanes_data_out   = {4088'h0, 8'hBB, 8'hAA};
        destination_data = '0;
        #5;
        begin
            logic [4095:0] exp;
            exp = {4096{1'b1}};              // all tail → all 1s
            exp[0*8 +: 8] = 8'hAA;          // body element 0
            exp[1*8 +: 8] = 8'hBB;          // body element 1
            check_result("SEW=8 tail vta=1", mask_unit_output, exp);
        end

        // ============================================================
        // TEST 7: Prestart elements
        //         vstart=2 → elements 0,1 are prestart → keep destination
        // ============================================================
        $display("\n--- Group 7: Prestart Elements ---");
        reset_inputs();
        sew              = 7'b0000100;
        mask_en          = 1'b1;
        mask_reg_en      = 1'b0;
        vstart           = 32'd2;            // elements 0,1 = prestart
        vl               = 32'd5;
        vta              = 1'b0;
        vma              = 1'b0;
        v0               = 512'hFF;
        lanes_data_out   = {4085'h0, 8'hEE, 8'hDD, 8'hCC, 8'hBB, 8'hAA};
        destination_data = {4090'h0, 8'h11, 8'h22, 8'h33, 8'h44, 8'h55};
        #5;
        begin
            logic [4095:0] exp;
            exp = destination_data;
            // prestart: elements 0,1 → destination
            // body: elements 2,3,4 → lanes
            exp[2*8 +: 8] = lanes_data_out[2*8 +: 8];
            exp[3*8 +: 8] = lanes_data_out[3*8 +: 8];
            exp[4*8 +: 8] = lanes_data_out[4*8 +: 8];
            check_result("Prestart elements preserved", mask_unit_output, exp);
        end

        // ============================================================
        // TEST 8: SEW=16 basic test
        //         vstart=0, vl=2, v0[1:0]=2'b11 → elements 0,1 active
        // ============================================================
        $display("\n--- Group 8: SEW=16 ---");
        reset_inputs();
        sew              = 7'b0001000;       // SEW=16
        mask_en          = 1'b1;
        mask_reg_en      = 1'b0;
        vstart           = 32'd0;
        vl               = 32'd2;
        vta              = 1'b0;
        vma              = 1'b0;
        v0               = 512'h3;           // bits [1:0]=11
        lanes_data_out   = {4064'h0, 16'hBBBB, 16'hAAAA};
        destination_data = {4064'h0, 16'hDDDD, 16'hCCCC};
        #5;
        begin
            logic [4095:0] exp;
            exp = destination_data;
            exp[0*16 +: 16] = 16'hAAAA;
            exp[1*16 +: 16] = 16'hBBBB;
            check_result("SEW=16 body active", mask_unit_output, exp);
        end

        // ============================================================
        // TEST 9: SEW=32 basic test
        // ============================================================
        $display("\n--- Group 9: SEW=32 ---");
        reset_inputs();
        sew              = 7'b0010000;       // SEW=32
        mask_en          = 1'b1;
        mask_reg_en      = 1'b0;
        vstart           = 32'd0;
        vl               = 32'd2;
        vta              = 1'b0;
        vma              = 1'b0;
        v0               = 512'h3;
        lanes_data_out   = {4032'h0, 32'hBBBBBBBB, 32'hAAAAAAAA};
        destination_data = {4032'h0, 32'hDDDDDDDD, 32'hCCCCCCCC};
        #5;
        begin
            logic [4095:0] exp;
            exp = destination_data;
            exp[0*32 +: 32] = 32'hAAAAAAAA;
            exp[1*32 +: 32] = 32'hBBBBBBBB;
            check_result("SEW=32 body active", mask_unit_output, exp);
        end

        // ============================================================
        // TEST 10: SEW=64 basic test
        // ============================================================
        $display("\n--- Group 10: SEW=64 ---");
        reset_inputs();
        sew              = 7'b0100000;       // SEW=64
        mask_en          = 1'b1;
        mask_reg_en      = 1'b0;
        vstart           = 32'd0;
        vl               = 32'd2;
        vta              = 1'b0;
        vma              = 1'b0;
        v0               = 512'h3;
        lanes_data_out   = {3968'h0, 64'hBBBBBBBB_BBBBBBBB, 64'hAAAAAAAA_AAAAAAAA};
        destination_data = {3968'h0, 64'hDDDDDDDD_DDDDDDDD, 64'hCCCCCCCC_CCCCCCCC};
        #5;
        begin
            logic [4095:0] exp;
            exp = destination_data;
            exp[0*64 +: 64] = 64'hAAAAAAAA_AAAAAAAA;
            exp[1*64 +: 64] = 64'hBBBBBBBB_BBBBBBBB;
            check_result("SEW=64 body active", mask_unit_output, exp);
        end

        // ============================================================
        // TEST 11: mask_reg_en=1, vmand (mask_op=000)
        //          vs1 & vs2 → mask_reg_updated
        // ============================================================
        $display("\n--- Group 11: Mask Register Update (vmand) ---");
        reset_inputs();
        sew         = 7'b0000100;
        mask_en     = 1'b0;
        mask_reg_en = 1'b1;
        mask_op     = 3'b000;               // vmand
        vs1         = 512'hF0F0;
        vs2         = 512'hFF00;
        #5;
        check_mask_reg("vmand vs1=0xF0F0 vs2=0xFF00", mask_reg_updated, 512'hF000);

        // ============================================================
        // TEST 12: vmor (mask_op=100)
        // ============================================================
        $display("\n--- Group 12: Mask Register Update (vmor) ---");
        reset_inputs();
        sew         = 7'b0000100;
        mask_en     = 1'b0;
        mask_reg_en = 1'b1;
        mask_op     = 3'b100;               // vmor
        vs1         = 512'hF0F0;
        vs2         = 512'hFF00;
        #5;
        check_mask_reg("vmor vs1=0xF0F0 vs2=0xFF00", mask_reg_updated, 512'hFFF0);

        // ============================================================
        // TEST 13: vmxor (mask_op=011)
        // ============================================================
        $display("\n--- Group 13: Mask Register Update (vmxor) ---");
        reset_inputs();
        sew         = 7'b0000100;
        mask_en     = 1'b0;
        mask_reg_en = 1'b1;
        mask_op     = 3'b011;               // vmxor
        vs1         = 512'hFF00;
        vs2         = 512'hFF00;
        #5;
        check_mask_reg("vmxor vs1==vs2 → 0", mask_reg_updated, 512'h0);

        // ============================================================
        // TEST 14: Mixed body — some active, some inactive, vma=1
        //          v0[3:0]=4'b1010 → elements 1,3 active; 0,2 inactive
        // ============================================================
        $display("\n--- Group 14: Mixed Body (partial mask) ---");
        reset_inputs();
        sew              = 7'b0000100;
        mask_en          = 1'b1;
        mask_reg_en      = 1'b0;
        vstart           = 32'd0;
        vl               = 32'd4;
        vta              = 1'b0;
        vma              = 1'b1;            // agnostic → inactive body = all 1s
        v0               = 512'hA;          // 4'b1010 → elem 1,3 active
        lanes_data_out   = {4088'h0, 8'hD3, 8'hC2, 8'hB1, 8'hA0};
        destination_data = '0;
        #5;
        begin
            logic [4095:0] exp;
            exp = '0;
            exp[0*8 +: 8] = 8'hFF; // inactive + vma=1 → all 1s
            exp[1*8 +: 8] = 8'hB1; // active → lanes
            exp[2*8 +: 8] = 8'hFF; // inactive + vma=1 → all 1s
            exp[3*8 +: 8] = 8'hD3; // active → lanes
            check_result("Mixed body vma=1", mask_unit_output, exp);
        end

        // ============================================================
        // Summary
        // ============================================================
        #10;
        $display("\n====================================================");
        $display("   RESULTS: %0d Passed, %0d Failed (Total: %0d)",
                  pass_cnt, fail_cnt, test_num);
        if (fail_cnt == 0)
            $display("   *** ALL TESTS PASSED ✓ ***");
        else
            $display("   *** SOME TESTS FAILED ✗ ***");
        $display("====================================================\n");

        $finish;
    end

    // ----------------------------------------------------------------
    // Timeout watchdog
    // ----------------------------------------------------------------
    initial begin
        #500000;
        $display("[ERROR] Simulation timeout!");
        $finish;
    end

endmodule