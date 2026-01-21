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
    output  logic                index_unordered,     // tells about index unordered stride

    output  logic [2:0]          execution_op,
    output  logic                execution_inst,
    output  logic                signed_mode,
    output  logic                Ctrl,
    output  logic                mul_low, 
    output  logic                mul_high,
    output  logic [4:0]          bitwise_op, 
    output  logic [1:0]          op_type, 
    output  logic [2:0]          cmp_op, 

    output  logic                add_inst, sub_inst, reverse_sub_inst, 

    output  logic                and_inst, or_inst, xor_inst ,

    output  logic                mul_inst,

    output  logic                shift_left_logical_inst, shift_right_arith_inst,shift_right_logical_inst, 

    output  logic                equal_inst, not_equal_inst, less_or_equal_unsigned_inst, less_or_equal_signed_inst, 
                                 less_unsinged_inst, greater_unsigned_inst, less_signed_inst, greater_signed_inst, 

    output  logic                move_inst, 

    output  logic                mul_add_dest_inst, mul_sub_dest_inst, mul_add_source_inst, mul_sub_source_inst,   

    output  logic                mask_and_inst, mask_nand_inst, mask_and_not_inst, mask_xor_inst, mask_or_inst, mask_nor_inst,
                                 mask_or_not_inst , mask_xnor_inst, 

    output  logic                red_sum_inst, red_max_unsigned_inst, red_max_signed_inst,
                                 red_min_signed_inst, red_min_unsigned_inst, red_and_inst , red_or_inst, red_xor_inst,
    
    output  logic                signed_min_inst, unsigned_min_inst, signed_max_inst, unsigned_max_inst, 
                                
    output  logic                wid_add_signed_inst, wid_add_unsigned_inst, wid_sub_signed_inst, wid_sub_unsigned_inst, 

    output  logic                add_carry_inst_inst, sub_borrow_inst, add_carry_masked_inst, sub_borrow_masked_inst, 

    output  logic                sat_add_signed_inst, sat_add_unsigned_inst, sat_sub_signed_inst, sat_sub_unsigned_inst                                                               
);

v_opcode_e      vopcode;
v_func3_e       vfunc3;
logic [1:0]     mop;
logic [4:0]     rs1_addr;
logic [4:0]     rd_addr;
v_func6_vix_e   v_func6_vix;
v_func6_vx_e    v_func6_vx;

assign vopcode  = v_opcode_e'(vec_inst[6:0]);
// vfunc3 for differentiate between arithematic and configuration instructions
assign vfunc3   = v_func3_e'(vec_inst[14:12]);
assign v_func6_vx = v_func6_vx_e'(vec_inst[31:26]);
assign v_func6_vix = v_func6_vix_e'(vec_inst[31:26]);

// vector load instruction
assign mop      = vec_inst[27:26];

assign rs1_addr = vec_inst[19:15];
assign rd_addr = vec_inst[11:7];

always_comb begin
    lumop_sel                   = 1'b0;
    csrwr_en                    = 1'b0;
    vl_sel                      = 1'b0;
    rs1rd_de                    = 1'b1;
    vtype_sel                   = 1'b0;
    stride_sel                  = 1'b0;
    vec_reg_wr_en               = 1'b0;
    mask_operation              = 1'b0;
    mask_wr_en                  = 1'b0;
    index_str                   = 1'b0;
    index_unordered             = 1'b0;
    offset_vec_en               = 1'b0;

    data_mux1_sel               = 2'b00;
    data_mux2_sel               = 1'b0;
    
    sew_eew_sel                 = 1'b0;
    vlmax_evlmax_sel            = 1'b0;
    emul_vlmul_sel              = 1'b0;

    ld_inst                     = 1'b0;
    st_inst                     = 1'b0;

    add_inst                    = 1'b0;
    sub_inst                    = 1'b0;
    reverse_sub_inst            = 1'b0;
    mul_inst                    = 1'b0;

    shift_left_logical_inst     = 1'b0;
    shift_right_arith_inst      = 1'b0;
    shift_right_logical_inst    = 1'b0; 

    mul_inst                    = 1'b0;

    equal_inst                  = 1'b0;
    not_equal_inst              = 1'b0;
    less_or_equal_unsigned_inst = 1'b0; 
    less_or_equal_signed_inst   = 1'b0;
    less_unsinged_inst          = 1'b0; 
    greater_unsigned_inst       = 1'b0;
    less_signed_inst            = 1'b0;
    greater_signed_inst         = 1'b0;

    signed_min_inst             = 1'b0;
    unsigned_min_inst           = 1'b0;
    signed_max_inst             = 1'b0;
    unsigned_max_inst           = 1'b0;

    move_inst                   = 1'b0;

    and_inst                    = 1'b0;
    or_inst                     = 1'b0;
    xor_inst                    = 1'b0;

    mul_add_dest_inst           = 1'b0;
    mul_sub_dest_inst           = 1'b0;
    mul_add_source_inst         = 1'b0;
    mul_sub_source_inst         = 1'b0;

    mask_and_inst               = 1'b0;
    mask_nand_inst              = 1'b0;
    mask_and_not_inst           = 1'b0;
    mask_xor_inst               = 1'b0; 
    mask_or_inst                = 1'b0; 
    mask_nor_inst               = 1'b0;
    mask_or_not_inst            = 1'b0;
    mask_xnor_inst              = 1'b0;

    red_sum_inst                = 1'b0;
    red_max_unsigned_inst       = 1'b0;
    red_max_signed_inst         = 1'b0;
    red_min_signed_inst         = 1'b0;
    red_min_unsigned_inst       = 1'b0;
    red_and_inst                = 1'b0;
    red_or_inst                 = 1'b0;
    red_xor_inst                = 1'b0;
    
    wid_add_signed_inst         = 1'b0;
    wid_add_unsigned_inst       = 1'b0;
    wid_sub_signed_inst         = 1'b0;
    wid_sub_unsigned_inst       = 1'b0;

    add_carry_inst_inst         = 1'b0;
    sub_borrow_inst             = 1'b0;
    add_carry_masked_inst       = 1'b0;
    sub_borrow_masked_inst      = 1'b0;

    sat_add_signed_inst         = 1'b0;
    sat_add_unsigned_inst       = 1'b0;
    sat_sub_signed_inst         = 1'b0;
    sat_sub_unsigned_inst       = 1'b0;

    signed_mode                 = 1'b0;
    mul_low                     = 1'b0;
    mul_high                    = 1'b0;
    Ctrl                        = 1'b0;
    execution_inst              = 1'b0;
    bitwise_op                  = 5'b0; 
    op_type                     = 2'b0;
    cmp_op                      = 3'b0;
    
    case (vopcode)
    V_ARITH: begin
        execution_inst = 1'b1;
        case (vfunc3) 

            OPIVV: begin
                data_mux1_sel = 2'b00;
                data_mux2_sel = 1'b0;
                sew_eew_sel     = 1'b0;     // eew selected
                vlmax_evlmax_sel= 1'b0;     // evlmax selected
                emul_vlmul_sel  = 1'b0;     // emul selected
                vec_reg_wr_en   = 1;
                
                case (v_func6_vix) 
                    VADD: begin
                        add_inst = 1'b1;
                        Ctrl = 1'b0;
                        execution_op = 3'b000;
                    end
                    VSUB: begin
                        sub_inst = 1'b1;
                        Ctrl = 1'b1;
                        execution_op = 3'b000;
                    end
                    VSLL: begin
                        shift_left_logical_inst = 1'b1;
                        execution_op = 3'b001;
                    end
                    VSRL: begin
                        shift_right_logical_inst = 1'b1;
                        execution_op = 3'b001;
                    end
                    VSRA: begin
                        shift_right_arith_inst = 1'b1;
                        execution_op = 3'b001;
                    end
                    VAND: begin
                        and_inst = 1'b1;
                        execution_op = 3'b100;
                        bitwise_op = 5'b00000;
                        op_type = 2'b00;
                    end
                    VOR: begin
                        or_inst = 1'b1;
                        execution_op = 3'b100;
                        bitwise_op = 5'b00001;
                        op_type = 2'b00;
                    end
                    VXOR: begin
                        xor_inst = 1'b1;
                        execution_op = 3'b100;
                        bitwise_op = 5'b00010;
                        op_type = 2'b00;
                    end
                    VMINU: begin
                        unsigned_min_inst = 1'b1;
                        execution_op = 3'b100;
                        bitwise_op = 5'b00100;
                        op_type = 2'b00;
                    end
                    VMIN: begin
                        signed_min_inst = 1'b1;
                        execution_op = 3'b100;
                        bitwise_op = 5'b00101;
                        op_type = 2'b00;
                    end
                    VMAXU: begin
                        unsigned_max_inst = 1'b1;
                        execution_op = 3'b100;
                        bitwise_op = 5'b00110;
                        op_type = 2'b00;
                    end
                    VMAX: begin
                        signed_max_inst = 1'b1;
                        execution_op = 3'b100; 
                        bitwise_op = 5'b00111;
                        op_type = 2'b00;
                    end

                    VMSEQ: begin
                        equal_inst = 1'b1;
                        execution_op = 3'b101;
                        op_type = 2'b00;
                        cmp_op = 3'b000;
                    end
                    VMSNE: begin
                        not_equal_inst = 1'b1;
                        execution_op = 3'b101;
                        op_type = 2'b00;
                        cmp_op = 3'b001;
                    end
                    VMSLTU: begin
                        less_unsinged_inst = 1'b1;
                        execution_op = 3'b101;
                        op_type = 2'b00;
                        cmp_op = 3'b010;
                    end
                    VMSLT: begin
                        less_signed_inst = 1'b1;
                        execution_op = 3'b101;
                        op_type = 2'b00;
                        cmp_op = 3'b100;
                    end
                    VMSLEU: begin
                        less_or_equal_unsigned_inst = 1'b1;
                        execution_op = 3'b101;
                        op_type = 2'b00;
                        cmp_op = 3'b011;
                    end
                    VMSLE: begin
                        less_or_equal_signed_inst = 1'b1;
                        execution_op = 3'b101;
                        op_type = 2'b00;
                        cmp_op = 3'b101;
                    end 
                    VMV: begin
                        move_inst = 1'b1;
                        execution_op = 3'b110;
                    end         
                endcase
            end

            OPIVX: begin
                data_mux1_sel = 2'b01;
                data_mux2_sel = 1'b0;
                sew_eew_sel     = 1'b0;     // eew selected
                vlmax_evlmax_sel= 1'b0;     // evlmax selected
                emul_vlmul_sel  = 1'b0;     // emul selected
                vec_reg_wr_en   = 1;
                
                case(v_func6_vix) 
                    VADD: begin
                        Ctrl = 1'b0;
                        add_inst = 1'b1;
                        execution_op = 3'b000;
                    end
                    VSUB: begin
                        Ctrl = 1'b1;
                        sub_inst = 1'b1;
                        execution_op = 3'b000;
                    end
                    VRSUB: begin
                        Ctrl = 1'b1;
                        reverse_sub_inst = 1'b1;
                        execution_op = 3'b000;
                    end
                    VSLL: begin
                        shift_left_logical_inst = 1'b1;
                        execution_op = 3'b001;
                    end
                    VSRL: begin
                        shift_right_logical_inst = 1'b1;
                        execution_op = 3'b001;
                    end
                    VSRA: begin 
                        shift_right_arith_inst = 1'b1;
                        execution_op = 3'b001;
                    end
                    VAND: begin
                        and_inst = 1'b1;
                        execution_op = 3'b100;
                        bitwise_op = 5'b00000;
                        op_type = 2'b01;
                    end
                    VOR: begin
                        or_inst = 1'b1;
                        execution_op = 3'b100;
                        bitwise_op = 5'b00001;
                        op_type = 2'b01;
                    end
                    VXOR: begin 
                        xor_inst = 1'b1;
                        execution_op = 3'b100;
                        bitwise_op = 5'b00010;
                        op_type = 2'b01;
                    end
                    VMSEQ: begin 
                        equal_inst = 1'b1;
                        execution_op = 3'b101;
                        op_type = 2'b01;
                        cmp_op = 3'b001;
                    end
                    VMSNE: begin 
                        not_equal_inst = 1'b1;
                        execution_op = 3'b101;
                        op_type = 2'b01;
                        cmp_op = 3'b001;
                    end
                    VMSLTU: begin 
                        less_unsinged_inst = 1'b1;
                        execution_op = 3'b101;
                        op_type = 2'b01;
                        cmp_op = 3'b010;
                    end
                    VMSLT: begin
                         less_signed_inst = 1'b1;
                        execution_op = 3'b101;
                        op_type = 2'b01;
                        cmp_op = 3'b100;
                    end
                    VMSLEU: begin
                        less_or_equal_unsigned_inst = 1'b1;
                        execution_op = 3'b101;
                        op_type = 2'b01;
                        cmp_op = 3'b011;
                    end
                    VMSLE: begin
                        less_or_equal_signed_inst = 1'b1;
                        execution_op = 3'b101;
                        op_type = 2'b01;
                        cmp_op = 3'b101;
                    end
                    VMSGTU: begin
                        greater_unsigned_inst = 1'b1; 
                        execution_op = 3'b101;
                        op_type = 2'b01;
                        cmp_op = 3'b111;
                    end
                    VMSGT: begin 
                        greater_signed_inst = 1'b1;
                        execution_op = 3'b101;
                        op_type = 2'b01;
                        cmp_op = 3'b110;
                    end
                    VMINU: begin
                        unsigned_min_inst = 1'b1;
                        execution_op = 3'b100;
                        bitwise_op = 5'b00100;
                        op_type = 2'b01;
                    end
                    VMIN: begin
                        signed_min_inst = 1'b1;
                        execution_op = 3'b100;
                        bitwise_op = 5'b00101;
                        op_type = 2'b01;
                    end
                    VMAXU: begin
                        unsigned_max_inst = 1'b1;
                        execution_op = 3'b100;
                        bitwise_op = 5'b00110;
                        op_type = 2'b01;
                    end
                    VMAX: begin
                        signed_max_inst = 1'b1;
                        execution_op = 3'b100; 
                        bitwise_op = 5'b00111;
                        op_type = 2'b01;
                    end
                    VMV: begin
                        move_inst = 1'b1;
                        execution_op = 3'b110;
                    end
                endcase
            end

            OPIVI: begin
                data_mux1_sel = 2'b10;
                data_mux2_sel = 1'b0;
                sew_eew_sel     = 1'b0;     // eew selected
                vlmax_evlmax_sel= 1'b0;     // evlmax selected
                emul_vlmul_sel  = 1'b0;     // emul selected
                vec_reg_wr_en   = 1;
                
                case(v_func6_vix) 
                    VADD: begin
                        Ctrl = 1'b0;
                        add_inst = 1'b1;
                        execution_op = 3'b000;
                    end
                    VRSUB: begin
                        Ctrl = 1'b1;
                        reverse_sub_inst = 1'b1;
                        execution_op = 3'b000;
                    end
                    VSLL: begin
                        shift_left_logical_inst = 1'b1;
                        execution_op = 3'b001;
                    end
                    VSRL: begin
                        shift_right_logical_inst = 1'b1;
                        execution_op = 3'b001;
                    end
                    VSRA: begin
                        shift_right_arith_inst = 1'b1;
                        execution_op = 3'b001;
                    end
                    VAND: begin
                        and_inst = 1'b1;
                        execution_op = 3'b100;
                        bitwise_op = 5'b00000;
                        op_type = 2'b10;
                    end
                    VOR: begin
                        or_inst = 1'b1;
                        execution_op = 3'b100;
                        bitwise_op = 5'b00001;
                        op_type = 2'b10;
                    end
                    VXOR: begin
                        xor_inst = 1'b1;
                        execution_op = 3'b100;
                        bitwise_op = 5'b00010;
                        op_type = 2'b10;
                    end 
                    VMSLEU: begin
                        less_or_equal_unsigned_inst = 1'b1;
                        execution_op = 3'b101;
                        op_type = 2'b10;
                        cmp_op = 3'b011;
                    end
                    VMSLE: begin
                        less_or_equal_signed_inst = 1'b1;
                        execution_op = 3'b101;
                        op_type = 2'b10;
                        cmp_op = 3'b101;
                    end
                    VMSGTU: begin
                        greater_unsigned_inst = 1'b1; 
                        execution_op = 3'b101;
                        op_type = 2'b10;
                        cmp_op = 3'b111;
                    end
                    VMSGT: begin 
                        greater_signed_inst = 1'b1;
                        execution_op = 3'b101;
                        op_type = 2'b10;
                        cmp_op = 3'b110;
                    end 
                    VMV: begin
                        move_inst = 1'b1;
                        execution_op = 3'b110;
                    end  
                endcase
            end
            
            OPMVV: begin
                data_mux1_sel = 2'b00;
                data_mux2_sel = 1'b0;
                sew_eew_sel     = 1'b0;     // eew selected
                vlmax_evlmax_sel= 1'b0;     // evlmax selected
                emul_vlmul_sel  = 1'b0;     // emul selected
                vec_reg_wr_en   = 1;
                case(v_func6_vx) 

                    VMUL: begin
                        mul_inst = 1'b1;
                        mul_low = 1'b1;
                        signed_mode = 1'b1;
                        execution_op = 3'b011;
                    end
                    VMULH: begin
                        mul_inst = 1'b1;
                        mul_high = 1'b1; 
                        signed_mode = 1'b1;
                        execution_op = 3'b011;
                    end
                    VMULHU: begin
                        mul_inst = 1'b1;
                        mul_high = 1'b1;
                        signed_mode = 1'b0;
                        execution_op = 3'b011;
                    end
                    VMULHSU: begin
                        mul_inst = 1'b1;
                        signed_mode = 1'b1;
                        mul_high = 1'b1;
                        execution_op = 3'b011;
                    end
                
                endcase 
            end

            OPMVX: begin
                data_mux1_sel = 2'b01;
                data_mux2_sel = 1'b0;
                sew_eew_sel     = 1'b0;     // eew selected
                vlmax_evlmax_sel= 1'b0;     // evlmax selected
                emul_vlmul_sel  = 1'b0;     // emul selected
                vec_reg_wr_en   = 1;

                case(v_func6_vx) 
                    
                    VMUL: begin
                        mul_inst = 1'b1;
                        mul_low = 1'b1;
                        signed_mode = 1'b1;
                        execution_op = 3'b011;
                    end
                    VMULH: begin
                        mul_inst = 1'b1;
                        mul_high = 1'b1; 
                        signed_mode = 1'b1;
                        execution_op = 3'b011;
                    end
                    VMULHU: begin
                        mul_inst = 1'b1;
                        mul_high = 1'b1;
                        signed_mode = 1'b0;
                        execution_op = 3'b011;
                    end
                    VMULHSU: begin
                        mul_inst = 1'b1;
                        signed_mode = 1'b1;
                        mul_high = 1'b1;
                        execution_op = 3'b011;
                    end
                
                endcase 
            end

            CONF: begin
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
            default: begin
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