
module val_ready_controller (
    
    input   logic       clk,
    input   logic       reset,

    // scaler_procssor  --> val_ready_controller
    input   logic       inst_valid,             // tells data comming from the saler processor is valid
    input   logic       scalar_pro_ready,       // tells that scaler processor is ready to take output
    
    // val_ready_controller --> scaler_processor
    output  logic       vec_pro_ready,          // tells that vector processor is ready to take the instruction
    output  logic       vec_pro_ack,             // tells that the data comming from the vec_procssor is valid and done with the implementation of instruction 

    // datapath -->   val_ready_controller 
    input   logic       inst_done
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
            if (inst_valid)     n_state = PROCESS;
            else                n_state = IDLE;
      end
      PROCESS  :   begin
            if (inst_done) begin
                if (scalar_pro_ready) begin
                    n_state = IDLE;
                end
                else n_state = WAIT_READY;
            end   
            else     n_state = PROCESS;
      end
      WAIT_READY : begin
            if (scalar_pro_ready)   n_state = IDLE;
            else                    n_state = WAIT_READY;
        end    
        default: n_state = IDLE; 
    endcase    
end

// Next State Output Logic Block

always_comb begin 
    
    vec_pro_ready = 1'b1;
    vec_pro_ack   = 1'b0;

    case (c_state)
       IDLE : begin
            vec_pro_ready = 1'b1;
            vec_pro_ack   = 1'b0;
        end

        PROCESS : begin
            
            vec_pro_ready = 1'b0;

            if (inst_done)begin
                vec_pro_ack = 1'b1;
            end
            else begin
                vec_pro_ack     = 1'b0;    
            end
        end 

        WAIT_READY : begin
            vec_pro_ack = 1'b1;
            vec_pro_ready = 1'b0;
        end

        default: begin
            vec_pro_ready = 1'b1;
            vec_pro_ack   = 1'b0;
        end
    endcase
    
end



endmodule