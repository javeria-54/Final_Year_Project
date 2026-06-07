`include "pcore_types_pkg.sv"
import pcore_types_pkg::*;
`include "vector_processor_defs.svh"
`include "scalar_pcore_interface_defs.svh"
`include "scalar_pcore_config_defs.svh"

module reorder_buffer(
    input  logic                                clk,
    input  logic                                reset,

    input  logic [`Tag_Width-1:0]               id2rob_seq_num,
    input  logic [`REG_ADDR_W-1:0]              id2rob_rs1_addr,
    input  logic [`REG_ADDR_W-1:0]              id2rob_rs2_addr,
    input  logic                                id2rob_valid_i,
    input  logic [`XLEN-1:0]                    id2rob_instr_i,

    input  logic                                id2rob_is_mem_i,
    input  logic                                id2rob_is_vector_i,

    input  logic [`VREG_ADDR_W-1:0]             vid2rob_vs1_addr,
    input  logic [`VREG_ADDR_W-1:0]             vid2rob_vs2_addr,
    input  logic [`VREG_ADDR_W-1:0]             vid2rob_vd_addr,

    input  logic                                flush_valid_i,
    input  logic [`Tag_Width-1:0]               flush_seq_i,

    input  logic                                scalar_done_i,
    input  logic [`Tag_Width-1:0]               scalar_seq_num_i,
    input  logic [`VREG_ADDR_W-1:0]             scalar_rd_addr_i,
    input  logic [`XLEN-1:0]                    scalar_result_i,
    input  logic [`XLEN-1:0]                    scalar_mem_addr_i,
    input  logic [`XLEN-1:0]                    scalar_mem_data_i,
    input  type_st_ops_e                        scalar_store_op_i,
    input  logic                                scalar_rd_wr_req,

    input  logic                                vector_done_i,
    input  logic [`Tag_Width-1:0]               vector_seq_num_i,
    input  logic [`MAX_VLEN-1:0]                vector_result_i,
    input  logic                                vec_decode,

    output logic                                commit_valid_o, 
    output logic [`Tag_Width-1:0]               commit_scalar_seq_num_o,
    output logic [`Tag_Width-1:0]               commit_vector_seq_num_o,
    output logic [`REG_ADDR_W-1:0]              commit_rd_o,
    output logic [`VREG_ADDR_W-1:0]             commit_vd_o,
    output logic [`XLEN-1:0]                    commit_scalar_result_o,
    output logic [`MAX_VLEN-1:0]                commit_vector_result_o,
    output logic [`XLEN-1:0]                    commit_scalar_mem_addr_o,
    output logic [`XLEN-1:0]                    commit_scalar_mem_data_o,
    output type_st_ops_e                        commit_scalar_store_op_o,
    output logic                                commit_scalar_rd_wr_req_o,
    output logic                                commit_is_vec_o,

    output logic                                stall_fetch_o,
    output logic                                stall_scalar_raw_o,
    output logic                                stall_vec_raw_o,

    output logic [`XLEN-1:0]                    fwd_rs1_data_o,
    output logic [`XLEN-1:0]                    fwd_rs2_data_o,
    output logic [`VLEN-1:0]                    fwd_vs1_data_o,
    output logic [`VLEN-1:0]                    fwd_vs2_data_o
);

    // =========================================================
    // ROB Entry Struct
    // =========================================================
    typedef struct packed {
        logic                        valid;
        logic                        filled;
        logic                        done;
        logic                        is_vector;
        logic                        is_mem;
        logic [`XLEN-1:0]            instr;
        logic [`REG_ADDR_W-1:0]      rd;
        logic [`VREG_ADDR_W-1:0]     vd;
        logic [`VREG_ADDR_W-1:0]     vs1;
        logic [`VREG_ADDR_W-1:0]     vs2;
        logic [`VREG_ADDR_W-1:0]     rs1;
        logic [`VREG_ADDR_W-1:0]     rs2;
        logic [`XLEN-1:0]            scalar_result;
        logic [`MAX_VLEN-1:0]        vector_result;
        logic [`XLEN-1:0]            mem_addr;
        logic [`XLEN-1:0]            scalar_mem_data;
        type_st_ops_e                scalar_store_op;
        logic                        scalar_rd_wr_req;
    } rob_entry_t;

    // =========================================================
    // Parameters
    // =========================================================
    localparam int PTR_W = $clog2(`ROB_DEPTH);

    // =========================================================
    // Internal signals
    // =========================================================
    rob_entry_t                  rob [`ROB_DEPTH];
    rob_entry_t                  head_entry;

    logic [PTR_W-1:0]            head;
    logic [PTR_W-1:0]            tail;
    logic [PTR_W:0]              count;

    logic                        rob_full;
    logic                        do_commit;

    // Forwarding
    logic                        fwd_rs1_hit;
    logic [`XLEN-1:0]            fwd_rs1_val;
    logic                        fwd_rs2_hit;
    logic [`XLEN-1:0]            fwd_rs2_val;
    logic                        fwd_vs1_hit;
    logic [`VLEN-1:0]            fwd_vs1_val;
    logic                        fwd_vs2_hit;
    logic [`VLEN-1:0]            fwd_vs2_val;

    // Memory stall
    logic                        any_unretired_vec_mem;
    logic                        any_unretired_scalar_mem;

    // Flush helpers
    logic [PTR_W-1:0]            flush_dist_comb;
    logic [PTR_W-1:0]            entry_dist_comb [`ROB_DEPTH];
    logic [PTR_W:0]              flush_count;

    // =========================================================
    // Pointer helper function
    // =========================================================
    function automatic logic [PTR_W-1:0] next_ptr(logic [PTR_W-1:0] p);
        logic [PTR_W-1:0] n;
        n = p + PTR_W'(1);
        return (n == '0) ? PTR_W'(1) : n;   // skip 0, wrap to 1
    endfunction

    // =========================================================
    // Basic status
    // =========================================================
    assign rob_full    = (count == (PTR_W+1)'(`ROB_DEPTH));
    assign head_entry  = rob[head];
    assign do_commit   = commit_valid_o;

    // Stalls
    assign stall_fetch_o    = rob_full | any_unretired_vec_mem | any_unretired_scalar_mem;
    assign stall_scalar_raw_o = 1'b0;
    assign stall_vec_raw_o    = 1'b0;

    // =========================================================
    // Scalar forwarding (decode time, using id2rob ports)
    // =========================================================
    always_comb begin
        fwd_rs1_hit = 1'b0;
        fwd_rs1_val = '0;
        fwd_rs2_hit = 1'b0;
        fwd_rs2_val = '0;
        for (int i = 0; i < `ROB_DEPTH; i++) begin
            if (rob[i].valid && rob[i].filled &&
                rob[i].done  && !rob[i].is_vector) begin
                if (rob[i].rd == id2rob_rs1_addr && id2rob_rs1_addr != '0) begin
                    fwd_rs1_hit = 1'b1;
                    fwd_rs1_val = rob[i].scalar_result;
                end
                if (rob[i].rd == id2rob_rs2_addr && id2rob_rs2_addr != '0) begin
                    fwd_rs2_hit = 1'b1;
                    fwd_rs2_val = rob[i].scalar_result;
                end
            end
        end
    end

    // No register-file read data input in this module's ports,
    // so forwarding outputs are ROB hits only (or zero if no hit).
    // If RF data is available upstream, connect there.
    assign fwd_rs1_data_o = fwd_rs1_hit ? fwd_rs1_val : '0;
    assign fwd_rs2_data_o = fwd_rs2_hit ? fwd_rs2_val : '0;

    // =========================================================
    // Vector forwarding (vs1 / vs2)
    // =========================================================
    always_comb begin
        fwd_vs1_hit = 1'b0;
        fwd_vs1_val = '0;
        fwd_vs2_hit = 1'b0;
        fwd_vs2_val = '0;
        for (int i = 0; i < `ROB_DEPTH; i++) begin
            if (rob[i].valid && rob[i].filled && rob[i].done) begin
                if (rob[i].is_vector) begin
                    if (rob[i].vd == vid2rob_vs1_addr) begin
                        fwd_vs1_hit = 1'b1;
                        fwd_vs1_val = rob[i].vector_result[`VLEN-1:0];
                    end
                    if (rob[i].vd == vid2rob_vs2_addr) begin
                        fwd_vs2_hit = 1'b1;
                        fwd_vs2_val = rob[i].vector_result[`VLEN-1:0];
                    end
                end
                if (!rob[i].is_vector && rob[i].rd != '0) begin
                    if (`VREG_ADDR_W'(rob[i].rd) == vid2rob_vs1_addr) begin
                        fwd_vs1_hit = 1'b1;
                        fwd_vs1_val = {(`VLEN-`XLEN)'(0), rob[i].scalar_result};
                    end
                    if (`VREG_ADDR_W'(rob[i].rd) == vid2rob_vs2_addr) begin
                        fwd_vs2_hit = 1'b1;
                        fwd_vs2_val = {(`VLEN-`XLEN)'(0), rob[i].scalar_result};
                    end
                end
            end
        end
    end

    assign fwd_vs1_data_o = fwd_vs1_hit ? fwd_vs1_val : '0;
    assign fwd_vs2_data_o = fwd_vs2_hit ? fwd_vs2_val : '0;


    // =========================================================
    // Memory stall logic
    // =========================================================
    always_comb begin
        // 1. Initialize to 0
        any_unretired_vec_mem    = 1'b0;
        any_unretired_scalar_mem = 1'b0;

        // 2. Check all entries in the ROB
        for (int i = 0; i < `ROB_DEPTH; i++) begin
            // Only stall if the entry is valid and NOT done
            if (rob[i].valid && rob[i].is_mem && !rob[i].done) begin
                if (rob[i].is_vector) 
                    any_unretired_vec_mem    = 1'b1;
                else 
                    any_unretired_scalar_mem = 1'b1;
            end
        end
    end

    // =========================================================
    // Flush distance helper (combinational)
    // =========================================================
    always_comb begin
        flush_dist_comb = flush_seq_i[PTR_W-1:0] - head;
        flush_count     = '0;
        for (int i = 0; i < `ROB_DEPTH; i++) begin
            entry_dist_comb[i] = PTR_W'(i) - head;
            if (rob[i].valid && (entry_dist_comb[i] < flush_dist_comb))
                flush_count = flush_count + (PTR_W+1)'(1);
        end
    end

    // =========================================================
    // Sequential logic
    // =========================================================
    always_ff @(posedge clk or posedge reset) begin
        if (!reset) begin
            head  <= 'd1;
            tail  <= 'd1;
            count <= '0;
            for (int i = 0; i < `ROB_DEPTH; i++)
                rob[i] = '0;
        end else begin

            // ── Commit: retire head entry ─────────────────────────
            if (do_commit) begin
                rob[head].valid  <= 1'b0;
                rob[head].filled <= 1'b0;
                rob[head].done   <= 1'b0;
                head  <= next_ptr(head);
                count <= count - (PTR_W+1)'(1);
            end

            // ── Decode: allocate entry (seq_num comes from decode) 
            if (id2rob_valid_i && (id2rob_seq_num != '0)) begin
                rob[id2rob_seq_num].valid          <= 1'b1;
                rob[id2rob_seq_num].filled         <= 1'b1;
                rob[id2rob_seq_num].done           <= 1'b0;
                rob[id2rob_seq_num].is_vector      <= id2rob_is_vector_i;
                rob[id2rob_seq_num].is_mem         <= id2rob_is_mem_i;
                rob[id2rob_seq_num].instr          <= id2rob_instr_i;
                rob[id2rob_seq_num].rs1            <= (`VREG_ADDR_W)'(id2rob_rs1_addr);
                rob[id2rob_seq_num].rs2            <= (`VREG_ADDR_W)'(id2rob_rs2_addr);
                rob[id2rob_seq_num].scalar_store_op<= scalar_store_op_i;
                rob[id2rob_seq_num].scalar_rd_wr_req <= scalar_rd_wr_req;
                // Advance tail to next slot
                tail  <= next_ptr(id2rob_seq_num[PTR_W-1:0]);
                count <= count + (PTR_W+1)'(1);
            end

            // ── Vector decode: fill vd/vs1/vs2 fields ────────────
            if (vec_decode) begin
                rob[vector_seq_num_i].vd  <= vid2rob_vd_addr;
                rob[vector_seq_num_i].vs1 <= vid2rob_vs1_addr;
                rob[vector_seq_num_i].vs2 <= vid2rob_vs2_addr;
            end

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
                rob[vector_seq_num_i].done          <= 1'b1;
                rob[vector_seq_num_i].vector_result <= vector_result_i;
            end

            // ── Flush ─────────────────────────────────────────────
            if (flush_valid_i) begin
                rob[flush_seq_i[PTR_W-1:0]].valid   <= 1'b0;
                rob[flush_seq_i[PTR_W-1:0]].filled  <= 1'b0;
                rob[flush_seq_i[PTR_W-1:0]].done    <= 1'b0;
                tail                                <= flush_seq_i[PTR_W-1:0];
                count                               <= (PTR_W+1)'(flush_seq_i[PTR_W-1:0] - head);
            end

        end
    end

    // =========================================================
    // Commit outputs (combinational)
    // =========================================================
    assign commit_valid_o            = head_entry.valid && head_entry.filled && head_entry.done;
    assign commit_scalar_seq_num_o   = (!head_entry.is_vector & commit_valid_o) ? (`Tag_Width)'(head) : '0;
    assign commit_vector_seq_num_o   = ( head_entry.is_vector & commit_valid_o) ? (`Tag_Width)'(head) : '0;
    assign commit_rd_o               = (!head_entry.is_vector & commit_valid_o) ? head_entry.rd               : '0;
    assign commit_vd_o               = ( head_entry.is_vector & commit_valid_o) ? head_entry.vd               : '0;
    assign commit_scalar_result_o    = (!head_entry.is_vector & commit_valid_o) ? head_entry.scalar_result    : '0;
    assign commit_vector_result_o    = ( head_entry.is_vector & commit_valid_o) ? head_entry.vector_result    : '0;
    assign commit_scalar_mem_addr_o  = (!head_entry.is_vector & commit_valid_o) ? head_entry.mem_addr         : '0;
    assign commit_scalar_mem_data_o  = (!head_entry.is_vector & commit_valid_o) ? head_entry.scalar_mem_data  : '0;
    assign commit_scalar_store_op_o  = (!head_entry.is_vector & commit_valid_o) ? head_entry.scalar_store_op  : ST_OPS_NONE;
    assign commit_scalar_rd_wr_req_o = (!head_entry.is_vector & commit_valid_o) ? head_entry.scalar_rd_wr_req : 1'b0;
    assign commit_is_vec_o           = commit_valid_o && head_entry.is_vector;


endmodule