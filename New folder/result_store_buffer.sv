module rsb #(
    parameter DEPTH        = 16,
    parameter SEQ_W        = 8,
    parameter SCALAR_DW    = 32,
    parameter VECTOR_DW    = 512,
    parameter SCALAR_REG_W = 5,
    parameter VECTOR_REG_W = 5,
    parameter ADDR_W       = 32
)(
    input  logic                    clk,
    input  logic                    reset,

    // ── Scalar write port ─────────────────────────────────────
    input  logic                    s_write_valid,
    input  logic [SEQ_W-1:0]        s_write_seq,
    input  logic [SCALAR_REG_W-1:0] s_write_rd,
    input  logic [SCALAR_DW-1:0]    s_write_result,
    input  logic                    s_write_is_store,
    input  logic                    s_write_is_load,
    input  logic [ADDR_W-1:0]       s_write_mem_addr,
    input  logic                    s_write_exception,

    // ── Vector write port ─────────────────────────────────────
    input  logic                    v_write_valid,
    input  logic [SEQ_W-1:0]        v_write_seq,
    input  logic [VECTOR_REG_W-1:0] v_write_vd,
    input  logic [VECTOR_DW-1:0]    v_write_result,
    input  logic                    v_write_is_store,
    input  logic                    v_write_is_load,
    input  logic [ADDR_W-1:0]       v_write_mem_addr,
    input  logic                    v_write_exception,

    // ── Status ────────────────────────────────────────────────
    output logic                    rsb_full,
    output logic [$clog2(DEPTH):0]  num_entries,

    // ── ROB commit port ───────────────────────────────────────
    input  logic                    rob_commit_valid,
    input  logic [SEQ_W-1:0]        rob_commit_seq,

    // ── Commit outputs ────────────────────────────────────────
    output logic                    commit_valid,
    output logic [SEQ_W-1:0]        commit_seq,
    output logic                    commit_is_vector,
    output logic [SCALAR_REG_W-1:0] commit_rd,
    output logic [VECTOR_REG_W-1:0] commit_vd,
    output logic [SCALAR_DW-1:0]    commit_scalar_result,
    output logic [VECTOR_DW-1:0]    commit_vector_result,
    output logic                    commit_is_store,
    output logic                    commit_is_load,
    output logic [ADDR_W-1:0]       commit_mem_addr,
    output logic                    commit_exception,

    // ── Scalar forwarding ─────────────────────────────────────
    input  logic                    s_fwd_req_valid,
    input  logic [SCALAR_REG_W-1:0] s_fwd_rs1,
    input  logic [SCALAR_REG_W-1:0] s_fwd_rs2,
    output logic                    s_fwd_rs1_hit,
    output logic [SCALAR_DW-1:0]    s_fwd_rs1_data,
    output logic                    s_fwd_rs2_hit,
    output logic [SCALAR_DW-1:0]    s_fwd_rs2_data,

    // ── Vector forwarding ─────────────────────────────────────
    input  logic                    v_fwd_req_valid,
    input  logic [VECTOR_REG_W-1:0] v_fwd_vs1,
    input  logic [VECTOR_REG_W-1:0] v_fwd_vs2,
    output logic                    v_fwd_vs1_hit,
    output logic [VECTOR_DW-1:0]    v_fwd_vs1_data,
    output logic                    v_fwd_vs2_hit,
    output logic [VECTOR_DW-1:0]    v_fwd_vs2_data,

    // ── Flush ─────────────────────────────────────────────────
    input  logic                    flush_valid,
    input  logic [SEQ_W-1:0]        flush_seq
);

    localparam PTR_W = $clog2(DEPTH);

    // ── Entry struct ──────────────────────────────────────────
    typedef struct packed {
        logic                    valid;
        logic                    is_vector;
        logic [SEQ_W-1:0]        seq;
        logic [SCALAR_REG_W-1:0] rd;
        logic [VECTOR_REG_W-1:0] vd;
        logic [VECTOR_DW-1:0]    result;
        logic                    is_store;
        logic                    is_load;
        logic [ADDR_W-1:0]       mem_addr;
        logic                    exception;
    } rsb_entry_t;

    rsb_entry_t entries [0:DEPTH-1];

    // ── Status ────────────────────────────────────────────────
    logic [PTR_W:0] count;
    assign num_entries = count;

    // ── FIX 1: rsb_full must leave room for BOTH possible writes ──
    // We need 2 free slots to allow a simultaneous scalar+vector write.
    // Use count-based full detection per write:
    //   scalar write is allowed if count < DEPTH
    //   vector write is allowed if count + do_s_write < DEPTH
    // This is computed below after do_s_write/do_v_write are known.
    // For the rsb_full status output, assert when no room for any new entry.
    assign rsb_full = (count >= DEPTH[PTR_W:0]);

    // ── Free slot finder ──────────────────────────────────────
    // FIX 2: Properly find TWO DISTINCT free slots.
    // First pass: find lowest free slot → scalar write slot
    // Second pass: find lowest free slot that is NOT s_free_slot → vector write slot
    logic [PTR_W-1:0] s_free_slot, v_free_slot;
    logic             s_free_found, v_free_found;

    always_comb begin
        s_free_slot  = '0; s_free_found = 1'b0;
        v_free_slot  = '0; v_free_found = 1'b0;

        // First free slot → scalar write (scan low to high, last match wins = highest index)
        for (int i = 0; i < DEPTH; i++)
            if (!entries[i].valid) begin
                s_free_slot  = PTR_W'(i);
                s_free_found = 1'b1;
            end

        // Second free slot — must differ from s_free_slot
        for (int i = 0; i < DEPTH; i++)
            if (!entries[i].valid && PTR_W'(i) != s_free_slot) begin
                v_free_slot  = PTR_W'(i);
                v_free_found = 1'b1;
            end
    end

    // FIX 3: Dual-write gate — scalar uses one slot, vector needs a DIFFERENT second slot
    logic do_s_write, do_v_write;
    assign do_s_write = s_write_valid && s_free_found && (count < DEPTH[PTR_W:0]);
    // Vector write also needs a free slot that is distinct from the scalar slot
    assign do_v_write = v_write_valid && v_free_found &&
                        ((count + {{PTR_W{1'b0}}, do_s_write}) < DEPTH[PTR_W:0]);

    // ── Commit slot finder ────────────────────────────────────
    logic [PTR_W-1:0] commit_slot;
    logic             commit_slot_found;

    always_comb begin
        commit_slot       = '0;
        commit_slot_found = 1'b0;
        for (int i = 0; i < DEPTH; i++) begin
            if (entries[i].valid && (entries[i].seq == rob_commit_seq)) begin
                commit_slot       = PTR_W'(i);
                commit_slot_found = 1'b1;
            end
        end
    end

    logic do_commit;
    assign do_commit = rob_commit_valid && commit_slot_found;

    // ── Commit outputs ────────────────────────────────────────
    // Problem: jab commit_slot_found=0 hota hai, commit_slot default
    // '0 hota hai, toh entries[0] ka data output pe aata hai → garbage.
    //
    // Solution: hold registers — jab commit hota hai toh data latch karo,
    // aur jab commit nahi ho raha toh last committed value dikhao.
    // Jab commit_slot_found=1 → combinational path (testbench same cycle mein check karta hai)
    // Jab commit_slot_found=0 → hold register (stable, no garbage from slot 0)

    logic [SEQ_W-1:0]        r_seq;
    logic                    r_is_vector;
    logic [SCALAR_REG_W-1:0] r_rd;
    logic [VECTOR_REG_W-1:0] r_vd;
    logic [SCALAR_DW-1:0]    r_scalar;
    logic [VECTOR_DW-1:0]    r_vector;
    logic                    r_is_store;
    logic                    r_is_load;
    logic [ADDR_W-1:0]       r_mem_addr;
    logic                    r_exception;

    always_ff @(posedge clk) begin
        if (reset) begin
            r_seq       <= '0;  r_is_vector <= '0;
            r_rd        <= '0;  r_vd        <= '0;
            r_scalar    <= '0;  r_vector    <= '0;
            r_is_store  <= '0;  r_is_load   <= '0;
            r_mem_addr  <= '0;  r_exception <= '0;
        end else if (do_commit) begin
            r_seq       <= entries[commit_slot].seq;
            r_is_vector <= entries[commit_slot].is_vector;
            r_rd        <= entries[commit_slot].rd;
            r_vd        <= entries[commit_slot].vd;
            r_scalar    <= entries[commit_slot].result[SCALAR_DW-1:0];
            r_vector    <= entries[commit_slot].result;
            r_is_store  <= entries[commit_slot].is_store;
            r_is_load   <= entries[commit_slot].is_load;
            r_mem_addr  <= entries[commit_slot].mem_addr;
            r_exception <= entries[commit_slot].exception;
        end
    end

    // commit_valid: purely combinational pulse
    assign commit_valid = do_commit;

    // Data outputs: combinational when slot found, hold register otherwise
    assign commit_seq           = commit_slot_found ? entries[commit_slot].seq                   : r_seq;
    assign commit_is_vector     = commit_slot_found ? entries[commit_slot].is_vector             : r_is_vector;
    assign commit_rd            = commit_slot_found ? entries[commit_slot].rd                    : r_rd;
    assign commit_vd            = commit_slot_found ? entries[commit_slot].vd                    : r_vd;
    assign commit_scalar_result = commit_slot_found ? entries[commit_slot].result[SCALAR_DW-1:0]: r_scalar;
    assign commit_vector_result = commit_slot_found ? entries[commit_slot].result                : r_vector;
    assign commit_is_store      = commit_slot_found ? entries[commit_slot].is_store              : r_is_store;
    assign commit_is_load       = commit_slot_found ? entries[commit_slot].is_load               : r_is_load;
    assign commit_mem_addr      = commit_slot_found ? entries[commit_slot].mem_addr              : r_mem_addr;
    assign commit_exception     = commit_slot_found ? entries[commit_slot].exception             : r_exception;

    // ── Scalar forwarding (combinational, newest seq wins WAW) ─
    always_comb begin
        s_fwd_rs1_hit  = 1'b0; s_fwd_rs1_data = '0;
        s_fwd_rs2_hit  = 1'b0; s_fwd_rs2_data = '0;

        if (s_fwd_req_valid) begin
            logic [SEQ_W-1:0] rs1_best_seq, rs2_best_seq;
            rs1_best_seq = '0;
            rs2_best_seq = '0;

            for (int i = 0; i < DEPTH; i++) begin
                if (entries[i].valid && !entries[i].is_vector) begin
                    if ((entries[i].rd == s_fwd_rs1) &&
                        (!s_fwd_rs1_hit || entries[i].seq > rs1_best_seq)) begin
                        s_fwd_rs1_hit  = 1'b1;
                        s_fwd_rs1_data = entries[i].result[SCALAR_DW-1:0];
                        rs1_best_seq   = entries[i].seq;
                    end
                    if ((entries[i].rd == s_fwd_rs2) &&
                        (!s_fwd_rs2_hit || entries[i].seq > rs2_best_seq)) begin
                        s_fwd_rs2_hit  = 1'b1;
                        s_fwd_rs2_data = entries[i].result[SCALAR_DW-1:0];
                        rs2_best_seq   = entries[i].seq;
                    end
                end
            end
        end
    end

    // ── Vector forwarding (combinational, newest seq wins WAW) ─
    always_comb begin
        v_fwd_vs1_hit  = 1'b0; v_fwd_vs1_data = '0;
        v_fwd_vs2_hit  = 1'b0; v_fwd_vs2_data = '0;

        if (v_fwd_req_valid) begin
            logic [SEQ_W-1:0] vs1_best_seq, vs2_best_seq;
            vs1_best_seq = '0;
            vs2_best_seq = '0;

            for (int i = 0; i < DEPTH; i++) begin
                if (entries[i].valid && entries[i].is_vector) begin
                    if ((entries[i].vd == v_fwd_vs1) &&
                        (!v_fwd_vs1_hit || entries[i].seq > vs1_best_seq)) begin
                        v_fwd_vs1_hit  = 1'b1;
                        v_fwd_vs1_data = entries[i].result;
                        vs1_best_seq   = entries[i].seq;
                    end
                    if ((entries[i].vd == v_fwd_vs2) &&
                        (!v_fwd_vs2_hit || entries[i].seq > vs2_best_seq)) begin
                        v_fwd_vs2_hit  = 1'b1;
                        v_fwd_vs2_data = entries[i].result;
                        vs2_best_seq   = entries[i].seq;
                    end
                end
            end
        end
    end

    // ── Sequential logic ──────────────────────────────────────
    always_ff @(posedge clk) begin
        if (reset) begin
            count <= '0;
            for (int i = 0; i < DEPTH; i++)
                entries[i] <= '0;

        end else begin

            // ── Flush (invalidate entries with seq >= flush_seq) ──
            if (flush_valid) begin
                for (int i = 0; i < DEPTH; i++) begin
                    if (entries[i].valid && entries[i].seq >= flush_seq)
                        entries[i].valid <= 1'b0;
                end
            end

            // ── Scalar write ──────────────────────────────────────
            if (do_s_write) begin
                entries[s_free_slot].valid     <= 1'b1;
                entries[s_free_slot].is_vector <= 1'b0;
                entries[s_free_slot].seq       <= s_write_seq;
                entries[s_free_slot].rd        <= s_write_rd;
                entries[s_free_slot].vd        <= '0;
                entries[s_free_slot].result    <= {{(VECTOR_DW-SCALAR_DW){1'b0}},
                                                   s_write_result};
                entries[s_free_slot].is_store  <= s_write_is_store;
                entries[s_free_slot].is_load   <= s_write_is_load;
                entries[s_free_slot].mem_addr  <= s_write_mem_addr;
                entries[s_free_slot].exception <= s_write_exception;
            end

            // ── Vector write ──────────────────────────────────────
            if (do_v_write) begin
                entries[v_free_slot].valid     <= 1'b1;
                entries[v_free_slot].is_vector <= 1'b1;
                entries[v_free_slot].seq       <= v_write_seq;
                entries[v_free_slot].rd        <= '0;
                entries[v_free_slot].vd        <= v_write_vd;
                entries[v_free_slot].result    <= v_write_result;
                entries[v_free_slot].is_store  <= v_write_is_store;
                entries[v_free_slot].is_load   <= v_write_is_load;
                entries[v_free_slot].mem_addr  <= v_write_mem_addr;
                entries[v_free_slot].exception <= v_write_exception;
            end

            // ── Commit (invalidate the committed slot) ─────────────
            if (do_commit) begin
                entries[commit_slot].valid <= 1'b0;
            end

            // ── FIX 5: Entry count update ─────────────────────────
            // After flush: recount NEXT cycle's valid bits.
            // Must account for flush invalidations + writes + commit
            // happening in the same cycle.
            if (flush_valid) begin
                // FIX: count the entries that will be valid AFTER this cycle:
                // - entries that survive flush AND are not committed
                // - plus any new writes (scalar/vector) that are being added
                // Note: writes land in slots that were previously invalid,
                // so they cannot be flushed (seq check would not apply to new
                // writes since we don't flush the slot being written this cycle).
                automatic logic [PTR_W:0] tmp = '0;
                for (int i = 0; i < DEPTH; i++) begin
                    // Entry survives if: currently valid, seq < flush_seq,
                    // and it is not the entry being committed this cycle.
                    if (entries[i].valid &&
                        !(entries[i].seq >= flush_seq) &&
                        !(do_commit && (PTR_W'(i) == commit_slot)))
                        tmp++;
                end
                // Add newly written entries this cycle
                tmp = tmp + {{PTR_W{1'b0}}, do_s_write} + {{PTR_W{1'b0}}, do_v_write};
                count <= tmp;
            end else begin
                // FIX 6: Treat scalar and vector writes as SEPARATE increments
                // Original code used (do_s_write || do_v_write) which collapsed
                // dual writes into a single +1. Use separate addition instead.
                case ({do_s_write, do_v_write, do_commit})
                    3'b000: count <= count;
                    3'b001: count <= count - 1'b1;          // commit only
                    3'b010: count <= count + 1'b1;          // v_write only
                    3'b011: count <= count;                  // v_write + commit
                    3'b100: count <= count + 1'b1;          // s_write only
                    3'b101: count <= count;                  // s_write + commit
                    3'b110: count <= count + 2'd2;          // s_write + v_write
                    3'b111: count <= count + 1'b1;          // s_write + v_write + commit
                    default: count <= count;
                endcase
            end

        end
    end

endmodule