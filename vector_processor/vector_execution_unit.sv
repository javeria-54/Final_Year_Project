`include "vector_de_csr_defs.svh"
`include "vector_processor_defs.svh"
`include "vector_bitwise_unit.sv"
`include "vector_compare_unit.sv"
`include "vector_multiplier.sv"
`include "vector_shift_module.sv"
`include "vector_adder_subtractor_unit.sv"
`include "vector_execution_unit.svh"

module vector_execution_unit(
    input   logic                               clk,
    input   logic                               reset,

    input   logic [`MAX_VLEN-1:0]               data_1,
    input   logic [`MAX_VLEN-1:0]               data_2, 
    input   logic [`MAX_VLEN-1:0]               data_3,

    input  logic [`Tag_Width-1:0]        seq_num,
    output logic [`Tag_Width-1:0] seq_num_exe,
    input logic execution_inst,

    input   logic                               Ctrl,start,
    input   logic [6:0]                         sew_eew_mux_out,
    input   logic [2:0]                         execution_op,
    input   logic                               signed_mode, 
    input   logic                               mul_low,
    input   logic                               mul_high,
    input   logic                               reverse_sub_inst,add_inst,sub_inst,
    input   logic [4:0]                         bitwise_op, 
    input   logic [2:0]                         cmp_op,accum_op,shift_op, 
    input   logic [`VLEN-1:0] mask_reg_updated,
    output logic [`MAX_VLEN-1:0]               execution_result,

    output  logic [(`VLEN/8)-1:0] carry_out_mask,
    output logic mult_done,
    output  logic [`MAX_VLEN-1:0] execution_result_reg,
    output  logic                               execution_done,
    output  logic [(`VLEN/8)-1:0]                        carry_out,
    output  logic [1:0]                         sew
     
);

logic [`Tag_Width-1:0] seq_num_held;

// Holding register - captures seq_num_i when enable is high
always_ff @(posedge clk ) begin
    if (!reset)
        seq_num_held <= 'b0;
    else if (execution_inst )       
        seq_num_held <= seq_num;
end

always_comb begin
    if (!reset)
        seq_num_exe = 'b0;
    else if (execution_done)        
        seq_num_exe = seq_num_held;
end
    
    // Internal signals
    logic                               count_0;
    logic                               sew_16_32;
    logic                               sew_32;
    logic                               add_en, shift_en, mult_en, compare_en, bitwise_en, reverse_sub_en, move_en, mask_add_en,
                                        mult_add_en;
    logic                               sum_done, shift_done,  compare_done, bitwise_done, product_sum_done, move_done, sum_mask_done;
    logic                               sum_done_internal, shift_done_internal, mult_done_internal, compare_done_internal, sum_mask_done_internal,
                                        bitwise_done_internal, product_sum_done_internal;
    logic [`VLEN-1:0]                   adder_data_1, adder_data_2;
    logic [`VLEN-1:0]                   mult_data_1, mult_data_2, mult_data_1_latch, mult_data_2_latch;
    logic [`VLEN-1:0]                   shift_data_1, shift_data_2 ;
    logic [`VLEN-1:0]                   bitwise_data_1, bitwise_data_2;
    logic [`VLEN-1:0]                   compare_data_1, compare_data_2 ;
    logic [`VLEN-1:0]                   mult_add_data_2, mult_add_data_1, mult_add_data_3 ;
    logic [`VLEN-1:0]                   mult_sum_data_2_latch, mult_sum_data_1_latch, mult_sum_data_3_latch ;
    logic [`VLEN-1:0]                   mask_add_data_1, mask_add_data_2 ;
    logic [`VLEN-1:0]                   move_data_1;

    logic [`VLEN-1:0]                   sum_result, compare_result, bitwise_result, shift_result, move_result, sum_mask_result,
                                        sum_product_result; 
                                         
    logic [`VLEN*2-1:0]                 product_result;

    logic count_0_mult_add;
    
    // SEW decoding
    always_comb begin
        case (sew_eew_mux_out)
            7'b0001000: sew = 2'b00;  // 8-bit
            7'b0010000: sew = 2'b01;  // 16-bit
            7'b0100000: sew = 2'b10;  // 32-bit
            default:    sew = 2'b00;
        endcase
    end

    always_comb begin
        // Default sab zero
        add_en         = 1'b0;
        shift_en       = 1'b0;
        mult_en        = 1'b0;
        bitwise_en     = 1'b0;
        compare_en     = 1'b0;
        move_en        = 1'b0;
        mult_add_en    = 1'b0;
        reverse_sub_en = 1'b0;
        mask_add_en    = 1'b0;

        if (reset) begin
            case (execution_op)
                3'b000  : begin
                    if      (add_inst | sub_inst)  add_en         = 1'b1;
                    else if (reverse_sub_inst)     reverse_sub_en = 1'b1;
                end
                3'b001  :   shift_en    = 1'b1;
                3'b010  :   mask_add_en = 1'b1;
                3'b011  :   mult_en     = 1'b1;
                3'b100  :   bitwise_en  = 1'b1;
                3'b101  :   compare_en  = 1'b1;
                3'b110  :   move_en     = 1'b1;
                3'b111  :   mult_add_en = 1'b1;
                default : begin  
                    add_en         = 1'b0;
                    shift_en       = 1'b0;
                    mult_en        = 1'b0;
                    bitwise_en     = 1'b0;
                    compare_en     = 1'b0;
                    move_en        = 1'b0;
                    mult_add_en    = 1'b0;
                    reverse_sub_en = 1'b0;
                    mask_add_en    = 1'b0; // sab already zero hain
                end
            endcase
        end
    end

    logic [`VLEN-1:0] mult_sum_data_1_reg, mult_sum_data_2_reg, mult_sum_data_3_reg;
    logic mult_sum_active, mul_sum_low_reg, mul_sum_high_reg, signed_sum_mode_reg;
    logic [1:0] sew_latch;
    logic Ctrl_latch;
    logic [2:0] accum_op_latch, accum_op_mul;

    always_ff @(posedge clk) begin
        if (!reset) begin
            mult_sum_data_1_reg <= '0;
            mult_sum_data_2_reg <= '0;
            mult_sum_data_3_reg <= '0;
            mult_sum_active     <= 1'b0;
            mul_sum_low_reg     <= 1'b0;
            mul_sum_high_reg    <= 1'b0;
            sew_latch           <= 2'b0;
            Ctrl_latch          <= 1'b0;
            signed_sum_mode_reg <= 1'b0;
            accum_op_latch <= 3'b0;
        end else if (mult_add_en && !mult_sum_active) begin
                mult_sum_data_1_reg <= data_1[`VLEN-1:0];
                mult_sum_data_2_reg <= data_2[`VLEN-1:0];
                mult_sum_data_3_reg <= data_3[`VLEN-1:0];
                mult_sum_active     <= 1'b1;
                mul_sum_low_reg     <= mul_low;
                mul_sum_high_reg    <= mul_high;
                sew_latch           <= sew;
                Ctrl_latch          <= Ctrl;
                signed_sum_mode_reg <= signed_mode;
                accum_op_latch <= accum_op;
        end else if (mult_done_internal) begin
                mult_sum_data_1_reg <= '0;
                mult_sum_data_2_reg <= '0;
                mult_sum_data_3_reg <= '0;
                mult_sum_active     <= 1'b0; 
                mul_sum_low_reg     <= 1'b0;
                mul_sum_high_reg    <= 1'b0;
                sew_latch           <= sew;
                Ctrl_latch          <= Ctrl;
                signed_sum_mode_reg <= 1'b0;
                accum_op_latch <= 3'b0;
        end
    end

    logic [1:0] sew_sum_mul;
    assign mult_sum_data_1_latch = (mult_sum_active ) ? mult_sum_data_1_reg : '0;
    assign mult_sum_data_2_latch = (mult_sum_active ) ? mult_sum_data_2_reg : '0;
    assign mult_sum_data_3_latch = (mult_sum_active ) ? mult_sum_data_3_reg : '0;
    assign signed_mult_sum = (signed_mode) ? 1'b1 : signed_sum_mode_reg;
    assign sew_sum_mul = (mult_sum_active) ? sew_latch : sew;
    assign accum_op_mul = (mult_sum_active) ? accum_op_latch : accum_op;

    logic [`VLEN-1:0] mult_data_1_reg, mult_data_2_reg;
    logic mult_active,  mul_low_reg, mul_high_reg, signed_mode_reg;

    always_ff @(posedge clk) begin
        if (!reset) begin
            mult_data_1_reg <= '0;
            mult_data_2_reg <= '0;
            mult_active     <= 1'b0;
            mul_low_reg     <= 1'b0;
            mul_high_reg    <= 1'b0;
            signed_mode_reg <= 1'b0;
        end else if (mult_en && !mult_active) begin
                mult_data_1_reg <= data_1[`VLEN-1:0];
                mult_data_2_reg <= data_2[`VLEN-1:0];
                mult_active     <= 1'b1;
                mul_low_reg     <= mul_low;
                mul_high_reg    <= mul_high;
                signed_mode_reg <= signed_mode;
        end else if (mult_done_internal) begin
                mult_data_1_reg <= '0;
                mult_data_2_reg <= '0;
                mult_active     <= 1'b0; 
                mul_low_reg     <= 1'b0;
                mul_high_reg    <= 1'b0;
                signed_mode_reg <= 1'b0;
        end
    end

    assign mult_data_1_latch = (mult_active ) ? mult_data_1_reg : '0;
    assign mult_data_2_latch = (mult_active ) ? mult_data_2_reg : '0;
    assign signed_mult = (signed_mode) ? 1'b1 : signed_mode_reg; 

    assign adder_data_1         =   reverse_sub_en  ? data_1[`VLEN-1:0] :
                                    add_en          ? data_2[`VLEN-1:0] :
                                                      `VLEN'b0;
    assign adder_data_2         =   reverse_sub_en  ? data_2[`VLEN-1:0] :
                                    add_en          ? data_1[`VLEN-1:0] :
                                                      `VLEN'b0;
    assign  mult_data_1         = mult_en           ? data_1[`VLEN-1:0] :  mult_data_1_latch;
    assign  mult_data_2         = mult_en           ? data_2[`VLEN-1:0] :  mult_data_2_latch;
    assign  shift_data_1        = shift_en          ? data_1[`VLEN-1:0] :  `VLEN'b0;
    assign  shift_data_2        = shift_en          ? data_2[`VLEN-1:0] :  `VLEN'b0;
    assign  compare_data_1      = compare_en        ? data_1[`VLEN-1:0] :  `VLEN'b0;
    assign  compare_data_2      = compare_en        ? data_2[`VLEN-1:0] :  `VLEN'b0;
    assign  bitwise_data_1      = bitwise_en        ? data_1[`VLEN-1:0] :  `VLEN'b0;
    assign  bitwise_data_2      = bitwise_en        ? data_2[`VLEN-1:0] :  `VLEN'b0;
    assign  mult_add_data_1     = mult_add_en       ? data_1[`VLEN-1:0] :  mult_sum_data_1_latch;
    assign  mult_add_data_2     = mult_add_en       ? data_2[`VLEN-1:0] :  mult_sum_data_2_latch;
    assign  mult_add_data_3     = mult_add_en       ? data_3[`VLEN-1:0] :  mult_sum_data_3_latch;
    assign  move_data_1         = move_en           ? data_1[`VLEN-1:0] :  `VLEN'b0;
    assign  mask_add_data_1     = mask_add_en       ? data_1[`VLEN-1:0] :  `VLEN'b0;
    assign  mask_add_data_2     = mask_add_en       ? data_2[`VLEN-1:0] :  `VLEN'b0;

    always_comb begin
        sum_done = 1'b0;
        shift_done = 1'b0;
        mult_done = 1'b0;
        compare_done = 1'b0;
        bitwise_done = 1'b0;
        move_done = 1'b0;
        product_sum_done = 1'b0;
        sew_16_32 = 1'b0;
        sew_32 = 1'b0;
        sum_mask_done = 1'b0;
            if (reset) begin  
                sew_16_32 = 1'b0;
                sew_32 = 1'b0;  
                if (add_en | reverse_sub_en) begin
                    if (sew == 2'b00) begin
                        sew_16_32 = 1'b0;
                        sew_32    = 1'b0;
                    end
                    else if (sew == 2'b01) begin
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
                    execution_result = sum_result;
                    sum_done = sum_done_internal;
                    shift_done = 1'b0;
                    mult_done = 1'b0;
                    compare_done = 1'b0;
                    bitwise_done = 1'b0;
                    move_done = 1'b0;
                    product_sum_done = 1'b0;
                    sum_mask_done = 1'b0;
                end 
                if (shift_en) begin
                    execution_result = shift_result;
                    shift_done = shift_done_internal;
                    sum_done = 1'b0;
                    mult_done = 1'b0;
                    compare_done = 1'b0;
                    bitwise_done = 1'b0;
                    move_done = 1'b0;
                    product_sum_done = 1'b0;
                    sew_16_32 = 1'b0;
                    sew_32 = 1'b0;
                    sum_mask_done = 1'b0;
                end
                if (compare_en) begin
                    execution_result = compare_result;
                    compare_done = compare_done_internal;
                    sum_done = 1'b0;
                    shift_done = 1'b0;
                    mult_done = 1'b0;
                    bitwise_done = 1'b0;
                    move_done = 1'b0;
                    product_sum_done = 1'b0;
                    sew_16_32 = 1'b0;
                    sew_32 = 1'b0;
                    sum_mask_done = 1'b0;
                end
                if (bitwise_en) begin
                    execution_result = bitwise_result;
                    bitwise_done = bitwise_done_internal;
                    sum_done = 1'b0;
                    shift_done = 1'b0;
                    mult_done = 1'b0;
                    compare_done = 1'b0;
                    move_done = 1'b0;
                    product_sum_done = 1'b0;
                    sew_16_32 = 1'b0;
                    sew_32 = 1'b0;
                    sum_mask_done = 1'b0;
                end
                if (move_en) begin
                    execution_result = move_result;
                    move_done = 1'b1;  
                    sum_done = 1'b0;
                    shift_done = 1'b0;
                    mult_done = 1'b0;
                    compare_done = 1'b0;
                    bitwise_done = 1'b0;
                    product_sum_done = 1'b0;
                    sew_16_32 = 1'b0;
                    sew_32 = 1'b0;
                    sum_mask_done = 1'b0;
                end
                if (mask_add_en | mult_sum_active) begin
                    if (sew == 2'b00) begin
                        sew_16_32 = 1'b0;
                        sew_32    = 1'b0;
                    end
                    else if (sew == 2'b01) begin
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
                    execution_result = sum_mask_result;
                    sum_mask_done = sum_mask_done_internal;
                    sum_done = 1'b0;
                    shift_done = 1'b0;
                    mult_done = 1'b0;
                    compare_done = 1'b0;
                    bitwise_done = 1'b0;
                    move_done = 1'b0;
                    product_sum_done = 1'b0;
                end
                if (mult_done_internal) begin
                    mult_done = mult_done_internal;
                    sum_done = 1'b0;
                    shift_done = 1'b0;
                    compare_done = 1'b0;
                    bitwise_done = 1'b0;
                    product_sum_done = 1'b0;
                    sew_16_32 = 1'b0;
                    sew_32 = 1'b0;
                    sum_mask_done = 1'b0;
                    case (sew)
                        2'b00: begin // 8-bit elements → 16-bit products
                            for (int i = 0; i < `NUM_ELEMENT_SEW8 ; i++) begin
                                if (mul_high_reg)
                                    execution_result[i*8 +: 8] = product_result[i*16 + 8 +: 8]; // Upper 8 bits
                                else if (mul_low_reg) 
                                    execution_result[i*8 +: 8] = product_result[i*16 +: 8];     // Lower 8 bits
                                else 
                                    execution_result = '0; 
                            end
                        end
                        2'b01: begin // 16-bit elements → 32-bit products
                            for (int i = 0; i < `NUM_ELEMENT_SEW16; i++) begin
                                if (mul_high_reg)
                                    execution_result[i*16 +: 16] = product_result[i*32 + 16 +: 16]; // Upper 16 bits
                                else if (mul_low_reg)
                                    execution_result[i*16 +: 16] = product_result[i*32 +: 16];      // Lower 16 bits
                                else 
                                    execution_result = '0; 
                            end
                        end
                        2'b10: begin // 32-bit elements → 64-bit products
                            for (int i = 0; i < `NUM_ELEMENT_SEW32; i++) begin
                                if (mul_high_reg)
                                    execution_result[i*32 +: 32] = product_result[i*64 + 32 +: 32]; // Upper 32 bits
                                else if (mul_low_reg)
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
                if (mult_done_internal && product_sum_done_internal && sum_done_internal) begin
                    product_sum_done = product_sum_done_internal;
                    sum_done = 1'b0;
                    shift_done = 1'b0;
                    compare_done = 1'b0;
                    bitwise_done = 1'b0;
                    sum_mask_done = 1'b0;
                    execution_result = sum_product_result;
                        /*case (sew)
                            2'b00: begin 
                                for (int i = 0; i < `NUM_ELEMENT_SEW8; i++) begin
                                    if (mul_sum_high_reg)
                                        execution_result[i*8 +: 8] = sum_product_result[i*16 + 8 +: 8];
                                    else if (mul_sum_low_reg)
                                        execution_result[i*8 +: 8] = sum_product_result[i*16 +: 8];
                                    else
                                        execution_result[i*32 +: 32] = '0;
                                end            
                            end
                            2'b01: begin 
                                for (int i = 0; i < `NUM_ELEMENT_SEW16; i++) begin 
                                    if (mul_sum_high_reg)
                                        execution_result[i*16 +: 16] = sum_product_result[i*32 + 16 +: 16];
                                    else if (mul_sum_low_reg)
                                        execution_result[i*16 +: 16] = sum_product_result[i*32 +: 16];
                                    else
                                        execution_result[i*32 +: 32] = '0;
                                end        
                            end
                            2'b10: begin 
                                for (int i = 0; i < `NUM_ELEMENT_SEW32; i++) begin
                                    if (mul_sum_high_reg)
                                        execution_result[i*32 +: 32] = sum_product_result[i*64 + 32 +: 32];
                                    else if (mul_sum_low_reg)
                                        execution_result[i*32 +: 32] = sum_product_result[i*64 +: 32];
                                    else
                                        execution_result[i*32 +: 32] = '0;
                                end
                            end
                            default: begin
                                execution_result = '0;
                            end
                        endcase*/
                    end
            end
            else begin 
                execution_result = '0;
                sum_done = 1'b0;
                shift_done = 1'b0;
                mult_done = 1'b0;
                compare_done = 1'b0;
                bitwise_done = 1'b0;
                move_done = 1'b0;
                product_sum_done = 1'b0;
                sew_16_32 = 1'b0;
                sew_32 = 1'b0;
            end
        end

    logic sew_16_32_latch,sew_32_latch;
    
    always_ff @(posedge clk) begin
        if (!reset) begin
            sew_16_32_latch <= 1'b0;
            sew_32_latch <= 1'b0; 
        end
        else begin
            sew_16_32_latch <= sew_16_32;
            sew_32_latch <= sew_32; 
        end
    end

    vector_adder_subtractor adder_inst (
        .A              (adder_data_1),
        .B              (adder_data_2),
        .Ctrl           (Ctrl),         
        .sew_16_32      (sew_16_32),     
        .sew_32         (sew_32),        
        .Sum            (sum_result),
        .carry_out      (carry_out),
        .sum_done       (sum_done_internal)
    );

    vector_multiplier vect_mult(
        .clk            (clk),
        .reset          (reset),
        .data_in_A      (mult_data_1),
        .data_in_B      (mult_data_2),
        .sew            (sew),
        .signed_mode    (signed_mult),
        .count_0        (count_0),
        .start          (start),
        .mult_done      (mult_done_internal),
        .product        (product_result)
    );  

    vector_compare_unit vect_comp (
        .dataA          (compare_data_1),         
        .dataB          (compare_data_2),               
        .cmp_op         (cmp_op),        
        .sew            (sew),         
        .compare_result (compare_result), 
        .compare_done   (compare_done_internal)  
    );

    vector_bitwise_unit vect_bitwise (
        .dataA          (bitwise_data_1),         
        .dataB          (bitwise_data_2),              
        .bitwise_op     (bitwise_op),   
        .sew            (sew),          
        .bitwise_result     (bitwise_result),   
        .bitwise_done       (bitwise_done_internal)       
    );

    vector_shift_unit vector_shift(
        .dataA          (shift_data_1),         
        .dataB          (shift_data_2),             
        .shift_op       (shift_op),      
        .sew            (sew),           
        .shift_result   (shift_result),  
        .shift_done     (shift_done_internal)    
    );

    vector_multiply_add_unit mult_add(
        .clk                (clk),
        .reset              (reset),
        .data_A             (mult_add_data_1),    
        .data_B             (mult_add_data_2),      
        .data_C             (mult_add_data_3),  
        .signed_mode        (signed_mult_sum), 
        .sew_16_32          (sew_16_32_latch),
        .sew_32             (sew_32_latch),    
        .accum_op           (accum_op_mul),     
        .sew                (sew_sum_mul),         
        .Ctrl               (Ctrl_latch),
        .start              (start),
        .count_0_mul_add    (count_0_mult_add),
        .sum_product_result (sum_product_result),
        .product_sum_done   (product_sum_done_internal)
    );

    vector_mask_add_sub mask_add_sub (
        .adder_data_1     (mask_add_data_1),
        .adder_data_2     (mask_add_data_2),
        .mask_reg         (mask_reg_updated),
        .Ctrl             (Ctrl),
        .sew_16_32        (sew_16_32),
        .sew_32           (sew_32),
        .sew              (sew),
        .carry_out        (carry_out_mask),
        .sum_mask_result  (sum_mask_result),
        .sum_mask_done    (sum_mask_done_internal)
    );
    
    assign move_result = move_data_1;
   
    always_ff @(posedge clk ) begin
        if (!reset) begin
            execution_done <= 1'b0;
            execution_result_reg <= '0;
        end else if (sum_done | shift_done | mult_done | compare_done | bitwise_done | product_sum_done | move_done ) begin
            execution_done <= 1'b1;
            execution_result_reg <= execution_result;
        end else if (sum_done && mask_add_en ) begin
            execution_done <= 1'b0;
            execution_result_reg <= 'b0;
        end else begin
            execution_done <= 1'b0;
            execution_result_reg <= '0;
        end
    end

endmodule