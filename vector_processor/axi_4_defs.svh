//Author        : Zawaher Bin Asim , UET Lahore
//Description   : This the header file  for  axi 4 
// Date         : 15 Sep, 2024.

`ifndef axi_4_defs
`define axi_4_defs

`define XLEN            32
`define DATA_BUS_WIDTH  512
`define MEM_DEPTH       4096

`define BURST_MAX  16  // or 256 if max len = 255
`define STROBE_WIDTH  (`DATA_BUS_WIDTH/8)

// Parameters for burst type
`define BURST_FIXED  2'b00
`define BURST_INCR   2'b01
`define BURST_WRAP   2'b10

// Parameters for the response 
`define RESP_OKAY    2'b00
`define RESP_SLVERR  2'b10
`define RESP_DECERR  2'b11

`endif
