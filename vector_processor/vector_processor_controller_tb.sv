`timescale 1ns/1ps

`include "vec_de_csr_defs.svh"
`include "vector_processor_defs.svh"

module tb_vector_processor_controller;

    // DUT inputs
    logic [`XLEN-1:0] vec_inst;

    // DUT outputs
    logic vl_sel;
    logic vtype_sel;
    logic lumop_sel;
    logic rs1rd_de;

    logic csrwr_en;

    logic sew_eew_sel;
    logic vlmax_evlmax_sel;
    logic emul_vlmul_sel;

    logic vec_reg_wr_en;
    logic mask_operation;
    logic mask_wr_en;
    logic [1:0] data_mux1_sel;
    logic data_mux2_sel;
    logic offset_vec_en;

    logic stride_sel;
    logic ld_inst;
    logic st_inst;
    logic index_str;
    logic index_unordered;

    // -------------------------------------------------
    // DUT instantiation 
    // -------------------------------------------------
    vector_processor_controller dut (
        .vec_inst(vec_inst),

        .vl_sel(vl_sel),
        .vtype_sel(vtype_sel),
        .lumop_sel(lumop_sel),
        .rs1rd_de(rs1rd_de),

        .csrwr_en(csrwr_en),

        .sew_eew_sel(sew_eew_sel),
        .vlmax_evlmax_sel(vlmax_evlmax_sel),
        .emul_vlmul_sel(emul_vlmul_sel),

        .vec_reg_wr_en(vec_reg_wr_en),
        .mask_operation(mask_operation),
        .mask_wr_en(mask_wr_en),
        .data_mux1_sel(data_mux1_sel),
        .data_mux2_sel(data_mux2_sel),
        .offset_vec_en(offset_vec_en),

        .stride_sel(stride_sel),
        .ld_inst(ld_inst),
        .st_inst(st_inst),
        .index_str(index_str),
        .index_unordered(index_unordered)
    );

    // -------------------------------------------------
    // Test sequence 
    // -------------------------------------------------
    initial begin
        $display(" Starting Vector Processor Controller TB ");

        // Default
        vec_inst = '0;
        #10;

        // ---------------------------------------------
        // VADD.VV (OPIVV)
        // ---------------------------------------------
        vec_inst[6:0]   = V_ARITH;
        vec_inst[14:12]= OPIVV;
        vec_inst[31:26]= VADD;
        #10;

        // ---------------------------------------------
        // VADD.VV (OPIVV)
        // ---------------------------------------------
        vec_inst[6:0]   = V_ARITH;
        vec_inst[14:12]= OPIVV;
        vec_inst[31:26]= VSLL;
        #10;

        // ---------------------------------------------
        // VADD.VV (OPIVV)
        // ---------------------------------------------
        vec_inst[6:0]   = V_ARITH;
        vec_inst[14:12]= OPIVV;
        vec_inst[31:26]= VSRL;
        #10;

        // ---------------------------------------------
        // VADD.VV (OPIVV)
        // ---------------------------------------------
        vec_inst[6:0]   = V_ARITH;
        vec_inst[14:12]= OPIVV;
        vec_inst[31:26]= VSRA;
        #10;

        // ---------------------------------------------
        // VSUB.VX (OPIVX)
        // ---------------------------------------------
        vec_inst[6:0]   = V_ARITH;
        vec_inst[14:12]= OPIVX;
        vec_inst[31:26]= VSUB;
        #10;

        // ---------------------------------------------
        // VMUL.VV (OPMVV)
        // ---------------------------------------------
        vec_inst[6:0]   = V_ARITH;
        vec_inst[14:12]= OPMVV;
        vec_inst[31:26]= VMUL;
        #10;

        // ---------------------------------------------
        // Vector Load (Unit stride)
        // ---------------------------------------------
        vec_inst[6:0]   = V_LOAD;
        vec_inst[27:26]= 2'b00;   // unit stride
        #10;

        // ---------------------------------------------
        // Vector Store (Indexed)
        // ---------------------------------------------
        vec_inst[6:0]   = V_STORE;
        vec_inst[27:26]= 2'b01;   // indexed
        #10;

        // ---------------------------------------------
        // VSETVLI
        // ---------------------------------------------
        vec_inst[6:0]   = V_ARITH;
        vec_inst[14:12]= CONF;
        vec_inst[31]   = 1'b0;
        #10;

        $display(" Testbench completed successfully ");
        $finish;
    end

    // -------------------------------------------------
    // Optional monitor 🌷
    // -------------------------------------------------
    initial begin
        $monitor("T=%0t | opcode=%0h | vec_wr=%b | ld=%b | st=%b | mux1=%b mux2=%b",
                 $time, vec_inst[6:0], vec_reg_wr_en, ld_inst, st_inst,
                 data_mux1_sel, data_mux2_sel);
    end

endmodule
