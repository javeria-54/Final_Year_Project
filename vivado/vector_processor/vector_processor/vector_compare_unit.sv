// vec_compare_execution_unit.sv
`include "vector_regfile_defs.svh"
`include "vector_processor_defs.svh"
`include "vector_execution_unit.svh"

//////////////////////////////////////////////////////////////////////////////////
// Design Name: Vector Compare Unit
// Project    : RISC-V VPU (Vector Processing Unit)
//
// Description:
//   This module implements a fully combinational vector comparison unit.
//   It performs element-wise comparisons between two input vectors (dataA
//   and dataB) and produces a PACKED MASK result where each BIT i holds
//   the boolean comparison result for element i.
//
//   Output Format (RISC-V V Spec compliant):
//     compare_result is a packed mask register:
//       bit[i] = 1  if comparison is TRUE  for element i
//       bit[i] = 0  if comparison is FALSE for element i
//     All upper bits (beyond num_elements) are zero-filled.
//
//   Example — SEW=32, VLEN=128, 4 elements, all true:
//     compare_result = 128'h0000_0000_0000_0000_0000_0000_0000_000F
//     (bits [3:0] = 4'b1111)
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
//   SEW Encoding (sew input):
//   ┌──────┬───────┬──────────────────────────────┐
//   │ sew  │ Width │ Elements = VLEN / SEW         │
//   ├──────┼───────┼──────────────────────────────┤
//   │ 2'b00│  8    │ VLEN / 8                      │
//   │ 2'b01│  16   │ VLEN / 16                     │
//   │ 2'b10│  32   │ VLEN / 32                     │
//   │ 2'b11│  64   │ (not implemented, default=0)  │
//   └──────┴───────┴──────────────────────────────┘
//
//   Since logic is purely combinational, compare_done is always 1.
//////////////////////////////////////////////////////////////////////////////////

module vector_compare_unit (

    // ----------------------------------------------------------
    // INPUTS
    // ----------------------------------------------------------

    // Operand A: Full-width vector (VLEN bits)
    input  logic [`VLEN-1:0] dataA,

    // Operand B: Full-width vector (VLEN bits)
    input  logic [`VLEN-1:0] dataB,

    // Comparison operation select (3-bit)
    input  logic [2:0]       cmp_op,

    // Standard Element Width (2-bit)
    // 2'b00=8-bit, 2'b01=16-bit, 2'b10=32-bit, 2'b11=64-bit
    input  logic [1:0]       sew,

    // ----------------------------------------------------------
    // OUTPUTS
    // ----------------------------------------------------------

    // Result: PACKED MASK — bit[i] = comparison result for element i
    // Rest of bits are zero
    output logic [`VLEN-1:0] compare_result,

    // Done flag: always 1 since this is purely combinational
    output logic             compare_done
);

    // ----------------------------------------------------------
    // Comparison Operation Enum
    // ----------------------------------------------------------
    typedef enum logic [2:0] {
        CMP_EQ  = 3'b000,   // Equal:                 B == A
        CMP_NE  = 3'b001,   // Not Equal:             B != A
        CMP_LTU = 3'b010,   // Less Than Unsigned:    B <  A (unsigned)
        CMP_LEU = 3'b011,   // Less/Equal Unsigned:   B <= A (unsigned)
        CMP_LT  = 3'b100,   // Less Than Signed:      B <  A (signed)
        CMP_LE  = 3'b101,   // Less/Equal Signed:     B <= A (signed)
        CMP_GT  = 3'b110,   // Greater Than Signed:   B >  A *pseudo: swap then LT*
        CMP_GTU = 3'b111    // Greater Than Unsigned: B >  A *pseudo: swap then LTU*
    } cmp_op_e;

    // ----------------------------------------------------------
    // Internal signals
    // ----------------------------------------------------------
    logic [`VLEN-1:0] raw_result;
    logic             use_swapped;

    // ----------------------------------------------------------
    // Main combinational logic
    // KEY CHANGE: result is packed — bit[i] = cmp result for element i
    // NOT {(SEW-1)'b0, cmp} per element anymore
    // ----------------------------------------------------------
    always_comb begin
        raw_result  = '0;
        compare_done = 1'b1;  // Always done — purely combinational

        // GT/GTU pseudo-ops: swap operands so we can reuse LT/LTU logic
        use_swapped = (cmp_op == CMP_GT || cmp_op == CMP_GTU);

        case (sew)

            // ==================================================
            // SEW = 8-bit elements
            // VLEN/8 elements → bits [VLEN/8 - 1 : 0] used
            // bit[i] = comparison result of element i
            // ==================================================
            2'b00: begin
                for (int i = 0; i < `NUM_ELEMENT_SEW8; i++) begin
                    logic [7:0] a, b, a_eff, b_eff;
                    logic       cmp;

                    a = dataA[i*8 +: 8];
                    b = dataB[i*8 +: 8];

                    // Swap for GT/GTU pseudo-ops
                    a_eff = use_swapped ? b : a;
                    b_eff = use_swapped ? a : b;

                    case (cmp_op_e'(cmp_op))
                        CMP_EQ:  cmp = (b_eff == a_eff);
                        CMP_NE:  cmp = (b_eff != a_eff);
                        CMP_LTU: cmp = (b_eff <  a_eff);
                        CMP_LEU: cmp = (b_eff <= a_eff);
                        CMP_LT:  cmp = ($signed(b_eff) <  $signed(a_eff));
                        CMP_LE:  cmp = ($signed(b_eff) <= $signed(a_eff));
                        CMP_GT:  cmp = ($signed(b_eff) <  $signed(a_eff)); // after swap → GT
                        CMP_GTU: cmp = (b_eff <  a_eff);                   // after swap → GTU
                        default: cmp = 1'b0;
                    endcase

                    // PACKED: store 1 bit at position i
                    raw_result[i] = cmp;
                end
            end

            // ==================================================
            // SEW = 16-bit elements
            // VLEN/16 elements → bits [VLEN/16 - 1 : 0] used
            // bit[i] = comparison result of element i
            // ==================================================
            2'b01: begin
                for (int i = 0; i < `NUM_ELEMENT_SEW16; i++) begin
                    logic [15:0] a, b, a_eff, b_eff;
                    logic        cmp;

                    a = dataA[i*16 +: 16];
                    b = dataB[i*16 +: 16];

                    a_eff = use_swapped ? b : a;
                    b_eff = use_swapped ? a : b;

                    case (cmp_op_e'(cmp_op))
                        CMP_EQ:  cmp = (b_eff == a_eff);
                        CMP_NE:  cmp = (b_eff != a_eff);
                        CMP_LTU: cmp = (b_eff <  a_eff);
                        CMP_LEU: cmp = (b_eff <= a_eff);
                        CMP_LT:  cmp = ($signed(b_eff) <  $signed(a_eff));
                        CMP_LE:  cmp = ($signed(b_eff) <= $signed(a_eff));
                        CMP_GT:  cmp = ($signed(b_eff) <  $signed(a_eff));
                        CMP_GTU: cmp = (b_eff <  a_eff);
                        default: cmp = 1'b0;
                    endcase

                    // PACKED: store 1 bit at position i
                    raw_result[i] = cmp;
                end
            end

            // ==================================================
            // SEW = 32-bit elements
            // VLEN/32 elements → bits [VLEN/32 - 1 : 0] used
            // bit[i] = comparison result of element i
            //
            // Example: VLEN=128, 4 elements, all true
            //   raw_result = 128'h...0000_000F  (bits[3:0] = 1111)
            //   Matches Spike: v12[0] = 0x000000000000000f ✓
            // ==================================================
            2'b10: begin
                for (int i = 0; i < `NUM_ELEMENT_SEW32; i++) begin
                    logic [31:0] a, b, a_eff, b_eff;
                    logic        cmp;

                    a = dataA[i*32 +: 32];
                    b = dataB[i*32 +: 32];

                    a_eff = use_swapped ? b : a;
                    b_eff = use_swapped ? a : b;

                    case (cmp_op_e'(cmp_op))
                        CMP_EQ:  cmp = (b_eff == a_eff);
                        CMP_NE:  cmp = (b_eff != a_eff);
                        CMP_LTU: cmp = (b_eff <  a_eff);
                        CMP_LEU: cmp = (b_eff <= a_eff);
                        CMP_LT:  cmp = ($signed(b_eff) <  $signed(a_eff));
                        CMP_LE:  cmp = ($signed(b_eff) <= $signed(a_eff));
                        CMP_GT:  cmp = ($signed(b_eff) <  $signed(a_eff));
                        CMP_GTU: cmp = (b_eff <  a_eff);
                        default: cmp = 1'b0;
                    endcase

                    // PACKED: store 1 bit at position i
                    raw_result[i] = cmp;
                end
            end

            // SEW=64 not implemented
            default: begin
                raw_result   = '0;
                compare_done = 1'b1;
            end

        endcase
    end

    // ----------------------------------------------------------
    // Output assignments
    // ----------------------------------------------------------
    assign compare_result = raw_result;

endmodule