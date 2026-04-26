// Author       : Zawaher Bin Asim , UET Lahore  <zawaherbinasim.333@gmail.com>
// Date         : 23 Sep 2024
// Description  : This file contains the  datapath of the vector_processor where different units are connnected together 

`include "vector_processor_defs.svh"
`include "vector_regfile_defs.svh"
`include "axi_4_defs.svh"

module vector_processor_datapth (
    
    input   logic   clk,reset,
    
    // Inputs from the scaler processor  --> vector processor
    input   logic   [`XLEN-1:0]                 instruction,        // The instruction that is to be executed by the vector processor
    input   logic   [`XLEN-1:0]                 rs1_data,           // The scaler input from the scaler processor for the instructon that needs data from the  scaler register file across the rs1 address
    input   logic   [`XLEN-1:0]                 rs2_data,           // The scaler input from the scaler processor for the instructon that needs data from the  scaler register file across the rs2 address
    
    // Output from  vec_lsu -> 
    output  logic                               ld_req,                 // load request signal to the AXI 4 MASTER
    output  logic                               st_req,                 // store request signal to the AXI 4 MASTER

    output logic [31:0]             mem_addr,
    output logic [511:0]            mem_wdata,
    output logic [511:0]            mem_wdata_unit,
    output logic [63:0]             mem_byte_en,
    output logic                    mem_wen,
    output logic                    mem_ren,
    output logic                    mem_elem_mode,
    output logic [1:0]              mem_sew_enc,
    input  logic [511:0]            mem_rdata,

    // Outputs from vector rocessor --> scaler processor
    input  logic                                is_vec,             // This tells the instruction is a vector instruction or not mean a legal insrtruction or not
    output  logic                               error,              // error has occure due to invalid configurations
    
    // csr_regfile -> scalar_processor
    output  logic   [`XLEN-1:0]                 csr_out,            

    // datapth  --> scaler_processor 
    output  logic                               inst_done,          // signal that tells that successfully implemented the previous instruction and ready to  take next iinstruction

    // Inputs from the controller --> datapath
    
    input  logic                                sew_eew_sel,        // selection for sew_eew mux
    input  logic                                vlmax_evlmax_sel,   // selection for vlmax_evlmax mux
    input  logic                                emul_vlmul_sel,     // selection for vlmul_emul mux
    // vec_control_signals -> vec_decode
    input   logic                               vl_sel,             // selection for rs1_data or uimm
    input   logic                               vtype_sel,          // selection for rs2_data or zimm
    input   logic                               lumop_sel,          // selection lumop
    
    // vec_control_signals -> vec_csr_regs
    input   logic                               csrwr_en,
    input   logic                               rs1rd_de,           // selection for VLMAX or comparator
    
    // vec_control_signals -> vec_register_file
    input   logic                               vec_reg_wr_en,     // The enable signal to write in the vector register
    input   logic                               mask_operation,    // This signal tell this instruction is going to perform mask register update
    input   logic                               mask_wr_en,        // This the enable signal for updating the mask value
    input   logic                               offset_vec_en,     // Tells the rdata2 vector is offset vector and will be chosen on base of emul
    input   logic   [1:0]                       data_mux1_sel,     // This the selsction of the mux to select between vec_imm , scaler1 , and vec_data1
    input   logic                               data_mux2_sel,     // This the selsction of the mux to select between scaler2 , and vec_data2
    input   logic                               data_mux3_sel,

    // vec_control_signals -> vec_lsu
    input   logic                               stride_sel,         // tells that  it is a unit stride or the indexed
    input   logic                               ld_inst,            // tells that it is load insruction or store one
    input   logic                               st_inst,            // Store instruction
    input   logic                               index_str,          // tells about index stride
    input   logic                               index_unordered,     // tells about index unordered stride

    output  logic   [`MAX_VLEN-1:0]             vec_wr_data,
    input   logic   [`Tag_Width-1:0]            seq_num_i,
    output  logic   [`Tag_Width-1:0]            seq_num_o,
    output  logic                               execution_done,
    output  logic                               data_written,           // tells that data is written to the register file
    // Output from csr_reg--> datapath (done signal)
    output  logic                               csr_done,               // This signal tells that csr instruction has been implemented successfully
    output logic                                is_stored,              // It tells that data is stored to the memory
    output logic    [`MAX_VLEN-1:0]     execution_result,


    output  logic   [4:0]                 vec_read_addr_1  , vec_read_addr_2 , vec_write_addr,

    input   logic                               Ctrl,start,
    input   logic   [2:0]                       execution_op,
    input   logic                               mul_high, mul_low, execution_inst,reverse_sub_inst,add_inst, sub_inst,
    input   logic                               signed_mode,
    input   logic   [4:0]                       bitwise_op, 
    input   logic   [3:0]                       mask_op,
    input   logic   [2:0]                       cmp_op, accum_op,shift_op,
    input   logic   [1:0]                       op_type
);


// Read and Write address from Decode --> Vector Register file 


// Vector Immediate from the decode 
logic   [`MAX_VLEN-1:0] vec_imm;

// signal that tells that if the masking is  enabled or not
logic  vec_mask;

// The enable  signal for the vec_register file after the load of the data from the memory
logic   vec_wr_en;

// The width of the memory element that has to be loaded from the memory
logic   [2:0] width;

// it tells the selection between  the floating point  and the integer
logic   mew;

// number of fields in case of the load
logic   [2:0] nf;

// vec-csr-dec -> vec-csr / vec-regfile
// The scaler output from the decode that could be imm ,rs1_data ,rs2_data and address in case of the load based on the instruction 
logic   [`XLEN-1:0] scalar1;
logic   [`XLEN-1:0] scalar2;

// Output from vector processor lsu --> lsu mux
logic               is_loaded;              // It tells that data is loaded from the memory and ready to be written in register file

logic               error_flag;             // It tells that wrong configurations has occure   

// The extended scaler 1 and scaler 2 upto MAX_VLEN
logic   [`MAX_VLEN-1:0] scaler1_extended ,scaler2_extended; 

// The vector data that is to be written\


// vec_csr_regs ->
logic   [3:0]                   vlmul,emul;             // Gives the value of the lmul that is to used  in the procesor
logic   [6:0]                   sew,eew;                // Gives the standard element width 
logic   [9:0]                   vlmax,e_vlmax;          // the maximum number of elements vector will contain based on the lmul and sew and vlen
logic                           tail_agnostic;          // vector tail agnostic
logic                           mask_agnostic;          // vector mask agnostic
logic   [`XLEN-1:0]             vec_length;             // Gives the length of the vector onwhich maskng operation is to performed
logic   [`XLEN-1:0]             start_element;          // Gives the start elemnet of the vector from where the masking is to be started

 

// vec_registerfile --> next moduels and data selection muxes
logic   [`MAX_VLEN-1:0]         vec_data_1, vec_data_2, vec_data_3; // The read data from the vector register file
logic   [`MAX_VLEN-1:0]         dst_vec_data;           // The data of the destination register that is to be replaced with the data after the opertaion and masking
logic   [VECTOR_LENGTH-1:0]     vector_length;          // Width of the vector depending on LMUL
logic                           wrong_addr;             // Signal to indicate an invalid address
logic   [`VLEN-1:0]             v0_mask_data;           // The data of the mask register that is v0 in register file 


// Outputs of the data selection muxes after register file
logic   [`MAX_VLEN-1:0]         data_mux1_out;          // selection between the vec_reg_data_1 , vec_imm , scalar1
logic   [`MAX_VLEN-1:0]         data_mux2_out;          // selection between the vec_reg_data_2 , scaler2
logic   [`MAX_VLEN-1:0]         data_mux3_out;          // selection between the vec_reg_data_2 , scaler2

// Outputs of the sew eew mux after the decode and csr
logic   [6:0]                  sew_eew_mux_out;         // selection between sew and eew

// Outputs of the lmul emul mux after the decode and csr
logic   [3:0]                  vlmul_emul_mux_out;      // selection between lmul and emul

// Outputs of the sew eew mux after the decode and csr
logic   [9:0]                  vlmax_evlmax_mux_out;    // selection between vlmax and e_vlmax



logic   [1:0]               sew_execution;         
logic   [`MAX_VLEN-1:0]     vd_data;

logic   [`VLEN-1:0]         vs1,vs2;
logic   [4095:0]            mask_unit_output;
logic   [511:0]             mask_reg_updated;
logic   [63:0]              adder_carry_out;
logic [1:0] sew_sel;
logic [63:0] carry_out_mask;

assign inst_done = data_written || csr_done || is_stored || error || execution_done;
assign error     = error_flag || wrong_addr;
assign seq_num_o = seq_num_i;

             //////////////////////
            //      DECODE      //
           //////////////////////   
logic [4:0] vector_write_address;       

    vec_decode DECODER(
        // scalar_processor -> vec_decode
        .vec_inst           (instruction    ),
        .rs1_data           (rs1_data       ), 
        .rs2_data           (rs2_data       ),

        // vec_decode -> scalar_processor
        .is_vec             (is_vec         ),
        
        // vec_decode -> vec_regfile
        .vec_read_addr_1    (vec_read_addr_1),      
        .vec_read_addr_2    (vec_read_addr_2),   
        .vec_read_addr_3    (vector_write_address),
        .vec_write_addr     (vec_write_addr ),      
        .vec_imm            (vec_imm        ),
        .vec_mask           (vec_mask       ),

        // vec_decode -> vector load
        .width              (width          ),             
        .mew                (mew            ),             
        .nf                 (nf             ),                       

        // vec_decode -> csr 
        .scalar2            (scalar2        ),             
        .scalar1            (scalar1        ),             

        // vec_control_signals -> vec_decode
        .vl_sel             (vl_sel         ),             
        .vtype_sel          (vtype_sel      ),             
        .lumop_sel          (lumop_sel      )             
    );


             /////////////////////
            //   CSR REGFILE   //
           /////////////////////


    vec_csr_regfile CSR_REGFILE(
        .clk                    (clk            ),
        .n_rst                  (reset          ),

        // scalar_processor -> csr_regfile
        .inst                   (instruction    ),

        // csr_regfile -> scalar_processor
        .csr_out                (csr_out        ),

        // vec_controller -> csr_regfile
        .rs1rd_de               (rs1rd_de       ),
        
        // vec_decode -> vec_csr_regs
        .scalar2                (scalar2        ), 
        .scalar1                (scalar1        ),
        .width                  (width          ),
     

        // vec_control_signals -> vec_csr_regs
        .csrwr_en               (csrwr_en       ),

        // vec_csr_regs ->
        .vlmul                  (vlmul          ),
        .sew                    (sew            ),
        .vlmax                  (vlmax          ),
        .emul                   (emul           ),
        .eew                    (eew            ),
        .e_vlmax                (e_vlmax        ),

        .tail_agnostic          (tail_agnostic  ), 
        .mask_agnostic          (mask_agnostic  ), 

        .vec_length             (vec_length     ),
        .start_element          (start_element  ),

        .csr_done               (csr_done       )
    );


             /////////////////////
            //   SEW/EEW MUX   //
           /////////////////////

    data_mux_2x1 #(.width(7)) SEW_EEW_MUX( 
        
        .operand1       (sew                ),
        .operand2       (eew                ),
        .sel            (sew_eew_sel        ),
        .mux_out        (sew_eew_mux_out    )     
    );


             /////////////////////
            // LMUL/EMUL MUX   //
           /////////////////////

    data_mux_2x1 #(.width(4)) LMUL_EMUL_MUX( 
        
        .operand1       (vlmul              ),
        .operand2       (emul               ),
        .sel            (emul_vlmul_sel     ),
        .mux_out        (vlmul_emul_mux_out )     
    );



             ///////////////////////////
            //  VLMAX/ E_VLMAX MUX   //
           ///////////////////////////

    data_mux_2x1 #(.width(10)) VLMAX_EVLMAX_MUX( 
        
        .operand1       (vlmax               ),
        .operand2       (e_vlmax             ),
        .sel            (vlmax_evlmax_sel    ),
        .mux_out        (vlmax_evlmax_mux_out)     
    );

             /////////////////////
            //   VEC REGFILE   //
           /////////////////////



    vec_regfile VEC_REGFILE(
        // Inputs
        .clk            (clk                ), 
        .reset          (reset              ),
        .raddr_1        (vec_read_addr_1    ), 
        .raddr_2        (vec_read_addr_2    ),  
        .wdata          (vec_wr_data        ),          
        .waddr          (vec_write_addr     ),
        .wr_en          (vec_wr_en          ), 
        .lmul           (vlmul_emul_mux_out ),
        .emul           (emul               ),
        .offset_vec_en  (offset_vec_en      ),
        .mask_operation (mask_operation     ), 
        .mask_wr_en     (mask_wr_en         ), 
        
        // Outputs 
        .rdata_1        (vec_data_1         ),
        .rdata_2        (vec_data_2         ),
        .rdata_3        (vec_data_3         ),
        .dst_data       (dst_vec_data       ),
        .vector_length  (vector_length      ),
        .wrong_addr     (wrong_addr         ),
        .v0_mask_data   (v0_mask_data       ),
        .data_written   (data_written       )  
    );

    logic [4:0] vec_imm_selected;
    logic [`MAX_VLEN-1:0] vec_imm_extended;
    assign vec_imm_selected = vec_imm[4:0];

    always_comb begin
        if (execution_inst) begin
            case (sew_execution)
                // SEW=8  → 5-bit to 8-bit sign extend, phir replicate
                2'b00: vec_imm_extended = {(`MAX_VLEN/8) {{{3{vec_imm_selected[4]}}, vec_imm_selected}}};
                
                // SEW=16 → 5-bit to 16-bit sign extend, phir replicate
                2'b01: vec_imm_extended = {(`MAX_VLEN/16){{{11{vec_imm_selected[4]}}, vec_imm_selected}}};
                
                // SEW=32 → 5-bit to 32-bit sign extend, phir replicate
                2'b10: vec_imm_extended = {(`MAX_VLEN/32){{{27{vec_imm_selected[4]}}, vec_imm_selected}}};
                
                default: vec_imm_extended = '0;
            endcase
        end else begin
            vec_imm_extended = '0;
        end
    end

    always_comb begin 
         // Zero-extend  scalar1 dynamically
        if (execution_inst) begin
            scaler1_extended = {(`MAX_VLEN/`XLEN){scalar1}};
        end 
        else begin
            scaler1_extended = {{`MAX_VLEN -`XLEN{1'b0}}, scalar1[`XLEN-1:0]};
        end
        //assign scaler1_extended = {{`MAX_VLEN -`XLEN{1'b0}}, scalar1[`XLEN-1:0]};
        //assign scaler1_extended = {(`MAX_VLEN/`XLEN){scalar1}};

        // Zero-extend  scalar1 dynamically
        if (execution_inst) begin
            scaler2_extended = {(`MAX_VLEN/`XLEN){scalar2}};
        end 
        else begin
            scaler2_extended = {{`MAX_VLEN -`XLEN{1'b0}}, scalar2[`XLEN-1:0]};
        end
        //assign scaler2_extended = {{`MAX_VLEN -`XLEN{1'b0}}, scalar2[`XLEN-1:0]};
        //assign scaler2_extended = {(`MAX_VLEN/`XLEN){scalar2}};
    end

             /////////////////////
            //    DATA_1 MUX   //
           /////////////////////

    data_mux_3x1 #(.width(`MAX_VLEN)) DATA1_MUX( 
        
        .operand1       (vec_data_1         ),
        .operand2       (scaler1_extended   ),
        .operand3       (vec_imm_extended  ),
        .sel            (data_mux1_sel      ),
        .mux_out        (data_mux1_out      )     
    );

             /////////////////////
            //    DATA_2 MUX   //
           /////////////////////

    data_mux_2x1 #(.width(`MAX_VLEN)) DATA2_MUX( 
        
        .operand1       (vec_data_2         ),
        .operand2       (scaler2_extended   ),
        .sel            (data_mux2_sel      ),
        .mux_out        (data_mux2_out      )     
    );

    data_mux_2x1 #(.width(`MAX_VLEN)) DATA3_MUX( 
        
        .operand1       (4096'b0            ),
        .operand2       (vec_data_3         ),
        .sel            (data_mux3_sel      ),
        .mux_out        (data_mux3_out      )     
    );

             //////////////////////
            //      VLSU        //
           //////////////////////          

    logic elem_mode;


    vec_lsu VLSU(
        .clk                (clk                        ),
        .n_rst              (reset                      ),

        // scalar-processor -> vec_lsu
        .rs1_data           (data_mux1_out[`XLEN-1:0]   ),  
        .rs2_data           (data_mux2_out[`XLEN-1:0]   ),

        // vector_processor_controller -> vec_lsu
        .stride_sel         (stride_sel                 ), 
        .ld_inst            (ld_inst                    ),      
        .st_inst            (st_inst                    ),
        .index_str          (index_str                  ),
        .index_unordered    (index_unordered            ),

        // vec_decode -> vec_lsu
        .mew                (mew                        ),          
        .width              (width                      ),

        // vec_csr --> vec_lsu
        .sew                (sew_eew_mux_out            ),
        .vlmax              (vlmax_evlmax_mux_out       ),      

        // vec_register_file -> vec_lsu
        .vs2_data           (data_mux2_out              ),       
        .vs3_data           (dst_vec_data               ),      
        
        // datapath -->  vec_lsu        
        .inst_done          (inst_done                  ),

        .mem_addr           (mem_addr                   ),
        .mem_wdata          (mem_wdata                  ),
        .mem_wdata_unit     (mem_wdata_unit             ),
        .mem_byte_en        (mem_byte_en                ),
        .mem_wen            (mem_wen                    ),
        .mem_ren            (mem_ren                    ),
        .mem_elem_mode      (mem_elem_mode              ),
        .mem_sew_enc        (mem_sew_enc                ),
        .mem_rdata          (mem_rdata                  ),
 
        .seq_num(seq_num),
        // vec_lsu  -> vec_register_file
        .vd_data            (vd_data                    ), 
        .is_loaded          (is_loaded                  ),
        .is_stored          (is_stored                  ),
        .error_flag         (error_flag                 )  
    );


    data_mux_2x1 #(.width(1'b1)) VLSU_DATA_MUX(
        
        .operand1       (1'b0                     ),
        .operand2       (vec_reg_wr_en            ),
        .sel            (is_loaded && !error_flag ),
        .mux_out        (vec_wr_en                )     
    
    );

    assign vec_wr_data = execution_inst ? execution_result : vd_data ;
    
    vector_execution_unit EXECUTION_UNIT(

        .clk                (clk),
        .reset              (reset),

        .data_1             (data_mux1_out[`MAX_VLEN-1:0]),
        .data_2             (data_mux2_out[`MAX_VLEN-1:0]), 
        .data_3             (vec_data_3),

        .seq_num(seq_num),
        .Ctrl               (Ctrl),
        .sew_eew_mux_out    (sew_eew_mux_out),
        .execution_op       (execution_op),
        .signed_mode        (signed_mode),
        .mul_high           (mul_high),
        .mul_low            (mul_low), 
        .reverse_sub_inst   (reverse_sub_inst),
        .add_inst           (add_inst),
        .sub_inst           (sub_inst),
        .bitwise_op         (bitwise_op),
        .cmp_op             (cmp_op),
        .accum_op           (accum_op),
        .shift_op           (shift_op),
        .execution_result   (execution_result),
        .sew                (sew_execution),  
        .carry_out          (adder_carry_out),                 
        .start              (start),
        .mask_reg_updated   (mask_reg_updated),
        .carry_out_mask     (carry_out_mask),
        .execution_done     (execution_done)
);

    // vs1 mux — mask_operation ho to lower 512 bits, warna poora data
    assign vs1 = mask_operation ? vec_data_1[`VLEN-1:0] : 'b0;

    // vs2 mux — mask_operation ho to lower 512 bits, warna poora data  
    assign vs2 = mask_operation ? vec_data_2[`VLEN-1:0] : 'b0;

    vector_mask_unit MASK_UNIT(
        .lanes_data_out     (execution_result),
        .destination_data   (vd_data),
        .mask_op            (mask_op),
        .mask_en            (mask_operation),
        .mask_reg_en        (mask_wr_en),
        .vta                (tail_agnostic),
        .vma                (mask_agnostic),
        .vstart             (start_element),
        .vl                 (vec_length),
        .sew                (sew_eew_mux_out),
        .vs1                (vs1),  
        .vs2                (vs2),   
        .v0                 (v0_mask_data),
        .sew_sel            (sew_sel),
        .carry_out           (carry_out_mask),
        .mask_unit_output   (mask_unit_output),
        .mask_reg_updated   (mask_reg_updated)     
    );

endmodule

module data_mux_2x1 #(
   parameter width = `MAX_VLEN
) ( 
    
    input   logic   [width-1:0] operand1,
    input   logic   [width-1:0] operand2,
    input   logic               sel,
    output  logic   [width-1:0] mux_out     
);
    always_comb begin 
        case (sel)
           1'b0 : mux_out = operand1;
           1'b1 : mux_out = operand2;
            default: mux_out = 'h0;
        endcase        
    end
    
endmodule


module data_mux_3x1 #(
   parameter width = `MAX_VLEN
) ( 
    
    input   logic   [width-1:0] operand1,
    input   logic   [width-1:0] operand2,
    input   logic   [width-1:0] operand3,
    input   logic   [1:0]       sel,
    output  logic   [width-1:0] mux_out     
);
    always_comb begin 
        case (sel)
           2'b00 : mux_out = operand1;
           2'b01 : mux_out = operand2;
           2'b10 : mux_out = operand3;
            default: mux_out = 'h0;
        endcase        
    end
    
endmodule