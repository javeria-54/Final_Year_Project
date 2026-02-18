// Copyright 2025 Maktab-e-Digital Systems Lahore.
// Licensed under the Apache License, Version 2.0, see LICENSE file for details.
// SPDX-License-Identifier: Apache-2.0
//
// Author: javeria
// =============================================================================
// Single-Cycle RISC-V Processor - Data Memory (Workshop Skeleton Version)
// =============================================================================

module Data_Memory(
    input  logic        clk,
    input  logic        rst,
    input  logic        wr_en,
    input  logic        rd_en,
    input  logic [31:0] address,
    input  logic [31:0] wdata,
    output logic [31:0] rdata
);

    logic [31:0] data_memory [0:4095];

    // Synchronous write with reset initialization
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            for (int i = 0; i < 4096; i++) begin
                data_memory[i] <= 32'b0;
            end
        end else if (wr_en) begin
            data_memory[address] <= wdata;
        end
    end

    // Synchronous read
    always_ff @(posedge clk) begin
        if (rd_en)
            rdata <= data_memory[address];
        else
            rdata <= 32'b0;
    end
endmodule

