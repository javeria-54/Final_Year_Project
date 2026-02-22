`include "vector_processor_defs.svh"

//////////////////////////////////////////////////////////////////////////////////
// Design Name: Vector Adder/Subtractor
// Project    : RISC-V VPU (Vector Processing Unit)
//
// Description:
//   This file implements a scalable vector adder/subtractor that supports
//   three element widths: SEW=8, SEW=16, and SEW=32 bits.
//
//   Architecture Overview:
//
//   vector_adder_subtractor  (Top - processes full MAX_VLEN-bit vector)
//       └── adder_subtractor_32bit  x (MAX_VLEN/32) slices
//               └── 4x adder8          (one per 8-bit segment)
//               └── 4x mux_ctr         (carry-in initialization)
//               └── 1x mux_sew_16_32   (carry propagation for SEW=16/8)
//               └── 2x mux_sew_32      (carry propagation for SEW=32)
//
//   SEW Control Signals:
//     sew_32=0, sew_16_32=0 → SEW=8  (8-bit  independent elements)
//     sew_32=0, sew_16_32=1 → SEW=16 (16-bit independent elements)
//     sew_32=1, sew_16_32=1 → SEW=32 (32-bit full-width operation)
//
//   Carry Propagation:
//     The carry between 8-bit segments is selectively enabled/disabled
//     using mux_sew_16_32 and mux_sew_32 to create independent element
//     boundaries at 8, 16, or 32 bits.
//
//   Add/Subtract Control (Ctrl):
//     Ctrl=0 → Addition    : B passes through unchanged, Cin=0
//     Ctrl=1 → Subtraction : B is XORed with 1s (~B), Cin=1 → A + (~B) + 1 = A - B
//////////////////////////////////////////////////////////////////////////////////


//////////////////////////////////////////////////////////////////////////////////
//  MODULE: adder8
//
//  Purpose:
//    A basic 8-bit signed adder with carry-in and carry-out.
//    This is the fundamental building block of the entire adder/subtractor.
//    Four of these are chained inside adder_subtractor_32bit.
//
//  Operation:
//    {Cout, Sum} = A + B + Cin
//
//  Ports:
//    A, B  : 8-bit signed operands
//    Cin   : Carry input (used for chaining and subtraction)
//    Sum   : 8-bit signed result
//    Cout  : Carry output (passed to next segment or discarded)
//////////////////////////////////////////////////////////////////////////////////
module adder8 (
    input  logic signed [7:0] A,     // First 8-bit operand
    input  logic signed [7:0] B,     // Second 8-bit operand (may be inverted for subtraction)
    input  logic              Cin,   // Carry input
    output logic signed [7:0] Sum,   // 8-bit sum result
    output logic              Cout   // Carry output to next stage
);
    // Concatenate carry-out and sum in a single addition
    assign {Cout, Sum} = A + B + Cin;

endmodule


//////////////////////////////////////////////////////////////////////////////////
//  MODULE: mux_sew_32
//
//  Purpose:
//    Controls carry propagation between byte segments 2→3 and 3→4
//    (i.e., the upper two 8-bit adders in a 32-bit slice).
//
//    When sew_32=1 (32-bit mode): carry propagates from previous adder
//    When sew_32=0 (8-bit mode):  carry is reset to carry_ctrl (fresh start)
//
//  Truth Table:
//    sew_32 | carry_in
//    ───────┼─────────────────────────────────────
//      0    | carry_ctrl  (8-bit: no carry propagation across boundary)
//      1    | carry_out   (32-bit: carry propagates through all segments)
//////////////////////////////////////////////////////////////////////////////////
module mux_sew_32 (
    input  logic carry_out,   // Carry from the previous 8-bit adder
    input  logic carry_ctrl,  // Fresh carry-in (0 for add, 1 for sub)
    input  logic sew_32,      // 1 = 32-bit mode, 0 = 8-bit mode
    output logic carry_in     // Selected carry-in for next adder
);
    // If sew_32=0: start fresh (8-bit boundary)
    // If sew_32=1: propagate carry (32-bit operation continues)
    assign carry_in = (sew_32 == 1'b0) ? carry_ctrl : carry_out;

endmodule


//////////////////////////////////////////////////////////////////////////////////
//  MODULE: mux_sew_16_32
//
//  Purpose:
//    Controls carry propagation between byte segments 1→2
//    (between the first and second 8-bit adder in a 32-bit slice).
//
//    When sew_16_32=1 (16-bit or 32-bit mode): carry propagates
//    When sew_16_32=0 (8-bit mode):            carry is reset to carry_ctrl
//
//  Truth Table:
//    sew_16_32 | carry_in
//    ──────────┼──────────────────────────────────────
//       0      | carry_ctrl  (8-bit: independent elements, no carry cross)
//       1      | carry_out   (16 or 32-bit: carry continues to next byte)
//////////////////////////////////////////////////////////////////////////////////
module mux_sew_16_32 (
    input  logic carry_out,    // Carry from previous 8-bit adder
    input  logic carry_ctrl,   // Fresh carry-in (0 for add, 1 for sub)
    input  logic sew_16_32,    // 1 = 16 or 32-bit mode, 0 = 8-bit mode
    output logic carry_in      // Selected carry-in for next adder
);
    // If sew_16_32=0: start fresh (8-bit boundary)
    // If sew_16_32=1: propagate carry (16/32-bit operation continues)
    assign carry_in = (sew_16_32 == 1'b0) ? carry_ctrl : carry_out;

endmodule


//////////////////////////////////////////////////////////////////////////////////
//  MODULE: mux_ctr
//
//  Purpose:
//    Selects the initial carry-in value for each 8-bit adder segment
//    based on the operation type (add or subtract).
//
//    For addition    (Ctrl=0): carry_in = 0 (no initial carry)
//    For subtraction (Ctrl=1): carry_in = 1 (for 2's complement: A + ~B + 1)
//
//  Truth Table:
//    ctr | out
//    ────┼─────
//     0  | in0  (addition: 0)
//     1  | in1  (subtraction: 1)
//////////////////////////////////////////////////////////////////////////////////
module mux_ctr (
    input  logic in0,   // Value for add mode (tied to 1'b0 externally)
    input  logic in1,   // Value for sub mode (tied to 1'b1 externally)
    input  logic ctr,   // Control: 0=add, 1=subtract
    output logic out    // Selected carry value
);
    assign out = (ctr == 1'b0) ? in0 : in1;

endmodule


//////////////////////////////////////////////////////////////////////////////////
//  MODULE: adder_subtractor_32bit
//
//  Purpose:
//    A 32-bit adder/subtractor that internally uses four 8-bit adders.
//    Supports three element widths by controlling carry propagation:
//
//    SEW=8  (sew_32=0, sew_16_32=0):
//      Each 8-bit segment is fully independent.
//      Carry never crosses byte boundaries.
//      Result: 4 independent 8-bit add/subtract operations.
//
//    SEW=16 (sew_32=0, sew_16_32=1):
//      Carry propagates between segments 0→1 and 2→3.
//      Carry does NOT propagate between segments 1→2.
//      Result: 2 independent 16-bit add/subtract operations.
//
//    SEW=32 (sew_32=1, sew_16_32=1):
//      Carry propagates through all four segments.
//      Result: 1 full 32-bit add/subtract operation.
//
//  Subtraction Implementation (2's complement):
//    A - B = A + (~B) + 1
//    When Ctrl=1: each B byte is XORed with 0xFF (~B), and Cin=1 injected
//
//  Ports:
//    Ctrl      : 0=Add, 1=Subtract
//    sew_16_32 : 1 = enable carry across byte 0→1 boundary (16/32-bit)
//    sew_32    : 1 = enable carry across byte 1→2 and 2→3 boundaries (32-bit)
//    A, B      : 32-bit signed operands
//    Sum       : 32-bit signed result
//    sum_done  : Indicates valid output (1 = result ready)
//////////////////////////////////////////////////////////////////////////////////
module adder_subtractor_32bit (
    input  logic        Ctrl,              // Operation: 0=Add, 1=Subtract
    input  logic        sew_16_32,         // 1=16 or 32-bit mode, 0=8-bit mode
    input  logic        sew_32,            // 1=32-bit mode
    input  logic signed [31:0] A,          // First 32-bit operand
    input  logic signed [31:0] B,          // Second 32-bit operand
    output logic signed [31:0] Sum,        // 32-bit result
    output logic               sum_done    // 1 when result is valid
);

    // --------------------------------------------------------
    // Internal signals for 4 byte segments (indexed 0 to 3)
    // --------------------------------------------------------
    logic [7:0] A_seg[0:3];        // Byte slices of A (A_seg[0]=bits 7:0, etc.)
    logic [7:0] B_seg[0:3];        // Byte slices of B
    logic [7:0] B_xor[0:3];        // B after optional XOR with Ctrl (for subtraction)
    logic [7:0] Sum_seg[0:3];      // Output sum from each 8-bit adder

    logic [3:0] carry_out;          // Carry output from each adder8 instance
    logic [3:0] carry_ctrl;         // Carry-in from mux_ctr (0 or 1 based on Ctrl)
    logic [3:0] selected_carry;     // Final carry-in fed into each adder8

    genvar i;
    generate
        for (i = 0; i < 4; i++) begin : segment_process

            // Extract byte i from full 32-bit operands
            assign A_seg[i] = A[i*8 +: 8];
            assign B_seg[i] = B[i*8 +: 8];

            // For subtraction (Ctrl=1): XOR B with 0xFF to get ~B (2's complement step 1)
            // For addition    (Ctrl=0): XOR with 0x00, B remains unchanged
            assign B_xor[i] = B_seg[i] ^ {8{Ctrl}};

            // mux_ctr: selects carry-in initialization value
            // Add (Ctrl=0): carry_ctrl[i] = 0
            // Sub (Ctrl=1): carry_ctrl[i] = 1  (2's complement step 2: +1)
            mux_ctr ctr_mux (
                .in0(1'b0),           // For addition: initial carry = 0
                .in1(1'b1),           // For subtraction: initial carry = 1
                .ctr(Ctrl),
                .out(carry_ctrl[i])
            );

            // Carry-in selection based on element boundary and SEW mode
            if (i == 0) begin
                // Segment 0 (bits 7:0): always gets carry_ctrl directly
                // No previous adder to chain from
                assign selected_carry[i] = carry_ctrl[i];

            end else if (i == 1) begin
                // Segment 1 (bits 15:8): byte boundary between seg0 and seg1
                // mux_sew_16_32 decides if carry propagates (16/32-bit) or resets (8-bit)
                mux_sew_16_32 mux16 (
                    .carry_out (carry_out[i-1]),     // Carry from segment 0
                    .carry_ctrl(carry_ctrl[i]),      // Fresh carry-in if boundary
                    .sew_16_32 (sew_16_32),          // 1=propagate, 0=reset
                    .carry_in  (selected_carry[i])
                );

            end else begin
                // Segments 2 and 3 (bits 23:16 and 31:24): upper byte boundaries
                // mux_sew_32 decides if carry propagates (32-bit) or resets (8-bit)
                mux_sew_32 mux32 (
                    .carry_out (carry_out[i-1]),     // Carry from previous segment
                    .carry_ctrl(carry_ctrl[i]),      // Fresh carry-in if boundary
                    .sew_32    (sew_32),             // 1=propagate, 0=reset
                    .carry_in  (selected_carry[i])
                );
            end

            // 8-bit adder for this segment
            // Takes: byte of A, byte of B (possibly inverted), and selected carry-in
            adder8 adder_inst (
                .A   (A_seg[i]),
                .B   (B_xor[i]),
                .Cin (selected_carry[i]),
                .Sum (Sum_seg[i]),
                .Cout(carry_out[i])
            );
        end
    endgenerate

    // --------------------------------------------------------
    // Pack the 8-bit segment results into final 32-bit Sum
    // sum_done indicates whether the SEW setting is valid
    // --------------------------------------------------------
    always_comb begin
        Sum      = '0;
        sum_done = 1'b1;

        case ({sew_32, sew_16_32})
            // SEW=8: all four bytes are independent results
            // sew_32=0, sew_16_32=0
            2'b00: begin
                Sum      = {Sum_seg[3], Sum_seg[2], Sum_seg[1], Sum_seg[0]};
                sum_done = 1'b1;
            end

            // SEW=16: two 16-bit results packed into 32 bits
            // sew_32=0, sew_16_32=1
            2'b01: begin
                Sum      = {Sum_seg[3], Sum_seg[2], Sum_seg[1], Sum_seg[0]};
                sum_done = 1'b1;
            end

            // SEW=32: single 32-bit result
            // sew_32=1, sew_16_32=1
            2'b11: begin
                Sum      = {Sum_seg[3], Sum_seg[2], Sum_seg[1], Sum_seg[0]};
                sum_done = 1'b1;
            end

            // Invalid SEW combination: output zero and flag incomplete
            default: begin
                Sum      = 32'd0;
                sum_done = 1'b0;
            end
        endcase
    end

endmodule


//////////////////////////////////////////////////////////////////////////////////
//  MODULE: vector_adder_subtractor  (Top Module)
//
//  Purpose:
//    Top-level vector adder/subtractor that processes a full MAX_VLEN-bit
//    vector by instantiating (MAX_VLEN/32) parallel adder_subtractor_32bit
//    slices. Each slice independently processes a 32-bit portion of the
//    input vectors using the same Ctrl, sew_16_32, and sew_32 settings.
//
//  Scalability:
//    NUM_SLICES = MAX_VLEN / 32
//    e.g. if MAX_VLEN = 512 → 16 slices → 16 parallel 32-bit operations
//
//  sum_done:
//    ANDs together all sum_done signals from all slices.
//    Only asserts 1 when every slice has produced a valid result.
//
//  Ports:
//    Ctrl      : 0=Add, 1=Subtract (broadcast to all slices)
//    sew_16_32 : SEW boundary control (broadcast to all slices)
//    sew_32    : SEW boundary control (broadcast to all slices)
//    A, B      : Full-width signed vector operands (MAX_VLEN bits)
//    Sum       : Full-width signed result vector
//    sum_done  : 1 when all slices have valid outputs
//////////////////////////////////////////////////////////////////////////////////
module vector_adder_subtractor (
    input  logic                          Ctrl,       // 0=Add, 1=Subtract
    input  logic                          sew_16_32,  // 1=16 or 32-bit, 0=8-bit
    input  logic                          sew_32,     // 1=32-bit mode
    input  logic signed [`MAX_VLEN-1:0]   A,          // Full vector operand A
    input  logic signed [`MAX_VLEN-1:0]   B,          // Full vector operand B
    output logic signed [`MAX_VLEN-1:0]   Sum,        // Full vector result
    output logic                          sum_done    // All slices valid
);

    // Number of 32-bit slices needed to cover the full vector width
    localparam NUM_SLICES = (`MAX_VLEN / 32);

    // Collect sum_done from each 32-bit slice
    // Final sum_done = AND of all individual sum_done signals
    logic [NUM_SLICES-1:0] sum_done_array;

    genvar i;
    generate
        for (i = 0; i < NUM_SLICES; i++) begin : units

            // Instantiate one 32-bit adder/subtractor per slice
            // Each slice handles 32 bits of A and B independently
            adder_subtractor_32bit units (
                .Ctrl      (Ctrl),
                .sew_16_32 (sew_16_32),
                .sew_32    (sew_32),
                .A         (A[i*32 +: 32]),         // 32-bit slice of A
                .B         (B[i*32 +: 32]),         // 32-bit slice of B
                .Sum       (Sum[i*32 +: 32]),       // 32-bit result slice
                .sum_done  (sum_done_array[i])      // Per-slice valid flag
            );
        end
    endgenerate

    // Global sum_done: asserted only when ALL slices report valid output
    // Uses reduction AND operator (&) across the sum_done_array
    assign sum_done = &sum_done_array;

endmodule