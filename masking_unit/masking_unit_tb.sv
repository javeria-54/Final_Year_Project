`timescale 1ns/1ps

module vector_mask_unit_tb;

    // =====================================================
    // DUT Signals
    // =====================================================

    logic [4095:0] lanes_data_out;
    logic [4095:0] destination_data;

    logic [2:0]    mask_op;
    logic          mask_en;
    logic          mask_reg_en;
    logic          vta;
    logic          vma;

    logic [8:0]    vstart;
    logic [8:0]    vl;
    logic [5:0]    sew;

    logic [511:0]  vs1;
    logic [511:0]  vs2;
    logic [511:0]  v0;

    logic [4095:0] mask_unit_output;
    logic [511:0]  mask_reg_updated;

    logic [4095:0] expected_output;

    // =====================================================
    // Counters for pass/fail summary
    // =====================================================
    integer pass_count = 0;
    integer fail_count = 0;

    // =====================================================
    // DUT Instantiation
    // =====================================================

    vector_mask_unit DUT (.*);

    // =====================================================
    // Golden Model (Reference Logic)
    // =====================================================
    function automatic [4095:0] golden_model;

        integer i;
        logic [4095:0] temp;
        logic [511:0]  effective_mask;

        begin
            temp = destination_data;

            // Compute effective mask (same as DUT's mux2x1 + comb_mask_operations)
            if (mask_reg_en)
                effective_mask = mask_reg_updated;
            else
                effective_mask = v0;

            if (!mask_en) begin
                golden_model = lanes_data_out;
            end
            else begin

                case (sew)

                // ================= SEW = 8 =================
                6'b000100: begin
                    for (i = 0; i < 512; i++) begin
                        if (i < vstart)
                            temp[i*8 +: 8] = destination_data[i*8 +: 8];
                        else if (i < vl) begin
                            if (effective_mask[i])
                                temp[i*8 +: 8] = lanes_data_out[i*8 +: 8];
                            else if (!vma)
                                temp[i*8 +: 8] = destination_data[i*8 +: 8];
                            else
                                temp[i*8 +: 8] = 8'hFF;
                        end
                        else begin
                            if (!vta)
                                temp[i*8 +: 8] = destination_data[i*8 +: 8];
                            else
                                temp[i*8 +: 8] = 8'hFF;
                        end
                    end
                end

                // ================= SEW = 16 =================
                6'b001000: begin
                    for (i = 0; i < 256; i++) begin
                        if (i < vstart)
                            temp[i*16 +: 16] = destination_data[i*16 +: 16];
                        else if (i < vl) begin
                            if (effective_mask[i])
                                temp[i*16 +: 16] = lanes_data_out[i*16 +: 16];
                            else if (!vma)
                                temp[i*16 +: 16] = destination_data[i*16 +: 16];
                            else
                                temp[i*16 +: 16] = 16'hFFFF;
                        end
                        else begin
                            if (!vta)
                                temp[i*16 +: 16] = destination_data[i*16 +: 16];
                            else
                                temp[i*16 +: 16] = 16'hFFFF;
                        end
                    end
                end

                // ================= SEW = 32 =================
                6'b010000: begin
                    for (i = 0; i < 128; i++) begin
                        if (i < vstart)
                            temp[i*32 +: 32] = destination_data[i*32 +: 32];
                        else if (i < vl) begin
                            if (effective_mask[i])
                                temp[i*32 +: 32] = lanes_data_out[i*32 +: 32];
                            else if (!vma)
                                temp[i*32 +: 32] = destination_data[i*32 +: 32];
                            else
                                temp[i*32 +: 32] = 32'hFFFF_FFFF;
                        end
                        else begin
                            if (!vta)
                                temp[i*32 +: 32] = destination_data[i*32 +: 32];
                            else
                                temp[i*32 +: 32] = 32'hFFFF_FFFF;
                        end
                    end
                end

                // ================= SEW = 64 =================
                6'b100000: begin
                    for (i = 0; i < 64; i++) begin
                        if (i < vstart)
                            temp[i*64 +: 64] = destination_data[i*64 +: 64];
                        else if (i < vl) begin
                            if (effective_mask[i])
                                temp[i*64 +: 64] = lanes_data_out[i*64 +: 64];
                            else if (!vma)
                                temp[i*64 +: 64] = destination_data[i*64 +: 64];
                            else
                                temp[i*64 +: 64] = 64'hFFFF_FFFF_FFFF_FFFF;
                        end
                        else begin
                            if (!vta)
                                temp[i*64 +: 64] = destination_data[i*64 +: 64];
                            else
                                temp[i*64 +: 64] = 64'hFFFF_FFFF_FFFF_FFFF;
                        end
                    end
                end

                default: temp = destination_data;

                endcase

                golden_model = temp;
            end
        end
    endfunction

    // =====================================================
    // Compare Task (with Input/Output Display)
    // =====================================================
    task compare_result(string testname);
        begin
            #1; // small settle time
            expected_output = golden_model();

            $display("");
            $display("  ┌─────────────────────────────────────────────────┐");
            $display("  │ TEST: %-43s│", testname);
            $display("  ├─────────────────────────────────────────────────┤");
            $display("  │ INPUTS:                                         │");
            $display("  │   sew         = %6b  (%0d-bit)                  ", sew,
                     (sew == 6'b000100) ? 8  :
                     (sew == 6'b001000) ? 16 :
                     (sew == 6'b010000) ? 32 : 64);
            $display("  │   vstart      = %0d", vstart);
            $display("  │   vl          = %0d", vl);
            $display("  │   mask_en     = %0b  (0=bypass, 1=masked)", mask_en);
            $display("  │   mask_reg_en = %0b  (0=use v0, 1=update v0)", mask_reg_en);
            $display("  │   vta         = %0b  (tail agnostic)", vta);
            $display("  │   vma         = %0b  (mask agnostic)", vma);
            $display("  │   mask_op     = %3b", mask_op);
            $display("  │   vs1         = %0h", vs1);
            $display("  │   vs2         = %0h", vs2);
            $display("  │   v0          = %0h", v0);
            $display("  │   lanes_data_out   [63:0] = %0h", lanes_data_out[63:0]);
            $display("  │   destination_data [63:0] = %0h", destination_data[63:0]);
            $display("  ├─────────────────────────────────────────────────┤");
            $display("  │ OUTPUTS:                                        │");
            $display("  │   mask_reg_updated [63:0] = %0h", mask_reg_updated[63:0]);
            $display("  │   mask_unit_output [63:0] = %0h", mask_unit_output[63:0]);
            $display("  │   expected_output  [63:0] = %0h", expected_output[63:0]);
            $display("  ├─────────────────────────────────────────────────┤");

            if (expected_output === mask_unit_output) begin
                $display("  │  RESULT: ✅  PASS                               │");
                pass_count++;
            end else begin
                $display("  │  RESULT: ❌  FAIL                               │");
                $display("  │  Expected [full] = %h", expected_output);
                $display("  │  Got      [full] = %h", mask_unit_output);
                fail_count++;
            end

            $display("  └─────────────────────────────────────────────────┘");
        end
    endtask

    // =====================================================
    // Initialize random data
    // =====================================================
    task init_data();
        integer i;
        begin
            for (i = 0; i < 4096; i++) begin
                lanes_data_out[i]  = $random;
                destination_data[i] = $random;
            end
        end
    endtask

    // =====================================================
    // Reset / Default Task
    // =====================================================
    task apply_defaults();
        begin
            vs1         = 512'hFFFF;
            vs2         = 512'hAAAA;
            v0          = 512'hFFFF;
            mask_op     = 3'b000;
            mask_reg_en = 1;
            mask_en     = 1;
            vstart      = 0;
            vl          = 20;
            vta         = 0;
            vma         = 0;
            sew         = 6'b000100;
        end
    endtask

    // =====================================================
    // TEST SEQUENCE
    // =====================================================
    initial begin

        $display("");
        $display("========================================================");
        $display("      VECTOR MASK UNIT - SELF CHECKING TESTBENCH        ");
        $display("========================================================");

        init_data();
        apply_defaults();

        // ------------------------------------------------
        // GROUP 1: Basic SEW Tests
        // ------------------------------------------------
        $display("");
        $display("---- GROUP 1: Basic SEW Tests (vl=20, vstart=0) --------");

        mask_op = 3'b000; mask_reg_en = 1; mask_en = 1;
        vstart = 0; vl = 20; vta = 0; vma = 0;

        sew = 6'b000100; #5; compare_result("G1: SEW=8  Basic");
        sew = 6'b001000; #5; compare_result("G1: SEW=16 Basic");
        sew = 6'b010000; #5; compare_result("G1: SEW=32 Basic");
        sew = 6'b100000; #5; compare_result("G1: SEW=64 Basic");

        // ------------------------------------------------
        // GROUP 2: Tail Agnostic (vta=1)
        // ------------------------------------------------
        $display("");
        $display("---- GROUP 2: Tail Agnostic Tests (vta=1) ---------------");

        vta = 1; vma = 0; vl = 10; vstart = 0;

        sew = 6'b000100; #5; compare_result("G2: SEW=8  Tail Agnostic");
        sew = 6'b001000; #5; compare_result("G2: SEW=16 Tail Agnostic");
        sew = 6'b010000; #5; compare_result("G2: SEW=32 Tail Agnostic");
        sew = 6'b100000; #5; compare_result("G2: SEW=64 Tail Agnostic");

        // ------------------------------------------------
        // GROUP 3: Mask Agnostic (vma=1)
        // ------------------------------------------------
        $display("");
        $display("---- GROUP 3: Mask Agnostic Tests (vma=1) ---------------");

        vta = 0; vma = 1; vl = 20; vstart = 0;
        vs1 = 512'hAAAA_AAAA; vs2 = 512'hFFFF_FFFF; // alternating mask

        sew = 6'b000100; #5; compare_result("G3: SEW=8  Mask Agnostic");
        sew = 6'b001000; #5; compare_result("G3: SEW=16 Mask Agnostic");
        sew = 6'b010000; #5; compare_result("G3: SEW=32 Mask Agnostic");
        sew = 6'b100000; #5; compare_result("G3: SEW=64 Mask Agnostic");

        // ------------------------------------------------
        // GROUP 4: Both Agnostic (vta=1, vma=1)
        // ------------------------------------------------
        $display("");
        $display("---- GROUP 4: Both Agnostic (vta=1, vma=1) --------------");

        vta = 1; vma = 1; vl = 15; vstart = 5;

        sew = 6'b000100; #5; compare_result("G4: SEW=8  vta+vma");
        sew = 6'b001000; #5; compare_result("G4: SEW=16 vta+vma");
        sew = 6'b010000; #5; compare_result("G4: SEW=32 vta+vma");
        sew = 6'b100000; #5; compare_result("G4: SEW=64 vta+vma");

        // ------------------------------------------------
        // GROUP 5: Bypass Mode (mask_en=0)
        // ------------------------------------------------
        $display("");
        $display("---- GROUP 5: Bypass Mode (mask_en=0) -------------------");

        mask_en = 0; vta = 0; vma = 0; vl = 20; vstart = 0;

        sew = 6'b000100; #5; compare_result("G5: SEW=8  Bypass");
        sew = 6'b001000; #5; compare_result("G5: SEW=16 Bypass");
        sew = 6'b010000; #5; compare_result("G5: SEW=32 Bypass");
        sew = 6'b100000; #5; compare_result("G5: SEW=64 Bypass");

        // ------------------------------------------------
        // GROUP 6: vstart > 0 (Prestart Elements)
        // ------------------------------------------------
        $display("");
        $display("---- GROUP 6: Prestart Tests (vstart>0) ----------------");

        mask_en = 1; vta = 0; vma = 0;
        vs1 = 512'hFFFF_FFFF; vs2 = 512'hFFFF_FFFF;

        vstart = 5;  vl = 20; sew = 6'b000100; #5; compare_result("G6: SEW=8  vstart=5");
        vstart = 10; vl = 30; sew = 6'b001000; #5; compare_result("G6: SEW=16 vstart=10");
        vstart = 2;  vl = 50; sew = 6'b010000; #5; compare_result("G6: SEW=32 vstart=2");
        vstart = 3;  vl = 20; sew = 6'b100000; #5; compare_result("G6: SEW=64 vstart=3");

        // ------------------------------------------------
        // GROUP 7: vl = 0 (All Elements are Tail)
        // ------------------------------------------------
        $display("");
        $display("---- GROUP 7: vl=0 Edge Case ----------------------------");

        vstart = 0; vl = 0; vta = 0; vma = 0;

        sew = 6'b000100; #5; compare_result("G7: SEW=8  vl=0 vta=0");
        sew = 6'b001000; #5; compare_result("G7: SEW=16 vl=0 vta=0");

        vta = 1;
        sew = 6'b010000; #5; compare_result("G7: SEW=32 vl=0 vta=1");
        sew = 6'b100000; #5; compare_result("G7: SEW=64 vl=0 vta=1");

        // ------------------------------------------------
        // GROUP 8: All Mask Bits = 0 (All Inactive Body)
        // ------------------------------------------------
        $display("");
        $display("---- GROUP 8: All Mask Bits = 0 -------------------------");

        vs1 = 512'h0; vs2 = 512'h0; v0 = 512'h0;
        mask_op = 3'b000; mask_reg_en = 1; // vmand: 0 & 0 = 0
        vstart = 0; vl = 20; vta = 0; vma = 0; mask_en = 1;

        sew = 6'b000100; #5; compare_result("G8: SEW=8  All Mask=0 vma=0");
        vma = 1;
        sew = 6'b000100; #5; compare_result("G8: SEW=8  All Mask=0 vma=1");
        vma = 0;
        sew = 6'b001000; #5; compare_result("G8: SEW=16 All Mask=0");
        sew = 6'b010000; #5; compare_result("G8: SEW=32 All Mask=0");
        sew = 6'b100000; #5; compare_result("G8: SEW=64 All Mask=0");

        // ------------------------------------------------
        // GROUP 9: All Mask Bits = 1 (All Active Body)
        // ------------------------------------------------
        $display("");
        $display("---- GROUP 9: All Mask Bits = 1 -------------------------");

        vs1 = 512'hFFFF_FFFF_FFFF_FFFF; 
        vs2 = 512'hFFFF_FFFF_FFFF_FFFF;
        v0  = 512'hFFFF_FFFF_FFFF_FFFF;
        mask_op = 3'b100; // vmor: all 1
        mask_reg_en = 1; vstart = 0; vl = 30; vta = 0; vma = 0; mask_en = 1;

        sew = 6'b000100; #5; compare_result("G9: SEW=8  All Mask=1");
        sew = 6'b001000; #5; compare_result("G9: SEW=16 All Mask=1");
        sew = 6'b010000; #5; compare_result("G9: SEW=32 All Mask=1");
        sew = 6'b100000; #5; compare_result("G9: SEW=64 All Mask=1");

        // ------------------------------------------------
        // GROUP 10: mask_reg_en = 0 (Use old v0)
        // ------------------------------------------------
        $display("");
        $display("---- GROUP 10: mask_reg_en=0 (Use existing v0) ---------");

        vs1 = 512'h0; vs2 = 512'h0; // mask_reg_updated would be 0
        v0  = 512'hFFFF_FFFF;       // but we use v0 since mask_reg_en=0
        mask_op     = 3'b000;
        mask_reg_en = 0;            // use v0 directly
        mask_en     = 1;
        vstart = 0; vl = 20; vta = 0; vma = 0;

        sew = 6'b000100; #5; compare_result("G10: SEW=8  mask_reg_en=0");
        sew = 6'b001000; #5; compare_result("G10: SEW=16 mask_reg_en=0");
        sew = 6'b010000; #5; compare_result("G10: SEW=32 mask_reg_en=0");
        sew = 6'b100000; #5; compare_result("G10: SEW=64 mask_reg_en=0");

        // ------------------------------------------------
        // GROUP 11: All Mask Operations (vmand, vmnand, ...)
        // ------------------------------------------------
        $display("");
        $display("---- GROUP 11: All mask_op Values -----------------------");

        vs1 = 512'hAAAA_AAAA_AAAA_AAAA;
        vs2 = 512'hCCCC_CCCC_CCCC_CCCC;
        mask_reg_en = 1; mask_en = 1;
        vstart = 0; vl = 20; vta = 0; vma = 0; sew = 6'b000100;

        mask_op = 3'b000; #5; compare_result("G11: mask_op=000 vmand.mm");
        mask_op = 3'b001; #5; compare_result("G11: mask_op=001 vmnand.mm");
        mask_op = 3'b010; #5; compare_result("G11: mask_op=010 vmandn.mm");
        mask_op = 3'b011; #5; compare_result("G11: mask_op=011 vmxor.mm");
        mask_op = 3'b100; #5; compare_result("G11: mask_op=100 vmor.mm");
        mask_op = 3'b101; #5; compare_result("G11: mask_op=101 vmnor.mm");
        mask_op = 3'b110; #5; compare_result("G11: mask_op=110 vmorn.mm");
        mask_op = 3'b111; #5; compare_result("G11: mask_op=111 vmxnor.mm");

        // ------------------------------------------------
        // GROUP 12: Max vl Boundary Test
        // ------------------------------------------------
        $display("");
        $display("---- GROUP 12: Max vl Boundary Tests --------------------");

        vs1 = 512'hFFFF_FFFF_FFFF_FFFF;
        vs2 = 512'hFFFF_FFFF_FFFF_FFFF;
        mask_op = 3'b000; mask_reg_en = 1; mask_en = 1;
        vstart = 0; vta = 0; vma = 0;

        vl = 9'd511; sew = 6'b000100; #5; compare_result("G12: SEW=8  vl=511");
        vl = 9'd255; sew = 6'b001000; #5; compare_result("G12: SEW=16 vl=255");
        vl = 9'd127; sew = 6'b010000; #5; compare_result("G12: SEW=32 vl=127");
        vl = 9'd63;  sew = 6'b100000; #5; compare_result("G12: SEW=64 vl=63");

        // ------------------------------------------------
        // GROUP 13: Alternating Mask (Checkerboard Pattern)
        // ------------------------------------------------
        $display("");
        $display("---- GROUP 13: Alternating/Checkerboard Mask ------------");

        vs1 = {64{8'hAA}}; // alternating 10101010
        vs2 = {64{8'hAA}};
        mask_op = 3'b000; // vmand: AAAA & AAAA = AAAA
        mask_reg_en = 1; mask_en = 1;
        vstart = 0; vl = 40; vta = 0; vma = 0;

        sew = 6'b000100; #5; compare_result("G13: SEW=8  Alternating Mask vma=0");
        vma = 1;
        sew = 6'b000100; #5; compare_result("G13: SEW=8  Alternating Mask vma=1");
        vma = 0;
        sew = 6'b001000; #5; compare_result("G13: SEW=16 Alternating Mask");
        sew = 6'b010000; #5; compare_result("G13: SEW=32 Alternating Mask");
        sew = 6'b100000; #5; compare_result("G13: SEW=64 Alternating Mask");

        // ------------------------------------------------
        // GROUP 14: vstart = vl (No Body Elements)
        // ------------------------------------------------
        $display("");
        $display("---- GROUP 14: vstart == vl (Empty Body) ----------------");

        vs1 = 512'hFFFF; vs2 = 512'hFFFF;
        mask_op = 3'b000; mask_reg_en = 1; mask_en = 1;
        vstart = 10; vl = 10; // vstart == vl => no body elements

        vta = 0; vma = 0;
        sew = 6'b000100; #5; compare_result("G14: SEW=8  vstart==vl vta=0");
        vta = 1;
        sew = 6'b000100; #5; compare_result("G14: SEW=8  vstart==vl vta=1");
        vta = 0;
        sew = 6'b001000; #5; compare_result("G14: SEW=16 vstart==vl");
        sew = 6'b010000; #5; compare_result("G14: SEW=32 vstart==vl");
        sew = 6'b100000; #5; compare_result("G14: SEW=64 vstart==vl");

        // ------------------------------------------------
        // GROUP 15: Random Stress Test
        // ------------------------------------------------
        $display("");
        $display("---- GROUP 15: Random Stress Tests (20 iterations) ------");

        begin
            integer j;
            for (j = 0; j < 20; j++) begin
                // Randomize everything
                init_data();
                vs1         = $random;
                vs2         = $random;
                v0          = $random;
                mask_op     = $random % 8;
                mask_reg_en = $random % 2;
                mask_en     = $random % 2;
                vta         = $random % 2;
                vma         = $random % 2;
                vstart      = $random % 10;
                // Pick random SEW
                case ($random % 4)
                    0: begin sew = 6'b000100; vl = ($random % 30) + vstart; end
                    1: begin sew = 6'b001000; vl = ($random % 30) + vstart; end
                    2: begin sew = 6'b010000; vl = ($random % 30) + vstart; end
                    3: begin sew = 6'b100000; vl = ($random % 30) + vstart; end
                endcase
                #5;
                compare_result($sformatf("G15: Stress Iter %0d", j+1));
            end
        end

        // ------------------------------------------------
        // FINAL SUMMARY
        // ------------------------------------------------
        $display("");
        $display("========================================================");
        $display("   FINAL SUMMARY: %0d PASSED | %0d FAILED", pass_count, fail_count);
        $display("========================================================");
        $display("");

        if (fail_count == 0)
            $display("🎉  ALL TESTS PASSED!");
        else
            $display("⚠️   SOME TESTS FAILED. Check above for details.");

        $display("");
        $stop;
    end

endmodule