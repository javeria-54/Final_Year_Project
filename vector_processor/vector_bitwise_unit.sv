// vec_alu_execution_unit.sv
`include "vec_regfile_defs.svh"
`include "vector_processor_defs.svh"

module vector_bitwise_unit #(
    parameter VLEN = 4096,
    parameter ELEN = 32
)(
    // Input operands (both 512-bit)
    input  logic [VLEN-1:0]         data1,         // vs1/scalar/imm (zero-extended to 512 bits)
    input  logic [VLEN-1:0]         data2,         // vs2_data (always 512 bits)
    
    // Control signals
    input  logic [1:0]              op_type,       // 00: vv, 01: vx, 10: vi, 11: reserved
    input  logic [4:0]              bitwise_op,    // ALU operation code
    input  logic [1:0]              sew,           // Standard Element Width
    
    // Output
    output logic [VLEN-1:0]         alu_result,    // Raw ALU result (before masking)
    output logic                    alu_done       // Completion signal
);

    // Instruction types
    typedef enum logic [1:0] {
        OP_VV = 2'b00,
        OP_VX = 2'b01,
        OP_VI = 2'b10,
        OP_RESERVED = 2'b11
    } op_type_e;

    // ALU operation encoding (only bitwise and min/max)
    typedef enum logic [4:0] {
        // Bitwise logical operations
        ALU_AND  = 5'b00000,
        ALU_OR   = 5'b00001,
        ALU_XOR  = 5'b00010,
        ALU_NOT  = 5'b00011,  // Pseudo-op: vxor.vi with imm=-1
        
        // Min/Max operations
        ALU_MINU = 5'b00100,  // Unsigned minimum
        ALU_MIN  = 5'b00101,  // Signed minimum
        ALU_MAXU = 5'b00110,  // Unsigned maximum
        ALU_MAX  = 5'b00111   // Signed maximum
    } alu_op_e;

    // Internal signals
    logic [VLEN-1:0] raw_result;
    
    // Calculate number of elements based on SEW
    int num_elements;
    always_comb begin
        case (sew)
            8:  num_elements = 64;
            16: num_elements = 32;
            32: num_elements = 16;
            64: num_elements = 8;
            default: num_elements = 16;
        endcase
    end

    // Main ALU logic
    always_comb begin
        raw_result = '0;
        
        case (sew)
            // 8-bit elements
            2'b00: begin
                // Extract immediate value
                logic [7:0] imm_val;
                if (op_type == OP_VI) begin
                    if (bitwise_op == ALU_NOT) begin
                        // vnot.v: immediate -1 = 0xFF
                        imm_val = 8'hFF;
                    end else begin
                        // Sign-extend 5-bit immediate to 8 bits
                        imm_val = {{3{data1[4]}}, data1[4:0]};
                    end
                end
                
                for (int i = 0; i < 64; i++) begin
                    if (i < num_elements) begin
                        logic [7:0] op1_elem, op2_elem, result_elem;
                        
                        // Get operands
                        op2_elem = data2[i*8 +: 8];
                        
                        case (op_type)
                            OP_VV: begin
                                // For vv: vs1 is in data1
                                op1_elem = data1[i*8 +: 8];
                            end
                            OP_VX: begin
                                // For vx: scalar is in data1[31:0], use lower 8 bits
                                op1_elem = data1[7:0];  // Same value for all elements
                            end
                            OP_VI: begin
                                // For vi: use sign-extended immediate
                                op1_elem = imm_val;  // Same value for all elements
                            end
                            default: op1_elem = 8'b0;
                        endcase
                        
                        // Perform ALU operation
                        case (alu_op_e'(bitwise_op))
                            // Bitwise logical operations
                            ALU_AND:  result_elem = op2_elem & op1_elem;
                            ALU_OR:   result_elem = op2_elem | op1_elem;
                            ALU_XOR:  result_elem = op2_elem ^ op1_elem;
                            ALU_NOT:  result_elem = ~op2_elem;  // vnot.v pseudo-instruction
                            
                            // Min/Max operations
                            ALU_MINU: begin  // Unsigned minimum
                                result_elem = (op2_elem < op1_elem) ? op2_elem : op1_elem;
                            end
                            ALU_MIN: begin   // Signed minimum
                                result_elem = ($signed(op2_elem) < $signed(op1_elem)) ? op2_elem : op1_elem;
                            end
                            ALU_MAXU: begin  // Unsigned maximum
                                result_elem = (op2_elem > op1_elem) ? op2_elem : op1_elem;
                            end
                            ALU_MAX: begin   // Signed maximum
                                result_elem = ($signed(op2_elem) > $signed(op1_elem)) ? op2_elem : op1_elem;
                            end
                            
                            // Default: pass through operand2
                            default: result_elem = op2_elem;
                        endcase
                        
                        raw_result[i*8 +: 8] = result_elem;
                    end
                end
            end
            
            // 16-bit elements
            2'b01: begin
                // Extract immediate value
                logic [15:0] imm_val;
                if (op_type == OP_VI) begin
                    if (bitwise_op == ALU_NOT) begin
                        // vnot.v: immediate -1 = 0xFFFF
                        imm_val = 16'hFFFF;
                    end else begin
                        // Sign-extend 5-bit immediate to 16 bits
                        imm_val = {{11{data1[4]}}, data1[4:0]};
                    end
                end
                
                for (int i = 0; i < 32; i++) begin
                    if (i < num_elements) begin
                        logic [15:0] op1_elem, op2_elem, result_elem;
                        
                        // Get operands
                        op2_elem = data2[i*16 +: 16];
                        
                        case (op_type)
                            OP_VV: op1_elem = data1[i*16 +: 16];
                            OP_VX: op1_elem = data1[15:0];  // Use lower 16 bits
                            OP_VI: op1_elem = imm_val;      // Use sign-extended immediate
                            default: op1_elem = 16'b0;
                        endcase
                        
                        // Perform ALU operation
                        case (alu_op_e'(bitwise_op))
                            ALU_AND:  result_elem = op2_elem & op1_elem;
                            ALU_OR:   result_elem = op2_elem | op1_elem;
                            ALU_XOR:  result_elem = op2_elem ^ op1_elem;
                            ALU_NOT:  result_elem = ~op2_elem;
                            
                            ALU_MINU: begin
                                result_elem = (op2_elem < op1_elem) ? op2_elem : op1_elem;
                            end
                            ALU_MIN: begin
                                result_elem = ($signed(op2_elem) < $signed(op1_elem)) ? op2_elem : op1_elem;
                            end
                            ALU_MAXU: begin
                                result_elem = (op2_elem > op1_elem) ? op2_elem : op1_elem;
                            end
                            ALU_MAX: begin
                                result_elem = ($signed(op2_elem) > $signed(op1_elem)) ? op2_elem : op1_elem;
                            end
                            
                            default: result_elem = op2_elem;
                        endcase
                        
                        raw_result[i*16 +: 16] = result_elem;
                    end
                end
            end
            
            // 32-bit elements
            2'b10: begin
                // Extract immediate value
                logic [31:0] imm_val;
                if (op_type == OP_VI) begin
                    if (bitwise_op == ALU_NOT) begin
                        // vnot.v: immediate -1 = 0xFFFFFFFF
                        imm_val = 32'hFFFFFFFF;
                    end else begin
                        // Sign-extend 5-bit immediate to 32 bits
                        imm_val = {{27{data1[4]}}, data1[4:0]};
                    end
                end
                
                for (int i = 0; i < 16; i++) begin
                    if (i < num_elements) begin
                        logic [31:0] op1_elem, op2_elem, result_elem;
                        
                        // Get operands
                        op2_elem = data2[i*32 +: 32];
                        
                        case (op_type)
                            OP_VV: op1_elem = data1[i*32 +: 32];
                            OP_VX: op1_elem = data1[31:0];  // Use lower 32 bits
                            OP_VI: op1_elem = imm_val;      // Use sign-extended immediate
                            default: op1_elem = 32'b0;
                        endcase
                        
                        // Perform ALU operation
                        case (alu_op_e'(bitwise_op))
                            ALU_AND:  result_elem = op2_elem & op1_elem;
                            ALU_OR:   result_elem = op2_elem | op1_elem;
                            ALU_XOR:  result_elem = op2_elem ^ op1_elem;
                            ALU_NOT:  result_elem = ~op2_elem;
                            
                            ALU_MINU: begin
                                result_elem = (op2_elem < op1_elem) ? op2_elem : op1_elem;
                            end
                            ALU_MIN: begin
                                result_elem = ($signed(op2_elem) < $signed(op1_elem)) ? op2_elem : op1_elem;
                            end
                            ALU_MAXU: begin
                                result_elem = (op2_elem > op1_elem) ? op2_elem : op1_elem;
                            end
                            ALU_MAX: begin
                                result_elem = ($signed(op2_elem) > $signed(op1_elem)) ? op2_elem : op1_elem;
                            end
                            
                            default: result_elem = op2_elem;
                        endcase
                        
                        raw_result[i*32 +: 32] = result_elem;
                    end
                end
            end
            
            default: begin
                raw_result = '0;
            end
        endcase
    end

    assign alu_result = raw_result;
    assign alu_done = 1'b1;  // Combinational operation

endmodule