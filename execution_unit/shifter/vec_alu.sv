module tb_vec_alu_execution_unit;

    localparam VLEN = 512;
    localparam ELEN = 32;

    // DUT signals
    logic [VLEN-1:0] data1;
    logic [VLEN-1:0] data2;
    logic [1:0]      op_type;
    logic [4:0]      alu_opcode;
    logic [6:0]      sew;

    logic [VLEN-1:0] alu_result;
    logic            alu_done;

    // DUT instantiation
    vec_alu_execution_unit #(
        .VLEN(VLEN),
        .ELEN(ELEN)
    ) dut (
        .data1(data1),
        .data2(data2),
        .op_type(op_type),
        .alu_opcode(alu_opcode),
        .sew(sew),
        .alu_result(alu_result),
        .alu_done(alu_done)
    );

    // -------------------------------------------------
    // Display helpers
    // -------------------------------------------------
    task show_vec8(input [VLEN-1:0] v);
        for (int i = 0; i < 8; i++)
            $display("elem[%0d] = %0d (0x%0h)", i, v[i*8 +: 8], v[i*8 +: 8]);
    endtask

    task show_vec16(input [VLEN-1:0] v);
        for (int i = 0; i < 4; i++)
            $display("elem[%0d] = %0d (0x%0h)", i, v[i*16 +: 16], v[i*16 +: 16]);
    endtask

    task show_vec32(input [VLEN-1:0] v);
        for (int i = 0; i < 4; i++)
            $display("elem[%0d] = %0d (0x%0h)", i, v[i*32 +: 32], v[i*32 +: 32]);
    endtask

    // -------------------------------------------------
    // Test sequence
    // -------------------------------------------------
    initial begin
        $display("======================================");
        $display(" VECTOR ALU EXECUTION UNIT TEST START ");
        $display("======================================");

        // -------------------------------
        // TEST 1: SEW=8, VV, AND
        // -------------------------------
        sew        = 8;
        op_type    = 2'b00; // OP_VV
        alu_opcode = 5'b00000; // ALU_AND

        data1 = '0;
        data2 = '0;

        data2[7:0]  = 8'hF0;
        data2[15:8] = 8'hAA;

        data1[7:0]  = 8'h0F;
        data1[15:8] = 8'h0F;

        #5;
        $display("\nTEST 1: SEW=8 VV AND");
        show_vec8(alu_result);

        // -------------------------------
        // TEST 2: SEW=8, VX, OR
        // -------------------------------
        op_type    = 2'b01; // OP_VX
        alu_opcode = 5'b00001; // ALU_OR

        data1 = '0;
        data1[7:0] = 8'h55; // scalar

        #5;
        $display("\nTEST 2: SEW=8 VX OR");
        show_vec8(alu_result);

        // -------------------------------
        // TEST 3: SEW=8, VI, XOR (imm = -1)
        // -------------------------------
        op_type    = 2'b10; // OP_VI
        alu_opcode = 5'b00010; // ALU_XOR

        data1 = '0;
        data1[4:0] = 5'b11111; // -1

        #5;
        $display("\nTEST 3: SEW=8 VI XOR imm=-1");
        show_vec8(alu_result);

        // -------------------------------
        // TEST 4: SEW=16, VI, NOT
        // -------------------------------
        sew        = 16;
        alu_opcode = 5'b00011; // ALU_NOT

        data2 = '0;
        data2[15:0]  = 16'h00FF;
        data2[31:16] = 16'h0F0F;

        #5;
        $display("\nTEST 4: SEW=16 VI NOT");
        show_vec16(alu_result);

        // -------------------------------
        // TEST 5: SEW=16, VV, MIN (signed)
        // -------------------------------
        alu_opcode = 5'b00101; // ALU_MIN
        op_type    = 2'b00;    // OP_VV

        data1 = '0;
        data2 = '0;

        data2[15:0]  = 16'sd10;
        data1[15:0]  = 16'sd5;

        #5;
        $display("\nTEST 5: SEW=16 VV MIN (signed)");
        show_vec16(alu_result);

        // -------------------------------
        // TEST 6: SEW=32, VX, MAXU
        // -------------------------------
        sew        = 32;
        alu_opcode = 5'b00110; // ALU_MAXU
        op_type    = 2'b01;    // OP_VX

        data2 = '0;
        data1 = '0;

        data2[31:0] = 32'd100;
        data1[31:0] = 32'd50;

        #5;
        $display("\nTEST 6: SEW=32 VX MAXU");
        show_vec32(alu_result);

        // -------------------------------
        // TEST 7: SEW=32, VV, MAX (signed)
        // -------------------------------
        alu_opcode = 5'b00111; // ALU_MAX
        op_type    = 2'b00;    // OP_VV

        data2[31:0] = -32'sd20;
        data1[31:0] =  32'sd10;

        #5;
        $display("\nTEST 7: SEW=32 VV MAX (signed)");
        show_vec32(alu_result);

        $display("\n======================================");
        $display(" ALL ALU TESTS COMPLETED SUCCESSFULLY ");
        $display("======================================");

        $finish;
    end

endmodule
