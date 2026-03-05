// ============================================================
// Testbench for vector_scalar_top
// Sirf clk aur rst_n drive hoti hain — baki sab top module
// khud handle karta hai (memory banks bhi)
// ============================================================

`timescale 1ns/1ps

module vector_scalar_top_tb;

// ----------------------------------------------------------------
// Clock & Reset
// ----------------------------------------------------------------
logic clk;
logic rst_n;

// ----------------------------------------------------------------
// DUT instantiation
// ----------------------------------------------------------------
vector_scalar_top dut (
    .clk   (clk),
    .rst_n (rst_n)
);

// ----------------------------------------------------------------
// Clock: 10ns period (100 MHz)
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

// ----------------------------------------------------------------
// Waveform dump + run
// ----------------------------------------------------------------
initial begin
    $dumpfile("vector_scalar_top_tb.vcd");
    $dumpvars(0, vector_scalar_top_tb);

    @(posedge rst_n);
    repeat (500) @(posedge clk);

    $display("[TB] Simulation complete at %0t ns", $time);
    $finish;
end

// ----------------------------------------------------------------
// Monitor: fetch stage
// ----------------------------------------------------------------
always @(posedge clk) begin
    if (rst_n && dut.mem2if.ack)
        $display("[FETCH] t=%0t  PC=0x%08h  INSTR=0x%08h",
                 $time, dut.if2mem.addr, dut.mem2if.r_data);
end

endmodule : vector_scalar_top_tb