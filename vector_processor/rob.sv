`include "pcore_types_pkg.sv"
import pcore_types_pkg::*;
`include "vector_processor_defs.svh"
`include "scalar_pcore_interface_defs.svh"

module rob (
    input  logic clk,
    input  logic rst_n,

    // ---- Fetch stage ----------------------------------------
    input  logic                           fetch_valid_i,
    input  logic [`XLEN-1:0]               fetch_instr_i,

    // ---- To Decode ------------------------------------------
    output logic [`XLEN-1:0]               rob_de_instr_o,
    output logic [`Tag_Width-1:0]          rob_de_seq_num_o,

    // ---- From Decode ----------------------------------------
    input  logic                           de_valid_i,
    input  logic [`Tag_Width-1:0]          de_seq_num_i,
    input  logic [`XLEN-1:0]               de_instr_i,
    input  logic                           de_is_vector_i,
    input  logic                           de_scalar_store_i,
    input  logic                           de_vector_store_i,
    input  logic                           de_scalar_load_i,
    input  logic                           de_vector_load_i,
    input  logic [`REG_ADDR_W-1:0]         de_scalar_rd_addr_i,
    input  logic [`VREG_ADDR_W-1:0]        de_vector_vd_addr_i,
    input  logic [`RF_AWIDTH-1:0]          de_rs1_addr_i,
    input  logic [`RF_AWIDTH-1:0]          de_rs2_addr_i,
    input  logic [`VREG_ADDR_W-1:0]        de_vs1_addr_i,
    input  logic [`VREG_ADDR_W-1:0]        de_vs2_addr_i,

    input  type_st_ops_e                   scalar_store_op_i,
    input  logic                           scalar_rd_wr_req,

    // ---- Register-file read data ----------------------------
    input  logic [`XLEN-1:0]               rf2rob_rs1_data_i,
    input  logic [`XLEN-1:0]               rf2rob_rs2_data_i,
    input  logic [`XLEN-1:0]               rf2rob_vs1_scalar_data_i,

    // ---- Forwarding outputs ---------------------------------
    output logic [`XLEN-1:0]               fwd_rs1_data_o,
    output logic [`XLEN-1:0]               fwd_rs2_data_o,
    output logic [`VLEN-1:0]               fwd_vs1_data_o,
    output logic [`VLEN-1:0]               fwd_vs2_data_o,

    // ---- Stalls ---------------------------------------------
    output logic                           stall_scalar_raw_o,
    output logic                           stall_viq_full_o,
    output logic                           stall_vec_raw_o,
    output logic                           stall_fetch_o,

    // ---- VIQ dispatch ---------------------------------------
    output logic                           viq_dispatch_valid_o,
    output logic [`XLEN-1:0]               viq_dispatch_instr_o,
    output logic [`Tag_Width-1:0]          viq_dispatch_seq_num_o,
    output logic [`XLEN-1:0]               viq_dispatch_rs1_data_o,
    output logic [`XLEN-1:0]               viq_dispatch_rs2_data_o,
    output logic                           viq_dispatch_is_vec_o,
    input  logic                           viq_full_i,

    // ---- Scalar writeback -----------------------------------
    input  logic                           scalar_done_i,
    input  logic [`Tag_Width-1:0]          scalar_seq_num_i,
    input  logic [`VREG_ADDR_W-1:0]        scalar_rd_addr_i,
    input  logic [`XLEN-1:0]               scalar_result_i,
    input  logic [`XLEN-1:0]               scalar_mem_addr_i,
    input  logic [`XLEN-1:0]               scalar_mem_data_i,

    // ---- Vector writeback -----------------------------------
    input  logic                           vector_done_i,
    input  logic [`Tag_Width-1:0]          vector_seq_num_i,
    input  logic [`VREG_ADDR_W-1:0]        vector_vd_addr_i,
    input  logic [`MAX_VLEN-1:0]           vector_result_i,
    input  logic [`XLEN-1:0]               vector_mem_addr_i,
    input  logic [`VLEN-1:0]               vector_mem_data_i,
    input  logic [63:0]                    mem_byte_en,
    input  logic                           mem_wen,
    input  logic                           mem_elem_mode,
    input  logic [1:0]                     mem_sew_enc,
    input logic vec_decode,

    // ---- Commit ---------------------------------------------
    output logic                           commit_valid_o, rob_commit_is_vec_o,
    output logic [`Tag_Width-1:0]          commit_scalar_seq_num_o,
    output logic [`Tag_Width-1:0]          commit_vector_seq_num_o,
    output logic [`REG_ADDR_W-1:0]         commit_rd_o,
    output logic [`VREG_ADDR_W-1:0]        commit_vd_o,
    output logic [`XLEN-1:0]               commit_scalar_result_o,
    output logic [`MAX_VLEN-1:0]           commit_vector_result_o,
    output logic [`XLEN-1:0]               commit_scalar_mem_addr_o,
    output logic [`XLEN-1:0]               commit_vec_mem_addr_o,
    output logic [`XLEN-1:0]               commit_scalar_mem_data_o,
    output logic [`VLEN-1:0]               commit_vector_mem_data_o,
    output logic [63:0]                    commit_vector_mem_byte_en,
    output logic                           commit_vector_mem_wen,
    output logic                           commit_vector_mem_elem_mode,
    output logic [1:0]                     commit_vector_mem_sew_enc,
    output type_st_ops_e                   commit_scalar_store_op_o,
    output logic                           commit_scalar_rd_wr_req_o,

    input  logic                           flush_valid_i,
    input  logic [`Tag_Width-1:0]          flush_seq_i
);

    // =========================================================
    // ROB Entry Struct
    // =========================================================
    typedef struct packed {
        logic                        valid;
        logic                        filled;
        logic                        done;
        logic                        is_vector;
        logic                        is_scalar_store;
        logic                        is_vector_store;
        logic                        is_scalar_load;
        logic                        is_vector_load;
        logic                        is_mem;
        logic                        viq_dispatched;
        logic [`XLEN-1:0]            instr;
        logic [`REG_ADDR_W-1:0]      rd;
        logic [`VREG_ADDR_W-1:0]     vd;
        logic [`VREG_ADDR_W-1:0]     vs1;
        logic [`VREG_ADDR_W-1:0]     vs2;
        logic [`VREG_ADDR_W-1:0]     rs1;
        logic [`VREG_ADDR_W-1:0]     rs2;
        logic [`XLEN-1:0]            rs1_data;
        logic [`XLEN-1:0]            rs2_data;
        logic [`XLEN-1:0]            scalar_result;
        logic [`MAX_VLEN-1:0]        vector_result;
        logic [`XLEN-1:0]            mem_addr;
        logic [`XLEN-1:0]            scalar_mem_data;
        logic [`VLEN-1:0]            vector_mem_data;
        logic [63:0]                 mem_byte_en;
        logic                        mem_wen;
        logic                        mem_elem_mode;
        logic [1:0]                  mem_sew_enc;
        type_st_ops_e                scalar_store_op;
        logic                        scalar_rd_wr_req;
    } rob_entry_t;

    // =========================================================
    // Parameters
    // =========================================================
    localparam int PTR_W = $clog2(`ROB_DEPTH);
    localparam logic [`XLEN-1:0] NOP_INSTR = `XLEN'h0000_0013;

    // =========================================================
    // Internal signals — all at module level, no automatic vars
    // =========================================================
    rob_entry_t                  rob [`ROB_DEPTH];
    rob_entry_t                  head_entry;

    logic [PTR_W-1:0]            head;
    logic [PTR_W-1:0]            tail;
    logic [PTR_W:0]              count;

    logic                        rob_full;
    logic                        is_nop;
    logic                        is_repeat;
    logic                        do_fetch;
    logic                        do_commit;
    logic                        do_viq_dispatch;

    // VIQ scan
    logic                        found_vec_to_dispatch;
    logic [PTR_W-1:0]            viq_seq_num;

    // Decode-time scalar forwarding
    logic                        fwd_rs1_hit;
    logic [`XLEN-1:0]            fwd_rs1_val;
    logic                        fwd_rs2_hit;
    logic [`XLEN-1:0]            fwd_rs2_val;
    logic                        fwd_vs1_hit;
    logic [`VLEN-1:0]            fwd_vs1_val;
    logic                        fwd_vs2_hit;
    logic [`VLEN-1:0]            fwd_vs2_val;

    // VIQ dispatch forwarding
    logic [`XLEN-1:0]            viq_fwd_rs1;
    logic [`XLEN-1:0]            viq_fwd_rs2;
    logic                        viq_rs1_ready;
    logic                        viq_rs2_ready;

    // Memory stall
    logic                        any_unretired_vec_mem;
    logic                        any_unretired_scalar_mem;
    logic                        stall_scalar_mem;
    logic                        stall_vec_mem;

    // Flush helpers
    logic [PTR_W-1:0]            flush_dist_comb;
    logic [PTR_W-1:0]            entry_dist_comb [`ROB_DEPTH];
    logic [PTR_W:0]              flush_count;

    // Module-level loop helpers to avoid automatic declarations
    logic [PTR_W-1:0]            scan_idx      [`ROB_DEPTH];
    logic [PTR_W-1:0]            entry_age_arr [`ROB_DEPTH];
    logic [PTR_W-1:0]            cand_age_sig;

    // Decode-cycle dispatch flag
    logic                        de_vec_dispatch_now;

    // last instruction for repeat detection
    logic [`XLEN-1:0]            last_instr;

    function automatic logic [PTR_W-1:0] next_ptr(logic [PTR_W-1:0] p);
        logic [PTR_W-1:0] n;
        n = p + PTR_W'(1);
        return (n == '0) ? PTR_W'(1) : n;   // skip 0, wrap to 1
    endfunction

    // =========================================================
    // Basic status
    // =========================================================
    assign rob_full           = (count == (PTR_W+1)'(`ROB_DEPTH));
    assign is_nop             = (fetch_instr_i == NOP_INSTR);
    assign head_entry         = rob[head];
    assign stall_viq_full_o   = viq_full_i;
    assign stall_vec_raw_o    = 1'b0;
    assign stall_scalar_raw_o = 1'b0;

    logic is_vx_instr;
    assign is_vx_instr = (de_instr_i[6:0] == 7'b1010111) && (de_instr_i[14:12] == 3'b100 || de_instr_i[14:12] == 3'b110);    

    // =========================================================
    // Repeat detection
    // =========================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            last_instr <= '0;
        else if (de_valid_i & ~is_nop)
            last_instr <= rob_de_instr_o;
    end

    // =========================================================
    // Previous stall tracking
    // =========================================================
    logic stall_fetch_prev;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            stall_fetch_prev <= 1'b0;
        else
            stall_fetch_prev <= stall_fetch_o;
    end

    // Stall ke baad NOP aa raha hai to VIQ dispatch block karo
    logic block_viq_after_stall;
    assign block_viq_after_stall = stall_fetch_prev & is_nop;

    assign is_repeat = (fetch_instr_i == last_instr) & ~is_nop;

    always_comb begin
        found_vec_to_dispatch = 1'b0;
        viq_seq_num           = '0;
        for (int i = 0; i < `ROB_DEPTH; i++) begin
            automatic logic [PTR_W-1:0] idx;
            idx = PTR_W'(head + PTR_W'(i));   // walk in-order from head
            if (rob[idx].valid && rob[idx].filled && rob[idx].is_vector  && !rob[idx].viq_dispatched && !found_vec_to_dispatch) begin
                found_vec_to_dispatch = 1'b1;
                viq_seq_num           = idx;
            end
        end
    end

    // =========================================================
    // Pre-compute scan_idx and age arrays
    // =========================================================
    always_comb begin
        for (int i = 0; i < `ROB_DEPTH; i++) begin
            scan_idx[i]      = PTR_W'(head + PTR_W'(i));
            entry_age_arr[i] = PTR_W'(i) - head;
        end
        cand_age_sig = viq_seq_num - head;
    end
    
    always_comb begin
        viq_fwd_rs1   = de_vec_dispatch_now ? fwd_rs1_data_o : rob[viq_seq_num].rs1_data;
        viq_fwd_rs2   = de_vec_dispatch_now ? fwd_rs2_data_o : rob[viq_seq_num].rs2_data;
        viq_rs1_ready = 1'b1;
        viq_rs2_ready = 1'b1;

        for (int i = 0; i < `ROB_DEPTH; i++) begin
            if (rob[i].valid && rob[i].filled && (entry_age_arr[i] < cand_age_sig)) begin

                // Older scalar instruction
                if (!rob[i].is_vector && rob[i].rd != '0 ) begin

                    if (`VREG_ADDR_W'(rob[i].rd) == (de_vec_dispatch_now ? `VREG_ADDR_W'(de_rs1_addr_i) : rob[viq_seq_num].rs1)) begin
                        if (rob[i].done) begin
                            viq_fwd_rs1 = rob[i].scalar_result;
                            viq_rs1_ready = 1'b1;
                        end else begin
                            viq_rs1_ready = 1'b0;
                        end
                    end

                    if (`VREG_ADDR_W'(rob[i].rd) == (de_vec_dispatch_now ? `VREG_ADDR_W'(de_rs2_addr_i) : rob[viq_seq_num].rs2)) begin
                        if (rob[i].done) begin
                            viq_fwd_rs2 = rob[i].scalar_result;
                            viq_rs1_ready = 1'b1;
                        end else begin
                            viq_rs2_ready = 1'b0;
                        end
                    end
                end

                // Older vector instruction
                if (rob[i].is_vector && is_vx_instr) begin
                    if (rob[i].vd == (de_vec_dispatch_now ? `VREG_ADDR_W'(de_rs1_addr_i): rob[viq_seq_num].rs1)) begin
                        if (rob[i].done) begin
                            viq_fwd_rs1 = rob[i].vector_result[`XLEN-1:0];
                            viq_rs1_ready = 1'b1;
                        end else begin
                            viq_rs1_ready = 1'b0;
                        end
                    end


                    if (rob[i].vd == (de_vec_dispatch_now ? `VREG_ADDR_W'(de_rs2_addr_i): rob[viq_seq_num].rs2)) begin
                        if (rob[i].done) begin
                            viq_fwd_rs2 = rob[i].vector_result[`XLEN-1:0];
                            viq_rs1_ready = 1'b1;
                        end else begin
                            viq_rs2_ready = 1'b0;
                        end
                    end
                end
            end
        end
    end
    always_comb begin
        do_fetch        = fetch_valid_i & ~rob_full & ~is_nop & ~is_repeat & ~flush_valid_i;
        do_commit       = commit_valid_o;
        de_vec_dispatch_now = de_valid_i    & de_is_vector_i    & ~viq_full_i    & ~flush_valid_i & ~stall_fetch_o;
        do_viq_dispatch =  ~viq_full_i   & viq_rs1_ready & ~block_viq_after_stall & (found_vec_to_dispatch | de_vec_dispatch_now);
                           //& viq_rs2_ready;
    end
    always_comb begin
        fwd_rs1_hit = 1'b0;
        fwd_rs1_val = '0;
        fwd_rs2_hit = 1'b0;
        fwd_rs2_val = '0;
        for (int i = 0; i < `ROB_DEPTH; i++) begin
            if (rob[i].valid && rob[i].filled &&
                rob[i].done  && !rob[i].is_vector) begin
                if (rob[i].rd == de_rs1_addr_i && de_rs1_addr_i != '0) begin
                    fwd_rs1_hit = 1'b1;
                    fwd_rs1_val = rob[i].scalar_result;
                end
                if (rob[i].rd == de_rs2_addr_i && de_rs2_addr_i != '0) begin
                    fwd_rs2_hit = 1'b1;
                    fwd_rs2_val = rob[i].scalar_result;
                end
            end
        end
    end

    assign fwd_rs1_data_o = fwd_rs1_hit ? fwd_rs1_val : rf2rob_rs1_data_i;
    assign fwd_rs2_data_o = fwd_rs2_hit ? fwd_rs2_val : rf2rob_rs2_data_i;

    // =========================================================
    // Decode-time vector forwarding (vs1 / vs2)
    // =========================================================
    always_comb begin
        fwd_vs1_hit = 1'b0;
        fwd_vs1_val = '0;
        fwd_vs2_hit = 1'b0;
        fwd_vs2_val = '0;
        for (int i = 0; i < `ROB_DEPTH; i++) begin
            if (rob[i].valid && rob[i].filled && rob[i].done) begin
                if (rob[i].is_vector) begin
                    if (rob[i].vd == de_vs1_addr_i) begin
                        fwd_vs1_hit = 1'b1;
                        fwd_vs1_val = rob[i].vector_result[`VLEN-1:0];
                    end
                    if (rob[i].vd == de_vs2_addr_i) begin
                        fwd_vs2_hit = 1'b1;
                        fwd_vs2_val = rob[i].vector_result[`VLEN-1:0];
                    end
                end
                if (!rob[i].is_vector && rob[i].rd != '0) begin
                    if (`VREG_ADDR_W'(rob[i].rd) == de_vs1_addr_i) begin
                        fwd_vs1_hit = 1'b1;
                        fwd_vs1_val = {(`VLEN-`XLEN)'(0), rob[i].scalar_result};
                    end
                    if (`VREG_ADDR_W'(rob[i].rd) == de_vs2_addr_i) begin
                        fwd_vs2_hit = 1'b1;
                        fwd_vs2_val = {(`VLEN-`XLEN)'(0), rob[i].scalar_result};
                    end
                end
            end
        end
    end

    assign fwd_vs1_data_o = fwd_vs1_hit ? fwd_vs1_val
                                        : {(`VLEN-`XLEN)'(0), rf2rob_vs1_scalar_data_i};
    assign fwd_vs2_data_o = fwd_vs2_hit ? fwd_vs2_val : '0;

    // =========================================================
    // Memory stall
    // =========================================================
    /*always_comb begin
        any_unretired_vec_mem    = 1'b0;
        any_unretired_scalar_mem = 1'b0;
        for (int i = 0; i < `ROB_DEPTH; i++) begin
            if (rob[i].valid && rob[i].filled && rob[i].is_mem) begin
                if ( rob[i].is_vector) any_unretired_vec_mem    = 1'b1;
                if (!rob[i].is_vector) any_unretired_scalar_mem = 1'b1;
            end
        end
    end*/

    always_comb begin
        any_unretired_vec_mem    = 1'b0;
        any_unretired_scalar_mem = 1'b0;
        for (int i = 0; i < `ROB_DEPTH; i++) begin
            // commit wali entry ko is cycle mein count mat karo
            if (rob[i].valid && rob[i].filled && rob[i].is_mem  && !(commit_valid_o && (i == head))) begin  // ← yeh add karo
                if ( rob[i].is_vector) any_unretired_vec_mem    = 1'b1;
                if (!rob[i].is_vector) any_unretired_scalar_mem = 1'b1;
            end
        end
    end

    assign stall_scalar_mem = any_unretired_vec_mem;
    assign stall_vec_mem    = any_unretired_scalar_mem;
    assign stall_fetch_o    = stall_scalar_mem  | stall_vec_mem    | rob_full ;//       | de_scalar_store_i | 
                              //de_vector_store_i | de_scalar_load_i | de_vector_load_i;

    // =========================================================
    // Decode output registers
    // =========================================================
    logic [`XLEN-1:0]      rob_de_instr_q;
    logic [`Tag_Width-1:0] rob_de_seq_num_q;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rob_de_instr_q   <= '0;
            rob_de_seq_num_q <= '0;
        end else if (do_fetch && !is_nop) begin
            rob_de_instr_q   <= fetch_instr_i;
            rob_de_seq_num_q <= (`Tag_Width)'(tail);
        end
    end

    assign rob_de_instr_o   = (do_fetch && !is_nop) ? fetch_instr_i      : rob_de_instr_q;
    assign rob_de_seq_num_o = (do_fetch && !is_nop) ? (`Tag_Width)'(tail) : rob_de_seq_num_q;

    // =========================================================
    // Sequential logic
    // =========================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            head  <= 'd1;
            tail  <= 'd1;
            count <= '0;
            for (int i = 0; i < `ROB_DEPTH; i++)
                rob[i] <= '0;
        end else begin

            // ── Fetch / Commit pointer management ────────────────
            if (do_fetch && do_commit && ~is_nop) begin
                rob[tail].valid <= 1'b1;
                rob[tail].instr <= fetch_instr_i;
                tail <= next_ptr(tail);
                head <= next_ptr(head);
                rob[head].valid <= 1'b0;
                // count unchanged: one in, one out
            end
            else if (do_fetch && ~is_nop) begin
                rob[tail].valid <= 1'b1;
                rob[tail].instr <= fetch_instr_i;
                tail <= next_ptr(tail);
                count           <= count + (PTR_W+1)'(1);
            end
            else if (do_commit) begin
                rob[head].valid <= 1'b0;
                head <= next_ptr(head);
                count           <= count - (PTR_W+1)'(1);
            end

            // ── Decode: fill entry metadata ───────────────────────
            if (de_valid_i) begin
                rob[de_seq_num_i].filled          <= 1'b1;
                rob[de_seq_num_i].is_vector       <= de_is_vector_i;
                rob[de_seq_num_i].is_scalar_store <= de_scalar_store_i;
                rob[de_seq_num_i].is_scalar_load  <= de_scalar_load_i;
                rob[de_seq_num_i].rd              <= de_scalar_rd_addr_i;
                rob[de_seq_num_i].rs1             <= (`VREG_ADDR_W)'(de_rs1_addr_i);
                rob[de_seq_num_i].rs2             <= (`VREG_ADDR_W)'(de_rs2_addr_i);
                rob[de_seq_num_i].scalar_store_op <= scalar_store_op_i;
                rob[de_seq_num_i].scalar_rd_wr_req<= scalar_rd_wr_req;
                rob[de_seq_num_i].is_vector_store <= de_vector_store_i;
                rob[de_seq_num_i].is_vector_load  <= de_vector_load_i;
                rob[de_seq_num_i].is_mem          <= de_scalar_store_i | de_vector_store_i
                                                   | de_scalar_load_i  | de_vector_load_i;
                rob[de_seq_num_i].rs1_data        <= fwd_rs1_data_o;
                rob[de_seq_num_i].rs2_data        <= fwd_rs2_data_o;
                if (de_is_vector_i && do_viq_dispatch)
                    rob[de_seq_num_i].viq_dispatched <= 1'b1;
            end
            if (vec_decode) begin
                rob[vector_seq_num_i].vd              <= de_vector_vd_addr_i;
                rob[vector_seq_num_i].vs1             <= de_vs1_addr_i;
                rob[vector_seq_num_i].vs2             <= de_vs2_addr_i; 
            end

            // For already-filled entries dispatched in a later cycle
            if (do_viq_dispatch && !de_vec_dispatch_now)
                rob[viq_seq_num].viq_dispatched <= 1'b1;

            // ── Scalar writeback ──────────────────────────────────
            if (scalar_done_i) begin
                rob[scalar_seq_num_i].done             <= 1'b1;
                rob[scalar_seq_num_i].rd               <= scalar_rd_addr_i;
                rob[scalar_seq_num_i].scalar_result    <= scalar_result_i;
                rob[scalar_seq_num_i].mem_addr         <= scalar_mem_addr_i;
                rob[scalar_seq_num_i].scalar_mem_data  <= scalar_mem_data_i;
                rob[scalar_seq_num_i].scalar_store_op  <= scalar_store_op_i;
                rob[scalar_seq_num_i].scalar_rd_wr_req <= scalar_rd_wr_req;
            end

            // ── Vector writeback ──────────────────────────────────
            if (vector_done_i) begin
                rob[vector_seq_num_i].done             <= 1'b1;
                rob[vector_seq_num_i].vector_result    <= vector_result_i;
                rob[vector_seq_num_i].mem_addr         <= vector_mem_addr_i;
                rob[vector_seq_num_i].vector_mem_data  <= vector_mem_data_i;
                rob[vector_seq_num_i].mem_byte_en      <= mem_byte_en;
                rob[vector_seq_num_i].mem_wen          <= mem_wen;
                rob[vector_seq_num_i].mem_elem_mode    <= mem_elem_mode;
                rob[vector_seq_num_i].mem_sew_enc      <= mem_sew_enc;
                //rob[vector_seq_num_i].vd               <= rob[vector_seq_num_i].vd;//vector_vd_addr_i;
            end

            // ── Flush ─────────────────────────────────────────────
            /*if (flush_valid_i) begin
                for (int i = 0; i < `ROB_DEPTH; i++) begin
                    if (rob[i].valid &&
                        (entry_age_arr[i] > (flush_seq_i[PTR_W-1:0] - head))) begin
                        rob[i].valid  <= 1'b0;
                        rob[i].filled <= 1'b0;
                        rob[i].done   <= 1'b0;
                    end
                end
                tail  <= flush_seq_i[PTR_W-1:0] + PTR_W'(1);
                count <= (PTR_W+1)'(flush_seq_i[PTR_W-1:0] - head + 1);
            end*/

            if (flush_valid_i) begin
                rob[flush_seq_i[PTR_W-1:0]].valid  <= 1'b0;
                rob[flush_seq_i[PTR_W-1:0]].filled <= 1'b0;
                rob[flush_seq_i[PTR_W-1:0]].done   <= 1'b0;
                tail  <= flush_seq_i[PTR_W-1:0];        // tail = 4
                count <= (PTR_W+1)'(flush_seq_i[PTR_W-1:0] - head);
            end else if (do_fetch && ~is_nop) begin     // flush nahi hai tabhi fetch karo
                rob[tail].valid <= 1'b1;
                rob[tail].instr <= fetch_instr_i;
                tail  <= next_ptr(tail);
                count <= count + (PTR_W+1)'(1);
            end

        end
    end

    assign commit_valid_o              = head_entry.valid && head_entry.filled && head_entry.done;
    assign commit_scalar_seq_num_o     = (!head_entry.is_vector & commit_valid_o) ? (`Tag_Width)'(head) : '0;
    assign commit_vector_seq_num_o     = ( head_entry.is_vector & commit_valid_o) ? (`Tag_Width)'(head) : '0;
    assign commit_rd_o                 = (!head_entry.is_vector & commit_valid_o) ? head_entry.rd       : '0;
    assign commit_vd_o                 = ( head_entry.is_vector & commit_valid_o) ? head_entry.vd       : '0;
    assign commit_scalar_result_o      = (!head_entry.is_vector & commit_valid_o) ? head_entry.scalar_result   : '0;
    assign commit_vector_result_o      = ( head_entry.is_vector & commit_valid_o) ? head_entry.vector_result   : '0;
    assign commit_scalar_mem_addr_o    = (!head_entry.is_vector & commit_valid_o) ? head_entry.mem_addr        : '0;
    assign commit_vec_mem_addr_o       = ( head_entry.is_vector & commit_valid_o) ? head_entry.mem_addr        : '0;
    assign commit_scalar_mem_data_o    = (!head_entry.is_vector & commit_valid_o) ? head_entry.scalar_mem_data : '0;
    assign commit_vector_mem_data_o    = ( head_entry.is_vector & commit_valid_o) ? head_entry.vector_mem_data : '0;
    assign commit_vector_mem_byte_en   = ( head_entry.is_vector & commit_valid_o) ? head_entry.mem_byte_en     : '0;
    assign commit_vector_mem_wen       = ( head_entry.is_vector & commit_valid_o) ? head_entry.mem_wen         : 1'b0;
    assign commit_vector_mem_elem_mode = ( head_entry.is_vector & commit_valid_o) ? head_entry.mem_elem_mode   : '0;
    assign commit_vector_mem_sew_enc   = ( head_entry.is_vector & commit_valid_o) ? head_entry.mem_sew_enc     : '0;
    assign commit_scalar_store_op_o    = (!head_entry.is_vector & commit_valid_o) ? head_entry.scalar_store_op : ST_OPS_NONE;
    assign commit_scalar_rd_wr_req_o   = (!head_entry.is_vector & commit_valid_o) ? head_entry.scalar_rd_wr_req: 1'b0;
    assign rob_commit_is_vec_o         = commit_valid_o && head_entry.is_vector;

    logic [PTR_W-1:0] dispatch_idx;
    assign dispatch_idx = de_vec_dispatch_now ? PTR_W'(de_seq_num_i) : viq_seq_num;
    assign viq_dispatch_valid_o    = do_viq_dispatch;
    assign viq_dispatch_is_vec_o   = do_viq_dispatch;
    assign viq_dispatch_instr_o    = de_vec_dispatch_now ? de_instr_i : rob[viq_seq_num].instr;
    assign viq_dispatch_seq_num_o  = (`Tag_Width)'(dispatch_idx);
    assign viq_dispatch_rs1_data_o = do_viq_dispatch ? viq_fwd_rs1 : '0;
    assign viq_dispatch_rs2_data_o = do_viq_dispatch ? viq_fwd_rs2 : '0;

    always_comb begin
        flush_dist_comb = flush_seq_i[PTR_W-1:0] - head;
        flush_count     = '0;
        for (int i = 0; i < `ROB_DEPTH; i++) begin
            entry_dist_comb[i] = PTR_W'(i) - head;
            if (rob[i].valid && (entry_dist_comb[i] < flush_dist_comb))
                flush_count = flush_count + (PTR_W+1)'(1);
        end
    end

endmodule