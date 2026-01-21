module tb_vector_shift_unit;

    // Parameters
    localparam VLEN = 512;
    localparam ELEN = 32;

    // DUT signals
    logic [VLEN-1:0] data1;
    logic [VLEN-1:0] data2;
    logic [1:0]      op_type;
    logic [2:0]      shift_op;
    logic [6:0]      sew;

    logic [VLEN-1:0] shift_result;
    logic            shift_done;

    // Instantiate DUT
    vector_shift_unit #(
        .VLEN(VLEN),
        .ELEN(ELEN)
    ) dut (
        .data1(data1),
        .data2(data2),
        .op_type(op_type),
        .shift_op(shift_op),
        .sew(sew),
        .shift_result(shift_result),
        .shift_done(shift_done)
    );

    // ----------------------------------
    // Task: Display vector elements
    // ----------------------------------
    task display_vector_8;
        input [VLEN-1:0] vec;
        begin
            for (int i = 0; i < 8; i++)
                $display("elem[%0d] = %0d", i, vec[i*8 +: 8]);
        end
    endtask

    task display_vector_16;
        input [VLEN-1:0] vec;
        begin
            for (int i = 0; i < 4; i++)
                $display("elem[%0d] = %0d", i, vec[i*16 +: 16]);
        end
    endtask

    task display_vector_32;
        input [VLEN-1:0] vec;
        begin
            for (int i = 0; i < 4; i++)
                $display("elem[%0d] = %0d", i, vec[i*32 +: 32]);
        end
    endtask

    // ----------------------------------
    // Test stimulus
    // ----------------------------------
    initial begin
        $display("====================================");
        $display(" VECTOR SHIFT UNIT TESTBENCH START ");
        $display("====================================");

        // ----------------------------------
        // TEST 1: SEW = 8, VV, SLL
        // ----------------------------------
        sew      = 8;
        op_type = 2'b00; // OP_VV
        shift_op= 3'b000; // SLL

        data2 = '0;
        data1 = '0;

        // vs2 data
        data2[7:0]   = 8'd10;
        data2[15:8]  = 8'd20;

        // vs1 shift amounts
        data1[7:0]   = 8'd1;
        data1[15:8]  = 8'd2;

        #5;
        $display("\nTEST 1: SEW=8 VV SLL");
        display_vector_8(shift_result);

        // ----------------------------------
        // TEST 2: SEW = 8, VX, SRL
        // ----------------------------------
        op_type = 2'b01; // OP_VX
        shift_op= 3'b001; // SRL

        data1 = '0;
        data1[7:0] = 8'd2; // scalar shift

        #5;
        $display("\nTEST 2: SEW=8 VX SRL");
        display_vector_8(shift_result);

        // ----------------------------------
        // TEST 3: SEW = 16, VI, SRA
        // ----------------------------------
        sew      = 16;
        op_type = 2'b10; // OP_VI
        shift_op= 3'b010; // SRA

        data2 = '0;
        data1 = '0;

        data2[15:0]  = 16'sd64;
        data2[31:16] = 16'sd128;

        data1[4:0]   = 5'd3; // immediate shift

        #5;
        $display("\nTEST 3: SEW=16 VI SRA");
        display_vector_16(shift_result);

        // ----------------------------------
        // TEST 4: SEW = 32, VV, SLL
        // ----------------------------------
        sew      = 32;
        op_type = 2'b00; // OP_VV
        shift_op= 3'b000; // SLL

        data2 = '0;
        data1 = '0;

        data2[31:0]  = 32'd5;
        data1[31:0]  = 32'd3;

        #5;
        $display("\nTEST 4: SEW=32 VV SLL");
        display_vector_32(shift_result);

        // ----------------------------------
        // Finish simulation
        // ----------------------------------
        $display("\n====================================");
        $display(" ALL TESTS COMPLETED ");
        $display("====================================");

        $finish;
    end

endmodule
