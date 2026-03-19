//////////////////////////////////////////////////////////////////////////////////
// Company: NA
// Engineer: Muhammad Bilal Matloob
// 
// Create Date: 09/26/2024 04:39:47 AM
// Design Name: Mask Unit (Corrected Version)
// Module Name: vector_mask_unit
// Project Name: RISC_V VPU (Vector Processing Unit)
//////////////////////////////////////////////////////////////////////////////////


`include "vector_processor_defs.svh"
`include "vec_regfile_defs.svh"
module vector_mask_unit(

    input  logic [4095:0] lanes_data_out,
    input  logic [4095:0] destination_data,
    input  logic [3:0]    mask_op,
    input  logic          mask_en,
    input  logic          mask_reg_en,
    input  logic          vta,
    input  logic          vma,
    input  logic [31:0]   vstart,
    input  logic [31:0]   vl,
    input  logic [6:0]    sew,
    input  logic [511:0]  vs1,
    input  logic [511:0]  vs2,
    input  logic [511:0]  v0,
    output  logic [1:0]   sew_sel,
    input  logic [63:0]   carry_out,

    output logic [4095:0] mask_unit_output,
    output logic [511:0]  mask_reg_updated 
);

    // ----------------------------------------------------------
    // Internal signals
    // ----------------------------------------------------------
    logic [511:0]  mask_reg;          // FIX: single declaration only (removed duplicate)
    logic [511:0]  prestart_check;
    logic [511:0]  body_check;
    logic [511:0]  tail_check;
    logic [511:0]  v0_updated;
    logic [4095:0] mask_output_01;
    logic [4095:0] mask_output_02;
    logic [4095:0] mask_output_03;
    logic [4095:0] mask_output_04;
    logic [4095:0] selected_output;

    // ----------------------------------------------------------
    // Submodule Instantiations
    // ----------------------------------------------------------

    comb_for_vsew_08 UUT01(
        .lanes_data_out  (lanes_data_out),
        .destination_data(destination_data),
        .mask_reg        (mask_reg),
        .prestart_check  (prestart_check),
        .body_check      (body_check),
        .tail_check      (tail_check),
        .vta             (vta),
        .vma             (vma),
        .mask_output_01  (mask_output_01)
    );

    comb_for_vsew_16 UUT02(
        .lanes_data_out  (lanes_data_out),
        .destination_data(destination_data),
        .mask_reg        (mask_reg),
        .prestart_check  (prestart_check),
        .body_check      (body_check),
        .tail_check      (tail_check),
        .vta             (vta),
        .vma             (vma),
        .mask_output_02  (mask_output_02)
    );

    comb_for_vsew_32 UUT03(
        .lanes_data_out  (lanes_data_out),
        .destination_data(destination_data),
        .mask_reg        (mask_reg),
        .prestart_check  (prestart_check),
        .body_check      (body_check),
        .tail_check      (tail_check),
        .vta             (vta),
        .vma             (vma),
        .mask_output_03  (mask_output_03)
    );

    comb_for_vsew_64 UUT04(
        .lanes_data_out  (lanes_data_out),
        .destination_data(destination_data),
        .mask_reg        (mask_reg),
        .prestart_check  (prestart_check),
        .body_check      (body_check),
        .tail_check      (tail_check),
        .vta             (vta),
        .vma             (vma),
        .mask_output_04  (mask_output_04)
    );

    comb_mask_operations UUT05(
        .vs1             (vs1),
        .vs2             (vs2),
        .mask_op         (mask_op),
        .sew_sel         (sew_sel),
        .carry_out       (carry_out),
        .mask_reg_updated(mask_reg_updated)
    );

    sew_encoder UUT06(
        .sew    (sew),
        .sew_sel(sew_sel)
    );

    mux4x1 UUT07(
        .mask_output_01 (mask_output_01),
        .mask_output_02 (mask_output_02),
        .mask_output_03 (mask_output_03),
        .mask_output_04 (mask_output_04),
        .sew_sel        (sew_sel),
        .selected_output(selected_output)
    );

    mux_output UUT08(
        .selected_output (selected_output),
        .lanes_data_out  (lanes_data_out),
        .mask_en         (mask_en),
        .mask_unit_output(mask_unit_output)
    );

    mux2x1 UUT09(
        .v0              (v0),
        .mask_reg_updated(mask_reg_updated),
        .mask_reg_en     (mask_reg_en),
        .v0_updated      (v0_updated)
    );

    check_generator UUT10(
        .vl            (vl),
        .vstart        (vstart),
        .v0_updated    (v0_updated),
        .mask_reg      (mask_reg),
        .prestart_check(prestart_check),
        .body_check    (body_check),
        .tail_check    (tail_check)
    );
    
endmodule


//////////////////////////////////////////////////////////////////////////////////
//  MODULE: comb_mask_operations
//////////////////////////////////////////////////////////////////////////////////
module comb_mask_operations (
    input  logic [511:0] vs1,
    input  logic [511:0] vs2,
    input  logic [3:0]   mask_op,
    input logic  [1:0]   sew_sel,     
    input  logic [63:0]  carry_out,
    output logic [511:0] mask_reg_updated
);

    // FIX: declare loop variable outside always_comb (SV requires this for
    //      variables used in for-loops inside procedural blocks when automatic
    //      is not set; use integer declared before the always block)
    integer i;

    always_comb begin
        mask_reg_updated = '0;

        case (mask_op)
            4'b0000:  mask_reg_updated = vs2 & vs1;
            4'b0001:  mask_reg_updated = ~(vs2 & vs1);
            4'b0010:  mask_reg_updated = vs2 & ~vs1;
            4'b0011:  mask_reg_updated = vs2 ^ vs1;
            4'b0100:  mask_reg_updated = vs2 | vs1;
            4'b0101:  mask_reg_updated = ~(vs2 | vs1);
            4'b0110:  mask_reg_updated = vs2 | ~vs1;
            4'b0111:  mask_reg_updated = ~(vs2 ^ vs1);
            4'b1000: begin
                mask_reg_updated = 512'b0;
                if (sew_sel == 2'b00) begin
                    for (i = 0; i < 64; i = i + 1) begin
                        mask_reg_updated[i] = carry_out[i];
                    end
                end
                else if (sew_sel == 2'b01) begin
                    for (i = 0; i < 64; i = i + 1) begin
                        mask_reg_updated[i] = carry_out[i*2 + 1];
                    end
                end
                else if (sew_sel == 2'b10) begin
                    for (i = 0; i < 64; i = i + 1) begin
                        mask_reg_updated[i] = carry_out[i*4 + 3];
                    end
                end
            end

            default: mask_reg_updated = '0;
        endcase
    end

endmodule


//////////////////////////////////////////////////////////////////////////////////
//  MODULE: sew_encoder
//////////////////////////////////////////////////////////////////////////////////
module sew_encoder (
    input  logic [6:0] sew,
    output logic [1:0] sew_sel
);
    always_comb begin
        case (sew)
            7'b0000100: sew_sel = 2'b00;
            7'b0001000: sew_sel = 2'b01;
            7'b0010000: sew_sel = 2'b10;
            7'b0100000: sew_sel = 2'b11;
            default:    sew_sel = 2'b00;
        endcase
    end
endmodule


//////////////////////////////////////////////////////////////////////////////////
//  MODULE: check_generator
//////////////////////////////////////////////////////////////////////////////////
module check_generator (
    input  logic [31:0]  vl,
    input  logic [31:0]  vstart,
    input  logic [511:0] v0_updated,
    output logic [511:0] mask_reg,
    output logic [511:0] prestart_check,
    output logic [511:0] body_check,
    output logic [511:0] tail_check
);

    always_comb begin
        mask_reg = v0_updated;

        if (vstart == '0)
            prestart_check = '0;
        else
            prestart_check = ~({512{1'b1}} << vstart);

        if (vl == '0)
            body_check = '0;
        else
            body_check = (~({512{1'b1}} << vl)) & ({512{1'b1}} << vstart);

        tail_check = {512{1'b1}} << vl;
    end

endmodule


//////////////////////////////////////////////////////////////////////////////////
//  MODULE: comb_for_vsew_08
//////////////////////////////////////////////////////////////////////////////////
module comb_for_vsew_08 #(
    parameter SEW = 8,
    parameter VAR = 512
)(
    input  logic [4095:0] lanes_data_out,
    input  logic [4095:0] destination_data,
    input  logic [511:0]  mask_reg,
    input  logic [511:0]  prestart_check,
    input  logic [511:0]  body_check,
    input  logic [511:0]  tail_check,
    input  logic          vta,
    input  logic          vma,
    output logic [4095:0] mask_output_01
);

    generate
        genvar i;
        for (i = 0; i < VAR; i++) begin : gen_sew08
            always_comb begin
                if (prestart_check[i])
                    mask_output_01[i*SEW +: SEW] = destination_data[i*SEW +: SEW];
                else if (body_check[i] && mask_reg[i])
                    mask_output_01[i*SEW +: SEW] = lanes_data_out[i*SEW +: SEW];
                else if (body_check[i] && !mask_reg[i] && !vma)
                    mask_output_01[i*SEW +: SEW] = destination_data[i*SEW +: SEW];
                else if (body_check[i] && !mask_reg[i] && vma)
                    mask_output_01[i*SEW +: SEW] = {SEW{1'b1}};
                else if (tail_check[i] && !vta)
                    mask_output_01[i*SEW +: SEW] = destination_data[i*SEW +: SEW];
                else if (tail_check[i] && vta)
                    mask_output_01[i*SEW +: SEW] = {SEW{1'b1}};
                else
                    mask_output_01[i*SEW +: SEW] = destination_data[i*SEW +: SEW];
            end
        end
    endgenerate

endmodule


//////////////////////////////////////////////////////////////////////////////////
//  MODULE: comb_for_vsew_16
//////////////////////////////////////////////////////////////////////////////////
module comb_for_vsew_16 #(
    parameter SEW = 16,
    parameter VAR = 256
)(
    input  logic [4095:0] lanes_data_out,
    input  logic [4095:0] destination_data,
    input  logic [511:0]  mask_reg,
    input  logic [511:0]  prestart_check,
    input  logic [511:0]  body_check,
    input  logic [511:0]  tail_check,
    input  logic          vta,
    input  logic          vma,
    output logic [4095:0] mask_output_02
);

    generate
        genvar i;
        for (i = 0; i < VAR; i++) begin : gen_sew16
            always_comb begin
                if (prestart_check[i])
                    mask_output_02[i*SEW +: SEW] = destination_data[i*SEW +: SEW];
                else if (body_check[i] && mask_reg[i])
                    mask_output_02[i*SEW +: SEW] = lanes_data_out[i*SEW +: SEW];
                else if (body_check[i] && !mask_reg[i] && !vma)
                    mask_output_02[i*SEW +: SEW] = destination_data[i*SEW +: SEW];
                else if (body_check[i] && !mask_reg[i] && vma)
                    mask_output_02[i*SEW +: SEW] = {SEW{1'b1}};
                else if (tail_check[i] && !vta)
                    mask_output_02[i*SEW +: SEW] = destination_data[i*SEW +: SEW];
                else if (tail_check[i] && vta)
                    mask_output_02[i*SEW +: SEW] = {SEW{1'b1}};
                else
                    mask_output_02[i*SEW +: SEW] = destination_data[i*SEW +: SEW];
            end
        end
    endgenerate

endmodule


//////////////////////////////////////////////////////////////////////////////////
//  MODULE: comb_for_vsew_32
//////////////////////////////////////////////////////////////////////////////////
module comb_for_vsew_32 #(
    parameter SEW = 32,
    parameter VAR = 128
)(
    input  logic [4095:0] lanes_data_out,
    input  logic [4095:0] destination_data,
    input  logic [511:0]  mask_reg,
    input  logic [511:0]  prestart_check,
    input  logic [511:0]  body_check,
    input  logic [511:0]  tail_check,
    input  logic          vta,
    input  logic          vma,
    output logic [4095:0] mask_output_03
);

    generate
        genvar i;
        for (i = 0; i < VAR; i++) begin : gen_sew32
            always_comb begin
                if (prestart_check[i])
                    mask_output_03[i*SEW +: SEW] = destination_data[i*SEW +: SEW];
                else if (body_check[i] && mask_reg[i])
                    mask_output_03[i*SEW +: SEW] = lanes_data_out[i*SEW +: SEW];
                else if (body_check[i] && !mask_reg[i] && !vma)
                    mask_output_03[i*SEW +: SEW] = destination_data[i*SEW +: SEW];
                else if (body_check[i] && !mask_reg[i] && vma)
                    mask_output_03[i*SEW +: SEW] = {SEW{1'b1}};
                else if (tail_check[i] && !vta)
                    mask_output_03[i*SEW +: SEW] = destination_data[i*SEW +: SEW];
                else if (tail_check[i] && vta)
                    mask_output_03[i*SEW +: SEW] = {SEW{1'b1}};
                else
                    mask_output_03[i*SEW +: SEW] = destination_data[i*SEW +: SEW];
            end
        end
    endgenerate

endmodule


//////////////////////////////////////////////////////////////////////////////////
//  MODULE: comb_for_vsew_64
//////////////////////////////////////////////////////////////////////////////////
module comb_for_vsew_64 #(
    parameter SEW = 64,
    parameter VAR = 64
)(
    input  logic [4095:0] lanes_data_out,
    input  logic [4095:0] destination_data,
    input  logic [511:0]  mask_reg,
    input  logic [511:0]  prestart_check,
    input  logic [511:0]  body_check,
    input  logic [511:0]  tail_check,
    input  logic          vta,
    input  logic          vma,
    output logic [4095:0] mask_output_04
);

    generate
        genvar i;
        for (i = 0; i < VAR; i++) begin : gen_sew64
            always_comb begin
                if (prestart_check[i])
                    mask_output_04[i*SEW +: SEW] = destination_data[i*SEW +: SEW];
                else if (body_check[i] && mask_reg[i])
                    mask_output_04[i*SEW +: SEW] = lanes_data_out[i*SEW +: SEW];
                else if (body_check[i] && !mask_reg[i] && !vma)
                    mask_output_04[i*SEW +: SEW] = destination_data[i*SEW +: SEW];
                else if (body_check[i] && !mask_reg[i] && vma)
                    mask_output_04[i*SEW +: SEW] = {SEW{1'b1}};
                else if (tail_check[i] && !vta)
                    mask_output_04[i*SEW +: SEW] = destination_data[i*SEW +: SEW];
                else if (tail_check[i] && vta)
                    mask_output_04[i*SEW +: SEW] = {SEW{1'b1}};
                else
                    mask_output_04[i*SEW +: SEW] = destination_data[i*SEW +: SEW];
            end
        end
    endgenerate

endmodule


//////////////////////////////////////////////////////////////////////////////////
//  MODULE: mux2x1
//////////////////////////////////////////////////////////////////////////////////
module mux2x1 (
    input  logic [511:0] v0,
    input  logic [511:0] mask_reg_updated,
    input  logic         mask_reg_en,
    output logic [511:0] v0_updated
);

    always_comb begin
        if (!mask_reg_en)
            v0_updated = v0;
        else
            v0_updated = mask_reg_updated;
    end

endmodule


//////////////////////////////////////////////////////////////////////////////////
//  MODULE: mux4x1
//////////////////////////////////////////////////////////////////////////////////
module mux4x1 (
    input  logic [4095:0] mask_output_01,
    input  logic [4095:0] mask_output_02,
    input  logic [4095:0] mask_output_03,
    input  logic [4095:0] mask_output_04,
    input  logic [1:0]    sew_sel,
    output logic [4095:0] selected_output
);

    always_comb begin
        case (sew_sel)
            2'b00:   selected_output = mask_output_01;
            2'b01:   selected_output = mask_output_02;
            2'b10:   selected_output = mask_output_03;
            2'b11:   selected_output = mask_output_04;
            default: selected_output = mask_output_01;
        endcase
    end

endmodule


//////////////////////////////////////////////////////////////////////////////////
//  MODULE: mux_output
//////////////////////////////////////////////////////////////////////////////////
module mux_output (
    input  logic [4095:0] selected_output,
    input  logic [4095:0] lanes_data_out,
    input  logic          mask_en,
    output logic [4095:0] mask_unit_output
);

    always_comb begin
        if (!mask_en)
            mask_unit_output = lanes_data_out;
        else
            mask_unit_output = selected_output;
    end

endmodule