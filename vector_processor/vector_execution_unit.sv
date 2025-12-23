`include "vec_de_csr_defs.svh"
`include "vector_processor_defs.svh"

module vector_execution_unit(
    input   logic                    clk,
    input   logic                    reset,
    input   logic [`VLEN-1:0]        data_1,
    input   logic [`VLEN-1:0]        data_2, 
    input   logic                    Ctrl,
    input   logic [5:0]              sew_eew_mux_out,
    input   logic [2:0]              execution_op,
    input   logic                    signed_mode, 
    output  logic [`VLEN-1:0]        result,
    output  logic [1:0]              sew,           // 00=8-bit, 01=16-bit, 10=32-bit
    output  logic                    start
);

    logic [2:0]                      sew_mode_bit;
    logic [1:0]                      sew_mode;
    logic                            count_0;
    logic                            sew_16_32;
    logic                            sew_32;
    logic [`VLEN-1:0]                adder_result;
    logic [`VLEN-1:0]                mult_result;

    always_comb begin
        case (sew_eew_mux_out)
            6'b001000: begin 
                sew = 2'b00;
            end
            6'b010000: begin
                sew = 2'b01;
            end
            6'b100000: begin
                sew = 2'b10;
            end
            default:    sew = 2'b11;
        endcase
    end

    always_comb begin
        case(execution_op)
            3'b000 : begin
                result =  adder_result;
            end    
            //3'b001 :
            //3'b010 :
            3'b011 : begin 
                result = mult_result;
                start = 1'b1;
            end
            //3'b100 :
            //3'b101 :
            //3'b110 :
            //3'b111 : 

        endcase
    end

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

    vector_adder_subtractor adder_inst (
        .Ctrl           (Ctrl),         
        .sew_16_32      (sew_16_32),     
        .sew_32         (sew_32),        
        .A              (data_1),
        .B              (data_2),
        .Sum            (adder_result)
    );

    vector_multiplier vect_mult(
        .clk            (clk),
        .reset          (reset),
        .sew            (sew),           // 00=8-bit, 01=16-bit, 10=32-bit
        .start          (start),
        .data_in_A      (data_1),    // 512-bit input A
        .data_in_B      (data_2),    // 512-bit input B
        .signed_mode    (signed_mode),
        .count_0        (count_0),
        .product        (mult_result)      // 1024-bit result
);

endmodule


