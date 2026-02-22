// Copyright 2025 Maktab-e-Digital Systems Lahore.
// Licensed under the Apache License, Version 2.0, see LICENSE file for details.
// SPDX-License-Identifier: Apache-2.0
//
// Author: javeria
// =============================================================================
// Single-Cycle RISC-V Processor - Top-Level Module (Workshop Skeleton Version)
// =============================================================================

module single_cycle_processor_top(
    input  logic clk,rst,
    input  logic pc_enable,
    output logic is_vector
    
 );
 logic [31:0] A,B;
 logic [31:0] C;
 logic [31:0] ALU_out;
 logic [31:0] instruction;
 
 logic[31:0] pc_next;
 Progam_Counter pr_c1(C,pc_enable,clk,rst,pc_next);


 Instruction_Memory inst_mem1(pc_next,instruction);

 logic reg_wr, rd_en, wr_en, sel_A, sel_B;
 logic [1:0] wb_sel;
 logic [2:0] br_type;
 logic [3:0] alu_op ; 
 Controller c1(instruction,reg_wr, rd_en, wr_en, sel_A, sel_B,wb_sel,br_type,is_vector,alu_op );

 logic [31:0] w_in,rdataA,rdataB;
 logic br_taken;
 Branch_Condition b1(br_type,rdataA,rdataB,br_taken);
 
 logic [4:0] rs1,rs2,rsd;
 register_file rf1(rs1,rs2,rsd,w_in,clk,rst,reg_wr,rdataA,rdataB);

 logic[31:0] immediate_value;
 Immediate_Generator im_g1(instruction,immediate_value);

 
 ALU a1(alu_op,A,B,is_vector,ALU_out);

 logic [31:0] rdata,wdata,address;
 Data_Memory dm1(clk,rst,wr_en,rd_en,address,wdata,rdata);

 mux_2 muxA(sel_A,pc_next,rdataA,A);
 mux_2 muxB(sel_B,rdataB,immediate_value,B);
 mux_4 m4(wb_sel,pc_next+4,ALU_out,rdata,32'b0,wdata);
 mux_2 muxC(br_taken,pc_next+4,ALU_out,C);
 
 always_comb begin
     w_in = wdata;
     rs1 = instruction[19:15];
     rs2 = instruction[24:20];
     rsd = instruction[11:7];
 end
 
 endmodule