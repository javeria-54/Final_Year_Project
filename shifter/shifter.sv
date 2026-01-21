module vector_shift_unit #(
    parameter VLEN = 512,
    parameter ELEN = 32
)(
    // Input operands (both 512-bit)
    input  logic [VLEN-1:0]         data1,         // vs1/scalar/imm (shift amount)
    input  logic [VLEN-1:0]         data2,         // vs2_data (value to shift)
    
    // Control signals
    input  logic [1:0]              op_type,       // 00: vv, 01: vx, 10: vi, 11: reserved
    input  logic [2:0]              shift_op,      // Shift operation
    input  logic [6:0]              sew,           // Standard Element Width
    
    // Output
    output logic [VLEN-1:0]         shift_result,  // Shift result
    output logic                    shift_done     // Completion signal
);

    // Instruction types
    typedef enum logic [1:0] {
        OP_VV = 2'b00,
        OP_VX = 2'b01,
        OP_VI = 2'b10,
        OP_RESERVED = 2'b11
    } op_type_e;

    // Shift operations encoding
    typedef enum logic [2:0] {
        SHIFT_SLL  = 3'b000,  // Logical shift left
        SHIFT_SRL  = 3'b001,  // Logical shift right
        SHIFT_SRA  = 3'b010   // Arithmetic shift right
    } shift_op_e;

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

    // Main shift logic
    always_comb begin
        raw_result = '0;
        
        case (sew)
            // 8-bit elements
            8: begin
                // Declare all variables at the beginning
                logic [7:0] vs2_elem;
                logic [7:0] vs1_elem;
                logic [4:0] shift_amount;  // 5 bits for 8-bit shifts (max 31)
                logic [7:0] shifted_result;
                
                for (int i = 0; i < 64; i++) begin
                    if (i < num_elements) begin
                        vs2_elem = data2[i*8 +: 8];
                        
                        // Get shift amount based on instruction type
                        case (op_type)
                            OP_VV: begin
                                // For vv: shift amount from vs1
                                vs1_elem = data1[i*8 +: 8];
                                shift_amount = vs1_elem[4:0];  // Use lower 5 bits
                            end
                            OP_VX: begin
                                // For vx: scalar shift amount
                                vs1_elem = data1[7:0];
                                shift_amount = vs1_elem[4:0];  // Use lower 5 bits
                            end
                            OP_VI: begin
                                // For vi: immediate shift amount (5-bit unsigned)
                                shift_amount = data1[4:0];
                            end
                            default: shift_amount = 5'b0;
                        endcase
                        
                        // Perform shift operation
                        case (shift_op_e'(shift_op))
                            SHIFT_SLL: begin
                                // Logical shift left
                                shifted_result = vs2_elem << shift_amount;
                            end
                            SHIFT_SRL: begin
                                // Logical shift right
                                shifted_result = vs2_elem >> shift_amount;
                            end
                            SHIFT_SRA: begin
                                // Arithmetic shift right (sign-extended)
                                shifted_result = $signed(vs2_elem) >>> shift_amount;
                            end
                            default: shifted_result = 8'b0;
                        endcase
                        
                        raw_result[i*8 +: 8] = shifted_result;
                    end
                end
            end
            
            // 16-bit elements
            16: begin
                // Declare all variables at the beginning
                logic [15:0] vs2_elem;
                logic [15:0] vs1_elem;
                logic [4:0] shift_amount;  // 5 bits for 16-bit shifts (max 31)
                logic [15:0] shifted_result;
                
                for (int i = 0; i < 32; i++) begin
                    if (i < num_elements) begin
                        vs2_elem = data2[i*16 +: 16];
                        
                        // Get shift amount based on instruction type
                        case (op_type)
                            OP_VV: begin
                                vs1_elem = data1[i*16 +: 16];
                                shift_amount = vs1_elem[4:0];  // Use lower 5 bits
                            end
                            OP_VX: begin
                                vs1_elem = data1[15:0];
                                shift_amount = vs1_elem[4:0];  // Use lower 5 bits
                            end
                            OP_VI: begin
                                shift_amount = data1[4:0];
                            end
                            default: shift_amount = 5'b0;
                        endcase
                        
                        // Perform shift operation
                        case (shift_op_e'(shift_op))
                            SHIFT_SLL: begin
                                // Logical shift left
                                shifted_result = vs2_elem << shift_amount;
                            end
                            SHIFT_SRL: begin
                                // Logical shift right
                                shifted_result = vs2_elem >> shift_amount;
                            end
                            SHIFT_SRA: begin
                                // Arithmetic shift right (sign-extended)
                                shifted_result = $signed(vs2_elem) >>> shift_amount;
                            end
                            default: shifted_result = 16'b0;
                        endcase
                        
                        raw_result[i*16 +: 16] = shifted_result;
                    end
                end
            end
            
            // 32-bit elements
            32: begin
                // Declare all variables at the beginning
                logic [31:0] vs2_elem;
                logic [31:0] vs1_elem;
                logic [4:0] shift_amount;  // 5 bits for 32-bit shifts (max 31)
                logic [31:0] shifted_result;
                
                for (int i = 0; i < 16; i++) begin
                    if (i < num_elements) begin
                        vs2_elem = data2[i*32 +: 32];
                        
                        // Get shift amount based on instruction type
                        case (op_type)
                            OP_VV: begin
                                vs1_elem = data1[i*32 +: 32];
                                shift_amount = vs1_elem[4:0];  // Use lower 5 bits
                            end
                            OP_VX: begin
                                vs1_elem = data1[31:0];
                                shift_amount = vs1_elem[4:0];  // Use lower 5 bits
                            end
                            OP_VI: begin
                                shift_amount = data1[4:0];
                            end
                            default: shift_amount = 5'b0;
                        endcase
                        
                        // Perform shift operation
                        case (shift_op_e'(shift_op))
                            SHIFT_SLL: begin
                                // Logical shift left
                                shifted_result = vs2_elem << shift_amount;
                            end
                            SHIFT_SRL: begin
                                // Logical shift right
                                shifted_result = vs2_elem >> shift_amount;
                            end
                            SHIFT_SRA: begin
                                // Arithmetic shift right (sign-extended)
                                shifted_result = $signed(vs2_elem) >>> shift_amount;
                            end
                            default: shifted_result = 32'b0;
                        endcase
                        
                        raw_result[i*32 +: 32] = shifted_result;
                    end
                end
            end
            
            default: begin
                raw_result = '0;
            end
        endcase
    end

    assign shift_result = raw_result;
    assign shift_done = 1'b1;  // Combinational operation

endmodule