`include "vec_regfile_defs.svh"
`include "vector_processor_defs.svh"

//////////////////////////////////////////////////////////////////////////////////
// Design Name: Vector Bitwise Unit
// Project    : RISC-V VPU (Vector Processing Unit)
//
// Description:
//   This module implements a fully combinational vector bitwise and
//   comparison unit. It supports 8 operations across all four element
//   widths (SEW = 8, 16, 32, 64 bits).
//
//   For each SEW, the full MAX_VLEN-bit vector is divided into independent
//   elements, and the selected operation is applied to each element in
//   parallel using a for-loop inside always_comb.
//
//   Supported Operations:
//   ┌─────────────┬──────────┬────────────────────────────────────┐
//   │ bitwise_op  │ Name     │ Operation                          │
//   ├─────────────┼──────────┼────────────────────────────────────┤
//   │ 5'b00000    │ ALU_AND  │ B & A  (bitwise AND)               │
//   │ 5'b00001    │ ALU_OR   │ B | A  (bitwise OR)                │
//   │ 5'b00010    │ ALU_XOR  │ B ^ A  (bitwise XOR)               │
//   │ 5'b00011    │ ALU_NOT  │ ~B     (bitwise NOT, pseudo-op)    │
//   │ 5'b00100    │ ALU_MINU │ min(B, A) unsigned                 │
//   │ 5'b00101    │ ALU_MIN  │ min(B, A) signed                   │
//   │ 5'b00110    │ ALU_MAXU │ max(B, A) unsigned                 │
//   │ 5'b00111    │ ALU_MAX  │ max(B, A) signed                   │
//   └─────────────┴──────────┴────────────────────────────────────┘
//
//   SEW Encoding (sew input):
//   ┌──────┬───────┬──────────────────────────────────────────┐
//   │ sew  │ Width │ Number of Elements (MAX_VLEN / SEW)      │
//   ├──────┼───────┼──────────────────────────────────────────┤
//   │ 2'b00│  8    │ MAX_VLEN / 8                             │
//   │ 2'b01│  16   │ MAX_VLEN / 16                            │
//   │ 2'b10│  32   │ MAX_VLEN / 32                            │
//   │ 2'b11│  64   │ MAX_VLEN / 64                            │
//   └──────┴───────┴──────────────────────────────────────────┘
//
//   Output is always valid (bitwise_done = 1) since logic is purely
//   combinational — no clock or handshake required.
//////////////////////////////////////////////////////////////////////////////////

module vector_bitwise_unit (

    // ----------------------------------------------------------
    // INPUTS
    // ----------------------------------------------------------

    // Operand A: Full-width vector input (MAX_VLEN bits)
    // Used as the second operand in most operations
    input  logic [`MAX_VLEN-1:0] dataA,

    // Operand B: Full-width vector input (MAX_VLEN bits)
    // Used as the primary operand (result is based on B for NOT)
    input  logic [`MAX_VLEN-1:0] dataB,

    // Operation select code (5-bit)
    // Maps to alu_op_e enum: AND, OR, XOR, NOT, MINU, MIN, MAXU, MAX
    input  logic [4:0]           bitwise_op,

    // Standard Element Width selector (2-bit)
    // 2'b00=8-bit, 2'b01=16-bit, 2'b10=32-bit, 2'b11=64-bit
    input  logic [1:0]           sew,

    // ----------------------------------------------------------
    // OUTPUTS
    // ----------------------------------------------------------

    // Result vector: element-wise operation result (MAX_VLEN bits)
    output logic [`MAX_VLEN-1:0] bitwise_result,

    // Done flag: always 1 since this is purely combinational
    output logic                 bitwise_done
);

    // ----------------------------------------------------------
    // ALU Operation Enum
    // Maps 5-bit operation codes to readable names
    // ----------------------------------------------------------
    typedef enum logic [4:0] {
        ALU_AND  = 5'b00000,   // Bitwise AND:  B & A
        ALU_OR   = 5'b00001,   // Bitwise OR:   B | A
        ALU_XOR  = 5'b00010,   // Bitwise XOR:  B ^ A
        ALU_NOT  = 5'b00011,   // Bitwise NOT:  ~B  (A is ignored)
        ALU_MINU = 5'b00100,   // Unsigned MIN: min(B, A)
        ALU_MIN  = 5'b00101,   // Signed   MIN: min(signed B, signed A)
        ALU_MAXU = 5'b00110,   // Unsigned MAX: max(B, A)
        ALU_MAX  = 5'b00111    // Signed   MAX: max(signed B, signed A)
    } alu_op_e;

    // ----------------------------------------------------------
    // Internal signals
    // ----------------------------------------------------------

    // Intermediate result before assignment to output
    logic [`MAX_VLEN-1:0] raw_result;

    // Number of elements = MAX_VLEN / SEW (computed from sew input)
    int num_elements;

    // ----------------------------------------------------------
    // Compute number of elements based on SEW
    // This determines how many iterations the for-loop runs
    // ----------------------------------------------------------
    always_comb begin
        case (sew)
            2'b00: num_elements = `MAX_VLEN / 8;    // SEW=8:  e.g. 512/8  = 64 elements
            2'b01: num_elements = `MAX_VLEN / 16;   // SEW=16: e.g. 512/16 = 32 elements
            2'b10: num_elements = `MAX_VLEN / 32;   // SEW=32: e.g. 512/32 = 16 elements
            2'b11: num_elements = `MAX_VLEN / 64;   // SEW=64: e.g. 512/64 = 8  elements
            default: num_elements = `MAX_VLEN / 32; // Safe default: 32-bit
        endcase
    end

    // ----------------------------------------------------------
    // Main combinational logic
    // Applies the selected operation element-by-element for each SEW
    // Each SEW case extracts slices of the appropriate width,
    // applies the operation, and packs results back into raw_result
    // ----------------------------------------------------------
    always_comb begin
        raw_result = '0;  // Default: zero all bits

        case (sew)

            // ==================================================
            // SEW = 8-bit elements
            // Each element is 8 bits wide
            // Loop iterates num_elements = MAX_VLEN/8 times
            // ==================================================
            2'b00: begin
                for (int i = 0; i < num_elements; i++) begin
                    logic [7:0] a, b, res;

                    // Extract 8-bit element i from each operand
                    a = dataA[i*8 +: 8];
                    b = dataB[i*8 +: 8];

                    // Apply selected operation to this element
                    case (alu_op_e'(bitwise_op))
                        ALU_AND:  res = b & a;                                   // Bitwise AND
                        ALU_OR:   res = b | a;                                   // Bitwise OR
                        ALU_XOR:  res = b ^ a;                                   // Bitwise XOR
                        ALU_NOT:  res = ~b;                                      // Bitwise NOT (A unused)
                        ALU_MINU: res = (b < a) ? b : a;                        // Unsigned minimum
                        ALU_MIN:  res = ($signed(b) < $signed(a)) ? b : a;      // Signed minimum
                        ALU_MAXU: res = (b > a) ? b : a;                        // Unsigned maximum
                        ALU_MAX:  res = ($signed(b) > $signed(a)) ? b : a;      // Signed maximum
                        default:  res = b;                                       // Pass-through B
                    endcase

                    // Write result back to correct position in output vector
                    raw_result[i*8 +: 8] = res;
                end
            end

            // ==================================================
            // SEW = 16-bit elements
            // Each element is 16 bits wide
            // Loop iterates num_elements = MAX_VLEN/16 times
            // ==================================================
            2'b01: begin
                for (int i = 0; i < num_elements; i++) begin
                    logic [15:0] a, b, res;

                    // Extract 16-bit element i from each operand
                    a = dataA[i*16 +: 16];
                    b = dataB[i*16 +: 16];

                    case (alu_op_e'(bitwise_op))
                        ALU_AND:  res = b & a;
                        ALU_OR:   res = b | a;
                        ALU_XOR:  res = b ^ a;
                        ALU_NOT:  res = ~b;
                        ALU_MINU: res = (b < a) ? b : a;
                        ALU_MIN:  res = ($signed(b) < $signed(a)) ? b : a;
                        ALU_MAXU: res = (b > a) ? b : a;
                        ALU_MAX:  res = ($signed(b) > $signed(a)) ? b : a;
                        default:  res = b;
                    endcase

                    raw_result[i*16 +: 16] = res;
                end
            end

            // ==================================================
            // SEW = 32-bit elements
            // Each element is 32 bits wide
            // Loop iterates num_elements = MAX_VLEN/32 times
            // ==================================================
            2'b10: begin
                for (int i = 0; i < num_elements; i++) begin
                    logic [31:0] a, b, res;

                    // Extract 32-bit element i from each operand
                    a = dataA[i*32 +: 32];
                    b = dataB[i*32 +: 32];

                    case (alu_op_e'(bitwise_op))
                        ALU_AND:  res = b & a;
                        ALU_OR:   res = b | a;
                        ALU_XOR:  res = b ^ a;
                        ALU_NOT:  res = ~b;
                        ALU_MINU: res = (b < a) ? b : a;
                        ALU_MIN:  res = ($signed(b) < $signed(a)) ? b : a;
                        ALU_MAXU: res = (b > a) ? b : a;
                        ALU_MAX:  res = ($signed(b) > $signed(a)) ? b : a;
                        default:  res = b;
                    endcase

                    raw_result[i*32 +: 32] = res;
                end
            end

            // ==================================================
            // SEW = 64-bit elements
            // Each element is 64 bits wide
            // Loop iterates num_elements = MAX_VLEN/64 times
            // ==================================================
            2'b11: begin
                for (int i = 0; i < num_elements; i++) begin
                    logic [63:0] a, b, res;

                    // Extract 64-bit element i from each operand
                    a = dataA[i*64 +: 64];
                    b = dataB[i*64 +: 64];

                    case (alu_op_e'(bitwise_op))
                        ALU_AND:  res = b & a;
                        ALU_OR:   res = b | a;
                        ALU_XOR:  res = b ^ a;
                        ALU_NOT:  res = ~b;
                        ALU_MINU: res = (b < a) ? b : a;
                        ALU_MIN:  res = ($signed(b) < $signed(a)) ? b : a;
                        ALU_MAXU: res = (b > a) ? b : a;
                        ALU_MAX:  res = ($signed(b) > $signed(a)) ? b : a;
                        default:  res = b;
                    endcase

                    raw_result[i*64 +: 64] = res;
                end
            end

            // Invalid SEW: zero output
            default: raw_result = '0;

        endcase
    end

    // ----------------------------------------------------------
    // Output assignments
    // ----------------------------------------------------------

    // Forward raw_result to output
    assign bitwise_result = raw_result;

    // Always 1: this module is purely combinational, no latency
    assign bitwise_done   = 1'b1;

endmodule