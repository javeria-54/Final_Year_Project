`ifndef vec_de_csr_defs
`define vec_de_csr_defs

`include "vector_processor_defs.svh"

parameter VLMAX = 16 ;
parameter CSR_ADDR = 12;

  ////////////////////////////////
  //  Vector instruction types  //
  ////////////////////////////////

typedef enum logic [6:0] {
    V_ARITH = 7'h57,
    V_LOAD  = 7'h07,
    V_STORE = 7'h27
} v_opcode_e;

typedef enum logic [2:0] {
    OPIVV = 3'b000,
    OPIVI = 3'b011,
    OPIVX = 3'b100,
    CONF  = 3'b111
} v_func3_e;

// CSR vtype structure
typedef struct packed {
    logic        ill;
    logic [22:0] reserved;
    logic        vma;
    logic        vta;
    logic [2:0]  vsew;
    logic [2:0]  vlmul;
} csr_vtype_s;

// Length multiplier
typedef enum logic [2:0] {
  LMUL_1    = 3'b000,
  LMUL_2    = 3'b001,
  LMUL_4    = 3'b010,
  LMUL_8    = 3'b011,
  LMUL_RSVD = 3'b100
} vlmul_e;

// Element width
typedef enum logic [2:0] {
  EW8    = 3'b000,
  EW16   = 3'b001,
  EW32   = 3'b010,
  EW64   = 3'b011,
  EWRSVD = 3'b1xx
} vew_e;

// CSR Registers addresses
typedef enum logic [11:0] {
  CSR_VSTART = 12'h008,
  CSR_VTYPE  = 12'hC20,
  CSR_VL     = 12'hC21
} csr_reg_e;

typedef struct packed {
    logic [31:26] func6;
    logic vm;
    logic [24:20] rs2;
    logic [19:15] rs1;
    v_func3_e func3;
    logic [11:7] rd;
    logic [6:0] opcode;
} varith_type_t;

`endif