// Copyright 2025 Maktab-e-Digital Systems Lahore.
// Licensed under the Apache License, Version 2.0, see LICENSE file for details.
// SPDX-License-Identifier: Apache-2.0
//
// Author: Javeria
// =============================================================================
// System-Level Testbench — system_top (Scalar + Vector)
// Scalar processor khud instruction fetch karta hai,
// vector instructions automatically forward hoti hain
// =============================================================================

import axi_4_pkg::*;

`include "vector_processor_defs.svh"
`include "axi_4_defs.svh"

`timescale 1ns/1ps

module system_top_tb();

    //==========================================================================
    // Clock & Reset
    //==========================================================================
    logic clk, rst;

    initial clk = 0;
    always #5 clk = ~clk;  // 100MHz clock

    //==========================================================================
    // DUT Instantiation
    //==========================================================================
    system_top DUT (
        .clk(clk),
        .rst(rst)
    );

    //==========================================================================
    // Monitoring — DUT ke andar se signals observe karo
    //==========================================================================

    // Scalar signals
    wire [31:0] pc          = DUT.SCALAR.pc_next;
    wire [31:0] instruction = DUT.SCALAR.instruction;
    wire        is_vector   = DUT.is_vector;

    // Handshaking signals
    wire        inst_valid      = DUT.inst_valid;
    wire        vec_pro_ready   = DUT.vec_pro_ready;
    wire        vec_pro_ack     = DUT.vec_pro_ack;
    wire        scalar_pro_ready= DUT.scalar_pro_ready;

    // Vector processor results
    wire        is_vec  = DUT.is_vec;
    wire        error   = DUT.error;
    wire [31:0] csr_out = DUT.csr_out;

    //==========================================================================
    // Test Counters
    //==========================================================================
    int scalar_inst_count = 0;
    int vector_inst_count = 0;
    int error_count       = 0;

    //==========================================================================
    // RESET SEQUENCE
    //==========================================================================
    initial begin
        $display("============================================");
        $display("  System Top Testbench");
        $display("  Scalar + Vector Processor Integration");
        $display("============================================\n");

        rst = 1;
        #20;
        rst = 0;
        #30;
        rst = 1;
        #20;
        $display("Reset complete — Processor starting...\n");
        $display("--------------------------------------------");
    end

    //==========================================================================
    // SCALAR INSTRUCTION MONITOR
    // Har cycle mein scalar instruction observe karo
    //==========================================================================
    always @(posedge clk) begin
        if (rst) begin
            if (!is_vector) begin
                scalar_inst_count++;
                $display("[SCALAR] PC: 0x%08h | Inst: 0x%08h",
                    pc, instruction);
            end
        end
    end

    //==========================================================================
    // VECTOR INSTRUCTION MONITOR
    // Jab vector instruction detect ho
    //==========================================================================
    always @(posedge clk) begin
        if (rst && is_vector && inst_valid) begin
            vector_inst_count++;
            $display("[VECTOR] Detected  | PC: 0x%08h | Inst: 0x%08h",
                pc, instruction);
            $display("         rs1: 0x%08h | rs2: 0x%08h",
                DUT.rs1_data_fwd, DUT.rs2_data_fwd);
        end
    end

    //==========================================================================
    // VECTOR COMPLETION MONITOR
    // Jab vector processor done ho (vec_pro_ack)
    //==========================================================================
    always @(posedge clk) begin
        if (rst && vec_pro_ack) begin
            if (error) begin
                error_count++;
                $display("[VECTOR] DONE ✗ ERROR | csr_out: 0x%08h", csr_out);
            end else begin
                $display("[VECTOR] DONE ✓ OK   | csr_out: 0x%08h", csr_out);
            end
        end
    end

    //==========================================================================
    // MAIN SIMULATION — Processor ko chalao
    //==========================================================================
    initial begin
        // Reset complete hone ka wait
        @(posedge rst);
        #50;

        // Processor khud chal raha hai — sirf observe karo
        // Jitna time chahiye simulation chalao
        #2000;  // 200 cycles (adjust karo apni instruction count ke hisaab se)

        //======================================================================
        // FINAL SUMMARY
        //======================================================================
        $display("\n============================================");
        $display("  Simulation Complete — Summary");
        $display("============================================");
        $display("  Scalar Instructions : %0d", scalar_inst_count);
        $display("  Vector Instructions : %0d", vector_inst_count);
        $display("  Vector Errors       : %0d", error_count);

        if (error_count == 0)
            $display("  Result              : ALL PASSED ✓");
        else
            $display("  Result              : %0d ERRORS ✗", error_count);

        $display("============================================\n");
        $finish;
    end

    //==========================================================================
    // TIMEOUT — Agar processor hang ho jaye
    //==========================================================================
    initial begin
        #50000;  // 5000 cycles ke baad timeout
        $display("\n[TIMEOUT] Simulation stuck! Check handshaking.");
        $finish;
    end

    //==========================================================================
    // Waveform Dump
    //==========================================================================
    initial begin
        $dumpfile("system_top.vcd");
        $dumpvars(0, system_top_tb);
    end

endmodule