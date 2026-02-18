// Copyright 2025 Maktab-e-Digital Systems Lahore.
// Licensed under the Apache License, Version 2.0, see LICENSE file for details.
// SPDX-License-Identifier: Apache-2.0
//
// Author: javeria
// =============================================================================
// Single-Cycle RISC-V Processor - Program Counter (Workshop Skeleton Version)
// =============================================================================


module Progam_Counter(
     input logic [31:0] pc_in,
     input logic clk,rst, 
     output logic [31:0] pc_next
     );
 
     always_ff @(posedge clk or posedge rst) begin
         if (rst) 
             pc_next <= 32'b0;
         else 
             pc_next <= pc_in;
     end
 
 
 endmodule
