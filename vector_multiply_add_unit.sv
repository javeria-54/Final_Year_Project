`include "vector_adder_subtractor_unit.sv"
`include "vector_multiplier.sv"
`include "vec_regfile_defs.svh"

module vector_multiply_add_unit (
    input  logic                 clk,
    input  logic                 reset,
    
    input  logic [`MAX_VLEN-1:0] data_A,    
    input  logic [`MAX_VLEN-1:0] data_B,      
    input  logic [`MAX_VLEN-1:0] data_C,      
    
    input  logic [2:0]           accum_op,     
    input  logic [1:0]           sew,         
    input  logic                 signed_mode, 
    input  logic                 Ctrl,
    input  logic                 sew_16_32,
    input  logic                 sew_32,
    input  logic                 count_0,

    output logic [`MAX_VLEN-1:0] sum_product_result,
    output logic                 product_sum_done
);

    logic [`MAX_VLEN-1:0] mult_operand_1;
    logic [`MAX_VLEN-1:0] mult_operand_2;
    logic [`MAX_VLEN-1:0] add_operand_1,add_operand_2,add_operand;
    logic [`MAX_VLEN*2+1:0] product_result;
    logic [`MAX_VLEN-1:0] product_selected;
    logic                 mult_done;
    logic [`MAX_VLEN-1:0] product_1,product_2;

    typedef enum logic [2:0] {
        VMACC_VV   = 3'b000,  // vd = +(vs1 * vs2) + vd
        VMACC_VX   = 3'b001,  // vd = +(rs1 * vs2) + vd
        VNMSAC_VV  = 3'b010,  // vd = -(vs1 * vs2) + vd
        VNMSAC_VX  = 3'b011,  // vd = -(rs1 * vs2) + vd
        VMADD_VV   = 3'b100,  // vd = (vs1 * vd) + vs2
        VMADD_VX   = 3'b101,  // vd = (rs1 * vd) + vs2
        VNMSUB_VV  = 3'b110,  // vd = -(vs1 * vd) + vs2
        VNMSUB_VX  = 3'b111   // vd = -(rs1 * vd) + vs2
    } accum_op_e;

    always_comb begin
        case (accum_op_e'(accum_op))
            VMACC_VV, VMACC_VX, VNMSAC_VV, VNMSAC_VX: begin
                // Multiply A * B, then add C
                mult_operand_1 = data_A;
                mult_operand_2 = data_B;
                if (mult_done) begin
                    add_operand    = data_C;
                end
                else begin 
                    add_operand = '0;
                end
            end
            
            VMADD_VV, VMADD_VX, VNMSUB_VV, VNMSUB_VX: begin
                // Multiply A * C, then add B
                mult_operand_1 = data_A;
                mult_operand_2 = data_C;
                if (mult_done) begin
                    add_operand    = data_B;
                end
                else begin
                    add_operand = '0;
                end
            end
            
            default: begin
                mult_operand_1 = '0;
                mult_operand_2 = '0;
                add_operand    = '0;
            end
        endcase
    end

    vector_multiplier vect_mult (
        .clk            (clk),
        .reset          (reset),
        .data_in_A      (mult_operand_1),
        .data_in_B      (mult_operand_2),
        .sew            (sew),
        .signed_mode    (signed_mode),
        .count_0        (count_0),
        .mult_done      (mult_done),
        .product_1      (product_1),
        .product_2      (product_2),
        .product        (product_result)
    );

        always_comb begin
        product_selected = '0;
        
        case (sew)
            2'b00: begin // 8-bit elements → 16-bit products
                for (int i = 0; i < `MAX_VLEN/8; i++) begin
                    if (mult_done) 
                        product_selected[i*8 +: 8] = product_result[i*16 +: 8];     // Lower 8 bits
                    else 
                        product_selected = '0; 
                end
            end
            
            2'b01: begin // 16-bit elements → 32-bit products
                for (int i = 0; i < `MAX_VLEN/16; i++) begin
                    if (mult_done)
                        product_selected[i*16 +: 16] = product_result[i*32 +: 16];      // Lower 16 bits
                    else 
                        product_selected = '0; 
                end
            end
            
            2'b10: begin // 32-bit elements → 64-bit products
                for (int i = 0; i < `MAX_VLEN/32; i++) begin
                    if (mult_done)
                        product_selected[i*32 +: 32] = product_result[i*64 +: 32];      // Lower 32 bits
                    else 
                        product_selected = '0; 
                end
            end
            
            default: begin
                product_selected = '0;
            end 
        endcase
    end

    always_comb begin
        add_operand_1 = '0;
        add_operand_2 = '0;
        if (Ctrl) begin
            add_operand_1 = add_operand;
            add_operand_2 = product_selected;
        end
        else begin
            add_operand_1 = product_selected;
            add_operand_2 = add_operand;
        end
    end

    vector_adder_subtractor adder_inst (
        .A              (add_operand_1),
        .B              (add_operand_2),
        .Ctrl           (Ctrl),
        .sew_16_32      (sew_16_32),
        .sew_32         (sew_32),
        .Sum            (sum_product_result),
        .sum_done        (product_sum_done)
    );

endmodule


   
    


