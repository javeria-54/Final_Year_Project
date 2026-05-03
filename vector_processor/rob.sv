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
    output logic [`XLEN-1:0]              viq_dispatch_rs1_data_o,
    output logic [`XLEN-1:0]              viq_dispatch_rs2_data_o,
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
    input  logic [`XLEN-1:0]              vector_mem_addr_i,
    input  logic [`VLEN-1:0]              vector_mem_data_i,
    input  logic [63:0]                    mem_byte_en,
    input  logic                           mem_wen,
    input  logic                           mem_elem_mode,
    input  logic [1:0]                     mem_sew_enc,

    // ---- Commit ---------------------------------------------
    output logic                           commit_valid_o,rob_commit_is_vec_o,
    output logic [`Tag_Width-1:0]          commit_scalar_seq_num_o,
    output logic [`Tag_Width-1:0]          commit_vector_seq_num_o,
    output logic [`REG_ADDR_W-1:0]         commit_rd_o,
    output logic [`VREG_ADDR_W-1:0]        commit_vd_o,
    output logic [`XLEN-1:0]              commit_scalar_result_o,
    output logic [`MAX_VLEN-1:0]           commit_vector_result_o,
    output logic [`XLEN-1:0]              commit_scalar_mem_addr_o,
    output logic [`XLEN-1:0]              commit_vec_mem_addr_o,
    output logic [`XLEN-1:0]              commit_scalar_mem_data_o,
    output logic [`VLEN-1:0]              commit_vector_mem_data_o,
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
        // FIX: split result into scalar and vector fields (were missing before)
        logic [`XLEN-1:0]            scalar_result;
        logic [`MAX_VLEN-1:0]        vector_result;
        logic [`XLEN-1:0]            mem_addr;
        // FIX: split mem_data into scalar and vector fields (were missing before)
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
    // FIX: Declare all missing internal signals
    // =========================================================
    localparam int PTR_W = $clog2(`ROB_DEPTH);
    localparam logic [`XLEN-1:0] NOP_INSTR = `XLEN'h0000_0013;

    // ROB array and head entry
    rob_entry_t                  rob [`ROB_DEPTH];
    rob_entry_t                  head_entry;

    // Head/tail pointers and count
    logic [PTR_W-1:0]            head;
    logic [PTR_W-1:0]            tail;
    logic [PTR_W:0]              count;

    // Status flags
    logic                        rob_full;
    logic                        is_nop;
    logic                        do_fetch;
    logic                        do_commit;
    logic                        do_viq_dispatch;

    // FIX: VIQ dispatch - scan result signals (were completely missing)
    logic                        found_vec_to_dispatch;
    logic [PTR_W-1:0]            viq_seq_num;
    logic [`VREG_ADDR_W-1:0]     viq_dispatch_vd;
    logic [`VREG_ADDR_W-1:0]     viq_dispatch_vs1;
    logic [`VREG_ADDR_W-1:0]     viq_dispatch_vs2;
    logic                        viq_dispatch_is_load;
    logic                        viq_dispatch_is_store;

    // Forwarding
    logic                        fwd_rs1_hit;
    logic [`XLEN-1:0]            fwd_rs1_val;
    logic                        fwd_rs2_hit;
    logic [`XLEN-1:0]            fwd_rs2_val;
    logic                        fwd_vs1_hit;
    logic [`VLEN-1:0]            fwd_vs1_val;
    logic                        fwd_vs2_hit;
    logic [`VLEN-1:0]            fwd_vs2_val;

    // FIX: RAW in-flight checks for VIQ dispatch (were missing)
    logic                        rs1_in_flight;
    logic                        rs2_in_flight;

    // Memory stall tracking
    logic                        any_unretired_vec_mem;
    logic                        any_unretired_scalar_mem;
    logic                        stall_scalar_mem;
    logic                        stall_vec_mem;

    // Flush
    logic [PTR_W-1:0]            flush_dist_comb;
    logic [PTR_W-1:0]            entry_dist_comb [`ROB_DEPTH];
    logic [PTR_W:0]              flush_count;

    // =========================================================
    // Basic status
    // =========================================================
    assign rob_full    = (count == (PTR_W+1)'(`ROB_DEPTH));
    assign is_nop      = (fetch_instr_i == NOP_INSTR);
    assign head_entry  = rob[head];

        // ── Mini early decoder ─────────────────────────────────────
    // RISC-V standard opcodes
    localparam logic [6:0] OPC_LOAD   = 7'b000_0011;  // scalar load
    localparam logic [6:0] OPC_STORE  = 7'b010_0011;  // scalar store
    localparam logic [6:0] OPC_VLD    = 7'b000_0111;  // vector load  (RISC-V V extension)
    localparam logic [6:0] OPC_VST    = 7'b010_0111;  // vector store

    logic        fetch_is_mem_early;   // same-cycle combinational flag
    logic [6:0]  fetch_opcode;

    // =========================================================
    // Early (same-cycle) memory instruction detect
    // Sirf opcode[6:0] dekhta hai — no pipeline dependency
    // =========================================================
    assign fetch_opcode      = fetch_instr_i[6:0];

    assign fetch_is_mem_early = fetch_valid_i & (
        (fetch_opcode == OPC_LOAD)  |
        (fetch_opcode == OPC_STORE) |
        (fetch_opcode == OPC_VLD)   |
        (fetch_opcode == OPC_VST)
    );

    // FIX: stall_viq_full_o was never driven
    assign stall_viq_full_o = viq_full_i;

    logic [`XLEN-1:0] last_instr;

    // ── Sequential: pichli instruction store karo ─────────────
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            last_instr <= '0;
        end else if (de_valid_i & ~is_nop) begin
            last_instr <= rob_de_instr_o;  // sirf valid non-NOP store karo
        end
    end

    // =========================================================
    // FIX: VIQ scan - find oldest undispatched vector instruction
    // (viq_seq_num was used but never computed before)
    // =========================================================
    always_comb begin
        found_vec_to_dispatch = 1'b0;
        viq_seq_num           = '0;
        for (int i = 0; i < `ROB_DEPTH; i++) begin
            automatic logic [PTR_W-1:0] idx;
            idx = PTR_W'(head + PTR_W'(i));   // walk in-order from head
            if (rob[idx].valid      &&
                rob[idx].filled     &&
                rob[idx].is_vector  &&
                !rob[idx].viq_dispatched &&
                !found_vec_to_dispatch) begin
                found_vec_to_dispatch = 1'b1;
                viq_seq_num           = idx;
            end
        end
    end

    // =========================================================
    // FIX: rs1/rs2 in-flight check for VIQ dispatch
    // checks whether any older unfinished instruction will
    // write rs1 or rs2 of the candidate vector instruction
    // =========================================================
    always_comb begin
        rs1_in_flight = 1'b0;
        rs2_in_flight = 1'b0;
        for (int i = 0; i < `ROB_DEPTH; i++) begin
            if (rob[i].valid && rob[i].filled && !rob[i].done) begin
                // older scalar writing a reg that vec needs
                if (!rob[i].is_vector && rob[i].rd != '0) begin
                    if (`VREG_ADDR_W'(rob[i].rd) == rob[viq_seq_num].vs1)
                        rs1_in_flight = 1'b1;
                    if (`VREG_ADDR_W'(rob[i].rd) == rob[viq_seq_num].vs2)
                        rs2_in_flight = 1'b1;
                end
                // older vector writing a vreg that vec needs
                if (rob[i].is_vector) begin
                    if (rob[i].vd == rob[viq_seq_num].vs1)
                        rs1_in_flight = 1'b1;
                    if (rob[i].vd == rob[viq_seq_num].vs2)
                        rs2_in_flight = 1'b1;
                end
            end
        end
    end
    
logic is_repeat;
assign is_repeat = (fetch_instr_i == last_instr) & ~is_nop;
    // =========================================================
    // Control signals
    // =========================================================
    always_comb begin
        do_fetch  = fetch_valid_i & ~rob_full & ~is_repeat;
        do_commit = commit_valid_o;
        do_viq_dispatch = found_vec_to_dispatch   // FIX: use scan result
                           & ~viq_full_i
                           & ~flush_valid_i
                           & ~rs1_in_flight
                           & ~rs2_in_flight
                           & ~stall_vec_raw_o;
    end

    // =========================================================
    // VIQ dispatch output
    // =========================================================
    always_comb begin
        if (do_viq_dispatch) begin
            viq_dispatch_valid_o    = 1'b1;
            viq_dispatch_instr_o    = rob[viq_seq_num].instr;
            viq_dispatch_seq_num_o  = (`Tag_Width)'(viq_seq_num);
            viq_dispatch_vd         = rob[viq_seq_num].vd;
            viq_dispatch_vs1        = rob[viq_seq_num].vs1;
            viq_dispatch_vs2        = rob[viq_seq_num].vs2;
            viq_dispatch_rs1_data_o = rob[viq_seq_num].rs1_data;
            viq_dispatch_rs2_data_o = rob[viq_seq_num].rs2_data;
            viq_dispatch_is_load    = rob[viq_seq_num].is_vector_load;
            viq_dispatch_is_store   = rob[viq_seq_num].is_vector_store;
            viq_dispatch_is_vec_o   = 1'b1;
        end else begin
            viq_dispatch_valid_o    = 1'b0;
            viq_dispatch_instr_o    = '0;
            viq_dispatch_seq_num_o  = '0;
            viq_dispatch_vd         = '0;
            viq_dispatch_vs1        = '0;
            viq_dispatch_vs2        = '0;
            viq_dispatch_rs1_data_o = '0;
            viq_dispatch_rs2_data_o = '0;
            viq_dispatch_is_load    = 1'b0;
            viq_dispatch_is_store   = 1'b0;
            viq_dispatch_is_vec_o   = 1'b0;
        end
    end

    // =========================================================
    // Scalar forwarding (rs1 / rs2)
    // =========================================================
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
                    // FIX: use scalar_result field (result field did not exist)
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
                    if (rob[i].vd == de_vs1_addr_i) begin
                        fwd_vs1_hit = 1'b1;
                        // FIX: use vector_result field
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

    assign fwd_vs1_data_o = fwd_vs1_hit ? fwd_vs1_val : {(`VLEN-`XLEN)'(0), rf2rob_vs1_scalar_data_i};
    assign fwd_vs2_data_o = fwd_vs2_hit ? fwd_vs2_val : '0;

    // =========================================================
    // Vector RAW stall
    // =========================================================
    always_comb begin
        stall_vec_raw_o = 1'b0;
        for (int i = 0; i < `ROB_DEPTH; i++) begin
            if (rob[i].valid && rob[i].filled && !rob[i].done) begin
                if (rob[i].is_vector) begin
                    if (rob[i].vd == de_vs1_addr_i || rob[i].vd == de_vs2_addr_i)
                        stall_vec_raw_o = 1'b1;
                end
                if (!rob[i].is_vector && rob[i].rd != '0) begin
                    if (`VREG_ADDR_W'(rob[i].rd) == de_vs1_addr_i ||
                        `VREG_ADDR_W'(rob[i].rd) == de_vs2_addr_i)
                        stall_vec_raw_o = 1'b1;
                end
            end
        end
    end

    // =========================================================
    // Memory stall
    // =========================================================
    always_comb begin
        any_unretired_vec_mem    = 1'b0;
        any_unretired_scalar_mem = 1'b0;
        for (int i = 0; i < `ROB_DEPTH; i++) begin
            if (rob[i].valid && rob[i].filled && rob[i].is_mem) begin
                if ( rob[i].is_vector) any_unretired_vec_mem    = 1'b1;
                if (!rob[i].is_vector) any_unretired_scalar_mem = 1'b1;
            end
        end
    end

    assign stall_scalar_mem = any_unretired_vec_mem;
    // FIX: name was stall_vector_mem before (mismatch) - now consistent
    assign stall_vec_mem    = any_unretired_scalar_mem;

    // Stall fetch usi cycle mein
    assign stall_fetch_o = stall_scalar_mem     | stall_vec_mem     | rob_full    | fetch_is_mem_early; 

    always_comb begin
        if (do_fetch) begin
            rob_de_instr_o   = fetch_instr_i;  // same cycle
            if (is_nop)
                rob_de_seq_num_o = 'b0;
            else 
                rob_de_seq_num_o = (`Tag_Width)'(tail); // tail = current seq_num
        end else begin
            rob_de_instr_o   = rob_de_instr_o;
            rob_de_seq_num_o = rob_de_seq_num_o;
        end
    end

    // =========================================================
    // Sequential logic - reset, fetch, decode, writeback, commit
    // =========================================================
    always_ff @(posedge clk or negedge rst_n) begin
        // FIX: rst_n is active-low so reset on !rst_n (was if(rst_n) before)
        if (!rst_n) begin
            head  <= 'd1;
            tail  <= 'd1;
            count <= '0;
            for (int i = 0; i < `ROB_DEPTH; i++) begin
                 rob[i] <= '0; 
            end
        end else begin

            // ── Fetch: allocate new ROB slot at tail ──────────────
            if (do_fetch) begin
                rob[tail].valid  <= 1'b1;
                rob[tail].instr  <= fetch_instr_i;
                tail <= tail + PTR_W'(1);  // sirf yahan register update
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
                rob[de_seq_num_i].is_mem          <= de_scalar_store_i | de_vector_store_i | de_scalar_load_i  | de_vector_load_i;
                rob[de_seq_num_i].vd              <= de_vector_vd_addr_i;
                rob[de_seq_num_i].vs1             <= de_vs1_addr_i;
                rob[de_seq_num_i].vs2             <= de_vs2_addr_i;
                // store forwarded data at decode time
                rob[de_seq_num_i].rs1_data        <= fwd_rs1_data_o;
                rob[de_seq_num_i].rs2_data        <= fwd_rs2_data_o;
                if (de_is_vector_i && do_viq_dispatch)
                    rob[de_seq_num_i].viq_dispatched <= 1'b1;
            end

            // ── Scalar writeback ──────────────────────────────────
            if (scalar_done_i) begin
                rob[scalar_seq_num_i].done            <= 1'b1;
                rob[scalar_seq_num_i].rd              <= scalar_rd_addr_i;
                // FIX: use scalar_result field (was .result before - did not exist)
                rob[scalar_seq_num_i].scalar_result   <= scalar_result_i;
                rob[scalar_seq_num_i].mem_addr        <= scalar_mem_addr_i;
                // FIX: use scalar_mem_data field (was .scalar_mem_data but no dot + comma)
                rob[scalar_seq_num_i].scalar_mem_data <= scalar_mem_data_i;
                // FIX: added missing dot and changed comma to semicolon
                rob[scalar_seq_num_i].scalar_store_op <= scalar_store_op_i;
                rob[scalar_seq_num_i].scalar_rd_wr_req<= scalar_rd_wr_req;
            end

            // ── Vector writeback ──────────────────────────────────
            if (vector_done_i) begin
                rob[vector_seq_num_i].done          <= 1'b1;
                rob[vector_seq_num_i].vd            <= vector_vd_addr_i;
                // FIX: use vector_result field
                rob[vector_seq_num_i].vector_result <= vector_result_i;
                rob[vector_seq_num_i].mem_addr      <= vector_mem_addr_i;
                // FIX: use vector_mem_data field
                rob[vector_seq_num_i].vector_mem_data <= vector_mem_data_i;
                rob[vector_seq_num_i].mem_byte_en   <= mem_byte_en;
                rob[vector_seq_num_i].mem_wen       <= mem_wen;
                rob[vector_seq_num_i].mem_elem_mode <= mem_elem_mode;
                rob[vector_seq_num_i].mem_sew_enc   <= mem_sew_enc;
            end

            // ── Commit: retire head entry ─────────────────────────
            if (do_commit) begin
                rob[head].valid <= 1'b0;
                head  <= head  + PTR_W'(1);
                count <= count - (PTR_W+1)'(1);
            end

            // ── Flush ─────────────────────────────────────────────
            // FIX: flush was computed but entries were never invalidated
            if (flush_valid_i) begin
                for (int i = 0; i < `ROB_DEPTH; i++) begin
                    automatic logic [PTR_W-1:0] entry_dist;
                    automatic logic [PTR_W-1:0] f_dist;
                    entry_dist = PTR_W'(i)              - head;
                    f_dist     = flush_seq_i[PTR_W-1:0] - head;
                    // invalidate entries newer than flush_seq_i
                    if (rob[i].valid && (entry_dist > f_dist)) begin
                        rob[i].valid <= 1'b0;
                        rob[i].filled<= 1'b0;
                        rob[i].done  <= 1'b0;
                    end
                end
                // reset tail to one past flush point
                tail  <= flush_seq_i[PTR_W-1:0] + PTR_W'(1);
                count <= (PTR_W+1)'(flush_seq_i[PTR_W-1:0] - head + 1);
            end

        end
    end

    // =========================================================
    // Commit outputs
    // FIX: use scalar_result / vector_result / scalar_mem_data /
    //      vector_mem_data instead of the nonexistent .result / .mem_data
    // =========================================================
    assign commit_valid_o              = head_entry.valid && head_entry.filled && head_entry.done;
    assign commit_scalar_seq_num_o     = (!head_entry.is_vector & commit_valid_o) ? (`Tag_Width)'(head) : '0;
    assign commit_vector_seq_num_o     = ( head_entry.is_vector & commit_valid_o) ? (`Tag_Width)'(head) : '0;
    assign commit_rd_o                 = (!head_entry.is_vector & commit_valid_o) ? head_entry.rd  : '0;
    assign commit_vd_o                 = ( head_entry.is_vector & commit_valid_o) ? head_entry.vd  : '0;
    assign commit_scalar_result_o      = (!head_entry.is_vector & commit_valid_o) ? head_entry.scalar_result              : '0;
    assign commit_vector_result_o      = ( head_entry.is_vector & commit_valid_o) ? head_entry.vector_result              : '0;
    assign commit_scalar_mem_addr_o    = (!head_entry.is_vector & commit_valid_o) ? head_entry.mem_addr                   : '0;
    assign commit_vec_mem_addr_o       = ( head_entry.is_vector & commit_valid_o) ? head_entry.mem_addr                   : '0;
    assign commit_scalar_mem_data_o    = (!head_entry.is_vector & commit_valid_o) ? head_entry.scalar_mem_data            : '0;
    assign commit_vector_mem_data_o    = ( head_entry.is_vector & commit_valid_o) ? head_entry.vector_mem_data            : '0;
    assign commit_vector_mem_byte_en   = ( head_entry.is_vector & commit_valid_o) ? head_entry.mem_byte_en                : '0;
    assign commit_vector_mem_wen       = ( head_entry.is_vector & commit_valid_o) ? head_entry.mem_wen                    : 1'b0;
    assign commit_vector_mem_elem_mode = ( head_entry.is_vector & commit_valid_o) ? head_entry.mem_elem_mode              : '0;
    assign commit_vector_mem_sew_enc   = ( head_entry.is_vector & commit_valid_o) ? head_entry.mem_sew_enc                : '0;
    //assign commit_scalar_store_op_o    = (!head_entry.is_vector & commit_valid_o) ? type_st_ops_e'(head_entry.scalar_store_op) : '0;
    assign commit_scalar_store_op_o = (!head_entry.is_vector & commit_valid_o)   ? head_entry.scalar_store_op : ST_OPS_NONE;
    assign commit_scalar_rd_wr_req_o   = (!head_entry.is_vector & commit_valid_o) ? head_entry.scalar_rd_wr_req           : 1'b0;
    assign rob_commit_is_vec_o         = commit_valid_o && head_entry.is_vector;

    // =========================================================
    // Flush distance (combinational helper - kept from original)
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

    // stall_scalar_raw_o - placeholder (decode-stage RAW logic feeds this)
    assign stall_scalar_raw_o = 1'b0;

endmodule