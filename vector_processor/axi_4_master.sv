// Author       : Zawaher Bin Asim , UET Lahore  <zawaherbinasim.333@gmail.com>
// Date         : 7 April 2025
// Description  : This file contain the controller for the axi 4 master side (vlsu) that is used for the throughput/pushback control between the memory and vlsu  

`include "axi_4_defs.svh"

import axi_4_pkg::*;

module axi_4_master(
    
    input   logic       clk,
    input   logic       reset,

    // vector_processor vlsu  --> axi_4_master_controller
    input   logic       ld_req,                     // signal for the load request
    input   logic       st_req,                     // signal for the store request

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
    output  logic       m_bready,                     // tells that master(vlsu) is ready to take the valid response from the slave(memory)

    // VLSU -->   AXI 4 MASTER
    input   logic   [`XLEN-1 : 0]                       base_addr,
    input   logic   [`DATA_BUS_WIDTH*`BURST_MAX-1:0]    vlsu_wdata,
    input   logic   [`STROBE_WIDTH*`BURST_MAX-1:0]      write_strobe,
    input   logic   [7:0]                               burst_len,
    input   logic   [2:0]                               burst_size,
    input   logic   [1:0]                               burst_type,

    // AXI 4 MASTER  -->  VLSU 
    output  logic   [`DATA_BUS_WIDTH*`BURST_MAX-1:0]    burst_rdata_array,
    output  logic                                       burst_valid_data,
    output  logic                                       burst_wr_valid,

    // AXI 4 MASTER --> AXI4_SLAVE  
    output  logic                                       ld_req_reg ,st_req_reg,
    output  read_write_address_channel_t                re_wr_addr_channel,
    output  write_data_channel_t                        wr_data_channel,

    // SLAVE(MEMORY) --> AXI 4 MASTER  
    input   wire read_data_channel_t                         re_data_channel,
    input   wire write_response_channel_t                    wr_resp_channel
);
    // axi_4_master_controller --> AXI  4 MASTER
    logic       incre_data_counter;

    // AXI 4 MASTER READ BURSTS SIGNALS
    logic [7:0]                burst_index;
    // Store last burst info to reissue on retry
    logic [`XLEN-1:0]                       last_base_addr;
    logic [7:0]                             last_burst_len;
    logic [2:0]                             last_burst_size;
    logic [1:0]                             last_burst_type;
    logic [`DATA_BUS_WIDTH*`BURST_MAX-1:0]  last_burst_wdata;
    logic [`STROBE_WIDTH*`BURST_MAX-1:0]    last_burst_write_strobe;
    logic                                   resend_burst;
    logic                                   burst_read_err;
    logic                                   burst_active;
    logic                                   retry_req;

    // AXI 4 MASTER WRITE BURSTS SIGNALS
    logic              burst_write_err;
    logic              wr_burst_active;
    logic              retry_wr_req;
    logic              resend_wr_burst;
    logic  [7:0]       burst_wr_counter;
    logic  [7:0]       next_burst_wr_counter;
    logic  [2:0]       effective_axsize;

    // Select source based on normal or retry burst
    logic [`DATA_BUS_WIDTH-1:0]             curr_data;
    logic [`STROBE_WIDTH-1:0]               curr_strobe;
    logic [`DATA_BUS_WIDTH*`BURST_MAX-1:0]  src_data;
    logic [`STROBE_WIDTH*`BURST_MAX-1:0]    src_strobe;
    logic [`XLEN-1:0]                       offset;

    // AXI 4  ID NUMBER 
    logic  [3:0]       id_counter;
    logic  [3:0]       id_num;
    logic              ld_req_prev, st_req_prev;
    logic              ld_req_rise, st_req_rise;


    //==========================================================================//
    //                    AXI-4 MASTER CONTROLLER INSTANTIATION                 //
    //==========================================================================//

    axi_4_master_controller u_axi_4_master_controller (
        .clk                 (clk),
        .reset               (reset),

        // Control signals from VLSU
        .ld_req              (ld_req_reg),
        .st_req              (st_req_reg),

        // Signals related to WLAST handling
        .m_wlast             (wr_data_channel.wlast),
        .s_rlast             (re_data_channel.rlast),

        // Output to control burst data counting
        .incre_data_counter  (incre_data_counter),

        // Read address channel
        .s_arready           (s_arready),
        .m_arvalid           (m_arvalid),

        // Read data channel
        .s_rvalid            (s_rvalid),
        .m_rready            (m_rready),

        // Write address channel
        .s_awready           (s_awready),
        .m_awvalid           (m_awvalid),

        // Write data channel
        .s_wready            (s_wready),
        .m_wvalid            (m_wvalid),

        // Write response channel
        .s_bvalid            (s_bvalid),
        .m_bready            (m_bready)
    );

    //==========================================================================//
    //           AXI-4 READ WRITE BURST CONFIG CAPTURE & RE-ISSUE               //
    //==========================================================================//

    // Config backup for retry (for both load and store)
    always_ff @(posedge clk or negedge reset) begin
        if (!reset) begin
            last_base_addr          <= 0;
            last_burst_len          <= 0;
            last_burst_size         <= 0;
            last_burst_type         <= 0;
            last_burst_wdata        <= 0;
            last_burst_write_strobe <= 0;
        end
        else if (ld_req || st_req) begin
            last_base_addr          <= base_addr;
            last_burst_len          <= burst_len;
            last_burst_size         <= burst_size;
            last_burst_type         <= burst_type;
            last_burst_wdata        <= vlsu_wdata;
            last_burst_write_strobe <= write_strobe;
        end
    end

    // Combined Retry signal assignments
    assign resend_burst     = retry_req    && !ld_req && !burst_valid_data;
    assign resend_wr_burst  = retry_wr_req && !st_req && !burst_wr_valid;

    always_ff @(posedge clk or negedge reset) begin
        if (!reset) begin
            ld_req_reg                  <= 0;
            st_req_reg                  <= 0;
            re_wr_addr_channel.arid     <= 0;
            re_wr_addr_channel.awid     <= 0;
            re_wr_addr_channel.axaddr   <= 0;
            re_wr_addr_channel.axlen    <= 0;
            re_wr_addr_channel.axsize   <= 0;
            re_wr_addr_channel.axburst  <= 0;
            re_wr_addr_channel.axlock   <= 1'b0;
            re_wr_addr_channel.axcache  <= 4'b0000;
            re_wr_addr_channel.axprot   <= 3'b000;
            re_wr_addr_channel.axqos    <= 4'b0000;
        end
        else begin
            // Handle Load (Read) Request or Retry
            if (ld_req || resend_burst) begin
                ld_req_reg                  <= 1'b1;
                st_req_reg                  <= 1'b0;  // Explicitly clear store flag
                re_wr_addr_channel.arid     <= id_num;
                re_wr_addr_channel.axaddr   <= resend_burst ? last_base_addr  : base_addr;
                re_wr_addr_channel.axlen    <= resend_burst ? last_burst_len  : burst_len;
                re_wr_addr_channel.axsize   <= resend_burst ? last_burst_size : burst_size;
                re_wr_addr_channel.axburst  <= resend_burst ? last_burst_type : burst_type;
                re_wr_addr_channel.axlock   <= 1'b0;
                re_wr_addr_channel.axcache  <= 4'b0000;
                re_wr_addr_channel.axprot   <= 3'b000;
                re_wr_addr_channel.axqos    <= 4'b0000;
            end

            // Handle Store (Write) Request or Retry
            else if (st_req || resend_wr_burst) begin
                st_req_reg                  <= 1'b1;
                ld_req_reg                  <= 1'b0;  // Explicitly clear load flag
                re_wr_addr_channel.awid     <= id_num;
                re_wr_addr_channel.axaddr   <= resend_wr_burst ? last_base_addr  : base_addr;
                re_wr_addr_channel.axlen    <= resend_wr_burst ? last_burst_len  : burst_len;
                re_wr_addr_channel.axsize   <= resend_wr_burst ? last_burst_size : burst_size;
                re_wr_addr_channel.axburst  <= resend_wr_burst ? last_burst_type : burst_type;
                re_wr_addr_channel.axlock   <= 1'b0;
                re_wr_addr_channel.axcache  <= 4'b0000;
                re_wr_addr_channel.axprot   <= 3'b000;
                re_wr_addr_channel.axqos    <= 4'b0000;
            end
            else if (wr_data_channel.wlast && s_bvalid && m_bready)begin
                st_req_reg <= 0;
            end
            else if (re_data_channel.rlast && s_rvalid && m_rready)begin
                ld_req_reg <= 0;
            end
            
        end
    end

    //==========================================================================//
    //                      AXI-4  WRITE DATA CHANNEL                           //
    //==========================================================================//


assign effective_axsize = (st_req || resend_wr_burst) ? 
                                (resend_wr_burst ? last_burst_size : burst_size) :
                                re_wr_addr_channel.axsize;

always_ff @(posedge clk or negedge reset) begin
    if (!reset) begin
        burst_wr_counter      <= 0;
        wr_data_channel.wid   <= 0;
        wr_data_channel.wdata <= 0;
        wr_data_channel.wstrb <= 0;
        wr_data_channel.wlast <= 0;
        curr_data             <= '0;
        curr_strobe           <= '0;
    end
    else begin
        // =========================================
        // 1. Update next_burst_wr_counter
        // =========================================

        next_burst_wr_counter = burst_wr_counter;

        if ((st_req || resend_wr_burst) && (burst_wr_counter == 0)) begin
            next_burst_wr_counter = 0;
        end
        else if (incre_data_counter) begin
            if (burst_wr_counter == burst_len) begin
                next_burst_wr_counter = 0;
            end
            else begin
                next_burst_wr_counter = burst_wr_counter + 1;
            end
        end

        // =========================================
        // 2. Prepare curr_data and curr_strobe using NEXT value
        // =========================================

        curr_data   = '0;
        curr_strobe = '0;

        src_data   = resend_wr_burst ? last_burst_wdata : vlsu_wdata;
        src_strobe = resend_wr_burst ? last_burst_write_strobe : write_strobe;
        offset     = next_burst_wr_counter << effective_axsize;  // offset in bytes

        case (effective_axsize)
            3'd0: begin // 1 byte
                curr_data[7:0]   = src_data[offset*8 +: 8];
                curr_strobe[0]   = src_strobe[offset];
            end
            3'd1: begin // 2 bytes
                curr_data[15:0]  = src_data[offset*8 +: 16];
                curr_strobe[1:0] = src_strobe[offset +: 2];
            end
            3'd2: begin // 4 bytes
                curr_data[31:0]  = src_data[offset*8 +: 32];
                curr_strobe[3:0] = src_strobe[offset +: 4];
            end
            3'd3: begin // 8 bytes
                curr_data[63:0]  = src_data[offset*8 +: 64];
                curr_strobe[7:0] = src_strobe[offset +: 8];
            end
            3'd4: begin // 16 bytes
                curr_data[127:0]  = src_data[offset*8 +: 128];
                curr_strobe[15:0] = src_strobe[offset +: 16];
            end
            3'd5: begin // 32 bytes
                curr_data[255:0]  = src_data[offset*8 +: 256];
                curr_strobe[31:0] = src_strobe[offset +: 32];
            end
            3'd6: begin // 64 bytes
                curr_data[511:0]  = src_data[offset*8 +: 512];
                curr_strobe[63:0] = src_strobe[offset +: 64];
            end
            default: begin
                curr_data   = '0;
                curr_strobe = '0;
            end
        endcase


        // =========================================
        // 3. Write prepared data
        // =========================================
        
        if ((st_req || resend_wr_burst) && (burst_wr_counter == 0)) begin
            wr_data_channel.wid   <= id_num;    
        end
        else begin
            wr_data_channel.wid   <= re_wr_addr_channel.awid;    
        end
        wr_data_channel.wdata <= curr_data;
        wr_data_channel.wstrb <= curr_strobe;
        wr_data_channel.wlast <= (next_burst_wr_counter == burst_len);

        // =========================================
        // 4. Finally update burst_wr_counter
        // =========================================

        burst_wr_counter <= next_burst_wr_counter;
    end
end



    //==========================================================================//
    //               AXI-4  READ DATA CHANNEL AND RESPONSE CHECK                //
    //==========================================================================//


    always_ff @(posedge clk or negedge reset) begin
        if (!reset) begin
            burst_rdata_array <= 0;
            burst_read_err    <= 0;
            burst_active      <= 0;
            retry_req         <= 0;
            burst_index       <= 0;
            burst_valid_data  <= 0;
        end
        else begin
            if ((ld_req_reg || resend_burst) && s_arready && m_arvalid && !burst_active) begin
                // Start burst
                burst_active      <= 1;
                burst_read_err    <= 0;
                retry_req         <= 0;
                burst_index       <= 0;
                burst_valid_data  <= 0;
            end
            else if (burst_active && s_rvalid && m_rready) begin
                if (re_data_channel.rid == re_wr_addr_channel.arid) begin
                    if (re_data_channel.rresp != `RESP_OKAY) begin
                        burst_read_err <= 1;
                    end
                    else begin
                        // Store word into burst array
                        burst_rdata_array[burst_index * `DATA_BUS_WIDTH +: `DATA_BUS_WIDTH] <= re_data_channel.rdata;
                        burst_index <= burst_index + 1;
                    end
                end
                else begin
                    burst_read_err <= 1;    
                end
    
                if (re_data_channel.rlast) begin
                    burst_active    <= 0;
                    burst_index     <= 0;

                    if (burst_read_err)begin
                        retry_req <= 1;
                        burst_valid_data <= 0;
                    end
                    else begin
                        retry_req <= 0 ;
                        burst_valid_data <= 1;
                    end
                end
                else begin
                    burst_valid_data <= 0;
                end
            end
            else begin
                burst_valid_data  <= 0;
            end
        end
    end


    //==========================================================================//
    //                   AXI-4 WRITE RESPONSE CHECK FOR RETRY                   //
    //==========================================================================//


    // NOTE: Write response comes only after last beat
    always_ff @(posedge clk or negedge reset) begin
        if (!reset) begin
            burst_write_err     <= 0;
            wr_burst_active     <= 0;
            retry_wr_req        <= 0;
            burst_wr_valid      <= 0;
        end
        else begin
            // Start of write burst
            if ((st_req_reg || resend_wr_burst) && s_awready && m_awvalid && !wr_burst_active) begin
                wr_burst_active   <= 1;
                burst_write_err   <= 0;
                retry_wr_req      <= 0;
                burst_wr_valid    <= 0;
            end

            // Write response received (only after wlast)
            else if (wr_burst_active && s_bvalid && m_bready) begin
                if (wr_resp_channel.bid == re_wr_addr_channel.awid)begin

                    // Response check
                    if (wr_resp_channel.bresp != `RESP_OKAY) begin
                        burst_write_err <= 1;
                    end

                    wr_burst_active  <= 0;

                    if (burst_write_err) begin
                        retry_wr_req     <= 1;
                        burst_wr_valid   <= 0;
                    end
                    else begin
                        retry_wr_req     <= 0;
                        burst_wr_valid   <= 1; // successful write
                    end 
                end
                else begin  // if id mis-matches that means the burst is failed or done wrong so repeat it
                    retry_wr_req     <= 1;
                    burst_wr_valid   <= 0;                   
                end
            end
            else begin
                burst_write_err   <= 0;
                burst_wr_valid    <= 0;
            end
        end
    end


    //==========================================================================//
    //                   AXI-4 ID NUMBER GENERATOR                              //
    //==========================================================================//

    // Edge Detection logic 
    always_ff @(posedge clk or negedge reset) begin
        if (!reset) begin
            ld_req_prev <= 0;
            st_req_prev <= 0;
        end else begin
            ld_req_prev <= ld_req;
            st_req_prev <= st_req;
        end
    end

    assign ld_req_rise = ld_req & ~ld_req_prev;
    assign st_req_rise = st_req & ~st_req_prev;

    always_ff @(posedge clk or negedge reset) begin
        if (!reset)
            id_counter <= 0;
        else if (ld_req_rise || st_req_rise)
            id_counter <= id_counter + 1;
    end

    assign id_num = id_counter;
endmodule