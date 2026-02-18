// Copyright 2025 Maktab-e-Digital Systems Lahore.
// Licensed under the Apache License, Version 2.0, see LICENSE file for details.
// SPDX-License-Identifier: Apache-2.0
//
// Author: javeria
// =============================================================================
// Single-Cycle RISC-V Processor - Complete Implementation
// MEDS Workshop: "Build your own RISC-V Processor in a day"
// =============================================================================


module ALU(
 	input logic [3:0] alu_op,
 	input logic [31:0] A, B,
 	output logic [31:0] AB_out
 );
 
 	always_comb begin
         case (alu_op)
             4'b0000: AB_out = A + B; // ADD
             4'b0001: AB_out = A - B; // SUB
             4'b0010: AB_out = A << B[4:0]; // SLL
             4'b0011: AB_out = A >> B[4:0]; // SRL
             4'b0100: AB_out = $signed(A) >>> B[4:0]; // SRA
             4'b0101: AB_out = ($signed(A) < $signed(B)) ? 1 : 0; // SLT
             4'b0110: AB_out = (A < B) ? 1 : 0; // SLTU
             4'b0111: AB_out = A ^ B; // XOR
             4'b1000: AB_out = A | B; // OR
             4'b1001: AB_out = A & B; // AND
             4'b1010: AB_out = B; // Just Pass B
         
             default: AB_out = 32'b0;
         endcase
     end
 
 endmodule
