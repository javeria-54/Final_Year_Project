`include "vector_regfile_defs.svh"

module vec_lsu (
    input   logic                               clk,
    input   logic                               n_rst,

    input   logic   [`XLEN-1:0]                 rs1_data,
    input   logic   [`XLEN-1:0]                 rs2_data,

    input   logic   [9:0]                       vlmax,
    input   logic   [6:0]                       sew,

    input   logic                               stride_sel,
    input   logic                               ld_inst,
    input   logic                               st_inst,
    input   logic                               index_str,
    input   logic                               index_unordered,

    input   logic   [`MAX_VLEN-1:0]             vs2_data,
    input   logic   [`MAX_VLEN-1:0]             vs3_data,

    input   logic                               mew,
    input   logic   [2:0]                       width,
    input   logic                               inst_done,

    output  logic   [31:0]                      mem_addr,
    output  logic                               mem_addr_valid,
    input   logic                               mem_addr_ready,

    output  logic   [511:0]                     mem_wdata,
    output  logic   [63:0]                      mem_byte_en,
    output  logic                               mem_wdata_valid,
    input   logic                               mem_wdata_ready,

    input   logic   [511:0]                     mem_rdata,
    input   logic                               mem_rdata_valid,
    output  logic                               mem_rdata_ready,

    input   logic                               mem_write_done,
    input   logic                               mem_write_valid,
    output  logic                               mem_write_ready,

    output  logic   [`MAX_VLEN-1:0]             vd_data,
    output  logic                               is_loaded,
    output  logic                               is_stored,
    output  logic                               error_flag
);

    // =========================================================================
    // State encoding
    // =========================================================================
    typedef enum logic [3:0] {
        IDLE,
        RD_ADDR,
        RD_WAIT_DATA,
        RD_NEXT,
        WR_ADDR,
        WR_WAIT_RESP,
        WR_NEXT,
        RD_UNIT,
        RD_UNIT_WAIT,
        WR_UNIT,
        WR_UNIT_WAIT_RESP
    } lsu_state_e;

    lsu_state_e c_state, n_state;

    // =========================================================================
    // Stride type decode
    // =========================================================================
    logic unit_stride, const_stride;
    assign unit_stride  =  stride_sel || ($unsigned(rs2_data) == 1);
    assign const_stride = !stride_sel && ($unsigned(rs2_data) != 1) && !index_str;

    // =========================================================================
    // Error flag
    // =========================================================================
    always_comb begin
        error_flag = 0;
        if (index_str)
            case (width)
                3'b000, 3'b101, 3'b110: ;
                default: error_flag = 1;
            endcase
    end

    // =========================================================================
    // Element counter
    // =========================================================================
    logic [$clog2(`MAX_VLEN)-1:0] count_el;
    logic                         count_en;
    logic [$clog2(`MAX_VLEN)-1:0] next_el;
    assign next_el = count_el + 1'b1;

    logic do_reset_counter;
    assign do_reset_counter = inst_done || (c_state == IDLE);

    always_ff @(posedge clk or negedge n_rst) begin
        if (!n_rst)                  count_el <= '0;
        else if (do_reset_counter)   count_el <= '0;
        else if (count_en)           count_el <= (count_el == vlmax-1) ? '0 : next_el;
    end

    logic load_complete, store_complete;
    logic data_en, is_loaded_reg, is_stored_reg;
    assign load_complete  = (count_el == vlmax-1) && data_en;
    assign store_complete = (count_el == vlmax-1) && mem_write_valid;

    // =========================================================================
    // New instruction flag
    // =========================================================================
    logic new_inst;
    always_ff @(posedge clk or negedge n_rst) begin
        if (!n_rst)
            new_inst <= 1;
        else if (inst_done)
            new_inst <= 1;
        else if ((c_state == IDLE) && (ld_inst || st_inst) && new_inst)
            new_inst <= 0;
    end

    // =========================================================================
    // Index-ordered stride extraction
    // =========================================================================
    logic [`XLEN-1:0] selected_stride;
    logic [`XLEN-1:0] next_stride_val;
    logic             index_str_en;

    always_comb begin
        case (width)
            3'b000: selected_stride = {{(`XLEN-8){1'b0}},  vs2_data[count_el*8  +:  8]};
            3'b101: selected_stride = {{(`XLEN-16){1'b0}}, vs2_data[count_el*16 +: 16]};
            3'b110: selected_stride =                       vs2_data[count_el*32 +: 32];
            default: selected_stride = '0;
        endcase
    end

    always_comb begin
        case (width)
            3'b000: next_stride_val = {{(`XLEN-8){1'b0}},  vs2_data[next_el*8  +:  8]};
            3'b101: next_stride_val = {{(`XLEN-16){1'b0}}, vs2_data[next_el*16 +: 16]};
            3'b110: next_stride_val =                       vs2_data[next_el*32 +: 32];
            default: next_stride_val = '0;
        endcase
    end

    // =========================================================================
    // Index-Unordered: LFSR + tracking
    //
    // FIX vs File-2: LFSR is a REGISTERED signal so it advances each cycle
    // while index_unordered is active, giving true pseudo-random sequencing.
    // File-2 had it combinational (always reset to seed 1 every cycle).
    // =========================================================================
    localparam LFSR_W = $clog2(`VLEN) + 1;

    logic [LFSR_W-1:0]              lfsr_reg;
    logic [$clog2(`VLEN)-1:0]       random_index;
    logic [$clog2(`VLEN)-1:0]       unorder_idx_counter;
    logic [`XLEN-1:0]               random_str_array [0:`VLEN-1];
    logic [`XLEN-1:0]               random_stride;
    logic [`VLEN-1:0]               index_used;
    logic                           valid_entry;
    logic                           all_indices_used;

    // LFSR advances every cycle when unordered mode is active
    always_ff @(posedge clk or negedge n_rst) begin
        if (!n_rst)
            lfsr_reg <= LFSR_W'(1);
        else if (index_unordered)
            lfsr_reg <= {lfsr_reg[LFSR_W-2:0],
                         lfsr_reg[LFSR_W-1] ^ lfsr_reg[LFSR_W-3] ^
                         lfsr_reg[LFSR_W-4] ^ 1'b1};
    end

    // Combinational: pick first unused slot starting from LFSR-derived seed
    always_comb begin
        valid_entry      = 0;
        random_stride    = '0;
        random_index     = '0;
        all_indices_used = 1'b1;

        // Check if all active elements have been visited
        for (int k = 0; k < `VLEN; k++) begin
            if (k < vlmax && !index_used[k])
                all_indices_used = 1'b0;
        end

        if (index_unordered && !all_indices_used) begin
            // Start scan from LFSR seed
            random_index = lfsr_reg[$clog2(`VLEN)-1:0] % vlmax;

            for (int i = 0; i < `VLEN; i++) begin
                if (!index_used[random_index]) begin
                    valid_entry = 1;
                    break;
                end else begin
                    random_index = (random_index == vlmax-1) ? '0 : random_index + 1;
                end
            end

            if (valid_entry) begin
                case (width)
                    3'b000: random_stride = {{(`XLEN-8){1'b0}},  vs2_data[random_index*8  +:  8]};
                    3'b101: random_stride = {{(`XLEN-16){1'b0}}, vs2_data[random_index*16 +: 16]};
                    3'b110: random_stride =                       vs2_data[random_index*32 +: 32];
                    default: random_stride = '0;
                endcase
            end
        end
    end

    // Register chosen stride at the selected random_index slot
    always_ff @(posedge clk or negedge n_rst) begin
        if (!n_rst) begin
            unorder_idx_counter <= '0;
            index_used          <= '0;
            for (int i = 0; i < `VLEN; i++)
                random_str_array[i] <= '0;
        end else begin
            if (is_loaded_reg || is_stored_reg) begin
                index_used          <= '0;
                unorder_idx_counter <= '0;
                for (int i = 0; i < `VLEN; i++)
                    random_str_array[i] <= '0;
            end else if (index_unordered && valid_entry) begin
                // Store at the sequential counter slot so count_el lookup works
                random_str_array[unorder_idx_counter] <= random_stride;
                index_used[random_index]              <= 1'b1;
                unorder_idx_counter <= (unorder_idx_counter == vlmax-1) ? '0
                                                                         : unorder_idx_counter + 1;
            end
        end
    end

    // =========================================================================
    // Stride value mux
    //   index ordered:   selected_stride
    //   index unordered: random_stride (el-0) or random_str_array[count_el]
    //   const:           rs2_data
    // =========================================================================
    logic [`XLEN-1:0] stride_value;
    always_comb begin
        stride_value = '0;
        if (index_str_en) begin
            if (index_unordered)
                stride_value = (count_el == 0) ? random_stride
                                               : random_str_array[count_el];
            else
                stride_value = selected_stride;
        end else if (const_stride) begin
            stride_value = rs2_data;
        end
    end

    // =========================================================================
    // Element-0 address (combinational, used in IDLE)
    // =========================================================================
    logic [`XLEN-1:0] init_addr;
    always_comb begin
        if (index_str)
            // For unordered el-0, random_stride is already computed above
            init_addr = rs1_data + (index_unordered ? random_stride : selected_stride);
        else
            init_addr = rs1_data;
    end

    // =========================================================================
    // Address register
    // =========================================================================
    logic [`XLEN-1:0] current_addr_reg;

    always_ff @(posedge clk or negedge n_rst) begin
        if (!n_rst)
            current_addr_reg <= '0;
        else if (inst_done || (c_state == IDLE))
            current_addr_reg <= '0;
        else if (count_en) begin
            if      (unit_stride)   current_addr_reg <= rs1_data + (next_el * (sew >> 3));
            else if (const_stride)  current_addr_reg <= rs1_data + (next_el * stride_value);
            else if (index_str)     current_addr_reg <= rs1_data + next_stride_val;
        end
    end

    // =========================================================================
    // Write data register
    // Cleared on every new transaction start, then filled by element.
    // For unordered: element slot is random_str_array[el] (the vs3 element index)
    // =========================================================================
    logic [511:0] current_wdata_reg;
    logic [63:0]  current_byte_en_reg;

    always_ff @(posedge clk or negedge n_rst) begin
        if (!n_rst) begin
            current_wdata_reg   <= '0;
            current_byte_en_reg <= '0;

        // Pack on IDLE when new store instruction detected
        end else if ((c_state == IDLE) && st_inst && new_inst && !inst_done) begin
            current_wdata_reg   <= '0;
            current_byte_en_reg <= '0;

            if (unit_stride) begin
                for (int i = 0; i < `MAX_VLEN; i++) begin
                    if (i < vlmax) begin
                        case (sew)
                            7'd8:  begin
                                current_wdata_reg[i*8  +:  8] <= vs3_data[i*8  +:  8];
                                current_byte_en_reg[i]         <= 1'b1;
                            end
                            7'd16: begin
                                current_wdata_reg[i*16 +: 16] <= vs3_data[i*16 +: 16];
                                current_byte_en_reg[2*i +: 2]  <= 2'b11;
                            end
                            7'd32: begin
                                current_wdata_reg[i*32 +: 32] <= vs3_data[i*32 +: 32];
                                current_byte_en_reg[4*i +: 4]  <= 4'b1111;
                            end
                            7'd64: begin
                                current_wdata_reg[i*64 +: 64] <= vs3_data[i*64 +: 64];
                                current_byte_en_reg[8*i +: 8]  <= 8'hFF;
                            end
                            default: ;
                        endcase
                    end
                end
            end else begin
                // Element-0 data (count_el=0 at this point)
                if (index_str && index_unordered) begin
                    // Unordered el-0: use random_str_array[0] as vs3 element index
                    // random_str_array[0] holds the stride chosen for slot-0,
                    // but vs3 element slot == unorder_idx_counter (0 here)
                    case (sew)
                        7'd8:  begin current_wdata_reg[7:0]  <= vs3_data[0*8  +:  8]; current_byte_en_reg <= 64'd1;  end
                        7'd16: begin current_wdata_reg[15:0] <= vs3_data[0*16 +: 16]; current_byte_en_reg <= 64'd3;  end
                        7'd32: begin current_wdata_reg[31:0] <= vs3_data[0*32 +: 32]; current_byte_en_reg <= 64'hF;  end
                        7'd64: begin current_wdata_reg[63:0] <= vs3_data[0*64 +: 64]; current_byte_en_reg <= 64'hFF; end
                        default: ;
                    endcase
                end else begin
                    case (sew)
                        7'd8:  begin current_wdata_reg[7:0]  <= vs3_data[0*8  +:  8]; current_byte_en_reg <= 64'd1;  end
                        7'd16: begin current_wdata_reg[15:0] <= vs3_data[0*16 +: 16]; current_byte_en_reg <= 64'd3;  end
                        7'd32: begin current_wdata_reg[31:0] <= vs3_data[0*32 +: 32]; current_byte_en_reg <= 64'hF;  end
                        7'd64: begin current_wdata_reg[63:0] <= vs3_data[0*64 +: 64]; current_byte_en_reg <= 64'hFF; end
                        default: ;
                    endcase
                end
            end

        // After each element (count_en): load next element's data
        end else if (count_en && !unit_stride) begin
            current_wdata_reg   <= '0;
            current_byte_en_reg <= '0;

            if (index_str && index_unordered) begin
                // next_el holds the sequential visit counter;
                // random_str_array[next_el] holds the vs3 slot for that visit
                // For stores, vs3 element order == visit order, so use next_el directly
                case (sew)
                    7'd8:  begin current_wdata_reg[7:0]  <= vs3_data[next_el*8  +:  8]; current_byte_en_reg <= 64'd1;  end
                    7'd16: begin current_wdata_reg[15:0] <= vs3_data[next_el*16 +: 16]; current_byte_en_reg <= 64'd3;  end
                    7'd32: begin current_wdata_reg[31:0] <= vs3_data[next_el*32 +: 32]; current_byte_en_reg <= 64'hF;  end
                    7'd64: begin current_wdata_reg[63:0] <= vs3_data[next_el*64 +: 64]; current_byte_en_reg <= 64'hFF; end
                    default: ;
                endcase
            end else begin
                case (sew)
                    7'd8:  begin current_wdata_reg[7:0]  <= vs3_data[next_el*8  +:  8]; current_byte_en_reg <= 64'd1;  end
                    7'd16: begin current_wdata_reg[15:0] <= vs3_data[next_el*16 +: 16]; current_byte_en_reg <= 64'd3;  end
                    7'd32: begin current_wdata_reg[31:0] <= vs3_data[next_el*32 +: 32]; current_byte_en_reg <= 64'hF;  end
                    7'd64: begin current_wdata_reg[63:0] <= vs3_data[next_el*64 +: 64]; current_byte_en_reg <= 64'hFF; end
                    default: ;
                endcase
            end
        end
    end

    // =========================================================================
    // Output registers
    // =========================================================================
    always_ff @(posedge clk or negedge n_rst) begin
        if (!n_rst) begin is_loaded <= 0; is_stored <= 0; end
        else        begin is_loaded <= is_loaded_reg; is_stored <= is_stored_reg; end
    end

    // =========================================================================
    // Load data capture
    // =========================================================================
    logic [2*`XLEN-1:0] loaded_data [0:`MAX_VLEN-1];

    always_ff @(posedge clk or negedge n_rst) begin
        if (!n_rst) begin
            for (int i = 0; i < `MAX_VLEN; i++) loaded_data[i] <= '0;
        end else if (mem_rdata_valid && mem_rdata_ready) begin
            if (unit_stride) begin
                for (int i = 0; i < `MAX_VLEN; i++) begin
                    if (i < vlmax) begin
                        case (sew)
                            7'd8:  loaded_data[i] <= mem_rdata[i*8  +:  8];
                            7'd16: loaded_data[i] <= mem_rdata[i*16 +: 16];
                            7'd32: loaded_data[i] <= mem_rdata[i*32 +: 32];
                            7'd64: loaded_data[i] <= mem_rdata[i*64 +: 64];
                            default: loaded_data[i] <= '0;
                        endcase
                    end
                end
            end else begin
                // For unordered: data for visit-slot count_el goes to count_el
                // (The TB serves data in the visit order the DUT requests)
                case (sew)
                    7'd8:  loaded_data[count_el] <= mem_rdata[7:0];
                    7'd16: loaded_data[count_el] <= mem_rdata[15:0];
                    7'd32: loaded_data[count_el] <= mem_rdata[31:0];
                    7'd64: loaded_data[count_el] <= mem_rdata[63:0];
                    default: loaded_data[count_el] <= mem_rdata;
                endcase
            end
        end
    end

    always_comb begin
        vd_data = '0;
        for (int i = 0; i < `MAX_VLEN; i++) begin
            if (i < vlmax) begin
                case (sew)
                    7'd8:  vd_data[i*8  +:  8] = loaded_data[i][7:0];
                    7'd16: vd_data[i*16 +: 16] = loaded_data[i][15:0];
                    7'd32: vd_data[i*32 +: 32] = loaded_data[i][31:0];
                    7'd64: vd_data[i*64 +: 64] = loaded_data[i][63:0];
                    default: ;
                endcase
            end
        end
    end

    // =========================================================================
    // Main FSM
    // =========================================================================
    always_ff @(posedge clk or negedge n_rst) begin
        if (!n_rst) c_state <= IDLE;
        else        c_state <= n_state;
    end

    always_comb begin
        n_state          = c_state;
        count_en         = 0;
        mem_addr         = current_addr_reg;
        mem_addr_valid   = 0;
        mem_wdata        = current_wdata_reg;
        mem_byte_en      = current_byte_en_reg;
        mem_wdata_valid  = 0;
        mem_rdata_ready  = 0;
        mem_write_ready  = 0;
        index_str_en     = 0;
        data_en          = 0;
        is_loaded_reg    = 0;
        is_stored_reg    = 0;

        if (error_flag) begin
            n_state = IDLE;
        end else case (c_state)

            // -----------------------------------------------------------------
            IDLE: begin
                if (ld_inst && new_inst) begin
                    if (unit_stride) begin
                        mem_addr       = rs1_data;
                        mem_addr_valid = 1;
                        n_state        = RD_UNIT;
                    end else begin
                        // Both ordered and unordered use RD_ADDR path
                        // init_addr uses random_stride for unordered el-0
                        index_str_en   = index_str;
                        mem_addr       = init_addr;
                        mem_addr_valid = 1;
                        n_state        = RD_ADDR;
                    end
                end else if (st_inst && new_inst) begin
                    if (unit_stride) begin
                        mem_addr        = rs1_data;
                        mem_addr_valid  = 1;
                        mem_wdata_valid = 1;
                        n_state         = WR_UNIT;
                    end else begin
                        index_str_en    = index_str;
                        mem_addr        = init_addr;
                        mem_addr_valid  = 1;
                        mem_wdata_valid = 1;
                        n_state         = WR_ADDR;
                    end
                end
            end

            // -----------------------------------------------------------------
            RD_ADDR: begin
                mem_addr       = (count_el == 0) ? init_addr : current_addr_reg;
                mem_addr_valid = 1;
                index_str_en   = index_str;
                if (mem_addr_ready) begin
                    n_state         = RD_WAIT_DATA;
                    mem_rdata_ready = 1;
                end
            end

            RD_WAIT_DATA: begin
                mem_rdata_ready = 1;
                if (mem_rdata_valid) begin
                    data_en = 1;
                    if (load_complete) begin
                        is_loaded_reg = 1;
                        n_state       = IDLE;
                    end else begin
                        count_en = 1;
                        n_state  = RD_NEXT;
                    end
                end
            end

            RD_NEXT: begin
                mem_addr       = current_addr_reg;
                mem_addr_valid = 1;
                index_str_en   = index_str;
                if (mem_addr_ready) begin
                    n_state         = RD_WAIT_DATA;
                    mem_rdata_ready = 1;
                end
            end

            // -----------------------------------------------------------------
            RD_UNIT: begin
                mem_addr       = rs1_data;
                mem_addr_valid = 1;
                if (mem_addr_ready) begin
                    n_state         = RD_UNIT_WAIT;
                    mem_rdata_ready = 1;
                end
            end

            RD_UNIT_WAIT: begin
                mem_rdata_ready = 1;
                if (mem_rdata_valid) begin
                    data_en       = 1;
                    is_loaded_reg = 1;
                    n_state       = IDLE;
                end
            end

            // -----------------------------------------------------------------
            WR_ADDR: begin
                mem_addr        = (count_el == 0) ? init_addr : current_addr_reg;
                mem_addr_valid  = 1;
                mem_wdata       = current_wdata_reg;
                mem_byte_en     = current_byte_en_reg;
                mem_wdata_valid = 1;
                index_str_en    = index_str;
                if (mem_addr_ready && mem_wdata_ready) begin
                    n_state         = WR_WAIT_RESP;
                    mem_write_ready = 1;
                end
            end

            WR_WAIT_RESP: begin
                mem_write_ready = 1;
                if (mem_write_valid) begin
                    if (store_complete) begin
                        is_stored_reg = 1;
                        n_state       = IDLE;
                    end else begin
                        count_en = 1;
                        n_state  = WR_NEXT;
                    end
                end
            end

            WR_NEXT: begin
                mem_addr        = current_addr_reg;
                mem_addr_valid  = 1;
                mem_wdata       = current_wdata_reg;
                mem_byte_en     = current_byte_en_reg;
                mem_wdata_valid = 1;
                index_str_en    = index_str;
                if (mem_addr_ready && mem_wdata_ready) begin
                    n_state         = WR_WAIT_RESP;
                    mem_write_ready = 1;
                end
            end

            // -----------------------------------------------------------------
            WR_UNIT: begin
                mem_addr        = rs1_data;
                mem_addr_valid  = 1;
                mem_wdata       = current_wdata_reg;
                mem_byte_en     = current_byte_en_reg;
                mem_wdata_valid = 1;
                if (mem_addr_ready && mem_wdata_ready) begin
                    n_state         = WR_UNIT_WAIT_RESP;
                    mem_write_ready = 1;
                end
            end

            WR_UNIT_WAIT_RESP: begin
                mem_write_ready = 1;
                if (mem_write_valid) begin
                    is_stored_reg = 1;
                    n_state       = IDLE;
                end
            end

            default: n_state = IDLE;
        endcase
    end

endmodule