`include "vec_regfile_defs.svh"
`include "vector_processor_defs.svh"

module vector_shift_unit #(
    parameter VLEN = 4096,
    parameter ELEN = 32
)(
    // Prepared operands
    input  logic [VLEN-1:0] dataA,  // shift amount
    input  logic [VLEN-1:0] dataB,  // value to shift

    // Control
    input  logic [2:0]       shift_op, // Shift operation
    input  logic [1:0]       sew,      // Standard Element Width

    // Output
    output logic [VLEN-1:0]  shift_result,
    output logic             shift_done
);

    typedef enum logic [2:0] {
        SHIFT_SLL = 3'b000, // Logical shift left
        SHIFT_SRL = 3'b001, // Logical shift right
        SHIFT_SRA = 3'b010  // Arithmetic shift right
    } shift_op_e;

    logic [VLEN-1:0] raw_result;

    // Number of elements based on SEW
    int num_elements;
    always_comb begin
        case (sew)
            2'b00: num_elements = VLEN/8;
            2'b01: num_elements = VLEN/16;
            2'b10: num_elements = VLEN/32;
            2'b11: num_elements = VLEN/64;
            default: num_elements = VLEN/32;
        endcase
    end

    // Main shift logic
    always_comb begin
        raw_result = '0;

        case (sew)
            2'b00: begin // 8-bit elements
                for (int i = 0; i < num_elements; i++) begin
                    logic [7:0] a, b, res;
                    a = dataA[i*8 +: 8]; // shift amount
                    b = dataB[i*8 +: 8]; // value

                    case (shift_op_e'(shift_op))
                        SHIFT_SLL: res = b << a;
                        SHIFT_SRL: res = b >> a;
                        SHIFT_SRA: res = $signed(b) >>> a;
                        default:   res = b;
                    endcase

                    raw_result[i*8 +: 8] = res;
                end
            end

            2'b01: begin // 16-bit elements
                for (int i = 0; i < num_elements; i++) begin
                    logic [15:0] a, b, res;
                    a = dataA[i*16 +: 16];
                    b = dataB[i*16 +: 16];

                    case (shift_op_e'(shift_op))
                        SHIFT_SLL: res = b << a;
                        SHIFT_SRL: res = b >> a;
                        SHIFT_SRA: res = $signed(b) >>> a;
                        default:   res = b;
                    endcase

                    raw_result[i*16 +: 16] = res;
                end
            end

            2'b10: begin // 32-bit elements
                for (int i = 0; i < num_elements; i++) begin
                    logic [31:0] a, b, res;
                    a = dataA[i*32 +: 32];
                    b = dataB[i*32 +: 32];

                    case (shift_op_e'(shift_op))
                        SHIFT_SLL: res = b << a;
                        SHIFT_SRL: res = b >> a;
                        SHIFT_SRA: res = $signed(b) >>> a;
                        default:   res = b;
                    endcase

                    raw_result[i*32 +: 32] = res;
                end
            end

            2'b11: begin // 64-bit elements
                for (int i = 0; i < num_elements; i++) begin
                    logic [63:0] a, b, res;
                    a = dataA[i*64 +: 64];
                    b = dataB[i*64 +: 64];

                    case (shift_op_e'(shift_op))
                        SHIFT_SLL: res = b << a;
                        SHIFT_SRL: res = b >> a;
                        SHIFT_SRA: res = $signed(b) >>> a;
                        default:   res = b;
                    endcase

                    raw_result[i*64 +: 64] = res;
                end
            end

            default: raw_result = '0;
        endcase
    end

    assign shift_result = raw_result;
    assign shift_done   = 1'b1; // combinational
endmodule