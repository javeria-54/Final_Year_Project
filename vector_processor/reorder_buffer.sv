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
    //  Scalar RS1/RS2 (existing)
    input  logic [`XLEN-1:0]               rf2rob_rs1_data_i,
    input  logic [`XLEN-1:0]               rf2rob_rs2_data_i,
    //  FIX: Vector VS1 read from scalar reg-file
    //  (decode already drives de_rs1_addr_i for vector ops;
    //   the reg-file should also provide the data on this port)
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

    // ---- Commit ---------------------------------------------
    output logic                           commit_valid_o,
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

rob_entry_t          rob [`ROB_DEPTH];
rob_entry_t          head_entry;
 
logic [PTR_W-1:0]    head;
logic [PTR_W-1:0]    tail;
logic [PTR_W:0]      count;

logic                rob_full;
logic                is_nop;
logic                do_fetch;
logic                do_commit;
logic                do_viq_dispatch;

logic [PTR_W-1:0]        viq_seq_num;
logic [`VREG_ADDR_W-1:0] viq_dispatch_vd;
logic [`VREG_ADDR_W-1:0] viq_dispatch_vs1;
logic [`VREG_ADDR_W-1:0] viq_dispatch_vs2;
logic                    viq_dispatch_is_load;
logic                    viq_dispatch_is_store;
logic                    found_vec_to_dispatch;

logic                fwd_rs1_hit;
logic [`XLEN-1:0]    fwd_rs1_val;
logic                fwd_rs2_hit;
logic [`XLEN-1:0]    fwd_rs2_val;
logic                fwd_vs1_hit;
logic [`VLEN-1:0]    fwd_vs1_val;
logic                fwd_vs2_hit;
logic [`VLEN-1:0]    fwd_vs2_val;

logic                rs1_in_flight;
logic                rs2_in_flight;
logic                any_unretired_vec_mem;
logic                any_unretired_scalar_mem;
logic                stall_scalar_mem;
logic                stall_vec_mem;

logic [PTR_W-1:0]    flush_dist_comb;
logic [PTR_W-1:0]    entry_dist_comb [`ROB_DEPTH];
logic [PTR_W:0]      flush_count;

logic [PTR_W-1:0]    fetch_seq_num;

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
        logic [`MAX_VLEN-1:0]        vector_result;
        logic [`XLEN-1:0]            mem_addr;
        logic [`VLEN-1:0]            mem_data;
        logic [63:0]                 mem_byte_en;
        logic                        mem_wen;
        logic                        mem_elem_mode;
        logic [1:0]                  mem_sew_enc;
        logic [1:0]                  scalar_store_op;
        logic                        scalar_rd_wr_req;
    } rob_entry_t;

    localparam int PTR_W = $clog2(`ROB_DEPTH);
    localparam logic [`XLEN-1:0] NOP_INSTR = `XLEN'h0000_0013;

    assign rob_full = (count == (PTR_W+1)'(`ROB_DEPTH));
    assign is_nop = (fetch_instr_i == NOP_INSTR);
   
    always_comb begin
        do_fetch  = fetch_valid_i & ~rob_full & ~is_nop;
        do_commit = commit_valid_o;
        do_viq_dispatch = de_valid_i
                           & de_is_vector_i
                           & ~viq_full_i
                           & ~flush_valid_i
                           & ~rs1_in_flight
                           & ~rs2_in_flight
                           & ~stall_vec_raw_o
                           & ~rob[de_seq_num_i].viq_dispatched;
        if (do_viq_dispatch) begin
            viq_dispatch_valid_o    = 1'b1;
            viq_dispatch_instr_o    = rob[viq_seq_num].instr;
            viq_dispatch_seq_num_o  = rob[viq_seq_num].seq_num;
            viq_dispatch_vd         = rob[viq_seq_num].vd;
            viq_dispatch_rs1_data_o = rob[viq_seq_num].rs1_data;
            viq_dispatch_rs2_data_o = rob[viq_seq_num].rs2_data;
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
                    fwd_rs1_val = rob[i].result[`XLEN-1:0];
                end
                if (rob[i].rd == de_rs2_addr_i && de_rs2_addr_i != '0) begin
                    fwd_rs2_hit = 1'b1;
                    fwd_rs2_val = rob[i].result[`XLEN-1:0];
                end
            end
        end
    end

    assign fwd_rs1_data_o = fwd_rs1_hit ? fwd_rs1_val : rf2rob_rs1_data_i;
    assign fwd_rs2_data_o = fwd_rs2_hit ? fwd_rs2_val : rf2rob_rs2_data_i;

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
                        fwd_vs1_val = rob[i].result[`VLEN-1:0];
                    end
                    if (rob[i].vd == de_vs2_addr_i) begin
                        fwd_vs2_hit = 1'b1;
                        fwd_vs2_val = rob[i].result[`VLEN-1:0];
                    end
                end
                if (!rob[i].is_vector && rob[i].rd != '0) begin
                    if (`VREG_ADDR_W'(rob[i].rd) == de_vs1_addr_i) begin
                        fwd_vs1_hit = 1'b1;
                        fwd_vs1_val = {(`VLEN-`XLEN)'(0), rob[i].result[`XLEN-1:0]};
                    end
                    if (`VREG_ADDR_W'(rob[i].rd) == de_vs2_addr_i) begin
                        fwd_vs2_hit = 1'b1;
                        fwd_vs2_val = {(`VLEN-`XLEN)'(0), rob[i].result[`XLEN-1:0]};
                    end
                end
            end
        end
    end

    assign fwd_vs1_data_o = fwd_vs1_hit ? fwd_vs1_val : {(`VLEN-`XLEN)'(0),  rf2rob_vs1_scalar_data_i};
    assign fwd_vs2_data_o = fwd_vs2_hit ? fwd_vs2_val : '0;

    always_comb begin
        stall_vec_raw_o = 1'b0;
        for (int i = 0; i < `ROB_DEPTH; i++) begin
            if (rob[i].valid && rob[i].filled && !rob[i].done) begin
                if (rob[i].is_vector) begin
                    if (rob[i].vd == de_vs1_addr_i || rob[i].vd == de_vs2_addr_i)
                        stall_vec_raw_o = 1'b1;
                end
                if (!rob[i].is_vector && rob[i].rd != '0) begin
                    if (`VREG_ADDR_W'(rob[i].rd) == de_vs1_addr_i || `VREG_ADDR_W'(rob[i].rd) == de_vs2_addr_i)
                        stall_vec_raw_o = 1'b1;
                end
            end
        end
    end

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
    assign stall_fetch_o  = stall_scalar_mem | stall_vec_mem | rob_full;
    assign stall_scalar_mem = any_unretired_vec_mem;
    assign stall_vector_mem = any_unretired_scalar_mem;


    always_ff @(posedge clk) begin
        if(rst_n) begin
            count = 0;
            fetch_seq_num = 0;
        end
        if (fetch_valid_i & ~is_nop) begin
            fetch_seq_num <= count +1;
        end
        if (do_fetch) begin
            rob_de_instr_o <= instr_fetch_i;
            rob_de_seq_num_o <= fetch_seq_num;
        end
        if (de_valid_i) begin
            rob[de_seq_num_i].filled          <= 1'b1;
            rob[de_seq_num_i].is_vector       <= de_is_vector_i;
            rob[de_seq_num_i].is_scalar_store <= de_scalar_store_i;
            rob[de_seq_num_i].is_scalar_load  <= de_scalar_load_i;
            rob[de_seq_num_i].rd              <= de_scalar_rd_addr_i;
            rob[de_seq_num_i].rs1             <= de_rs1_addr_i;
            rob[de_seq_num_i].rs2             <= de_rs2_addr_i;
            rob[de_seq_num_i].scalar_store_op <= scalar_store_op_i;
            rob[de_seq_num_i].scalar_rd_wr_req<= scalar_rd_wr_req;
            rob[de_seq_num_i].is_vector_store <= de_vector_store_i;
            rob[de_seq_num_i].is_vector_load  <= de_vector_load_i;
            rob[de_seq_num_i].is_mem          <= de_scalar_store_i | de_vector_store_i | de_scalar_load_i | de_vector_load_i;  
            rob[de_seq_num_i].vd              <= de_vector_vd_addr_i;
            rob[de_seq_num_i].vs1             <= de_vs1_addr_i;
            rob[de_seq_num_i].vs2             <= de_vs2_addr_i;
            if (de_is_vector_i && do_viq_dispatch)
                rob[de_seq_num_i].viq_dispatched <= 1'b1;
        end
        if (scalar_done_i) begin
            rob[scalar_seq_num_i].done              <= 1'b1;
            rob[scalar_seq_num_i].rd                <= scalar_rd_addr_i;
            rob[scalar_seq_num_i].scalar_result     <=  scalar_result_i;
            rob[scalar_seq_num_i].mem_addr          <= scalar_mem_addr_i;
            rob[scalar_seq_num_i].scalar_mem_data   <= scalar_mem_data_i;
            rob[scalar_seq_num_i]scalar_store_op    <= scalar_store_op_i,
            rob[scalar_seq_num_i].scalar_rd_wr_req  <= scalar_rd_wr_req,
        end
        if (vector_done_i) begin
            rob[vector_seq_num_i].done          <= 1'b1;
            rob[vector_seq_num_i].vd            <= vector_vd_addr_i;
            rob[vector_seq_num_i].vector_result <= vector_result_i;
            rob[vector_seq_num_i].mem_addr      <= vector_mem_addr_i;
            rob[vector_seq_num_i].mem_data      <= vector_mem_data_i;
            rob[vector_seq_num_i].mem_byte_en   <= mem_byte_en;
            rob[vector_seq_num_i].mem_wen       <= mem_wen;
            rob[vector_seq_num_i].mem_elem_mode <= mem_elem_mode;
            rob[vector_seq_num_i].mem_sew_enc   <= mem_sew_enc;
        end
    end

    assign commit_valid_o               = head_entry.valid && head_entry.filled && head_entry.done;
    assign commit_scalar_seq_num_o      = (!head_entry.is_vector & commit_valid_o) ? (`Tag_Width)'(head) : '0;
    assign commit_vector_seq_num_o      = ( head_entry.is_vector & commit_valid_o) ? (`Tag_Width)'(head) : '0;
    assign commit_is_vector             = head_entry.is_vector;
    assign commit_scalar_store          = head_entry.is_scalar_store & commit_valid_o;
    assign commit_vector_store          = head_entry.is_vector_store & commit_valid_o;
    assign commit_scalar_load           = head_entry.is_scalar_load  & commit_valid_o;
    assign commit_vector_load           = head_entry.is_vector_load  & commit_valid_o;
    assign commit_rd_o                  = (!head_entry.is_vector & commit_valid_o) ? head_entry.rd : '0;
    assign commit_vd_o                  = ( head_entry.is_vector & commit_valid_o) ? head_entry.vd : '0;
    assign commit_scalar_result_o       = (!head_entry.is_vector & commit_valid_o) ? head_entry.result[`XLEN-1:0] : '0;
    assign commit_vector_result_o       = ( head_entry.is_vector & commit_valid_o) ? head_entry.result : '0;
    assign commit_scalar_mem_addr_o     = (!head_entry.is_vector & commit_valid_o) ? head_entry.mem_addr : '0;
    assign commit_vec_mem_addr_o        = ( head_entry.is_vector & commit_valid_o) ? head_entry.mem_addr : '0;
    assign commit_scalar_mem_data_o     = (!head_entry.is_vector & commit_valid_o) ? head_entry.mem_data[`XLEN-1:0] : '0;
    assign commit_vector_mem_data_o     = ( head_entry.is_vector & commit_valid_o) ? head_entry.mem_data : '0;
    assign commit_vector_mem_byte_en    = (head_entry.is_vector & commit_valid_o) ? head_entry.mem_byte_en   : '0;
    assign commit_vector_mem_wen        =(head_entry.is_vector & commit_valid_o) ? head_entry.mem_wen       : 1'b0;
    assign commit_vector_mem_elem_mode  = (head_entry.is_vector & commit_valid_o) ? head_entry.mem_elem_mode : '0;
    assign commit_vector_mem_sew_enc    =  (head_entry.is_vector & commit_valid_o) ? head_entry.mem_sew_enc   : '0;
    assign commit_scalar_store_op_o     = (!head_entry.is_vector & commit_valid_o) ? head_entry.scalar_store_op : '0;
    assign commit_scalar_rd_wr_req_o    = (!head_entry.is_vector & commit_valid_o) ? head_entry.scalar_rd_wr_req : 1'b0;

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