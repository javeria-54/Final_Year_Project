`include "vector_regfile_defs.svh"
`include "scalar_pcore_interface_defs.svh"

module memory #(
    parameter D = 2,
    parameter ROW_W = $clog2(D)
)(
    input  logic clk,
    input  logic rst_n,

    // ---------- PORT A : 512-bit / Element ----------
    input  logic [31:0]  addr_a,
    input  logic [511:0] wdata_a,
    output logic [511:0] rdata_a,
    input  logic         wen_a,
    input  logic         ren_a,
    input  logic [63:0]  byte_en_a,

    input  logic        elem_mode_a,
    input  logic [1:0]  sew_a,

    // ---------- PORT B : Scalar ----------
    input  logic                     vec_pro_ack,
    input  wire  type_if2imem_s      if2mem_i,
    output type_imem2if_s            mem2if_o,
    output logic [`XLEN-1:0]         instr_read,

    input  logic                     dmem_sel,
    input  type_dbus2peri_s          exe2mem_i,
    output type_peri2dbus_s          mem2wrb_o
);

    // =====================================================
    // Address Decode
    // =====================================================
    logic [ROW_W-1:0] row_a;
    logic [1:0]       bank_sel_a_elem;
    logic [3:0]       byte_off_a_elem;
    logic [ROW_W-1:0] row_b;
    logic [1:0]       bank_sel_b;
    logic [3:0]       byte_off_b;

    // Scalar/Instr interface signals
    logic                 instr_req;
    logic [`XLEN-3:0]     instr_address;
    logic                 instr_ack;
    logic                 load_req;
    logic                 store_req;
    logic [`XLEN-1:0]     write_data;
    logic [`XLEN-3:0]     mem_address;
    logic [3:0]           write_sel_byte;
    logic [`XLEN-1:0]     read_data;
    logic                 read_ack;

    assign load_req       = exe2mem_i.req & dmem_sel & !exe2mem_i.w_en;
    assign store_req      = exe2mem_i.req & dmem_sel &  exe2mem_i.w_en;
    assign write_data     = exe2mem_i.w_data;
    assign write_sel_byte = exe2mem_i.sel_byte;
    assign mem_address    = exe2mem_i.addr[`XLEN-1:2];
    assign mem2wrb_o.r_data = read_data;
    assign mem2wrb_o.ack    = read_ack;
    assign mem2if_o.r_data  = instr_read;
    assign mem2if_o.ack     = instr_ack;
    assign instr_req        = if2mem_i.req;
    assign instr_address    = if2mem_i.addr[`XLEN-1:2];

    assign row_a           = addr_a[ROW_W+5 : 6];
    assign bank_sel_a_elem = addr_a[5:4];
    assign byte_off_a_elem = addr_a[3:0];

    // =====================================================
    // Memory Banks (4 x 128-bit)
    // =====================================================
    `ifdef FPGA
        (* ram_style = "block" *) logic [127:0] mem_bank_0 [D];
        (* ram_style = "block" *) logic [127:0] mem_bank_1 [D];
        (* ram_style = "block" *) logic [127:0] mem_bank_2 [D];
        (* ram_style = "block" *) logic [127:0] mem_bank_3 [D];
    `else
        logic [127:0] mem_bank_0 [D];
        logic [127:0] mem_bank_1 [D];
        logic [127:0] mem_bank_2 [D];
        logic [127:0] mem_bank_3 [D];
    `endif

    `ifdef COMPLIANCE
    initial begin
        // Not required for COMPLIANCE Tests
    end
    `else
    initial begin
        $readmemh("MEM_BANK_0.txt", mem_bank_0);
        $readmemh("MEM_BANK_1.txt", mem_bank_1);
        $readmemh("MEM_BANK_2.txt", mem_bank_2);
        $readmemh("MEM_BANK_3.txt", mem_bank_3);
    end
    `endif

    // =====================================================
    // Combinational Read - Port A
    // =====================================================
    logic [127:0] bank_rdata_a [4];

    always_comb begin
        bank_rdata_a[0] = ren_a ? mem_bank_0[row_a] : 128'b0;
        bank_rdata_a[1] = ren_a ? mem_bank_1[row_a] : 128'b0;
        bank_rdata_a[2] = ren_a ? mem_bank_2[row_a] : 128'b0;
        bank_rdata_a[3] = ren_a ? mem_bank_3[row_a] : 128'b0;
    end

    always_comb begin
        rdata_a = 512'b0;
        if (ren_a) begin
            if (!elem_mode_a) begin
                rdata_a[  0 +: 128] = bank_rdata_a[0];
                rdata_a[128 +: 128] = bank_rdata_a[1];
                rdata_a[256 +: 128] = bank_rdata_a[2];
                rdata_a[384 +: 128] = bank_rdata_a[3];
            end else begin
                automatic logic [127:0] sel_bank;
                sel_bank = bank_rdata_a[bank_sel_a_elem];
                case (sew_a)
                    2'd0: rdata_a[  7:0] = sel_bank[byte_off_a_elem*8 +:  8];
                    2'd1: rdata_a[ 15:0] = sel_bank[byte_off_a_elem*8 +: 16];
                    2'd2: rdata_a[ 31:0] = sel_bank[byte_off_a_elem*8 +: 32];
                    default: rdata_a[7:0] = sel_bank[byte_off_a_elem*8 +: 8];
                endcase
            end
        end
    end

    // =====================================================
    // SINGLE always_ff — ALL bank writes + scalar + instr
    // =====================================================
    always_ff @(posedge clk) begin

        // ---- Default: deassert handshake signals ----
        read_ack   <= 1'b0;
        instr_ack  <= 1'b0;
        instr_read <= `INSTR_NOP;

        if (!rst_n) begin
            instr_read <= `INSTR_NOP;
            instr_ack  <= 1'b0;
            read_ack   <= 1'b0;
        end else begin

            // ---- PORT A : Unit-stride write ----
            if (wen_a && !elem_mode_a) begin
                for (int j = 0; j < 16; j++) begin
                    if (byte_en_a[0*16 + j]) mem_bank_0[row_a][j*8 +: 8] <= wdata_a[0*128 + j*8 +: 8];
                    if (byte_en_a[1*16 + j]) mem_bank_1[row_a][j*8 +: 8] <= wdata_a[1*128 + j*8 +: 8];
                    if (byte_en_a[2*16 + j]) mem_bank_2[row_a][j*8 +: 8] <= wdata_a[2*128 + j*8 +: 8];
                    if (byte_en_a[3*16 + j]) mem_bank_3[row_a][j*8 +: 8] <= wdata_a[3*128 + j*8 +: 8];
                end
            end

            // ---- PORT A : Element-mode write ----
            else if (wen_a && elem_mode_a) begin
                case (sew_a)
                    2'd0: begin
                        case (bank_sel_a_elem)
                            2'd0: mem_bank_0[row_a][byte_off_a_elem*8 +:  8] <= wdata_a[ 7:0];
                            2'd1: mem_bank_1[row_a][byte_off_a_elem*8 +:  8] <= wdata_a[ 7:0];
                            2'd2: mem_bank_2[row_a][byte_off_a_elem*8 +:  8] <= wdata_a[ 7:0];
                            2'd3: mem_bank_3[row_a][byte_off_a_elem*8 +:  8] <= wdata_a[ 7:0];
                        endcase
                    end
                    2'd1: begin
                        case (bank_sel_a_elem)
                            2'd0: mem_bank_0[row_a][byte_off_a_elem*8 +: 16] <= wdata_a[15:0];
                            2'd1: mem_bank_1[row_a][byte_off_a_elem*8 +: 16] <= wdata_a[15:0];
                            2'd2: mem_bank_2[row_a][byte_off_a_elem*8 +: 16] <= wdata_a[15:0];
                            2'd3: mem_bank_3[row_a][byte_off_a_elem*8 +: 16] <= wdata_a[15:0];
                        endcase
                    end
                    2'd2: begin
                        case (bank_sel_a_elem)
                            2'd0: mem_bank_0[row_a][byte_off_a_elem*8 +: 32] <= wdata_a[31:0];
                            2'd1: mem_bank_1[row_a][byte_off_a_elem*8 +: 32] <= wdata_a[31:0];
                            2'd2: mem_bank_2[row_a][byte_off_a_elem*8 +: 32] <= wdata_a[31:0];
                            2'd3: mem_bank_3[row_a][byte_off_a_elem*8 +: 32] <= wdata_a[31:0];
                        endcase
                    end
                    default: begin
                        case (bank_sel_a_elem)
                            2'd0: mem_bank_0[row_a][byte_off_a_elem*8 +:  8] <= wdata_a[ 7:0];
                            2'd1: mem_bank_1[row_a][byte_off_a_elem*8 +:  8] <= wdata_a[ 7:0];
                            2'd2: mem_bank_2[row_a][byte_off_a_elem*8 +:  8] <= wdata_a[ 7:0];
                            2'd3: mem_bank_3[row_a][byte_off_a_elem*8 +:  8] <= wdata_a[ 7:0];
                        endcase
                    end
                endcase
            end

            // ---- PORT B : Scalar Store ----
            else if (store_req) begin
                case (write_sel_byte)
                    4'b0001: mem_bank_0[mem_address][7:0]   <= write_data[7:0];
                    4'b0010: mem_bank_1[mem_address][7:0]   <= write_data[15:8];
                    4'b0100: mem_bank_2[mem_address][7:0]   <= write_data[23:16];
                    4'b1000: mem_bank_3[mem_address][7:0]   <= write_data[31:24];
                    4'b0011: begin
                        mem_bank_0[mem_address][7:0] <= write_data[7:0];
                        mem_bank_1[mem_address][7:0] <= write_data[15:8];
                    end
                    4'b1100: begin
                        mem_bank_2[mem_address][7:0] <= write_data[23:16];
                        mem_bank_3[mem_address][7:0] <= write_data[31:24];
                    end
                    4'b1111: begin
                        mem_bank_0[mem_address][7:0] <= write_data[7:0];
                        mem_bank_1[mem_address][7:0] <= write_data[15:8];
                        mem_bank_2[mem_address][7:0] <= write_data[23:16];
                        mem_bank_3[mem_address][7:0] <= write_data[31:24];
                    end
                    default: ;
                endcase
                read_ack <= 1'b1;
            end

            // ---- PORT B : Scalar Load ----
            else if (load_req) begin
                read_data <= { mem_bank_3[mem_address],
                               mem_bank_2[mem_address],
                               mem_bank_1[mem_address],
                               mem_bank_0[mem_address] };
                read_ack  <= 1'b1;
            end

            // ---- Instruction Fetch ----
            if (instr_req && !instr_ack) begin
                instr_read <= { mem_bank_3[instr_address],
                                mem_bank_2[instr_address],
                                mem_bank_1[instr_address],
                                mem_bank_0[instr_address] };
                instr_ack  <= 1'b1;
            end else if (instr_req && instr_ack) begin
                instr_ack  <= 1'b0;
            end

        end 
    end 
endmodule
