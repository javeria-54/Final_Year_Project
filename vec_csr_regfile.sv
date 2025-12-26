`include "vec_de_csr_defs.svh"

module vec_csr_regfile (
    input   logic                    clk,
    input   logic                    n_rst,

    // scalar_processor -> csr_regfile
    input   logic   [`XLEN-1:0]      inst,

    // csr_regfile -> scalar_processor
    output  logic   [`XLEN-1:0]     csr_out,

    // vec_controller -> csr
    input   logic                   rs1rd_de,   // selection for VLMAX or comparator
    // vec_decode -> vec_csr_regs
    input   logic   [`XLEN-1:0]     scalar2,    // vtype-csr
    input   logic   [`XLEN-1:0]     scalar1,    // vlen-csr / vstart-csr
    input   logic   [2:0]           width,      // width of memory element

    // vec_control_signals -> vec_csr_regs
    input   logic                   csrwr_en,

    // vec_csr_regs ->
    output  logic   [3:0]           vlmul, emul,
    output  logic   [6:0]           sew, eew,
    output  logic   [9:0]           vlmax, e_vlmax,
    output  logic                   tail_agnostic,    // vector tail agnostic
    output  logic                   mask_agnostic,    // vector mask agnostic

    output  logic   [`XLEN-1:0]     vec_length,
    output  logic   [`XLEN-1:0]     start_element,

    // Output from csr_reg--> datapath (done signal)
    output  logic                   csr_done           // This signal tells that csr instruction has been implemented successfully.       
);


csr_vtype_s         csr_vtype_q;
logic [`XLEN-1:0]   csr_vl_q;
logic [`XLEN-1:0]   csr_vstart_d, csr_vstart_q;
logic               illegal_insn;
logic [`XLEN-1:0]   vl,vlen_compare;  
// instruction decode
logic [6:0]     opcode;
logic [4:0]     rs1_addr;
logic [4:0]     rd_addr;
logic [2:0]     funct3;
csr_reg_e       csr_addr;  

assign opcode   = inst [6:0];
assign rd_addr  = inst [11:7];
assign funct3   = inst [14:12];
assign rs1_addr = inst [19:15];
assign csr_addr = csr_reg_e'(inst [31:20]);  

// Two vector CSR registers vtype and vl are written by using only one 'vsetvli' instruction
// these two registers are not written by the simple read write csr_addr.
 
// CSR registers vtype and vl (vector length)

////////////////////////////
//  Vector Configuration  //
////////////////////////////

logic csrwr_en_d; // Delayed version of csrwr_en

// Sequential block to store the previous value of csrwr_en
always_ff @(posedge clk or negedge n_rst) begin
    if (!n_rst) begin
        csrwr_en_d <= 1'b0;
    end else begin
        if (csr_done) begin
            csrwr_en_d <= 1'b0;
        end
        else begin
            csrwr_en_d <= csrwr_en; // Store current state of csrwr_en
        end
    end
end

always_ff @(posedge clk, negedge n_rst) begin
    if (!n_rst) begin
        csr_vtype_q.ill       <= 1;
        csr_vtype_q.vma       <= '0;
        csr_vtype_q.reserved  <= '0;
        csr_vtype_q.vta       <= '0;
        csr_vtype_q.vsew      <= '0;
        csr_vtype_q.vlmul     <= '0;
        csr_vl_q              <= '0;
        csr_done              <= '0;
    end
    else if (csrwr_en && !csrwr_en_d) begin
         // **Step 1: Update vtype FIRST**
        csr_vtype_q.ill   <= '0;
        csr_vtype_q.vma   <= scalar2[7];
        csr_vtype_q.vta   <= scalar2[6];
        csr_vtype_q.vsew  <= scalar2[5:3];
        csr_vtype_q.vlmul <= scalar2[2:0];
        
        // **Step 2: Compute vlmax based on updated vtype**
        case (vlmul_e'(scalar2[2:0]))  // Using new vlmul
            LMUL_1: begin
                case(vew_e'(scalar2[5:3]))  // Using new vsew
                    EW8:    vlmax = 64;
                    EW16:   vlmax = 32;
                    EW32:   vlmax = 16;
                    EW64:   vlmax = 8;
                    default: vlmax = 16;
                endcase
            end
            LMUL_2: begin
                case(vew_e'(scalar2[5:3]))
                    EW8:    vlmax = 128;
                    EW16:   vlmax = 64;
                    EW32:   vlmax = 32;
                    EW64:   vlmax = 16;
                    default: vlmax = 32;
                endcase
            end
            LMUL_4: begin
                case(vew_e'(scalar2[5:3]))
                    EW8:    vlmax = 256;
                    EW16:   vlmax = 128;
                    EW32:   vlmax = 64;
                    EW64:   vlmax = 32;
                    default: vlmax = 64;
                endcase
            end
            LMUL_8: begin
                case(vew_e'(scalar2[5:3]))
                    EW8:    vlmax = 512;
                    EW16:   vlmax = 256;
                    EW32:   vlmax = 128;
                    EW64:   vlmax = 64;
                    default: vlmax = 128;
                endcase
            end
            default: vlmax = 16;
        endcase

        // **Step 3: Compute AVL using updated vlmax**
        vlen_compare = (scalar1 > vlmax) ? vlmax : scalar1;

        case (rs1rd_de)
            1'b0: vl = vlmax;         // rs1 == x0
            1'b1: vl = vlen_compare;  // rs1 != x0
            default: vl = vlmax;
        endcase

        // **Step 4: Update VL register after vtype is set**
        if ((inst[19:15] == 0) && (inst[11:7] == 0))
            csr_vl_q <= csr_vl_q; // Preserve old vl
        else
            csr_vl_q <= vl; // Set new vl

        csr_done <= 1'b1;
        
    end 
    else begin 
        csr_vtype_q <= csr_vtype_q;
        csr_vl_q    <= csr_vl_q;
        csr_done    <= 1'b0;
    end   
end

// CSR vstart register
always_ff @(posedge clk or negedge n_rst) begin
    if (!n_rst)
        csr_vstart_q <= '0;
    else 
        csr_vstart_q <= csr_vstart_d;
end

// vlmul decoding 
always_comb begin
    case(vlmul_e'(csr_vtype_q.vlmul))
        LMUL_1:     vlmul = 1;
        LMUL_2:     vlmul = 2;
        LMUL_4:     vlmul = 4;
        LMUL_8:     vlmul = 8;
        LMUL_RSVD:  vlmul = 1;
        default:    vlmul = 1;
    endcase
end

// sew decoding 
always_comb begin
    case(vew_e'(csr_vtype_q.vsew))
        EW8:    sew = 8;
        EW16:   sew = 16;
        EW32:   sew = 32;
        EW64:   sew = 64;
        EWRSVD: sew = 32;
        default: sew = 32;
    endcase
end

// EEW EMUL and EVLMAX DECODING 
always_comb begin : eew_emul_evlmax_decoding
    // eew decoding
    case (width)
        4'b0000:eew = 8;
        4'b0101:eew = 16;
        4'b0110:eew = 32;
        4'b0111:eew = 64;
        default:eew = 32;
    endcase

    // emul = eew/sew * lmul
    case (width)
        4'b0000: begin // eew=8
            case (vlmul_e'(csr_vtype_q.vlmul))
                LMUL_1: begin // vlmul=1
                    case (vew_e'(csr_vtype_q.vsew))
                        EW8:    emul = 1;   // sew=8
                        // EW16:   emul = 1/2; // sew=16
                        // EW32:   emul = 1/4; // sew=32
                        // EW64:   emul = 1/8; // sew=64
                        // EWRSVD: emul = 1/4; // sew=32
                        default: emul = 1; 
                    endcase
                end
                LMUL_2: begin // vlmul=2
                    case (vew_e'(csr_vtype_q.vsew))
                        EW8:    emul = 2;   // sew=8
                        EW16:   emul = 1;   // sew=16
                        // EW32:   emul = 1/2; // sew=32
                        // EW64:   emul = 1/4; // sew=64
                        // EWRSVD: emul = 1/2; // sew=32
                        default: emul = 1; 
                    endcase
                end
                LMUL_4: begin // vlmul=4
                    case (vew_e'(csr_vtype_q.vsew))
                        EW8:    emul = 4;   // sew=8
                        EW16:   emul = 2; // sew=16
                        EW32:   emul = 1; // sew=32
                        // EW64:   emul = 1/2; // sew=64
                        EWRSVD: emul = 1; // sew=32
                        default: emul = 1; 
                    endcase
                end
                LMUL_8: begin // vlmul=8
                    case (vew_e'(csr_vtype_q.vsew))
                        EW8:    emul = 8;   // sew=8
                        EW16:   emul = 4; // sew=16
                        EW32:   emul = 2; // sew=32
                        EW64:   emul = 1; // sew=64
                        EWRSVD: emul = 2; // sew=32
                        default: emul = 1; 
                    endcase
                end
                default: begin
                    emul = 1;
                end
            endcase
        end
        4'b0101: begin // eew=16
            case (vlmul_e'(csr_vtype_q.vlmul))
                LMUL_1: begin // vlmul=1
                    case (vew_e'(csr_vtype_q.vsew))
                        EW8:    emul = 2;   // sew=8
                        EW16:   emul = 1; // sew=16
                        // EW32:   emul = 1/2; // sew=32
                        // EW64:   emul = 1/4; // sew=64
                        // EWRSVD: emul = 1/2; // sew=32
                        default: emul = 1; 
                    endcase
                end
                LMUL_2: begin // vlmul=2
                    case (vew_e'(csr_vtype_q.vsew))
                        EW8:    emul = 4;   // sew=8
                        EW16:   emul = 2; // sew=16
                        EW32:   emul = 1; // sew=32
                        // EW64:   emul = 1/2; // sew=64
                        EWRSVD: emul = 1; // sew=32
                        default: emul = 1; 
                    endcase
                end
                LMUL_4: begin // vlmul=4
                    case (vew_e'(csr_vtype_q.vsew))
                        EW8:    emul = 8;   // sew=8
                        EW16:   emul = 4; // sew=16
                        EW32:   emul = 2; // sew=32
                        EW64:   emul = 1; // sew=64
                        EWRSVD: emul = 2; // sew=32
                        default: emul = 1; 
                    endcase
                end
                LMUL_8: begin // vlmul=8
                    case (vew_e'(csr_vtype_q.vsew))
                        // EW8:    emul = 16;   // sew=8
                        EW16:   emul = 8; // sew=16
                        EW32:   emul = 4; // sew=32
                        EW64:   emul = 2; // sew=64
                        EWRSVD: emul = 4; // sew=32
                        default: emul = 1; 
                    endcase
                end
                default: begin
                    emul = 1;
                end
            endcase
        end
        4'b0110: begin // eew=32
            case (vlmul_e'(csr_vtype_q.vlmul))
                LMUL_1: begin // vlmul=1
                    case (vew_e'(csr_vtype_q.vsew))
                        EW8:    emul = 4;   // sew=8
                        EW16:   emul = 2; // sew=16
                        EW32:   emul = 1; // sew=32
                        //EW64:   emul = 1/2; // sew=64
                        EWRSVD: emul = 1; // sew=32
                        default: emul = 1; 
                    endcase
                end
                LMUL_2: begin // vlmul=2
                    case (vew_e'(csr_vtype_q.vsew))
                        EW8:    emul = 8;   // sew=8
                        EW16:   emul = 4; // sew=16
                        EW32:   emul = 2; // sew=32
                        EW64:   emul = 1; // sew=64
                        EWRSVD: emul = 2; // sew=32
                        default: emul = 1; 
                    endcase
                end
                LMUL_4: begin // vlmul=4
                    case (vew_e'(csr_vtype_q.vsew))
                        // EW8:    emul = 16;   // sew=8
                        EW16:   emul = 8; // sew=16
                        EW32:   emul = 4; // sew=32
                        EW64:   emul = 2; // sew=64
                        EWRSVD: emul = 4; // sew=32
                        default: emul = 1; 
                    endcase
                end
                LMUL_8: begin // vlmul=8
                    case (vew_e'(csr_vtype_q.vsew))
                        // EW8:    emul = 32;   // sew=8
                        // ?\EW16:   emul = 16; // sew=16 
                        EW32:   emul = 8; // sew=32
                        EW64:   emul = 4; // sew=64
                        EWRSVD: emul = 8; // sew=32
                        default: emul = 1; 
                    endcase
                end
                default: begin
                    emul = 1;
                end
            endcase
        end
        4'b0111: begin // eew=64
            case (vlmul_e'(csr_vtype_q.vlmul))
                LMUL_1: begin // vlmul=1
                    case (vew_e'(csr_vtype_q.vsew))
                        EW8:    emul = 8;   // sew=8
                        EW16:   emul = 4; // sew=16
                        EW32:   emul = 2; // sew=32
                        EW64:   emul = 1; // sew=64
                        EWRSVD: emul = 2; // sew=32
                        default: emul = 1; 
                    endcase
                end
                LMUL_2: begin // vlmul=2
                    case (vew_e'(csr_vtype_q.vsew))
                        // EW8:    emul = 16;   // sew=8
                        EW16:   emul = 8; // sew=16
                        EW32:   emul = 4; // sew=32
                        EW64:   emul = 2; // sew=64
                        EWRSVD: emul = 4; // sew=32
                        default: emul = 1; 
                    endcase
                end
                LMUL_4: begin // vlmul=4
                    case (vew_e'(csr_vtype_q.vsew))
                        // EW8:    emul = 32;   // sew=8
                        // EW16:   emul = 16; // sew=16
                        EW32:   emul = 8; // sew=32
                        EW64:   emul = 4; // sew=64
                        EWRSVD: emul = 8; // sew=32
                        default: emul = 1; 
                    endcase
                end
                LMUL_8: begin // vlmul=8
                    case (vew_e'(csr_vtype_q.vsew))
                        // EW8:    emul = 64;   // sew=8
                        // EW16:   emul = 32;   // sew=16
                        // EW32:   emul = 16;   // sew=32
                        EW64:   emul = 8;    // sew=64
                        EWRSVD: emul = 16;   // sew=32
                        default: emul = 1; 
                    endcase
                end
                default: begin
                    emul = 1;
                end
            endcase
        end
    endcase

    // e_vlmax calculation
    if (eew != 0) begin
        e_vlmax = (`VLEN / eew) * emul;
    end else begin
        e_vlmax = 0;
    end
end

assign vec_length = csr_vl_q;
assign start_element  = csr_vstart_q;
assign mask_agnostic  = csr_vtype_q.vma;
assign tail_agnostic  = csr_vtype_q.vta;

////////////////////////////
//  CSR Reads and Writes  //
////////////////////////////

// Converts between the internal representation of `vtype_t` and the full XLEN-bit CSR.
function logic[`XLEN-1:0] xlen_vtype(csr_vtype_s vtype);
  xlen_vtype = {vtype.ill, {23'h000000}, vtype.vma, vtype.vta, vtype.vsew,
    vtype.vlmul[2:0]};
endfunction: xlen_vtype

always_comb begin
    csr_vstart_d = '0;
    case (opcode)
        // CSR instructions
        7'h73: begin
            case (funct3)
                3'b001: begin // csrrw
                    // Decode the CSR.
                    case (csr_addr)
                        // Only vstart can be written with CSR instructions.
                        CSR_VSTART: begin
                            csr_vstart_d    = scalar1;
                            csr_out         = csr_vstart_q;
                        end
                        default: illegal_insn = 1'b1;
                    endcase
                end
                3'b010: begin // csrrs
                    // Decode the CSR.
                    case (csr_addr)
                        CSR_VSTART: begin
                            csr_vstart_d    = csr_vstart_q | scalar1;
                            csr_out         = csr_vstart_q;
                        end
                        CSR_VTYPE: begin
                            // Only reads are allowed
                            if (rs1_addr == '0) csr_out = xlen_vtype(csr_vtype_q);
                            else illegal_insn = 1'b1;
                        end
                        CSR_VL: begin
                            // Only reads are allowed
                            if (rs1_addr == '0) csr_out = csr_vl_q;
                            else illegal_insn = 1'b1;
                        end
                    default: illegal_insn = 1'b1;
                    endcase
                end
                3'b011: begin // csrrc
                    // Decode the CSR.
                    case (csr_addr)
                        CSR_VSTART: begin
                            csr_vstart_d    = csr_vstart_q & ~scalar1;
                            csr_out         = csr_vstart_q;
                        end
                        CSR_VTYPE: begin
                            // Only reads are allowed
                            if (rs1_addr == '0) csr_out = xlen_vtype(csr_vtype_q);
                            else illegal_insn = 1'b1;
                        end
                        CSR_VL: begin
                            // Only reads are allowed
                            if (rs1_addr == '0) csr_out = csr_vl_q;
                            else illegal_insn = 1'b1;
                        end
                    default: illegal_insn = 1'b1;
                    endcase
                end
                3'b101: begin // csrrwi
                    // Decode the CSR.
                    case (csr_addr)
                        // Only vstart can be written with CSR instructions.
                        CSR_VSTART: begin
                            csr_vstart_d    = scalar1;
                            csr_out         = csr_vstart_q;
                        end
                    default: illegal_insn = 1'b1;
                    endcase
                end
                3'b110: begin // csrrsi
                    // Decode the CSR.
                    case (csr_addr)
                        CSR_VSTART: begin
                            csr_vstart_d  = csr_vstart_q | scalar1;
                            csr_out       = csr_vstart_q;
                        end
                        CSR_VTYPE: begin
                            // Only reads are allowed
                            if (rs1_addr == '0) csr_out = xlen_vtype(csr_vtype_q);
                            else illegal_insn = 1'b1;
                        end
                        CSR_VL: begin
                            // Only reads are allowed
                            if (rs1_addr == '0) csr_out = csr_vl_q;
                            else illegal_insn = 1'b1;
                        end
                    default: illegal_insn = 1'b1;
                    endcase
                end
                3'b111: begin // csrrci
                    // Decode the CSR.
                    case (csr_addr)
                        CSR_VSTART: begin
                            csr_vstart_d = csr_vstart_q & ~scalar1;
                            csr_out      = csr_vstart_q;
                        end
                        CSR_VTYPE: begin
                            // Only reads are allowed
                            if (rs1_addr == '0) csr_out = xlen_vtype(csr_vtype_q);
                            else illegal_insn = 1'b1;
                        end
                        CSR_VL: begin
                            // Only reads are allowed
                            if (rs1_addr == '0) csr_out = csr_vl_q;
                            else illegal_insn = 1'b1;
                        end
                    default: illegal_insn= 1'b1;
                    endcase
                end
                default: begin
                    // Trigger an illegal instruction
                    illegal_insn = 1'b1;
                end
            endcase // funct3
        end

        default: begin
        // Trigger an illegal instruction
        csr_out = '0;
        illegal_insn = 1'b1;
        end
    endcase
end

endmodule