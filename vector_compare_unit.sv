// vec_compare_execution_unit.sv
`include "vec_regfile_defs.svh"
`include "vector_processor_defs.svh"

module vector_compare_unit (
    // Vector inputs (already prepared outside)
    input  logic [`MAX_VLEN-1:0] dataA,   // operand A (vector)
    input  logic [`MAX_VLEN-1:0] dataB,   // operand B (vector)

    // Control
    input  logic [2:0]      cmp_op,  // compare operation
    input  logic [1:0]      sew,     // 00:8, 01:16, 10:32, 11:64

    // Output
    output logic [`MAX_VLEN-1:0] compare_result,
    output logic            compare_done
);

    typedef enum logic [2:0] {
        CMP_EQ   = 3'b000,
        CMP_NE   = 3'b001,
        CMP_LTU  = 3'b010,
        CMP_LEU  = 3'b011,
        CMP_LT   = 3'b100,
        CMP_LE   = 3'b101,
        CMP_GT   = 3'b110,  // pseudo
        CMP_GTU  = 3'b111   // pseudo
    } cmp_op_e;

    logic [`MAX_VLEN-1:0] raw_result;
    logic use_swapped;

    always_comb begin
        raw_result = '0;
        use_swapped = (cmp_op == CMP_GT || cmp_op == CMP_GTU);

        case (sew)

        // ---------------- 8-bit ----------------
        2'b00: begin
            for (int i = 0; i < `MAX_VLEN/8; i++) begin
                logic [7:0] a, b;
                logic cmp;

                a = dataA[i*8 +: 8];
                b = dataB[i*8 +: 8];

                if (use_swapped) begin
                    logic [7:0] t;
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

                raw_result[i*8 +: 8] = {7'b0, cmp};
            end
        end

        // ---------------- 16-bit ----------------
        2'b01: begin
            for (int i = 0; i < `MAX_VLEN/16; i++) begin
                logic [15:0] a, b;
                logic cmp;

                a = dataA[i*16 +: 16];
                b = dataB[i*16 +: 16];

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

                raw_result[i*16 +: 16] = {15'b0, cmp};
            end
        end

        // ---------------- 32-bit ----------------
        2'b10: begin
            for (int i = 0; i < `MAX_VLEN/32; i++) begin
                logic [31:0] a, b;
                logic cmp;

                a = dataA[i*32 +: 32];
                b = dataB[i*32 +: 32];

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

                raw_result[i*32 +: 32] = {31'b0, cmp};
            end
        end

        default: raw_result = '0;
        endcase
    end

    assign compare_result = raw_result;
    assign compare_done   = 1'b1;

endmodule
