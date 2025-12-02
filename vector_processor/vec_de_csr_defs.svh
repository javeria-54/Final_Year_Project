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

typedef enum logic [5:0] {
    VADD = 6'b000000,
    VSUB = 6'b000010,
    VRSUB = 6'b000011,
    VMINU = 6'b000100,
    VMIN = 6'b000101,
    VMAXU = 6'b000110,
    VMAX = 6'b000111,
    VAND = 6'b001001,
    VOR = 6'b001010,
    VXOR = 6'b001011,
    
    VADC = 6'b010000,
    VMADC = 6'b010001,
    VSBC = 6'b010010,
    VMSBC = 6'b010011,
    VMSEQ = 6'b011000,
    VMSNE = 6'b011001,
    VMSLTU = 6'b011010,
    VMSLT = 6'b011011,
    VMSLEU = 6'b011100,
    VMSLE = 6'b011101,
    VMSGTU = 6'b011110,
    VMSGT = 6'b011111,

    VSLL = 6'b100101,
    VSMUL = 6'b100111,
    VSRL = 6'b101000,
    VSRA = 6'b101001,
    VSSRL = 6'b101010,
    VSSRA = 6'b101011,
    VNSRL = 6'b101100,
    VNSRA = 6'b101101

} v_func6_vix_e;

typedef enum logic [5:0] {
    VMULHU = 6'b100100,
    VMUL = 6'b100101,
    VMULHSU = 6'b100110,
    VMULH = 6'b100111,
    VMADD = 6'b101001,
    VNMSUB = 6'b101011

} v_func6_vx_e;

typedef enum logic [2:0] {
    OPIVV = 3'b000,
    OPIVI = 3'b011,
    OPIVX = 3'b100,
    OPMVV = 3'b010,
    OPMVX = 3'b110,
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