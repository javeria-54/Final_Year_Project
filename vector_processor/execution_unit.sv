`include "vec_de_csr_defs.svh"

module execution_unit(
    input  logic                    clk,
    input  logic                    reset,
    input  logic [`VLEN-1:0]        data_1,
    input  logic [`VLEN-1:0]        data_2, 
    input  logic                    Ctrl,
    output logic [`VLEN-1:0]        result
);
    logic [2:0] sew_mode_bit;
    logic [1:0] sew_mode;

    csr_vtype_s         csr_vtype_q;

    assign csr_vtype_q.vsew  = sew_mode_bit;
    assign sew_mode_bit [1:0] = sew_mode;

    logic [1:0] sew_sel;
    logic       sew_16_32;
    logic       sew_32;

    always_comb begin
        case (vew_e'(sew_mode))
            EW8:    sew_sel = 3'b000;
            EW16:   sew_sel = 3'b001;
            EW32:   sew_sel = 3'b010;
            EW64:   sew_sel = 3'b011;
            default: sew_sel = 3'b000;
        endcase
    end

    always_comb begin 
        if (sew_sel == 2'b01) begin
            sew_16_32 = 1;
            sew_32    = 0;
        end
        else if (sew_sel == 2'b10) begin
            sew_16_32 = 1;
            sew_32    = 1;
        end
        else begin
            sew_16_32 = 0;
            sew_32    = 0;
        end
    end 

    adder_subtractor adder_inst (
        .Ctrl       (Ctrl),         
        .sew_16_32  (sew_16_32),     
        .sew_32     (sew_32),        
        .A          (data_1),
        .B          (data_2),
        .Sum        (result)
    );

endmodule
