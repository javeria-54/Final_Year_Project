`timescale 1ns/1ps

module vec_decode_tb;

    // Parameters
    parameter CLK_PERIOD = 10;
    
    // Testbench signals
    logic [31:0]    vec_inst;
    logic [31:0]    rs1_data;
    logic [31:0]    rs2_data;
    logic           is_vec;
    logic [31:0]    vec_read_addr_1;
    logic [31:0]    vec_read_addr_2;
    logic [31:0]    vec_write_addr;
    logic [4095:0]   vec_imm;
    logic           vec_mask;
    logic [2:0]     width;
    logic           mew;
    logic [2:0]     nf;
    logic [31:0]    scalar2;
    logic [31:0]    scalar1;
    logic           vl_sel;
    logic           vtype_sel;
    logic           lumop_sel;
    
    // Clock generation (optional, for sequential testing)
    logic clk;
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // DUT instantiation
    vec_decode dut (
        .vec_inst(vec_inst),
        .rs1_data(rs1_data),
        .rs2_data(rs2_data),
        .is_vec(is_vec),
        .vec_read_addr_1(vec_read_addr_1),
        .vec_read_addr_2(vec_read_addr_2),
        .vec_write_addr(vec_write_addr),
        .vec_imm(vec_imm),
        .vec_mask(vec_mask),
        .width(width),
        .mew(mew),
        .nf(nf),
        .scalar2(scalar2),
        .scalar1(scalar1),
        .vl_sel(vl_sel),
        .vtype_sel(vtype_sel),
        .lumop_sel(lumop_sel)
    );
    
    // Test counter
    integer test_num = 0;
    integer pass_count = 0;
    integer fail_count = 0;
    
    // Task to check results
    task check_result(
        input string test_name,
        input logic expected_is_vec,
        input logic [31:0] expected_write_addr,
        input logic [31:0] expected_read_addr_1,
        input logic [31:0] expected_read_addr_2
    );
        test_num++;
        $display("\n[Test %0d] %s", test_num, test_name);
        $display("  Instruction: 0x%08h", vec_inst);
        
        if (is_vec === expected_is_vec &&
            vec_write_addr === expected_write_addr &&
            vec_read_addr_1 === expected_read_addr_1 &&
            vec_read_addr_2 === expected_read_addr_2) begin
            $display("  ✅ PASS");
            $display("  is_vec=%b, vd=%0d, vs1=%0d, vs2=%0d", 
                     is_vec, vec_write_addr[4:0], vec_read_addr_1[4:0], vec_read_addr_2[4:0]);
            pass_count++;
        end else begin
            $display("  ❌ FAIL");
            $display("  Expected: is_vec=%b, vd=%0d, vs1=%0d, vs2=%0d", 
                     expected_is_vec, expected_write_addr[4:0], 
                     expected_read_addr_1[4:0], expected_read_addr_2[4:0]);
            $display("  Got:      is_vec=%b, vd=%0d, vs1=%0d, vs2=%0d", 
                     is_vec, vec_write_addr[4:0], vec_read_addr_1[4:0], vec_read_addr_2[4:0]);
            fail_count++;
        end
    endtask
    
    // Task to display func6 validation
    task display_func6_status();
        $display("  vec_func6: 0x%02h, vec_op_valid: %b, vec_mask: %b", 
                 dut.vec_func6, dut.vec_op_valid, vec_mask);
    endtask
    
    // Main test sequence
    initial begin
        $display("\n========================================");
        $display("  Vector Decode Testbench");
        $display("========================================\n");
        
        // Initialize signals
        vec_inst = 0;
        rs1_data = 32'h12345678;
        rs2_data = 32'h87654321;
        vl_sel = 0;
        vtype_sel = 0;
        lumop_sel = 0;
        
        #20;
        
        //===========================================
        // Test 1: VADD.VV - Vector-Vector Add
        //===========================================
        // Instruction format: func6[31:26]=000000, vm[25]=1, vs2[24:20]=2, vs1[19:15]=3, func3[14:12]=000, vd[11:7]=1, opcode[6:0]=0x57
        vec_inst = 32'b0000000_1_00010_00011_000_00001_1010111;
        #10;
        check_result("VADD.VV v1, v2, v3", 1'b1, 32'd1, 32'd3, 32'd2);
        display_func6_status();
        
        //===========================================
        // Test 2: VADD.VI - Vector-Immediate Add
        //===========================================
        // func6=000000, vm=1, vs2=4, imm=5, func3=011, vd=2, opcode=0x57
        vec_inst = 32'b0000000_1_00100_00101_011_00010_1010111;
        #10;
        check_result("VADD.VI v2, v4, 5", 1'b1, 32'd2, 32'd0, 32'd4);
        display_func6_status();
        $display("  vec_imm: 0x%0h", vec_imm);
        
        //===========================================
        // Test 3: VADD.VX - Vector-Scalar Add
        //===========================================
        // func6=000000, vm=1, vs2=5, rs1=6, func3=100, vd=3, opcode=0x57
        vec_inst = 32'b0000000_1_00101_00110_100_00011_1010111;
        #10;
        check_result("VADD.VX v3, v5, x6", 1'b1, 32'd3, 32'd0, 32'd5);
        display_func6_status();
        $display("  vec_imm (scalar): 0x%08h", vec_imm[31:0]);
        
        //===========================================
        // Test 4: VSUB.VV - Vector-Vector Subtract
        //===========================================
        // func6=000010, vm=1, vs2=7, vs1=8, func3=000, vd=4, opcode=0x57
        vec_inst = 32'b0000100_1_00111_01000_000_00100_1010111;
        #10;
        check_result("VSUB.VV v4, v7, v8", 1'b1, 32'd4, 32'd8, 32'd7);
        display_func6_status();
        
        //===========================================
        // Test 5: VMUL.VV - Vector-Vector Multiply
        //===========================================
        // func6=100101, vm=1, vs2=9, vs1=10, func3=010 (OPMVV), vd=5, opcode=0x57
        vec_inst = 32'b1001010_1_01001_01010_010_00101_1010111;
        #10;
        check_result("VMUL.VV v5, v9, v10", 1'b1, 32'd5, 32'd10, 32'd9);
        display_func6_status();
        
        //===========================================
        // Test 6: VMUL.VX - Vector-Scalar Multiply
        //===========================================
        // func6=100101, vm=1, vs2=11, rs1=12, func3=110 (OPMVX), vd=6, opcode=0x57
        vec_inst = 32'b1001010_1_01011_01100_110_00110_1010111;
        #10;
        check_result("VMUL.VX v6, v11, x12", 1'b1, 32'd6, 32'd0, 32'd11);
        display_func6_status();
        
        //===========================================
        // Test 7: VAND.VV - Vector AND
        //===========================================
        // func6=001001, vm=1, vs2=13, vs1=14, func3=000, vd=7, opcode=0x57
        vec_inst = 32'b0010010_1_01101_01110_000_00111_1010111;
        #10;
        check_result("VAND.VV v7, v13, v14", 1'b1, 32'd7, 32'd14, 32'd13);
        display_func6_status();
        
        //===========================================
        // Test 8: VOR.VI - Vector OR with Immediate
        //===========================================
        // func6=001010, vm=1, vs2=15, imm=7, func3=011, vd=8, opcode=0x57
        vec_inst = 32'b0010100_1_01111_00111_011_01000_1010111;
        #10;
        check_result("VOR.VI v8, v15, 7", 1'b1, 32'd8, 32'd0, 32'd15);
        display_func6_status();
        
        //===========================================
        // Test 9: VSLL.VX - Vector Shift Left Logical
        //===========================================
        // func6=100101, vm=1, vs2=16, rs1=5, func3=100, vd=9, opcode=0x57
        vec_inst = 32'b1001010_1_10000_00101_100_01001_1010111;
        #10;
        check_result("VSLL.VX v9, v16, x5", 1'b1, 32'd9, 32'd0, 32'd16);
        display_func6_status();
        
        //===========================================
        // Test 10: VSETVLI - Vector Configuration
        //===========================================
        // inst[31:30]=00 (VSETVLI), zimm[30:20], rs1=15, func3=111, rd=10, opcode=0x57
        vec_inst = 32'b0_00000000000_01111_111_01010_1010111;
        rs1_data = 32'd64;  // AVL
        vl_sel = 0;
        vtype_sel = 1;
        #10;
        $display("\n[Test %0d] VSETVLI", ++test_num);
        $display("  Instruction: 0x%08h", vec_inst);
        $display("  scalar1 (AVL): %0d", scalar1);
        $display("  scalar2 (vtype): 0x%08h", scalar2);
        if (is_vec) pass_count++; else fail_count++;
        
        //===========================================
        // Test 11: Vector Load Unit-Stride
        //===========================================
        // nf[31:29]=0, mew[28]=0, mop[27:26]=00, vm[25]=1, lumop[24:20]=0, 
        // rs1=20, width[14:12]=000, vd=11, opcode=0x07
        vec_inst = 32'b000_0_00_1_00000_10100_000_01011_0000111;
        rs1_data = 32'h1000;
        #10;
        $display("\n[Test %0d] VLE8.V (Unit-stride load)", ++test_num);
        $display("  Instruction: 0x%08h", vec_inst);
        $display("  is_vec=%b, vd=%0d, width=%0d, nf=%0d", 
                 is_vec, vec_write_addr[4:0], width, nf);
        if (is_vec && vec_write_addr[4:0] == 11) pass_count++; else fail_count++;
        
        //===========================================
        // Test 12: Vector Store Unit-Stride
        //===========================================
        // nf[31:29]=0, mew[28]=0, mop[27:26]=00, vm[25]=1, lumop[24:20]=0,
        // rs1=21, width[14:12]=010, vs3=12, opcode=0x27
        vec_inst = 32'b000_0_00_1_00000_10101_010_01100_0100111;
        rs1_data = 32'h2000;
        #10;
        $display("\n[Test %0d] VSE32.V (Unit-stride store)", ++test_num);
        $display("  Instruction: 0x%08h", vec_inst);
        $display("  is_vec=%b, vs3=%0d, width=%0d", 
                 is_vec, vec_read_addr_2[4:0], width);
        if (is_vec && width == 3'd2) pass_count++; else fail_count++;
        
        //===========================================
        // Test 13: Invalid Instruction (wrong opcode)
        //===========================================
        vec_inst = 32'b0000000_1_00010_00011_000_00001_0110011; // R-type, not vector
        #10;
        $display("\n[Test %0d] Invalid Instruction (scalar opcode)", ++test_num);
        $display("  Instruction: 0x%08h", vec_inst);
        $display("  is_vec=%b (should be 0)", is_vec);
        if (!is_vec) pass_count++; else fail_count++;
        
        //===========================================
        // Test 14: VMINU.VV - Unsigned Minimum
        //===========================================
        // func6=000100, vm=1, vs2=5, vs1=6, func3=000, vd=13, opcode=0x57
        vec_inst = 32'b0001000_1_00101_00110_000_01101_1010111;
        #10;
        check_result("VMINU.VV v13, v5, v6", 1'b1, 32'd13, 32'd6, 32'd5);
        display_func6_status();
        
        //===========================================
        // Test 15: VMAX.VX - Signed Maximum
        //===========================================
        // func6=000111, vm=1, vs2=7, rs1=8, func3=100, vd=14, opcode=0x57
        vec_inst = 32'b0001110_1_00111_01000_100_01110_1010111;
        #10;
        check_result("VMAX.VX v14, v7, x8", 1'b1, 32'd14, 32'd0, 32'd7);
        display_func6_status();
        
        //===========================================
        // Test 16: VMSLT.VV - Set if Less Than (signed)
        //===========================================
        // func6=011011, vm=1, vs2=9, vs1=10, func3=000, vd=15, opcode=0x57
        vec_inst = 32'b0110110_1_01001_01010_000_01111_1010111;
        #10;
        check_result("VMSLT.VV v15, v9, v10", 1'b1, 32'd15, 32'd10, 32'd9);
        display_func6_status();
        
        //===========================================
        // Test 17: Masked Operation (vm=0)
        //===========================================
        // func6=000000, vm=0 (masked), vs2=11, vs1=12, func3=000, vd=16, opcode=0x57
        vec_inst = 32'b0000000_0_01011_01100_000_10000_1010111;
        #10;
        check_result("VADD.VV v16, v11, v12 (masked)", 1'b1, 32'd16, 32'd12, 32'd11);
        $display("  Mask enabled: vm=%b", vec_mask);
        display_func6_status();
        
        //===========================================
        // Test Summary
        //===========================================
        #20;
        $display("\n========================================");
        $display("  Test Summary");
        $display("========================================");
        $display("  Total Tests: %0d", test_num);
        $display("  Passed:      %0d", pass_count);
        $display("  Failed:      %0d", fail_count);
        
        if (fail_count == 0) begin
            $display("\n  ✅ ALL TESTS PASSED! ✅\n");
        end else begin
            $display("\n  ❌ SOME TESTS FAILED ❌\n");
        end
        
        $display("========================================\n");
        $finish;
    end
    
    // Waveform dump
    initial begin
        $dumpfile("vec_decode_tb.vcd");
        $dumpvars(0, vec_decode_tb);
    end

endmodule