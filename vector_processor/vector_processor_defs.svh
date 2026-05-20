//Author        : Zawaher Bin Asim , UET Lahore
//Description   : This the header file  for  vector processor
// Date         : 15 Sep, 2024.

`ifndef vector_processor_defs
`define vector_processor_defs

// The architecture of the processor 32 bit or 64 bit 
`define XLEN 32
 
// The width of the vector register in the register file inspite of the lmul  
`define VLEN 128
// The width of the data signals . it depends  upon the "VLEN * max(lmul)" here the max of lmul is 8 
`define MAX_VLEN 1024
// The width of the memory data bus
`define DATA_BUS    512
// Write stobe for memory
parameter WR_STROB = `DATA_BUS/8;

`define ROB_DEPTH  256
`define Tag_Width  8
`define REG_ADDR_W  5
`define VREG_ADDR_W 5

`define VIQ_DEPTH  256
`define VIQ_tag_width 8
`define INSTR_W    32
`define OPERAND_W  32
//`define ENTRY_W  101
`define ENTRY_W  (`Tag_Width + `INSTR_W + `OPERAND_W + `OPERAND_W + 1)

`endif
