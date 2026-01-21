
module tb_vector_compare_unit;

    localparam VLEN = 512;
    localparam ELEN = 32;

    // DUT signals
    logic [VLEN-1:0] data1;
    logic [VLEN-1:0] data2;
    logic [1:0]      op_type;
    logic [2:0]      cmp_op;
    logic [6:0]      sew;

    logic [VLEN-1:0] compare_result;
    logic            compare_done;

    // DUT instantiation
    vector_compare_unit #(
        .VLEN(VLEN),
        .ELEN(ELEN)
    ) dut (
        .data1(data1),
        .data2(data2),
        .op_type(op_type),
        .cmp_op(cmp_op),
        .sew(sew),
        .compare_result(compare_result),
        .compare_done(compare_done)
    );

    // --------------------------------------------------
    // Display helpers (show only LSB of each element)
    // --------------------------------------------------
    task show_vec8(input [VLEN-1:0] v);
        for (int i = 0; i < 8; i++)
            $display("elem[%0d] = %0d", i, v[i*8]);
    endtask

    task show_vec16(input [VLEN-1:0] v);
        for (int i = 0; i < 4; i++)
            $display("elem[%0d] = %0d", i, v[i*16]);
    endtask

    task show_vec32(input [VLEN-1:0] v);
        for (int i = 0; i < 4; i++)
            $display("elem[%0d] = %0d", i, v[i*32]);
    endtask

    // --------------------------------------------------
    // Test sequence
    // --------------------------------------------------
    initial begin
        $display("========================================");
        $display(" VECTOR COMPARE UNIT TESTBENCH START ");
        $display("========================================");

        // --------------------------------
        // TEST 1: SEW=8, VV, EQ
        // --------------------------------
        sew     = 8;
        op_type = 2'b00; // OP_VV
        cmp_op = 3'b000; // CMP_EQ

        data1 = '0;
        data2 = '0;

        data1[7:0]  = 8'd10;
        data2[7:0]  = 8'd10;

        data1[15:8] = 8'd5;
        data2[15:8] = 8'd7;

        #5;
        $display("\nTEST 1: SEW=8 VV EQ");
        show_vec8(compare_result);

        // --------------------------------
        // TEST 2: SEW=8, VX, LTU
        // --------------------------------
        op_type = 2'b01; // OP_VX
        cmp_op = 3'b010; // CMP_LTU

        data1 = '0;
        data1[7:0] = 8'd20; // scalar

        #5;
        $display("\nTEST 2: SEW=8 VX LTU");
        show_vec8(compare_result);

        // --------------------------------
        // TEST 3: SEW=8, VI, LT (signed)
        // --------------------------------
        op_type = 2'b10; // OP_VI
        cmp_op = 3'b100; // CMP_LT

        data1 = '0;
        data1[4:0] = 5'b11111; // -1

        #5;
        $display("\nTEST 3: SEW=8 VI LT (signed, imm=-1)");
        show_vec8(compare_result);

        // --------------------------------
        // TEST 4: SEW=16, VV, GT (pseudo-op)
        // --------------------------------
        sew     = 16;
        op_type = 2'b00; // OP_VV
        cmp_op = 3'b110; // CMP_GT

        data1 = '0;
        data2 = '0;

        data2[15:0] = 16'sd5;
        data1[15:0] = 16'sd3;

        #5;
        $display("\nTEST 4: SEW=16 VV GT (signed pseudo-op)");
        show_vec16(compare_result);

        // --------------------------------
        // TEST 5: SEW=16, VX, LEU
        // --------------------------------
        op_type = 2'b01; // OP_VX
        cmp_op = 3'b011; // CMP_LEU

        data1 = '0;
        data1[15:0] = 16'd100;

        #5;
        $display("\nTEST 5: SEW=16 VX LEU");
        show_vec16(compare_result);

        // --------------------------------
        // TEST 6: SEW=32, VV, NE
        // --------------------------------
        sew     = 32;
        op_type = 2'b00; // OP_VV
        cmp_op = 3'b001; // CMP_NE

        data1 = '0;
        data2 = '0;

        data1[31:0] = 32'd42;
        data2[31:0] = 32'd42;

        data1[63:32] = 32'd10;
        data2[63:32] = 32'd20;

        #5;
        $display("\nTEST 6: SEW=32 VV NE");
        show_vec32(compare_result);

        // --------------------------------
        // TEST 7: SEW=32, VI, GE (signed)
        // --------------------------------
        op_type = 2'b10; // OP_VI
        cmp_op = 3'b111; // CMP_GE

        data1 = '0;
        data1[4:0] = 5'd3;

        #5;
        $display("\nTEST 7: SEW=32 VI GE (signed)");
        show_vec32(compare_result);

        $display("\n========================================");
        $display(" ALL COMPARE TESTS COMPLETED ");
        $display("========================================");

        $finish;
    end

endmodule
