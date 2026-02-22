//////////////////////////////////////////////////////////////////////////////////
// Company: NA
// Engineer: Muhammad Bilal Matloob
// 
// Create Date: 09/26/2024 04:39:47 AM
// Design Name: Mask Unit (Corrected Version)
// Module Name: vector_mask_unit
// Project Name: RISC_V VPU (Vector Processing Unit) 
//
// FIXES APPLIED:
//   1. Declared all internal signals in top module
//   2. Fixed check_generator logic (body_check, tail_check, mask_reg)
//   3. Added default cases in sew_encoder and comb_mask_operations
//   4. Changed part-select to +: syntax in all comb_for_vsew_* modules
//   5. Fixed v0_updated connectivity (internal signal only)
//////////////////////////////////////////////////////////////////////////////////


// ============================================================
//  TOP MODULE
// ============================================================
module vector_mask_unit(
    // Output data from lanes to be stored at destination
    input  logic [4095:0] lanes_data_out,
    
    // Currently present data at the destination register
    input  logic [4095:0] destination_data,
    
    // Mask operations for updating v0 (mask register)
    input  logic [2:0]    mask_op,
    
    // Masking enable (vm = v.instr[25])
    input  logic          mask_en,
    
    // Signal to show whether to update mask register or not
    input  logic          mask_reg_en,
    
    // Tail agnostic bit
    input  logic          vta,
    
    // Mask agnostic bit
    input  logic          vma,
    
    // Vector start index
    input  logic [8:0]    vstart,
    
    // Number of active elements
    input  logic [8:0]    vl,
    
    // Single element width [8, 16, 32, 64]
    input  logic [5:0]    sew,
    
    // Vector Mask Source Registers
    input  logic [511:0]  vs1,
    input  logic [511:0]  vs2,
    input  logic [511:0]  v0,
    
    // Final output after masking
    output logic [4095:0] mask_unit_output,

    // Updated value of mask register
    output logic [511:0]  mask_reg_updated 
);

    // --------------------------------------------------------
    // FIX #1: Declare all internal signals
    // --------------------------------------------------------
    logic [511:0]  mask_reg;
    logic [511:0]  prestart_check;
    logic [511:0]  body_check;
    logic [511:0]  tail_check;
    logic [511:0]  v0_updated;          // internal only, not an output port
    logic [1:0]    sew_sel;
    logic [4095:0] mask_output_01;
    logic [4095:0] mask_output_02;
    logic [4095:0] mask_output_03;
    logic [4095:0] mask_output_04;
    logic [4095:0] selected_output;

    // --------------------------------------------------------
    // Instantiations
    // --------------------------------------------------------

    // SEW-specific masking combinational blocks
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

    // Mask register logical operations (vmand, vmor, vmxor, etc.)
    comb_mask_operations UUT05(
        .vs1             (vs1),
        .vs2             (vs2),
        .mask_op         (mask_op),
        .mask_reg_updated(mask_reg_updated)
    );

    // SEW encoder: converts SEW value to 2-bit select
    sew_encoder UUT06(
        .sew    (sew),
        .sew_sel(sew_sel)
    );

    // 4-to-1 mux to select correct SEW output
    mux4x1 UUT07(
        .mask_output_01 (mask_output_01),
        .mask_output_02 (mask_output_02),
        .mask_output_03 (mask_output_03),
        .mask_output_04 (mask_output_04),
        .sew_sel        (sew_sel),
        .selected_output(selected_output)
    );

    // Final output mux: bypass masking if mask_en = 0
    mux_output UUT08(
        .selected_output (selected_output),
        .lanes_data_out  (lanes_data_out),
        .mask_en         (mask_en),
        .mask_unit_output(mask_unit_output)
    );

    // FIX #5: v0_updated is INTERNAL only - mux2x1 output stays inside
    mux2x1 UUT09(
        .v0              (v0),
        .mask_reg_updated(mask_reg_updated),
        .mask_reg_en     (mask_reg_en),
        .v0_updated      (v0_updated)
    );

    // Check generator: produces prestart/body/tail/mask_reg signals
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
//  MASK REGISTER LOGICAL OPERATIONS
//  FIX #3: Added default case
//////////////////////////////////////////////////////////////////////////////////
module comb_mask_operations (
    input  logic [511:0] vs1,
    input  logic [511:0] vs2,
    input  logic [2:0]   mask_op,
    output logic [511:0] mask_reg_updated
);

    always_comb begin
        case (mask_op)
            3'b000:  mask_reg_updated = vs2 & vs1;          // vmand.mm
            3'b001:  mask_reg_updated = ~(vs2 & vs1);       // vmnand.mm
            3'b010:  mask_reg_updated = vs2 & ~vs1;         // vmandn.mm
            3'b011:  mask_reg_updated = vs2 ^ vs1;          // vmxor.mm
            3'b100:  mask_reg_updated = vs2 | vs1;          // vmor.mm
            3'b101:  mask_reg_updated = ~(vs2 | vs1);       // vmnor.mm
            3'b110:  mask_reg_updated = vs2 | ~vs1;         // vmorn.mm
            3'b111:  mask_reg_updated = ~(vs2 ^ vs1);       // vmxnor.mm
            default: mask_reg_updated = '0;                  // FIX: safe default
        endcase
    end

endmodule


//////////////////////////////////////////////////////////////////////////////////
//  SEW ENCODER
//  FIX #3: Added default case
//////////////////////////////////////////////////////////////////////////////////
module sew_encoder (
    input  logic [5:0] sew,
    output logic [1:0] sew_sel
);
    always_comb begin
        case (sew)
            6'b000100: sew_sel = 2'b00;   // SEW = 8
            6'b001000: sew_sel = 2'b01;   // SEW = 16
            6'b010000: sew_sel = 2'b10;   // SEW = 32
            6'b100000: sew_sel = 2'b11;   // SEW = 64
            default:   sew_sel = 2'b00;   // FIX: safe default
        endcase
    end
endmodule


//////////////////////////////////////////////////////////////////////////////////
//  CHECK GENERATOR
//  FIX #2: Corrected body_check, tail_check, and mask_reg logic
//////////////////////////////////////////////////////////////////////////////////
module check_generator (
    input  logic [8:0]   vl,
    input  logic [8:0]   vstart,
    input  logic [511:0] v0_updated,
    
    output logic [511:0] mask_reg,        // Mask bit per element (from v0)
    output logic [511:0] prestart_check,  // 1 where index < vstart
    output logic [511:0] body_check,      // 1 where vstart <= index < vl
    output logic [511:0] tail_check       // 1 where index >= vl
);

    always_comb begin
        // FIX: mask_reg is v0 directly (no shift needed)
        // Each bit i of v0 corresponds to element i
        mask_reg = v0_updated;

        // prestart: elements 0 to (vstart-1)
        // If vstart == 0, no prestart elements exist
        if (vstart == '0)
            prestart_check = '0;
        else
            prestart_check = ~({512{1'b1}} << vstart);

        // FIX: body = elements from vstart up to (vl-1)
        // body_check[i] = 1 if (vstart <= i < vl)
        if (vl == '0)
            body_check = '0;
        else
            body_check = (~({512{1'b1}} << vl)) & ({512{1'b1}} << vstart);
        //                ^--- bits 0..(vl-1) set    ^--- clear bits below vstart

        // FIX: tail = elements from vl onwards
        // tail_check[i] = 1 if i >= vl
        tail_check = {512{1'b1}} << vl;
    end

endmodule


//////////////////////////////////////////////////////////////////////////////////
//  COMBINATIONAL MASKING LOGIC FOR SEW = 8
//  FIX #4: Used +: part-select syntax
//  MAX 512 elements (512 * 8 = 4096 bits)
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
                // FIX: use +: syntax for variable part-select
                if (prestart_check[i])
                    // Prestart: keep destination value
                    mask_output_01[i*SEW +: SEW] = destination_data[i*SEW +: SEW];

                else if (body_check[i] && mask_reg[i])
                    // Active body element, mask bit = 1: take new result
                    mask_output_01[i*SEW +: SEW] = lanes_data_out[i*SEW +: SEW];

                else if (body_check[i] && !mask_reg[i] && !vma)
                    // Inactive body element, mask-undisturbed: keep destination
                    mask_output_01[i*SEW +: SEW] = destination_data[i*SEW +: SEW];

                else if (body_check[i] && !mask_reg[i] && vma)
                    // Inactive body element, mask-agnostic: write all 1s
                    mask_output_01[i*SEW +: SEW] = {SEW{1'b1}};

                else if (tail_check[i] && !vta)
                    // Tail element, tail-undisturbed: keep destination
                    mask_output_01[i*SEW +: SEW] = destination_data[i*SEW +: SEW];

                else if (tail_check[i] && vta)
                    // Tail element, tail-agnostic: write all 1s
                    mask_output_01[i*SEW +: SEW] = {SEW{1'b1}};

                else
                    // Default: keep destination (safety)
                    mask_output_01[i*SEW +: SEW] = destination_data[i*SEW +: SEW];
            end
        end
    endgenerate

endmodule


//////////////////////////////////////////////////////////////////////////////////
//  COMBINATIONAL MASKING LOGIC FOR SEW = 16
//  MAX 256 elements (256 * 16 = 4096 bits)
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
//  COMBINATIONAL MASKING LOGIC FOR SEW = 32
//  MAX 128 elements (128 * 32 = 4096 bits)
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
//  COMBINATIONAL MASKING LOGIC FOR SEW = 64
//  MAX 64 elements (64 * 64 = 4096 bits)
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
//  2-TO-1 MUX: Select between old v0 and updated mask register
//////////////////////////////////////////////////////////////////////////////////
module mux2x1 (
    input  logic [511:0] v0,
    input  logic [511:0] mask_reg_updated,
    input  logic         mask_reg_en,
    output logic [511:0] v0_updated
);

    always_comb begin
        if (!mask_reg_en)
            v0_updated = v0;               // Keep old v0
        else
            v0_updated = mask_reg_updated; // Update v0 with new mask result
    end

endmodule


//////////////////////////////////////////////////////////////////////////////////
//  4-TO-1 MUX: Select correct SEW output
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
//  OUTPUT MUX: Bypass masking if mask_en = 0
//////////////////////////////////////////////////////////////////////////////////
module mux_output (
    input  logic [4095:0] selected_output,
    input  logic [4095:0] lanes_data_out,
    input  logic          mask_en,
    output logic [4095:0] mask_unit_output
);

    always_comb begin
        if (!mask_en)
            mask_unit_output = lanes_data_out;  // No masking: pass through
        else
            mask_unit_output = selected_output; // Apply masking
    end

endmodule