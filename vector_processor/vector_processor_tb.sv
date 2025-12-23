// Author       : Zawaher Bin Asim , UET Lahore <zawaherbinasim.333@gmail.com>
// Date         : 1 Oct 2024
// Description  : This file contains the testbench of the vector_processor

import axi_4_pkg::*;

`include "vector_processor_defs.svh"
`include "vec_de_csr_defs.svh"
`include "axi_4_defs.svh"
`define ROOT_PATH "/home/javeria/Documents/Final_Year_Project"


module vector_processor_tb ();


// Depth of the instruction memory 
parameter  depth = 512;
parameter   SEW  = 32;

logic   clk,reset;
        
// Inputs from the scaler processor  --> vector processor
logic   [`XLEN-1:0]         instruction;        // The instruction that is to be executed by the vector processor
logic   [`XLEN-1:0]         rs1_data;           // The scaler input from the scaler processor for the instructon that needs data from the  scaler register file across the rs1 address
logic   [`XLEN-1:0]         rs2_data;           // The scaler input from the scaler processor for the instructon that needs data from the  scaler register file across the rs2 address

// Outputs from vector rocessor --> scaler processor
logic                       is_vec;             // This tells the instruction is a vector instruction or not mean a legal instruction or not
logic                       error;              // error has occure due to invalid configurations

// csr_regfile -> scalar_processor
logic   [`XLEN-1:0]         csr_out;            

// addresses of the scaler register
logic   [4:0]               rs1_addr;
logic   [4:0]               rs2_addr;
   
// Register file to hold scalar register values (can be initialized as needed)
logic   [`XLEN-1:0] scalar_regfile [31:0];

// Instruction memory
logic   [`XLEN-1:0] inst_mem    [depth-1:0];

//  Dummy Memory for testing
logic   [7:0]   test_mem    [depth-1:0];
logic   [`XLEN-1:0] addr_array [depth-1:0];

// Variable for testing 
logic   [7:0]                       burst_len;
logic   [2:0]                       burst_size;
logic   [1:0]                       burst_type;
logic   [`XLEN-1:0]                 base_addr;



/*************************************** VAL READY INTERFACE SIGNALS *********************************************************/

logic               vec_pro_ack;            // signal that tells that successfully implemented the previous instruction 

logic               vec_pro_ready;          // tells that vector processor is ready to take the instruction

logic               scalar_pro_ready;       // tells that scaler processor is  ready to take output from the vector processor 

logic               inst_valid;             // tells that instruction and data related to instruction is valid

/*****************************************************************************************************************************/


/*************************************** AXI 4 INTERFACE SIGNALS *********************************************************/
    // AXI Master <-> Slave interface
    logic s_arready, m_arvalid;
    logic s_rvalid, m_rready;
    logic s_awready, m_awvalid;
    logic s_wready, m_wvalid;
    logic s_bvalid, m_bready;
    logic ld_req_reg, st_req_reg;

    // AXI Channels
    read_write_address_channel_t re_wr_addr_channel;
    write_data_channel_t         wr_data_channel;
    read_data_channel_t          re_data_channel;
    write_response_channel_t     wr_resp_channel;
/*****************************************************************************************************************************/


/***************************************** FLAGS FOR THE LOAD ****************************************************************/
int i = 0; // Declare i globally or persist across loads
bit step1_done = 0;
bit step3_done = 0;
int addr_array_index = 0;                           // Define an index to track the next position in `addr_array`
logic [`XLEN-1:0] current_instruction = 'h0;        // Keep track of the current instruction
logic [`MAX_VLEN-1:0]loaded_data;                   // loaded data for comparison
/****************************************************************************************************************************/

v_opcode_e      vopcode;
v_func3_e       vfunc3;
assign vopcode  = v_opcode_e'(VECTOR_PROCESSOR.inst_reg_instruction[6:0]);
assign vfunc3   = v_func3_e'(VECTOR_PROCESSOR.inst_reg_instruction[14:12]);


    vector_processor VECTOR_PROCESSOR(

        .clk                (clk                ),
        .reset              (reset              ),
        
        // Inputs from the scaler processor  --> vector processor
        .instruction        (instruction        ),
        .rs1_data           (rs1_data           ),
        .rs2_data           (rs2_data           ),

        // scaler_procssor  --> val_ready_controller
        .inst_valid         (inst_valid         ),             // tells data comming from the saler processor is valid
        .scalar_pro_ready   (scalar_pro_ready   ),       // tells that scaler processor is ready to take output
    

        // Outputs from vector rocessor --> scaler processor
        .is_vec             (is_vec             ),
        .error              (error              ),
        
        // csr_regfile -> scalar_processor
        .csr_out            (csr_out            ),

        // datapth  --> scaler_processor
        .vec_pro_ack        (vec_pro_ack        ),

        // controller --> scaler_processor
        .vec_pro_ready      (vec_pro_ready      ),

    //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> AXI 4 SIGNALS <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<//

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
        .m_bready            (m_bready),

        // AXI 4 MASTER --> AXI4_SLAVE(MEMORY) 
        .ld_req_reg          (ld_req_reg), 
        .st_req_reg          (st_req_reg),
        .re_wr_addr_channel  (re_wr_addr_channel),
        .wr_data_channel     (wr_data_channel),
        
        // SLAVE(MEMORY) --> AXI 4 MASTER  
        .re_data_channel     (re_data_channel),
        .wr_resp_channel     (wr_resp_channel)
    );


// Instantiate AXI Slave
    axi4_slave_mem u_axi_slave (
        .clk                (clk                ), 
        .reset              (reset              ),
        .ld_req             (ld_req_reg         ), 
        .st_req             (st_req_reg         ),
        .s_arready          (s_arready          ), 
        .m_arvalid          (m_arvalid          ),
        .s_rvalid           (s_rvalid           ), 
        .m_rready           (m_rready           ),
        .s_awready          (s_awready          ), 
        .m_awvalid          (m_awvalid          ),
        .s_wready           (s_wready           ), 
        .m_wvalid           (m_wvalid           ),
        .s_bvalid           (s_bvalid           ),
        .m_bready           (m_bready           ),
        .re_wr_addr_channel (re_wr_addr_channel ),
        .wr_data_channel    (wr_data_channel    ),
        .re_data_channel    (re_data_channel    ),
        .wr_resp_channel    (wr_resp_channel    )
    );


    initial begin
    // Clock generation
        clk <= 0;
        forever #5 clk <= ~clk;
    end

    /***********************************************  MAIN test bench ****************************************************************/
    initial begin

        // Reading the instruction memory
        
        // Initializing the signals 
        init_signals();

        @(posedge clk);

        // Applying Reset
        reset_sequence();

        // Initiating the dummy memories

        dummy_mem_reg_init();
        
        @(posedge clk);
        
        for (int i = 0 ; i < depth ; i++)begin

            fork
                $display("THE NEXT INDEX IS : %d",i);
                driver(i);
                monitor();
            join
        end

        $finish;
    end

    /********************************************************************************************************************************/

    // Initializing the  signals
    task  init_signals();
        rs1_data        = 'h0;
        rs2_data        = 'h0;
        instruction    	= 'h0;


    endtask 

    // Reset task
    task reset_sequence();
        begin
            reset <= 1;
            @(posedge clk);
            reset <= 0;
            @(posedge clk);
            reset <= 1;
            @(posedge clk);
        end
    endtask
    

    task  dummy_mem_reg_init();
        begin
            // initializing the instruction memory and the dummy memory
            for (int i  = 0 ; i < depth ; i++ ) begin
                inst_mem[i] = 'h0;
                test_mem[i] = 'h0;
                addr_array[i] = 'h0;
            end
            scalar_regfile[0] = 16;
            for (int j = 1 ; j < 32 ; j++)begin
                scalar_regfile[j] = 'h0;
            end
        end
    endtask

 

/********************************************** MEMORY DATA FETCHING  AND CALCULATING THE LOADED DATA *************************************************************/

    // if load_instruction and the masking is enabled it sees  see start_element number from the csr_file
    // and  before that start element it should copy the elements from the destination register and 
    // paste them before the start element based on the sew in the csr file and
    // from start element it should see the mask register bit value having index corresponding to the start element number .
    // if the bit is zero it  should see the mask_agnostic value .
    // if  1 it should replace that element with sew number of  1s and 
    // if the mask agnostic is 0 it  should  replace it with the value with destination register element
    // that corresponds   to that mask register bit based on the sew . 
    // if the mask register bit is 1 then value of the element will be same as the data fetched from the memory. 
    // and do the same till the value of the vl from the csr_register file and then after the vl value till vlmax
    // it should see whether the tail agnostic policy is active or not 
    // if yes then it should replace ecah element of the loaded data from the vl to vlmax with sew number of 1s .
    // and if not then it should replace each element with the destination register element corresponding to that element based on the sew .
task memory_data_fetch();

    static int loaded_seen = 0;

    // Reset `loaded_seen` only when a new instruction is issued
    if ((VECTOR_PROCESSOR.DATAPATH.VLSU.ld_inst) &&
        (VECTOR_PROCESSOR.inst_reg_instruction != current_instruction)) begin
        addr_array_index     = 0;
        current_instruction  = instruction;
        loaded_seen          = 0;
    end

    if (VECTOR_PROCESSOR.DATAPATH.VLSU.ld_inst) begin
        $display("Entering Load");

        // -------- Masking Enabled --------
        if (!VECTOR_PROCESSOR.inst_reg_instruction[25]) begin
            $display("Load with masking");

            while (ld_req_reg && !error) begin
                @(posedge clk);
            end

        // -------- No Masking --------
        end else begin
            $display("Load with not masking");
            @(posedge clk);
            while (ld_req_reg && !error) begin
                base_addr  <= re_wr_addr_channel.axaddr;
                burst_size <= re_wr_addr_channel.axsize;
                burst_len  <= re_wr_addr_channel.axlen;

                for (int i = 0; i < burst_len + 1; i++) begin
                    while (!s_rvalid) @(posedge clk);

                    for (int j = 0; j < (1 << burst_size); j++) begin
                        test_mem[base_addr + j] <= re_data_channel.rdata[j*8 +: 8];
                        addr_array[addr_array_index] <= base_addr + j;
                        addr_array_index++;
                    end
                    base_addr <= base_addr + (1 << burst_size);
                end
            end
            $display("END STORING INTO DUMMY");
        end
    end

endtask

    // task vector_load_with_masking();
    //     // Assuming the following values are available:
    //     logic [`MAX_VLEN-1:0] destination_reg;    // Destination register file
    //     logic [`VLEN-1:0] mask_reg;               // Mask register (v0 register)
    //     logic [`MAX_VLEN-1:0] loaded_data;        // Loaded data from memory
    //     logic [31:0] mem_data;                    // Fetched data from memory
    //     int vl;                                   // Vector length (from CSR)
    //     int sew;                                  // Element width (from CSR)
    //     int vlmax;                                // maximum number of elements
    //     int start_elem;                           // Start element (from CSR)
    //     bit mask_agnostic;                        // Mask agnostic flag (from CSR)
    //     bit tail_agnostic;                        // Tail agnostic flag (from CSR)
                    
        
    //     // Get  sew,VL,vlmax , start_elem, mask_agnostic, and tail_agnostic from the CSR
    //     sew = VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.sew;                    
    //     vl = VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.vec_length;
    //     vlmax = VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.vlmax;
    //     start_elem = VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.start_element;   
    //     mask_agnostic = VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.mask_agnostic;
    //     tail_agnostic = VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.tail_agnostic;

    //     case (VECTOR_PROCESSOR.DATAPATH.VEC_REGFILE.lmul)
                
    //         4'b0001: begin // LMUL = 1
    //             destination_reg = VECTOR_PROCESSOR.DATAPATH.VEC_REGFILE.vec_regfile[instruction[11:7]];
    //         end
    //         4'b0010: begin // LMUL = 2
        
    //             destination_reg = {VECTOR_PROCESSOR.DATAPATH.VEC_REGFILE.vec_regfile[instruction[11:7] + 1],
    //                             VECTOR_PROCESSOR.DATAPATH.VEC_REGFILE.vec_regfile[instruction[11:7]]};
    //         end

    //         4'b0100: begin // LMUL = 4
    //             destination_reg = {VECTOR_PROCESSOR.DATAPATH.VEC_REGFILE.vec_regfile[instruction[11:7] + 3], 
    //                             VECTOR_PROCESSOR.DATAPATH.VEC_REGFILE.vec_regfile[instruction[11:7] + 2],
    //                             VECTOR_PROCESSOR.DATAPATH.VEC_REGFILE.vec_regfile[instruction[11:7] + 1],
    //                             VECTOR_PROCESSOR.DATAPATH.VEC_REGFILE.vec_regfile[instruction[11:7]]};
    //         end

    //         4'b1000: begin // LMUL = 8
    //             destination_reg = {VECTOR_PROCESSOR.DATAPATH.VEC_REGFILE.vec_regfile[instruction[11:7] + 7], 
    //                             VECTOR_PROCESSOR.DATAPATH.VEC_REGFILE.vec_regfile[instruction[11:7] + 6],
    //                             VECTOR_PROCESSOR.DATAPATH.VEC_REGFILE.vec_regfile[instruction[11:7] + 5],
    //                             VECTOR_PROCESSOR.DATAPATH.VEC_REGFILE.vec_regfile[instruction[11:7] + 4],
    //                             VECTOR_PROCESSOR.DATAPATH.VEC_REGFILE.vec_regfile[instruction[11:7] + 3], 
    //                             VECTOR_PROCESSOR.DATAPATH.VEC_REGFILE.vec_regfile[instruction[11:7] + 2],
    //                             VECTOR_PROCESSOR.DATAPATH.VEC_REGFILE.vec_regfile[instruction[11:7] + 1],
    //                             VECTOR_PROCESSOR.DATAPATH.VEC_REGFILE.vec_regfile[instruction[11:7]]};
    //         end
    //         default: begin 
    //             destination_reg = 'h0;
    //         end
    //     endcase

    //     // v0 as mask register
    //     mask_reg = VECTOR_PROCESSOR.DATAPATH.VEC_REGFILE.vec_regfile[0];

    //     // Step 1: Before the start element, copy elements from the destination register
    //     // Step 1: Handle elements before the start element, runs once
    //     if (!step1_done) begin
    //         for (i = 0; i < start_elem; i++) begin
    //             for (int idx = 0; idx < sew; idx++) begin
    //                 loaded_data[(i * sew) + idx] = destination_reg[(i * sew) + idx];
    //             end
    //         end
    //         step1_done = 1; // Mark step1 as done
    //     end        


    //     // Step 3: From VL to VLMAX, handle tail agnostic logic
    //     // Step 3: Handle elements after VL, runs once
    //     if (!step3_done && i >= vl) begin
    //         for (i = vl; i < vlmax; i++) begin
    //             for (int idx = 0; idx < sew; idx++) begin
    //                 if (tail_agnostic) begin
    //                     loaded_data[(i * sew) + idx] = 1'b1; // Tail agnostic: fill with 1's
    //                 end else begin
    //                     loaded_data[(i * sew) + idx] = destination_reg[(i * sew) + idx];
    //                 end
    //             end
    //         end
    //         step3_done = 1;
    //     end

    //     // Step 2: Incrementally process masked elements between start_elem and VL
    //     if (ld_req && i >= start_elem && i < vl) begin
    //         for (int idx = 0; idx < sew; idx++) begin
    //             if (mask_reg[i] == 1'b0) begin
    //                 loaded_data[(i * sew) + idx] = mask_agnostic ? 1'b1 : destination_reg[(i * sew) + idx];
    //             end else begin
    //                 loaded_data[(i * sew) + idx] = mem2lsu_data[idx];
    //             end
    //         end
    //         i++; // Increment index for next element on subsequent load
    //     end
    // endtask

/*********************************************************** DRIVER TASKS *******************************************************************************/
     // Instruction Memory
     
    task instruction_fetch(input logic [`XLEN-1:0]address );
    
        begin
            string path;
            path = {`ROOT_PATH, "/rtl/vector_processor/instruction_mem.txt"};
            $readmemh(path, inst_mem);
            $display("Next Instruction");
            instruction = inst_mem[address];        // Fetch instruction from memory
            rs1_addr = instruction[19:15];          // Decode rs1 address
            rs2_addr = instruction[24:20];          // Decode rs2 address
            rs1_data = scalar_regfile[rs1_addr];    // Fetch rs1 data
            rs2_data = scalar_regfile[rs2_addr];    // Fetch rs2 data
            $display("Instruction : %h",instruction);
            $display("RS1 DATA : %h",rs1_data);
            $display("RS2 DATA : %h",rs2_data);
        end

    endtask

    // It will issue the instruction
    task  instruction_issue(input int z);


        // Fetching the instruction + data
        instruction_fetch(z);

        // Making the inst_valid 1
        inst_valid <= 1'b1;
        @(posedge clk);
        // Wait for the vector processor to be ready to take instruction
        while (!vec_pro_ready)begin
            @(posedge clk );
        end
        inst_valid <= 1'b0;
        $display("INSTRUCTION ISSUED!!");

    
    endtask

    task driver(input int i );
        $display("Entering Driver");
        instruction_issue(i);
        memory_data_fetch();
        $display("EXITING Driver");
    endtask
 
/*******************************************************************************************************************************************************/


/*********************************************************** MONITOR TASK *****************************************************************************/

    task monitor ();
        logic [4:0]vec_reg_addr ;
        
        logic [`MAX_VLEN-1:0] vec_reg_data;

        assign vec_reg_addr =  VECTOR_PROCESSOR.inst_reg_instruction[11:7];

        @(posedge clk);
        if (!is_vec)begin
            $error("ILLEGAL INSTRUCTION OR NOT A VECTOR INSTRUCTION");
        end
        else begin
            // Tell that scaler_porcessor is ready  to take the response
            scalar_pro_ready <= 1'b1;

            @(posedge clk);
            //Wait for the acknowledgement from the vector processor 
            while (!vec_pro_ack)begin
                @(posedge clk);
            end 

            scalar_pro_ready <= 1'b0;
    
            $display("Start monitoring");
    
         // Lets monitor the output by looking into the registers whether the instruction has been successfully implemented or not
            if (error)begin
                $display("ERROR OCCURED!");
                $display(">>>>>>>>>Skipping Monitering>>>>>>");
            end
            else begin
                case (vopcode)
                // vector arithematic and set instructions opcode = 0x57
                    V_ARITH: begin

                        case (vfunc3)
                            
                            // vector configuration instructions
                            CONF: begin
                                case (VECTOR_PROCESSOR.inst_reg_instruction[31])
                                // VSETVLI
                                    1'b0: begin
                                        if (VECTOR_PROCESSOR.inst_reg_instruction[19:15] == 0) begin // RS1_Addr == 0
                                            if (VECTOR_PROCESSOR.inst_reg_instruction[11:7] == 0 )begin // Rd_Addr ==  0
                                                if ((VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.csr_vtype_q == VECTOR_PROCESSOR.inst_reg_instruction[30:20]) && 
                                                    (VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.csr_vl_q == VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.csr_vl_q) )begin
                                                    $display("======================= TEST PASSED ==========================");
                                                    $display("Instruction : %h",instruction);
                                                    $display("VTYPE Value : %d",VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.csr_vtype_q);
                                                    $display("VL Value : %d",VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.csr_vl_q);
                                                end
                                                else begin
                                                    $display("======================= TEST FAILED ==========================");
                                                    $display("Instruction : %h",instruction);
                                                    $display("ACTUAL_VTYPE Value : %d",VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.csr_vtype_q);
                                                    $display("EXPECTED_VTYPE Value : %d",VECTOR_PROCESSOR.inst_reg_instruction[30:20]);
                                                    $display("ACTUAL_VL Value : %d",VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.csr_vl_q);
                                                    $display("EXPECTED_VL Value : %d",VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.csr_vl_q);    
                                                end
                                            end    
                                            else begin  // Rd_ADDR != 0
                                                if ((VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.csr_vtype_q == VECTOR_PROCESSOR.inst_reg_instruction[30:20]) && 
                                                    (VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.csr_vl_q == VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.vlmax) )begin
                                                    $display("======================= TEST PASSED ==========================");
                                                    $display("Instruction : %h",instruction);
                                                    $display("VTYPE Value : %d",VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.csr_vtype_q);
                                                    $display("VL Value : %d",VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.csr_vl_q);
                                                end
                                                else begin
                                                    $display("======================= TEST FAILED ==========================");
                                                    $display("Instruction : %h",instruction);
                                                    $display("ACTUAL_VTYPE Value : %d",VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.csr_vtype_q);
                                                    $display("EXPECTED_VTYPE Value : %d",VECTOR_PROCESSOR.inst_reg_instruction[30:20]);
                                                    $display("ACTUAL_VL Value : %d",VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.csr_vl_q);
                                                    $display("EXPECTED_VL Value : %d",VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.vlmax); 
                                                end
                                            end 
                                        end
                                        else begin
                                            if ((VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.csr_vtype_q == VECTOR_PROCESSOR.inst_reg_instruction[30:20]) && 
                                                (VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.csr_vl_q == VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.vlen_compare) )begin
                                                $display("======================= TEST PASSED ==========================");
                                                $display("Instruction : %h",instruction);
                                                $display("VTYPE Value : %d",VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.csr_vtype_q);
                                                $display("VL Value : %d",VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.csr_vl_q);
                                            end
                                            else begin
                                                $display("======================= TEST FAILED ==========================");
                                                $display("Instruction : %h",instruction);
                                                $display("ACTUAL_VTYPE Value : %d",VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.csr_vtype_q);
                                                $display("EXPECTED_VTYPE Value : %d",VECTOR_PROCESSOR.inst_reg_instruction[30:20]);
                                                $display("ACTUAL_VL Value : %d",VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.csr_vl_q);
                                                $display("EXPECTED_VL Value : %d",VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.vlen_compare);
                                            end
                                        end
                                    end
                                    1'b1: begin
                                        case (VECTOR_PROCESSOR.inst_reg_instruction[30])
                                        // VSETIVLI
                                            1'b1: begin
                                                if ((VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.csr_vtype_q == VECTOR_PROCESSOR.inst_reg_instruction[29:20]) && 
                                                    (VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.csr_vl_q == VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.vlen_compare) )begin
                                                    $display("======================= TEST PASSED ==========================");
                                                    $display("Instruction : %h",instruction);
                                                    $display("VTYPE Value : %d",VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.csr_vtype_q);
                                                    $display("VL Value : %d",VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.csr_vl_q);
                                                end
                                                else begin
                                                    $display("======================= TEST FAILED ==========================");
                                                    $display("Instruction : %h",instruction);
                                                    $display("ACTUAL_VTYPE Value : %d",VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.csr_vtype_q);
                                                    $display("EXPECTED_VTYPE Value : %d",VECTOR_PROCESSOR.inst_reg_instruction[29:20]);
                                                    $display("ACTUAL_VL Value : %d",VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.csr_vl_q);
                                                    $display("EXPECTED_VL Value : %d",VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.vlen_compare);    
                                                end
                                            end
                                        // VSETVL
                                            1'b0: begin
                                            
                                                if (VECTOR_PROCESSOR.inst_reg_instruction[19:15] == 0) begin // RS1_Addr == 0
                                                    if (VECTOR_PROCESSOR.inst_reg_instruction[11:7] == 0 )begin // Rd_Addr ==  0
                                                        if ((VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.csr_vtype_q == VECTOR_PROCESSOR.inst_reg_rs2_data) && 
                                                            (VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.csr_vl_q == VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.csr_vl_q) )begin
                                                            $display("======================= TEST PASSED ==========================");
                                                            $display("Instruction : %h",instruction);
                                                            $display("VTYPE Value : %d",VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.csr_vtype_q);
                                                            $display("VL Value : %d",VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.csr_vl_q);
                                                        end
                                                        else begin
                                                            $display("======================= TEST FAILED ==========================");
                                                            $display("Instruction : %h",instruction);
                                                            $display("ACTUAL_VTYPE Value : %d",VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.csr_vtype_q);
                                                            $display("EXPECTED_VTYPE Value : %d",VECTOR_PROCESSOR.inst_reg_rs2_data);
                                                            $display("ACTUAL_VL Value : %d",VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.csr_vl_q);
                                                            $display("EXPECTED_VL Value : %d",VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.csr_vl_q);    
                                                        end
                                                    end    
                                                    else begin  // Rd_ADDR != 0
                                                        if ((VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.csr_vtype_q == VECTOR_PROCESSOR.inst_reg_rs2_data) && 
                                                            (VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.csr_vl_q == VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.vlmax) )begin
                                                            $display("======================= TEST PASSED ==========================");
                                                            $display("Instruction : %h",instruction);
                                                            $display("VTYPE Value : %d",VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.csr_vtype_q);
                                                            $display("VL Value : %d",VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.csr_vl_q);
                                                        end
                                                        else begin
                                                            $display("======================= TEST FAILED ==========================");
                                                            $display("Instruction : %h",instruction);
                                                            $display("ACTUAL_VTYPE Value : %d",VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.csr_vtype_q);
                                                            $display("EXPECTED_VTYPE Value : %d",VECTOR_PROCESSOR.inst_reg_rs2_data);
                                                            $display("ACTUAL_VL Value : %d",VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.csr_vl_q);
                                                            $display("EXPECTED_VL Value : %d",VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.vlmax); 
                                                        end
                                                    end 
                                                end
                                                else begin
                                                    if ((VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.csr_vtype_q == VECTOR_PROCESSOR.inst_reg_rs2_data) && 
                                                        (VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.csr_vl_q == VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.vlen_compare) )begin
                                                        $display("======================= TEST PASSED ==========================");
                                                        $display("Instruction : %h",instruction);
                                                        $display("VTYPE Value : %d",VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.csr_vtype_q);
                                                        $display("VL Value : %d",VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.csr_vl_q);
                                                    end
                                                    else begin
                                                        $display("======================= TEST FAILED ==========================");
                                                        $display("Instruction : %h",instruction);
                                                        $display("ACTUAL_VTYPE Value : %d",VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.csr_vtype_q);
                                                        $display("EXPECTED_VTYPE Value : %d",VECTOR_PROCESSOR.inst_reg_rs2_data);
                                                        $display("ACTUAL_VL Value : %d",VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.csr_vl_q);
                                                        $display("EXPECTED_VL Value : %d",VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.vlen_compare);
                                                    end
                                                end  
                                            end
                                        default: ;
                                        endcase
                                    end
                                    default: ;
                                endcase
                            end

                            default: ;
                        endcase
                    end

                    // Vector load instructions
                    V_LOAD: begin
                                    
                    $display("======================= LOAD COMPLETE ==========================");
                    $display("Instruction : %h",instruction);        
                    end

                    V_STORE: begin
                        for (int i = 0 ; i < addr_array_index; i++)begin
                            if (test_mem[addr_array[i]] != u_axi_slave.memory[addr_array[i]])begin
                                $display("======================= LOAD STORE TEST FAILED ==========================");
                                $display("Instruction : %h",instruction);
                                $display("LOAD VALUE : %h",test_mem[addr_array[i]]);
                                $display("STORE VALUE : %h",u_axi_slave.memory[addr_array[i]]);
                                $display("ADDRESS : %h",addr_array[i]);
                                break;         
                            end
                        end
                        $display("======================= LOAD STORE TEST PASS  ==========================");
                        $display("Instruction : %h",instruction);
                    end 
                    default:  ;  
                endcase
            end
            $display("END MONITORING");    
        end
    endtask

endmodule