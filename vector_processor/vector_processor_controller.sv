`include "vec_de_csr_defs.svh"
`include "vector_processor_defs.svh"

module vector_processor_controller (

    // scalar_processor -> vector_extension
    input logic [`XLEN-1:0]     vec_inst,
    
    // vec_control_signals -> vec_decode
    output  logic               vl_sel,             // selection for rs1_data or uimm
    output  logic               vtype_sel,          // selection for rs2_data or zimm
    output  logic               lumop_sel,          // selection lumop
    output  logic               rs1rd_de,           // selection for VLMAX or comparator

    // vec_control_signals -> vec_csr
    output  logic                csrwr_en,

    output  logic                sew_eew_sel,
    output  logic                vlmax_evlmax_sel,
    output  logic                emul_vlmul_sel,
  
    // Vec_control_signals -> vec_registerfile
    output  logic                vec_reg_wr_en,      // The enable signal to write in the vector register
    output  logic                mask_operation,     // This signal tell this instruction is going to perform mask register update
    output  logic                mask_wr_en,         // This the enable signal for updating the mask value
    output  logic   [1:0]        data_mux1_sel,      // This the selsction of the mux to select between vec_imm , scaler1 , and vec_data1
    output  logic                data_mux2_sel,      // This the selsction of the mux to select between scaler2 , and vec_data2
    output  logic                offset_vec_en,      // Tells the rdata2 vector is offset vector and will be chosen on base of emul

    // vec_control_signals -> vec_lsu
    output  logic                stride_sel,         // tells about unit stride
    output  logic                ld_inst,            // tells about load insruction
    output  logic                st_inst,            // tells about store instruction 
    output  logic                index_str,          // tells about the indexed stride
    output  logic                index_unordered     // tells about index unordered stride
);

v_opcode_e      vopcode;
v_func3_e       vfunc3;
logic [1:0]     mop;
logic [4:0]     rs1_addr;
logic [4:0]     rd_addr;

assign vopcode  = v_opcode_e'(vec_inst[6:0]);

// vfunc3 for differentiate between arithematic and configuration instructions
assign vfunc3   = v_func3_e'(vec_inst[14:12]);

// vector load instruction
assign mop      = vec_inst[27:26];

assign rs1_addr = vec_inst[19:15];
assign rd_addr = vec_inst[11:7];

always_comb begin
    lumop_sel           = 0;
    csrwr_en            = 0;
    vl_sel              = 0;
    rs1rd_de            = 1;
    vtype_sel           = 0;
    data_mux1_sel       = 2'b00;
    data_mux2_sel       = 1'b0;
    stride_sel          = 1'b0;
    ld_inst             = 1'b0;
    st_inst             = 1'b0;
    index_str           = 1'b0;
    index_unordered     = 1'b0;
    offset_vec_en       = 1'b0;
    sew_eew_sel         = 1'b0;
    vlmax_evlmax_sel    = 1'b0;
    emul_vlmul_sel      = 1'b0;
    
    case (vopcode)
    V_ARITH: begin
        case (vfunc3)
            CONF: 
            begin
                csrwr_en = 1;
                case(vec_inst[31])
                // VSETVLI
                    1'b0: begin
                        vl_sel    = 0;
                        vtype_sel =  1;     //zimm selection
                        if ((rs1_addr == 0) && (rd_addr != 0)) 
                            rs1rd_de = 0;
                        else 
                            rs1rd_de = 1;
                    end
                    1'b1: begin
                        case (vec_inst[30])
                    // VSETIVLI
                        1'b1: begin
                            vl_sel    = 1;
                            vtype_sel = 1;
                            rs1rd_de  = 1;
                        end
                    // VSETIVL
                        1'b0: begin
                            vl_sel    = 0;
                            vtype_sel = 0;
                            if ((rs1_addr == 0) && (rd_addr != 0)) 
                                rs1rd_de = 0;
                            else 
                                rs1rd_de = 1;
                        end
                        default: begin
                            vl_sel    = 0;
                            vtype_sel = 0;
                            rs1rd_de  = 1;
                        end
                        endcase
                    end
                    default: begin
                        vl_sel    = 0;
                        vtype_sel = 0;
                        rs1rd_de  = 1;
                    end
                endcase
            end
            default: 
            begin
                csrwr_en  = 0;
                vl_sel    = 0;
                vtype_sel = 0;
                rs1rd_de  = 1;
            end
        endcase
    end
    V_LOAD: begin
        vl_sel          = 0;
        vec_reg_wr_en   = 1;
        mask_operation  = 0;
        mask_wr_en      = 0;
        ld_inst         = 1'b1;
        st_inst         = 1'b0;
                
        
        case (mop)
            2'b00: begin // unit-stride
                stride_sel      = 1'b1;     // unit stride
                data_mux1_sel   = 2'b01;    // scaler1
                data_mux2_sel   = 1'b1;     // scaler2
                offset_vec_en   = 1'b0;     // vector as offset
                index_unordered = 1'b0;
                sew_eew_sel     = 1'b1;     // eew selected
                vlmax_evlmax_sel= 1'b1;     // evlmax selected
                emul_vlmul_sel  = 1'b1;     // emul selected
            end
            2'b01: begin // indexed stride unordered
                index_str       = 1'b1;
                data_mux1_sel   = 2'b01;    // scaler1
                data_mux2_sel   = 1'b0;     // vec_data_2
                offset_vec_en   = 1'b1;     // vector as offset
                index_unordered = 1'b1;
                sew_eew_sel     = 1'b0;     // sew selected
                vlmax_evlmax_sel= 1'b1;     // evlmax selected
                emul_vlmul_sel  = 1'b0;     // vlmul selected
            end
            2'b10: begin // strided
                stride_sel      = 1'b0;     // constant stride
                data_mux1_sel   = 2'b01;    // scaler1
                data_mux2_sel   = 1'b1;     // scaler2
                offset_vec_en   = 1'b0;     // vector as offset
                index_unordered = 1'b0;
                sew_eew_sel     = 1'b1;     // eew selected
                vlmax_evlmax_sel= 1'b1;     // evlmax selected
                emul_vlmul_sel  = 1'b1;     // emul selected
            end
            2'b11: begin // indexed stride ordered
                index_str       = 1'b1;
                data_mux1_sel   = 2'b01;    // scaler1
                data_mux2_sel   = 1'b0;     // vec_data_2
                offset_vec_en   = 1'b1;     // vector as offset
                index_unordered = 1'b0;
                sew_eew_sel     = 1'b0;     // sew selected
                vlmax_evlmax_sel= 1'b1;     // evlmax selected
                emul_vlmul_sel  = 1'b0;     // vlmul selected
            end
            default: begin
                index_str       = 1'b0;
                data_mux1_sel   = 2'b01;    // scaler1
                data_mux2_sel   = 1'b0;    // scalar_2
                stride_sel      = 1'b1;     // unit stride
                offset_vec_en   = 1'b0;     // vector as offset
                index_unordered = 1'b0;
                sew_eew_sel     = 1'b0;     // sew selected
                vlmax_evlmax_sel= 1'b0;     // evlmax selected
                emul_vlmul_sel  = 1'b0;     // vlmul selected
            end
        endcase
    end
    V_STORE: begin
        vl_sel          = 0;
        vec_reg_wr_en   = 1;
        mask_operation  = 0;
        mask_wr_en      = 0;
        ld_inst         = 1'b0;
        st_inst         = 1'b1;
                   
        
        case (mop)
            2'b00: begin // unit-stride
                stride_sel      = 1'b1;     // unit stride
                data_mux1_sel   = 2'b01;    // scaler1
                data_mux2_sel   = 1'b1;     // scaler2
                offset_vec_en   = 1'b0;     // vector as offset
                index_unordered = 1'b0;
                sew_eew_sel     = 1'b1;     // eew selected
                vlmax_evlmax_sel= 1'b1;     // evlmax selected
                emul_vlmul_sel  = 1'b1;     // emul selected
            end
            2'b01: begin // indexed stride unordered
                index_str       = 1'b1;
                data_mux1_sel   = 2'b01;    // scaler1
                data_mux2_sel   = 1'b0;     // vec_data_2
                offset_vec_en   = 1'b1;     // vector as offset
                index_unordered = 1'b1;
                sew_eew_sel     = 1'b0;     // sew selected
                vlmax_evlmax_sel= 1'b1;     // evlmax selected
                emul_vlmul_sel  = 1'b0;     // vlmul selected
            end
            2'b10: begin // strided
                stride_sel      = 1'b0;     // constant stride
                data_mux1_sel   = 2'b01;    // scaler1
                data_mux2_sel   = 1'b1;     // scaler2
                offset_vec_en   = 1'b0;     // vector as offset
                index_unordered = 1'b0;
                sew_eew_sel     = 1'b1;     // eew selected
                vlmax_evlmax_sel= 1'b1;     // evlmax selected
                emul_vlmul_sel  = 1'b1;     // emul selected
            end
            2'b11: begin // indexed stride ordered
                index_str       = 1'b1;
                data_mux1_sel   = 2'b01;    // scaler1
                data_mux2_sel   = 1'b0;     // vec_data_2
                offset_vec_en   = 1'b1;     // vector as offset
                index_unordered = 1'b0;
                sew_eew_sel     = 1'b0;     // sew selected
                vlmax_evlmax_sel= 1'b1;     // evlmax selected
                emul_vlmul_sel  = 1'b0;     // vlmul selected
            end
            default: begin
                index_str       = 1'b0;
                data_mux1_sel   = 2'b01;    // scaler1
                data_mux2_sel   = 1'b0;    // scalar_2
                stride_sel      = 1'b1;     // unit stride
                offset_vec_en   = 1'b0;     // vector as offset
                index_unordered = 1'b0;
                sew_eew_sel     = 1'b0;     // sew selected
                vlmax_evlmax_sel= 1'b0;     // evlmax selected
                emul_vlmul_sel  = 1'b0;     // vlmul selected
            end
        endcase
    end
    default: begin
        csrwr_en        = 0;
        vl_sel          = 0;
        vtype_sel       = 0;
        rs1rd_de        = 1;
        lumop_sel       = 0;
        vec_reg_wr_en   = 1;
        mask_operation  = 0;
        mask_wr_en      = 0;
        data_mux1_sel   = 2'b00;   
        data_mux2_sel   = 1'b0;
        stride_sel      = 1'b0;
        ld_inst         = 1'b0;
        st_inst         = 1'b0;
        index_str       = 1'b0;
        index_unordered = 1'b0;
        offset_vec_en   = 1'b0;
        sew_eew_sel     = 1'b0;     
        vlmax_evlmax_sel= 1'b0;     
        emul_vlmul_sel  = 1'b0;     

    end
    endcase    
end

endmodule