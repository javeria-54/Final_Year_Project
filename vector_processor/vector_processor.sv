// Author       : Zawaher Bin Asim , UET Lahore  <zawaherbinasim.333@gmail.com>
// Date         : 1 Oct 2024
// Description  : This file contains the wrapper of the vector_processor where datapath and controller  are connnected together 

`include "vector_processor_defs.svh"
`include "axi_4_defs.svh"

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
    input  logic                            is_vec,                 // This tells the instruction is a vector instruction or not mean a legal insrtruction or not
    output  logic                           error,                  // error has occure due to invalid configurations
    output  logic   [4:0]                   vec_read_addr_1  , vec_read_addr_2 , vec_write_addr,
    output  logic   [`MAX_VLEN-1:0]             vec_wr_data,
    output logic execution_inst,
    
    // csr_regfile -> scalar_processor
    output  logic   [`XLEN-1:0]             csr_out,                // read data from the csr registers
    input  logic   [`Tag_Width-1:0]         seq_num_i,
    output  logic   [`Tag_Width-1:0]        seq_num_o,
    input logic rob_commit_valid_i,
    output logic is_loaded,is_stored,csr_done,execution_done,
    output logic [`MAX_VLEN-1:0] execution_result,

    // valready_controller  --> scaler_processor 
    input  logic                           vec_pro_ack,            // signal that tells that successfully implemented the previous instruction and ready to  take next iinstruction
    
    output logic [31:0]                     mem_addr,
    output logic [511:0]                    mem_wdata,
    output logic [511:0]                    mem_wdata_unit,
    output logic [63:0]                     mem_byte_en,
    output logic                            mem_wen,
    output logic                            mem_ren,
    output logic                            mem_elem_mode,
    output logic [1:0]                      mem_sew_enc,
    input  logic [511:0]                    mem_rdata,

    input logic [4:0] rob_commit_vd,
    input logic [`MAX_VLEN-1:0]  rob_commit_vector_result,

    // val_ready_controller --> scaler_processor
    input   logic                           vec_pro_ready          // tells that vector processor is ready to take the instruction
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
logic                               data_mux2_sel,data_mux3_sel;      // This the selsction of the mux to select between scaler2 , and vec_data2
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
//logic                               inst_reg_en;

logic   [2:0]                       execution_op;
logic                               signed_mode;
logic                               Ctrl,start;
logic                               mul_low;
logic                               mul_high;

logic                               add_inst, sub_inst, reverse_sub_inst;
                              
logic                               shift_left_logical_inst, shift_right_arith_inst, shift_right_logical_inst;
                             
logic                               mul_inst;

logic                               equal_inst, not_equal_inst, less_or_equal_unsigned_inst, less_or_equal_signed_inst, 
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
logic   [3:0]                       mask_op;
logic   [2:0]                       cmp_op,accum_op,shift_op;
logic   [1:0]                       op_type; 


    //==========================================================================//
    //                      MAIN DATAPTH INSTANTIATION                          //
    //==========================================================================//

    vector_processor_datapth DATAPATH(
        
        .clk                (clk                 ),
        .reset              (reset               ),
        
        // Inputs from the scaler processor  --> vector processor
        .instruction        (instruction),      
        .rs1_data           (rs1_data   ),
        .rs2_data           (rs2_data   ),

        // Outputs from vector rocessor --> scaler processor
        .is_vec             (is_vec              ),
        .error              (error               ),

        .mem_addr           (mem_addr                   ),
        .mem_wdata          (mem_wdata                  ),
        .mem_wdata_unit     (mem_wdata_unit             ),
        .mem_byte_en        (mem_byte_en                ),
        .mem_wen            (mem_wen                    ),
        .mem_ren            (mem_ren                    ),
        .mem_elem_mode      (mem_elem_mode              ),
        .mem_sew_enc        (mem_sew_enc                ),
        .mem_rdata          (mem_rdata                  ),

        .vec_commit_vd_i             (rob_commit_vd),
        .vec_commit_vector_result_i  (rob_commit_vector_result),
        .rob_commit_valid_i          (rob_commit_valid_i),
        .is_loaded(is_loaded),
        .is_stored(is_stored),
        .csr_done(csr_done),
        .execution_done(execution_done),
        .execution_result(execution_result),
        .vec_read_addr_1(vec_read_addr_1),
        .vec_read_addr_2(vec_read_addr_2),
        .vec_write_addr(vec_write_addr),

       
        // csr_regfile -> scalar_processor
        .csr_out            (csr_out             ),

        // datapth  --> val_ready_controller
        .inst_done          (inst_done           ), 
        .seq_num_i          (seq_num_i),
        .seq_num_o          (seq_num_o),           

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

        .vec_wr_data        (vec_wr_data),

        // vec_control_signals -> vec_register_file
        .vec_reg_wr_en      (vec_reg_wr_en       ),
        .mask_operation     (mask_operation      ),
        .mask_wr_en         (mask_wr_en          ),
        .data_mux1_sel      (data_mux1_sel       ),
        .data_mux2_sel      (data_mux2_sel       ),
        .data_mux3_sel      (data_mux3_sel       ),
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
        .add_inst           (add_inst),
        .sub_inst           (sub_inst),
        .signed_mode        (signed_mode),
        .bitwise_op         (bitwise_op),
        .op_type            (op_type),
        .cmp_op             (cmp_op),
        .accum_op           (accum_op),
        .mask_op            (mask_op),
        .start              (start),
        .shift_op           (shift_op)
    );


    //==========================================================================//
    //                  MAIN CONTROLLER INSTANTIATION                           //
    //==========================================================================//


    vector_processor_controller CONTROLLER(
        
        // scalar_processor -> vector_extension
        .vec_inst           (instruction),

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
        .data_mux3_sel              (data_mux3_sel  ),
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
        .start(start),

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
        .mask_op                    (mask_op),
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

endmodule
