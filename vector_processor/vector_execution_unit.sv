`include "vec_de_csr_defs.svh"
`include "vector_processor_defs.svh"

module vector_execution_unit(
    input   logic                    clk,
    input   logic                    reset,
    input   logic [`VLEN-1:0]        data_1,
    input   logic [`VLEN-1:0]        data_2, 
    input   logic                    Ctrl,
    input   logic [6:0]              sew_eew_mux_out,
    input   logic [2:0]              execution_op,
    input   logic                    signed_mode, 
    output  logic [`VLEN-1:0]        result,
    output  logic [1:0]              sew,
    output  logic                    start,
    output  logic                    count_0,
    output  logic                    sew_16_32,
    output  logic                    sew_32,
    output  logic [`VLEN-1:0]        sum,
    output  logic [`VLEN*2-1:0]      product
);
    
    // Internal signals
    logic add_en, shift_en, mult_en;
    logic [`VLEN-1:0] adder_data_1, adder_data_2;
    logic [`VLEN-1:0] mult_data_1, mult_data_2;

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
        start    = 1'b0;
        
        case(execution_op)
            3'b000: begin
                add_en = 1'b1;
            end    
            3'b001: begin
                shift_en = 1'b1;
            end
            3'b011: begin 
                mult_en = 1'b1;
                start   = 1'b1;
            end
            default: begin
                add_en = 1'b0;
                shift_en = 1'b0;
                mult_en  = 1'b0;
                start    = 1'b0;
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

    // Adder input muxes
    execution_mux_2x1 mux_adder_1(
        .data1(`VLEN'b0),
        .data2(data_1),
        .sel(add_en),
        .mux_out(adder_data_1)
    );

    execution_mux_2x1 mux_adder_2(
        .data1(`VLEN'b0),
        .data2(data_2),
        .sel(add_en),
        .mux_out(adder_data_2)
    );

    // Adder instance
    vector_adder_subtractor adder_inst (
        .Ctrl           (Ctrl),         
        .sew_16_32      (sew_16_32),     
        .sew_32         (sew_32),        
        .A              (adder_data_1),
        .B              (adder_data_2),
        .Sum            (sum)
    );

    // Multiplier input muxes
    execution_mux_2x1 mux_mult_1(
        .data1(`VLEN'b0),
        .data2(data_1),
        .sel(mult_en),
        .mux_out(mult_data_1)
    );

    execution_mux_2x1 mux_mult_2(
        .data1(`VLEN'b0),
        .data2(data_2),
        .sel(mult_en),
        .mux_out(mult_data_2)
    );

    // Multiplier instance
    vector_multiplier vect_mult(
        .clk            (clk),
        .reset          (reset),
        .sew            (sew),
        .start          (start),
        .data_in_A      (mult_data_1),
        .data_in_B      (mult_data_2),
        .signed_mode    (signed_mode),
        .count_0        (count_0),
        .product        (product)
    );

endmodule

module execution_mux_2x1( 
    input   logic   [`VLEN-1:0] data1,
    input   logic   [`VLEN-1:0] data2,
    input   logic               sel,
    output  logic   [`VLEN-1:0] mux_out     
);
    always_comb begin 
        case (sel)
           1'b0:    mux_out = data1;    // Fixed: was operand1
           1'b1:    mux_out = data2;    // Fixed: was operand2
           default: mux_out = '0;
        endcase        
    end
endmodule