`include "vector_regfile_defs.svh"

localparam int MEM_W = 512;

module vec_lsu (
    input  logic                    clk,
    input  logic                    n_rst,

    input  logic [`XLEN-1:0]        rs1_data,
    input  logic [`XLEN-1:0]        rs2_data,
    input  logic [9:0]              vlmax,
    input  logic [6:0]              sew,

    input  logic                    stride_sel,
    input  logic                    ld_inst,
    input  logic                    st_inst,
    input  logic                    index_str,
    input  logic                    index_unordered,

    input  logic [`MAX_VLEN-1:0]    vs2_data,
    input  logic [`MAX_VLEN-1:0]    vs3_data,

    input  logic                    mew,
    input  logic [2:0]              width,
    input  logic                    inst_done,

    output logic [31:0]             mem_addr,
    output logic [511:0]            mem_wdata,
    output logic [511:0]            mem_wdata_unit,
    output logic [63:0]             mem_byte_en,
    output logic                    mem_wen,
    output logic                    mem_ren,
    output logic                    mem_elem_mode,
    output logic [1:0]              mem_sew_enc,
    input  logic [511:0]            mem_rdata,

    input  logic [$clog2(ROB_DEPTH)-1:0] seq_num,

    output logic [`MAX_VLEN-1:0]    vd_data,
    output logic                    is_loaded,
    output logic                    is_stored,
    output logic                    error_flag
);

    // =========================================================================
    // FSM states
    // =========================================================================
    typedef enum logic [1:0] {
        ST_IDLE        = 2'd0,
        ST_RD_ISSUE    = 2'd1,
        ST_WR_ISSUE    = 2'd2,
        ST_UNORD_SETUP = 2'd3
    } state_e;

    state_e c_state, n_state;

    // =========================================================================
    // Stride type
    // =========================================================================
    logic unit_stride, const_stride;
    assign unit_stride  =  stride_sel || ($unsigned(rs2_data) == 32'd1);
    assign const_stride = !stride_sel && ($unsigned(rs2_data) != 32'd1) && !index_str;

    // =========================================================================
    // Element counter
    // =========================================================================
    logic [$clog2(`MAX_VLEN)-1:0] count_el, next_el;
    logic count_en, last_element;

    assign next_el      = count_el + 1'b1;
    assign last_element = (count_el == vlmax - 10'd1);

    always_ff @(posedge clk or negedge n_rst) begin
        if (!n_rst)
            count_el <= '0;
        else if (inst_done || (c_state == ST_IDLE))
            count_el <= '0;
        else if (count_en)
            count_el <= last_element ? '0 : next_el;
    end

    // =========================================================================
    // capture_idx: latched at issue phase, read at capture phase
    // =========================================================================
    logic [$clog2(`MAX_VLEN)-1:0] capture_idx;

    always_ff @(posedge clk or negedge n_rst) begin
        if (!n_rst)
            capture_idx <= '0;
        else if (inst_done || (c_state == ST_IDLE))
            capture_idx <= '0;
        else if (c_state == ST_RD_ISSUE) 
            capture_idx <= count_el;
    end

    // =========================================================================
    // New instruction flag
    // =========================================================================
    logic new_inst;
    always_ff @(posedge clk or negedge n_rst) begin
        if (!n_rst)
            new_inst <= 1'b1;
        else if (inst_done)
            new_inst <= 1'b1;
        else if ((c_state == ST_IDLE) && (ld_inst || st_inst) && new_inst)
            new_inst <= 1'b0;
    end

    // =========================================================================
    // Track whether in-flight instruction is load or store
    // =========================================================================
    logic in_flight_ld;
    always_ff @(posedge clk or negedge n_rst) begin
        if (!n_rst)
            in_flight_ld <= 1'b0;
        else if ((c_state == ST_IDLE) && new_inst) begin
            if      (ld_inst) in_flight_ld <= 1'b1;
            else if (st_inst) in_flight_ld <= 1'b0;
        end
    end

    // =========================================================================
    // Error flag
    // =========================================================================
    always_comb begin
        error_flag = 1'b0;
        if (index_str) begin
            case (width)
                3'b000, 3'b101, 3'b110: error_flag = 1'b0;
                default:                error_flag = 1'b1;
            endcase
        end
    end

    // =========================================================================
    // SEW encode
    // =========================================================================
    always_comb begin
        case (sew)
            7'd8    : mem_sew_enc = 2'b00;
            7'd16   : mem_sew_enc = 2'b01;
            7'd32   : mem_sew_enc = 2'b10;
            default : mem_sew_enc = 2'b00;
        endcase
    end

    // =========================================================================
    // Ordered index stride
    // =========================================================================
    logic [`XLEN-1:0] selected_stride;
    always_comb begin
        case (width)
            3'b000  : selected_stride = {{(`XLEN-8) {1'b0}}, vs2_data[count_el*8  +:  8]};
            3'b101  : selected_stride = {{(`XLEN-16){1'b0}}, vs2_data[count_el*16 +: 16]};
            3'b110  : selected_stride =                       vs2_data[count_el*32 +: 32];
            default : selected_stride = '0;
        endcase
    end

    // =========================================================================
    // LFSR + unordered address table
    // =========================================================================
    localparam int LFSR_W = $clog2(`VLEN) + 1;

    logic [LFSR_W-1:0]             lfsr_reg;
    logic [`VLEN-1:0]               index_used;
    logic [$clog2(`VLEN)-1:0]       fill_counter;
    logic [`XLEN-1:0]               random_addr_array [0:`VLEN-1];
    logic [$clog2(`VLEN)-1:0]       visit_to_logical  [0:`VLEN-1];

    logic [$clog2(`VLEN)-1:0]  comb_ridx;
    logic [`XLEN-1:0]           comb_rstride;
    logic                       comb_valid;
    logic                       all_assigned;

    // Combinational: find next unvisited element from LFSR hint
    always_comb begin : blk_unord_comb
        logic [$clog2(`VLEN)-1:0] hint;
        comb_valid   = 1'b0;
        comb_ridx    = '0;
        comb_rstride = '0;
        hint = lfsr_reg[$clog2(`VLEN)-1:0] % vlmax;
        for (int i = 0; i < `VLEN; i++) begin
            if (!comb_valid && (hint < vlmax[$clog2(`VLEN)-1:0]) && !index_used[hint]) begin
                comb_ridx  = hint;
                comb_valid = 1'b1;
            end
            hint = (hint == vlmax[$clog2(`VLEN)-1:0] - 1'b1) ? '0 : hint + 1'b1;
        end
        if (comb_valid) begin
            case (width)
                3'b000  : comb_rstride = {{(`XLEN-8) {1'b0}}, vs2_data[comb_ridx*8  +:  8]};
                3'b101  : comb_rstride = {{(`XLEN-16){1'b0}}, vs2_data[comb_ridx*16 +: 16]};
                3'b110  : comb_rstride =                       vs2_data[comb_ridx*32 +: 32];
                default : comb_rstride = '0;
            endcase
        end
    end

    assign all_assigned = (fill_counter >= vlmax[$clog2(`VLEN)-1:0]);

    // LFSR advances each cycle during ST_UNORD_SETUP
    always_ff @(posedge clk or negedge n_rst) begin
        if (!n_rst)
            lfsr_reg <= {{(LFSR_W-1){1'b0}}, 1'b1};
        else if ((c_state == ST_UNORD_SETUP) && !all_assigned)
            lfsr_reg <= {lfsr_reg[LFSR_W-2:0],
                         lfsr_reg[LFSR_W-1] ^ lfsr_reg[LFSR_W-3] ^
                         lfsr_reg[LFSR_W-4] ^ 1'b1};
    end

    always_ff @(posedge clk or negedge n_rst) begin
        if (!n_rst) begin
            fill_counter <= '0;
            index_used   <= '0;
            for (int i = 0; i < `VLEN; i++) begin
                random_addr_array[i] <= '0;
                visit_to_logical[i]  <= '0;
            end
        end else begin
            // Clear when instruction completes
            if (is_loaded || is_stored) begin
                fill_counter <= '0;
                index_used   <= '0;
                for (int i = 0; i < `VLEN; i++) begin
                    random_addr_array[i] <= '0;
                    visit_to_logical[i]  <= '0;
                end
            end else if ((c_state == ST_UNORD_SETUP) && comb_valid && !all_assigned) begin
                random_addr_array[fill_counter] <= rs1_data + comb_rstride;
                visit_to_logical[fill_counter]  <= comb_ridx;
                index_used[comb_ridx]            <= 1'b1;
                fill_counter                     <= fill_counter + 1'b1;
            end
        end
    end

    // =========================================================================
    // Address calculation
    // =========================================================================
    logic [`XLEN-1:0] current_addr;
    always_comb begin
        if (unit_stride)
            current_addr = rs1_data;
        else if (const_stride)
            current_addr = rs1_data + ({{(`XLEN-$clog2(`MAX_VLEN)){1'b0}}, count_el} * rs2_data);
        else if (index_str) begin
            if (index_unordered)
                current_addr = random_addr_array[count_el];
            else
                current_addr = rs1_data + selected_stride;
        end else
            current_addr = rs1_data;
    end

    // =========================================================================
    // Logical element index for store data (FIX-3 from original)
    // =========================================================================
    logic [$clog2(`MAX_VLEN)-1:0] wr_logical_idx;
    assign wr_logical_idx = (index_str && index_unordered)
                            ? {{($clog2(`MAX_VLEN)-$clog2(`VLEN)){1'b0}}, visit_to_logical[count_el]}
                            : count_el;

    // =========================================================================
    // Store data — per-element
    // =========================================================================
    logic [511:0] el_wdata;
    logic [63:0]  el_byte_en;

    always_comb begin
        el_wdata   = '0;
        el_byte_en = '0;
        case (sew)
            7'd8  : begin el_wdata[7:0]  = vs3_data[wr_logical_idx*8  +:  8]; el_byte_en = 64'd1;  end
            7'd16 : begin el_wdata[15:0] = vs3_data[wr_logical_idx*16 +: 16]; el_byte_en = 64'd3;  end
            7'd32 : begin el_wdata[31:0] = vs3_data[wr_logical_idx*32 +: 32]; el_byte_en = 64'hF;  end
            default: ;
        endcase
    end

    // Unit-stride store (full vector)
    always_comb begin
        mem_wdata_unit = '0;
        for (int i = 0; i < `MAX_VLEN; i++) begin
                case (sew)
                    7'd8  : begin 
                        if (i < 64) begin
                            mem_wdata_unit[i*8  +:  8] = vs3_data[i*8  +:  8];
                        end
                    end
                    7'd16 : begin 
                        if (i < 32) begin
                            mem_wdata_unit[i*16 +: 16] = vs3_data[i*16 +: 16];
                        end
                    end
                    7'd32 : begin 
                        if (i < 16) begin
                           mem_wdata_unit[i*32 +: 32] = vs3_data[i*32 +: 32]; 
                        end
                    end
                    default: ;
                endcase
        end
    end

    logic [63:0] unit_byte_en;
    always_comb begin
        unit_byte_en = '0;
        for (int i = 0; i < `MAX_VLEN; i++) begin
                case (sew)
                    7'd8  : begin
                        if (i < 64) begin
                            unit_byte_en[i]        = 1'b1;
                        end
                    end
                    7'd16 : begin
                        if (i < 32) begin
                            unit_byte_en[2*i +: 2] = 2'b11;
                        end
                    end
                    7'd32 :  begin
                        if (i < 16) begin
                           unit_byte_en[4*i +: 4] = 4'b1111; 
                        end
                    end
                    7'd64 :  begin
                        if (i < 8) begin 
                           unit_byte_en[8*i +: 8] = 8'hFF;
                        end
                    end
                    
                    default: ;
                endcase
            end
        end

    // =========================================================================
    // Load data capture
    //
    // Captures on the CAPTURE phase (rd_wait=1) when mem_rdata is valid.
    //
    // For unordered load: dest slot = visit_to_logical[capture_idx]
    //   so that even though the DUT visits elements out of order,
    //   each element ends up in its correct logical position in loaded_data[].
    //
    // For ordered / const / unit: dest = capture_idx directly.
    // =========================================================================
    logic [2*`XLEN-1:0] loaded_data [0:`MAX_VLEN-1];

    always_ff @(posedge clk or negedge n_rst) begin
        if (!n_rst) begin
            for (int i = 0; i < `MAX_VLEN; i++)
                loaded_data[i] <= '0;
        end else if ((c_state == ST_RD_ISSUE) && mem_ren) begin
            // mem_rdata is combinationally valid right now
            if (unit_stride) begin
                for (int i = 0; i < `MAX_VLEN; i++) begin
                        case (sew)
                            7'd8  : begin
                                if (i < 64) begin
                                    loaded_data[i] <= {{(2*`XLEN-8) {1'b0}}, mem_rdata[i*8  +:  8]};
                                end
                            end
                            7'd16 : begin 
                                if (i < 32) begin
                                    loaded_data[i] <= {{(2*`XLEN-16){1'b0}}, mem_rdata[i*16 +: 16]};
                                end
                            end
                            7'd32 : begin
                                if (i < 16) begin
                                    loaded_data[i] <= {{(2*`XLEN-32){1'b0}}, mem_rdata[i*32 +: 32]};
                                end
                            end
                            7'd64 : begin
                                if (i < 8) begin
                                    loaded_data[i] <= {{(2*`XLEN-64){1'b0}}, mem_rdata[i*64 +: 64]};
                                end
                            end
                            default: loaded_data[i] <= '0;
                        endcase
                    end
                end
            end else begin
                // capture_idx latched same cycle since we removed rd_wait
                automatic logic [$clog2(`MAX_VLEN)-1:0] dest;
                dest = (index_str && index_unordered)
                    ? {{($clog2(`MAX_VLEN)-$clog2(`VLEN)){1'b0}}, visit_to_logical[count_el]}
                    : count_el;
                case (sew)
                    7'd8  : loaded_data[dest] <= {{(2*`XLEN-8) {1'b0}}, mem_rdata[7:0]};
                    7'd16 : loaded_data[dest] <= {{(2*`XLEN-16){1'b0}}, mem_rdata[15:0]};
                    7'd32 : loaded_data[dest] <= {{(2*`XLEN-32){1'b0}}, mem_rdata[31:0]};
                    7'd64 : loaded_data[dest] <= {{(2*`XLEN-64){1'b0}}, mem_rdata[63:0]};
                    default: loaded_data[dest] <= '0;
                endcase
            end
        end
    // Pack to output
    always_comb begin
        vd_data = '0;
        for (int i = 0; i < `MAX_VLEN; i++) begin
                case (sew)
                    7'd8  : begin
                        if (i < 64) begin
                            vd_data[i*8  +:  8] = loaded_data[i][7:0];
                        end
                    end
                    7'd16 : begin
                        if (i < 32) begin
                            vd_data[i*16 +: 16] = loaded_data[i][15:0];
                        end
                    end
                    7'd32 : begin
                        if (i < 16) begin
                            vd_data[i*32 +: 32] = loaded_data[i][31:0];
                        end
                    end
                    7'd64 : begin
                        if (i < 8) begin
                            vd_data[i*64 +: 64] = loaded_data[i][63:0];
                        end
                    end
                    default: 
                        vd_data = '0;
                endcase
            end
        end

    // =========================================================================
    // is_loaded: REGISTERED from combinational is_loaded_comb
    //
    // THE KEY FIX:
    //   is_loaded_comb fires in the SAME cycle that loaded_data[] is written
    //   (both are driven by the same clock edge T). vd_data only reflects the
    //   new loaded_data[] AFTER posedge T (i.e., from posedge T+1 onward).
    //   By registering is_loaded_comb, the output is_loaded goes high at
    //   posedge T+1, exactly when vd_data has the correct values.
    //
    // is_loaded clears when:
    //   - reset
    //   - inst_done (instruction acknowledged)
    //   - new instruction starts (prevents stale high)
    // =========================================================================
    logic is_loaded_comb;  // internal, driven by FSM

    always_ff @(posedge clk or negedge n_rst) begin
        if (!n_rst)
            is_loaded <= 1'b0;
        else if (inst_done || ((c_state == ST_IDLE) && (ld_inst || st_inst) && new_inst))
            is_loaded <= 1'b0;
        else
            is_loaded <= is_loaded_comb;
    end

    // =========================================================================
    // FSM state register
    // =========================================================================
    always_ff @(posedge clk or negedge n_rst) begin
        if (!n_rst) c_state <= ST_IDLE;
        else        c_state <= n_state;
    end

    // =========================================================================
    // FSM combinational logic
    //
    // Load pipeline (all four modes: unit / const / ordered / unordered):
    //
    //   Cycle T   [rd_wait=0, issue phase]:
    //     drive mem_addr, mem_ren=1
    //     latch capture_idx = count_el   (via always_ff above)
    //     rd_wait_set=1  → rd_wait becomes 1 at posedge T
    //     stay in ST_RD_ISSUE
    //
    //   Cycle T+1 [rd_wait=1, capture phase]:
    //     mem_rdata is now valid (SRAM delivers 1 cycle after mem_ren)
    //     loaded_data[] FF captures mem_rdata[dest]  (posedge T+1)
    //     is_loaded_comb=1 if last element
    //     count_en=1 to advance count_el
    //     rd_wait_clr=1  → rd_wait becomes 0 at posedge T+1
    //     if last: n_state = ST_IDLE
    //
    //   Cycle T+2:
    //     loaded_data[] holds all correct values
    //     is_loaded output goes high (registered from is_loaded_comb)  ← TB sees this
    //     vd_data = f(loaded_data[]) = CORRECT  ← TB reads this ✓
    //     FSM is in ST_IDLE
    // =========================================================================
    always_comb begin
        n_state         = c_state;
        count_en        = 1'b0;
        mem_addr        = '0;
        mem_wdata       = '0;
        mem_byte_en     = '0;
        mem_wen         = 1'b0;
        mem_ren         = 1'b0;
        mem_elem_mode   = 1'b1;
        is_loaded_comb  = 1'b0;
        is_stored       = 1'b0;

        if (error_flag) begin
            n_state = ST_IDLE;
        end else begin
            case (c_state)

                // ── IDLE ──────────────────────────────────────────────────
                ST_IDLE: begin
                    if (ld_inst && new_inst) begin
                        n_state = index_unordered ? ST_UNORD_SETUP : ST_RD_ISSUE;
                    end else if (st_inst && new_inst) begin
                        n_state = index_unordered ? ST_UNORD_SETUP : ST_WR_ISSUE;
                    end
                end

                // ── Unordered setup ───────────────────────────────────────
                ST_UNORD_SETUP: begin
                    if (all_assigned)
                        n_state = in_flight_ld ? ST_RD_ISSUE : ST_WR_ISSUE;
                end

                // ── Element-wise LOAD ─────────────────────────────────────
                ST_RD_ISSUE: begin
                    if (unit_stride) begin
                        // No rd_wait needed — mem is async, data valid same cycle
                        mem_addr      = rs1_data[31:0];
                        mem_byte_en   = unit_byte_en;
                        mem_ren       = 1'b1;
                        mem_elem_mode = 1'b0;
                        is_loaded_comb = 1'b1;
                        n_state        = ST_IDLE;
                        // capture happens in always_ff below same posedge
                    end
                    else begin
                        mem_addr      = current_addr[31:0];
                        mem_byte_en   = el_byte_en;
                        mem_ren       = 1'b1;
                        mem_elem_mode = 1'b1;
                        count_en      = 1'b1;
                        if (last_element) begin
                            is_loaded_comb = 1'b1;
                            n_state        = ST_IDLE;
                        end
                    end
                end

                // ── Store ─────────────────────────────────────────────────
                ST_WR_ISSUE: begin
                    if (unit_stride) begin
                        mem_addr      = rs1_data[31:0];
                        mem_wdata     = mem_wdata_unit;
                        mem_byte_en   = unit_byte_en;
                        mem_wen       = 1'b1;
                        mem_elem_mode = 1'b0;
                        is_stored     = 1'b1;
                        n_state       = ST_IDLE;
                    end else begin
                        mem_addr      = current_addr[31:0];
                        mem_wdata     = el_wdata;
                        mem_byte_en   = el_byte_en;
                        mem_wen       = 1'b1;
                        mem_elem_mode = 1'b1;
                        count_en      = 1'b1;
                        if (last_element) begin
                            is_stored = 1'b1;
                            n_state   = ST_IDLE;
                        end
                    end
                end

                default: n_state = ST_IDLE;

            endcase
        end
    end

endmodule