`include "vec_de_csr_defs.svh"

module vec_decode(
    // scalar_processor -> vec_decode
    input   logic [`XLEN-1:0]       vec_inst,
    input   logic [`XLEN-1:0]       rs1_data, 
    input   logic [`XLEN-1:0]       rs2_data,

    // vec_decode -> scalar_processor
    output  logic                   is_vec,

    // vec_decode -> vec_regfile
    output  logic [`XLEN-1:0]       vec_read_addr_1,        // vs1_addr
    output  logic [`XLEN-1:0]       vec_read_addr_2,        // vs2_addr
    output  logic [`XLEN-1:0]       vec_write_addr,         // vd_addr
    output  logic [`MAX_VLEN-1:0]   vec_imm,
    output  logic                   vec_mask,

    // vec_decode -> vector load
    output  logic [2:0]             width,                  // width of memory element
    output  logic                   mew,                    // selection bwtween fp or integer
    output  logic [2:0]             nf,                     // number of fields          

    // vec_decode -> csr 
    output  logic [`XLEN-1:0]       scalar2,                // vector type or rs2
    output  logic [`XLEN-1:0]       scalar1,               // rs1_data or uimm

    // vec_control_signals -> vec_decode
    input   logic                   vl_sel,                 // selection for rs1_data or uimm
    input   logic                   vtype_sel,              // selection for rs2_data or zimm
    input   logic                   lumop_sel               // selection lumop
);

v_opcode_e      vopcode;
v_func3_e       vfunc3;
logic [1:0]     inst_msb;
logic [4:0]     vs1_addr, vs3_addr;
logic [4:0]     vs2_addr;
logic [4:0]     vd_addr;
logic [4:0]     rs1_addr;
logic [4:0]     imm;
logic           vm;         // vector mask

// vector load
logic [4:0]     lumop;      // additional unit stride
logic [1:0]     mop;        // selection between strided and gather

// vector configuration 
logic [`XLEN-1:0]     rs1_o, rs2_o;
logic [`XLEN-1:0]     vtype_mux;
logic [10:0]          zimm;          // zero-extended immediate
logic [4:0]           uimm;          // unsigned immediate

assign vopcode  = v_opcode_e'(vec_inst[6:0]);
assign vd_addr  = vec_inst[11:7];
assign vfunc3   = v_func3_e'(vec_inst[14:12]);
assign vs1_addr = vec_inst[19:15];
assign rs1_addr = vec_inst[19:15];
assign imm      = vec_inst[19:15];
assign vs2_addr = vec_inst[24:20];
assign lumop    = vec_inst[24:20];
assign vm       = vec_inst[25];
assign func6    = vec_inst[31:26];

// vector instruction msb bits used to select the vector config registers
assign inst_msb = vec_inst[31:30];

// vector config
assign uimm = vec_inst[19:15];

// vector load
assign mop = vec_inst[27:26];

always_comb begin : vec_decode
    is_vec          = '0;
    vec_write_addr  = '0;
    vec_read_addr_1 = '0;
    vec_read_addr_2 = '0;
    vec_imm         = '0;
    vec_mask        = '0;
    rs1_o           = '0;
    rs2_o           = '0;
    zimm            = '0;
    case (vopcode)
        // vector arithematic and set instructions opcode = 0x57
        V_ARITH: begin
            is_vec          = 1;
            case (vfunc3)
                OPIVV: begin
                    vec_write_addr  = vd_addr;
                    vec_read_addr_1 = vs1_addr;
                    vec_read_addr_2 = vs2_addr;
                    vec_imm         = '0;
                    vec_mask        = vm;
                end
                OPIVI: begin
                    vec_write_addr  = vd_addr;
                    vec_read_addr_1 = '0;
                    vec_read_addr_2 = vs2_addr;
                    vec_imm         = imm;
                    vec_mask        = vm;
                end
                OPIVX: begin
                    vec_write_addr  = vd_addr;
                    vec_read_addr_1 = '0;
                    vec_read_addr_2 = vs2_addr;
                    vec_imm         = '0;
                    vec_mask        = vm;
                end

                // vector configuration instructions
                CONF: begin
                    case (inst_msb[1])
                    // VSETVLI
                        1'b0: begin
                            rs1_o = rs1_data;
                            rs2_o =  '0; 
                            zimm  = vec_inst [30:20];
                        end
                        1'b1: begin
                            case (inst_msb[0])
                            // VSETIVLI
                                1'b1: begin
                                    rs1_o = '0;
                                    rs2_o = '0; 
                                    zimm  = {'0,vec_inst [29:20]};
                                end
                            // VSETVL
                                1'b0: begin
                                    rs1_o = rs1_data;
                                    rs2_o = rs2_data;
                                    zimm  =  '0;
                                end
                            default: begin
                                rs1_o = '0;
                                rs2_o = '0;
                                zimm  = '0;
                            end
                            endcase
                        end
                        default: begin
                            rs1_o = '0;
                            rs2_o = '0;
                            zimm  = '0;
                        end
                    endcase
                end

                default: begin
                    vec_write_addr  = '0;
                    vec_read_addr_1 = '0;
                    vec_read_addr_2 = '0;
                    vec_imm         = '0;
                    vec_mask        = '0;
                    rs2_o           = '0;
                    rs1_o           = '0;
                    zimm            = '0;
                end
            endcase
        end

        // Vector load instructions
        V_LOAD: begin
            is_vec          = 1;
            vec_write_addr  = vd_addr;
            rs1_o           = rs1_data;
            vec_imm         = '0;
            vec_mask        = vm;
            mew             = vec_inst[28];
            nf              = vec_inst[31:29];
            width           = vec_inst[14:12];
            case(mop)
                2'b10: rs2_o = rs2_data;
                // gather unordered
                2'b01:vec_read_addr_2 = vs2_addr;
                // gather ordered
                2'b11:vec_read_addr_2 = vs2_addr;
                default:vec_read_addr_2 = '0;
            endcase
        end

        // Vector Store instructions
        V_STORE: begin
            is_vec          = 1'b1;
            vec_write_addr  = vd_addr;
            rs1_o           = rs1_data;
            vec_imm         = '0;
            vec_mask        = vm;
            mew             = vec_inst[28];
            nf              = vec_inst[31:29];
            width           = vec_inst[14:12];
            case(mop)
                2'b10: rs2_o = rs2_data;
                // gather unordered
                2'b01:vec_read_addr_2 = vs2_addr;
                // gather ordered
                2'b11:vec_read_addr_2 = vs2_addr;
                default:vec_read_addr_2 = '0;
            endcase
        end

        default: begin
            is_vec          = '0;
            vec_write_addr  = '0;
            vec_read_addr_1 = '0;
            vec_read_addr_2 = '0;
            vec_imm         = '0;
            vec_mask        = '0;
            rs1_o           = '0;
            rs2_o           = '0;
            zimm            = '0;
            mew             = '0;
            nf              = '0;
            width           = '0;
        end
    endcase
end
    
/* Mux for vector configuration scalar2 selections*/

always_comb begin
    // mux for selection of uimm or rs1 for scalar1
    scalar1 = (vl_sel) ? $unsigned(uimm) : rs1_o;

    // mux for selection of zimm or rs2 for scalar2
    vtype_mux = (vtype_sel) ? {'0 ,zimm} : rs2_o;

    // mux for selection of lumop or vtype
    scalar2   = (lumop_sel) ? $unsigned(lumop) : vtype_mux;
end

endmodule