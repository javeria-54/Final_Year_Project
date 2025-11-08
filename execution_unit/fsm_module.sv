module combined_accumulator (
    input logic clk,
    input logic rst,
    input logic start,
    input logic mode_32bit,  // 0: 16-bit mode (2x16x16), 1: 32-bit mode (1x32x32)
    input logic [15:0] mult_out_1,  // Partial product for multiplier 1 (or single input in 32-bit mode)
    input logic [15:0] mult_out_2,  // Partial product for multiplier 2 (unused in 32-bit mode)
    output logic [31:0] product_1,  // Final result for multiplier 1 (or low 32 bits in 32-bit mode)
    output logic [31:0] product_2,  // Final result for multiplier 2 (or high 32 bits in 32-bit mode)
    output logic done               // Completion signal
);

// Internal registers
logic [17:0] sum1, sum2, sum3;      // 18-bit sums (for 16-bit mode)
logic [16:0] sum32_1, sum32_2;      // 17-bit sums (for 32-bit mode)
logic [15:0] accum_0, accum_1, accum_2, accum_3;
logic [15:0] next_accum_0, next_accum_1, next_accum_2, next_accum_3;
logic next_done;

// Combined state definitions
typedef enum logic [4:0] {
    IDLE,
    // 16-bit mode states
    PP1_16, PP2_16, PP3_16, PP4_16, 
    // 32-bit mode states
    PP1_32, PP2_32, PP3_32, PP4_32, PP5_32, PP6_32, PP7_32, PP8_32,
    PP9_32, PP10_32, PP11_32, PP12_32, PP13_32, PP14_32, PP15_32, PP16_32,
    DONE
} state_t;

state_t state, next_state;
logic [15:0] mult_out_shift; // For 32-bit mode shifts

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
    sum32_1 = '0;
    sum32_2 = '0;
    mult_out_shift = '0;

    case (state)
        IDLE: begin
            next_done = 0;
            if (start) begin
                next_accum_0 = 0;
                next_accum_1 = 0;
                next_accum_2 = 0;
                next_accum_3 = 0;
                next_state = mode_32bit ? PP1_32 : PP1_16;
            end
        end

        // 16-bit mode states (2x16x16 multiplications)
        PP1_16: begin
            // Process both PP1s in parallel
            next_accum_0[7:0] = mult_out_1[7:0];    // M1: A_L × B_L (low)
            next_accum_0[15:8] = mult_out_2[7:0];   // M2: A_L × B_L (low)
            next_accum_1[7:0] = mult_out_1[15:8];   // M1: A_L × B_L (high)
            next_accum_1[15:8] = mult_out_2[15:8];  // M2: A_L × B_L (high)
            next_state = PP2_16;
        end

        PP2_16: begin
            // Process both PP2s in parallel (A_L × B_H)
            // M1 path (bits [8:0])
            sum1[8:0] = {1'b0, accum_1[7:0]} + {1'b0, mult_out_1[7:0]};
            // M2 path (bits [17:9])
            sum1[17:9] = {1'b0, accum_1[15:8]} + {1'b0, mult_out_2[7:0]};
            
            // M1 path with carry
            sum2[8:0] = {1'b0, accum_2[7:0]} + {1'b0, mult_out_1[15:8]} + sum1[8];
            // M2 path with carry
            sum2[17:9] = {1'b0, accum_2[15:8]} + {1'b0, mult_out_2[15:8]} + sum1[17];
            
            // M1 carry propagation
            sum3[8:0] = {1'b0, accum_3[7:0]} + sum2[8];
            // M2 carry propagation
            sum3[17:9] = {1'b0, accum_3[15:8]} + sum2[17];

            // Update accumulators
            next_accum_1[7:0] = sum1[7:0];
            next_accum_1[15:8] = sum1[16:9];
            next_accum_2[7:0] = sum2[7:0];
            next_accum_2[15:8] = sum2[16:9];
            next_accum_3[7:0] = sum3[7:0];
            next_accum_3[15:8] = sum3[16:9];
            next_state = PP3_16;
        end

        PP3_16: begin
            // Process both PP3s in parallel (A_H × B_L)
            sum1[8:0] = {1'b0, accum_1[7:0]} + {1'b0, mult_out_1[7:0]};
            sum1[17:9] = {1'b0, accum_1[15:8]} + {1'b0, mult_out_2[7:0]};
            
            sum2[8:0] = {1'b0, accum_2[7:0]} + {1'b0, mult_out_1[15:8]} + sum1[8];
            sum2[17:9] = {1'b0, accum_2[15:8]} + {1'b0, mult_out_2[15:8]} + sum1[17];
            
            sum3[8:0] = {1'b0, accum_3[7:0]} + sum2[8];
            sum3[17:9] = {1'b0, accum_3[15:8]} + sum2[17];

            next_accum_1[7:0] = sum1[7:0];
            next_accum_1[15:8] = sum1[16:9];
            next_accum_2[7:0] = sum2[7:0];
            next_accum_2[15:8] = sum2[16:9];
            next_accum_3[7:0] = sum3[7:0];
            next_accum_3[15:8] = sum3[16:9];
            next_state = PP4_16;
        end

        PP4_16: begin
            // Process both PP4s in parallel (A_H × B_H)
            sum1[8:0] = {1'b0, accum_2[7:0]} + {1'b0, mult_out_1[7:0]};
            sum1[17:9] = {1'b0, accum_2[15:8]} + {1'b0, mult_out_2[7:0]};
            
            sum2[8:0] = {1'b0, accum_3[7:0]} + {1'b0, mult_out_1[15:8]} + sum1[8];
            sum2[17:9] = {1'b0, accum_3[15:8]} + {1'b0, mult_out_2[15:8]} + sum1[17];

            next_accum_2[7:0] = sum1[7:0];
            next_accum_2[15:8] = sum1[16:9];
            next_accum_3[7:0] = sum2[7:0];
            next_accum_3[15:8] = sum2[16:9];
            next_state = DONE;
        end

        // 32-bit mode states (1x32x32 multiplication)
        PP1_32: begin
            // A_0 × B_0
            sum32_1 = mult_out_1;
            next_accum_0 = sum32_1[15:0];
            next_state = PP2_32;
        end

        PP2_32: begin
            // A_1 × B_0
            mult_out_shift = mult_out_1 << 8; 
            sum32_1 = accum_0 + mult_out_shift;              
            sum32_2 = {mult_out_1[15:8] + sum32_1[16] };    
            
            next_accum_0 = sum32_1[15:0];
            next_accum_1 = sum32_2[15:0];
            next_accum_2 = sum32_2[16];                   
            next_state = PP3_32;
        end

        PP3_32: begin
            // A_2 × B_0
            sum32_1 = accum_1 + mult_out_1;
            sum32_2 = accum_2 + sum32_1[16];
            
            next_accum_1 = sum32_1[15:0];
            next_accum_2 = sum32_2;
            next_state = PP4_32;
        end

        PP4_32: begin
            // A_3 × B_0
            mult_out_shift = mult_out_1 << 8;
            sum32_1 = accum_1 + mult_out_shift;
            sum32_2 = {accum_2 + mult_out_1[15:8] + sum32_1[16]};
            
            next_accum_1 = sum32_1[15:0];
            next_accum_2 = sum32_2[15:0];
            next_accum_3 = sum32_2[16];
            next_state = PP5_32;
        end

        PP5_32: begin
            // A_0 × B_1
            mult_out_shift = mult_out_1 << 8;
            sum32_1 = accum_0 + mult_out_shift;
            sum32_2 = {accum_1 + mult_out_1[15:8] + sum32_1[16]};
            
            next_accum_0 = sum32_1[15:0];
            next_accum_1 = sum32_2[15:0];
            next_accum_2 = accum_2 + sum32_2[16];
            next_state = PP6_32;
        end

        PP6_32: begin
            // A_1 × B_1
            sum32_1 = accum_1 + mult_out_1;
            sum32_2 = accum_2 + sum32_1[16];
            
            next_accum_1 = sum32_1[15:0];
            next_accum_2 = sum32_2;
            next_state = PP7_32;
        end

        PP7_32: begin
            // A_2 × B_1
            mult_out_shift = mult_out_1 << 8;
            sum32_1 = accum_1 + mult_out_shift;
            sum32_2 = {accum_2 + mult_out_1[15:8] + sum32_1[16]};
            
            next_accum_1 = sum32_1[15:0];
            next_accum_2 = sum32_2[15:0];
            next_accum_3 = accum_3 + sum32_2[16];
            next_state = PP8_32;
        end

        PP8_32: begin
            // A_3 × B_1
            sum32_1 = accum_2 + mult_out_1;
            sum32_2 = accum_3 + sum32_1[16];
            
            next_accum_2 = sum32_1[15:0];
            next_accum_3 = sum32_2;
            next_state = PP9_32;
        end

        PP9_32: begin
            // A_0 × B_2
            mult_out_shift = mult_out_1 << 8;
            sum32_1 = accum_0 + mult_out_shift;
            sum32_2 = {accum_1 + mult_out_1[15:8] + sum32_1[16]};
            
            next_accum_0 = sum32_1[15:0];
            next_accum_1 = sum32_2[15:0];
            next_accum_2 = accum_2 + sum32_2[16];
            next_state = PP10_32;
        end

        PP10_32: begin
            // A_1 × B_2
            sum32_1 = accum_1 + mult_out_1;
            sum32_2 = accum_2 + sum32_1[16];
            
            next_accum_1 = sum32_1[15:0];
            next_accum_2 = sum32_2;
            next_state = PP11_32;
        end

        PP11_32: begin
            // A_2 × B_2
            mult_out_shift = mult_out_1 << 8;
            sum32_1 = accum_1 + mult_out_shift;
            sum32_2 = {accum_2 + mult_out_1[15:8] + sum32_1[16]};
            
            next_accum_1 = sum32_1[15:0];
            next_accum_2 = sum32_2[15:0];
            next_accum_3 = accum_3 + sum32_2[16];
            next_state = PP12_32;
        end

        PP12_32: begin
            // A_3 × B_2
            sum32_1 = accum_2 + mult_out_1;
            sum32_2 = accum_3 + sum32_1[16];
            
            next_accum_2 = sum32_1[15:0];
            next_accum_3 = sum32_2;
            next_state = PP13_32;
        end

        PP13_32: begin
            // A_0 × B_3
            mult_out_shift = mult_out_1 << 8;
            sum32_1 = accum_0 + mult_out_shift;
            sum32_2 = {accum_1 + mult_out_1[15:8] + sum32_1[16]};
            
            next_accum_0 = sum32_1[15:0];
            next_accum_1 = sum32_2[15:0];
            next_accum_2 = accum_2 + sum32_2[16];
            next_state = PP14_32;
        end

        PP14_32: begin
            // A_1 × B_3
            sum32_1 = accum_1 + mult_out_1;
            sum32_2 = accum_2 + sum32_1[16];
            
            next_accum_1 = sum32_1[15:0];
            next_accum_2 = sum32_2;
            next_state = PP15_32;
        end

        PP15_32: begin
            // A_2 × B_3
            mult_out_shift = mult_out_1 << 8;
            sum32_1 = accum_1 + mult_out_shift;
            sum32_2 = {accum_2 + mult_out_1[15:8] + sum32_1[16]};
            
            next_accum_1 = sum32_1[15:0];
            next_accum_2 = sum32_2[15:0];
            next_accum_3 = accum_3 + sum32_2[16];
            next_state = PP16_32;
        end

        PP16_32: begin
            // A_3 × B_3
            sum32_1 = accum_3 + mult_out_1;
            next_accum_3 = sum32_1[15:0];
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

// Final product outputs
assign product_1 = mode_32bit ? {accum_1, accum_0} : {accum_3[7:0], accum_2[7:0], accum_1[7:0], accum_0[7:0]};
assign product_2 = mode_32bit ? {accum_3, accum_2} : {accum_3[15:8], accum_2[15:8], accum_1[15:8], accum_0[15:8]};

endmodule