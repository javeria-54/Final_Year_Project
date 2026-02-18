module vec_csr_dec #(
    XLEN = 32
) (
    input logic             clk,
    input logic             n_rst,

    // testbench -> vector_extension
    input logic [XLEN-1:0]  vec_inst,
    input logic [XLEN-1:0]  rs1_data,
    input logic [XLEN-1:0]  rs2_data,

    // vec-csr-dec -> vec-regfile
    output logic [4:0]      vec_read_addr_1,
    output logic [4:0]      vec_read_addr_2,
    output logic [4:0]      vec_write_addr,
    output logic [4:0]      vec_imm,
    output logic            vec_mask,

    // vec-csr-dec -> vec-csr / vec-regfile
    output logic [XLEN-1:0] scalar1,
    output logic [XLEN-1:0] scalar2,

    // vec-csr-dec -> scalar-processor
    output logic [XLEN-1:0] csr_out,

    // vec_decode -> vector load
    output logic [2:0]      width,
    output logic            mew,
    output logic [2:0]      nf,

    // vec-csr-dec -> vector-processor
    output logic [3:0]      vlmul,
    output logic [5:0]      sew,
    output logic            tail_agnostic,    // vector tail agnostic 
    output logic            mask_agnostic,    // vector mask agnostic
    output logic [XLEN-1:0] vec_length,
    output logic [XLEN-1:0] start_element,

    // vector_extension -> testbench
    output logic            is_vec_inst

);

// vec_decode -> regfile
logic [4:0]         rs1_addr, rs2_addr, rd_addr;

// vec_control_signals -> vec_decode
logic               vl_sel;
logic               vtype_sel;
logic               rs1rd_de;
logic               lumop_sel;
logic               rs1_sel;

// vec_control_signals -> vec_csr
logic               csrwr_en;

// vector decode instruction
// TODO implement instructions of store
// implemented for the vector configuration registers
vec_decode vector_decode (

    // scalar_processor -> vec_decode
        .vec_inst           (vec_inst),
        .rs1_data           (rs1_data),
        .rs2_data           (rs2_data),

    // vec_decode -> scalar_processor
        .is_vec             (is_vec_inst),

    // vec_decode -> vec_regfile
        .vec_read_addr_1    (vec_read_addr_1),
        .vec_read_addr_2    (vec_read_addr_2),

        .vec_write_addr     (vec_write_addr),
        .vec_imm            (vec_imm),
        .vec_mask           (vec_mask),

    // vec_decode -> vector_load
        .width              (width),
        .mew                (mew),
        .nf                 (nf),

    // vec_decode -> csr
        .scalar1            (scalar1),
        .scalar2            (scalar2),

    // vec_control_signals -> vec_decode
        .vl_sel             (vl_sel),
        .vtype_sel          (vtype_sel),
        .rs1rd_de           (rs1rd_de),
        .lumop_sel          (lumop_sel),
        .rs1_sel            (rs1_sel)
);

// implemented only for vectror configuration instructions
vector_processor_controller vector_controller (
    // scalar_processor -> vector_exctension
        .vec_inst           (vec_inst),

    // vec_control_signasl -> vec_decode 
        .vl_sel             (vl_sel),
        .vtype_sel          (vtype_sel),
        .rs1rd_de           (rs1rd_de),
        .lumop_sel          (lumop_sel),
        .rs1_sel            (rs1_sel),

    // vec_control_signals -> csr
        .csrwr_en           (csrwr_en)          
);

// CSR registers vtype and vl
vec_csr_regfile vec_csr_regfile (
        .clk                (clk),
        .n_rst              (n_rst),

    // scalar_processor -> csr_regfile
        .inst               (vec_inst),

    // csr_regfile ->  scalar-processor
        .csr_out            (csr_out),

    // vec_decode -> vec_csr_regs
        .scalar1            (scalar1),
        .scalar2            (scalar2),

    // vec_control_signals -> vec_csr_regs
        .csrwr_en           (csrwr_en),

    // vec_csr_regs -> 
        .vlmul              (vlmul),
        .sew                (sew),
        .tail_agnostic      (tail_agnostic),
        .mask_agnostic      (mask_agnostic),

        .vec_length         (vec_length),
        .start_element      (start_element)
);

endmodule