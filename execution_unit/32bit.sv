module bit_32(
    input logic clk,
    input logic reset,
    input logic start,
    input logic [15:0] mult_out,
    output logic [63:0] product 
);

logic [16:0] sum1, sum2, sum3;
logic [15:0] accum_0, accum_1, accum_2, accum_3, mult_out_shift;
logic [15:0] next_accum_0, next_accum_1, next_accum_2, next_accum_3;
logic  done, next_done;

typedef enum logic [4:0] {
    IDLE, PP1, PP2, PP3, PP4, PP5, PP6, PP7, PP8, PP9, PP10, PP11, PP12, PP13, PP14, PP15, PP16, DONE
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
            // A_0 × B_0
            sum1 = mult_out ;

            next_accum_0 = sum1[15:0];
            next_state = PP2;
        end

        PP2: begin
            // A_1 × B_0
			mult_out_shift = mult_out << 8; 
            sum1 = accum_0 + mult_out_shift;              
            sum2 = {mult_out[15:8] + sum1[16] };    
            sum3 = sum2[16];

            next_accum_0 = sum1[15:0];
            next_accum_1 = sum2[15:0];
            next_accum_2 = sum3;                   
            next_state = PP3;
        end

        PP3: begin
            // A_2 × B_0
            sum1 = accum_1 + mult_out;              // PP3_low
            sum2 = accum_2 + sum1[16];   // PP3_high + carry
            
            next_accum_1 = sum1[15:0];
            next_accum_2 = sum2;
            next_state = PP4;
        end

        PP4: begin
            // A_3 × B_0
			mult_out_shift = mult_out << 8;
            sum1 = accum_1 + mult_out_shift;              // PP4_low
            sum2 = {mult_out[15:8] + sum1[16] };   // PP4_high + carry
            sum3 = sum2[16];

            next_accum_1 = sum1[15:0];
            next_accum_2 = sum2[15:0];
            next_accum_3 = sum3;
            next_state = PP5;
        end
		
		PP5: begin
            // A_0 × B_1
            mult_out_shift = mult_out << 8; 
            sum1 = accum_0 + mult_out_shift;              // PP2_low
            sum2 = {accum_1 + mult_out[15:8] + sum1[16] };    // PP2_high + carry
            sum3 = accum_2 + sum2[16];

            next_accum_0 = sum1[15:0];
            next_accum_1 = sum2[15:0];
            next_accum_2 = sum3;
            next_state = PP6;
        end

        PP6: begin
            // A_1 × B_1
            sum1 = accum_1 + mult_out;   // PP3_low
            sum2 = accum_2 + sum1[16];   // PP3_high + carry
            
            next_accum_1 = sum1[15:0];
            next_accum_2 = sum2;
            next_state = PP7;
        end

        PP7: begin
            // A_2 × B_1
			mult_out_shift = mult_out << 8;
            sum1 = accum_1 + mult_out_shift;              // PP4_low
            sum2 = {accum_2 + mult_out[15:8] + sum1[16] };   // PP4_high + carry
            sum3 = sum2[16];

            next_accum_1 = sum1[15:0];
            next_accum_2 = sum2[15:0];
            next_accum_3 = sum3;
            next_state = PP8;
        end
		
		PP8: begin
            // A_3 × B_1
            sum1 = accum_2 + mult_out;
			sum2 = sum1[16];
			
			next_accum_2 = sum1[15:0];
			next_accum_3 = sum2;
            next_state = PP9;
        end

        PP9: begin
            // A_0 × B_2
            sum1 = accum_1 + mult_out;  // PP3_low
            sum2 = accum_2 + sum1[16];   // PP3_high + carry
            
            next_accum_1 = sum1[15:0];
            next_accum_2 = sum2;
            next_state = PP10;
        end

        PP10: begin
            // A_1 × B_2
			mult_out_shift = mult_out << 8;
            sum1 = accum_1 + mult_out_shift;              // PP4_low
            sum2 = {accum_2 + mult_out[15:8] + sum1[16]};   // PP4_high + carry
            sum3 = sum2[16];

            next_accum_1 = sum1[15:0];
            next_accum_2 = sum2[15:0];
            next_accum_3 = sum3;
            next_state = PP11;
        end
		
		PP11: begin
            // A_2 × B_2
            sum1 = accum_2 + mult_out;
			sum2 = sum1[16];
			
			next_accum_2 = sum1[15:0];
			next_accum_3 = sum2;
            next_state = PP12;
        end

        PP12: begin
            // A_3 × B_2
			mult_out_shift = mult_out << 8; 
            sum1 = accum_2 + mult_out_shift;              // PP2_low
            sum2 = {mult_out[15:8] + sum1[16] };    // PP2_high + carry
            sum3 = sum2[16];

            next_accum_2 = sum1[15:0];
            next_accum_3 = sum2[15:0];
            
            next_state = PP13;
        end

        PP13: begin
            // A_0 × B_2
            mult_out_shift = mult_out << 8;
            sum1 = accum_1 + mult_out_shift;              // PP4_low
            sum2 = {accum_2 + mult_out[15:8] + sum1[16] };   // PP4_high + carry
            sum3 = accum_3 + sum2[16];

            next_accum_1 = sum1[15:0];
            next_accum_2 = sum2[15:0];
            next_accum_3 = sum3;
            next_state = PP14;
        end

        PP14: begin
            // A_1 × B_3
			sum1 = accum_2 + mult_out;
			sum2 = accum_3 + sum1[16];
			
			next_accum_2 = sum1[15:0];
			next_accum_3 = sum2 ;
            next_state = PP15;
        end
		
		PP15: begin
            // A_2 × B_3
			mult_out_shift = mult_out << 8;
            sum1 = accum_2 + mult_out_shift;              // PP2_low
            sum2 = {accum_3 + mult_out[15:8] + sum1[16] };    // PP2_high + carry
            sum3 = sum2[16];            

            next_accum_2 = sum1[15:0];
            next_accum_3 = sum2[15:0];                              
            next_state = PP16;
        end
		
		PP16: begin
            // A_3 × B_3
            sum1 = accum_3 + mult_out;
            sum2 = sum1[16];

			next_accum_3 = sum1[15:0];
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
always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
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
assign product = {accum_3, accum_2, accum_1, accum_0};

endmodule
