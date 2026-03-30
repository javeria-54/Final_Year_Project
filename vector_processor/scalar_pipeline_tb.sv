// ============================================================
// Testbench for pipeline_top + memory
// Sirf clk aur rst_n drive hoti hain
// Memory module khud MEM_BANK_0..3.txt load karta hai
// aur fetch stage ko serve karta hai
// ============================================================

`timescale 1ns/1ps

`include "scalar_pcore_interface_defs.svh"
`include "scalar_m_ext_defs.svh"
`include "scalar_a_ext_defs.svh"

module pipeline_tb;

// ----------------------------------------------------------------
// Clock & Reset
// ----------------------------------------------------------------
logic clk;
logic rst_n;

// ----------------------------------------------------------------
// pipeline_top <---> memory  (imem)
// ----------------------------------------------------------------
type_if2imem_s   if2mem;
type_imem2if_s   mem2if;

// ----------------------------------------------------------------
// pipeline_top <---> memory  (dmem via dbus)
// ----------------------------------------------------------------
type_lsu2dbus_s  lsu2dbus;
type_dbus2lsu_s  dbus2lsu;
type_dbus2peri_s dbus2mem;
type_peri2dbus_s mem2dbus;
logic            lsu_flush;
logic            dmem_sel;

// ----------------------------------------------------------------
// Unused inputs tied off
// ----------------------------------------------------------------
type_clint2csr_s clint2csr;
type_pipe2csr_s  core2pipe;
logic            is_vector;


// ----------------------------------------------------------------
// pipeline_top instantiation
// ----------------------------------------------------------------
pipeline_top dut (
    .rst_n          (rst_n),
    .clk            (clk),
    .is_vector      (is_vector),

    // Instruction memory interface
    .if2mem_o       (if2mem),
    .mem2if_i       (mem2if),

    // Data bus interface
    .lsu2dbus_o     (lsu2dbus),
    .dbus2lsu_i     (dbus2lsu),
    .lsu_flush_o    (lsu_flush),

    // Clint & IRQ
    .clint2csr_i    (clint2csr),
    .instr_o(instruction),      // fetch stage se
    .rs1_data_o(rs1_data),   // decode stage se  
    .rs2_data_o(rs2_data), 
    .core2pipe_i    (core2pipe)
);

// ----------------------------------------------------------------
// Dbus -> memory wiring
// ----------------------------------------------------------------

// ----------------------------------------------------------------
// memory instantiation
// (loads MEM_BANK_0..3.txt internally, serves imem + dmem)
// ----------------------------------------------------------------
memory mem_module (
    .rst_n      (rst_n),
    .clk        (clk),

    // Instruction port
    .if2mem_i   (if2mem),
    .mem2if_o   (mem2if),

    // Data port
    .dmem_sel   (dmem_sel),
    .exe2mem_i  (dbus2mem),
    .mem2wrb_o  (mem2dbus)
);

// ----------------------------------------------------------------
// Clock generation  (10ns => 100 MHz)
// ----------------------------------------------------------------
initial clk = 1'b0;
always  #5 clk = ~clk;

// ----------------------------------------------------------------
// Reset: 5 cycles low, phir release
// ----------------------------------------------------------------
initial begin
    rst_n = 1'b0;
    repeat (5) @(posedge clk);
    @(negedge clk);
    rst_n = 1'b1;
    $display("[TB] Reset released at time %0t ns", $time);
end

// ----------------------------------------------------------------
// Waveform dump + run time
// ----------------------------------------------------------------
initial begin
    $dumpfile("pipeline_tb.vcd");
    $dumpvars(0, pipeline_tb);

    @(posedge rst_n);
    repeat (500) @(posedge clk);

    $display("[TB] Simulation complete at %0t ns", $time);
    $finish;
end

// ----------------------------------------------------------------
// Monitor: har fetch print karo
// ----------------------------------------------------------------
always @(posedge clk) begin
    if (rst_n && mem2if.ack)
        $display("[FETCH] t=%0t  PC=0x%08h  INSTR=0x%08h",
                 $time, if2mem.addr, mem2if.r_data);
end

endmodule : pipeline_tb