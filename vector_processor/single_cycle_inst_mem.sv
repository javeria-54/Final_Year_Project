// Copyright 2025 Maktab-e-Digital Systems Lahore.
// Licensed under the Apache License, Version 2.0, see LICENSE file for details.
// SPDX-License-Identifier: Apache-2.0
//
// Author:  javeria
// =============================================================================
// Single-Cycle RISC-V Processor - Instruction Memory (Workshop Skeleton Version)
// =============================================================================

module Instruction_Memory (
    input  logic [31:0] address,
    output logic [31:0] instruction
);
    logic [31:0] instruction_memory [0:1023];

    initial begin
        // Pehle sab NOP se initialize karo
        for (int i = 0; i < 1024; i++) begin
            instruction_memory[i] = 32'h00000013;
        end

        // File se instructions load karo
        $readmemh("/home/javeria/Documents/Final_Year_Project/rtl/vector_processor/instruction_mem.txt", instruction_memory);
    end

    always_comb begin
        instruction = instruction_memory[address[11:2]];
    end
endmodule

