// Author       : Zawaher Bin Asim , UET Lahore  <zawaherbinasim.333@gmail.com>
// Date         : 1 Oct 2024
// Description  : This file contains the wrapper of the vector_processor where datapath and controller  are connnected together 

`include "vector_processor_defs.svh"
`include "axi_4_defs.svh"
import axi_4_pkg::*;

module vector_processor(
    
    input   logic   clk,reset,
    
    // Inputs from the scaler processor  --> vector processor
    input   logic   [`XLEN-1:0]             instruction,            // The instruction that is to be executed by the vector processor
    input   logic   [`XLEN-1:0]             rs1_data,               // The scaler input from the scaler processor for the instructon that needs data from the  scaler register file across the rs1 address
    input   logic   [`XLEN-1:0]             rs2_data,               // The scaler input from the scaler processor for the instructon that needs data from the  scaler register file across the rs2 address

     // scaler_procssor  --> val_ready_controller
    input   logic                           inst_valid,             // tells data comming from the saler processor is valid
    input   logic                           scalar_pro_ready,       // tells that scaler processor is ready to take output

    // Outputs from vector processor --> scaler processor 
    output  logic                           is_vec,                 // This tells the instruction is a vector instruction or not mean a legal insrtruction or not
    output  logic                           error,                  // error has occure due to invalid configurations
    
    // csr_regfile -> scalar_processor
    output  logic   [`XLEN-1:0]             csr_out,                // read data from the csr registers

    // valready_controller  --> scaler_processor 
    output  logic                           vec_pro_ack,            // signal that tells that successfully implemented the previous instruction and ready to  take next iinstruction

    // val_ready_controller --> scaler_processor
    output  logic                           vec_pro_ready,          // tells that vector processor is ready to take the instruction

    //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> AXI 4 SIGNALS <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<//

    // READ ADDRESS CHANNEL 
    input   logic                           s_arready,
    output  logic                           m_arvalid,
    
    // READ DATA CHANNEL
    input   logic                           s_rvalid,
    output  logic                           m_rready,

    // WRITE ADRRESS CHANNEL 
    input   logic                           s_awready,
    output  logic                           m_awvalid,

    // WRITE DATA CHANNEL
    input   logic                           s_wready,
    output  logic                           m_wvalid,

    // WRITE RESPONSE CHANNEL 
    input   logic                           s_bvalid,
    output  logic                           m_bready,
    
    // AXI 4 MASTER --> AXI4_SLAVE(MEMORY)  
    output  logic                           ld_req_reg ,st_req_reg,
    output  read_write_address_channel_t    re_wr_addr_channel,
    output  write_data_channel_t            wr_data_channel,

    // SLAVE(MEMORY) --> AXI 4 MASTER  
    input  wire read_data_channel_t              re_data_channel,
    input  wire write_response_channel_t         wr_resp_channel
);


// vec_control_signals -> vec_decode
logic                               vl_sel;             // selection for rs1_data or uimm
logic                               vtype_sel;          // selection for rs2_data or zimm
logic                               lumop_sel;          // selection lumop
logic                               rs1rd_de;           // selection for VLMAX or comparator

// vec_control_signals -> vec_csr
logic                               csrwr_en;
logic                               sew_eew_sel;       // selection for sew_eew mux
logic                               vlmax_evlmax_sel;  // selection for vlmax_evlmax
logic                               emul_vlmul_sel;    // selection for vlmul_emul m

// Vec_control_signals -> vec_registerfile
logic                               vec_reg_wr_en;      // The enable signal to write in the vector register
logic                               mask_operation;     // This signal tell this instruction is going to perform mask register update
logic                               mask_wr_en;         // This the enable signal for updating the mask value
logic   [1:0]                       data_mux1_sel;      // This the selsction of the mux to select between vec_imm , scaler1 , and vec_data1
logic                               data_mux2_sel;      // This the selsction of the mux to select between scaler2 , and vec_data2
logic                               offset_vec_en;      // Tells the rdata2 vector is offset vector and will be chosen on base of emul
// vec_control_signals -> vec_lsu
logic                               stride_sel;         // tells that  it is a unit stride or the constant stride
logic                               ld_inst;            // tells about load instruction
logic                               st_inst;            // tells about store instruction
logic                               index_str;          // tells about indexed strided load/store
logic                               index_unordered;    // tells about index unordered stride
// datapath --> val_ready_controller
logic                               inst_done;

// val_ready_controller --> datapath
logic                               inst_reg_en;

//vector processor lsu --> AXI 4 MASTER
logic   [`XLEN-1:0]                 lsu2mem_addr;           // Gives the memory address to load or store data
logic                               ld_req;                 // load request signal to the AXI 4 MASTER
logic                               st_req;                 // store request signal to the AXI 4 MASTER
logic   [`DATA_BUS*`BURST_MAX-1:0]  lsu2mem_data;           // Data to be stored
logic   [WR_STROB*`BURST_MAX-1:0]   wr_strobe;              // THE bytes of the DATA_BUS that contains the actual data 
logic   [7:0]                       burst_len;
logic   [2:0]                       burst_size;
logic   [1:0]                       burst_type;

// AXI 4 MASTER  -->  VLSU 
logic   [`DATA_BUS*`BURST_MAX-1:0]  mem2lsu_data;
logic                               burst_valid_data;
logic                               burst_wr_valid;

// Instruction Register --> datapath
logic   [`XLEN-1:0]                 inst_reg_instruction;            // The instruction that is to be executed by the vector processor
logic   [`XLEN-1:0]                 inst_reg_rs1_data;               // The scaler input from the scaler processor for the instructon that needs data from the  scaler register file across the rs1 address
logic   [`XLEN-1:0]                 inst_reg_rs2_data;               // The scaler input from the scaler processor for the instructon that needs data from the  scaler register file across the rs2 address


logic   [2:0]                       execution_op;
logic                               signed_mode;
logic                               Ctrl;
logic                               mul_low;
logic                               mul_high;

logic                               add_inst, sub_inst, reverse_sub_inst;
                              
logic                               shift_left_logical_inst, shift_right_arith_inst, shift_right_logical_inst;
                             
logic                               mul_inst;

logic                               equal_inst, not_equal_inst, les_or_equal_unsigned_inst, less_or_equal_signed_inst,
                                    less_unsinged_inst, greater_unsigned_inst, less_signed_inst, greater_signed_inst;

logic                               mul_add_dest_inst, mul_sub_dest_inst, mul_add_source_inst, mul_sub_source_inst;  

logic                               mask_and_inst, mask_nand_inst, mask_and_not_inst, mask_xor_inst, mask_or_inst, mask_nor_inst,
                                    mask_or_not_inst , mask_xnor_inst; 

logic                               red_sum_inst, red_max_unsigned_inst, red_max_signed_inst,
                                    red_min_signed_inst, red_min_unsigned_inst, red_and_inst , red_or_inst, red_xor_inst;
    
logic                               signed_min_inst, unsigned_min_inst, signed_max_inst, unsigned_max_inst; 
                                
logic                               move_inst; 

logic                               wid_add_signed_inst, wid_add_unsigned_inst, wid_sub_signed_inst, wid_sub_unsigned_inst; 

logic                               add_carry_inst_inst, sub_borrow_inst, add_carry_masked_inst, sub_borrow_masked_inst; 

logic                               sat_add_signed_inst, sat_add_unsigned_inst, sat_sub_signed_inst, sat_sub_unsigned_inst;

logic                               and_inst, or_inst, xor_inst;

logic   [4:0]                       bitwise_op;
logic   [2:0]                       cmp_op,accum_op,shift_op;
logic   [1:0]                       op_type;


    //==========================================================================//
    //                      MAIN DATAPTH INSTANTIATION                          //
    //==========================================================================//

    vector_processor_datapth DATAPATH(
        
        .clk                (clk                 ),
        .reset              (reset               ),
        
        // Inputs from the scaler processor  --> vector processor
        .instruction        (inst_reg_instruction),      
        .rs1_data           (inst_reg_rs1_data   ),
        .rs2_data           (inst_reg_rs2_data   ),

        // Outputs from vector rocessor --> scaler processor
        .is_vec             (is_vec              ),
        .error              (error               ),
        
        // Output from vector processor lsu --> AXI 4 MASTER
        .lsu2mem_addr       (lsu2mem_addr        ),
        .lsu2mem_data       (lsu2mem_data        ),
        .ld_req             (ld_req              ),
        .st_req             (st_req              ),
        .wr_strobe          (wr_strobe           ),
        .burst_len          (burst_len           ),
        .burst_size         (burst_size          ),
        .burst_type         (burst_type          ),

        
        //Inputs from main_memory -> vec_lsu
        // AXI 4 MASTER  -->  VLSU 
        .mem2lsu_data      (mem2lsu_data         ),
        .burst_valid_data  (burst_valid_data     ),
        .burst_wr_valid    (burst_wr_valid       ),

       
        // csr_regfile -> scalar_processor
        .csr_out            (csr_out             ),

        // datapth  --> val_ready_controller
        .inst_done          (inst_done           ),            

        // Inputs from the controller --> datapath
        .sew_eew_sel        (sew_eew_sel         ),
        .vlmax_evlmax_sel   (vlmax_evlmax_sel    ),
        .emul_vlmul_sel     (emul_vlmul_sel      ),

        // vec_control_signals -> vec_decode
        .vl_sel             (vl_sel              ),
        .vtype_sel          (vtype_sel           ),
        .lumop_sel          (lumop_sel           ),
        .rs1rd_de           (rs1rd_de            ),
        
        // vec_control_signals -> vec_csr_regs
        .csrwr_en           (csrwr_en            ),

        // vec_control_signals -> vec_register_file
        .vec_reg_wr_en      (vec_reg_wr_en       ),
        .mask_operation     (mask_operation      ),
        .mask_wr_en         (mask_wr_en          ),
        .data_mux1_sel      (data_mux1_sel       ),
        .data_mux2_sel      (data_mux2_sel       ),
        .offset_vec_en      (offset_vec_en       ),

        // vec_control_signals -> vec_lsu
        .stride_sel         (stride_sel          ),
        .ld_inst            (ld_inst             ),
        .st_inst            (st_inst             ),
        .index_str          (index_str           ), 
        .index_unordered    (index_unordered     ),
        
        .Ctrl               (Ctrl),
        .execution_op       (execution_op),
        .mul_high           (mul_high),
        .mul_low            (mul_low),
        .execution_inst     (execution_inst),
        .reverse_sub_inst   (reverse_sub_inst),
        .signed_mode        (signed_mode),
        .bitwise_op(bitwise_op),
        .op_type(op_type),
        .cmp_op(cmp_op),
        .accum_op(accum_op),
        .shift_op(shift_op)
    );


    //==========================================================================//
    //                  MAIN CONTROLLER INSTANTIATION                           //
    //==========================================================================//


    vector_processor_controller CONTROLLER(
        
        // scalar_processor -> vector_extension
        .vec_inst           (inst_reg_instruction),

        // Output from  controller --> datapath

        // vec_control_signals -> vec_decode
        .vl_sel             (vl_sel         ),
        .vtype_sel          (vtype_sel      ),
        .lumop_sel          (lumop_sel      ),
        
        // vec_control_signals -> vec_csr_regs
        .csrwr_en           (csrwr_en        ),
        .sew_eew_sel        (sew_eew_sel     ),
        .vlmax_evlmax_sel   (vlmax_evlmax_sel),
        .emul_vlmul_sel     (emul_vlmul_sel  ),
        .rs1rd_de           (rs1rd_de       ),

        // vec_control_signals -> vec_register_file
        .vec_reg_wr_en              (vec_reg_wr_en  ),
        .mask_operation             (mask_operation ),
        .mask_wr_en                 (mask_wr_en     ),
        .data_mux1_sel              (data_mux1_sel  ),
        .data_mux2_sel              (data_mux2_sel  ),
        .offset_vec_en              (offset_vec_en  ),

        // vec_control_signals -> vec_lsu
        .stride_sel                 (stride_sel     ),
        .ld_inst                    (ld_inst        ),
        .st_inst                    (st_inst        ),
        .index_str                  (index_str      ),
        .index_unordered            (index_unordered),

        .execution_op               (execution_op),
        
        .signed_mode                (signed_mode),
        .Ctrl                       (Ctrl),
        .mul_low                    (mul_low), 
        .mul_high                   (mul_high),

        .add_inst                   (add_inst), 
        .sub_inst                   (sub_inst), 
        .reverse_sub_inst           (reverse_sub_inst), 
        .shift_left_logical_inst    (shift_left_logical_inst), 
        .shift_right_arith_inst     (shift_right_arith_inst), 
        .shift_right_logical_inst   (shift_right_logical_inst),
        .execution_inst             (execution_inst),
        .mul_inst                   (mul_inst),
        .equal_inst                 (equal_inst), 
        .not_equal_inst             (not_equal_inst),
        .less_or_equal_unsigned_inst(less_or_equal_unsigned_inst),
        .less_or_equal_signed_inst  (less_or_equal_signed_inst), 
        .less_unsinged_inst         (less_unsinged_inst),
        .greater_unsigned_inst      (greater_unsigned_inst),
        .less_signed_inst           (less_signed_inst), 
        .greater_signed_inst        (greater_signed_inst), 
        .mul_add_dest_inst          (mul_add_dest_inst), 
        .mul_sub_dest_inst          (mul_sub_dest_inst), 
        .mul_add_source_inst        (mul_add_source_inst), 
        .mul_sub_source_inst        (mul_sub_source_inst),   
        .mask_and_inst              (mask_and_inst), 
        .mask_nand_inst             (mask_nand_inst), 
        .mask_and_not_inst          (mask_and_not_inst), 
        .mask_xor_inst              (mask_xor_inst), 
        .mask_or_inst               (mask_or_inst), 
        .mask_nor_inst              (mask_nor_inst),
        .mask_or_not_inst           (mask_or_not_inst) , 
        .mask_xnor_inst             (mask_xnor_inst), 
        .red_sum_inst               (red_sum_inst), 
        .red_max_unsigned_inst      (red_max_unsigned_inst), 
        .red_max_signed_inst        (red_max_signed_inst),
        .red_min_signed_inst        (red_min_signed_inst), 
        .red_min_unsigned_inst      (red_min_unsigned_inst), 
        .red_and_inst               (red_and_inst) , 
        .red_or_inst                (red_or_inst), 
        .red_xor_inst               (red_xor_inst),
        .signed_min_inst            (signed_min_inst),
        .unsigned_min_inst          (unsigned_min_inst), 
        .signed_max_inst            (signed_max_inst), 
        .unsigned_max_inst          (unsigned_max_inst), 
        .move_inst                  (move_inst), 
        .wid_add_signed_inst        (wid_add_signed_inst), 
        .wid_add_unsigned_inst      (wid_add_unsigned_inst), 
        .wid_sub_signed_inst        (wid_sub_signed_inst), 
        .wid_sub_unsigned_inst      (wid_sub_unsigned_inst), 
        .add_carry_inst_inst        (add_carry_inst_inst), 
        .sub_borrow_inst            (sub_borrow_inst), 
        .add_carry_masked_inst      (add_carry_masked_inst), 
        .sub_borrow_masked_inst     (sub_borrow_masked_inst), 
        .sat_add_signed_inst        (sat_add_signed_inst), 
        .sat_add_unsigned_inst      (sat_add_unsigned_inst), 
        .sat_sub_signed_inst        (sat_sub_signed_inst), 
        .sat_sub_unsigned_inst      (sat_sub_unsigned_inst),
        .and_inst                   (and_inst), 
        .or_inst                    (or_inst), 
        .xor_inst                   (xor_inst),
        .bitwise_op                 (bitwise_op),
        .op_type                    (op_type),
        .cmp_op                     (cmp_op),
        .shift_op                   (shift_op),
        .accum_op                    (accum_op)

    );

    //==========================================================================//
    //                  VAL READY INTERFACE INSTANTIATION                       //
    //==========================================================================//


    val_ready_controller VAL_READY_INTERFACE(
        
        .clk                (clk                ),
        .reset              (reset              ),

        // scaler_procssor  --> val_ready_controller
        .inst_valid         (inst_valid         ),             // tells data comming from the saler processor is valid
        .scalar_pro_ready   (scalar_pro_ready   ),       // tells that scaler processor is ready to take output
        
        // val_ready_controller --> scaler_processor
        .vec_pro_ready      (vec_pro_ready      ),          // tells that vector processor is ready to take the instruction
        .vec_pro_ack        (vec_pro_ack        ),             // tells that the data comming from the vec_procssor is valid and done with the implementation of instruction 

        // datapath -->   val_ready_controller 
        .inst_done          (inst_done          )
    );

    //==========================================================================//
    //                      AXI-4 MASTER INSTANTIATION                          //
    //==========================================================================//

    axi_4_master u_axi_4_master (
        .clk                    (clk                ),
        .reset                  (reset              ),

        // vector_processor vlsu  --> axi_4_master_controller
        .ld_req                 (ld_req             ),
        .st_req                 (st_req             ),

        //===================== axi_4 read address channel signals =========================//
        .s_arready              (s_arready          ),
        .m_arvalid              (m_arvalid          ),

        //===================== axi_4 read data channel signals =========================//
        .s_rvalid               (s_rvalid           ),
        .m_rready               (m_rready           ),

        //===================== axi_4 write address channel signals =========================//
        .s_awready              (s_awready          ),
        .m_awvalid              (m_awvalid          ),

        //===================== axi_4 write data channel signals =========================//
        .s_wready               (s_wready           ),
        .m_wvalid               (m_wvalid           ),

        //===================== axi_4 write response channel signals =========================//
        .s_bvalid               (s_bvalid           ),
        .m_bready               (m_bready           ),

        // VLSU -->   AXI 4 MASTER
        .base_addr              (lsu2mem_addr       ),
        .vlsu_wdata             (lsu2mem_data       ),
        .write_strobe           (wr_strobe          ),
        .burst_len              (burst_len          ),
        .burst_size             (burst_size         ),
        .burst_type             (burst_type         ),

        // AXI 4 MASTER  -->  VLSU 
        .burst_rdata_array      (mem2lsu_data       ),
        .burst_valid_data       (burst_valid_data   ),
        .burst_wr_valid         (burst_wr_valid     ),

        // AXI 4 MASTER --> AXI4_SLAVE  
        .ld_req_reg             (ld_req_reg         ),
        .st_req_reg             (st_req_reg         ),
        .re_wr_addr_channel     (re_wr_addr_channel ),
        .wr_data_channel        (wr_data_channel    ),

        // SLAVE(MEMORY) --> AXI 4 MASTER  
        .re_data_channel        (re_data_channel    ),
        .wr_resp_channel        (wr_resp_channel    )
    );


    //==========================================================================//
    //                    INSTRUCTION QUEUE INSTANTIATION                       //
    //==========================================================================//


    instruction_data_queue INS_DATA_QUEUE(
        .clk                    (clk                ),
        .reset                  (reset              ),
        // Scaler Processor --> Queue 
        .inst_valid             (inst_valid         ), 
        .instruction            (instruction        ), 
        .rs1_data               (rs1_data           ), 
        .rs2_data               (rs2_data           ),  
        
        // VAL_READY_Controller --> Queue
        .vec_pro_ready          (vec_pro_ready      ),  
        
        // Queue --> Vector Processor
        .inst_reg_instruction   (inst_reg_instruction), 
        .inst_reg_rs1_data      (inst_reg_rs1_data   ), 
        .inst_reg_rs2_data      (inst_reg_rs2_data   )  
    );

endmodule


/*
Logic Description:

    Bypass Cases:
        Simultaneous Assertion: If inst_valid and vec_pro_ready are asserted in the same cycle, bypass the queue and directly output the data.
        vec_pro_ready Asserted Before inst_valid: If vec_pro_ready was asserted first, 
        and inst_valid is asserted later, bypass the queue and directly output the current data.

    Enqueue Case:
        If inst_valid is asserted and vec_pro_ready is not, enqueue the instruction and data.

    Dequeue Case:
        If inst_valid is already asserted (data is in the queue), and vec_pro_ready becomes asserted, dequeue and output the instruction and data.

*/
module instruction_data_queue #(

    parameter DEPTH = 2    // Queue depth
) (
    input  logic                clk,
    input  logic                reset,
    // Scaler Processor --> Queue 
    input  logic                inst_valid,       // Instruction valid
    input  logic [`XLEN-1:0]    instruction,      // Instruction input
    input  logic [`XLEN-1:0]    rs1_data,         // RS1 data
    input  logic [`XLEN-1:0]    rs2_data,         // RS2 data
    
     // VAL_READY_Controller --> Queue
    input  logic                 vec_pro_ready,   // Vector processor ready
    
    // Queue --> Vector Processor
    output logic [`XLEN-1:0]    inst_reg_instruction,     // Output instruction
    output logic [`XLEN-1:0]    inst_reg_rs1_data,        // Output RS1 data
    output logic [`XLEN-1:0]    inst_reg_rs2_data         // Output RS2 data
);

    logic [`XLEN-1:0]    inst_out_instruction;     // Dummy Output instruction
    logic [`XLEN-1:0]    inst_out_rs1_data;        // Dummy Output RS1 data
    logic [`XLEN-1:0]    inst_out_rs2_data;        // Dummy Output RS2 data

    // FIFO storage for instructions and data
    typedef struct packed {
        logic [`XLEN-1:0] instruction;
        logic [`XLEN-1:0] rs1_data;
        logic [`XLEN-1:0] rs2_data;
    } queue_entry_t;

    queue_entry_t fifo [DEPTH-1:0];

    logic [$clog2(DEPTH):0] write_ptr, read_ptr;
    logic [$clog2(DEPTH+1):0] count;

    // Status flags
    wire full  = (count == DEPTH);
    wire empty = (count == 0);

    // Handshake signal
    logic inst_accepted;
    logic inst_ready;

     // Bypass signals
    logic bypass;
    logic inst_valid_seen;  // Tracks whether inst_valid has been asserted

    always_ff @( posedge clk or negedge clk ) begin 
        if (!reset)begin
            inst_valid_seen <= 1'b0;
        end
        else begin
            if (inst_valid && !vec_pro_ready)begin
                inst_valid_seen <= 1'b1;
            end
            else begin
                inst_valid_seen <= 1'b0;
            end
        end
        
    end


    assign bypass = (inst_valid && vec_pro_ready && !inst_valid_seen);

    // Output logic with bypass handling
   always_ff @(posedge clk or negedge reset) begin
        if (!reset) begin
            inst_out_instruction <= 0;
            inst_out_rs1_data    <= 0;
            inst_out_rs2_data    <= 0;
            read_ptr             <= 0;
            write_ptr <= 0;
            count <= 0;
            inst_accepted <= 0;
        end else if (bypass) begin
            // Directly bypass the input instruction and data to output
            inst_out_instruction <= instruction;
            inst_out_rs1_data    <= rs1_data;
            inst_out_rs2_data    <= rs2_data;
        end else if (!empty && vec_pro_ready) begin
            // Update read pointer and prepare for next cycle
            read_ptr <= read_ptr + 1;
            count    <= count - 1;
        end else begin
            if (inst_valid && inst_ready && !inst_accepted) begin
                // Store the instruction and data in the queue
                fifo[write_ptr].instruction <= instruction;
                fifo[write_ptr].rs1_data    <= rs1_data;
                fifo[write_ptr].rs2_data    <= rs2_data;
                write_ptr <= write_ptr + 1;
                count <= count + 1;

                // Mark instruction as accepted
                inst_accepted <= 1;
            end else if (!inst_valid) begin
                // Reset the accepted flag when inst_valid deasserts
                inst_accepted <= 0;
            end
        end
    end

    // Combinational output logic for immediate dequeued data
    always_comb begin
        if (bypass) begin
            // Directly pass the input instruction and data to the output
            inst_reg_instruction = instruction;
            inst_reg_rs1_data    = rs1_data;
            inst_reg_rs2_data    = rs2_data;
        end else if (!empty && vec_pro_ready) begin
            // Directly use the data from the queue for immediate output
            inst_reg_instruction = fifo[read_ptr].instruction;
            inst_reg_rs1_data    = fifo[read_ptr].rs1_data;
            inst_reg_rs2_data    = fifo[read_ptr].rs2_data;
        end else begin
            // Hold the current values
            inst_reg_instruction = inst_out_instruction;
            inst_reg_rs1_data    = inst_out_rs1_data;
            inst_reg_rs2_data    = inst_out_rs2_data;
        end
    end

    assign inst_ready = !full && !vec_pro_ready;
    
endmodule









