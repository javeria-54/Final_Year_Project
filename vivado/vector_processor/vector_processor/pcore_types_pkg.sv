// pcore_types_pkg.sv
`ifndef PCore_TYPES_PKG_SV
`define PCore_TYPES_PKG_SV

package pcore_types_pkg;
    
    // Keep your existing type here
    typedef enum logic [1:0] {
        ST_OPS_NONE = 2'b00,
        ST_OPS_SB   = 2'b01,
        ST_OPS_SH   = 2'b10,
        ST_OPS_SW   = 2'b11
    } type_st_ops_e;

endpackage : pcore_types_pkg

`endif