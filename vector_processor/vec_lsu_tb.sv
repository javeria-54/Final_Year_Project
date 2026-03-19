// ============================================================================
// File        : tb_vec_lsu.sv
// Author      : Zawaher Bin Asim , UET Lahore
// Description : Minimal testbench for vec_lsu.
//               Every LSU mode is exercised in a single flat initial block,
//               with no complex helper infrastructure.
// ============================================================================

`timescale 1ns/1ps
`include "vec_regfile_defs.svh"
`include "axi_4_defs.svh"

module tb_vec_lsu;

    // -------------------------------------------------------------------------
    // Parameters
    // -------------------------------------------------------------------------
    localparam XLEN    = `XLEN;
    localparam MVLEN   = `MAX_VLEN;
    localparam DBW     = `DATA_BUS_WIDTH;   // 512
    localparam BMAX    = `BURST_MAX;        // 16
    localparam STROBEW = `STROBE_WIDTH;     // 64

    // -------------------------------------------------------------------------
    // DUT signals
    // -------------------------------------------------------------------------
    logic                    clk, n_rst;
    logic [XLEN-1:0]         rs1_data, rs2_data;
    logic [9:0]              vlmax;
    logic [6:0]              sew;
    logic                    stride_sel, ld_inst, st_inst;
    logic                    index_str, index_unordered;
    logic [MVLEN-1:0]        vs2_data, vs3_data;
    logic                    mew;
    logic [2:0]              width;
    logic                    inst_done;

    logic [XLEN-1:0]         lsu2mem_addr;
    logic [DBW*BMAX-1:0]     lsu2mem_data;
    logic                    ld_req, st_req;
    logic [STROBEW*BMAX-1:0] wr_strobe;
    logic [7:0]              burst_len;
    logic [2:0]              burst_size;
    logic [1:0]              burst_type;

    logic [DBW*BMAX-1:0]     mem2lsu_data;
    logic                    burst_valid_data, burst_wr_valid;

    logic [MVLEN-1:0]        vd_data;
    logic                    is_loaded, is_stored, error_flag;

    // -------------------------------------------------------------------------
    // DUT instantiation
    // -------------------------------------------------------------------------
    vec_lsu dut (
        .clk(clk),               .n_rst(n_rst),
        .rs1_data(rs1_data),     .rs2_data(rs2_data),
        .vlmax(vlmax),           .sew(sew),
        .stride_sel(stride_sel), .ld_inst(ld_inst),    .st_inst(st_inst),
        .index_str(index_str),   .index_unordered(index_unordered),
        .vs2_data(vs2_data),     .vs3_data(vs3_data),
        .mew(mew),               .width(width),         .inst_done(inst_done),
        .lsu2mem_addr(lsu2mem_addr), .lsu2mem_data(lsu2mem_data),
        .ld_req(ld_req),         .st_req(st_req),       .wr_strobe(wr_strobe),
        .burst_len(burst_len),   .burst_size(burst_size), .burst_type(burst_type),
        .mem2lsu_data(mem2lsu_data),
        .burst_valid_data(burst_valid_data), .burst_wr_valid(burst_wr_valid),
        .vd_data(vd_data),       .is_loaded(is_loaded),
        .is_stored(is_stored),   .error_flag(error_flag)
    );

    // -------------------------------------------------------------------------
    // Clock  (10 ns period)
    // -------------------------------------------------------------------------
    initial clk = 1'b0;
    always  #5 clk = ~clk;

    // -------------------------------------------------------------------------
    // Score-board
    // -------------------------------------------------------------------------
    int pass_cnt = 0, fail_cnt = 0;

    task automatic chk(input string name, input logic ok);
        if (ok) begin $display("  [PASS] %s", name); pass_cnt++; end
        else    begin $display("  [FAIL] %s  @%0t ns", name, $time); fail_cnt++; end
    endtask

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------

    // Reset + zero all inputs
    task automatic do_reset();
        n_rst=0; rs1_data=0; rs2_data=0; vlmax=0; sew=0;
        stride_sel=0; ld_inst=0; st_inst=0;
        index_str=0; index_unordered=0;
        vs2_data=0; vs3_data=0; mew=0; width=0; inst_done=0;
        mem2lsu_data=0; burst_valid_data=0; burst_wr_valid=0;
        repeat(4) @(posedge clk);
        n_rst=1; @(posedge clk);
    endtask

    // Pulse inst_done and clear instruction enables
    task automatic end_inst();
        ld_inst=0; st_inst=0;
        inst_done=1; @(posedge clk);
        inst_done=0; @(posedge clk);
    endtask

    // Spin until signal goes high; fail after 'limit' cycles
    task automatic wait_hi(ref logic sig, input int limit, input string label);
        for (int i=0; i<limit; i++) begin
            @(posedge clk);
            if (sig) begin chk(label, 1'b1); return; end
        end
        chk(label, 1'b0);   // timeout = FAIL
    endtask

    // =========================================================================
    //  TEST 1 – Reset
    // =========================================================================
    task automatic test_reset();
        $display("\n--- TEST 1: Reset ---");
        do_reset();
        @(negedge clk);
        chk("lsu2mem_addr = 0", lsu2mem_addr === '0);
        chk("ld_req = 0",       ld_req        === 1'b0);
        chk("st_req = 0",       st_req        === 1'b0);
        chk("is_loaded = 0",    is_loaded     === 1'b0);
        chk("is_stored = 0",    is_stored     === 1'b0);
        chk("error_flag = 0",   error_flag    === 1'b0);
        chk("burst_len = 0",    burst_len     === 8'h00);
    endtask

    // =========================================================================
    //  TEST 2 – Unit Stride LOAD  SEW=32  vlmax=16
    // =========================================================================
    task automatic test_unit_load_sew32();
        $display("\n--- TEST 2: Unit Stride Load  SEW=32 vlmax=16 ---");
        do_reset();

        // Fake memory: element[i] = i+1
        mem2lsu_data = '0;
        for (int i=0; i<16; i++)
            mem2lsu_data[i*32 +: 32] = 32'(i+1);

        rs1_data   = 32'h0000_1000;
        rs2_data   = 32'h1;          // ==1 → unit stride
        vlmax      = 10'd16;
        sew        = 7'd32;
        stride_sel = 1'b1;
        ld_inst    = 1'b1;

        @(posedge clk); @(posedge clk);   // FSM settles, ld_req registered

        chk("ld_req",              ld_req       === 1'b1);
        chk("addr = base",         lsu2mem_addr === 32'h0000_1000);
        chk("burst_size = 3'b110", burst_size   === 3'b110);
        chk("burst_len = 0",       burst_len    === 8'd0);
        chk("burst_type = INCR",   burst_type   === `BURST_INCR);

        burst_valid_data = 1'b1; @(posedge clk); burst_valid_data = 1'b0;

        wait_hi(is_loaded, 20, "is_loaded");
        chk("vd_data[0]  = 1",  vd_data[0*32  +: 32] === 32'd1);
        chk("vd_data[7]  = 8",  vd_data[7*32  +: 32] === 32'd8);
        chk("vd_data[15] = 16", vd_data[15*32 +: 32] === 32'd16);

        end_inst();
    endtask

    // =========================================================================
    //  TEST 3 – Unit Stride LOAD  SEW=8  vlmax=64
    // =========================================================================
    task automatic test_unit_load_sew8();
        $display("\n--- TEST 3: Unit Stride Load  SEW=8 vlmax=64 ---");
        do_reset();

        mem2lsu_data = '0;
        for (int i=0; i<64; i++) mem2lsu_data[i*8 +: 8] = 8'hAB;

        rs1_data   = 32'h0000_2000;
        rs2_data   = 32'h1;
        vlmax      = 10'd64;
        sew        = 7'd8;
        stride_sel = 1'b1;
        ld_inst    = 1'b1;

        @(posedge clk); @(posedge clk);

        chk("ld_req",      ld_req    === 1'b1);
        chk("burst_len=0", burst_len === 8'd0);   // 64*8 = 512 bits = 1 beat

        burst_valid_data = 1'b1; @(posedge clk); burst_valid_data = 1'b0;

        wait_hi(is_loaded, 20, "is_loaded");
        chk("vd[0]  = 0xAB", vd_data[0*8  +: 8] === 8'hAB);
        chk("vd[63] = 0xAB", vd_data[63*8 +: 8] === 8'hAB);

        end_inst();
    endtask

    // =========================================================================
    //  TEST 4 – Unit Stride LOAD  SEW=16  vlmax=32
    // =========================================================================
    task automatic test_unit_load_sew16();
        $display("\n--- TEST 4: Unit Stride Load  SEW=16 vlmax=32 ---");
        do_reset();

        mem2lsu_data = '0;
        for (int i=0; i<32; i++) mem2lsu_data[i*16 +: 16] = 16'(i*2);

        rs1_data   = 32'h0000_3000;
        rs2_data   = 32'h1;
        vlmax      = 10'd32;
        sew        = 7'd16;
        stride_sel = 1'b1;
        ld_inst    = 1'b1;

        @(posedge clk); @(posedge clk);

        chk("ld_req",      ld_req    === 1'b1);
        chk("burst_len=0", burst_len === 8'd0);   // 32*16 = 512 bits = 1 beat

        burst_valid_data = 1'b1; @(posedge clk); burst_valid_data = 1'b0;

        wait_hi(is_loaded, 20, "is_loaded");
        chk("vd[0]  = 0",  vd_data[0*16  +: 16] === 16'd0);
        chk("vd[1]  = 2",  vd_data[1*16  +: 16] === 16'd2);
        chk("vd[31] = 62", vd_data[31*16 +: 16] === 16'd62);

        end_inst();
    endtask

    // =========================================================================
    //  TEST 5 – Unit Stride STORE  SEW=32  vlmax=16
    // =========================================================================
    task automatic test_unit_store_sew32();
        $display("\n--- TEST 5: Unit Stride Store  SEW=32 vlmax=16 ---");
        do_reset();

        vs3_data = '0;
        for (int i=0; i<16; i++)
            vs3_data[i*32 +: 32] = 32'hA000_0000 + 32'(i);

        rs1_data   = 32'h0000_4000;
        rs2_data   = 32'h1;
        vlmax      = 10'd16;
        sew        = 7'd32;
        stride_sel = 1'b1;
        st_inst    = 1'b1;

        @(posedge clk); @(posedge clk);

        chk("st_req",              st_req       === 1'b1);
        chk("addr = base",         lsu2mem_addr === 32'h0000_4000);
        chk("data[0]=0xA000_0000", lsu2mem_data[0*32 +: 32] === 32'hA000_0000);
        chk("data[1]=0xA000_0001", lsu2mem_data[1*32 +: 32] === 32'hA000_0001);
        chk("wr_strobe[3:0]=0xF",  wr_strobe[3:0] === 4'hF);

        // Hold write-valid for one full cycle so the FSM captures it
        @(posedge clk);
        burst_wr_valid = 1'b1; @(posedge clk); burst_wr_valid = 1'b0;

        wait_hi(is_stored, 15, "is_stored");
        end_inst();
    endtask

    // =========================================================================
    //  TEST 6 – Unit Stride STORE  SEW=8  write-strobe + data check
    // =========================================================================
    task automatic test_unit_store_sew8();
        $display("\n--- TEST 6: Unit Stride Store  SEW=8  strobe check ---");
        do_reset();

        vs3_data = '0;
        vs3_data[0*8 +: 8] = 8'h11;
        vs3_data[1*8 +: 8] = 8'h22;
        vs3_data[2*8 +: 8] = 8'h33;
        vs3_data[3*8 +: 8] = 8'h44;

        rs1_data   = 32'h0000_5000;
        rs2_data   = 32'h1;
        vlmax      = 10'd4;
        sew        = 7'd8;
        stride_sel = 1'b1;
        st_inst    = 1'b1;

        @(posedge clk); @(posedge clk);

        chk("st_req",           st_req           === 1'b1);
        chk("strobe[0]=1",      wr_strobe[0]     === 1'b1);
        chk("strobe[1]=1",      wr_strobe[1]     === 1'b1);
        chk("strobe[2]=1",      wr_strobe[2]     === 1'b1);
        chk("strobe[3]=1",      wr_strobe[3]     === 1'b1);
        chk("data[0]=0x11",     lsu2mem_data[0  +: 8] === 8'h11);
        chk("data[1]=0x22",     lsu2mem_data[8  +: 8] === 8'h22);
        chk("data[2]=0x33",     lsu2mem_data[16 +: 8] === 8'h33);
        chk("data[3]=0x44",     lsu2mem_data[24 +: 8] === 8'h44);

        @(posedge clk);
        burst_wr_valid = 1'b1; @(posedge clk); burst_wr_valid = 1'b0;

        wait_hi(is_stored, 15, "is_stored");
        end_inst();
    endtask

    // =========================================================================
    //  TEST 7 – Constant Stride LOAD  SEW=8  vlmax=4  stride=4
    // =========================================================================
    task automatic test_const_load();
        $display("\n--- TEST 7: Constant Stride Load  SEW=8 vlmax=4 stride=4 ---");
        do_reset();

        rs1_data   = 32'h0000_6000;
        rs2_data   = 32'h4;        // stride = 4 bytes (not 1, not unit)
        vlmax      = 10'd4;
        sew        = 7'd8;
        stride_sel = 1'b0;
        ld_inst    = 1'b1;

        @(posedge clk);  // FSM → LOAD_CONST_STR

        // One byte returned per memory beat
        for (int el=0; el<4; el++) begin
            wait_hi(ld_req, 15, $sformatf("ld_req el%0d", el));
            mem2lsu_data     = {{(DBW*BMAX-8){1'b0}}, 8'(10+el)};
            burst_valid_data = 1'b1; @(posedge clk); burst_valid_data = 1'b0;
        end

        wait_hi(is_loaded, 30, "is_loaded");
        chk("vd[0]=10", vd_data[0  +: 8] === 8'd10);
        chk("vd[1]=11", vd_data[8  +: 8] === 8'd11);
        chk("vd[2]=12", vd_data[16 +: 8] === 8'd12);
        chk("vd[3]=13", vd_data[24 +: 8] === 8'd13);

        end_inst();
    endtask

    // =========================================================================
    //  TEST 8 – Constant Stride STORE  SEW=16  vlmax=4  stride=2
    // =========================================================================
    task automatic test_const_store();
        $display("\n--- TEST 8: Constant Stride Store  SEW=16 vlmax=4 stride=2 ---");
        do_reset();

        vs3_data = '0;
        for (int i=0; i<4; i++)
            vs3_data[i*16 +: 16] = 16'hBEEF + 16'(i);

        rs1_data   = 32'h0000_7000;
        rs2_data   = 32'h2;        // stride = 2
        vlmax      = 10'd4;
        sew        = 7'd16;
        stride_sel = 1'b0;
        st_inst    = 1'b1;

        @(posedge clk);

        // ACK each element write individually
        for (int el=0; el<4; el++) begin
            wait_hi(st_req, 15, $sformatf("st_req el%0d", el));
            @(posedge clk);   // one extra cycle so FSM is in the state to see it
            burst_wr_valid = 1'b1; @(posedge clk); burst_wr_valid = 1'b0;
        end

        wait_hi(is_stored, 30, "is_stored");
        end_inst();
    endtask

    // =========================================================================
    //  TEST 9 – Index-Ordered LOAD  SEW=32  vlmax=4
    // =========================================================================
    task automatic test_index_ordered_load();
        logic [XLEN-1:0] offsets [4];
        $display("\n--- TEST 9: Index-Ordered Load  SEW=32 vlmax=4 ---");
        do_reset();

        offsets = '{32'h10, 32'h20, 32'h30, 32'h40};
        vs2_data = '0;
        for (int i=0; i<4; i++) vs2_data[i*32 +: 32] = offsets[i];

        rs1_data        = 32'h0000_8000;
        vlmax           = 10'd4;
        sew             = 7'd32;
        stride_sel      = 1'b0;
        ld_inst         = 1'b1;
        index_str       = 1'b1;
        index_unordered = 1'b0;
        width           = 3'b110;

        @(posedge clk);

        for (int el=0; el<4; el++) begin
            wait_hi(ld_req, 15, $sformatf("ld_req el%0d", el));
            chk($sformatf("addr el%0d = base+offset", el),
                lsu2mem_addr === (32'h0000_8000 + offsets[el]));
            mem2lsu_data     = {{(DBW*BMAX-32){1'b0}}, 32'hCAFE_0000 + 32'(el)};
            burst_valid_data = 1'b1; @(posedge clk); burst_valid_data = 1'b0;
        end

        wait_hi(is_loaded, 30, "is_loaded");
        end_inst();
    endtask

    // =========================================================================
    //  TEST 10 – Index-Ordered STORE  SEW=32  vlmax=4
    // =========================================================================
    task automatic test_index_ordered_store();
        $display("\n--- TEST 10: Index-Ordered Store  SEW=32 vlmax=4 ---");
        do_reset();

        vs2_data = '0;
        vs2_data[0*32 +: 32] = 32'h100;
        vs2_data[1*32 +: 32] = 32'h200;
        vs2_data[2*32 +: 32] = 32'h300;
        vs2_data[3*32 +: 32] = 32'h400;

        vs3_data = '0;
        for (int i=0; i<4; i++)
            vs3_data[i*32 +: 32] = 32'hDEAD_0000 + 32'(i);

        rs1_data        = 32'h0000_9000;
        vlmax           = 10'd4;
        sew             = 7'd32;
        stride_sel      = 1'b0;
        st_inst         = 1'b1;
        index_str       = 1'b1;
        index_unordered = 1'b0;
        width           = 3'b110;

        @(posedge clk);

        for (int el=0; el<4; el++) begin
            wait_hi(st_req, 15, $sformatf("st_req el%0d", el));
            @(posedge clk);
            burst_wr_valid = 1'b1; @(posedge clk); burst_wr_valid = 1'b0;
        end

        wait_hi(is_stored, 30, "is_stored");
        end_inst();
    endtask

    // =========================================================================
    //  TEST 11 – Error flag  (index_str + width = 3'b111)
    // =========================================================================
    task automatic test_error_flag();
        $display("\n--- TEST 11: Error Flag ---");
        do_reset();

        vlmax      = 10'd8;
        sew        = 7'd64;
        stride_sel = 1'b0;
        ld_inst    = 1'b1;
        index_str  = 1'b1;
        width      = 3'b111;   // illegal combination → error_flag

        @(posedge clk); @(negedge clk);

        chk("error_flag = 1",      error_flag === 1'b1);
        chk("ld_req suppressed",   ld_req     === 1'b0);
        chk("is_loaded = 0",       is_loaded  === 1'b0);

        end_inst();
    endtask

    // =========================================================================
    //  TEST 12 – Back-to-back  Load → Store  (unit stride, SEW=32)
    // =========================================================================
    task automatic test_back_to_back();
        $display("\n--- TEST 12: Back-to-Back Load then Store ---");
        do_reset();

        // --- Load ---
        mem2lsu_data = '0;
        for (int i=0; i<16; i++) mem2lsu_data[i*32 +: 32] = 32'(i+1);

        rs1_data   = 32'h0000_A000;
        rs2_data   = 32'h1;
        vlmax      = 10'd16;
        sew        = 7'd32;
        stride_sel = 1'b1;
        ld_inst    = 1'b1;

        @(posedge clk); @(posedge clk);

        burst_valid_data = 1'b1; @(posedge clk); burst_valid_data = 1'b0;

        wait_hi(is_loaded, 20, "Load: is_loaded");

        // Transition to idle, then issue store
        ld_inst=0; inst_done=1; @(posedge clk); inst_done=0; @(posedge clk);

        // --- Store ---
        vs3_data = '0;
        for (int i=0; i<16; i++) vs3_data[i*32 +: 32] = 32'(i+100);

        rs1_data = 32'h0000_B000;
        st_inst  = 1'b1;

        @(posedge clk); @(posedge clk);

        chk("Store: st_req", st_req === 1'b1);

        @(posedge clk);
        burst_wr_valid = 1'b1; @(posedge clk); burst_wr_valid = 1'b0;

        wait_hi(is_stored, 20, "Store: is_stored");
        end_inst();
    endtask

    // =========================================================================
    //  MAIN
    // =========================================================================
    initial begin
        $display("============================================================");
        $display("              vec_lsu Minimal Testbench                     ");
        $display("============================================================");

        test_reset();
        test_unit_load_sew32();
        test_unit_load_sew8();
        test_unit_load_sew16();
        test_unit_store_sew32();
        test_unit_store_sew8();
        test_const_load();
        test_const_store();
        test_index_ordered_load();
        test_index_ordered_store();
        test_error_flag();
        test_back_to_back();

        $display("\n============================================================");
        $display("  PASS = %0d   FAIL = %0d", pass_cnt, fail_cnt);
        $display("============================================================");
        if (fail_cnt == 0) $display("  *** ALL TESTS PASSED ***");
        else               $display("  *** FAILURES - see [FAIL] lines above ***");
        $finish;
    end

    // Watchdog – prevents infinite hang
    initial begin #200_000; $display("[WATCHDOG] timeout"); $finish; end

endmodule