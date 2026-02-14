`include "vec_de_csr_defs.svh"
`include "vector_processor_defs.svh"
`include "vector_bitwise_unit.sv"
`include "vector_compare_unit.sv"
`include "vector_multiplier.sv"
`include "vector_shift_module.sv"
`include "vector_adder_subtractor_unit.sv"

module vector_execution_unit(
    input   logic                               clk,
    input   logic                               reset,

    input   logic [`MAX_VLEN-1:0]               data_1,
    input   logic [`MAX_VLEN-1:0]               data_2, 
    input   logic [`MAX_VLEN-1:0]               data_3,

    input   logic                               Ctrl,
    input   logic [6:0]                         sew_eew_mux_out,
    input   logic [2:0]                         execution_op,
    input   logic                               signed_mode, 
    input   logic                               mul_low,
    input   logic                               mul_high,
    input   logic                               reverse_sub_inst,
    input   logic [4:0]                         bitwise_op, 
    input   logic [2:0]                         cmp_op, 

    output  logic [`MAX_VLEN-1:0]               execution_result,
    output  logic [1:0]                         sew,
    output  logic                               count_0,
    output  logic                               sew_16_32,
    output  logic                               sew_32   
);
    
    // Internal signals
    logic                           add_en, shift_en, mult_en, logical_en, compare_en, bitwise_en, reverse_sub_en, move_en, 
                                    mult_add_en;
    logic                           sum_done, shift_done, mult_done, logical_done, compare_done, bitwise_done, mul_add_done;
    logic [`MAX_VLEN-1:0]           adder_data_1, adder_data_2;
    logic [`MAX_VLEN-1:0]           mult_data_1, mult_data_2;
    logic [`MAX_VLEN-1:0]           shift_data_1, shift_data_2 ;
    logic [`MAX_VLEN-1:0]           bitwise_data_1, bitwise_data_2;
    logic [`MAX_VLEN-1:0]           compare_data_1, compare_data_2 ;

    logic [`MAX_VLEN-1:0]           sum_result, compare_result, bitwise_result, shift_result, move_result, product_1, product_2, 
                                    sum_product_result; 
    logic [`MAX_VLEN*2-1:0]         product_result;

    // SEW decoding
    always_comb begin
        case (sew_eew_mux_out)
            7'b0001000: sew = 2'b00;  // 8-bit
            7'b0010000: sew = 2'b01;  // 16-bit
            7'b0100000: sew = 2'b10;  // 32-bit
            default:    sew = 2'b00;
        endcase
    end

    // Execution unit enable logic
    always_comb begin
        add_en = 1'b0;
        shift_en = 1'b0;
        mult_en  = 1'b0;
        bitwise_en = 1'b0;
        compare_en = 1'b0;
        move_en = 1'b0;
        mult_add_en = 1'b0;
        
        if (execution_op == 3'b000 ) begin
            if (!reverse_sub_inst) begin   
                add_en = 1'b1;
            end 
            else if (reverse_sub_inst) begin
                reverse_sub_en = 1'b1;
            end
            else begin
                add_en = 1'b0;
                reverse_sub_en = 1'b0;
            end
        end  
        else if (execution_op == 3'b001) begin
            shift_en = 1'b1;
        end
        else if (execution_op == 3'b011) begin 
            mult_en = 1'b1;
        end
        else if (execution_op == 3'b100) begin 
            bitwise_en = 1'b1;    
            end
        else if (execution_op == 3'b101) begin
            compare_en = 1'b1;
        end
        else if (execution_op == 3'b110 ) begin
            move_en = 1'b1;
        end
        else if (execution_op == 3'b111) begin
            mult_add_en = 1'b1;
        end
        else begin
            add_en = 1'b0;
            shift_en = 1'b0;
            mult_en  = 1'b0;
            bitwise_en = 1'b0;
            compare_en = 1'b0;
            move_en = 1'b0;
            mult_add_en = 1'b0;
        end
    end

    // SEW control signals
    always_comb begin 
        if (sew == 2'b01) begin
            sew_16_32 = 1'b1;
            sew_32    = 1'b0;
        end
        else if (sew == 2'b10) begin
            sew_16_32 = 1'b1;
            sew_32    = 1'b1;
        end
        else begin
            sew_16_32 = 1'b0;
            sew_32    = 1'b0;
        end
    end 

    assign adder_data_1         =   add_en          ? data_1 :
                                    reverse_sub_en  ? data_2 :
                                                                `MAX_VLEN'b0;
    assign adder_data_2         =   add_en          ? data_2 :
                                    reverse_sub_en  ? data_1 :
                                                                `MAX_VLEN'b0;
    assign  mult_data_1         = mult_en           ? data_1 :  `MAX_VLEN'b0;
    assign  mult_data_2         = mult_en           ? data_2 :  `MAX_VLEN'b0;
    assign  shift_data_1        = shift_en          ? data_1 :  `MAX_VLEN'b0;
    assign  shift_data_2        = shift_en          ? data_2 :  `MAX_VLEN'b0;
    assign  compare_data_1      = compare_en        ? data_1 :  `MAX_VLEN'b0;
    assign  compare_data_2      = compare_en        ? data_2 :  `MAX_VLEN'b0;
    assign  bitwise_data_1      = bitwise_en        ? data_1 :  `MAX_VLEN'b0;
    assign  bitwise_data_2      = bitwise_en        ? data_2 :  `MAX_VLEN'b0;
    assign  mult_add_data_1     = mult_add_en       ? data_1 :  `MAX_VLEN'b0;
    assign  mult_add_data_2     = mult_add_en       ? data_2 :  `MAX_VLEN'b0;
    assign  mult_add_data_3     = mult_add_en       ? data_3 :  `MAX_VLEN'b0;

    vector_adder_subtractor adder_inst (
        .A              (adder_data_1),
        .B              (adder_data_2),
        .Ctrl           (Ctrl),         
        .sew_16_32      (sew_16_32),     
        .sew_32         (sew_32),        
        .Sum            (sum_result),
        .sum_done       (sum_done)
    );

    vector_multiplier vect_mult(
        .clk            (clk),
        .reset          (reset),
        .data_in_A      (mult_data_1),
        .data_in_B      (mult_data_2),
        .sew            (sew),
        .signed_mode    (signed_mode),
        .count_0        (count_0),
        .mult_done      (mult_done),
        .product_1      (product_1),
        .product_2      (product_2),
        .product        (product_result)
    );  

    vector_compare_unit vect_comp (
        .data1          (compare_data_1),         
        .data2          (compare_data_2),               
        .cmp_op         (cmp_op),        
        .sew            (sew),         
        .compare_result (compare_result), 
        .compare_done   (compare_done)  
    );

    vector_bitwise_unit vect_bitwise (
        .data1          (bitwise_data_1),         
        .data2          (bitwise_data_2),              
        .bitwise_op     (alu_opcode),   
        .sew            (sew),          
        .alu_result     (bitwise_result),   
        .alu_done       (bitwise_done)       
    );

    vector_shift_unit vector_shift(
        .data1          (shift_data_1),         
        .data2          (shift_data_2),             
        .shift_op       (shift_op),      
        .sew            (sew),           
        .shift_result   (shift_result),  
        .shift_done     (shift_done)    
    );

    vector_multiply_add_unit mult_add(
        .clk                (clk),
        .reset              (reset),
        .data_A             (mult_add_data_1),    
        .data_B             (mult_add_data_2),      
        .data_C             (mult_add_data_3),      
        .accum_op           (accum_op),     
        .sew                (sew),         
        .signed_mode        (signed_mode), 
        .Ctrl               (Ctrl),
        .sew_16_32          (sew_16_32),
        .sew_32             (sew_32),
        .count_0            (count_0),
        .sum_product_result (sum_product_result),
        .product_sum_done   (product_sum_done)
);

    always_comb begin
        if (reset) begin
            execution_result = '0;
        end else begin
            if (add_en) begin
                execution_result = sum_result;
            end 
            else if (shift_en) begin
                execution_result = shift_result;
            end
            else if (compare_en) begin
                execution_result = compare_result;
            end
            else if (bitwise_en) begin
                execution_result = bitwise_result;
            end
            else if (move_en) begin
                execution_result = data_1;
            end
            else if (mult_en) begin
                case (sew)
                    2'b00: begin // 8-bit elements → 16-bit products
                        for (int i = 0; i < `MAX_VLEN/8; i++) begin
                            if (mul_high)
                                execution_result[i*8 +: 8] = product_result[i*16 + 8 +: 8]; // Upper 8 bits
                            else if (mul_low) 
                                execution_result[i*8 +: 8] = product_result[i*16 +: 8];     // Lower 8 bits
                            else 
                                execution_result = '0; 
                        end
                    end
                    2'b01: begin // 16-bit elements → 32-bit products
                        for (int i = 0; i < `MAX_VLEN/16; i++) begin
                            if (mul_high)
                                execution_result[i*16 +: 16] = product_result[i*32 + 16 +: 16]; // Upper 16 bits
                            else if (mul_low)
                                execution_result[i*16 +: 16] = product_result[i*32 +: 16];      // Lower 16 bits
                            else 
                                execution_result = '0; 
                        end
                    end
                    2'b10: begin // 32-bit elements → 64-bit products
                        for (int i = 0; i < `MAX_VLEN/32; i++) begin
                            if (mul_high)
                                execution_result[i*32 +: 32] = product_result[i*64 + 32 +: 32]; // Upper 32 bits
                            else if (mul_low)
                                execution_result[i*32 +: 32] = product_result[i*64 +: 32];      // Lower 32 bits
                            else 
                                execution_result = '0; 
                        end
                    end
                    default: begin
                        execution_result = '0;
                    end 
                endcase
            end
            else begin 
                execution_result = '0;
            end
        end
    end
 
endmodule
