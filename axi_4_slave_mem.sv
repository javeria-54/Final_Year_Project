// Author       : Zawaher Bin Asim , UET Lahore  <zawaherbinasim.333@gmail.com>
// Date         : 7 April 2025
// Description  : This file contain the axi4 slave  and the decoder that decodes the controls signls 
//                send by the read write  and gentertes the address based on the information described
//                by the channels control signals and generates the read write response.    

`include "axi_4_defs.svh"

import axi_4_pkg::*;

module axi4_slave_mem(

    input   logic       clk,
    input   logic       reset,

    // vector_processor vlsu  --> axi_4_controller
    input   logic       ld_req,                     // signal for the load request
    input   logic       st_req,                     // signal for the store request
    
    //===================== axi_4 read address channel signals =========================//
 
    // slave(memory) --> axi_4_controller 
    output  logic       s_arready,                    // tells that slave(memory) is ready to take address for the read

    // axi_4_conntroller --> slave(memory) 
    input   logic       m_arvalid,                    // tells that address coming from master for the read is valid
    
    //===================== axi_4 read data channel signals =========================//
    
    // slave(memory) --> axi_4_controller
    output  logic       s_rvalid,                     // tells that loaded data and response coming from the slave(memory) is valid
    
    // axi_4_conntroller --> slave(memory)
    input   logic       m_rready,                     // tells that master(vlsu) is ready to take the valid loaded data response from the slave(memory)

    //===================== axi_4 write address channel signals =========================//
 
    // slave(memory) --> axi_4_controller 
    output  logic       s_awready,                    // tells that slave(memory) is ready to take address for the write

    // axi_4_conntroller --> slave(memory) 
    input   logic       m_awvalid,                    // tells that address coming from master for the write is valid

    //===================== axi_4 write data channel signals =========================//
 
    // slave(memory) --> axi_4_controller 
    output  logic       s_wready,                     // tells that slave(memory) is ready to take data for the write

    // axi_4_conntroller --> slave(memory) 
    input   logic       m_wvalid,                     // tells that data coming from master for the write is valid


    //===================== axi_4 write response channel signals =========================//
    
    // slave(memory) --> axi_4_controller
    output  logic       s_bvalid,                     // tells that response coming from the slave(memory) is valid
    
    // axi_4_conntroller --> slave(memory)
    input   logic       m_bready,                     // tells that master(vlsu) is ready to take the valid response from the slave(memory)


    // MASTER(VLSU) --> AXI4_SLAVE  

    input   wire read_write_address_channel_t  re_wr_addr_channel,
    input   wire write_data_channel_t          wr_data_channel,

    // SLAVE(MEMORY) --> AXI 4 MASTER (VLSU) 
    output  read_data_channel_t           re_data_channel,
    output  write_response_channel_t      wr_resp_channel
);

    // MEMORY DECLARATION 
    logic   [7:0] memory [`MEM_DEPTH-1:0];

    // AXI 4 SLAVE CONTROLLER SIGNALS
    logic                          data_fetched;
    logic                          data_stored;
    logic                          incre_counter;
    logic                          store_data;
    logic                          wlast_done;   // tells that last write done
    // AXI 4 Control Signals
    logic   [`XLEN-1:0]             read_addr_id;
    logic   [`XLEN-1:0]             write_addr_id;
    logic   [`XLEN-1:0]             write_data_id;
    logic   [`XLEN-1:0]             read_addr;
    logic   [`XLEN-1:0]             write_addr;
    logic   [`DATA_BUS_WIDTH-1:0]   wr_data;
    logic   [`STROBE_WIDTH-1:0]     write_strobe;
    logic                           wlast;
    logic   [7:0]                   burst_len;        // Burst Length . Number of burst transfers
    logic   [7:0]                   burst_size;       // Burst Size . Number of bytes to be transfered in each burst 
    logic   [1:0]                   burst_type;       // Burst type
    logic                           atomic_access;    // Atomic Access
    logic   [3:0]                   mem_type;         // memory type
    logic   [2:0]                   prot_type;        // Protection Type
    logic   [3:0]                   qos;              // Quality of Service

    // BURST CONTROL SIGNALS
    logic   [`XLEN-1:0]             current_addr;     // The current address that is to be assigned to read_mem_addr
    logic   [`XLEN-1:0]             wrap_boundary;    // Wrap boundry for the wrap burst type
    logic                           burst_active;     // Tells the burst is in progress or the memory read operation is in progress
    logic   [7:0]                   burst_counter;    // Counter to keep the check of the number of burst transfers
    logic                           addr_valid;       // Tells the address is in valid Range
    logic                           wr_id_mismatch;   // tells there is a mismatch in the awid and wid
    logic                           write_err;        // tells there occurr an error in writing

    //==========================================================================//
    //                    AXI-4 SLAVE CONTROLLER INSTANTIATION                  //
    //==========================================================================//

    axi_4_slave_controller AXI4_SLAVE_CONTR (

        //======================== Clock and Reset ============================//
        .clk            (clk),
        .reset          (reset),

        //================ Vector Processor <--> AXI Controller ==============//
        .ld_req         (ld_req),
        .st_req         (st_req),

        //==================== Memory <--> AXI Controller =====================//
        .data_fetched   (data_fetched),
        .data_stored    (data_stored),
        .s_rlast        (re_data_channel.rlast),
        .wlast_done     (wlast_done), 
        .incre_counter  (incre_counter),
        .store_data     (store_data),

        //=================== AXI-4 Read Address Channel ======================//
        .s_arready      (s_arready),
        .m_arvalid      (m_arvalid),

        //=================== AXI-4 Read Data Channel =========================//
        .s_rvalid       (s_rvalid),
        .m_rready       (m_rready),

        //================== AXI-4 Write Address Channel ======================//
        .s_awready      (s_awready),
        .m_awvalid      (m_awvalid),

        //=================== AXI-4 Write Data Channel ========================//
        .s_wready       (s_wready),
        .m_wvalid       (m_wvalid),

        //================== AXI-4 Write Response Channel =====================//
        .s_bvalid       (s_bvalid),
        .m_bready       (m_bready)
    );


    //==========================================================================//
    //                    AXI-4 CONTROL SIGNAL STORATION                        //
    //==========================================================================//

    always_ff @( posedge clk or negedge reset ) begin 
        if (!reset)begin
            read_addr_id    <= 0;
            write_addr_id   <= 0;
            write_data_id   <= 0;
            read_addr       <= 0;
            write_addr      <= 0;
            wr_data         <= 0;
            write_strobe    <= 0;
            wlast           <= 0;
            burst_len       <= 0; 
            burst_size      <= 0; 
            burst_type      <= 0;
            atomic_access   <= 0;
            mem_type        <= 0;
            prot_type       <= 0;
            qos             <= 0;      
        end
        else begin
            if (ld_req)begin
                if (m_arvalid && s_arready)begin
                    read_addr_id    <= re_wr_addr_channel.arid;
                    read_addr       <= re_wr_addr_channel.axaddr;
                    burst_len       <= re_wr_addr_channel.axlen + 1;
                    burst_size      <= (1 << re_wr_addr_channel.axsize);
                    burst_type      <= re_wr_addr_channel.axburst;
                    atomic_access   <= re_wr_addr_channel.axlock;
                    mem_type        <= re_wr_addr_channel.axcache;
                    prot_type       <= re_wr_addr_channel.axprot;
                    qos             <= re_wr_addr_channel.axqos;
                end
                else begin
                    read_addr_id    <= read_addr_id;
                    read_addr       <= read_addr;
                    burst_len       <= burst_len;
                    burst_size      <= burst_size;
                    burst_type      <= burst_type;
                    atomic_access   <= atomic_access;
                    mem_type        <= mem_type;
                    prot_type       <= prot_type;
                    qos             <= qos;
                end
            end
            else if (st_req)begin
                if (m_awvalid && s_awready)begin
                    write_addr_id   <= re_wr_addr_channel.awid;
                    write_addr      <= re_wr_addr_channel.axaddr;
                    burst_len       <= re_wr_addr_channel.axlen + 1;
                    burst_size      <= 1<<re_wr_addr_channel.axsize;
                    burst_type      <= re_wr_addr_channel.axburst;
                    atomic_access   <= re_wr_addr_channel.axlock;
                    mem_type        <= re_wr_addr_channel.axcache;
                    prot_type       <= re_wr_addr_channel.axprot;
                    qos             <= re_wr_addr_channel.axqos;
                end
                if (m_wvalid && s_wready)begin
                    write_data_id   <= wr_data_channel.wid;
                    wr_data         <= wr_data_channel.wdata;
                    write_strobe    <= wr_data_channel.wstrb;
                    wlast           <= wr_data_channel.wlast;
                end
                else begin
                    write_addr_id   <= write_addr_id;
                    write_addr      <= write_addr;
                    burst_len       <= burst_len;
                    burst_size      <= burst_size;
                    burst_type      <= burst_type;
                    atomic_access   <= atomic_access;
                    mem_type        <= mem_type;
                    prot_type       <= prot_type;
                    qos             <= qos;
                    write_data_id   <= write_data_id;
                    wr_data         <= wr_data;
                    write_strobe    <= write_strobe;
                    wlast           <= wlast;
                end
            end
        end
    end

    //==========================================================================//
    //               AXI-4 BURST READ AND WRITE ADDRESS GENERATION              //
    //==========================================================================//

    // Address validity check and write id check
    always_comb begin
        addr_valid = ((current_addr + burst_size ) < `MEM_DEPTH);
        wr_id_mismatch = (write_addr_id != write_data_id);
    end


    always_comb begin 
        if (burst_type == `BURST_WRAP)begin
            wrap_boundary   = (read_addr / (burst_size * burst_len)) * (burst_size * burst_len);
        end
        else begin
            wrap_boundary = 'h0;
        end
    end

    always_ff @(posedge clk or negedge reset) begin 
        if (!reset) begin
            burst_counter <= 0;
            current_addr  <= 0;
            burst_active  <= 0;
        end
        else begin
            // ========================= //
            //   Handle Load Requests    //
            // ========================= //
            if (ld_req) begin
                if ((m_arvalid && s_arready) && !burst_active) begin
                    burst_counter <= 0;
                    current_addr  <= re_wr_addr_channel.axaddr;
                    burst_active  <= 1;
                end 
                else if (burst_active) begin
                    if (!re_data_channel.rlast) begin
                        if (incre_counter ) begin
                            case (burst_type)
                                `BURST_FIXED: begin
                                    current_addr <= current_addr;
                                end
                                `BURST_INCR: begin
                                    current_addr    <= current_addr + burst_size;
                                end
                                `BURST_WRAP: begin
                                    if ((current_addr + burst_size) >= (wrap_boundary + (burst_size * burst_len))) begin
                                        current_addr <= wrap_boundary;
                                    end else begin
                                        current_addr <= current_addr + burst_size;
                                    end
                                end
                                default: current_addr <= 'h0;
                            endcase
                            burst_counter <= burst_counter + 1;
                        end
                        else begin
                            current_addr  <= current_addr;
                            burst_counter <= burst_counter;
                        end
                    end
                    // Burst Reaches its Length
                    else begin
                        burst_active  <= 0;
                        burst_counter <= 0;
                    end
                end
            end

            // ========================= //
            //   Handle Store Requests   //
            // ========================= //
            else if (st_req) begin
                if ((m_awvalid && s_awready) && !burst_active) begin
                    // Start of burst
                    burst_counter <= 0;
                    current_addr  <= re_wr_addr_channel.axaddr;
                    burst_active  <= 1;
                end 
                else if (burst_active) begin
                    if (!(wlast && burst_counter == 0)) begin
                        // Skip address generation if this is the only transaction (first is wlast)
                        if (incre_counter) begin
                            case (burst_type)
                                `BURST_FIXED: begin
                                    current_addr <= current_addr;
                                end
                                `BURST_INCR: begin
                                    current_addr <= current_addr + burst_size;
                                end
                                `BURST_WRAP: begin
                                    if ((current_addr + burst_size) >= (wrap_boundary + (burst_size * burst_len))) begin
                                        current_addr <= wrap_boundary;
                                    end else begin
                                        current_addr <= current_addr + burst_size;
                                    end
                                end
                                default: current_addr <= 'h0;
                            endcase
                            burst_counter <= burst_counter + 1;
                        end
                    end

                    // End the burst if last transfer
                    if (wlast_done) begin
                        burst_active  <= 0;
                        burst_counter <= 0;
                    end
                end
            end
        end
    end


    //==========================================================================//
    //                          AXI-4  READ DATA CHANNEL                        //
    //==========================================================================//

    // The channel will not change its value because the value of the burst counter
    // and the current address are the register value and will not be incremented  
    // if m_rready is not 1 
    // The burst active also depends upon the rlast signal so it will also maintain value
    always_comb begin
    
        re_data_channel.rid   = 0;
        re_data_channel.rlast = 0;
        re_data_channel.rdata = 0;
        re_data_channel.rresp = `RESP_OKAY;
        data_fetched          = 0;
        
        if (ld_req && burst_active )begin
            re_data_channel.rid   = read_addr_id;
            re_data_channel.rlast = (burst_counter == burst_len - 1);

            // Response CASE 
            case (addr_valid)
            1'b1 : begin
                    for (int i = 0; i < burst_size; i++) begin
                        re_data_channel.rdata[i*8 +: 8] = memory[current_addr + i];
                    end
                    re_data_channel.rresp = `RESP_OKAY;
            end 
            1'b0 : begin
                    re_data_channel.rdata = 0;
                    re_data_channel.rresp = `RESP_DECERR;
            end
            default : begin
                    re_data_channel.rdata = 0;
                    re_data_channel.rresp = `RESP_DECERR;
            end 
            endcase
            
            data_fetched          = 1;
        end  
    end

    //==========================================================================//
    //                          AXI-4  WRITE DATA                               //
    //==========================================================================//
    always_ff @(posedge clk or negedge reset) begin
        if (!reset) begin
            data_stored <= 0;
            write_err   <= 0;
            for (int i = 0 ; i < `MEM_DEPTH ; i++)begin
                memory[i] <= $random;
            end
        end
        else begin
            if (store_data) begin
                if (addr_valid && !wr_id_mismatch) begin
                    for (int i = 0; i < `STROBE_WIDTH; i++) begin
                        if (write_strobe[i]) begin
                            memory[current_addr + i] <= wr_data[8*i +: 8];
                        end
                    end
                    data_stored <= 1;
                    write_err   <= 0;
                end
                else begin
                    write_err <= 1;
                    data_stored <= 1;
                end
                if (wlast) begin
                    wlast_done = 1;
                end
                else begin
                    wlast_done = 0;
                end
            end
            else begin
                data_stored = 0;
            end
        end
    end


    //==========================================================================//
    //                          AXI-4  WRITE RESPONSE CHANNEL                   //
    //==========================================================================//

    always_comb begin 
            
        wr_resp_channel.bid = 0;
        wr_resp_channel.bresp = `RESP_OKAY;

        if (wlast_done )begin
            wr_resp_channel.bid = write_addr_id;
            // Response CASE 
            case (write_err)
            1'b1 : begin
                wr_resp_channel.bresp = `RESP_DECERR;
            end 
            1'b0 : begin
                wr_resp_channel.bresp = `RESP_OKAY;
            end
            default : begin
                wr_resp_channel.bresp = `RESP_DECERR;
            end 
            endcase   
        end
        else begin
            wr_resp_channel.bid = wr_resp_channel.bid;
            wr_resp_channel.bresp = wr_resp_channel.bresp;
        end
    end
endmodule