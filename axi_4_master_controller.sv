// Author       : Zawaher Bin Asim , UET Lahore  <zawaherbinasim.333@gmail.com>
// Date         : 7 April 2025
// Description  : This file contain the controller for the axi 4 master side (vlsu) that is used for the throughput/pushback control between the memory and vlsu  

import axi_4_pkg::*;

module axi_4_master_controller (
    
    input   logic       clk,
    input   logic       reset,

    // vector_processor vlsu  --> axi_4_master_controller
    input   logic       ld_req,                     // signal for the load request
    input   logic       st_req,                     // signal for the store request
    
    // AXI 4 MASTER --> axi_4_master_controller
    input   logic       m_wlast,
    input   logic       s_rlast,

    // axi_4_master_controller --> AXI  4 MASTER
    output  logic       incre_data_counter,
   
    //===================== axi_4 read address channel signals =========================//
 
    // axi_4_slave_controller --> axi_4_master_controller 
    input   logic       s_arready,                    // tells that slave(memory) is ready to take address for the read

    // axi_4_master_controller --> axi_4_slave_controller 
    output  logic       m_arvalid,                    // tells that address coming from master for the read is valid
    
    //===================== axi_4 read data channel signals =========================//
    
    // axi_4_slave_controller --> axi_4_master_controller
    input   logic       s_rvalid,                     // tells that loaded data and response coming from the slave(memory) is valid
    
    // axi_4_master_controller --> axi_4_slave_controller
    output  logic       m_rready,                     // tells that master(vlsu) is ready to take the valid loaded data response from the slave(memory)

    //===================== axi_4 write address channel signals =========================//
 
    // axi_4_slave_controller --> axi_4_master_controller 
    input   logic       s_awready,                    // tells that slave(memory) is ready to take address for the write

    // axi_4_master_controller --> axi_4_slave_controller 
    output  logic       m_awvalid,                    // tells that address coming from master for the write is valid

    //===================== axi_4 write data channel signals =========================//
 
    // axi_4_slave_controller --> axi_4_master_controller 
    input   logic       s_wready,                     // tells that slave(memory) is ready to take data for the write

    // axi_4_master_controller --> axi_4_slave_controller 
    output  logic       m_wvalid,                     // tells that data coming from master for the write is valid


    //===================== axi_4 write response channel signals =========================//
    
    // axi_4_slave_controller --> axi_4_master_controller
    input   logic       s_bvalid,                     // tells that response coming from the slave(memory) is valid
    
    // axi_4_master_controller --> axi_4_slave_controller
    output  logic       m_bready                      // tells that master(vlsu) is ready to take the valid response from the slave(memory)

);

axi_4_master_states_e  c_state,n_state;

always_ff @( posedge clk or negedge reset) begin 
    if (!reset)begin
        c_state <= MASTER_IDLE;
    end
    else begin
        c_state <= n_state; 
    end
end


// Next State  Logic Block

always_comb begin

    n_state = c_state;

    case (c_state)
        MASTER_IDLE: begin
            if (ld_req) begin
                if (s_arready)            n_state = WAIT_RVALID;
                else                      n_state = WAIT_ARREADY;
            end
            else if (st_req) begin
                if      (s_awready && s_wready && m_wlast)  n_state = WAIT_BVALID;
                else if (s_awready && s_wready && !m_wlast) n_state = WAIT_WLAST;
                else if (s_awready && !s_wready)            n_state = WAIT_WREADY;
                else if (s_wready  && !s_awready)           n_state = WAIT_AWREADY;
                else                                        n_state = WAIT_AWREADY_WREADY;
            end
            else begin
                n_state = MASTER_IDLE;
            end
        end

        WAIT_ARREADY  :   begin
            if (s_arready)  n_state = WAIT_RVALID;
            else            n_state = WAIT_ARREADY;
        end

        WAIT_RVALID : begin
            if (s_rvalid) begin
                if (s_rlast) n_state = MASTER_IDLE;
                else         n_state = WAIT_RVALID;
            end 
            else             n_state = WAIT_RVALID;
        end

        WAIT_AWREADY_WREADY : begin
            if      (!s_awready && !s_wready)            n_state = WAIT_AWREADY_WREADY;
            else if (!s_awready && s_wready )            n_state = WAIT_AWREADY;
            else if (s_awready && !s_wready )            n_state = WAIT_WREADY;
            else if (s_awready && s_wready && m_wlast)   n_state = WAIT_BVALID;
            else if (s_awready && s_wready && !m_wlast)  n_state = WAIT_WLAST;
        end

        WAIT_AWREADY : begin
            if (s_awready) begin
                if (m_wlast) n_state = WAIT_BVALID;
                else           n_state = WAIT_WLAST;
            end 
            else               n_state = WAIT_AWREADY; 
        end

        WAIT_WREADY : begin
            if (s_wready) begin
                if (m_wlast)   n_state = WAIT_BVALID;
                else           n_state = WAIT_WLAST;
            end
            else            n_state = WAIT_WREADY; 
        end

        WAIT_WLAST : begin
            if (s_wready) begin
                if (m_wlast) n_state = WAIT_BVALID;
                else         n_state = WAIT_WLAST;
            end
            else             n_state = WAIT_WLAST; 
        end
        WAIT_BVALID : begin
            if (s_bvalid)   n_state = MASTER_IDLE;
            else            n_state = WAIT_BVALID;
        end

        default: n_state = MASTER_IDLE; 
    endcase    
end

// Next State Output Logic Block

always_comb begin 
    
    m_arvalid          = 1'b0;
    m_rready           = 1'b0;
    m_awvalid          = 1'b0;
    m_wvalid           = 1'b0;
    m_bready           = 1'b0;
    incre_data_counter = 1'b0;
    case (c_state)
        MASTER_IDLE : begin
            if (ld_req)begin
                m_arvalid = 1'b1;
                m_rready  = 1'b1;
            end
            else if (st_req)begin
                if (s_awready && s_wready && !m_wlast)begin
                    m_awvalid           = 1'b1;
                    m_wvalid            = 1'b1;
                    m_bready            = 1'b1;
                    incre_data_counter  = 1'b1;   
                end
                else begin
                    m_awvalid           = 1'b1;
                    m_wvalid            = 1'b1;
                    m_bready            = 1'b1;
                    incre_data_counter  = 1'b0;
                end
            end
            else begin
                m_arvalid           = 1'b0;
                m_rready            = 1'b0;
                m_awvalid           = 1'b0;
                m_wvalid            = 1'b0;
                m_bready            = 1'b0;
                incre_data_counter  = 1'b0;
            end
        end

        WAIT_ARREADY  :   begin
           m_arvalid  = 1'b1;
           m_rready   = 1'b1;
        end

        WAIT_RVALID : begin
            m_rready = 1;
        end

        WAIT_AWREADY_WREADY : begin
            if (s_awready && s_wready && !m_wlast) begin
                m_awvalid           = 1'b1;
                m_wvalid            = 1'b1;
                m_bready            = 1'b1;
                incre_data_counter  = 1'b1;    
            end
            else begin
                m_awvalid = 1'b1;
                m_wvalid  = 1'b1;
                m_bready  = 1'b1;       
            end
        end

        WAIT_AWREADY : begin
            if (s_awready && !m_wlast)begin
                m_awvalid           = 1'b1;
                m_bready            = 1'b1;
                incre_data_counter  = 1'b1;     
            end
            else begin
                m_awvalid = 1'b1;
                m_bready  = 1'b1;  
            end
        end

        WAIT_WREADY : begin
            if (s_wready && !m_wlast) begin
                m_wvalid            = 1'b1;
                m_bready            = 1'b1;
                incre_data_counter  = 1'b1;    
            end
            else begin
                m_wvalid  = 1'b1;
                m_bready  = 1'b1;       
            end
        end

        WAIT_WLAST : begin
            if (s_wready && !m_wlast) begin
                m_wvalid            = 1'b1;
                m_bready            = 1'b1;
                incre_data_counter  = 1'b1;    
            end
            else begin
                m_wvalid  = 1'b1;
                m_bready  = 1'b1;       
            end
        end

        WAIT_BVALID : begin
            m_bready  = 1'b1;
        end

        default: begin
            m_arvalid           = 1'b0;
            m_rready            = 1'b0;
            m_awvalid           = 1'b0;
            m_wvalid            = 1'b0;
            m_bready            = 1'b0;
            incre_data_counter  = 1'b0;
        end
    endcase
    
end



endmodule

