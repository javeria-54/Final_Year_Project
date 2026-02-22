// vec_compare_execution_unit.sv
`include "vec_regfile_defs.svh"
`include "vector_processor_defs.svh"

//////////////////////////////////////////////////////////////////////////////////
// Design Name: Vector Compare Unit
// Project    : RISC-V VPU (Vector Processing Unit)
//
// Description:
//   This module implements a fully combinational vector comparison unit.
//   It performs element-wise comparisons between two input vectors (dataA
//   and dataB) and produces a result vector where each element contains
//   a 1-bit comparison result (0 or 1) in the LSB.
//
//   Supports all four element widths (SEW = 8, 16, 32, 64 bits) and
//   eight comparison operations including two pseudo-operations (GT, GTU)
//   that are implemented by swapping operands internally.
//
//   Supported Operations:
//   ┌─────────┬─────────┬───────────────────────────────────────────┐
//   │ cmp_op  │ Name    │ Operation                                 │
//   ├─────────┼─────────┼───────────────────────────────────────────┤
//   │ 3'b000  │ CMP_EQ  │ B == A  (equal)                           │
//   │ 3'b001  │ CMP_NE  │ B != A  (not equal)                       │
//   │ 3'b010  │ CMP_LTU │ B <  A  (less than, unsigned)             │
//   │ 3'b011  │ CMP_LEU │ B <= A  (less than or equal, unsigned)    │
//   │ 3'b100  │ CMP_LT  │ B <  A  (less than, signed)               │
//   │ 3'b101  │ CMP_LE  │ B <= A  (less than or equal, signed)      │
//   │ 3'b110  │ CMP_GT  │ B >  A  (greater than, signed) *pseudo*   │
//   │ 3'b111  │ CMP_GTU │ B >  A  (greater than, unsigned) *pseudo* │
//   └─────────┴─────────┴───────────────────────────────────────────┘
//
//   Pseudo-Operations (GT, GTU):
//     CMP_GT and CMP_GTU are implemented by swapping A and B before
//     the comparison. This avoids dedicated hardware:
//       B > A  ≡  A < B  (swap operands, then use LT)
//
//   Output Format:
//     Each element in compare_result holds the boolean result in its LSB.
//     Upper bits of each element are zero-filled.
//     Example for SEW=8: element i = {7'b0, cmp_result}
//
//   SEW Encoding (sew input):
//   ┌──────┬───────┬──────────────────────────────┐
//   │ sew  │ Width │ Elements = MAX_VLEN / SEW     │
//   ├──────┼───────┼──────────────────────────────┤
//   │ 2'b00│  8    │ MAX_VLEN / 8                 │
//   │ 2'b01│  16   │ MAX_VLEN / 16                │
//   │ 2'b10│  32   │ MAX_VLEN / 32                │
//   │ 2'b11│  64   │ (not implemented, default=0) │
//   └──────┴───────┴──────────────────────────────┘
//
//   Since logic is purely combinational, compare_done is always 1.
//////////////////////////////////////////////////////////////////////////////////

module vector_compare_unit (

    // ----------------------------------------------------------
    // INPUTS
    // ----------------------------------------------------------

    // Operand A: Full-width vector (MAX_VLEN bits)
    // Used as the right-hand side of comparisons (B op A)
    input  logic [`MAX_VLEN-1:0] dataA,

    // Operand B: Full-width vector (MAX_VLEN bits)
    // Used as the left-hand side of comparisons (B op A)
    input  logic [`MAX_VLEN-1:0] dataB,

    // Comparison operation select (3-bit)
    // Maps to cmp_op_e enum values
    input  logic [2:0]           cmp_op,

    // Standard Element Width (2-bit)
    // 2'b00=8-bit, 2'b01=16-bit, 2'b10=32-bit, 2'b11=64-bit
    input  logic [1:0]           sew,

    // ----------------------------------------------------------
    // OUTPUTS
    // ----------------------------------------------------------

    // Result vector: each element holds {(SEW-1)'b0, cmp_bit}
    // LSB of each element = 1 if comparison true, 0 if false
    output logic [`MAX_VLEN-1:0] compare_result,

    // Done flag: always 1 since this is purely combinational
    output logic                 compare_done
);

    // ----------------------------------------------------------
    // Comparison Operation Enum
    // Maps 3-bit op codes to human-readable names
    // ----------------------------------------------------------
    typedef enum logic [2:0] {
        CMP_EQ  = 3'b000,   // Equal:                B == A
        CMP_NE  = 3'b001,   // Not Equal:            B != A
        CMP_LTU = 3'b010,   // Less Than Unsigned:   B <  A (unsigned)
        CMP_LEU = 3'b011,   // Less/Equal Unsigned:  B <= A (unsigned)
        CMP_LT  = 3'b100,   // Less Than Signed:     B <  A (signed)
        CMP_LE  = 3'b101,   // Less/Equal Signed:    B <= A (signed)
        CMP_GT  = 3'b110,   // Greater Than Signed:  B >  A *pseudo: swap A,B then LT*
        CMP_GTU = 3'b111    // Greater Than Unsigned: B > A *pseudo: swap A,B then LTU*
    } cmp_op_e;

    // ----------------------------------------------------------
    // Internal signals
    // ----------------------------------------------------------

    // Intermediate result before output assignment
    logic [`MAX_VLEN-1:0] raw_result;

    // Flag: indicates if operands should be swapped (GT/GTU pseudo-ops)
    // GT and GTU are implemented as: swap(A,B) then apply LT/LTU
    // This avoids needing separate GT hardware
    logic use_swapped;

    // ----------------------------------------------------------
    // Main combinational logic
    // Iterates over all elements, applies comparison, packs result
    // ----------------------------------------------------------
    always_comb begin
        raw_result = '0;

        // Determine if this is a pseudo GT/GTU operation
        // If yes, A and B will be swapped inside each element's loop
        use_swapped = (cmp_op == CMP_GT || cmp_op == CMP_GTU);

        case (sew)

            // ==================================================
            // SEW = 8-bit elements
            // Each element is 8 bits, result stored in {7'b0, cmp}
            // Loop runs MAX_VLEN/8 times
            // ==================================================
            2'b00: begin
                for (int i = 0; i < `MAX_VLEN/8; i++) begin
                    logic [7:0] a, b;   // Local 8-bit operands for this element
                    logic cmp;          // 1-bit comparison result

                    // Extract element i from each input vector
                    a = dataA[i*8 +: 8];
                    b = dataB[i*8 +: 8];

                    // For GT/GTU: swap A and B so we can reuse LT/LTU logic
                    // B > A  is the same as  A < B  (with operands swapped)
                    if (use_swapped) begin
                        logic [7:0] t;
                        t = a; a = b; b = t;
                    end

                    // Perform comparison based on selected operation
                    case (cmp_op_e'(cmp_op))
                        CMP_EQ:  cmp = (b == a);                           // Equal
                        CMP_NE:  cmp = (b != a);                           // Not equal
                        CMP_LT:  cmp = ($signed(b) <  $signed(a));         // Signed less than
                        CMP_LE:  cmp = ($signed(b) <= $signed(a));         // Signed less/equal
                        CMP_LTU: cmp = (b <  a);                           // Unsigned less than
                        CMP_LEU: cmp = (b <= a);                           // Unsigned less/equal
                        CMP_GT:  cmp = ($signed(b) >  $signed(a));         // Signed GT (after swap)
                        CMP_GTU: cmp = (b > a);                            // Unsigned GT (after swap)
                        default: cmp = 1'b0;                               // Invalid op: false
                    endcase

                    // Pack result: cmp bit in LSB, upper 7 bits zero
                    raw_result[i*8 +: 8] = {7'b0, cmp};
                end
            end

            // ==================================================
            // SEW = 16-bit elements
            // Each element is 16 bits, result stored in {15'b0, cmp}
            // Loop runs MAX_VLEN/16 times
            // ==================================================
            2'b01: begin
                for (int i = 0; i < `MAX_VLEN/16; i++) begin
                    logic [15:0] a, b;  // Local 16-bit operands for this element
                    logic cmp;          // 1-bit comparison result

                    // Extract 16-bit element i
                    a = dataA[i*16 +: 16];
                    b = dataB[i*16 +: 16];

                    // Swap for GT/GTU pseudo-operations
                    if (use_swapped) begin
                        logic [15:0] t;
                        t = a; a = b; b = t;
                    end

                    case (cmp_op_e'(cmp_op))
                        CMP_EQ:  cmp = (b == a);
                        CMP_NE:  cmp = (b != a);
                        CMP_LT:  cmp = ($signed(b) <  $signed(a));
                        CMP_LE:  cmp = ($signed(b) <= $signed(a));
                        CMP_LTU: cmp = (b <  a);
                        CMP_LEU: cmp = (b <= a);
                        CMP_GT:  cmp = ($signed(b) >  $signed(a));
                        CMP_GTU: cmp = (b > a);
                        default: cmp = 1'b0;
                    endcase

                    // Pack result: cmp bit in LSB, upper 15 bits zero
                    raw_result[i*16 +: 16] = {15'b0, cmp};
                end
            end

            // ==================================================
            // SEW = 32-bit elements
            // Each element is 32 bits, result stored in {31'b0, cmp}
            // Loop runs MAX_VLEN/32 times
            // ==================================================
            2'b10: begin
                for (int i = 0; i < `MAX_VLEN/32; i++) begin
                    logic [31:0] a, b;  // Local 32-bit operands for this element
                    logic cmp;          // 1-bit comparison result

                    // Extract 32-bit element i
                    a = dataA[i*32 +: 32];
                    b = dataB[i*32 +: 32];

                    // Swap for GT/GTU pseudo-operations
                    if (use_swapped) begin
                        logic [31:0] t;
                        t = a; a = b; b = t;
                    end

                    case (cmp_op_e'(cmp_op))
                        CMP_EQ:  cmp = (b == a);
                        CMP_NE:  cmp = (b != a);
                        CMP_LT:  cmp = ($signed(b) <  $signed(a));
                        CMP_LE:  cmp = ($signed(b) <= $signed(a));
                        CMP_LTU: cmp = (b <  a);
                        CMP_LEU: cmp = (b <= a);
                        CMP_GT:  cmp = ($signed(b) >  $signed(a));
                        CMP_GTU: cmp = (b > a);
                        default: cmp = 1'b0;
                    endcase

                    // Pack result: cmp bit in LSB, upper 31 bits zero
                    raw_result[i*32 +: 32] = {31'b0, cmp};
                end
            end

            // SEW=64 not implemented; output zero by default
            default: raw_result = '0;

        endcase
    end

    // ----------------------------------------------------------
    // Output assignments
    // ----------------------------------------------------------

    // Forward raw_result to output port
    assign compare_result = raw_result;

    // Always 1: purely combinational, result is always ready
    assign compare_done   = 1'b1;

endmodule