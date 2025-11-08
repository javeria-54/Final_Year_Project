module adder_subtractor_tb;

    localparam WIDTH = 512;

    logic              Ctrl;
    logic              sew_16_32;
    logic              sew_32;
    logic signed [WIDTH-1:0] A;
    logic signed [WIDTH-1:0] B;
    logic signed [WIDTH-1:0] Sum;
    logic signed [WIDTH-1:0] expected_sum;

    integer pass_count = 0;
    integer fail_count = 0;
    integer total_tests = 0;

    // ================= DUT INSTANTIATION =================
    adder_subtractor #(.WIDTH(WIDTH)) dut (
        .Ctrl      (Ctrl),
        .sew_16_32 (sew_16_32),
        .sew_32    (sew_32),
        .A         (A),
        .B         (B),
        .Sum       (Sum)
    );

    // =====================================================
    //  FUNCTION: SEGMENTED EXPECTED RESULT CALCULATION
    // =====================================================
    function automatic [WIDTH-1:0] segmented_add_sub(
        input logic [WIDTH-1:0] A,
        input logic [WIDTH-1:0] B,
        input logic Ctrl,
        input logic sew_16_32,
        input logic sew_32
    );
        integer i;
        reg [WIDTH-1:0] result;
        logic signed [31:0] a_seg, b_seg, res_seg;

        begin
            result = '0;

            // -------- 8-bit mode --------
            if (!sew_16_32 && !sew_32) begin
                for (i = 0; i < WIDTH/8; i++) begin
                    a_seg = $signed(A[i*8 +: 8]);
                    b_seg = $signed(B[i*8 +: 8]);
                    res_seg = (Ctrl) ? (a_seg - b_seg) : (a_seg + b_seg);
                    result[i*8 +: 8] = res_seg[7:0];
                end
            end

            // -------- 16-bit mode --------
            else if (sew_16_32 && !sew_32) begin
                for (i = 0; i < WIDTH/16; i++) begin
                    a_seg = $signed(A[i*16 +: 16]);
                    b_seg = $signed(B[i*16 +: 16]);
                    res_seg = (Ctrl) ? (a_seg - b_seg) : (a_seg + b_seg);
                    result[i*16 +: 16] = res_seg[15:0];
                end
            end

            // -------- 32-bit mode --------
            else begin
                for (i = 0; i < WIDTH/32; i++) begin
                    a_seg = $signed(A[i*32 +: 32]);
                    b_seg = $signed(B[i*32 +: 32]);
                    res_seg = (Ctrl) ? (a_seg - b_seg) : (a_seg + b_seg);
                    result[i*32 +: 32] = res_seg[31:0];
                end
            end

            return result;
        end
    endfunction


    // =====================================================
    //  TASK: RUN SINGLE TEST CASE
    // =====================================================
    task run_case(
        input logic ctrl_val,
        input logic sew16_32_val,
        input logic sew32_val,
        input logic signed [WIDTH-1:0] a_val,
        input logic signed [WIDTH-1:0] b_val,
        input string case_name
    );
    begin
        Ctrl = ctrl_val;
        sew_16_32 = sew16_32_val;
        sew_32 = sew32_val;
        A = a_val;
        B = b_val;
        #10;

        expected_sum = segmented_add_sub(A, B, Ctrl, sew_16_32, sew_32);
        total_tests++;

        if (Sum === expected_sum) begin
            pass_count++;
            $display("[%0t] %-25s |  PASS | Ctrl=%0b sew16_32=%0b sew_32=%0b",
                     $time, case_name, Ctrl, sew_16_32, sew_32);
        end else begin
            fail_count++;
            $display("[%0t] %-25s |  FAIL | Ctrl=%0b sew16_32=%0b sew_32=%0b",
                     $time, case_name, Ctrl, sew_16_32, sew_32);
            $display("   A=%h\n   B=%h\n   DUT Sum=%h\n   Expected=%h\n",
                      A, B, Sum, expected_sum);
        end
    end
    endtask


    // =====================================================
    //  MAIN TEST SEQUENCE
    // =====================================================
    integer i;
    initial begin
        $display("==============================================");
        $display("     🚀 Starting 512-bit Adder/Subtractor Testbench     ");
        $display("==============================================");

        // =============== BASIC TESTS ===============
        run_case(0,0,0,{16{32'hF7F7F7F7}},{16{32'h12121212}},"ADD 8-bit replicated");
        run_case(1,0,0,{16{32'hF7F7F7F7}},{16{32'h12121212}},"SUB 8-bit replicated");

        run_case(0,1,0,{16{32'hF0F6F0F6}},{16{32'h23242324}},"ADD 16-bit replicated");
        run_case(1,1,0,{16{32'hF0F6F0F6}},{16{32'h23242324}},"SUB 16-bit replicated");

        run_case(0,1,1,{16{32'h12345678}},{16{32'hFFFFFFFF}},"ADD 32-bit replicated");
        run_case(1,1,1,{16{32'h12345678}},{16{32'hFFFFFFFF}},"SUB 32-bit replicated");

        // =============== EDGE CASES ===============
        run_case(0,0,0,'0,'0,"Zero + Zero");
        run_case(1,0,0,'0,'0,"Zero - Zero");
        run_case(0,1,1,'1,'1,"1 + 1 (carry test)");
        run_case(1,1,1,'1,'0,"1 - 0");
        run_case(1,1,1,'0,'1,"0 - 1 (underflow test)");
        run_case(0,1,0,{16{32'h7FFFFFFF}},{16{32'h00000001}},"Positive Overflow");
        run_case(1,1,0,{16{32'h80000000}},{16{32'h00000001}},"Negative Overflow");

        // =============== ALTERNATING BIT PATTERNS ===============
        run_case(0,0,0,{16{32'hAAAAAAAA}},{16{32'h55555555}},"Add AAAAAAAA + 55555555");
        run_case(1,0,0,{16{32'hAAAAAAAA}},{16{32'h55555555}},"Sub AAAAAAAA - 55555555");
        run_case(0,1,1,{16{32'h5555AAAA}},{16{32'hAAAA5555}},"Mix pattern add");
        run_case(1,1,1,{16{32'h5555AAAA}},{16{32'hAAAA5555}},"Mix pattern sub");

        // =============== SIGNED BOUNDARY VALUES ===============
        run_case(0,1,1,{16{32'h7FFFFFFF}},{16{32'h00000001}},"Signed max + 1");
        run_case(1,1,1,{16{32'h80000000}},{16{32'h00000001}},"Signed min - 1");
        run_case(0,1,1,{16{32'hFFFFFFFF}},{16{32'h00000001}},"-1 + 1");
        run_case(1,1,1,{16{32'hFFFFFFFF}},{16{32'h00000001}},"-1 - 1");
        run_case(0,1,1,{16{32'h00000001}},{16{32'hFFFFFFFF}},"1 + (-1)");
        run_case(1,1,1,{16{32'h00000001}},{16{32'hFFFFFFFF}},"1 - (-1)");

        // =============== LARGE VALUE PATTERNS ===============
        run_case(0,1,1,{16{32'hFFFFFFFE}},{16{32'h00000002}},"Large numbers add");
        run_case(1,1,1,{16{32'hFFFFFFFE}},{16{32'h00000002}},"Large numbers sub");
        run_case(0,1,1,{16{32'h0000FFFF}},{16{32'h00000001}},"Halfword overflow test");
        run_case(1,1,1,{16{32'h0000FFFF}},{16{32'h00000001}},"Halfword underflow test");

        run_case(0,1,0,{16{32'h01010101}},{16{32'h02020202}},"8-bit simple add");
        run_case(1,1,0,{16{32'h01010101}},{16{32'h02020202}},"8-bit simple sub");
        run_case(0,1,1,{16{32'h11111111}},{16{32'h22222222}},"32-bit add pattern");
        run_case(1,1,1,{16{32'h11111111}},{16{32'h22222222}},"32-bit sub pattern");

        // =============== SUMMARY ===============
        $display("==============================================");
        $display(" Total Tests : %0d", total_tests);
        $display(" Passed      : %0d", pass_count);
        $display(" Failed      : %0d", fail_count);
        $display("==============================================");

        if (fail_count == 0)
            $display("ALL TESTS PASSED SUCCESSFULLY ");
        else
            $display("SOME TESTS FAILED ");

        $finish;
    end

endmodule
