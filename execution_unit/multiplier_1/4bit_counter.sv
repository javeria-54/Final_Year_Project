module counter_4bit(
    input logic clk,
    input logic reset,
    input logic enable_4bit,
    output logic [3:0] count_32bit
);
    always_ff @(posedge clk or posedge reset) begin
        if (reset)
            count_32bit <= 4'b00;       
        else if (enable_4bit)
            count_32bit <= count_32bit + 1'b1; 
    end
endmodule