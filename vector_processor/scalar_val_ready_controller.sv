module single_cycle_val_ready_controller (
    
    input   logic       clk,
    input   logic       reset,

    input   logic       is_vector,

    // scaler_procssor  --> val_ready_controller
    output  logic       inst_valid,        // tells data comming from the scalar processor is valid
    input   logic       vec_pro_ack,       // tells that scaler processor is ready to take output
    
    // val_ready_controller --> scaler_processor
    output  logic       scalar_pro_ready,          // tells that vector processor is ready to take the instruction
    output  logic       scalar_pro_ack            // tells that the data comming from the vec_procssor is valid and done with the implementation of instruction 

    // datapath -->   val_ready_controller 
    //input   logic       vec_pro_ready
);

typedef enum logic [1:0]{  
    IDLE,
    PROCESS,
    WAIT_READY
} val_read_states_e;

val_read_states_e  c_state,n_state;

always_ff @( posedge clk or negedge reset) begin 
    if (!reset)begin
        c_state <= IDLE;
    end
    else begin
        c_state <= n_state; 
    end
end


// Next State  Logic Block

always_comb begin

    n_state = IDLE;

    case (c_state)
      IDLE  :   begin
            if (is_vector)      n_state = PROCESS;
            else                n_state = IDLE;
      end
      PROCESS  :   begin
                if (vec_pro_ack) begin
                    n_state = WAIT_READY;
                end
                else n_state = PROCESS;
            end   
      WAIT_READY : begin
               n_state = IDLE;
        end    
        default: n_state = IDLE; 
    endcase    
end

// Next State Output Logic Block

always_comb begin 
    
    scalar_pro_ready = 1'b1;
    scalar_pro_ack   = 1'b0;
    inst_valid = 1'b0;

    case (c_state)
       IDLE : begin
            scalar_pro_ready = 1'b0;
            scalar_pro_ack   = 1'b0;
            inst_valid = 1'b0;
        end

        PROCESS : begin
            inst_valid = 1'b1;
            if (vec_pro_ack)begin
                scalar_pro_ready = 1'b1;
                scalar_pro_ack = 1'b0;  
            end
            else begin
                scalar_pro_ready  = 1'b0;    
            end
        end 

        WAIT_READY : begin
            inst_valid = 1'b1;
            scalar_pro_ack = 1'b1;
            scalar_pro_ready = 1'b0;
        end

        default: begin
            scalar_pro_ready = 1'b0;
            scalar_pro_ack   = 1'b0;
            inst_valid = 1'b0;
        end
    endcase
    
end

endmodule