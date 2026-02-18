// Copyright 2025 Maktab-e-Digital Systems Lahore.
// Licensed under the Apache License, Version 2.0, see LICENSE file for details.
// SPDX-License-Identifier: Apache-2.0
//
// Author:  javeria
// =============================================================================
// Single-Cycle RISC-V Processor - Instruction Memory (Workshop Skeleton Version)
// =============================================================================
module mux_4(
      input logic [1:0] s,
     input logic [31:0] a0,a1,a2,a3,
     output logic [31:0] y
 );
     always_comb begin
         case(s)
         2'h0:  y = a0;
         2'h1:  y = a1;
         2'h2:  y = a2;
         2'h3:  y = a3;
         endcase
     end 
 
 endmodule