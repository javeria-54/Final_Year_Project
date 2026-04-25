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


type_clint2csr_s clint2csr;
type_pipe2csr_s  core2pipe;


// ----------------------------------------------------------------
// pipeline_top instantiation
// ----------------------------------------------------------------
pipeline_top dut (
    .rst_n          (rst_n),
    .clk            (clk)
);

// ----------------------------------------------------------------
// Dbus -> memory wiring
// ----------------------------------------------------------------

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
    repeat (2) @(posedge clk);
    @(negedge clk);
    rst_n = 1'b1;
    $display("[TB] Reset released at time %0t ns", $time);
end

initial begin
    clint2csr = '0;
    core2pipe = '0;
end

// ----------------------------------------------------------------
// Waveform dump + run time
// ----------------------------------------------------------------
initial begin
    $dumpfile("pipeline_tb.vcd");
    $dumpvars(0, pipeline_tb);

    @(posedge rst_n);
    repeat (10) @(posedge clk);

    $display("[TB] Simulation complete at %0t ns", $time);
    $finish;
end


endmodule : pipeline_tb