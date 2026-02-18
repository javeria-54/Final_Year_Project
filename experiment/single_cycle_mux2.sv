// Copyright 2025 Maktab-e-Digital Systems Lahore.
// Licensed under the Apache License, Version 2.0, see LICENSE file for details.
// SPDX-License-Identifier: Apache-2.0
//
// Author:  javeria
// =============================================================================
// Single-Cycle RISC-V Processor - Instruction Memory (Workshop Skeleton Version)
// =============================================================================

module mux_2(
     input logic s,
     input logic [31:0] a0,a1,
     output logic [31:0] y
 );
     always_comb begin
         case(s)
         1'h0:  y = a0;
         1'h1:  y = a1;
         endcase
     end 
 
 endmodule