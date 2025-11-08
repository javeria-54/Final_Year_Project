module carry_save_8 (
    input  logic               clk,
    input  logic               reset,
    input  logic               start,
    input  logic        [1:0]  sew,         // 0: 16-bit mode (2x16x16), 1: 32-bit mode (1x32x32)
    input  logic signed [15:0] mult_out_1,  // Partial product for multiplier 1 
    input  logic signed [15:0] mult_out_2,  // Partial product for multiplier 2 
    input  logic signed [15:0] mult_out_3,  // Partial product for multiplier 3
    input  logic signed [15:0] mult_out_4,  // Partial product for multiplier 4
    input  logic signed [15:0] mult_out_5,  // Partial product for multiplier 5
    input  logic signed [15:0] mult_out_6,  // Partial product for multiplier 6
    input  logic signed [15:0] mult_out_7,  // Partial product for multiplier 7
    input  logic signed [15:0] mult_out_8,  // Partial product for multiplier 8
    output logic signed [31:0] product_1,  // Final result for multiplier 1 (or low 32 bits in 32-bit mode)
    output logic signed [31:0] product_2,   // Final result for multiplier 2 (or high 32 bits in 32-bit mode) 
    output logic signed [31:0] product_3,    
    output logic signed [31:0] product_4 
);

// Internal registers
logic   signed [15:0]   sum16_0, sum16_1, sum16_2, sum16_3, sum16_4, sum16_5, sum16_6, sum16_7;  // 18-bit sums (for 16-bit mode)
logic   signed [15:0]   sum16_8, sum16_9, sum16_10, sum16_11, sum16_12, sum16_13;
logic   signed [15:0]   sum32_0, sum32_1, sum32_2, sum32_3, sum32_4, sum32_5, sum32_6, sum32_7, sum32_8, sum32_9, 
                        sum32_10, sum32_11, sum32_12, sum32_13, sum32_14, sum32_15, sum32_16 ; // 17-bit sums (for 32-bit mode)
logic   signed [15:0]   accum_0, accum_1, accum_2, accum_3;
logic   signed [15:0]   accum_4, accum_5, accum_6, accum_7;
logic   signed [15:0]   next_accum_0, next_accum_1, next_accum_2, next_accum_3 ;
logic   signed [15:0]   next_accum_4, next_accum_5, next_accum_6, next_accum_7 ;
logic          [7:0]    PP16_1_1A, PP16_1_1B, PP16_1_2A, PP16_1_2B, PP16_1_3A, PP16_1_3B, PP16_1_4A, PP16_1_4B ;
logic          [7:0]    PP16_2_1A, PP16_2_1B, PP16_2_2A, PP16_2_2B, PP16_2_3A, PP16_2_3B, PP16_2_4A, PP16_2_4B ;
logic          [7:0]    PP32_1A,  PP32_1B, PP32_2A, PP32_2B, PP32_3A, PP32_3B, PP32_4A, PP32_4B, 
                        PP32_5A,  PP32_5B, PP32_6A, PP32_6B, PP32_7A, PP32_7B, PP32_8A, PP32_8B;
logic          [7:0]    PP32_9A,  PP32_9B, PP32_10A, PP32_10B, PP32_11A, PP32_11B, PP32_12A, PP32_12B, 
                        PP32_13A,  PP32_13B, PP32_14A, PP32_14B, PP32_15A, PP32_15B, PP32_16A, PP32_16B, PP32;  
logic          [8:0]    result_0, result_1, result_2, result_3;
logic          [8:0]    result_4, result_5, result_6, result_7, result_8;

// Combined state definitions
typedef enum logic [2:0] {
    IDLE,
    PP_8,
    // 16-bit mode states
    PP_16, 
    // 32-bit mode states
    PP1_32, PP2_32    
} state_t;

state_t state, next_state;

// 3:2 CSA function - 8-bit inputs, 16-bit output {sum, carry}
function automatic [15:0] csa_3to2(input [7:0] a, b, c);
    reg [7:0] sum, carry;
    begin
        sum   = a ^ b ^ c;
        carry = (a & b) | (b & c) | (a & c);
        csa_3to2 = {carry, sum};
    end
endfunction

function automatic [15:0] half_adder(input [8:0] a, b);
    reg [7:0] sum, carry;
    begin
        sum   = a ^ b ;
        carry = a & b;
        half_adder = {carry, sum};
    end
endfunction

// Add sum + carry function - returns 9-bit result (1 extra bit for overflow)
function automatic [8:0] add_sum_carry;
    input [7:0] sum, carry;
    begin
        add_sum_carry = sum + {carry[7:0], 1'b0};  // carry left shift by 1
    end
endfunction

function automatic [8:0] add_carry_8bit(
    input logic [7:0] value,
    input logic       carry_in1, carry_in2, carry_in3
);
    logic [8:0] carry_out;
    begin
        carry_out = value + carry_in1 + carry_in2 + carry_in3;  // add carry to 8-bit value
        return carry_out;  // result[8] = carry_out, result[7:0] = sum
    end
endfunction

// Combinational logic for next state and outputs
always_comb begin
    // Default assignments
    next_accum_0 = accum_0;
    next_accum_1 = accum_1;
    next_accum_2 = accum_2;
    next_accum_3 = accum_3;
    next_accum_4 = accum_4;
    next_accum_5 = accum_5;
    next_accum_6 = accum_6;
    next_accum_7 = accum_7;

    sum16_0 = '0;           sum16_8 = '0;           sum32_0 = '0;           sum32_8 = '0;           sum32_16 = '0;       
    sum16_1 = '0;           sum16_9 = '0;           sum32_1 = '0;           sum32_9 = '0;
    sum16_2 = '0;           sum16_10 = '0;          sum32_2 = '0;           sum32_10 = '0;
    sum16_3 = '0;           sum16_11 = '0;          sum32_3 = '0;           sum32_11 = '0;
    sum16_4 = '0;           sum16_12 = '0;          sum32_4 = '0;           sum32_12 = '0; 
    sum16_5 = '0;           sum16_13 = '0;          sum32_5 = '0;           sum32_13 = '0;
    sum16_6 = '0;                                   sum32_6 = '0;           sum32_14 = '0;
    sum16_7 = '0;                                   sum32_7 = '0;           sum32_15 = '0;

    PP16_1_1A  = '0;        PP16_2_1A  = '0;
    PP16_1_1B  = '0;        PP16_2_1B  = '0;
    PP16_1_2A  = '0;        PP16_2_2A  = '0;
    PP16_1_2B  = '0;        PP16_2_2B  = '0;
    PP16_1_3A  = '0;        PP16_2_3A  = '0;
    PP16_1_3B  = '0;        PP16_2_3B  = '0;
    PP16_1_4A  = '0;        PP16_2_4A  = '0;
    PP16_1_4B  = '0;        PP16_2_4B  = '0;


    PP32_1A  = '0;          PP32_1B  = '0;
    PP32_2A  = '0;          PP32_2B  = '0;
    PP32_3A  = '0;          PP32_3B  = '0;
    PP32_4A  = '0;          PP32_4B  = '0;
    PP32_5A  = '0;          PP32_5B  = '0;
    PP32_6A  = '0;          PP32_6B  = '0;
    PP32_7A  = '0;          PP32_7B  = '0;
    PP32_8A  = '0;          PP32_8B  = '0;

    case (state)
        IDLE: begin
            //next_done = 0;
            if (start) begin
                next_accum_0 = 0;
                next_accum_1 = 0;
                next_accum_2 = 0;
                next_accum_3 = 0;
                next_state = (sew == 2'b00) ? PP_8 :
                                    (sew == 2'b01) ? PP_16:
                                    (sew == 2'b10) ? PP1_32: IDLE;               
                end
        end

        PP_8: begin
            next_accum_0 =  mult_out_1;
            next_accum_1 =  mult_out_2;
            next_accum_2 =  mult_out_3;
            next_accum_3 =  mult_out_4; 
            next_accum_4 =  mult_out_5;
            next_accum_5 =  mult_out_6;
            next_accum_6 =  mult_out_7;
            next_accum_7 =  mult_out_8; 
            next_state = IDLE;   
        end

        PP_16: begin   

            PP16_1_1A = mult_out_1[7:0];        PP16_1_1B = mult_out_1[15:8];
            PP16_1_2A = mult_out_2[7:0];        PP16_1_2B = mult_out_2[15:8];
            PP16_1_3A = mult_out_3[7:0];        PP16_1_3B = mult_out_3[15:8];
            PP16_1_4A = mult_out_4[7:0];        PP16_1_4B = mult_out_4[15:8];

            PP16_2_1A = mult_out_5[7:0];        PP16_2_1B = mult_out_5[15:8];
            PP16_2_2A = mult_out_6[7:0];        PP16_2_2B = mult_out_6[15:8];
            PP16_2_3A = mult_out_7[7:0];        PP16_2_3B = mult_out_7[15:8];
            PP16_2_4A = mult_out_8[7:0];        PP16_2_4B = mult_out_8[15:8];

            // CSA operations (output is 16-bit: {sum, carry})
            sum16_0 = {8'b0, PP16_1_1A};  // No CSA, so carry = 0
            sum16_1 = csa_3to2(PP16_1_1B, PP16_1_2A, PP16_1_3A);
            sum16_2 = csa_3to2(PP16_1_2B, PP16_1_3B, PP16_1_4A);
            sum16_3 = {8'b0, PP16_1_4B};  // No CSA, so carry = 0

            sum16_4 = {8'b0, PP16_2_1A};  // No CSA, so carry = 0
            sum16_5 = csa_3to2(PP16_2_1B, PP16_2_2A, PP16_2_3A);
            sum16_6 = csa_3to2(PP16_2_2B, PP16_2_3B, PP16_2_4A);
            sum16_7 = {8'b0, PP16_2_4B};  // No CSA, so carry = 0

            // Add sum + carry (9-bit results for overflow handling)
            result_0 = add_sum_carry(sum16_0[7:0],  sum16_0[15:8]);
            result_1 = add_sum_carry(sum16_1[7:0],  sum16_1[15:8]);
            result_2 = add_sum_carry(sum16_2[7:0],  sum16_2[15:8]);
            result_3 = add_sum_carry(sum16_3[7:0],  sum16_3[15:8]);

            result_4 = add_sum_carry(sum16_4[7:0],  sum16_4[15:8]);
            result_5 = add_sum_carry(sum16_5[7:0],  sum16_5[15:8]);
            result_6 = add_sum_carry(sum16_6[7:0],  sum16_6[15:8]);
            result_7 = add_sum_carry(sum16_7[7:0],  sum16_7[15:8]);

            sum16_8 = add_carry_8bit(result_1[7:0], result_0[8], 1'b0, 1'b0);
            sum16_9 = add_carry_8bit(result_2[7:0], result_1[8], 1'b0, 1'b0);
            sum16_10 = add_carry_8bit(result_3[7:0], result_2[8], 1'b0, 1'b0);

            sum16_11 = add_carry_8bit(result_5[7:0], result_4[8], 1'b0, 1'b0);
            sum16_12 = add_carry_8bit(result_6[7:0], result_5[8], 1'b0, 1'b0);
            sum16_13 = add_carry_8bit(result_7[7:0], result_6[8], 1'b0, 1'b0);
 
            next_accum_0 =  {sum16_8[7:0], result_0[7:0]};
            next_accum_1 =  {sum16_10[7:0], sum16_9[7:0]};
            next_accum_2 =  {sum16_11[7:0], result_4[7:0]};
            next_accum_3 =  {sum16_13[7:0], sum16_12[7:0]};
                      
            next_state = IDLE ;            
        end

        PP1_32: begin 

            PP32_1A = mult_out_1[7:0];      PP32_1B = mult_out_1[15:8];
            PP32_2A = mult_out_2[7:0];      PP32_2B = mult_out_2[15:8];
            PP32_3A = mult_out_3[7:0];      PP32_3B = mult_out_3[15:8];
            PP32_4A = mult_out_4[7:0];      PP32_4B = mult_out_4[15:8];
            PP32_5A = mult_out_5[7:0];      PP32_5B = mult_out_5[15:8];
            PP32_6A = mult_out_6[7:0];      PP32_6B = mult_out_6[15:8];
            PP32_7A = mult_out_7[7:0];      PP32_7B = mult_out_7[15:8];
            PP32_8A = mult_out_8[7:0];      PP32_8B = mult_out_8[15:8];
                      
            sum32_0 = {8'b0, PP32_1A};
            sum32_1 = csa_3to2(PP32_1B , PP32_2A , PP32_5A);
            sum32_2 = csa_3to2(PP32_2B , PP32_3A , PP32_5B);
            sum32_3 = csa_3to2(PP32_3B , PP32_4A , PP32_6B);
            sum32_4 = csa_3to2(PP32_4B , PP32_7B , PP32_8A);
            sum32_5 = {8'b0, PP32_8B};

            // Add sum + carry (9-bit results for overflow handling)
            result_0 = add_sum_carry(sum32_0[7:0],  sum32_0[15:8]);
            result_1 = add_sum_carry(sum32_1[7:0],  sum32_1[15:8]);
            result_2 = add_sum_carry(sum32_2[7:0],  sum32_2[15:8]);
            result_3 = add_sum_carry(sum32_3[7:0],  sum32_3[15:8]);
            result_4 = add_sum_carry(sum32_4[7:0],  sum32_4[15:8]);
            result_5 = add_sum_carry(sum32_5[7:0],  sum32_5[15:8]);

            sum32_6 = half_adder(PP32_6A , result_2[7:0]);
            sum32_7 = half_adder(PP32_7A , result_3[7:0]);

            result_6 = add_sum_carry(sum32_6[7:0],  sum32_6[15:8]);
            result_7 = add_sum_carry(sum32_7[7:0],  sum32_7[15:8]);

            sum32_8  = add_carry_8bit(result_1[7:0], result_0[8], 1'b0, 1'b0);
            sum32_9  = add_carry_8bit(result_6[7:0], result_1[8], 1'b0, 1'b0);
            sum32_10 = add_carry_8bit(result_7[7:0], result_6[8], result_2[8], 1'b0);
            sum32_11 = add_carry_8bit(result_4[7:0], result_7[8], result_3[8], 1'b0);
            sum32_12 = add_carry_8bit(result_5[7:0], sum32_11[8], result_4[8], 1'b0);

            next_accum_0 =  {sum32_8[7:0], result_0[7:0]};
            next_accum_1 =  {sum32_10[7:0], sum32_9[7:0]};
            next_accum_2 =  {sum32_12[7:0], sum32_11[7:0]};
            next_accum_3 =  {15'b0        , sum32_12[8]};

            next_state = PP2_32;

        end 

        PP2_32: begin

            PP32_9A = mult_out_1[7:0];       PP32_9B = mult_out_1[15:8];
            PP32_10A = mult_out_2[7:0];      PP32_10B = mult_out_2[15:8];
            PP32_11A = mult_out_3[7:0];      PP32_11B = mult_out_3[15:8];
            PP32_12A = mult_out_4[7:0];      PP32_12B = mult_out_4[15:8];
            PP32_13A = mult_out_5[7:0];      PP32_13B = mult_out_5[15:8];
            PP32_14A = mult_out_6[7:0];      PP32_14B = mult_out_6[15:8];
            PP32_15A = mult_out_7[7:0];      PP32_15B = mult_out_7[15:8];
            PP32_16A = mult_out_8[7:0];      PP32_16B = mult_out_8[15:8];

            sum32_0 = half_adder(PP32_9A, accum_1[7:0]);
            sum32_1 = csa_3to2(PP32_9B , PP32_10A , PP32_13A);
            sum32_2 = csa_3to2(PP32_10B , PP32_11A , PP32_13B);
            sum32_3 = csa_3to2(PP32_11B , PP32_12A , PP32_14B);
            sum32_4 = csa_3to2(PP32_12B , PP32_15B , PP32_16A);
            sum32_5 = {8'b0, PP32_16B};

            result_0 = add_sum_carry(sum32_0[7:0],  sum32_0[15:8]);
            result_1 = add_sum_carry(sum32_1[7:0],  sum32_1[15:8]);
            result_2 = add_sum_carry(sum32_2[7:0],  sum32_2[15:8]);
            result_3 = add_sum_carry(sum32_3[7:0],  sum32_3[15:8]);
            result_4 = add_sum_carry(sum32_4[7:0],  sum32_4[15:8]);
            result_5 = add_sum_carry(sum32_5[7:0],  sum32_5[15:8]);

            sum32_6 = csa_3to2(result_2[7:0], PP32_14A , accum_2[7:0]);
            sum32_7 = half_adder(result_1[7:0], accum_1[15:8]);
            sum32_8 = csa_3to2(PP32_15A, result_3[7:0], accum_2[15:8]);

            result_6 = add_sum_carry(sum32_6[7:0],  sum32_6[15:8]);
            result_7 = add_sum_carry(sum32_7[7:0],  sum32_7[15:8]);
            result_8 = add_sum_carry(sum32_8[7:0],  sum32_8[15:8]);

            sum32_8  = add_carry_8bit (result_7[7:0], result_0[8], 1'b0, 1'b0);
            sum32_9  = add_carry_8bit (result_6[7:0], result_7[8], result_1[8], 1'b0);
            sum32_10 = add_carry_8bit (result_8[7:0], result_6[8], result_2[8], sum32_9[8]);
            sum32_11 = add_carry_8bit (result_4[7:0], result_8[8], result_3[8], sum32_10[8]);
            sum32_12 = add_carry_8bit (result_5[7:0], result_4[8], sum32_11[8], 1'b0);

            next_accum_0 = accum_0;
            next_accum_1 = {sum32_8[7:0], result_0[7:0]};
            next_accum_2 = {sum32_10[7:0],sum32_9[7:0]};
            next_accum_3 = {sum32_12[7:0], sum32_11[7:0]};

            next_state = IDLE ;

        end 
    endcase
end
    always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
        accum_0 <= 0;
        accum_1 <= 0;
        accum_2 <= 0;
        accum_3 <= 0;
        accum_4 <= 0;
        accum_5 <= 0;
        accum_6 <= 0;
        accum_7 <= 0;
        state   <= IDLE;
    end else begin
        accum_0 <= next_accum_0;
        accum_1 <= next_accum_1;
        accum_2 <= next_accum_2;
        accum_3 <= next_accum_3;
        accum_4 <= next_accum_4;
        accum_5 <= next_accum_5;
        accum_6 <= next_accum_6;
        accum_7 <= next_accum_7;
        state   <= next_state;
    end
end

// Final product outputs
assign product_1 =  {accum_1, accum_0} ;
assign product_2 =  {accum_3, accum_2} ;
assign product_3 =  {accum_5, accum_4} ;
assign product_4 =  {accum_7, accum_6} ;

endmodule             