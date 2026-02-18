//Author        : Zawaher Bin Asim , UET Lahore
//Description   : This the header file  for  vector processor
// Date         : 15 Sep, 2024.

`ifndef vector_processor_defs
`define vector_processor_defs

// The architecture of the processor 32 bit or 64 bit 
`define XLEN 32
 
// The width of the vector register in the register file inspite of the lmul  
`define VLEN 512
// The width of the data signals . it depends  upon the "VLEN * max(lmul)" here the max of lmul is 8 
`define MAX_VLEN 4096
// The width of the memory data bus
`define DATA_BUS    512
// Write stobe for memory
parameter WR_STROB = `DATA_BUS/8;

`endif
