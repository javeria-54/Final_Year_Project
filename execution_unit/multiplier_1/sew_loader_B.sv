module sew_loader_B #(
    parameter int  REG_WIDTH = 32
)(
    input  logic [1:0]   sew,        
    input  logic [REG_WIDTH-1:0] data_in_B,
    output logic [REG_WIDTH-1:0] reg_out_B
);

    logic [REG_WIDTH-1:0] temp_reg;

    always_comb begin
        temp_reg = '0; 
        case (sew)
            00: begin
                // pack 4 elements of 8 bits
                temp_reg[7:0]   = data_in_B[7:0];
                temp_reg[15:8]  = data_in_B[15:8];
                temp_reg[23:16] = data_in_B[23:16];
                temp_reg[31:24] = data_in_B[31:24];
            end
            01: begin
                // pack 2 elements of 16 bits
                temp_reg[15:0]  = data_in_B[15:0];
                temp_reg[31:16] = data_in_B[31:16];
            end
            10: begin
                // pack single 32-bit element
                temp_reg[31:0]  = data_in_B[31:0];
            end
            default: temp_reg = '0;
        endcase
    end

    assign reg_out_B = temp_reg;

endmodule
 