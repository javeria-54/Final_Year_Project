`include "vector_processor_defs.svh"
`include "vector_execution_unit.svh"

module tb_vector_mask_add_sub;

    // --------------------------------------------------------
    // DUT Signals
    // --------------------------------------------------------
    logic [`VLEN-1:0]       adder_data_1;
    logic [`VLEN-1:0]       adder_data_2;
    logic [`VLEN-1:0]       mask_reg;
    logic                   Ctrl;
    logic                   sew_16_32;
    logic                   sew_32;
    logic [1:0]             sew;
    logic [(`VLEN/8)-1:0]   carry_out;
    logic [`VLEN-1:0]       sum_mask_result;
    logic                   sum_mask_done;

    // --------------------------------------------------------
    // DUT Instantiation
    // --------------------------------------------------------
    vector_mask_add_sub DUT (
        .adder_data_1   (adder_data_1),
        .adder_data_2   (adder_data_2),
        .mask_reg       (mask_reg),
        .Ctrl           (Ctrl),
        .sew_16_32      (sew_16_32),
        .sew_32         (sew_32),
        .sew            (sew),
        .carry_out      (carry_out),
        .sum_mask_result(sum_mask_result),
        .sum_mask_done  (sum_mask_done)
    );

    // --------------------------------------------------------
    // Task: Apply inputs and display result
    // --------------------------------------------------------
    task apply_and_check(
        input [`VLEN-1:0] d1,
        input [`VLEN-1:0] d2,
        input [`VLEN-1:0] mask,
        input             ctrl,
        input             s16_32,
        input             s32,
        input [1:0]       s,
        input string      test_name
    );
        adder_data_1 = d1;
        adder_data_2 = d2;
        mask_reg     = mask;
        Ctrl         = ctrl;
        sew_16_32    = s16_32;
        sew_32       = s32;
        sew          = s;
        #10;

        $display("--------------------------------------------");
        $display("TEST: %s", test_name);
        $display("  adder_data_1   = %h", adder_data_1);
        $display("  adder_data_2   = %h", adder_data_2);
        $display("  mask_reg       = %h", mask_reg);
        $display("  Ctrl           = %b (0=Add, 1=Sub)", Ctrl);
        $display("  sew_32=%b sew_16_32=%b", sew_32, sew_16_32);
        $display("  sum_mask_result= %h", sum_mask_result);
        $display("  carry_out      = %h", carry_out);
        $display("  sum_mask_done  = %b", sum_mask_done);

        // X check
        if (^sum_mask_result === 1'bx)
            $display("  *** WARNING: sum_mask_result has X! ***");
        if (^carry_out === 1'bx)
            $display("  *** WARNING: carry_out has X! ***");
    endtask

    // --------------------------------------------------------
    // Test Stimulus
    // --------------------------------------------------------
    initial begin
        // Initialize all
        adder_data_1 = '0;
        adder_data_2 = '0;
        mask_reg     = '0;
        Ctrl         = 0;
        sew_16_32    = 0;
        sew_32       = 0;
        sew          = 2'b00;
        #20;

        // ------------------------------------------------
        // TEST 1: SEW=8, ADD, mask=0 (no carry-in)
        // ------------------------------------------------
        apply_and_check(
            128'h01010101_01010101_01010101_01010101,  // d1
            128'h02020202_02020202_02020202_02020202,  // d2
            128'h0,                                    // mask (carry-in=0)
            1'b0,                                      // ADD
            1'b0, 1'b0,                                // SEW=8
            2'b00,
            "SEW8 ADD no carry"
        );

        // ------------------------------------------------
        // TEST 2: SEW=8, ADD, mask=all 1s (carry-in=1 every element)
        // ------------------------------------------------
        apply_and_check(
            128'h01010101_01010101_01010101_01010101,
            128'h02020202_02020202_02020202_02020202,
            128'hFFFFFFFF_FFFFFFFF_FFFFFFFF_FFFFFFFF,  // mask all 1s
            1'b0,
            1'b0, 1'b0,
            2'b00,
            "SEW8 ADD with carry-in=1"
        );

        // ------------------------------------------------
        // TEST 3: SEW=16, ADD, mask=0
        // ------------------------------------------------
        apply_and_check(
            128'h00050005_00050005_00050005_00050005,
            128'h00080008_00080008_00080008_00080008,
            128'h0,
            1'b0,
            1'b1, 1'b0,   // SEW=16
            2'b01,
            "SEW16 ADD no carry"
        );

        // ------------------------------------------------
        // TEST 4: SEW=16, ADD, mask=1 (carry-in per element)
        // ------------------------------------------------
        apply_and_check(
            128'h00050005_00050005_00050005_00050005,
            128'h00080008_00080008_00080008_00080008,
            128'hFFFFFFFF_FFFFFFFF_FFFFFFFF_FFFFFFFF,
            1'b0,
            1'b1, 1'b0,
            2'b01,
            "SEW16 ADD with carry-in=1"
        );

        // ------------------------------------------------
        // TEST 5: SEW=32, ADD, mask=0
        // vadc: 0x8 + 0x1 + 0 = 0x9
        // ------------------------------------------------
        apply_and_check(
            128'h00000008_00000008_00000008_00000008,
            128'h00000001_00000001_00000001_00000001,
            128'h0,
            1'b0,
            1'b1, 1'b1,   // SEW=32
            2'b10,
            "SEW32 ADD no carry (8+1=9)"
        );

        // ------------------------------------------------
        // TEST 6: SEW=32, ADD, mask=1 (carry-in=1)
        // vadc: 0x8 + 0x1 + 1 = 0xA
        // ------------------------------------------------
        apply_and_check(
            128'h00000008_00000008_00000008_00000008,
            128'h00000001_00000001_00000001_00000001,
            128'hFFFFFFFF_FFFFFFFF_FFFFFFFF_FFFFFFFF,  // bit0=1 → carry-in=1
            1'b0,
            1'b1, 1'b1,
            2'b10,
            "SEW32 ADD with carry-in=1 (8+1+1=0xA)"
        );

        // ------------------------------------------------
        // TEST 7: SEW=32, SUBTRACT, mask=0
        // 0x8 - 0x1 = 0x7
        // ------------------------------------------------
        apply_and_check(
            128'h00000008_00000008_00000008_00000008,
            128'h00000001_00000001_00000001_00000001,
            128'h0,
            1'b1,          // SUB
            1'b1, 1'b1,
            2'b10,
            "SEW32 SUB (8-1=7)"
        );

        // ------------------------------------------------
        // TEST 8: SEW=32, ADD, Overflow test
        // 0xFFFFFFFF + 0x1 = 0x0 with carry
        // ------------------------------------------------
        apply_and_check(
            128'hFFFFFFFF_FFFFFFFF_FFFFFFFF_FFFFFFFF,
            128'h00000001_00000001_00000001_00000001,
            128'h0,
            1'b0,
            1'b1, 1'b1,
            2'b10,
            "SEW32 ADD Overflow (0xFFFFFFFF+1=0, carry=1)"
        );

        // ------------------------------------------------
        // TEST 9: All zeros
        // ------------------------------------------------
        apply_and_check(
            128'h0,
            128'h0,
            128'h0,
            1'b0,
            1'b0, 1'b0,
            2'b00,
            "All zeros SEW8"
        );

        $display("============================================");
        $display("All Tests Done");
        $display("============================================");
        $finish;
    end

    // --------------------------------------------------------
    // Waveform Dump
    // --------------------------------------------------------
    initial begin
        $dumpfile("tb_vector_mask_add_sub.vcd");
        $dumpvars(0, tb_vector_mask_add_sub);
    end

endmodule