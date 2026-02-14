`include "vec_regfile_defs.svh"
`include "vector_processor_defs.svh"

module vector_bitwise_unit #(
    parameter VLEN = 4096,
    parameter ELEN = 32
)(
    // Prepared operands
    input  logic [VLEN-1:0] dataA,   // Operand A (vector)
    input  logic [VLEN-1:0] dataB,   // Operand B (vector)

    // Control
    input  logic [4:0]      bitwise_op, // ALU operation code
    input  logic [1:0]      sew,        // Standard Element Width

    // Output
    output logic [VLEN-1:0] alu_result,
    output logic            alu_done
);

    typedef enum logic [4:0] {
        ALU_AND  = 5'b00000,
        ALU_OR   = 5'b00001,
        ALU_XOR  = 5'b00010,
        ALU_NOT  = 5'b00011,  // Pseudo-op: ~B
        ALU_MINU = 5'b00100,
        ALU_MIN  = 5'b00101,
        ALU_MAXU = 5'b00110,
        ALU_MAX  = 5'b00111
    } alu_op_e;

    logic [VLEN-1:0] raw_result;

    // Calculate number of elements based on SEW
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

    always_comb begin
        raw_result = '0;

        case (sew)
            // 8-bit elements
            2'b00: begin
                for (int i = 0; i < num_elements; i++) begin
                    logic [7:0] a, b, res;
                    a = dataA[i*8 +: 8];
                    b = dataB[i*8 +: 8];

                    case (alu_op_e'(bitwise_op))
                        ALU_AND:  res = b & a;
                        ALU_OR:   res = b | a;
                        ALU_XOR:  res = b ^ a;
                        ALU_NOT:  res = ~b;

                        ALU_MINU: res = (b < a) ? b : a;
                        ALU_MIN:  res = ($signed(b) < $signed(a)) ? b : a;
                        ALU_MAXU: res = (b > a) ? b : a;
                        ALU_MAX:  res = ($signed(b) > $signed(a)) ? b : a;

                        default: res = b;
                    endcase

                    raw_result[i*8 +: 8] = res;
                end
            end

            // 16-bit elements
            2'b01: begin
                for (int i = 0; i < num_elements; i++) begin
                    logic [15:0] a, b, res;
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

                        default: res = b;
                    endcase

                    raw_result[i*16 +: 16] = res;
                end
            end

            // 32-bit elements
            2'b10: begin
                for (int i = 0; i < num_elements; i++) begin
                    logic [31:0] a, b, res;
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

                        default: res = b;
                    endcase

                    raw_result[i*32 +: 32] = res;
                end
            end

            // 64-bit elements
            2'b11: begin
                for (int i = 0; i < num_elements; i++) begin
                    logic [63:0] a, b, res;
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

                        default: res = b;
                    endcase

                    raw_result[i*64 +: 64] = res;
                end
            end

            default: raw_result = '0;
        endcase
    end

    assign alu_result = raw_result;
    assign alu_done   = 1'b1;  // combinational
endmodule