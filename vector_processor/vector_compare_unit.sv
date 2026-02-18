// vec_compare_execution_unit.sv
`include "vec_regfile_defs.svh"
`include "vector_processor_defs.svh"

module vector_compare_unit #(
    parameter VLEN = 4096,
    parameter ELEN = 32
)(
    // Input operands (both 512-bit)
    input  logic [VLEN-1:0]         data1,         // vs1/scalar/imm (zero-extended to 512 bits)
    input  logic [VLEN-1:0]         data2,         // vs2_data (always 512 bits)
    
    // Control signals
    input  logic [1:0]              op_type,       // 00: vv, 01: vx, 10: vi, 11: reserved
    input  logic [2:0]              cmp_op,        // Comparison operation
    input  logic [1:0]              sew,           // Standard Element Width
    
    // Output
    output logic [VLEN-1:0]         compare_result, // Raw compare result (before masking)
    output logic                    compare_done    // Completion signal
);

    // Instruction types
    typedef enum logic [1:0] {
        OP_VV = 2'b00,
        OP_VX = 2'b01,
        OP_VI = 2'b10,
        OP_RESERVED = 2'b11
    } op_type_e;

    // Comparison operations encoding
    typedef enum logic [2:0] {
        CMP_EQ  = 3'b000,   //vmseq
        CMP_NE  = 3'b001,   //nmsne
        CMP_LTU = 3'b010,  // unsigned vmsltu
        CMP_LEU = 3'b011,   // unsigned vmsleu
        CMP_LT  = 3'b100,  // signed vmslt
        CMP_LE  = 3'b101,  // signed vmsle
        CMP_GT  = 3'b110,  // signed (pseudo-op) vmsgt
        CMP_GTU  = 3'b111  // signed (pseudo-op) vmsgtu   
    } cmp_op_e;

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

    // Main comparison logic (no masking)
    always_comb begin
        raw_result = '0;
        
        case (sew)
            // 8-bit elements
            2'b00: begin
                // Declare all variables at the beginning
                logic [7:0] imm_val;
                logic [7:0] vs2_elem;
                logic [7:0] vs1_elem;
                logic comparison_bit;
                logic [7:0] actual_vs2, actual_vs1;
                logic use_swapped;
                
                // Extract and sign-extend immediate value to 8 bits
                if (op_type == OP_VI) begin
                    // data1[4:0] contains 5-bit immediate, sign-extend to 8 bits
                    imm_val = {{3{data1[4]}}, data1[4:0]};
                end
                
                for (int i = 0; i < 64; i++) begin
                    if (i < num_elements) begin
                        vs2_elem = data2[i*8 +: 8];
                        
                        // Get operand1 based on instruction type
                        case (op_type)
                            OP_VV: begin
                                // For vv: vs1 is in data1
                                vs1_elem = data1[i*8 +: 8];
                            end
                            OP_VX: begin
                                // For vx: scalar is in data1[31:0], use lower 8 bits
                                vs1_elem = data1[7:0];  // Same value for all elements
                            end
                            OP_VI: begin
                                // For vi: use sign-extended immediate
                                vs1_elem = imm_val;  // Same value for all elements
                            end
                            default: vs1_elem = 8'b0;
                        endcase
                        
                        // Handle pseudo-ops: vmsgtu/vmsgt/vmsgeu/vmsge
                        // These are implemented as vmsltu/vmslt with swapped operands
                        // vmsgtu.vi, vmsgt.vi, vmsgtu.vx, vmsgt.vx use swapped operands
                        // vmsgeu.vx, vmsge.vx also use swapped operands (but not provided directly)
                        use_swapped = (cmp_op == CMP_GT || cmp_op == CMP_GTU);
                        
                        if (use_swapped) begin
                            actual_vs2 = vs1_elem;
                            actual_vs1 = vs2_elem;
                        end else begin
                            actual_vs2 = vs2_elem;
                            actual_vs1 = vs1_elem;
                        end
                        
                        // Perform comparison
                        case (cmp_op_e'(cmp_op))
                            CMP_EQ:  comparison_bit = (vs2_elem == vs1_elem);
                            CMP_NE:  comparison_bit = (vs2_elem != vs1_elem);
                            CMP_LT:  comparison_bit = ($signed(actual_vs2) < $signed(actual_vs1));
                            CMP_LE:  comparison_bit = ($signed(actual_vs2) <= $signed(actual_vs1));
                            CMP_GT:  comparison_bit = ($signed(actual_vs2) > $signed(actual_vs1));  // Swapped LT
                            CMP_GTU: comparison_bit = ((actual_vs2) > (actual_vs1)); // Swapped LE
                            CMP_LTU: comparison_bit = (actual_vs2 < actual_vs1);
                            CMP_LEU: comparison_bit = (actual_vs2 <= actual_vs1);
                            default: comparison_bit = 1'b0;
                        endcase
                        
                        // Store result in LSB, zero other bits (as per RISC-V spec)
                        raw_result[i*8 +: 8] = {7'b0, comparison_bit};
                    end
                end
            end
            
            // 16-bit elements
            2'b01: begin
                // Declare all variables at the beginning
                logic [15:0] imm_val;
                logic [15:0] vs2_elem;
                logic [15:0] vs1_elem;
                logic comparison_bit;
                logic [15:0] actual_vs2, actual_vs1;
                logic use_swapped;
                
                // Extract and sign-extend immediate value to 16 bits
                if (op_type == OP_VI) begin
                    // data1[4:0] contains 5-bit immediate, sign-extend to 16 bits
                    imm_val = {{11{data1[4]}}, data1[4:0]};
                end
                
                for (int i = 0; i < 32; i++) begin
                    if (i < num_elements) begin
                        vs2_elem = data2[i*16 +: 16];
                        
                        // Get operand1 based on instruction type
                        case (op_type)
                            OP_VV: vs1_elem = data1[i*16 +: 16];
                            OP_VX: vs1_elem = data1[15:0];  // Use lower 16 bits
                            OP_VI: vs1_elem = imm_val;      // Use sign-extended immediate
                            default: vs1_elem = 16'b0;
                        endcase
                        
                        // Handle pseudo-ops
                        use_swapped = (cmp_op == CMP_GT || cmp_op == CMP_GTU);
                        
                        if (use_swapped) begin
                            actual_vs2 = vs1_elem;
                            actual_vs1 = vs2_elem;
                        end else begin
                            actual_vs2 = vs2_elem;
                            actual_vs1 = vs1_elem;
                        end
                        
                        case (cmp_op_e'(cmp_op))
                            CMP_EQ:  comparison_bit = (vs2_elem == vs1_elem);
                            CMP_NE:  comparison_bit = (vs2_elem != vs1_elem);
                            CMP_LT:  comparison_bit = ($signed(actual_vs2) < $signed(actual_vs1));
                            CMP_LE:  comparison_bit = ($signed(actual_vs2) <= $signed(actual_vs1));
                            CMP_GT:  comparison_bit = ($signed(actual_vs2) > $signed(actual_vs1));  // Swapped LT
                            CMP_GTU: comparison_bit = ((actual_vs2) > (actual_vs1)); // Swapped LE
                            CMP_LTU: comparison_bit = (actual_vs2 < actual_vs1);
                            CMP_LEU: comparison_bit = (actual_vs2 <= actual_vs1);
                            default: comparison_bit = 1'b0;
                        endcase
                        
                        raw_result[i*16 +: 16] = {15'b0, comparison_bit};
                    end
                end
            end
            
            // 32-bit elements
            2'b10: begin
                // Declare all variables at the beginning
                logic [31:0] imm_val;
                logic [31:0] vs2_elem;
                logic [31:0] vs1_elem;
                logic comparison_bit;
                logic [31:0] actual_vs2, actual_vs1;
                logic use_swapped;
                
                // Extract and sign-extend immediate value to 32 bits
                if (op_type == OP_VI) begin
                    // data1[4:0] contains 5-bit immediate, sign-extend to 32 bits
                    imm_val = {{27{data1[4]}}, data1[4:0]};
                end
                
                for (int i = 0; i < 16; i++) begin
                    if (i < num_elements) begin
                        vs2_elem = data2[i*32 +: 32];
                        
                        // Get operand1 based on instruction type
                        case (op_type)
                            OP_VV: vs1_elem = data1[i*32 +: 32];
                            OP_VX: vs1_elem = data1[31:0];  // Use lower 32 bits
                            OP_VI: vs1_elem = imm_val;      // Use sign-extended immediate
                            default: vs1_elem = 32'b0;
                        endcase
                        
                        // Handle pseudo-ops
                        use_swapped = (cmp_op == CMP_GT || cmp_op == CMP_GTU);
                        
                        if (use_swapped) begin
                            actual_vs2 = vs1_elem;
                            actual_vs1 = vs2_elem;
                        end else begin
                            actual_vs2 = vs2_elem;
                            actual_vs1 = vs1_elem;
                        end
                        
                        case (cmp_op_e'(cmp_op))
                            CMP_EQ:  comparison_bit = (vs2_elem == vs1_elem);
                            CMP_NE:  comparison_bit = (vs2_elem != vs1_elem);
                            CMP_LT:  comparison_bit = ($signed(actual_vs2) < $signed(actual_vs1));
                            CMP_LE:  comparison_bit = ($signed(actual_vs2) <= $signed(actual_vs1));
                            CMP_GT:  comparison_bit = ($signed(actual_vs2) > $signed(actual_vs1));  // Swapped LT
                            CMP_GTU: comparison_bit = ((actual_vs2) > (actual_vs1)); // Swapped LE
                            CMP_LTU: comparison_bit = (actual_vs2 < actual_vs1);
                            CMP_LEU: comparison_bit = (actual_vs2 <= actual_vs1);
                            default: comparison_bit = 1'b0;
                        endcase
                        
                        raw_result[i*32 +: 32] = {31'b0, comparison_bit};
                    end
                end
            end
            
            default: begin
                raw_result = '0;
            end
        endcase
    end

    assign compare_result = raw_result;
    assign compare_done = 1'b1;  // Combinational operation

endmodule