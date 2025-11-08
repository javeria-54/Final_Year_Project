module counter_2bit(
    input logic clk,
    input logic reset,
    input logic enable_2bit,
    output logic [1:0] count_16bit
);
    always_ff @(posedge clk or posedge reset) begin
        if (reset)
            count_16bit <= 2'b00;       
        else if (enable_2bit)
            count_16bit <= count_16bit + 1'b1;
    end
endmodule

