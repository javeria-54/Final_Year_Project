`timescale 1ns/1ps

module tb_vector_bitwise_unit;

    parameter VLEN = 32;
    parameter ELEN = 32;

    logic [VLEN-1:0] dataA;
    logic [VLEN-1:0] dataB;
    logic [4:0]      bitwise_op;
    logic [1:0]      sew;

    logic [VLEN-1:0] bitwise_result;
    logic             bitwise_done;

    //-----------------------------------------
    // DUT
    //-----------------------------------------
    vector_bitwise_unit bitwise_unit (
        .dataA(dataA),
        .dataB(dataB),
        .bitwise_op(bitwise_op),
        .sew(sew),
        .bitwise_result(bitwise_result),
        .bitwise_done(bitwise_done)
    );

    //-----------------------------------------
    // Operation names (for printing)
    //-----------------------------------------
    string op_name [8] = '{
        "AND","OR","XOR","NOT",
        "MINU","MIN","MAXU","MAX"
    };

    //-----------------------------------------
    // Print helpers
    //-----------------------------------------
    task show8;
        for (int i = 0; i < VLEN/8; i++)
            $write("%02h ", bitwise_result[i*8 +: 8]);
        $display("");
    endtask

    task show16;
        for (int i = 0; i < VLEN/16; i++)
            $write("%04h ", bitwise_result[i*16 +: 16]);
        $display("");
    endtask

    task show32;
        for (int i = 0; i < VLEN/32; i++)
            $write("%08h ", bitwise_result[i*32 +: 32]);
        $display("");
    endtask

    //-----------------------------------------
    // Initialize vectors
    //-----------------------------------------
    task init8;
        for (int i = 0; i < VLEN/8; i++) begin
            dataA[i*8 +: 8] = i + 1;
            dataB[i*8 +: 8] = 8'hF0 - i;
        end
    endtask

    task init16;
        for (int i = 0; i < VLEN/16; i++) begin
            dataA[i*16 +: 16] = 100 + i;
            dataB[i*16 +: 16] = 50 + i;
        end
    endtask

    task init32;
        for (int i = 0; i < VLEN/32; i++) begin
            dataA[i*32 +: 32] = 32'd200 + i;
            dataB[i*32 +: 32] = 32'd150 + i;
        end
    endtask

    //-----------------------------------------
    // Test sequence
    //-----------------------------------------
    initial begin
        $display("\n===== VECTOR BITWISE UNIT TB =====");

        //---------------------------------
        // 8-bit tests
        //---------------------------------
        sew = 2'b00;
        init8();

        for (int op = 0; op < 8; op++) begin
            bitwise_op = op;
            #1;
            $display("\nSEW=8  OP=%s", op_name[op]);
            show8();
        end

        //---------------------------------
        // 16-bit tests
        //---------------------------------
        sew = 2'b01;
        init16();

        for (int op = 0; op < 8; op++) begin
            bitwise_op = op;
            #1;
            $display("\nSEW=16 OP=%s", op_name[op]);
            show16();
        end

        //---------------------------------
        // 32-bit tests
        //---------------------------------
        sew = 2'b10;
        init32();

        for (int op = 0; op < 8; op++) begin
            bitwise_op = op;
            #1;
            $display("\nSEW=32 OP=%s", op_name[op]);
            show32();
        end

        $display("\nAll tests completed.");
        $finish;
    end

endmodule
