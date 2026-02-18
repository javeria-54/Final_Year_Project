// Copyright 2025 Maktab-e-Digital Systems Lahore.
// Licensed under the Apache License, Version 2.0, see LICENSE file for details.
// SPDX-License-Identifier: Apache-2.0
//
// Author: javeria
// =============================================================================
// Single-Cycle RISC-V Processor - Register File (Workshop Skeleton Version)
// =============================================================================

module register_file(
     input logic [4:0] raddr1,raddr2,waddr,
     input logic [31:0] wdata,
     input logic clk,rst,reg_wr,
     output logic [31:0] rdata1,rdata2
 );
 logic [31:0]reg_file[0:31];
     always_ff @(negedge clk or posedge rst) begin
          if (rst) begin 
          reg_file[0]= 32'd0;
          reg_file[1]= 32'd10;
          reg_file[2]= 32'd20;
          reg_file[3]= 32'd30;
          reg_file[4]= 32'd40;
          reg_file[5]= 32'd50;
          reg_file[6]= 32'd60;
          reg_file[7]= 32'd70;
          reg_file[8]= 32'd80;
          reg_file[9]= 32'd90;
          reg_file[10]= 32'd100;
          reg_file[11]= 32'd110;
          reg_file[12]= 32'd120;
          reg_file[13]= 32'd130;
          reg_file[14]= 32'd140;
          reg_file[15]= 32'd150;
          reg_file[16]= 32'd160;
          reg_file[17]= 32'd170;
          reg_file[18]= 32'd180;
          reg_file[19]= 32'd190;
          reg_file[20]= 32'd200;
          reg_file[21]= 32'd210;
          reg_file[22]= 32'd220;
          reg_file[23]= 32'd230;
          reg_file[24]= 32'd240;
          reg_file[25]= 32'd250;
          reg_file[26]= 32'd260;
          reg_file[27]= 32'd270;
          reg_file[28]= 32'd280;
          reg_file[29]= 32'd290;
          reg_file[30]= 32'd300;
          reg_file[31]= 32'd310;
          end
          else begin
             if(reg_wr)
                 reg_file[waddr] <= wdata;
             reg_file[0] <= 32'd0;
 
          end
 
     end
     always_comb begin
 
         rdata1 = reg_file[raddr1];
         rdata2 = reg_file[raddr2];
 
     end
 
 
 
 endmodule