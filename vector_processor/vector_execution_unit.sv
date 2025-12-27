`include "vec_de_csr_defs.svh"
`include "vector_processor_defs.svh"

module vector_execution_unit(
    input   logic                               clk,
    input   logic                               reset,
    input   logic [`MAX_VLEN-1:0]               data_1,
    input   logic [`MAX_VLEN-1:0]               data_2, 
    input   logic                               Ctrl,
    input   logic [6:0]                         sew_eew_mux_out,
    input   logic [2:0]                         execution_op,
    input   logic                               signed_mode, 
    input   logic                               mul_low,
    input   logic                               mul_high,
    input   logic                               reverse_sub_inst,
    output  logic [`MAX_VLEN-1:0]               result,
    output  logic [1:0]                         sew,
    output  logic                               count_0,
    output  logic                               sew_16_32,
    output  logic                               sew_32,
    output  logic [`MAX_VLEN-1:0]               sum,
    output  logic [`MAX_VLEN*2-1:0]             product
);
    
    // Internal signals
    logic add_en, shift_en, mult_en;
    logic [`MAX_VLEN-1:0] adder_data_1, adder_data_2, temporary_A;
    logic [`MAX_VLEN-1:0] mult_data_1, mult_data_2;

    // SEW decoding
    always_comb begin
        case (sew_eew_mux_out)
            7'b0001000: sew = 2'b00;  // 8-bit
            7'b0010000: sew = 2'b01;  // 16-bit
            7'b0100000: sew = 2'b10;  // 32-bit
            default:    sew = 2'b11;
        endcase
    end

    // Execution unit enable logic
    always_comb begin
        // Default values
        add_en = 1'b0;
        shift_en = 1'b0;
        mult_en  = 1'b0;
        
        case(execution_op)
            3'b000: begin
                add_en = 1'b1;
            end    
            3'b001: begin
                shift_en = 1'b1;
            end
            3'b011: begin 
                mult_en = 1'b1;
            end
            default: begin
                add_en = 1'b0;
                shift_en = 1'b0;
                mult_en  = 1'b0;
            end
        endcase
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

    assign adder_data_1 = add_en ? data_1 : `MAX_VLEN'b0;
    assign adder_data_2 = add_en ? data_2 : `MAX_VLEN'b0;
    assign mult_data_1  = mult_en ? data_1 : `MAX_VLEN'b0;
    assign mult_data_2  = mult_en ? data_2 : `MAX_VLEN'b0;
    assign shift_data_1  = shift_en ? data_1 : `MAX_VLEN'b0;
    assign shift_data_2  = shift_en ? data_2 : `MAX_VLEN'b0;

    always_comb begin
        if (reset) begin
            result = '0;
        end else begin
            if (add_en) begin
                result = sum;
            end 
            else if (mult_en && mul_low) begin
                result = product[2047:0];
            end 
            else if (mult_en && mul_high) begin
                result = product[4096:2048];
            end 
            else begin 
                result = '0;
            end
        end
    end

    always_comb begin
        if (!reset) begin
            temporary_A = 0;
        end
        else if(reverse_sub_inst) begin
            temporary_A = adder_data_1;
            adder_data_1 = adder_data_2;
            adder_data_2 = temporary_A;    
        end
        else begin
            temporary_A = 0;
        end
    end

        // Adder instance
    vector_adder_subtractor adder_inst (
        .Ctrl           (Ctrl),         
        .sew_16_32      (sew_16_32),     
        .sew_32         (sew_32),        
        .A              (adder_data_1),
        .B              (adder_data_2),
        .Sum            (sum)
    );

    // Multiplier instance
    vector_multiplier vect_mult(
        .clk            (clk),
        .reset          (reset),
        .sew            (sew),
        .data_in_A      (mult_data_1),
        .data_in_B      (mult_data_2),
        .signed_mode    (signed_mode),
        .count_0        (count_0),
        .product        (product)
    );

endmodule