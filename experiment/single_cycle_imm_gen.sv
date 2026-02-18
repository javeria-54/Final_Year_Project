// Copyright 2025 Maktab-e-Digital Systems Lahore.
// Licensed under the Apache License, Version 2.0, see LICENSE file for details.
// SPDX-License-Identifier: Apache-2.0
//
// Author: javeria
// =============================================================================
// Single-Cycle RISC-V Processor - Immediate Generator (Workshop Skeleton Version)
// =============================================================================

module Immediate_Generator(
     input logic [31:0] instruction,
     output logic[31:0] immediate_value
 );
 logic [6:0] opcode;
 always_comb begin
     opcode = instruction[6:0];
     case(opcode)
     7'b0110011: immediate_value = 32'b0; //R-TYPE
     7'b0100011: immediate_value = {{20{instruction[31]}}, instruction[31:25], instruction[11:7]}; //S-TYPE
     7'b1101111 : immediate_value = {{11{instruction[31]}}, instruction[31], instruction[19:12], instruction[20], instruction[30:21], 1'b0}; //J-TYPE
     7'b1100011 : immediate_value = {{19{instruction[31]}}, instruction[31], instruction[7], instruction[30:25], instruction[11:8], 1'b0}; //B-TYPE
     7'b0110111 : immediate_value = {instruction[31:12], 12'b0}; // LUI
     7'b0010111 : immediate_value = {instruction[31:12], 12'b0}; // AUIPC
     7'b0000011 : immediate_value = {{20{instruction[31]}},instruction[31:20]}; //I-TYPE(LOAD)
     7'b0010011 : immediate_value = {{20{instruction[31]}},instruction[31:20]}; //I-TYPE
    
     endcase
 end
 endmodule
 
