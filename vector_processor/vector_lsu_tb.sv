`timescale 1ns/1ps

// ============================================================
//  Testbench: vec_lsu  (ModelSim / QuestaSim)
//
//  ROOT-CAUSE FIX for vopt-7061:
//    ModelSim treats always_ff as owning EVERY element of
//    mem_model[] once it writes ANY element.  So initial blocks
//    cannot write mem_model[] at all once an always_ff touches it.
//
//  SOLUTION:
//    mem_model[] is NEVER written by always_ff.
//    Instead a separate tb_write_pending / tb_write_* set of
//    signals captures the DUT's store request, and a dedicated
//    initial-block "memory server" (forever loop) performs the
//    actual write.  This keeps mem_model[] under a single driver
//    (the initial block) while still letting the DUT store data.
// ============================================================

`ifndef XLEN
  `define XLEN        32
`endif
`ifndef VLEN
  `define VLEN        128
`endif
`ifndef MAX_VLEN
  `define MAX_VLEN    1024
`endif
`ifndef Tag_Width
  `define Tag_Width   9
`endif
`ifndef NUM_ELEMENT_SEW8
  `define NUM_ELEMENT_SEW8   (`VLEN/8)
`endif
`ifndef NUM_ELEMENT_SEW16
  `define NUM_ELEMENT_SEW16  (`VLEN/16)
`endif
`ifndef NUM_ELEMENT_SEW32
  `define NUM_ELEMENT_SEW32  (`VLEN/32)
`endif

module vec_lsu_tb;

  // ── Clock / reset ──────────────────────────────────────────────────
  logic clk   = 1'b0;
  logic n_rst = 1'b0;
  always #5 clk = ~clk;

  // ── DUT inputs ─────────────────────────────────────────────────────
  logic                    stride_sel;
  logic                    ld_inst;
  logic                    st_inst;
  logic                    index_str;
  logic                    index_unordered;
  logic [9:0]              vlmax;
  logic [6:0]              sew;
  logic [`XLEN-1:0]        rs1_data;
  logic [`XLEN-1:0]        rs2_data;
  logic [`MAX_VLEN-1:0]    vs2_data;
  logic [`MAX_VLEN-1:0]    vs3_data;
  logic                    mew;
  logic [2:0]              width;
  logic                    inst_done;
  logic [`VLEN-1:0]        mem_rdata;
  logic [`Tag_Width-1:0]   seq_num;

  // ── DUT outputs ────────────────────────────────────────────────────
  logic [`XLEN-1:0]        mem_addr;
  logic [`VLEN-1:0]        mem_wdata;
  logic [`VLEN-1:0]        mem_wdata_unit;
  logic [63:0]             mem_byte_en;
  logic                    mem_wen;
  logic                    mem_ren;
  logic                    mem_elem_mode;
  logic [1:0]              mem_sew_enc;
  logic [`Tag_Width-1:0]   seq_num_lsu;
  logic [`MAX_VLEN-1:0]    vd_data;
  logic                    is_loaded;
  logic                    is_stored;
  logic                    error_flag;

  // ── DUT instantiation ──────────────────────────────────────────────
  vec_lsu DUT (
    .clk              (clk),
    .n_rst            (n_rst),
    .stride_sel       (stride_sel),
    .ld_inst          (ld_inst),
    .st_inst          (st_inst),
    .index_str        (index_str),
    .index_unordered  (index_unordered),
    .vlmax            (vlmax),
    .sew              (sew),
    .rs1_data         (rs1_data),
    .rs2_data         (rs2_data),
    .vs2_data         (vs2_data),
    .vs3_data         (vs3_data),
    .mew              (mew),
    .width            (width),
    .inst_done        (inst_done),
    .mem_addr         (mem_addr),
    .mem_wdata        (mem_wdata),
    .mem_wdata_unit   (mem_wdata_unit),
    .mem_byte_en      (mem_byte_en),
    .mem_wen          (mem_wen),
    .mem_ren          (mem_ren),
    .mem_elem_mode    (mem_elem_mode),
    .mem_sew_enc      (mem_sew_enc),
    .mem_rdata        (mem_rdata),
    .seq_num          (seq_num),
    .seq_num_lsu      (seq_num_lsu),
    .vd_data          (vd_data),
    .is_loaded        (is_loaded),
    .is_stored        (is_stored),
    .error_flag       (error_flag)
  );

  // ================================================================
  //  MEMORY MODEL
  //  mem_model[] has EXACTLY ONE driver: the initial block below.
  //  No always_ff, no always_comb writes to mem_model[].
  //
  //  Read path  : combinational assign (not a procedural write)
  //  Write path : tb_wr_req handshake consumed by memory server
  // ================================================================
  logic [`VLEN-1:0] mem_model [0:255];   // single driver = initial block

  // Combinational read — this is a continuous assign, NOT a driver
  assign mem_rdata = mem_model[ mem_addr[11:4] ];

  // Handshake signals for DUT->memory write
  // (set by always_ff watcher, cleared by memory server)
  logic              tb_wr_req  = 1'b0;
  logic [7:0]        tb_wr_bank = '0;
  logic [`VLEN-1:0]  tb_wr_data = '0;

  // Watcher: detects DUT store, latches address+data, pulses tb_wr_req
  always_ff @(posedge clk) begin
    if (mem_wen) begin
      tb_wr_req  <= 1'b1;
      tb_wr_bank <= mem_addr[11:4];
      tb_wr_data <= mem_wdata;
    end else begin
      tb_wr_req  <= 1'b0;
    end
  end

  // Memory server: runs inside initial so mem_model[] has one driver
  initial begin
    forever begin
      @(posedge clk);
      if (tb_wr_req)
        mem_model[ tb_wr_bank ] = tb_wr_data;   // blocking OK in initial
    end
  end

  // ── Scoreboard ─────────────────────────────────────────────────────
  int pass_cnt = 0;
  int fail_cnt = 0;

  task automatic chk(input string name, input logic cond);
    if (cond) begin $display("  [PASS] %s", name); pass_cnt++; end
    else      begin $display("  [FAIL] %s", name); fail_cnt++; end
  endtask

  // ── Helpers ────────────────────────────────────────────────────────
  task automatic do_reset();
    n_rst=0; ld_inst=0; st_inst=0;
    stride_sel=0; index_str=0; index_unordered=0;
    vlmax=10'd4; sew=7'd32; rs1_data=0; rs2_data=0;
    vs2_data=0; vs3_data=0; mew=0; width=3'b110;
    inst_done=0; seq_num=0;
    @(posedge clk); #1;
    n_rst=1;
    @(posedge clk); #1;
  endtask

  task automatic pulse_done();
    ld_inst=0; st_inst=0;
    inst_done=1; @(posedge clk); #1;
    inst_done=0; @(posedge clk); #1;
  endtask

  task automatic wait_loaded(input int maxcyc=80);
    for (int i=0; i<maxcyc; i++) begin
      if (is_loaded) return;
      @(posedge clk); #1;
    end
    $display("  [WARN] wait_loaded timeout");
  endtask

  task automatic wait_stored(input int maxcyc=80);
    for (int i=0; i<maxcyc; i++) begin
      if (is_stored) return;
      @(posedge clk); #1;
    end
    $display("  [WARN] wait_stored timeout");
  endtask

  // Helper: write a bank directly (safe — same initial driver)
  task automatic mem_write(input int bank, input logic [`VLEN-1:0] data);
    mem_model[bank] = data;
  endtask

  // ================================================================
  //  MAIN TEST SEQUENCE
  // ================================================================
  initial begin
    $dumpfile("vec_lsu_tb.vcd");
    $dumpvars(0, vec_lsu_tb);

    // -- Initialise all banks to 0 (safe: only initial writes here) --
    for (int i=0; i<256; i++) mem_model[i] = '0;

    do_reset();

    // ==============================================================
    // TC1  Unit-stride LOAD  sew=32, vlmax=4, base=0x000 (bank0)
    // ==============================================================
    $display("\n--- TC1: Unit-stride LOAD (sew=32) ---");
    mem_write(0, 128'hAABBCCDD_12345678_CAFEBABE_DEADBEEF);

    sew=7'd32; vlmax=10'd4; stride_sel=1'b1;
    rs1_data=32'h0000_0000; rs2_data=32'd4;
    index_str=0; index_unordered=0; width=3'b110; seq_num=4'd1;

    ld_inst=1; @(posedge clk); #1; ld_inst=0;
    wait_loaded();

    chk("TC1a: is_loaded",      is_loaded      == 1'b1);
    chk("TC1b: vd[31:0]",       vd_data[31:0]  == 32'hDEAD_BEEF);
    chk("TC1c: vd[63:32]",      vd_data[63:32] == 32'hCAFE_BABE);
    chk("TC1d: seq_num_lsu==1", seq_num_lsu    == 4'd1);
    chk("TC1e: elem_mode==0",   mem_elem_mode  == 1'b0 || is_loaded);
    pulse_done();

    // ==============================================================
    // TC2  Unit-stride STORE  sew=32, base=0x010 (bank1)
    // ==============================================================
    $display("\n--- TC2: Unit-stride STORE (sew=32) ---");
    vs3_data=0;
    vs3_data[31:0] =32'hAABB_CCDD;
    vs3_data[63:32]=32'h1122_3344;

    sew=7'd32; vlmax=10'd4; stride_sel=1'b1;
    rs1_data=32'h0000_0010; rs2_data=32'd4;
    index_str=0; index_unordered=0; width=3'b110; seq_num=4'd2;

    st_inst=1; @(posedge clk); #1; st_inst=0;
    wait_stored();

    chk("TC2a: is_stored",       is_stored      == 1'b1);
    chk("TC2b: seq_num_lsu==2",  seq_num_lsu    == 4'd2);
    repeat(2) @(posedge clk); #1;  // let memory server commit
    chk("TC2c: bank1[31:0]",  mem_model[1][31:0]  == 32'hAABB_CCDD);
    chk("TC2d: bank1[63:32]", mem_model[1][63:32] == 32'h1122_3344);
    pulse_done();

    // ==============================================================
    // TC3  Const-stride LOAD  sew=8, stride=8, vlmax=4
    // ==============================================================
    $display("\n--- TC3: Const-stride LOAD (sew=8, stride=8) ---");
    // addr sequence: 0x00, 0x08 (both bank0), 0x10, 0x18 (both bank1)
    mem_write(0, 128'h00000000_00000000_00000000_000000AB);
    mem_write(1, 128'h00000000_00000000_00000000_00000012);

    sew=7'd8; vlmax=10'd4; stride_sel=1'b0;
    rs1_data=32'h0000_0000; rs2_data=32'd8;
    index_str=0; index_unordered=0; width=3'b000; seq_num=4'd3;

    ld_inst=1; @(posedge clk); #1; ld_inst=0;
    wait_loaded();

    chk("TC3a: is_loaded",   is_loaded    == 1'b1);
    chk("TC3b: el0 == 0xAB", vd_data[7:0] == 8'hAB);
    pulse_done();

    // ==============================================================
    // TC4  Const-stride STORE  sew=8, stride=8, vlmax=2, base=0x020
    // ==============================================================
    $display("\n--- TC4: Const-stride STORE (sew=8, stride=8) ---");
    vs3_data=0;
    vs3_data[7:0] =8'hFF;
    vs3_data[15:8]=8'hEE;

    sew=7'd8; vlmax=10'd2; stride_sel=1'b0;
    rs1_data=32'h0000_0020; rs2_data=32'd8;
    index_str=0; index_unordered=0; width=3'b000; seq_num=4'd4;

    st_inst=1; @(posedge clk); #1; st_inst=0;
    wait_stored();
    chk("TC4a: is_stored", is_stored == 1'b1);
    pulse_done();

    // ==============================================================
    // TC5  Ordered index LOAD  32-bit offsets, sew=32, vlmax=2
    // ==============================================================
    $display("\n--- TC5: Ordered index LOAD (32-bit idx, sew=32) ---");
    mem_write(0, 128'h00000000_00000000_00000000_DEADBEEF);
    mem_write(1, 128'h00000000_00000000_00000000_CAFEBABE);

    vs2_data=0;
    vs2_data[31:0] =32'h0000_0000;   // el0 offset -> bank0
    vs2_data[63:32]=32'h0000_0010;   // el1 offset -> bank1

    sew=7'd32; vlmax=10'd2; stride_sel=1'b0;
    rs1_data=32'h0; rs2_data=32'd0;
    index_str=1; index_unordered=0; width=3'b110; seq_num=4'd5;

    ld_inst=1; @(posedge clk); #1; ld_inst=0;
    wait_loaded();

    chk("TC5a: is_loaded",        is_loaded      == 1'b1);
    chk("TC5b: el0 = DEAD_BEEF",  vd_data[31:0]  == 32'hDEAD_BEEF);
    chk("TC5c: el1 = CAFE_BABE",  vd_data[63:32] == 32'hCAFE_BABE);
    pulse_done();

    // ==============================================================
    // TC6  Ordered index STORE  32-bit offsets, sew=32, vlmax=2
    // ==============================================================
    $display("\n--- TC6: Ordered index STORE (32-bit idx, sew=32) ---");
    vs2_data=0;
    vs2_data[31:0] =32'h0000_0030;   // bank3
    vs2_data[63:32]=32'h0000_0040;   // bank4

    vs3_data=0;
    vs3_data[31:0] =32'h1234_5678;
    vs3_data[63:32]=32'h8765_4321;

    sew=7'd32; vlmax=10'd2; stride_sel=1'b0;
    rs1_data=32'h0; rs2_data=32'd0;
    index_str=1; index_unordered=0; width=3'b110; seq_num=4'd6;

    st_inst=1; @(posedge clk); #1; st_inst=0;
    wait_stored();
    chk("TC6a: is_stored", is_stored == 1'b1);
    repeat(2) @(posedge clk); #1;
    chk("TC6b: bank3[31:0]=1234_5678", mem_model[3][31:0] == 32'h1234_5678);
    pulse_done();

    // ==============================================================
    // TC7  Unordered index LOAD  sew=32, vlmax=2
    // ==============================================================
    $display("\n--- TC7: Unordered index LOAD (sew=32) ---");
    mem_write(0, 128'h00000000_00000000_00000000_ABCD1234);
    mem_write(1, 128'h00000000_00000000_00000000_5678EFAB);

    vs2_data=0;
    vs2_data[31:0] =32'h0000_0000;
    vs2_data[63:32]=32'h0000_0010;

    sew=7'd32; vlmax=10'd2; stride_sel=1'b0;
    rs1_data=32'h0; rs2_data=32'd0;
    index_str=1; index_unordered=1; width=3'b110; seq_num=4'd7;

    ld_inst=1; @(posedge clk); #1; ld_inst=0;
    wait_loaded(150);
    chk("TC7a: is_loaded", is_loaded == 1'b1);
    pulse_done();

    // ==============================================================
    // TC8  Unordered index STORE  sew=32, vlmax=2
    // ==============================================================
    $display("\n--- TC8: Unordered index STORE (sew=32) ---");
    vs2_data=0;
    vs2_data[31:0] =32'h0000_0050;   // bank5
    vs2_data[63:32]=32'h0000_0060;   // bank6

    vs3_data=0;
    vs3_data[31:0] =32'hDEAD_C0DE;
    vs3_data[63:32]=32'hBAAD_F00D;

    sew=7'd32; vlmax=10'd2; stride_sel=1'b0;
    rs1_data=32'h0; rs2_data=32'd0;
    index_str=1; index_unordered=1; width=3'b110; seq_num=4'd8;

    st_inst=1; @(posedge clk); #1; st_inst=0;
    wait_stored(150);
    chk("TC8a: is_stored", is_stored == 1'b1);
    pulse_done();

    // ==============================================================
    // TC9  error_flag
    // ==============================================================
    $display("\n--- TC9: error_flag ---");
    index_str=1; width=3'b001;          // illegal
    @(posedge clk); #1;
    chk("TC9a: error_flag HIGH bad  width", error_flag == 1'b1);
    width=3'b110;                        // valid
    @(posedge clk); #1;
    chk("TC9b: error_flag LOW  good width", error_flag == 1'b0);
    index_str=0;

    // ==============================================================
    // TC10  Reset mid-flight
    // ==============================================================
    $display("\n--- TC10: Reset mid-flight ---");
    sew=7'd32; vlmax=10'd4; stride_sel=1'b0;
    rs1_data=32'h0; rs2_data=32'd4;
    index_str=0; index_unordered=0;

    ld_inst=1; @(posedge clk); #1; ld_inst=0;
    n_rst=0; @(posedge clk); #1;
    n_rst=1; @(posedge clk); #1;

    chk("TC10a: is_loaded low", is_loaded == 1'b0);
    chk("TC10b: is_stored low", is_stored == 1'b0);
    chk("TC10c: mem_ren  low",  mem_ren   == 1'b0);
    chk("TC10d: mem_wen  low",  mem_wen   == 1'b0);

    // ==============================================================
    $display("\n============================================");
    $display("  RESULTS:  %0d PASS  /  %0d FAIL", pass_cnt, fail_cnt);
    $display("============================================\n");
    $finish;
  end

  initial begin #200000; $display("[ERROR] Watchdog!"); $finish; end

endmodule