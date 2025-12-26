`include "vector_processor_defs.svh"
// ============================================================
// RVV Single-Width Shift Unit (SEW = 8 / 16 / 32)
// Implements: vsll, vsrl, vsra (vv / vx / vi)
// No mask, no tail (handled externally)
// VLEN = 512, 4 lanes × 128-bit
// ============================================================


// ============================================================
// 1. Barrel Shifter (based on your original design)
//    - Shift only (no rotate)
//    - Logical left / logical right
// ============================================================
module barrel_shifter (
    input  logic [31:0] data_in,
    input  logic [4:0]  shift_amt,
    input  logic        left_right,   // 0 = left, 1 = right
    input  logic        shift_rotate, // unused (tied to 0)
    output logic [31:0] data_out
);
    logic [31:0] stage0, stage1, stage2, stage3;

    always_comb begin
        if (!left_right) begin // left shift
            stage0 = shift_amt[0] ? (data_in << 1)  : data_in;
            stage1 = shift_amt[1] ? (stage0 << 2)  : stage0;
            stage2 = shift_amt[2] ? (stage1 << 4)  : stage1;
            stage3 = shift_amt[3] ? (stage2 << 8)  : stage2;
            data_out = shift_amt[4] ? (stage3 << 16) : stage3;
        end
        else begin // right shift (logical)
            stage0 = shift_amt[0] ? (data_in >> 1)  : data_in;
            stage1 = shift_amt[1] ? (stage0 >> 2)  : stage0;
            stage2 = shift_amt[2] ? (stage1 >> 4)  : stage1;
            stage3 = shift_amt[3] ? (stage2 >> 8)  : stage2;
            data_out = shift_amt[4] ? (stage3 >> 16) : stage3;
        end
    end
endmodule


// ============================================================
// 2. RVV Element Shift Unit (uses barrel shifter)
// ============================================================
module rvv_shift_element (
    input  logic [31:0] vs2_elem,
    input  logic [31:0] shift_src,
    input  logic [1:0]  shift_op,   // 00=vsll, 01=vsrl, 10=vsra
    input  logic [1:0]  sew,        // 00=8, 01=16, 10=32
    output logic [31:0] vd_elem
);

    logic [4:0]  shift_amt;
    logic        left_right;
    logic [31:0] shifter_in;
    logic [31:0] shifter_out;

    // RVV shift amount masking
    always_comb begin
        case (sew)
            2'b00: shift_amt = shift_src[2:0]; // SEW=8
            2'b01: shift_amt = shift_src[3:0]; // SEW=16
            2'b10: shift_amt = shift_src[4:0]; // SEW=32
            default: shift_amt = 5'd0;
        endcase
    end

    // Operation control
    always_comb begin
        case (shift_op)
            2'b00: begin // vsll
                left_right = 1'b0;
                shifter_in = vs2_elem;
            end
            2'b01: begin // vsrl
                left_right = 1'b1;
                shifter_in = vs2_elem;
            end
            2'b10: begin // vsra
                left_right = 1'b1;
                shifter_in = {{32{vs2_elem[31]}}, vs2_elem}[31:0];
            end
            default: begin
                left_right = 1'b0;
                shifter_in = vs2_elem;
            end
        endcase
    end

    barrel_shifter u_barrel (
        .data_in      (shifter_in),
        .shift_amt    (shift_amt),
        .left_right   (left_right),
        .shift_rotate (1'b0),
        .data_out     (shifter_out)
    );

    assign vd_elem = shifter_out;

endmodule


// ============================================================
// 3. RVV Shift Lane (128-bit)
// ============================================================
module rvv_shift_lane (
    input  logic [127:0] vs2_lane,
    input  logic [127:0] vs1_lane,
    input  logic [31:0]  rs1_scalar,
    input  logic         use_scalar, // 1=vx/vi, 0=vv
    input  logic [1:0]   shift_op,
    input  logic [1:0]   sew,
    output logic [127:0] vd_lane
);

    integer i;
    logic [31:0] vs2_elem, shift_src, vd_elem;

    always_comb begin
        vd_lane = '0;

        case (sew)

            // SEW = 8
            2'b00: for (i = 0; i < 16; i++) begin
                vs2_elem  = {24'b0, vs2_lane[i*8 +: 8]};
                shift_src = use_scalar ? rs1_scalar
                                        : {24'b0, vs1_lane[i*8 +: 8]};
                rvv_shift_element u_elem (vs2_elem, shift_src, shift_op, sew, vd_elem);
                vd_lane[i*8 +: 8] = vd_elem[7:0];
            end

            // SEW = 16
            2'b01: for (i = 0; i < 8; i++) begin
                vs2_elem  = {16'b0, vs2_lane[i*16 +: 16]};
                shift_src = use_scalar ? rs1_scalar
                                        : {16'b0, vs1_lane[i*16 +: 16]};
                rvv_shift_element u_elem (vs2_elem, shift_src, shift_op, sew, vd_elem);
                vd_lane[i*16 +: 16] = vd_elem[15:0];
            end

            // SEW = 32
            2'b10: for (i = 0; i < 4; i++) begin
                vs2_elem  = vs2_lane[i*32 +: 32];
                shift_src = use_scalar ? rs1_scalar
                                        : vs1_lane[i*32 +: 32];
                rvv_shift_element u_elem (vs2_elem, shift_src, shift_op, sew, vd_elem);
                vd_lane[i*32 +: 32] = vd_elem;
            end
        endcase
    end
endmodule


// ============================================================
// 4. Top-Level RVV Shift Unit (4 lanes, 512-bit)
// ============================================================
module vector_shift_unit (
    input  logic [`MAX_VLEN-1:0] vs2_i,
    input  logic [`MAX_VLEN-1:0] vs1_i,
    input  logic [31:0]  rs1_i,
    input  logic         use_scalar,
    input  logic [1:0]   shift_op,
    input  logic [1:0]   sew,
    output logic [`MAX_VLEN-1:0] vd_o
);

    genvar l;

    generate
        for (l = 0; l < 4; l++) begin : LANES
            rvv_shift_lane u_lane (
                .vs2_lane   (vs2_i[l*128 +: 128]),
                .vs1_lane   (vs1_i[l*128 +: 128]),
                .rs1_scalar (rs1_i),
                .use_scalar (use_scalar),
                .shift_op   (shift_op),
                .sew        (sew),
                .vd_lane    (vd_o[l*128 +: 128])
            );
        end
    endgenerate

endmodule