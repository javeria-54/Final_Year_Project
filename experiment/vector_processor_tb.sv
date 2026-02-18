// Automatic Testbench - Handles all handshaking automatically

import axi_4_pkg::*;

`include "vector_processor_defs.svh"
`include "vec_de_csr_defs.svh"
`include "axi_4_defs.svh"

`timescale 1ns/1ps

module vector_processor_tb();

    logic clk, reset;
    logic [31:0]    instruction;
    logic [31:0]    rs1_data;
    logic [31:0]    rs2_data;
    logic           inst_valid;
    logic           scalar_pro_ready;
    logic           is_vec;
    logic           error;
    logic [31:0]    csr_out;
    logic           vec_pro_ack;
    logic           vec_pro_ready;
    
    logic s_arready, m_arvalid;
    logic s_rvalid, m_rready;
    logic s_awready, m_awvalid;
    logic s_wready, m_wvalid;
    logic s_bvalid, m_bready;
    logic ld_req_reg, st_req_reg;
    
    read_write_address_channel_t    re_wr_addr_channel;
    write_data_channel_t            wr_data_channel;
    read_data_channel_t             re_data_channel;
    write_response_channel_t        wr_resp_channel;
    
    logic [31:0] inst_mem [0:511];
    int inst_count;
    int file_handle;
    int scan_result;

    vector_processor VECTOR_PROCESSOR(
        .clk(clk), .reset(reset),
        .instruction(instruction),
        .rs1_data(rs1_data),
        .rs2_data(rs2_data),
        .inst_valid(inst_valid),
        .scalar_pro_ready(scalar_pro_ready),
        .is_vec(is_vec),
        .error(error),
        .csr_out(csr_out),
        .vec_pro_ack(vec_pro_ack),
        .vec_pro_ready(vec_pro_ready),
        .s_arready(s_arready), .m_arvalid(m_arvalid),
        .s_rvalid(s_rvalid), .m_rready(m_rready),
        .s_awready(s_awready), .m_awvalid(m_awvalid),
        .s_wready(s_wready), .m_wvalid(m_wvalid),
        .s_bvalid(s_bvalid), .m_bready(m_bready),
        .ld_req_reg(ld_req_reg), .st_req_reg(st_req_reg),
        .re_wr_addr_channel(re_wr_addr_channel),
        .wr_data_channel(wr_data_channel),
        .re_data_channel(re_data_channel),
        .wr_resp_channel(wr_resp_channel)
    );

    axi4_slave_mem u_axi_slave (
        .clk(clk), .reset(reset),
        .ld_req(ld_req_reg), .st_req(st_req_reg),
        .s_arready(s_arready), .m_arvalid(m_arvalid),
        .s_rvalid(s_rvalid), .m_rready(m_rready),
        .s_awready(s_awready), .m_awvalid(m_awvalid),
        .s_wready(s_wready), .m_wvalid(m_wvalid),
        .s_bvalid(s_bvalid), .m_bready(m_bready),
        .re_wr_addr_channel(re_wr_addr_channel),
        .wr_data_channel(wr_data_channel),
        .re_data_channel(re_data_channel),
        .wr_resp_channel(wr_resp_channel)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    //==========================================================================
    //     AUTOMATIC SCALAR_PRO_READY GENERATOR
    //==========================================================================
    // This always block automatically manages scalar_pro_ready signal
    
    always @(posedge clk or negedge reset) begin
        if (!reset) begin
            scalar_pro_ready <= 1'b0;
        end
        else begin
            if (vec_pro_ack && !scalar_pro_ready) begin
                // When vec_pro_ack arrives, assert scalar_pro_ready after 1 cycle
                scalar_pro_ready <= 1'b1;
            end
            else if (scalar_pro_ready && !vec_pro_ack) begin
                // When vec_pro_ack goes low, deassert scalar_pro_ready
                scalar_pro_ready <= 1'b0;
            end
        end
    end

    //==========================================================================
    //     READ INSTRUCTIONS FROM FILE
    //==========================================================================
    
    task read_instructions();
        begin
            for (int i = 0; i < 512; i++) inst_mem[i] = 32'h0;
            
            file_handle = $fopen("/home/javeria/Documents/Final_Year_Project/rtl/vector_processor/instruction_mem.txt", "r");
            if (file_handle == 0) begin
                $display("ERROR: Cannot open file!");
                $finish;
            end
            
            inst_count = 0;
            while (!$feof(file_handle)) begin
                scan_result = $fscanf(file_handle, "%h\n", inst_mem[inst_count]);
                if (scan_result == 1) begin
                    $display("  [%0d] 0x%08h", inst_count, inst_mem[inst_count]);
                    inst_count++;
                end
            end
            $fclose(file_handle);
            $display("\nTotal: %0d instructions\n", inst_count);
        end
    endtask

    //==========================================================================
    //     MAIN TEST SEQUENCE
    //==========================================================================
    
    initial begin
        $display("======================================");
        $display("  Vector Processor Testbench");
        $display("======================================\n");
        
        // Initialize
        reset = 1;
        inst_valid = 0;
        instruction = 0;
        rs1_data = 32'h10;
        rs2_data = 0;
        
        $display("Reading instructions...");
        read_instructions();
        
        if (inst_count == 0) begin
            $display("ERROR: No instructions found!");
            $finish;
        end
        
        // Reset sequence
        $display("Applying reset...");
        #50 reset = 0;
        #50 reset = 1;
        #20;
        $display("Reset complete\n");
        
        $display("======================================");
        $display("  Executing Instructions");
        $display("======================================\n");
        
        // Execute all instructions
        for (int i = 0; i < inst_count; i++) begin
            
            $display("[%0d/%0d] Inst: 0x%08h", i+1, inst_count, inst_mem[i]);
            
            // Wait for vec_pro_ready
            while (!vec_pro_ready) @(posedge clk);
            
            // Send instruction - inst_valid HIGH for exactly 1 cycle
            @(posedge clk);
            instruction = inst_mem[i];
            rs1_data = 32'h10;
            rs2_data = 32'h00;
            inst_valid = 1;
            
            // inst_valid LOW after 1 cycle
            @(posedge clk);
            inst_valid = 0;
            
            // Wait for completion
            while (!vec_pro_ack) @(posedge clk);
            
            // scalar_pro_ready is automatically handled by always block above
            
            // Wait for handshake to complete
            while (vec_pro_ack) @(posedge clk);
            
            // Display result
            if (error) 
                $display("       → ERROR!");
            else if (is_vec) 
                $display("       → DONE ✓");
            else 
                $display("       → NOT VEC INST");
            
            $display("");
            
            @(posedge clk);
        end
        
        $display("======================================");
        $display("  All %0d instructions completed!", inst_count);
        $display("======================================\n");
   
    end
    
    
    // Waveform dump
    initial begin
        $dumpfile("vec_proc.vcd");
        $dumpvars(0, vector_processor_tb);
    end

endmodule