`include "vec_regfile_defs.svh"

module vec_regfile_tb;

    //==========================================================================
    // Parameters
    //==========================================================================
    localparam ADDR_W = `XLEN;         // 32 registers
    localparam DATA_W = `MAX_VLEN;   // max LMUL=8

    //==========================================================================
    // DUT Signals
    //==========================================================================
    logic                       clk, reset;
    logic   [ADDR_W-1:0]        raddr_1, raddr_2;
    logic   [DATA_W-1:0]        wdata;
    logic   [ADDR_W-1:0]        waddr;
    logic                       wr_en;
    logic   [3:0]               lmul, emul;
    logic                       offset_vec_en;
    logic                       mask_operation;
    logic                       mask_wr_en;

    logic   [DATA_W-1:0]        rdata_1, rdata_2, rdata_3;
    logic   [DATA_W-1:0]        dst_data;
    logic   [VECTOR_LENGTH-1:0] vector_length;
    logic                       wrong_addr;
    logic   [`VLEN-1:0]         v0_mask_data;
    logic                       data_written;

    //==========================================================================
    // DUT Instantiation
    //==========================================================================
    vec_regfile DUT (
        .clk            (clk),
        .reset          (reset),
        .raddr_1        (raddr_1),
        .raddr_2        (raddr_2),
        .wdata          (wdata),
        .waddr          (waddr),
        .wr_en          (wr_en),
        .lmul           (lmul),
        .emul           (emul),
        .offset_vec_en  (offset_vec_en),
        .mask_operation (mask_operation),
        .mask_wr_en     (mask_wr_en),
        .rdata_1        (rdata_1),
        .rdata_2        (rdata_2),
        .rdata_3        (rdata_3),
        .dst_data       (dst_data),
        .vector_length  (vector_length),
        .wrong_addr     (wrong_addr),
        .v0_mask_data   (v0_mask_data),
        .data_written   (data_written)
    );

    //==========================================================================
    // Clock Generation — 10ns period
    //==========================================================================
    initial clk = 0;
    always #5 clk = ~clk;

    //==========================================================================
    // Task: Reset
    //==========================================================================
    task do_reset();
        reset          = 0;
        wr_en          = 0;
        mask_wr_en     = 0;
        mask_operation = 0;
        offset_vec_en  = 0;
        raddr_1        = 0;
        raddr_2        = 0;
        waddr          = 0;
        wdata          = 0;
        lmul           = 4'b0001;
        emul           = 4'b0001;
        @(negedge clk);
        reset = 1;
        @(negedge clk);
        $display("✅ RESET DONE");
    endtask

    //==========================================================================
    // Task: Write Single Register (LMUL=1)
    //==========================================================================
    task write_reg(
        input [ADDR_W-1:0]  addr,
        input [DATA_W-1:0]  data,
        input [3:0]         lmul_val
    );
        @(negedge clk);
        waddr  = addr;
        wdata  = data;
        lmul   = lmul_val;
        wr_en  = 1;
        @(negedge clk);
        wr_en  = 0;
        @(posedge clk); #1;
        if (data_written)
            $display("✅ WRITE OK | addr=%0d | data=%0h | lmul=%0b", addr, data, lmul_val);
        else
            $display("❌ WRITE FAILED | addr=%0d", addr);
    endtask

    //==========================================================================
    // Task: Read and Check
    //==========================================================================
    task read_check(
        input [ADDR_W-1:0]  r1, r2,
        input [DATA_W-1:0]  expected_r1, expected_r2,
        input [3:0]         lmul_val, emul_val,
        input               off_en
    );
        @(posedge clk); #1;
        raddr_1       = r1;
        raddr_2       = r2;
        lmul          = lmul_val;
        emul          = emul_val;
        offset_vec_en = off_en;
        mask_operation = 0;
        #1; // combinational settle
        if (rdata_1 === expected_r1)
            $display("✅ READ r1 OK  | addr=%0d | data=%0h", r1, rdata_1);
        else
            $display("❌ READ r1 FAIL| addr=%0d | got=%0h | expected=%0h", r1, rdata_1, expected_r1);

        if (rdata_2 === expected_r2)
            $display("✅ READ r2 OK  | addr=%0d | data=%0h", r2, rdata_2);
        else
            $display("❌ READ r2 FAIL| addr=%0d | got=%0h | expected=%0h", r2, rdata_2, expected_r2);
    endtask

    //==========================================================================
    // Main Test
    //==========================================================================
    initial begin
        $dumpfile("vec_regfile_tb.vcd");
        $dumpvars(0, vec_regfile_tb);

        //----------------------------------------------------------------------
        // TEST 1: Reset Check
        //----------------------------------------------------------------------
        $display("\n===== TEST 1: RESET =====");
        do_reset();
        if (wrong_addr === 0 && data_written === 0)
            $display("✅ Reset state correct");
        else
            $display("❌ Reset state wrong");

        //----------------------------------------------------------------------
        // TEST 2: LMUL=1 Write + Read
        //----------------------------------------------------------------------
        $display("\n===== TEST 2: LMUL=1 Write/Read =====");
        write_reg(5'd1, {{7*`VLEN{1'b0}}, {`VLEN{1'hAA}}}, 4'b0001);
        write_reg(5'd2, {{7*`VLEN{1'b0}}, {`VLEN{1'hBB}}}, 4'b0001);
        read_check(
            5'd1, 5'd2,
            {{7*`VLEN{1'b0}}, {`VLEN{1'hAA}}},
            {{7*`VLEN{1'b0}}, {`VLEN{1'hBB}}},
            4'b0001, 4'b0001, 1'b0
        );

        //----------------------------------------------------------------------
        // TEST 3: LMUL=2 Write + Read
        //----------------------------------------------------------------------
        $display("\n===== TEST 3: LMUL=2 Write/Read =====");
        write_reg(5'd4, {{6*`VLEN{1'b0}}, {`VLEN{1'hCC}}, {`VLEN{1'hDD}}}, 4'b0010);
        read_check(
            5'd4, 5'd4,
            {{6*`VLEN{1'b0}}, {`VLEN{1'hCC}}, {`VLEN{1'hDD}}},
            {{6*`VLEN{1'b0}}, {`VLEN{1'hCC}}, {`VLEN{1'hDD}}},
            4'b0010, 4'b0010, 1'b0
        );

        //----------------------------------------------------------------------
        // TEST 4: LMUL=4 Write + Read
        //----------------------------------------------------------------------
        $display("\n===== TEST 4: LMUL=4 Write/Read =====");
        write_reg(5'd8, {
            {4*`VLEN{1'b0}},
            {`VLEN{1'h44}}, {`VLEN{1'h33}},
            {`VLEN{1'h22}}, {`VLEN{1'h11}}
        }, 4'b0100);
        read_check(
            5'd8, 5'd8,
            {
                {4*`VLEN{1'b0}},
                {`VLEN{1'h44}}, {`VLEN{1'h33}},
                {`VLEN{1'h22}}, {`VLEN{1'h11}}
            },
            {
                {4*`VLEN{1'b0}},
                {`VLEN{1'h44}}, {`VLEN{1'h33}},
                {`VLEN{1'h22}}, {`VLEN{1'h11}}
            },
            4'b0100, 4'b0100, 1'b0
        );

        //----------------------------------------------------------------------
        // TEST 5: LMUL=8 Write + Read
        //----------------------------------------------------------------------
        $display("\n===== TEST 5: LMUL=8 Write/Read =====");
        write_reg(5'd16, {
            {`VLEN{1'h88}}, {`VLEN{1'h77}}, {`VLEN{1'h66}}, {`VLEN{1'h55}},
            {`VLEN{1'h44}}, {`VLEN{1'h33}}, {`VLEN{1'h22}}, {`VLEN{1'h11}}
        }, 4'b1000);
        read_check(
            5'd16, 5'd16,
            {
                {`VLEN{1'h88}}, {`VLEN{1'h77}}, {`VLEN{1'h66}}, {`VLEN{1'h55}},
                {`VLEN{1'h44}}, {`VLEN{1'h33}}, {`VLEN{1'h22}}, {`VLEN{1'h11}}
            },
            {
                {`VLEN{1'h88}}, {`VLEN{1'h77}}, {`VLEN{1'h66}}, {`VLEN{1'h55}},
                {`VLEN{1'h44}}, {`VLEN{1'h33}}, {`VLEN{1'h22}}, {`VLEN{1'h11}}
            },
            4'b1000, 4'b1000, 1'b0
        );

        //----------------------------------------------------------------------
        // TEST 6: Mask Write + Read (v0)
        //----------------------------------------------------------------------
        $display("\n===== TEST 6: MASK Write/Read =====");
        @(negedge clk);
        mask_wr_en = 1;
        waddr      = 5'd0;
        wdata      = {{7*`VLEN{1'b0}}, {`VLEN{1'hFF}}};
        lmul       = 4'b0001;
        @(negedge clk);
        mask_wr_en = 0;
        @(posedge clk); #1;
        if (v0_mask_data === {`VLEN{1'hFF}})
            $display("✅ MASK WRITE OK | v0=%0h", v0_mask_data);
        else
            $display("❌ MASK WRITE FAIL | got=%0h", v0_mask_data);

        //----------------------------------------------------------------------
        // TEST 7: Mask Operation Read
        //----------------------------------------------------------------------
        $display("\n===== TEST 7: MASK OPERATION Read =====");
        write_reg(5'd3, {{7*`VLEN{1'b0}}, {`VLEN{1'hAB}}}, 4'b0001);
        @(posedge clk); #1;
        mask_operation = 1;
        raddr_1        = 5'd0;
        raddr_2        = 5'd3;
        lmul           = 4'b0001;
        #1;
        $display("mask_op rdata_1(v0)=%0h | rdata_2(v3)=%0h", rdata_1, rdata_2);
        mask_operation = 0;

        //----------------------------------------------------------------------
        // TEST 8: Invalid Address — wrong_addr check
        //----------------------------------------------------------------------
        $display("\n===== TEST 8: INVALID ADDRESS =====");
        @(negedge clk);
        waddr  = 5'd31;     // invalid for LMUL=2 (odd addr)
        wdata  = {DATA_W{1'b1}};
        lmul   = 4'b0010;
        wr_en  = 1;
        @(negedge clk);
        wr_en  = 0;
        @(posedge clk); #1;
        if (wrong_addr)
            $display("✅ INVALID ADDR detected correctly");
        else
            $display("❌ INVALID ADDR not detected");

        //----------------------------------------------------------------------
        // TEST 9: offset_vec_en — EMUL based rdata_2
        //----------------------------------------------------------------------
        $display("\n===== TEST 9: OFFSET VEC (EMUL) =====");
        write_reg(5'd6, {{6*`VLEN{1'b0}}, {`VLEN{1'hEE}}, {`VLEN{1'hFF}}}, 4'b0010);
        @(posedge clk); #1;
        raddr_2       = 5'd6;
        emul          = 4'b0010;
        lmul          = 4'b0001;
        offset_vec_en = 1'b1;
        #1;
        $display("offset rdata_2=%0h (expected EMUL=2 read)", rdata_2);
        offset_vec_en = 0;

        //----------------------------------------------------------------------
        $display("\n===== ALL TESTS DONE =====");
        $finish;
    end

    // Timeout watchdog
    initial begin
        #100000;
        $display("❌ TIMEOUT");
        $finish;
    end

endmodule