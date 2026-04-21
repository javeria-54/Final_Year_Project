module rob #(
    parameter int ROB_DEPTH   = 16,
    parameter int REG_ADDR_W  = 5,
    parameter int VREG_ADDR_W = 5
)(
    input  logic clk,
    input  logic rst_n,

    input  logic                            fetch_valid_i,
    input  logic [31:0]                     fetch_instr_i,
    output logic                            rob_full_o,
    output logic [$clog2(ROB_DEPTH)-1:0]    rob_seq_num_o,

    input  logic                            de_valid_i,
    input  logic [$clog2(ROB_DEPTH)-1:0]    de_seq_num_i,
    input  logic                            de_is_vector_i,
    input  logic                            de_scalar_store_i,
    input  logic                            de_vector_store_i,
    input  logic                            de_is_load_i,
    input  logic                            de_vector_load_i,
    input  logic [REG_ADDR_W-1:0]           de_scalar_rd_addr_i,
    input  logic [VREG_ADDR_W-1:0]          de_vector_vd_addr_i,
    input  logic [REG_ADDR_W-1:0]           de_rs1_data_i,
    input  logic [REG_ADDR_W-1:0]           de_rs2_data_i,
    input  logic [31:0]                     de_instr_i,

    output logic                            fwd_rs1_hit_o,
    output logic [31:0]                     fwd_rs1_val_o,
    output logic                            fwd_rs2_hit_o,
    output logic [31:0]                     fwd_rs2_val_o,

    output logic                            fwd_vs1_hit_o,
    output logic [511:0]                    fwd_vs1_val_o,
    output logic                            fwd_vs2_hit_o,
    output logic [511:0]                    fwd_vs2_val_o,

    output logic [31:0]                     fwd_rs1_data_o,
    output logic [31:0]                     fwd_rs2_data_o,
    output logic [511:0]                    fwd_vs1_data_o,
    output logic [511:0]                    fwd_vs2_data_o,

    input  logic                            scalar_done_i,
    input  logic [$clog2(ROB_DEPTH)-1:0]    scalar_seq_num_i,
    input  logic [REG_ADDR_W-1:0]           scalar_rd_addr_i,
    input  logic [31:0]                     scalar_result_i,
    input  logic [31:0]                     scalar_mem_addr_i,
    input  logic [31:0]                     scalar_mem_data_i,
    input  logic                            scalar_exception_i,
    output logic [31:0]                     scalar_mem_data_o,

    input  logic                            vector_done_i,
    input  logic [$clog2(ROB_DEPTH)-1:0]    vector_seq_num_i,
    input  logic [VREG_ADDR_W-1:0]          vector_vd_addr_i,
    input  logic [511:0]                    vector_result_i,
    input  logic [31:0]                     vector_mem_addr_i,
    input  logic [511:0]                    vector_mem_data_i,
    input  logic                            vector_exception_i,
    output logic [511:0]                    vector_mem_data_o,

    input  logic [VREG_ADDR_W-1:0]          viq_src1_reg_i,
    input  logic [VREG_ADDR_W-1:0]          viq_src2_reg_i,
    output logic                            stall_vec_raw_o,

    output logic                            stall_scalar_mem_o,
    output logic                            stall_vector_mem_o,

    output logic                            commit_valid_o,
    output logic [$clog2(ROB_DEPTH)-1:0]    commit_seq_num_o,
    output logic                            commit_is_vector_o,
    output logic                            commit_scalar_store_o,
    output logic                            commit_vector_store_o,
    output logic [REG_ADDR_W-1:0]           commit_rd_o,
    output logic [VREG_ADDR_W-1:0]          commit_vd_o,
    output logic [31:0]                     commit_scalar_result_o,
    output logic [511:0]                    commit_vector_result_o,
    output logic [31:0]                     commit_mem_addr_o,
    output logic [511:0]                    commit_mem_data_o,
    output logic [31:0]                     commit_scalar_mem_data_o,
    output logic                            commit_exception_o,

    input  logic                            flush_valid_i,
    input  logic [$clog2(ROB_DEPTH)-1:0]    flush_seq_i
);

    localparam int PTR_W = $clog2(ROB_DEPTH);

    typedef struct packed {
        logic                    valid;
        logic                    filled;
        logic                    done;
        logic                    is_vector;
        logic                    is_scalar_store;
        logic                    is_vector_store;
        logic                    is_mem;
        logic [31:0]             instr;
        logic [REG_ADDR_W-1:0]  rd;
        logic [VREG_ADDR_W-1:0] vd;
        logic [511:0]            result;
        logic [31:0]             mem_addr;
        logic [511:0]            mem_data;
        logic                    exception;
    } rob_entry_t;

    rob_entry_t rob [ROB_DEPTH];

    logic [PTR_W-1:0] head;
    logic [PTR_W-1:0] tail;
    logic [PTR_W:0]   count;
    logic [PTR_W:0]   flush_count;

    assign rob_full_o    = (count == (PTR_W+1)'(ROB_DEPTH));
    assign rob_seq_num_o = tail;

    logic any_unretired_vec_mem;
    logic any_unretired_scalar_mem;

    always_comb begin
        any_unretired_vec_mem    = 1'b0;
        any_unretired_scalar_mem = 1'b0;
        for (int i = 0; i < ROB_DEPTH; i++) begin
            if (rob[i].valid && rob[i].filled && rob[i].is_mem) begin
                if ( rob[i].is_vector) any_unretired_vec_mem    = 1'b1;
                if (!rob[i].is_vector) any_unretired_scalar_mem = 1'b1;
            end
        end
    end

    assign stall_scalar_mem_o = any_unretired_vec_mem;
    assign stall_vector_mem_o = any_unretired_scalar_mem;

    always_comb begin
        fwd_rs1_hit_o = 1'b0; fwd_rs1_val_o = '0;
        fwd_rs2_hit_o = 1'b0; fwd_rs2_val_o = '0;
        for (int i = 0; i < ROB_DEPTH; i++) begin
            if (rob[i].valid && rob[i].done && !rob[i].is_vector) begin
                if (rob[i].rd == de_rs1_data_i) begin
                    fwd_rs1_hit_o = 1'b1;
                    fwd_rs1_val_o = rob[i].result[31:0];
                end
                if (rob[i].rd == de_rs2_data_i) begin
                    fwd_rs2_hit_o = 1'b1;
                    fwd_rs2_val_o = rob[i].result[31:0];
                end
            end
        end
    end

    assign fwd_rs1_data_o = fwd_rs1_hit_o;
    assign fwd_rs2_data_o = fwd_rs2_val_o;

    always_comb begin
        fwd_vs1_hit_o = 1'b0; fwd_vs1_val_o = '0;
        fwd_vs2_hit_o = 1'b0; fwd_vs2_val_o = '0;
        for (int i = 0; i < ROB_DEPTH; i++) begin
            if (rob[i].valid && rob[i].done && rob[i].is_vector) begin
                if (rob[i].vd == viq_src1_reg_i) begin
                    fwd_vs1_hit_o = 1'b1;
                    fwd_vs1_val_o = rob[i].result;
                end
                if (rob[i].vd == viq_src2_reg_i) begin
                    fwd_vs2_hit_o = 1'b1;
                    fwd_vs2_val_o = rob[i].result;
                end
            end
        end
    end

    assign fwd_vs1_data_o = fwd_vs1_hit_o;
    assign fwd_vs2_data_o = fwd_vs2_val_o;

    always_comb begin
        stall_vec_raw_o = 1'b0;
        for (int i = 0; i < ROB_DEPTH; i++) begin
            if (rob[i].valid && rob[i].is_vector && !rob[i].done) begin
                if ((rob[i].vd == viq_src1_reg_i) || (rob[i].vd == viq_src2_reg_i))
                    stall_vec_raw_o = 1'b1;
            end
        end
    end

    rob_entry_t head_entry;
    assign head_entry = rob[head];

    assign commit_valid_o           = head_entry.valid && head_entry.filled && head_entry.done;
    assign commit_seq_num_o         = head;
    assign commit_is_vector_o       = head_entry.is_vector;
    assign commit_scalar_store_o    = head_entry.is_scalar_store;
    assign commit_vector_store_o    = head_entry.is_vector_store;

    assign commit_rd_o              = (!head_entry.is_vector && commit_valid_o) ? head_entry.rd  : '0;
    assign commit_vd_o              = ( head_entry.is_vector && commit_valid_o) ? head_entry.vd  : '0;

    assign commit_scalar_result_o   = (!head_entry.is_vector && commit_valid_o) ? head_entry.result[31:0] : '0;
    assign commit_vector_result_o   = ( head_entry.is_vector && commit_valid_o) ? head_entry.result       : '0;

    assign commit_mem_addr_o        = head_entry.mem_addr;
    assign commit_mem_data_o        = head_entry.is_vector ? head_entry.mem_data : '0;
    assign commit_scalar_mem_data_o = !head_entry.is_vector ? head_entry.mem_data[31:0] : '0;
    assign commit_exception_o       = head_entry.exception;

    assign scalar_mem_data_o = head_entry.mem_data[31:0];
    assign vector_mem_data_o = head_entry.mem_data;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            head  <= '0;
            tail  <= '0;
            count <= '0;
            for (int i = 0; i < ROB_DEPTH; i++)
                rob[i] <= '0;
        end else begin

            if (flush_valid_i) begin
                for (int i = 0; i < ROB_DEPTH; i++) begin
                    if (rob[i].valid && (PTR_W'(i) >= flush_seq_i))
                        rob[i].valid <= 1'b0;
                end
                tail  <= flush_seq_i;
                count <= flush_count;
            end

            if (fetch_valid_i && !rob_full_o && !flush_valid_i) begin
                rob[tail].valid           <= 1'b1;
                rob[tail].filled          <= 1'b0;
                rob[tail].done            <= 1'b0;
                rob[tail].is_vector       <= 1'b0;
                rob[tail].is_scalar_store <= 1'b0;
                rob[tail].is_vector_store <= 1'b0;
                rob[tail].is_mem          <= 1'b0;
                rob[tail].instr           <= fetch_instr_i;
                rob[tail].rd              <= '0;
                rob[tail].vd              <= '0;
                rob[tail].result          <= '0;
                rob[tail].mem_addr        <= '0;
                rob[tail].mem_data        <= '0;
                rob[tail].exception       <= 1'b0;
                tail  <= tail + PTR_W'(1);
                count <= count + 1'b1;
            end

            if (de_valid_i && !flush_valid_i) begin
                rob[de_seq_num_i].filled          <= 1'b1;
                rob[de_seq_num_i].is_vector       <= de_is_vector_i;
                rob[de_seq_num_i].is_scalar_store <= de_scalar_store_i;
                rob[de_seq_num_i].is_vector_store <= de_vector_store_i;
                rob[de_seq_num_i].is_mem          <= de_scalar_store_i | de_vector_store_i
                                                   | de_is_load_i      | de_vector_load_i;
                rob[de_seq_num_i].rd              <= de_scalar_rd_addr_i;
                rob[de_seq_num_i].vd              <= de_vector_vd_addr_i;
                rob[de_seq_num_i].instr           <= de_instr_i;
            end

            if (scalar_done_i) begin
                rob[scalar_seq_num_i].done      <= 1'b1;
                rob[scalar_seq_num_i].rd        <= scalar_rd_addr_i;
                rob[scalar_seq_num_i].result    <= {{(512-32){1'b0}}, scalar_result_i};
                rob[scalar_seq_num_i].mem_addr  <= scalar_mem_addr_i;
                rob[scalar_seq_num_i].mem_data  <= {{(512-32){1'b0}}, scalar_mem_data_i};
                rob[scalar_seq_num_i].exception <= scalar_exception_i;
            end

            if (vector_done_i) begin
                rob[vector_seq_num_i].done      <= 1'b1;
                rob[vector_seq_num_i].vd        <= vector_vd_addr_i;
                rob[vector_seq_num_i].result    <= vector_result_i;
                rob[vector_seq_num_i].mem_addr  <= vector_mem_addr_i;
                rob[vector_seq_num_i].mem_data  <= vector_mem_data_i;
                rob[vector_seq_num_i].exception <= vector_exception_i;
            end

            if (commit_valid_o && !flush_valid_i) begin
                rob[head].valid  <= 1'b0;
                rob[head].filled <= 1'b0;
                rob[head].done   <= 1'b0;
                head  <= head + PTR_W'(1);
                count <= count - 1'b1;
            end

        end
    end

    always_comb begin
        flush_count = '0;
        for (int i = 0; i < ROB_DEPTH; i++)
            if (rob[i].valid && (PTR_W'(i) < flush_seq_i))
                flush_count = flush_count + 1'b1;
    end

endmodule