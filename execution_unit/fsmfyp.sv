module bit_16(
  input logic clk,
  input logic rst,
  input logic start,
  input logic [15:0] mult_out1,
  input logic [15:0] mult_out2,
  output logic [31:0] product1,
  output logic [31:0] product2
);
logic [8:0] sum1, sum2, sum3, sum4, sum5, sum6;
logic [15:0] accum_0, accum_1, accum_2, accum_3;
logic [15:0] next_accum_0, next_accum_1, next_accum_2, next_accum_3;
logic done, next_done;

typedef enum logic [2:0] {
    IDLE, PP1, PP2, PP3, PP4, DONE
} state_t;

state_t state, next_state;

// Combinational logic for next state and outputs
always_comb begin
    // Default assignments
    next_accum_0 = accum_0;
    next_accum_1 = accum_1;
    next_accum_2 = accum_2;
    next_accum_3 = accum_3;
    next_done = done;
    next_state = state;
    sum1 = '0;
    sum2 = '0;
    sum3 = '0;
    sum4 = '0;
    sum5 = '0;
    sum6 = '0;

    case (state)
        IDLE: begin
            next_done = 0;
            if (start) begin
                next_accum_0 = 0;
                next_accum_1 = 0;
                next_accum_2 = 0;
                next_accum_3 = 0;
                next_state = PP1;
            end
        end

        PP1: begin
            // A_L × B_L
            next_accum_0[7:0] = mult_out1[7:0];
            next_accum_1[7:0] = mult_out2[15:8];
            
            next_accum_0[15:8] = mult_out1[7:0];
            next_accum_1[15:8] = mult_out2[15:8];
            next_state = PP2;
        end

        PP2: begin
            // A_L × B_H
            sum1 = accum_1[7:0] + mult_out1[7:0];              // PP2_low
            sum2 = accum_2[7:0] + mult_out1[15:8] + sum1[8];    // PP2_high + carry
            sum3 = accum_3[7:0] + sum2[8];

            sum4 = accum_1[15:8] + mult_out2[7:0];              // PP2_low
            sum5 = accum_2[15:8] + mult_out2[15:8] + sum1[8];    // PP2_high + carry
            sum6 = accum_3[15:8] + sum2[8];
             
            next_accum_1[7:0] = sum1[7:0];
            next_accum_2[7:0] = sum2[7:0];
            next_accum_3[7:0] = sum3[7:0];                    // carry from accum_2 to accum_3
    
            next_accum_1[15:8] = sum4[7:0];
            next_accum_2[15:8] = sum5[7:0];
            next_accum_3[15:8] = sum6[7:0]; 

            next_state = PP3;
        end

        PP3: begin
            // A_H × B_L
            sum1 = accum_1[7:0] + mult_out1[7:0];              // PP3_low
            sum2 = accum_2[7:0] + mult_out1[15:8] + sum1[8];   // PP3_high + carry
            sum3 = accum_3[7:0] + sum2[8];

            sum4 = accum_1[15:8] + mult_out2[7:0];              // PP3_low
            sum5 = accum_2[15:8] + mult_out2[15:8] + sum1[8];   // PP3_high + carry
            sum6 = accum_3[15:8] + sum2[8];

            next_accum_1[7:0] = sum1[7:0];
            next_accum_2[7:0] = sum2[7:0];
            next_accum_3[7:0] = sum3[7:0];                   // carry from accum_2 to accum_3

            next_accum_1[15:8] = sum4[7:0];
            next_accum_2[15:8] = sum5[7:0];
            next_accum_3[15:8] = sum6[7:0]; 

            next_state = PP4;
        end

        PP4: begin
            // A_H × B_H
            sum1 = accum_2[7:0] + mult_out1[7:0];              // PP4_low
            sum2 = accum_3[7:0] + mult_out1[15:8] + sum1[8];   // PP4_high + carry

            sum4 = accum_2[15:8] + mult_out2[7:0];              // PP4_low
            sum5 = accum_3[15:8] + mult_out2[15:8] + sum1[8];   // PP4_high + carry

            next_accum_2[7:0] = sum1[7:0];
            next_accum_3[7:0] = sum2[7:0];

            next_accum_2[15:8] = sum4[7:0];
            next_accum_3[15:8]= sum5[7:0];
            next_state = DONE;
        end

        DONE: begin
            next_done = 1;
            if (!start) begin
                next_state = IDLE;
            end
        end

        default: begin
            next_state = IDLE;
        end
    endcase
end

// Sequential logic (register updates)
always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
        accum_0 <= 0;
        accum_1 <= 0;
        accum_2 <= 0;
        accum_3 <= 0;
        done    <= 0;
        state   <= IDLE;
    end else begin
        accum_0 <= next_accum_0;
        accum_1 <= next_accum_1;
        accum_2 <= next_accum_2;
        accum_3 <= next_accum_3;
        done    <= next_done;
        state   <= next_state;
    end
end
       
// Final product output
assign product1 = {accum_3[7:0], accum_2[7:0], accum_1[7:0], accum_0[7:0]};
assign product2 = {accum_3[15:8], accum_2[15:8], accum_1[15:8], accum_0[15:8]};

endmodule