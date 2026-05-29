`include "vector_regfile_defs.svh"
`include "scalar_pcore_interface_defs.svh"
`include "vector_execution_unit.svh"

module memory(
    input  logic clk,
    input  logic rst_n,

    // ---------- PORT A : Vector ----------
    input  logic [`XLEN-1:0]  addr_a,
    input  logic [`VLEN-1:0]  wdata_a,
    output logic [`VLEN-1:0]  rdata_a,
    input  logic               wen_a,
    input  logic               ren_a,
    input  logic [63:0]        byte_en_a,
    input  logic               elem_mode_a,
    input  logic [1:0]         sew_a,

    // ---------- PORT B : Scalar ----------
    input  logic               vec_pro_ack,
    input   var type_if2imem_s      if2mem_i,
    output  var type_imem2if_s      mem2if_o,
    input  logic               dmem_sel,
    input   var type_dbus2peri_s    exe2mem_i,
    output  var type_peri2dbus_s    mem2wrb_o
);

    // =====================================================
    // Parameters — 32-bit bank
    // 4 banks x 32-bit = 128-bit total per row
    // addr[1:0]       = byte offset  (4 bytes per bank)
    // addr[3:2]       = bank select  (4 banks)
    // addr[ROW_W+3:4] = row
    // =====================================================
    localparam int ROW_W          = $clog2(`MEM_BANK_SIZE);
    localparam int BYTES_PER_BANK = `MEM_BANK_WIDTH / 8;       // 32/8 = 4
    localparam int BYTE_BITS      = $clog2(BYTES_PER_BANK);    // clog2(4) = 2
    localparam int BANK_BITS      = $clog2(4);                  // = 2

    // =====================================================
    // Internal copies
    // =====================================================
    type_if2imem_s     if2mem;
    type_dbus2peri_s   exe2mem;

    assign if2mem  = if2mem_i;
    assign exe2mem = exe2mem_i;

    // =====================================================
    // Address Validation
    // =====================================================
    logic dmem_addr_valid;
    logic vec_addr_valid;
    logic imem_addr_valid;

    //assign dmem_addr_valid = (exe2mem.addr >= `DMEM_BASE_ADDR)  && (exe2mem.addr <  `DMEM_BASE_ADDR + `DMEM_SIZE);
    assign dmem_addr_valid = (exe2mem.addr < `DMEM_SIZE)  && (exe2mem.addr <  `DMEM_BASE_ADDR + `DMEM_SIZE) ;
    //assign vec_addr_valid  = (addr_a       >= `DMEM_BASE_ADDR)  && (addr_a       <  `DMEM_BASE_ADDR + `DMEM_SIZE);
    assign vec_addr_valid = (addr_a < `DMEM_SIZE) && (addr_a       <  `DMEM_BASE_ADDR + `DMEM_SIZE);
    assign imem_addr_valid = (if2mem.addr  >= `IMEM_BASE_ADDR)  && (if2mem.addr  <  `IMEM_BASE_ADDR + `IMEM_SIZE);

    // =====================================================
    // Local addresses — base subtract
    // =====================================================
    logic [`XLEN-1:0] instr_local_addr;
    logic [`XLEN-1:0] addr_b_local;
    logic [`XLEN-1:0] addr_a_local;

    assign instr_local_addr = imem_addr_valid ? (if2mem.addr  - `IMEM_BASE_ADDR) : '0;
    assign addr_b_local     = dmem_addr_valid ? (exe2mem.addr + `DMEM_BASE_ADDR) : '0;
    assign addr_a_local     = vec_addr_valid  ? (addr_a       + `DMEM_BASE_ADDR) : '0;

    // =====================================================
    // Address Decode — 32-bit bank
    // =====================================================
    logic [ROW_W-1:0] row_a;
    logic [1:0]       bank_sel_a_elem;
    logic [1:0]       byte_off_a_elem;   // 2-bit for 32-bit bank

    logic [ROW_W-1:0] row_b;
    logic [1:0]       bank_sel_b;
    logic [1:0]       byte_off_b;        // 2-bit for 32-bit bank

    logic [ROW_W-1:0] instr_row;
    logic [1:0]       instr_bank_sel;
    logic [1:0]       instr_byte_off;    // 2-bit for 32-bit bank

    // IMEM decode
    assign instr_byte_off = instr_local_addr[BYTE_BITS-1 : 0];
    assign instr_bank_sel = instr_local_addr[BYTE_BITS+BANK_BITS-1 : BYTE_BITS];
    assign instr_row      = instr_local_addr[ROW_W+BYTE_BITS+BANK_BITS-1 : BYTE_BITS+BANK_BITS];

    // Scalar DMEM decode
    assign byte_off_b = exe2mem.addr[BYTE_BITS-1 : 0];
    //assign bank_sel_b = addr_b_local[BYTE_BITS+BANK_BITS-1 : BYTE_BITS];
    assign bank_sel_b = exe2mem.addr[BYTE_BITS+BANK_BITS-1 : BYTE_BITS];
    assign row_b      = exe2mem.addr[ROW_W+BYTE_BITS+BANK_BITS-1 : BYTE_BITS+BANK_BITS];

    // Vector DMEM decode
    assign byte_off_a_elem = addr_a[BYTE_BITS-1 : 0];
    assign bank_sel_a_elem = addr_a[BYTE_BITS+BANK_BITS-1 : BYTE_BITS];
    assign row_a           = addr_a[ROW_W+BYTE_BITS+BANK_BITS-1 : BYTE_BITS+BANK_BITS];

    // =====================================================
    // Scalar interface signals
    // =====================================================
    logic               instr_req;
    logic [`XLEN-3:0]   instr_address;
    logic               instr_ack;
    logic               load_req;
    logic               store_req;
    logic [`XLEN-1:0]   write_data;
    logic [`XLEN-3:0]   mem_address;
    logic [3:0]         write_sel_byte;
    logic [`XLEN-1:0]   read_data;
    logic               read_ack;
    logic [`XLEN-1:0]   instr_read;

    assign load_req         = exe2mem.req & dmem_sel & !exe2mem.w_en & dmem_addr_valid;
    assign store_req        = exe2mem.req & dmem_sel &  exe2mem.w_en & dmem_addr_valid;
    assign write_data       = exe2mem.w_data;
    assign write_sel_byte   = exe2mem.sel_byte;
    assign mem_address      = exe2mem.addr[`XLEN-1:2];
    assign mem2wrb_o.r_data = read_data;
    assign mem2wrb_o.ack    = read_ack;
    assign mem2if_o.r_data  = instr_read;
    assign mem2if_o.ack     = instr_ack;
    assign instr_req        = if2mem.req;
    assign instr_address    = if2mem.addr[`XLEN-1:2];

    // =====================================================
    // Memory Banks (4 x 32-bit)
    // =====================================================
    `ifdef FPGA
        (* ram_style = "block" *) logic [`MEM_BANK_WIDTH-1:0] mem_bank_0 [`MEM_BANK_SIZE];
        (* ram_style = "block" *) logic [`MEM_BANK_WIDTH-1:0] mem_bank_1 [`MEM_BANK_SIZE];
        (* ram_style = "block" *) logic [`MEM_BANK_WIDTH-1:0] mem_bank_2 [`MEM_BANK_SIZE];
        (* ram_style = "block" *) logic [`MEM_BANK_WIDTH-1:0] mem_bank_3 [`MEM_BANK_SIZE];
    `else
        logic [`MEM_BANK_WIDTH-1:0] mem_bank_0 [`MEM_BANK_SIZE];
        logic [`MEM_BANK_WIDTH-1:0] mem_bank_1 [`MEM_BANK_SIZE];
        logic [`MEM_BANK_WIDTH-1:0] mem_bank_2 [`MEM_BANK_SIZE];
        logic [`MEM_BANK_WIDTH-1:0] mem_bank_3 [`MEM_BANK_SIZE];
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
    // Address Alignment Check — Port A (Vector)
    // =====================================================
    logic addr_misaligned_a;

    always_comb begin
        addr_misaligned_a = 1'b0;
        if ((ren_a || wen_a) && vec_addr_valid) begin
            case (sew_a)
                2'd0: addr_misaligned_a = 1'b0;
                2'd1: addr_misaligned_a = byte_off_a_elem[0];
                2'd2: addr_misaligned_a = |byte_off_a_elem[1:0];
                default: addr_misaligned_a = 1'b0;
            endcase
        end
    end

    // =====================================================
    // Combinational Read - Port A (Vector)
    // 32-bit bank — unit stride: sabhi 4 banks = 128-bit
    // =====================================================
    logic [`MEM_BANK_WIDTH-1:0] bank_rdata_a [4];

    always_comb begin
        bank_rdata_a[0] = (ren_a && vec_addr_valid) ? mem_bank_0[row_a] : 'b0;
        bank_rdata_a[1] = (ren_a && vec_addr_valid) ? mem_bank_1[row_a] : 'b0;
        bank_rdata_a[2] = (ren_a && vec_addr_valid) ? mem_bank_2[row_a] : 'b0;
        bank_rdata_a[3] = (ren_a && vec_addr_valid) ? mem_bank_3[row_a] : 'b0;
    end

    /*always_comb begin
        rdata_a = 'b0;
        if (ren_a && !addr_misaligned_a) begin
            if (!elem_mode_a) begin
                rdata_a[0*`MEM_BANK_WIDTH +: `MEM_BANK_WIDTH] = bank_rdata_a[0];
                rdata_a[1*`MEM_BANK_WIDTH +: `MEM_BANK_WIDTH] = bank_rdata_a[1];
                rdata_a[2*`MEM_BANK_WIDTH +: `MEM_BANK_WIDTH] = bank_rdata_a[2];
                rdata_a[3*`MEM_BANK_WIDTH +: `MEM_BANK_WIDTH] = bank_rdata_a[3];
            end else begin
                automatic logic [`MEM_BANK_WIDTH-1:0] sel_bank;
                sel_bank = bank_rdata_a[bank_sel_a_elem];
                case (sew_a)
                    2'd0: rdata_a[ 7:0] = sel_bank[byte_off_a_elem*8 +:  8];
                    2'd1: rdata_a[15:0] = sel_bank[byte_off_a_elem*8 +: 16];
                    2'd2: rdata_a[31:0] = sel_bank[byte_off_a_elem*8 +: 32];
                    default: rdata_a[7:0] = sel_bank[byte_off_a_elem*8 +: 8];
                endcase
            end
        end
    end*/

    always_comb begin
        rdata_a = 'b0;
        if (ren_a && !addr_misaligned_a) begin
            if (!elem_mode_a) begin
                for (int i = 0; i < 4; i++) begin
                    automatic logic [1:0] bank_idx;
                    automatic logic [ROW_W-1:0] row_idx;
                    bank_idx = (bank_sel_a_elem + i) % 4;
                    row_idx = ((bank_sel_a_elem + i) > 3) ? (row_a + 1) : row_a;
                    case (bank_idx)
                        2'd0: rdata_a[i*`MEM_BANK_WIDTH +: `MEM_BANK_WIDTH] = mem_bank_0[row_idx];
                        2'd1: rdata_a[i*`MEM_BANK_WIDTH +: `MEM_BANK_WIDTH] = mem_bank_1[row_idx];
                        2'd2: rdata_a[i*`MEM_BANK_WIDTH +: `MEM_BANK_WIDTH] = mem_bank_2[row_idx];
                        2'd3: rdata_a[i*`MEM_BANK_WIDTH +: `MEM_BANK_WIDTH] = mem_bank_3[row_idx];
                    endcase
                end
            end else begin
                automatic logic [`MEM_BANK_WIDTH-1:0] sel_bank;
                sel_bank = bank_rdata_a[bank_sel_a_elem];
                case (sew_a)
                    2'd0: rdata_a[ 7:0] = sel_bank[byte_off_a_elem*8 +:  8];
                    2'd1: rdata_a[15:0] = sel_bank[byte_off_a_elem*8 +: 16];
                    2'd2: rdata_a[31:0] = sel_bank[byte_off_a_elem*8 +: 32];
                    default: rdata_a[7:0] = sel_bank[byte_off_a_elem*8 +: 8];
                endcase
            end
        end
    end
    // =====================================================
    // SINGLE always_ff
    // =====================================================
    always_ff @(posedge clk) begin

        read_ack   <= 1'b0;
        instr_ack  <= 1'b0;
        instr_read <= `INSTR_NOP;

        if (!rst_n) begin
            instr_read <= `INSTR_NOP;
            instr_ack  <= 1'b0;
            read_ack   <= 1'b0;
        end else begin

            // ---- PORT A : Unit-stride write ----
            // 32-bit bank: MEM_WIDTH_ELEM = 4 bytes per bank
            if (wen_a && !elem_mode_a && !addr_misaligned_a && vec_addr_valid) begin
                for (int j = 0; j < `MEM_WIDTH_ELEM; j++) begin
                    if (byte_en_a[0*`MEM_WIDTH_ELEM + j]) mem_bank_0[row_a][j*8 +: 8] <= wdata_a[0*`MEM_BANK_WIDTH + j*8 +: 8];
                    if (byte_en_a[1*`MEM_WIDTH_ELEM + j]) mem_bank_1[row_a][j*8 +: 8] <= wdata_a[1*`MEM_BANK_WIDTH + j*8 +: 8];
                    if (byte_en_a[2*`MEM_WIDTH_ELEM + j]) mem_bank_2[row_a][j*8 +: 8] <= wdata_a[2*`MEM_BANK_WIDTH + j*8 +: 8];
                    if (byte_en_a[3*`MEM_WIDTH_ELEM + j]) mem_bank_3[row_a][j*8 +: 8] <= wdata_a[3*`MEM_BANK_WIDTH + j*8 +: 8];
                end
            end

            // ---- PORT A : Element-mode write ----
            if (wen_a && elem_mode_a && !addr_misaligned_a && vec_addr_valid) begin
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
            if (store_req) begin
                case (write_sel_byte)
                    4'b0001: begin  // Byte
                        case (bank_sel_b)
                            2'd0: mem_bank_0[row_b][byte_off_b*8 +: 8] <= write_data[7:0];
                            2'd1: mem_bank_1[row_b][byte_off_b*8 +: 8] <= write_data[7:0];
                            2'd2: mem_bank_2[row_b][byte_off_b*8 +: 8] <= write_data[7:0];
                            2'd3: mem_bank_3[row_b][byte_off_b*8 +: 8] <= write_data[7:0];
                        endcase
                    end
                    4'b0011: begin  // Halfword
                        case (bank_sel_b)
                            2'd0: begin
                                mem_bank_0[row_b][ byte_off_b   *8 +: 8] <= write_data[ 7:0];
                                mem_bank_0[row_b][(byte_off_b+1)*8 +: 8] <= write_data[15:8];
                            end
                            2'd1: begin
                                mem_bank_1[row_b][ byte_off_b   *8 +: 8] <= write_data[ 7:0];
                                mem_bank_1[row_b][(byte_off_b+1)*8 +: 8] <= write_data[15:8];
                            end
                            2'd2: begin
                                mem_bank_2[row_b][ byte_off_b   *8 +: 8] <= write_data[ 7:0];
                                mem_bank_2[row_b][(byte_off_b+1)*8 +: 8] <= write_data[15:8];
                            end
                            2'd3: begin
                                mem_bank_3[row_b][ byte_off_b   *8 +: 8] <= write_data[ 7:0];
                                mem_bank_3[row_b][(byte_off_b+1)*8 +: 8] <= write_data[15:8];
                            end
                        endcase
                    end
                    4'b1111: begin  // Word
                        case (bank_sel_b)
                            2'd0: begin
                                mem_bank_0[row_b][ byte_off_b   *8 +: 8] <= write_data[ 7: 0];
                                mem_bank_0[row_b][(byte_off_b+1)*8 +: 8] <= write_data[15: 8];
                                mem_bank_0[row_b][(byte_off_b+2)*8 +: 8] <= write_data[23:16];
                                mem_bank_0[row_b][(byte_off_b+3)*8 +: 8] <= write_data[31:24];
                            end
                            2'd1: begin
                                mem_bank_1[row_b][ byte_off_b   *8 +: 8] <= write_data[ 7: 0];
                                mem_bank_1[row_b][(byte_off_b+1)*8 +: 8] <= write_data[15: 8];
                                mem_bank_1[row_b][(byte_off_b+2)*8 +: 8] <= write_data[23:16];
                                mem_bank_1[row_b][(byte_off_b+3)*8 +: 8] <= write_data[31:24];
                            end
                            2'd2: begin
                                mem_bank_2[row_b][ byte_off_b   *8 +: 8] <= write_data[ 7: 0];
                                mem_bank_2[row_b][(byte_off_b+1)*8 +: 8] <= write_data[15: 8];
                                mem_bank_2[row_b][(byte_off_b+2)*8 +: 8] <= write_data[23:16];
                                mem_bank_2[row_b][(byte_off_b+3)*8 +: 8] <= write_data[31:24];
                            end
                            2'd3: begin
                                mem_bank_3[row_b][ byte_off_b   *8 +: 8] <= write_data[ 7: 0];
                                mem_bank_3[row_b][(byte_off_b+1)*8 +: 8] <= write_data[15: 8];
                                mem_bank_3[row_b][(byte_off_b+2)*8 +: 8] <= write_data[23:16];
                                mem_bank_3[row_b][(byte_off_b+3)*8 +: 8] <= write_data[31:24];
                            end
                        endcase
                    end
                endcase
                read_ack <= 1'b1;
            end

            // ---- PORT B : Scalar Load ----
            // 32-bit bank — word read sirf us bank se jo bank_sel_b bataye
            if (load_req) begin
                case (bank_sel_b)
                    2'd0: read_data <= mem_bank_0[row_b];
                    2'd1: read_data <= mem_bank_1[row_b];
                    2'd2: read_data <= mem_bank_2[row_b];
                    2'd3: read_data <= mem_bank_3[row_b];
                endcase
                read_ack <= 1'b1;
            end else if (~dmem_addr_valid && exe2mem.req) begin
                read_ack <= 1'b1;
                read_data <= 32'hDEADBEEF; 
            end

            // ---- Instruction Fetch ----
            // 32-bit bank — instruction sirf us bank se jo instr_bank_sel bataye
            if (instr_req & !instr_ack & imem_addr_valid) begin
                case (instr_bank_sel)
                    2'd0: instr_read <= mem_bank_0[instr_row];
                    2'd1: instr_read <= mem_bank_1[instr_row];
                    2'd2: instr_read <= mem_bank_2[instr_row];
                    2'd3: instr_read <= mem_bank_3[instr_row];
                endcase
                instr_ack <= 1'b1;
            end else if (instr_req & instr_ack) begin
                instr_ack <= 1'b0;
            end else begin
                instr_read <= `INSTR_NOP;
                instr_ack  <= 1'b0;
            end
        end
    end
endmodule