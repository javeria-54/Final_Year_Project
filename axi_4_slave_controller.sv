// Author       : Zawaher Bin Asim , UET Lahore  <zawaherbinasim.333@gmail.com>
// Date         : 7 April 2025
// Description  : This file contain the slave controller for the axi 4 that is used in the Slave side (memory) to complete the axi4 protocol  

import axi_4_pkg::*;

module axi_4_slave_controller (
    
    input   logic       clk,
    input   logic       reset,

    // vector_processor vlsu  --> axi_4_slave_controller
    input   logic       ld_req,                     // signal for the load request
    input   logic       st_req,                     // signal for the store request
    
    // SLave (memory) --> axi_4_slave_controller
    input   logic       data_fetched,               // tells that data is loaded from memory
    input   logic       data_stored,                // tells that data is stored in memory
    input   logic       s_rlast,                    // tells about the last transaction in the burst
    input   logic       wlast_done,                    // tells about last store data in the burst

    // axi_4_slave_controller --> SLave (memory)
    output  logic       incre_counter,
    output  logic       store_data,

    //===================== axi_4 read address channel signals =========================//
 
    // axi_4_slave_controller --> axi_4_master_controller 
    output  logic       s_arready,                    // tells that slave(memory) is ready to take address for the read

    // axi_4_conntroller --> axi_4_slave_controller 
    input   logic       m_arvalid,                    // tells that address coming from master for the read is valid
    
    //===================== axi_4 read data channel signals =========================//
    
    // axi_4_slave_controller --> axi_4_master_controller
    output  logic       s_rvalid,                     // tells that loaded data and response coming from the slave(memory) is valid
    
    // axi_4_conntroller --> axi_4_slave_controller
    input   logic       m_rready,                     // tells that master(vlsu) is ready to take the valid loaded data response from the slave(memory)

    //===================== axi_4 write address channel signals =========================//
 
    // axi_4_slave_controller --> axi_4_master_controller 
    output  logic       s_awready,                    // tells that slave(memory) is ready to take address for the write

    // axi_4_conntroller --> axi_4_slave_controller 
    input   logic       m_awvalid,                    // tells that address coming from master for the write is valid

    //===================== axi_4 write data channel signals =========================//
 
    // axi_4_slave_controller --> axi_4_master_controller 
    output  logic       s_wready,                     // tells that slave(memory) is ready to take data for the write

    // axi_4_conntroller --> axi_4_slave_controller 
    input   logic       m_wvalid,                     // tells that data coming from master for the write is valid


    //===================== axi_4 write response channel signals =========================//
    
    // axi_4_slave_controller --> axi_4_master_controller
    output  logic       s_bvalid,                     // tells that response coming from the slave(memory) is valid
    
    // axi_4_conntroller --> axi_4_slave_controller
    input   logic       m_bready                      // tells that master(vlsu) is ready to take the valid response from the slave(memory)

);

axi_4_slave_states_e  c_state,n_state;

always_ff @( posedge clk or negedge reset) begin 
    if (!reset)begin
        c_state <= SLAVE_IDLE;
    end
    else begin
        c_state <= n_state; 
    end
end

// NEXT STATE BLOCK
always_comb begin 
    case (c_state)
        SLAVE_IDLE     : begin
            if (ld_req )begin
                if (m_arvalid)  n_state = DATA_FETCH;
                else            n_state = WAIT_ARVALID;
            end
            else begin
                if (st_req)begin
                    if      (m_awvalid && m_wvalid)     n_state = DATA_STORE;
                    else if (!m_awvalid && !m_wvalid)   n_state = WAIT_AWVALID_WVALID;
                    else if (!m_awvalid && m_wvalid)    n_state = WAIT_AWVALID;
                    else if (m_awvalid && !m_wvalid)    n_state = WAIT_WVALID;
                end
                else n_state = SLAVE_IDLE;
            end
        end

        WAIT_ARVALID : begin
            if (m_arvalid)  n_state = DATA_FETCH;
            else            n_state = WAIT_ARVALID;
        end

        DATA_FETCH : begin
            if (data_fetched) begin
                if (m_rready) begin
                    if (s_rlast) begin
                        n_state = SLAVE_IDLE;
                    end
                    else n_state = DATA_FETCH;
                end
                else     n_state = WAIT_RREADY;
            end
            else         n_state = DATA_FETCH;
        end

        WAIT_RREADY : begin
            if (m_rready)begin
                if (s_rlast)    n_state = SLAVE_IDLE;
                else            n_state = DATA_FETCH; 
            end       
            else                n_state = WAIT_RREADY;
        end

        WAIT_AWVALID_WVALID : begin
            if (m_awvalid)      n_state = WAIT_WVALID;
            else if (m_wvalid)  n_state = WAIT_AWVALID;
            else                n_state = WAIT_AWVALID_WVALID;
        end

        WAIT_AWVALID : begin
            if (m_awvalid)  n_state = DATA_STORE;
            else            n_state = WAIT_AWVALID;
        end

        WAIT_WVALID : begin
            if (m_wvalid)   n_state = DATA_STORE;
            else            n_state = WAIT_WVALID;
        end

        DATA_STORE : begin
            if (data_stored) begin
                if (wlast_done) begin
                    if (m_bready)   n_state = SLAVE_IDLE;
                    else            n_state = WAIT_BREADY;
                end
                else begin
                    if (m_wvalid) begin
                       n_state = DATA_STORE;
                    end
                    else begin
                        n_state = WAIT_WVALID;
                    end
                end 
            end
            else    n_state = DATA_STORE;
        end

        WAIT_BREADY : begin
            if (m_bready)   n_state =  SLAVE_IDLE;
            else            n_state = WAIT_BREADY;
        end

        default : n_state = SLAVE_IDLE;
    endcase
end

// Output BLock 
always_comb begin
    s_arready       = 0;
    s_rvalid        = 0;
    s_awready       = 0;
    s_wready        = 0;
    s_bvalid        = 0;
    incre_counter   = 0;
    store_data      = 0;

    case (c_state)
        SLAVE_IDLE    : begin
            store_data = 0;
            if (ld_req) begin
                s_arready = 1;
                s_rvalid  = 0;
            end
            else begin
                if (st_req) begin
                    s_awready = 1;
                    s_wready  = 1;
                    s_bvalid  = 0;
                end
                else begin
                    s_arready       = 1;
                    s_rvalid        = 0;
                    s_awready       = 1;
                    s_wready        = 1;
                    s_bvalid        = 0;
                    incre_counter   = 0;
                end
            end            
        end

        WAIT_ARVALID : begin
            s_arready = 1;
        end

        DATA_FETCH : begin
            if (data_fetched) begin
                if (m_rready)begin
                    if (s_rlast)begin
                        s_rvalid = 1;
                    end
                    else begin
                        s_rvalid = 1;
                        incre_counter = 1;
                    end
                end
                else begin    
                    s_rvalid = 1;
                    incre_counter = 0;
                end
            end
            else begin 
                s_rvalid = 0;
                incre_counter = 0;
            end
        end

        WAIT_RREADY : begin
            if (m_rready) begin
                if (s_rlast) begin
                    s_rvalid = 1;
                    incre_counter = 0;
                end
                else begin
                    s_rvalid = 1;
                    incre_counter = 1;
                end
            end
            else begin
                s_rvalid = 1;
                incre_counter = 0;
            end
        end

        WAIT_AWVALID_WVALID : begin
           s_awready = 1;
           s_wready  = 1; 
        end

        WAIT_AWVALID : begin
            s_awready = 1;
        end

        WAIT_WVALID : begin
            store_data = 0;
            s_wready = 1;
        end

        DATA_STORE : begin
            if (data_stored) begin
                if (wlast_done) begin
                    s_bvalid = 1;
                    incre_counter = 0;
                    store_data    = 0;
                end
                else begin
                    s_wready = 1;
                    incre_counter = 1;
                    store_data   = 0;
                end
            end
            else begin
                incre_counter = 0;
                store_data = 1;
            end
        end

        WAIT_BREADY : begin
            s_bvalid = 1;
        end

        default: begin
            s_arready       = 0;
            s_rvalid        = 0;
            s_awready       = 0;
            s_wready        = 0;
            s_bvalid        = 0;
            incre_counter   = 0;
            store_data      = 0;
        end
    endcase
end


endmodule

