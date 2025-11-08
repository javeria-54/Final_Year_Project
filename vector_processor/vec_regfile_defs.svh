//Author        : Zawaher Bin Asim , UET Lahore
//Description   : This the header file  for  register file of the vector processor
// Date         : 13 Sep, 2024.



`ifndef vec_regfile_defs
`define vec_regfile_defs

`include "vector_processor_defs.svh"


// Maximum number of vector registers (32 in total)
`define   MAX_VEC_REGISTERS  32

// The width of the address based on the architecture of the instruction
parameter   ADDR_WIDTH = `XLEN;

// The data width is based on the maximum VLEN, adjusted dynamically in the module
parameter   DATA_WIDTH = `MAX_VLEN;

// The width of the variable that tells the width of the vector register that is useful
parameter   VECTOR_LENGTH = $clog2(`MAX_VLEN);

`endif
