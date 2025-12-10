module accumulator_8 (
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
logic   signed [16:0] sum1_16, sum2_16, sum3_16, sum4_16, sum5_16, sum6_16, sum7_16, sum8_16, sum9_16, sum10_16, 
             sum11_16, sum12_16;      // 18-bit sums (for 16-bit mode)
logic   signed [16:0] sum32_0, sum32_1, sum32_2, sum32_3, sum32_4, sum32_5, sum32_6, sum32_7, sum32_8, sum32_9, 
             sum32_10, sum32_11, sum32_12 ; // 17-bit sums (for 32-bit mode)
logic   signed [15:0] accum_0, accum_1, accum_2, accum_3;
logic   signed [15:0] accum_4, accum_5, accum_6, accum_7;
logic   signed [15:0] next_accum_0, next_accum_1, next_accum_2, next_accum_3 ;
logic   signed [15:0] next_accum_4, next_accum_5, next_accum_6, next_accum_7 ;
logic   signed [15:0] mult_out_6_shift, mult_out_5_shift, mult_out_7_shift, mult_out_8_shift,
             mult_out_shift_1, mult_out_shift_2, mult_out_shift_3, mult_out_shift_4; 

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

    sum1_16 = '0; 
    sum2_16 = '0; 
    sum3_16 = '0; 
    sum4_16 = '0; 
    sum5_16 = '0; 
    sum6_16 = '0;
    sum7_16 = '0; 
    sum8_16 = '0;
    sum9_16 = '0;
    sum10_16 = '0;
    sum11_16 = '0;
    sum12_16 = '0;

    sum32_0 = '0;
    sum32_1 = '0;
    sum32_2 = '0;
    sum32_3 = '0;
    sum32_4 = '0;
    sum32_5 = '0;
    sum32_6 = '0;
    sum32_7 = '0;
    sum32_8 = '0;
    sum32_9 = '0;
    sum32_10 = '0;
    sum32_11 = '0;
    sum32_12 = '0;

    mult_out_shift_1 = '0;
    mult_out_shift_2 = '0;
    mult_out_shift_3 = '0;
    mult_out_shift_4 = '0;

    mult_out_5_shift = '0;
    mult_out_6_shift = '0;
    mult_out_7_shift = '0;
    mult_out_8_shift = '0;

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
        end

        PP_16: begin            
            sum1_16 = mult_out_1[15:0];
            next_accum_0 = sum1_16[15:0];

            mult_out_6_shift = mult_out_6 << 8;
            sum2_16 = sum1_16 [16] + next_accum_0 + mult_out_6_shift ;
            next_accum_0 = sum2_16 [15:0];

            sum3_16 = sum2_16 [16] + mult_out_6 [15:8];
            next_accum_1 = sum3_16[15:0];

            mult_out_5_shift = mult_out_5 << 8;
            sum4_16 = sum3_16 [16] + next_accum_0 + mult_out_5_shift;
            next_accum_0 = sum4_16[15:0];

            sum5_16 = sum4_16 [16] + mult_out_5 [15:8] + next_accum_1;
            next_accum_1 = sum5_16[15:0]; 

            sum6_16 = sum5_16 [16] + next_accum_1 + mult_out_2[15:0];
            next_accum_1 = sum6_16[15:0]; 

            sum7_16 = mult_out_3[15:0];
            next_accum_2 = sum7_16[15:0];

            mult_out_8_shift = mult_out_8 << 8;
            sum8_16 = sum7_16[16] + next_accum_2 + mult_out_8_shift ;
            next_accum_2 = sum8_16[15:0];

            sum9_16 = sum8_16 [16] + mult_out_8 [15:8];
            next_accum_3 = sum9_16[15:0];

            mult_out_7_shift = mult_out_7 << 8;
            sum10_16 = sum9_16[16] + next_accum_2 + mult_out_7_shift;
            next_accum_2 = sum10_16[15:0];

            sum11_16 = sum10_16 [16] + mult_out_7 [15:8] + next_accum_3;
            next_accum_3 = sum11_16[15:0];

            sum12_16 = sum11_16 [16] + next_accum_3 + mult_out_4[15:0]; 
            next_accum_3 = sum12_16 [15:0];

            next_state = IDLE ;            
        end

        PP1_32: begin 

            sum32_0 = mult_out_1;  // PP1A + PP1B
            
            mult_out_shift_1 = mult_out_2 << 8; 
            sum32_1 = sum32_0[15:0] + mult_out_shift_1; // PP2A           
            sum32_2 = mult_out_2[15:8] + sum32_1[16] ;   // PP2B 

            sum32_3 = sum32_2[15:0] + mult_out_3 ;  // PP3A + PP3B
                       
            mult_out_shift_2 = mult_out_4 << 8;
            sum32_4 = sum32_3[15:0] + mult_out_shift_2; // PP4A
            sum32_5 = mult_out_4[15:8] + sum32_4[16] + sum32_3[16] ;  // PP4B          
            
            mult_out_shift_3 = mult_out_5 << 8;
            sum32_6 = sum32_1[15:0] + mult_out_shift_3; // PP5A
            sum32_7 = sum32_4[15:0] + mult_out_5[15:8] + sum32_6[16];  // PP5B          
            
            sum32_8 = sum32_7[15:0] + mult_out_6  ; // PP6A + PP6B            
            
            mult_out_shift_4 = mult_out_7 << 8;
            sum32_9 = sum32_8[15:0] + mult_out_shift_4 ; // PP7A 
            sum32_10 = sum32_5[15:0] + mult_out_7[15:8] + sum32_9[16] + sum32_8[16];  // PP7B          
           
            sum32_11 = sum32_10[15:0] + mult_out_8 ; // PP8A + PP8B

            next_accum_0 = sum32_6[15:0];
            next_accum_1 = sum32_9[15:0];
            next_accum_2 = sum32_11[15:0];
            next_accum_3 = sum32_11[16];          

            next_state = PP2_32;

        end 

        PP2_32: begin

            sum32_0 = accum_1 + mult_out_1 ;  // PP9A + PP9B
                       
            mult_out_shift_1 = mult_out_2 << 8;
            sum32_1 = sum32_0[15:0] + mult_out_shift_1 ; // PP10A
            sum32_2 = accum_2 + mult_out_2[15:8] + sum32_1[16] + sum32_0[16] ;  // PP10B          
            
            sum32_3 = sum32_2[15:0] + mult_out_3; //PP11A + PP11B

            mult_out_shift_2 = mult_out_4 << 8;
            sum32_4 = sum32_3[15:0] + mult_out_shift_2; // PP12A
            sum32_5 = accum_3 + mult_out_4[15:8] + sum32_4[16] +sum32_3[16];  // PP12B                      
            
            mult_out_shift_3 = mult_out_5 << 8;
            sum32_6 = sum32_1[15:0] + mult_out_shift_3 ; // PP13A 
            sum32_7 = sum32_4[15:0] + mult_out_5[15:8] + sum32_6[16];  // PP13B            
           
            sum32_8 = sum32_7[15:0] + mult_out_6; // PP14A + PP14B 

            mult_out_shift_4 = mult_out_7 << 8;
            sum32_9 = sum32_8[15:0] + mult_out_shift_4 ; // PP15A 
            sum32_10 = sum32_5[15:0] + mult_out_7[15:8] + sum32_9[16] + sum32_8[16];  // PP15B          
           
            sum32_11 = sum32_10[15:0] + mult_out_8; // PP16A + PP16B

            sum32_12 = accum_0 ;
            
            next_accum_0 = sum32_12[15:0];
            next_accum_1 = sum32_6[15:0];
            next_accum_2 = sum32_9[15:0];
            next_accum_3 = sum32_11[15:0];

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