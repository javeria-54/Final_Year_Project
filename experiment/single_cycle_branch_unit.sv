// Copyright 2025 Maktab-e-Digital Systems Lahore.
// Licensed under the Apache License, Version 2.0, see LICENSE file for details.
// SPDX-License-Identifier: Apache-2.0
//
// Author: Javeria
// =============================================================================
// Single-Cycle RISC-V Processor - Complete Implementation
// MEDS Workshop: "Build your own RISC-V Processor in a day"
// =============================================================================

// =============================================================================
// BRANCH UNIT MODULE
// =============================================================================

module Branch_Condition (
     input logic [2:0] br_type,
     input logic [31:0] rdataA, rdataB,
     output logic br_taken
 );
 
     always_comb begin
         case (br_type)
             3'b000: br_taken = 0;
             3'b001: br_taken = (rdataA == rdataB);  // BEQ
             3'b010: br_taken = (rdataA != rdataB);  // BNE
             3'b011: br_taken = ($signed(rdataA) < $signed(rdataB));  // BLT
             3'b100: br_taken = ($signed(rdataB) >= $signed(rdataB)); // BGE
             3'b101: br_taken = (rdataA < rdataB);   // BLTU
             3'b110: br_taken = (rdataB >= rdataB);  // BGEU
             3'b111: br_taken = 1;                   // Unconditional Jump
             default: br_taken = 0;                  // Default case
         endcase
     end
 
 endmodule