//////////////////////////////////////////////////////////////////////////////////
// Testbench: tb_vector_mask_unit
// DUT:       vector_mask_unit
// Engineer:  Testbench for Vector Mask Unit - Full Coverage
//
// Test Cases:
//   TC1:  mask_en=0  → output = lanes_data_out (passthrough)
//   TC2:  SEW=8,  basic body/mask passthrough
//   TC3:  SEW=16, body active, mask_reg selects elements
//   TC4:  SEW=32, tail agnostic (vta=1) → tail filled with 1s
//   TC5:  SEW=64, tail undisturbed (vta=0) → tail = destination
//   TC6:  vma=1  → masked-off body elements = all 1s
//   TC7:  vma=0  → masked-off body elements = destination
//   TC8:  prestart check → prestart elements = destination
//   TC9:  mask_reg_en=1 → v0 updated with mask_reg_updated
//   TC10: mask_reg_en=0 → v0 unchanged
//   TC11: mask_op AND  (4'b0000)
//   TC12: mask_op NAND (4'b0001)
//   TC13: mask_op ANDN (4'b0010)
//   TC14: mask_op XOR  (4'b0011)
//   TC15: mask_op OR   (4'b0100)
//   TC16: mask_op NOR  (4'b0101)
//   TC17: mask_op ORN  (4'b0110)
//   TC18: mask_op XNOR (4'b0111)
//   TC19: carry_out based mask update (mask_op=4'b1000, SEW=8)
//   TC20: carry_out based mask update (mask_op=4'b1000, SEW=16)
//   TC21: carry_out based mask update (mask_op=4'b1000, SEW=32)
//   TC22: vstart=4, vl=10, SEW=8 → prestart[0:3]=dest, body[4:9]=lanes, tail[10+]=dest/1s
//   TC23: vl=0 → all body_check=0, no active elements
//   TC24: Full 512-bit mask_reg all-ones
//   TC25: Full 512-bit mask_reg all-zeros
//////////////////////////////////////////////////////////////////////////////////

`include "vector_processor_defs.svh"
`include "vector_regfile_defs.svh"
`timescale 1ns/1ps

module tb_vector_mask_unit;

    // -------------------------------------------------------
    // DUT Ports
    // -------------------------------------------------------
    logic [4095:0] lanes_data_out;
    logic [4095:0] destination_data;
    logic [3:0]    mask_op;
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

    // -------------------------------------------------------
    // DUT Instantiation
    // -------------------------------------------------------
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

    // -------------------------------------------------------
    // Scoreboard counters
    // -------------------------------------------------------
    int pass_count = 0;
    int fail_count = 0;

    // -------------------------------------------------------
    // Helper Tasks
    // -------------------------------------------------------

    // Check a specific 8-bit slice of mask_unit_output
    task automatic check_byte(
        input int       element_idx,
        input logic [7:0] expected,
        input string    test_name
    );
        logic [7:0] actual;
        actual = mask_unit_output[element_idx*8 +: 8];
        if (actual === expected) begin
            $display("  [PASS] %s | elem[%0d] actual=0x%02h expected=0x%02h",
                      test_name, element_idx, actual, expected);
            pass_count++;
        end else begin
            $display("  [FAIL] %s | elem[%0d] actual=0x%02h expected=0x%02h",
                      test_name, element_idx, actual, expected);
            fail_count++;
        end
    endtask

    // Check a specific 16-bit slice
    task automatic check_half(
        input int        element_idx,
        input logic [15:0] expected,
        input string     test_name
    );
        logic [15:0] actual;
        actual = mask_unit_output[element_idx*16 +: 16];
        if (actual === expected) begin
            $display("  [PASS] %s | elem[%0d] actual=0x%04h expected=0x%04h",
                      test_name, element_idx, actual, expected);
            pass_count++;
        end else begin
            $display("  [FAIL] %s | elem[%0d] actual=0x%04h expected=0x%04h",
                      test_name, element_idx, actual, expected);
            fail_count++;
        end
    endtask

    // Check a specific 32-bit slice
    task automatic check_word(
        input int        element_idx,
        input logic [31:0] expected,
        input string     test_name
    );
        logic [31:0] actual;
        actual = mask_unit_output[element_idx*32 +: 32];
        if (actual === expected) begin
            $display("  [PASS] %s | elem[%0d] actual=0x%08h expected=0x%08h",
                      test_name, element_idx, actual, expected);
            pass_count++;
        end else begin
            $display("  [FAIL] %s | elem[%0d] actual=0x%08h expected=0x%08h",
                      test_name, element_idx, actual, expected);
            fail_count++;
        end
    endtask

    // Check mask_reg_updated bits
    task automatic check_mask_bits(
        input logic [511:0] expected,
        input string        test_name
    );
        if (mask_reg_updated === expected) begin
            $display("  [PASS] %s | mask_reg_updated correct", test_name);
            pass_count++;
        end else begin
            $display("  [FAIL] %s | mask_reg_updated", test_name);
            $display("         actual  [63:0]  = 0x%016h", mask_reg_updated[63:0]);
            $display("         expected[63:0]  = 0x%016h", expected[63:0]);
            fail_count++;
        end
    endtask

    // Generic full-output check
    task automatic check_full_output(
        input logic [4095:0] expected,
        input string         test_name
    );
        if (mask_unit_output === expected) begin
            $display("  [PASS] %s | full output correct", test_name);
            pass_count++;
        end else begin
            $display("  [FAIL] %s | full output mismatch", test_name);
            $display("         actual  [63:0]  = 0x%016h", mask_unit_output[63:0]);
            $display("         expected[63:0]  = 0x%016h", expected[63:0]);
            fail_count++;
        end
    endtask

    // -------------------------------------------------------
    // Initialize all inputs to safe defaults
    // -------------------------------------------------------
    task automatic init_defaults();
        lanes_data_out   = '0;
        destination_data = '0;
        mask_op          = 4'b0000;
        mask_en          = 1'b0;
        mask_reg_en      = 1'b0;
        vta              = 1'b0;
        vma              = 1'b0;
        vstart           = 32'd0;
        vl               = 32'd0;
        sew              = 7'b0000100;  // SEW=8
        vs1              = '0;
        vs2              = '0;
        v0               = '0;
        sew_sel          = 2'b00;
        carry_out        = '0;
    endtask

    // -------------------------------------------------------
    // MAIN TEST SEQUENCE
    // -------------------------------------------------------
    initial begin
        $display("========================================================");
        $display("   VECTOR MASK UNIT TESTBENCH - START");
        $display("========================================================");

        init_defaults();
        #10;

        // ====================================================
        // TC1: mask_en=0 → output must equal lanes_data_out
        // ====================================================
        $display("\n--- TC1: mask_en=0, output=lanes_data_out ---");
        begin
            lanes_data_out   = {512{8'hAB}};
            destination_data = {512{8'hCD}};
            mask_en          = 1'b0;
            sew              = 7'b0000100; // SEW=8
            vl               = 32'd4;
            vstart           = 32'd0;
            v0               = 512'hFFFF_FFFF_FFFF_FFFF;
            #10;
            // Expected: passthrough lanes_data_out regardless of mask
            check_full_output({512{8'hAB}}, "TC1_mask_en_0");
        end

        // ====================================================
        // TC2: SEW=8, mask_en=1, simple body check
        //      vstart=0, vl=4, v0=4'b1010 (elem1,3 active)
        //      lanes=0xAA, dest=0xBB
        //      elem0: body active, mask_reg[0]=0, vma=0 → dest=0xBB
        //      elem1: body active, mask_reg[1]=1       → lanes=0xAA
        //      elem2: body active, mask_reg[2]=0, vma=0 → dest=0xBB
        //      elem3: body active, mask_reg[3]=1       → lanes=0xAA
        // ====================================================
        $display("\n--- TC2: SEW=8, vl=4, v0=4'b1010, vma=0 ---");
        begin
            init_defaults();
            sew              = 7'b0000100; // SEW=8
            sew_sel          = 2'b00;
            mask_en          = 1'b1;
            vta              = 1'b0;
            vma              = 1'b0;
            vstart           = 32'd0;
            vl               = 32'd4;
            // v0[3:0] = 4'b1010 → elem1 & elem3 active
            v0               = {{508{1'b0}}, 4'b1010};
            mask_reg_en      = 1'b0;

            // Fill entire vector with pattern
            for (int i = 0; i < 512; i++)
                lanes_data_out[i*8 +: 8]    = 8'hAA;
            for (int i = 0; i < 512; i++)
                destination_data[i*8 +: 8]  = 8'hBB;
            #10;
            // elem0: mask=0, vma=0 → dest
            check_byte(0, 8'hBB, "TC2_elem0_masked_off");
            // elem1: mask=1 → lanes
            check_byte(1, 8'hAA, "TC2_elem1_active");
            // elem2: mask=0 → dest
            check_byte(2, 8'hBB, "TC2_elem2_masked_off");
            // elem3: mask=1 → lanes
            check_byte(3, 8'hAA, "TC2_elem3_active");
            // elem4+: tail, vta=0 → dest
            check_byte(4, 8'hBB, "TC2_elem4_tail_undisturbed");
        end

        // ====================================================
        // TC3: SEW=16, vl=3, v0=3'b101 (elem0,2 active)
        //      vma=0 → elem1 = dest
        //      vta=0 → tail = dest
        // ====================================================
        $display("\n--- TC3: SEW=16, vl=3, v0=3'b101, vma=0, vta=0 ---");
        begin
            init_defaults();
            sew              = 7'b0001000; // SEW=16
            sew_sel          = 2'b01;
            mask_en          = 1'b1;
            vta              = 1'b0;
            vma              = 1'b0;
            vstart           = 32'd0;
            vl               = 32'd3;
            v0               = {{509{1'b0}}, 3'b101};
            mask_reg_en      = 1'b0;

            for (int i = 0; i < 256; i++)
                lanes_data_out[i*16 +: 16]   = 16'hCAFE;
            for (int i = 0; i < 256; i++)
                destination_data[i*16 +: 16] = 16'hDEAD;
            #10;
            check_half(0, 16'hCAFE, "TC3_elem0_active");
            check_half(1, 16'hDEAD, "TC3_elem1_masked_off");
            check_half(2, 16'hCAFE, "TC3_elem2_active");
            check_half(3, 16'hDEAD, "TC3_elem3_tail_undisturbed");
        end

        // ====================================================
        // TC4: SEW=32, vta=1 → tail elements = 32'hFFFFFFFF
        //      vl=2, v0[1:0]=2'b11, all body active
        // ====================================================
        $display("\n--- TC4: SEW=32, vta=1, tail filled with 1s ---");
        begin
            init_defaults();
            sew              = 7'b0010000; // SEW=32
            sew_sel          = 2'b10;
            mask_en          = 1'b1;
            vta              = 1'b1;
            vma              = 1'b0;
            vstart           = 32'd0;
            vl               = 32'd2;
            v0               = {{510{1'b0}}, 2'b11};
            mask_reg_en      = 1'b0;

            for (int i = 0; i < 128; i++)
                lanes_data_out[i*32 +: 32]   = 32'hA5A5A5A5;
            for (int i = 0; i < 128; i++)
                destination_data[i*32 +: 32] = 32'h12345678;
            #10;
            check_word(0, 32'hA5A5A5A5, "TC4_elem0_body_active");
            check_word(1, 32'hA5A5A5A5, "TC4_elem1_body_active");
            check_word(2, 32'hFFFFFFFF, "TC4_elem2_tail_agnostic");
            check_word(3, 32'hFFFFFFFF, "TC4_elem3_tail_agnostic");
        end

        // ====================================================
        // TC5: SEW=32, vta=0 → tail = destination
        // ====================================================
        $display("\n--- TC5: SEW=32, vta=0, tail = destination ---");
        begin
            init_defaults();
            sew              = 7'b0010000;
            sew_sel          = 2'b10;
            mask_en          = 1'b1;
            vta              = 1'b0;
            vma              = 1'b0;
            vstart           = 32'd0;
            vl               = 32'd2;
            v0               = {{510{1'b0}}, 2'b11};
            mask_reg_en      = 1'b0;

            for (int i = 0; i < 128; i++)
                lanes_data_out[i*32 +: 32]   = 32'hBEEFBEEF;
            for (int i = 0; i < 128; i++)
                destination_data[i*32 +: 32] = 32'hDEADDEAD;
            #10;
            check_word(0, 32'hBEEFBEEF, "TC5_elem0_body");
            check_word(1, 32'hBEEFBEEF, "TC5_elem1_body");
            check_word(2, 32'hDEADDEAD, "TC5_elem2_tail_undisturbed");
            check_word(5, 32'hDEADDEAD, "TC5_elem5_tail_undisturbed");
        end

        // ====================================================
        // TC6: vma=1 → masked-off elements = all 1s
        //      SEW=8, vl=3, v0=3'b100 (only elem2 active)
        // ====================================================
        $display("\n--- TC6: vma=1, masked-off body = 0xFF ---");
        begin
            init_defaults();
            sew              = 7'b0000100;
            sew_sel          = 2'b00;
            mask_en          = 1'b1;
            vta              = 1'b0;
            vma              = 1'b1;
            vstart           = 32'd0;
            vl               = 32'd3;
            v0               = {{509{1'b0}}, 3'b100};
            mask_reg_en      = 1'b0;

            for (int i = 0; i < 512; i++)
                lanes_data_out[i*8 +: 8]   = 8'h55;
            for (int i = 0; i < 512; i++)
                destination_data[i*8 +: 8] = 8'hCC;
            #10;
            // elem0: body active, mask=0, vma=1 → 0xFF
            check_byte(0, 8'hFF, "TC6_elem0_vma1");
            // elem1: body active, mask=0, vma=1 → 0xFF
            check_byte(1, 8'hFF, "TC6_elem1_vma1");
            // elem2: body active, mask=1 → lanes
            check_byte(2, 8'h55, "TC6_elem2_active");
            // elem3: tail, vta=0 → destination
            check_byte(3, 8'hCC, "TC6_elem3_tail");
        end

        // ====================================================
        // TC7: vma=0 → masked-off = destination (already in TC2,
        //      but explicit focus here with different data)
        // ====================================================
        $display("\n--- TC7: vma=0, masked-off body = destination ---");
        begin
            init_defaults();
            sew              = 7'b0000100;
            sew_sel          = 2'b00;
            mask_en          = 1'b1;
            vta              = 1'b0;
            vma              = 1'b0;
            vstart           = 32'd0;
            vl               = 32'd2;
            v0               = {{510{1'b0}}, 2'b01}; // only elem0 active
            mask_reg_en      = 1'b0;

            for (int i = 0; i < 512; i++)
                lanes_data_out[i*8 +: 8]   = 8'h11;
            for (int i = 0; i < 512; i++)
                destination_data[i*8 +: 8] = 8'h22;
            #10;
            check_byte(0, 8'h11, "TC7_elem0_active");
            check_byte(1, 8'h22, "TC7_elem1_vma0_dest");
        end

        // ====================================================
        // TC8: Prestart check
        //      vstart=2, vl=5, SEW=8
        //      elem0,1 → prestart → destination
        //      elem2-4 → body
        //      elem5+  → tail
        // ====================================================
        $display("\n--- TC8: vstart=2, vl=5, SEW=8, prestart=dest ---");
        begin
            init_defaults();
            sew              = 7'b0000100;
            sew_sel          = 2'b00;
            mask_en          = 1'b1;
            vta              = 1'b0;
            vma              = 1'b0;
            vstart           = 32'd2;
            vl               = 32'd5;
            // v0[4:2] = 3'b111 → elem2,3,4 active in body
            v0               = {{507{1'b0}}, 5'b11100};
            mask_reg_en      = 1'b0;

            for (int i = 0; i < 512; i++)
                lanes_data_out[i*8 +: 8]   = 8'hAA;
            for (int i = 0; i < 512; i++)
                destination_data[i*8 +: 8] = 8'h55;
            #10;
            // elem0,1: prestart → destination
            check_byte(0, 8'h55, "TC8_elem0_prestart");
            check_byte(1, 8'h55, "TC8_elem1_prestart");
            // elem2,3,4: body active → lanes
            check_byte(2, 8'hAA, "TC8_elem2_body_active");
            check_byte(3, 8'hAA, "TC8_elem3_body_active");
            check_byte(4, 8'hAA, "TC8_elem4_body_active");
            // elem5+: tail, vta=0 → destination
            check_byte(5, 8'h55, "TC8_elem5_tail");
        end

        // ====================================================
        // TC9: mask_reg_en=1 → v0 updated with mask_reg_updated
        //      mask_op=AND, vs1=0xF, vs2=0x3 → expected=0x3
        // ====================================================
        $display("\n--- TC9: mask_reg_en=1, v0 gets mask_reg_updated ---");
        begin
            init_defaults();
            sew              = 7'b0000100;
            sew_sel          = 2'b00;
            mask_en          = 1'b0;
            mask_reg_en      = 1'b1;
            mask_op          = 4'b0000; // AND
            vs1              = {{508{1'b0}}, 4'hF};
            vs2              = {{508{1'b0}}, 4'h3};
            v0               = {{508{1'b0}}, 4'hF}; // original v0
            vl               = 32'd4;
            vstart           = 32'd0;
            #10;
            // mask_reg_updated = vs2 & vs1 = 0x3 & 0xF = 0x3
            // mask_reg_en=1 → v0_updated = mask_reg_updated
            // check_generator uses v0_updated as mask_reg
            // We verify mask_reg_updated output port
            check_mask_bits({{508{1'b0}}, 4'h3}, "TC9_mask_reg_en1_AND");
        end

        // ====================================================
        // TC10: mask_reg_en=0 → v0 unchanged (original v0 used)
        // ====================================================
        $display("\n--- TC10: mask_reg_en=0, v0 unchanged ---");
        begin
            init_defaults();
            sew              = 7'b0000100;
            sew_sel          = 2'b00;
            mask_en          = 1'b1;
            mask_reg_en      = 1'b0;
            mask_op          = 4'b0000; // AND
            vs1              = 512'hFF;
            vs2              = 512'hFF;
            // v0 has elem0 only active
            v0               = {{511{1'b0}}, 1'b1};
            vl               = 32'd3;
            vstart           = 32'd0;

            for (int i = 0; i < 512; i++)
                lanes_data_out[i*8 +: 8]   = 8'hEE;
            for (int i = 0; i < 512; i++)
                destination_data[i*8 +: 8] = 8'h33;
            #10;
            // mask_reg_en=0 → mask_reg = v0 = ...001
            // elem0: body, mask=1 → lanes=0xEE
            check_byte(0, 8'hEE, "TC10_elem0_v0_preserved");
            // elem1: body, mask=0, vma=0 → dest=0x33
            check_byte(1, 8'h33, "TC10_elem1_masked_off");
        end

        // ====================================================
        // TC11-TC18: mask_op logic operations
        // ====================================================
        $display("\n--- TC11-TC18: mask_op logic operations ---");
        begin
            automatic logic [511:0] v1, v2, exp;
            v2 = 512'hAAAA_AAAA_AAAA_AAAA;
            v1 = 512'hCCCC_CCCC_CCCC_CCCC;

            // TC11: AND
            init_defaults(); vs2=v2; vs1=v1; mask_op=4'b0000; #10;
            exp = v2 & v1;
            check_mask_bits(exp, "TC11_AND");

            // TC12: NAND
            init_defaults(); vs2=v2; vs1=v1; mask_op=4'b0001; #10;
            exp = ~(v2 & v1);
            check_mask_bits(exp, "TC12_NAND");

            // TC13: ANDN (vs2 & ~vs1)
            init_defaults(); vs2=v2; vs1=v1; mask_op=4'b0010; #10;
            exp = v2 & ~v1;
            check_mask_bits(exp, "TC13_ANDN");

            // TC14: XOR
            init_defaults(); vs2=v2; vs1=v1; mask_op=4'b0011; #10;
            exp = v2 ^ v1;
            check_mask_bits(exp, "TC14_XOR");

            // TC15: OR
            init_defaults(); vs2=v2; vs1=v1; mask_op=4'b0100; #10;
            exp = v2 | v1;
            check_mask_bits(exp, "TC15_OR");

            // TC16: NOR
            init_defaults(); vs2=v2; vs1=v1; mask_op=4'b0101; #10;
            exp = ~(v2 | v1);
            check_mask_bits(exp, "TC16_NOR");

            // TC17: ORN (vs2 | ~vs1)
            init_defaults(); vs2=v2; vs1=v1; mask_op=4'b0110; #10;
            exp = v2 | ~v1;
            check_mask_bits(exp, "TC17_ORN");

            // TC18: XNOR
            init_defaults(); vs2=v2; vs1=v1; mask_op=4'b0111; #10;
            exp = ~(v2 ^ v1);
            check_mask_bits(exp, "TC18_XNOR");
        end

        // ====================================================
        // TC19: carry_out → mask_reg, SEW=8 (sew_sel=2'b00)
        //       carry_out[i] maps to mask_reg_updated[i], i=0..63
        // ====================================================
        $display("\n--- TC19: mask_op=carry, SEW=8 ---");
        begin
            init_defaults();
            sew_sel   = 2'b00;
            mask_op   = 4'b1000;
            carry_out = 64'hDEAD_BEEF_CAFE_1234;
            #10;
            begin
                automatic logic [511:0] exp;
                exp = 512'b0;
                for (int i = 0; i < 64; i++)
                    exp[i] = carry_out[i];
                check_mask_bits(exp, "TC19_carry_SEW8");
            end
        end

        // ====================================================
        // TC20: carry_out → mask, SEW=16 (sew_sel=2'b01)
        //       carry_out[i*2+1] → mask_reg_updated[i], i=0..63
        // ====================================================
        $display("\n--- TC20: mask_op=carry, SEW=16 ---");
        begin
            init_defaults();
            sew_sel   = 2'b01;
            mask_op   = 4'b1000;
            carry_out = 64'hAAAA_AAAA_AAAA_AAAA; // bit pattern 1010...
            #10;
            begin
                automatic logic [511:0] exp;
                exp = 512'b0;
                for (int i = 0; i < 64; i++)
                    exp[i] = carry_out[i*2 + 1];
                check_mask_bits(exp, "TC20_carry_SEW16");
            end
        end

        // ====================================================
        // TC21: carry_out → mask, SEW=32 (sew_sel=2'b10)
        //       carry_out[i*4+3] → mask_reg_updated[i], i=0..63
        //       (only 16 elements fit in 64-bit carry for SEW=32)
        // ====================================================
        $display("\n--- TC21: mask_op=carry, SEW=32 ---");
        begin
            init_defaults();
            sew_sel   = 2'b10;
            mask_op   = 4'b1000;
            carry_out = 64'h8888_8888_8888_8888; // every 4th bit set
            #10;
            begin
                automatic logic [511:0] exp;
                exp = 512'b0;
                for (int i = 0; i < 64; i++)
                    exp[i] = carry_out[i*4 + 3];
                check_mask_bits(exp, "TC21_carry_SEW32");
            end
        end

        // ====================================================
        // TC22: vstart=4, vl=10, SEW=8
        //       elem0-3:  prestart → destination
        //       elem4-9:  body (v0 all-ones → active) → lanes
        //       elem10+:  tail, vta=0 → destination
        // ====================================================
        $display("\n--- TC22: vstart=4, vl=10, SEW=8 ---");
        begin
            init_defaults();
            sew              = 7'b0000100;
            sew_sel          = 2'b00;
            mask_en          = 1'b1;
            vta              = 1'b0;
            vma              = 1'b0;
            vstart           = 32'd4;
            vl               = 32'd10;
            v0               = {512{1'b1}}; // all active
            mask_reg_en      = 1'b0;

            for (int i = 0; i < 512; i++) begin
                lanes_data_out[i*8 +: 8]   = 8'hFF;
                destination_data[i*8 +: 8] = 8'h00;
            end
            #10;
            check_byte(0,  8'h00, "TC22_elem0_prestart");
            check_byte(3,  8'h00, "TC22_elem3_prestart");
            check_byte(4,  8'hFF, "TC22_elem4_body");
            check_byte(7,  8'hFF, "TC22_elem7_body");
            check_byte(9,  8'hFF, "TC22_elem9_body");
            check_byte(10, 8'h00, "TC22_elem10_tail");
            check_byte(20, 8'h00, "TC22_elem20_tail");
        end

        // ====================================================
        // TC23: vl=0 → no body elements, all tail or prestart
        // ====================================================
        $display("\n--- TC23: vl=0, no body elements ---");
        begin
            init_defaults();
            sew              = 7'b0000100;
            sew_sel          = 2'b00;
            mask_en          = 1'b1;
            vta              = 1'b0;
            vma              = 1'b0;
            vstart           = 32'd0;
            vl               = 32'd0;
            v0               = {512{1'b1}};
            mask_reg_en      = 1'b0;

            for (int i = 0; i < 512; i++) begin
                lanes_data_out[i*8 +: 8]   = 8'hAA;
                destination_data[i*8 +: 8] = 8'h55;
            end
            #10;
            // vl=0 → body_check=0 for all, tail_check=all 1s
            // vta=0 → all output = destination
            check_byte(0, 8'h55, "TC23_elem0_vl0_tail");
            check_byte(1, 8'h55, "TC23_elem1_vl0_tail");
            check_byte(10, 8'h55, "TC23_elem10_vl0_tail");
        end

        // ====================================================
        // TC24: All mask_reg bits=1 → all body elements active
        // ====================================================
        $display("\n--- TC24: v0=all_ones, all body active ---");
        begin
            init_defaults();
            sew              = 7'b0000100;
            sew_sel          = 2'b00;
            mask_en          = 1'b1;
            vta              = 1'b0;
            vma              = 1'b0;
            vstart           = 32'd0;
            vl               = 32'd8;
            v0               = {512{1'b1}};
            mask_reg_en      = 1'b0;

            for (int i = 0; i < 512; i++)
                lanes_data_out[i*8 +: 8]   = 8'hCC;
            for (int i = 0; i < 512; i++)
                destination_data[i*8 +: 8] = 8'h33;
            #10;
            for (int i = 0; i < 8; i++)
                check_byte(i, 8'hCC, $sformatf("TC24_elem%0d_all_active", i));
        end

        // ====================================================
        // TC25: All mask_reg bits=0 → all body masked off
        //       vma=0 → all = destination
        // ====================================================
        $display("\n--- TC25: v0=all_zeros, vma=0, all body=dest ---");
        begin
            init_defaults();
            sew              = 7'b0000100;
            sew_sel          = 2'b00;
            mask_en          = 1'b1;
            vta              = 1'b0;
            vma              = 1'b0;
            vstart           = 32'd0;
            vl               = 32'd8;
            v0               = {512{1'b0}};
            mask_reg_en      = 1'b0;

            for (int i = 0; i < 512; i++)
                lanes_data_out[i*8 +: 8]   = 8'hAA;
            for (int i = 0; i < 512; i++)
                destination_data[i*8 +: 8] = 8'h77;
            #10;
            for (int i = 0; i < 8; i++)
                check_byte(i, 8'h77, $sformatf("TC25_elem%0d_all_masked_dest", i));
        end

        // ====================================================
        // SUMMARY
        // ====================================================
        #10;
        $display("\n========================================================");
        $display("   TESTBENCH COMPLETE");
        $display("   PASSED : %0d", pass_count);
        $display("   FAILED : %0d", fail_count);
        $display("   TOTAL  : %0d", pass_count + fail_count);
        if (fail_count == 0)
            $display("   RESULT : *** ALL TESTS PASSED ***");
        else
            $display("   RESULT : *** %0d TEST(S) FAILED - CHECK ABOVE ***", fail_count);
        $display("========================================================");

        $finish;
    end

    // -------------------------------------------------------
    // Timeout watchdog
    // -------------------------------------------------------
    initial begin
        #500000;
        $display("[TIMEOUT] Simulation exceeded time limit!");
        $finish;
    end

endmodule