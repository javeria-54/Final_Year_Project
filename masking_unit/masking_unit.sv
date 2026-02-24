//////////////////////////////////////////////////////////////////////////////////
// Company: NA
// Engineer: Muhammad Bilal Matloob
// 
// Create Date: 09/26/2024 04:39:47 AM
// Design Name: Mask Unit (Corrected Version)
// Module Name: vector_mask_unit
// Project Name: RISC_V VPU (Vector Processing Unit)
//
// Description:
//   This module implements the Vector Mask Unit for a RISC-V Vector Processing
//   Unit (VPU). It handles per-element masking according to the RISC-V V
//   extension specification. It supports:
//     - Four element widths: SEW = 8, 16, 32, 64
//     - Prestart, body, and tail element classification
//     - Tail-agnostic (vta) and mask-agnostic (vma) policies
//     - Logical mask register operations (vmand, vmor, vmxor, etc.)
//     - Mask register update control via mask_reg_en
//
// Architecture Overview:
//   ┌─────────────────────────────────────────────────────┐
//   │              vector_mask_unit (Top)                 │
//   │                                                     │
//   │  vs1,vs2 ──► comb_mask_operations ──► mask_reg_updated
//   │                                             │        │
//   │  v0 ──────► mux2x1 (mask_reg_en) ◄─────────┘        │
//   │                  │                                   │
//   │                  ▼                                   │
//   │           check_generator                            │
//   │      (prestart/body/tail/mask_reg)                   │
//   │                  │                                   │
//   │     ┌────────────┼──────────────┐                    │
//   │     ▼            ▼              ▼                    │
//   │  sew_08       sew_16    sew_32/sew_64                │
//   │     └────────────┼──────────────┘                    │
//   │                  ▼                                   │
//   │              mux4x1 (sew_sel)                        │
//   │                  │                                   │
//   │                  ▼                                   │
//   │           mux_output (mask_en) ──► mask_unit_output  │
//   └─────────────────────────────────────────────────────┘
//
// FIXES APPLIED:
//   1. Declared all internal signals in top module
//   2. Fixed check_generator logic (body_check, tail_check, mask_reg)
//   3. Added default cases in sew_encoder and comb_mask_operations
//   4. Changed part-select to +: syntax in all comb_for_vsew_* modules
//   5. Fixed v0_updated connectivity (internal signal only)
//////////////////////////////////////////////////////////////////////////////////


// ============================================================
//  TOP MODULE: vector_mask_unit
//
//  This is the top-level wrapper that connects all submodules.
//  It receives raw inputs from the vector processor pipeline
//  and produces the final masked output and updated mask register.
// ============================================================
module vector_mask_unit(

    // ----------------------------------------------------------
    // INPUTS
    // ----------------------------------------------------------

    // Data coming from the vector execution lanes (computation result)
    // Width = VLEN = 4096 bits (supports up to 512 x 8-bit elements)
    input  logic [4095:0] lanes_data_out,
    
    // Current data already present in the destination vector register
    // Used for prestart elements, undisturbed tail/mask policy
    input  logic [4095:0] destination_data,
    
    // Selects which logical operation to perform on mask registers
    // Used to update v0 from vs1 and vs2
    // 000=vmand, 001=vmnand, 010=vmandn, 011=vmxor
    // 100=vmor,  101=vmnor,  110=vmorn,  111=vmxnor
    input  logic [2:0]    mask_op,
    
    // Masking enable signal (from instruction bit vm = instr[25])
    // 0 = no masking, output = lanes_data_out directly
    // 1 = masking enabled, apply mask logic
    input  logic          mask_en,
    
    // Controls whether the mask register (v0) gets updated
    // 0 = keep existing v0
    // 1 = update v0 with mask_reg_updated (result of mask_op)
    input  logic          mask_reg_en,
    
    // Tail-agnostic bit (from CSR vtype.vta)
    // 0 = tail-undisturbed: keep destination value for tail elements
    // 1 = tail-agnostic: tail elements can be written with all 1s
    input  logic          vta,
    
    // Mask-agnostic bit (from CSR vtype.vma)
    // 0 = mask-undisturbed: keep destination for inactive body elements
    // 1 = mask-agnostic: inactive body elements can be written with all 1s
    input  logic          vma,
    
    // Starting element index (from CSR vstart)
    // Elements 0 to vstart-1 are "prestart" and are not modified
    input  logic [8:0]    vstart,
    
    // Vector length - number of active elements to process (from CSR vl)
    // Elements vstart to vl-1 are "body" (active)
    // Elements vl and above are "tail"
    input  logic [8:0]    vl,
    
    // Single element width in bits (from CSR vtype.vsew)
    // Encoded as one-hot: 6'b000100=8, 6'b001000=16, 6'b010000=32, 6'b100000=64
    input  logic [5:0]    sew,
    
    // Source mask registers for logical mask operations
    // Each bit corresponds to one vector element's mask
    input  logic [511:0]  vs1,   // First source mask register
    input  logic [511:0]  vs2,   // Second source mask register
    input  logic [511:0]  v0,    // Current mask register value

    // ----------------------------------------------------------
    // OUTPUTS
    // ----------------------------------------------------------

    // Final masked output to be written back to the destination register
    // Contains: prestart=dest, active body=lanes or dest/1s, tail=dest or 1s
    output logic [4095:0] mask_unit_output,

    // Result of the logical mask operation on vs1 and vs2
    // May or may not update v0 depending on mask_reg_en
    output logic [511:0]  mask_reg_updated 
);

    // ----------------------------------------------------------
    // Internal signals connecting submodules
    // ----------------------------------------------------------

    // Effective mask register after mux2x1 decision (v0 or mask_reg_updated)
    logic [511:0]  mask_reg;

    // Per-element region classification signals (one bit per element)
    logic [511:0]  prestart_check;  // bit[i]=1 means element i is in prestart zone
    logic [511:0]  body_check;      // bit[i]=1 means element i is in body zone
    logic [511:0]  tail_check;      // bit[i]=1 means element i is in tail zone

    // Effective v0 after considering mask_reg_en (used for mask_reg)
    logic [511:0]  v0_updated;

    // 2-bit SEW selector for 4-to-1 output mux
    logic [1:0]    sew_sel;

    // Outputs from each SEW-specific combinational masking block
    logic [4095:0] mask_output_01;  // Output for SEW=8
    logic [4095:0] mask_output_02;  // Output for SEW=16
    logic [4095:0] mask_output_03;  // Output for SEW=32
    logic [4095:0] mask_output_04;  // Output for SEW=64

    // Selected output from the 4-to-1 mux (based on current SEW)
    logic [4095:0] selected_output;

    // ----------------------------------------------------------
    // Submodule Instantiations
    // ----------------------------------------------------------

    // --- SEW=8 masking block ---
    // Handles up to 512 elements of 8-bit width
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

    // --- SEW=16 masking block ---
    // Handles up to 256 elements of 16-bit width
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

    // --- SEW=32 masking block ---
    // Handles up to 128 elements of 32-bit width
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

    // --- SEW=64 masking block ---
    // Handles up to 64 elements of 64-bit width
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

    // --- Mask register logical operations ---
    // Computes bitwise operation between vs1 and vs2 based on mask_op
    // Result (mask_reg_updated) may be written to v0 if mask_reg_en=1
    comb_mask_operations UUT05(
        .vs1             (vs1),
        .vs2             (vs2),
        .mask_op         (mask_op),
        .mask_reg_updated(mask_reg_updated)
    );

    // --- SEW encoder ---
    // Converts one-hot SEW encoding to 2-bit binary select for mux4x1
    sew_encoder UUT06(
        .sew    (sew),
        .sew_sel(sew_sel)
    );

    // --- 4-to-1 output mux ---
    // Selects the correct SEW-specific masked output based on sew_sel
    mux4x1 UUT07(
        .mask_output_01 (mask_output_01),
        .mask_output_02 (mask_output_02),
        .mask_output_03 (mask_output_03),
        .mask_output_04 (mask_output_04),
        .sew_sel        (sew_sel),
        .selected_output(selected_output)
    );

    // --- Final output mux ---
    // If mask_en=0: bypass all masking, pass lanes_data_out directly
    // If mask_en=1: use the SEW-selected masked output
    mux_output UUT08(
        .selected_output (selected_output),
        .lanes_data_out  (lanes_data_out),
        .mask_en         (mask_en),
        .mask_unit_output(mask_unit_output)
    );

    // --- Mask register update mux ---
    // Decides whether to use old v0 or new mask_reg_updated as effective mask
    // mask_reg_en=0: use existing v0 (no update)
    // mask_reg_en=1: use mask_reg_updated (result of mask_op on vs1,vs2)
    // v0_updated feeds into check_generator as the effective mask register
    mux2x1 UUT09(
        .v0              (v0),
        .mask_reg_updated(mask_reg_updated),
        .mask_reg_en     (mask_reg_en),
        .v0_updated      (v0_updated)
    );

    // --- Check generator ---
    // Generates per-element region signals based on vstart and vl
    // Also passes v0_updated as mask_reg for body element decisions
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
//
//  Purpose:
//    Performs bitwise logical operations between two 512-bit mask registers
//    (vs1 and vs2). The result updates the mask register (v0) when enabled.
//
//  Supported Operations (mask_op):
//    000 = vmand.mm  : vs2 AND vs1
//    001 = vmnand.mm : NOT(vs2 AND vs1)
//    010 = vmandn.mm : vs2 AND NOT(vs1)
//    011 = vmxor.mm  : vs2 XOR vs1
//    100 = vmor.mm   : vs2 OR vs1
//    101 = vmnor.mm  : NOT(vs2 OR vs1)
//    110 = vmorn.mm  : vs2 OR NOT(vs1)
//    111 = vmxnor.mm : NOT(vs2 XOR vs1)
//////////////////////////////////////////////////////////////////////////////////
module comb_mask_operations (
    input  logic [511:0] vs1,             // First source mask register
    input  logic [511:0] vs2,             // Second source mask register
    input  logic [2:0]   mask_op,         // Operation select (3-bit)
    output logic [511:0] mask_reg_updated // Result of the logical operation
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
            default: mask_reg_updated = '0;                  // Safe default
        endcase
    end

endmodule


//////////////////////////////////////////////////////////////////////////////////
//  MODULE: sew_encoder
//
//  Purpose:
//    Converts the one-hot encoded SEW (Single Element Width) input into a
//    2-bit binary select signal used by the 4-to-1 output mux (mux4x1).
//
//  Encoding:
//    sew = 6'b000100 (8)  → sew_sel = 2'b00
//    sew = 6'b001000 (16) → sew_sel = 2'b01
//    sew = 6'b010000 (32) → sew_sel = 2'b10
//    sew = 6'b100000 (64) → sew_sel = 2'b11
//////////////////////////////////////////////////////////////////////////////////
module sew_encoder (
    input  logic [5:0] sew,      // One-hot SEW value from CSR
    output logic [1:0] sew_sel   // 2-bit mux select signal
);
    always_comb begin
        case (sew)
            6'b000100: sew_sel = 2'b00;   // SEW = 8-bit
            6'b001000: sew_sel = 2'b01;   // SEW = 16-bit
            6'b010000: sew_sel = 2'b10;   // SEW = 32-bit
            6'b100000: sew_sel = 2'b11;   // SEW = 64-bit
            default:   sew_sel = 2'b00;   // Default to SEW=8 (safe fallback)
        endcase
    end
endmodule


//////////////////////////////////////////////////////////////////////////////////
//  MODULE: check_generator
//
//  Purpose:
//    Generates three per-element region classification vectors based on
//    vstart and vl. These are used by the SEW-specific masking blocks to
//    decide what value to write for each element.
//
//  Element Regions (per RISC-V V spec):
//    Prestart : index < vstart            → always write destination_data
//    Body     : vstart <= index < vl      → apply mask logic (mask_reg bit)
//    Tail     : index >= vl               → apply vta policy
//
//  Also passes v0_updated directly as mask_reg (no shift needed since
//  each bit i in v0 directly corresponds to element i).
//////////////////////////////////////////////////////////////////////////////////
module check_generator (
    input  logic [8:0]   vl,           // Number of active elements
    input  logic [8:0]   vstart,       // Starting element index
    input  logic [511:0] v0_updated,   // Effective mask register (from mux2x1)
    
    output logic [511:0] mask_reg,        // Mask bit per element (bit i = mask for element i)
    output logic [511:0] prestart_check,  // bit[i]=1 if element i is in prestart zone
    output logic [511:0] body_check,      // bit[i]=1 if element i is in body zone
    output logic [511:0] tail_check       // bit[i]=1 if element i is in tail zone
);

    always_comb begin

        // mask_reg: directly use v0_updated
        // Bit i of v0 corresponds to element i's mask value
        // No shifting needed — v0 is already element-indexed
        mask_reg = v0_updated;

        // prestart_check: set bits 0 to (vstart-1)
        // If vstart=0, no prestart elements exist (all zeros)
        // Example: vstart=3 → prestart_check = 512'b...0111
        if (vstart == '0)
            prestart_check = '0;
        else
            prestart_check = ~({512{1'b1}} << vstart);

        // body_check: set bits vstart to (vl-1)
        // = (bits 0..vl-1) AND NOT (bits 0..vstart-1)
        // = (~(all_ones << vl)) & (all_ones << vstart)
        // Example: vstart=2, vl=5 → body_check = 512'b...011100
        // If vl=0, no body elements (all zeros)
        if (vl == '0)
            body_check = '0;
        else
            body_check = (~({512{1'b1}} << vl)) & ({512{1'b1}} << vstart);

        // tail_check: set bits vl to 511
        // = all_ones shifted left by vl (clears bits 0..vl-1)
        // Example: vl=5 → tail_check = 512'b...1111100000
        tail_check = {512{1'b1}} << vl;

    end

endmodule


//////////////////////////////////////////////////////////////////////////////////
//  MODULE: comb_for_vsew_08
//
//  Purpose:
//    Applies masking policy to all elements when SEW=8 (8-bit elements).
//    Supports up to VAR=512 elements (512 * 8 = 4096 bits total).
//
//  Per-element decision logic (applied to each element i):
//    ┌──────────────────────────────────────┬────────────────────────┐
//    │ Condition                            │ Output                 │
//    ├──────────────────────────────────────┼────────────────────────┤
//    │ prestart_check[i] = 1                │ destination_data[i]    │
//    │ body_check[i]=1, mask_reg[i]=1       │ lanes_data_out[i]      │
//    │ body_check[i]=1, mask[i]=0, vma=0    │ destination_data[i]    │
//    │ body_check[i]=1, mask[i]=0, vma=1    │ all 1s ({SEW{1'b1}})   │
//    │ tail_check[i]=1, vta=0               │ destination_data[i]    │
//    │ tail_check[i]=1, vta=1               │ all 1s ({SEW{1'b1}})   │
//    └──────────────────────────────────────┴────────────────────────┘
//////////////////////////////////////////////////////////////////////////////////
module comb_for_vsew_08 #(
    parameter SEW = 8,    // Element width in bits
    parameter VAR = 512   // Maximum number of elements for this SEW
)(
    input  logic [4095:0] lanes_data_out,   // New computation results
    input  logic [4095:0] destination_data, // Existing destination register data
    input  logic [511:0]  mask_reg,         // Effective mask (one bit per element)
    input  logic [511:0]  prestart_check,   // Prestart region flags
    input  logic [511:0]  body_check,       // Body region flags
    input  logic [511:0]  tail_check,       // Tail region flags
    input  logic          vta,              // Tail agnostic policy
    input  logic          vma,              // Mask agnostic policy
    output logic [4095:0] mask_output_01    // Masked output for SEW=8
);

    generate
        genvar i;
        for (i = 0; i < VAR; i++) begin : gen_sew08
            always_comb begin
                // Use +: part-select: element i occupies bits [i*SEW +: SEW]
                if (prestart_check[i])
                    // Prestart: element not yet started, preserve destination
                    mask_output_01[i*SEW +: SEW] = destination_data[i*SEW +: SEW];

                else if (body_check[i] && mask_reg[i])
                    // Active body element (mask bit=1): write new result
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
                    // Safety default: preserve destination
                    mask_output_01[i*SEW +: SEW] = destination_data[i*SEW +: SEW];
            end
        end
    endgenerate

endmodule


//////////////////////////////////////////////////////////////////////////////////
//  MODULE: comb_for_vsew_16
//
//  Purpose:
//    Same masking logic as comb_for_vsew_08 but for SEW=16 (16-bit elements).
//    Supports up to VAR=256 elements (256 * 16 = 4096 bits total).
//////////////////////////////////////////////////////////////////////////////////
module comb_for_vsew_16 #(
    parameter SEW = 16,   // Element width in bits
    parameter VAR = 256   // Maximum number of elements for this SEW
)(
    input  logic [4095:0] lanes_data_out,
    input  logic [4095:0] destination_data,
    input  logic [511:0]  mask_reg,
    input  logic [511:0]  prestart_check,
    input  logic [511:0]  body_check,
    input  logic [511:0]  tail_check,
    input  logic          vta,
    input  logic          vma,
    output logic [4095:0] mask_output_02   // Masked output for SEW=16
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
//
//  Purpose:
//    Same masking logic as comb_for_vsew_08 but for SEW=32 (32-bit elements).
//    Supports up to VAR=128 elements (128 * 32 = 4096 bits total).
//////////////////////////////////////////////////////////////////////////////////
module comb_for_vsew_32 #(
    parameter SEW = 32,   // Element width in bits
    parameter VAR = 128   // Maximum number of elements for this SEW
)(
    input  logic [4095:0] lanes_data_out,
    input  logic [4095:0] destination_data,
    input  logic [511:0]  mask_reg,
    input  logic [511:0]  prestart_check,
    input  logic [511:0]  body_check,
    input  logic [511:0]  tail_check,
    input  logic          vta,
    input  logic          vma,
    output logic [4095:0] mask_output_03   // Masked output for SEW=32
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
//
//  Purpose:
//    Same masking logic as comb_for_vsew_08 but for SEW=64 (64-bit elements).
//    Supports up to VAR=64 elements (64 * 64 = 4096 bits total).
//////////////////////////////////////////////////////////////////////////////////
module comb_for_vsew_64 #(
    parameter SEW = 64,   // Element width in bits
    parameter VAR = 64    // Maximum number of elements for this SEW
)(
    input  logic [4095:0] lanes_data_out,
    input  logic [4095:0] destination_data,
    input  logic [511:0]  mask_reg,
    input  logic [511:0]  prestart_check,
    input  logic [511:0]  body_check,
    input  logic [511:0]  tail_check,
    input  logic          vta,
    input  logic          vma,
    output logic [4095:0] mask_output_04   // Masked output for SEW=64
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
//
//  Purpose:
//    Selects the effective mask register value to be used by check_generator.
//    Decides between:
//      - Keeping the old v0 (mask_reg_en=0, no mask register update)
//      - Using the new mask_reg_updated (mask_reg_en=1, mask op was performed)
//
//  Truth Table:
//    mask_reg_en | v0_updated
//    ────────────┼───────────────────
//         0      | v0               (use existing mask register)
//         1      | mask_reg_updated (use result of vmand/vmor/etc.)
//////////////////////////////////////////////////////////////////////////////////
module mux2x1 (
    input  logic [511:0] v0,               // Existing mask register value
    input  logic [511:0] mask_reg_updated, // New mask register after logical op
    input  logic         mask_reg_en,      // Select: 0=keep v0, 1=use updated
    output logic [511:0] v0_updated        // Effective mask register output
);

    always_comb begin
        if (!mask_reg_en)
            v0_updated = v0;               // No update: keep existing v0
        else
            v0_updated = mask_reg_updated; // Update: use result of mask operation
    end

endmodule


//////////////////////////////////////////////////////////////////////////////////
//  MODULE: mux4x1
//
//  Purpose:
//    Selects the correct SEW-specific masked output to forward as the
//    final result. Only one of the four comb_for_vsew_* outputs is valid
//    at a time based on the current SEW setting.
//
//  Selection:
//    sew_sel=00 → mask_output_01 (SEW=8)
//    sew_sel=01 → mask_output_02 (SEW=16)
//    sew_sel=10 → mask_output_03 (SEW=32)
//    sew_sel=11 → mask_output_04 (SEW=64)
//////////////////////////////////////////////////////////////////////////////////
module mux4x1 (
    input  logic [4095:0] mask_output_01,  // SEW=8  masking result
    input  logic [4095:0] mask_output_02,  // SEW=16 masking result
    input  logic [4095:0] mask_output_03,  // SEW=32 masking result
    input  logic [4095:0] mask_output_04,  // SEW=64 masking result
    input  logic [1:0]    sew_sel,         // 2-bit select from sew_encoder
    output logic [4095:0] selected_output  // Chosen output
);

    always_comb begin
        case (sew_sel)
            2'b00:   selected_output = mask_output_01;  // SEW=8
            2'b01:   selected_output = mask_output_02;  // SEW=16
            2'b10:   selected_output = mask_output_03;  // SEW=32
            2'b11:   selected_output = mask_output_04;  // SEW=64
            default: selected_output = mask_output_01;  // Safe default
        endcase
    end

endmodule


//////////////////////////////////////////////////////////////////////////////////
//  MODULE: mux_output
//
//  Purpose:
//    Final output stage. Decides whether to apply masking or bypass it.
//    When mask_en=0 (vm bit=1 in instruction = unmasked operation),
//    all lanes are active and the raw lane output passes through directly.
//    When mask_en=1, the selected masked output is forwarded.
//
//  Truth Table:
//    mask_en | mask_unit_output
//    ────────┼──────────────────────────────
//       0    | lanes_data_out   (bypass, no masking)
//       1    | selected_output  (masked result applied)
//////////////////////////////////////////////////////////////////////////////////
module mux_output (
    input  logic [4095:0] selected_output,   // Masked output from mux4x1
    input  logic [4095:0] lanes_data_out,    // Raw output from execution lanes
    input  logic          mask_en,           // 0=bypass masking, 1=apply masking
    output logic [4095:0] mask_unit_output   // Final output to write-back stage
);

    always_comb begin
        if (!mask_en)
            mask_unit_output = lanes_data_out;  // Bypass: all lanes active
        else
            mask_unit_output = selected_output; // Apply mask policy
    end

endmodule