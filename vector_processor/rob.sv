`include "vector_processor_defs.svh"
`include "scalar_pcore_interface_defs.svh"

// ============================================================
//  ROB — Reorder Buffer
//  Changes in this version:
//   - Scalar register file se rs1/rs2 DATA read karta hai
//   - ROB forwarding check karta hai — agar ROB mein ready
//     result hai to woh use karta hai, warna reg file ka data
//   - VIQ ko vs1/vs2 ADDRESS + rs1/rs2 DATA bhejta hai
//   - Stall karta hai jab scalar operand ROB mein in-flight ho
//     (not done yet) taake wrong data dispatch na ho
// ============================================================

module rob (
    input  logic clk,
    input  logic rst_n,

    // --------------------------------------------------------
    // Fetch interface
    // --------------------------------------------------------
    input  logic                            fetch_valid_i,
    input  logic [`XLEN-1:0]                fetch_instr_i,
    output logic                            rob_full_o,

    // --------------------------------------------------------
    // ROB → Decode interface
    // --------------------------------------------------------
    output logic                            rob_de_valid_o,
    output logic [`XLEN-1:0]                rob_de_instr_o,
    output logic [`Tag_Width-1:0]           rob_de_seq_num_o,

    // --------------------------------------------------------
    // Decode → ROB metadata
    // --------------------------------------------------------
    input  logic                            de_valid_i,
    input  logic [`Tag_Width-1:0]           de_seq_num_i,
    input  logic                            de_is_vector_i,
    input  logic                            de_scalar_store_i,
    input  logic                            de_vector_store_i,
    input  logic                            de_scalar_load_i,
    input  logic                            de_vector_load_i,
    input  logic [4:0]                      de_scalar_rd_addr_i,
    input  logic [`VREG_ADDR_W-1:0]         de_vector_vd_addr_i,
    input  logic [`RF_AWIDTH-1:0]           de_rs1_addr_i,
    input  logic [`RF_AWIDTH-1:0]           de_rs2_addr_i,
    input  logic [`VREG_ADDR_W-1:0]         de_vs1_addr_i,
    input  logic [`VREG_ADDR_W-1:0]         de_vs2_addr_i,

    // --------------------------------------------------------
    // Scalar Register File interface
    // ROB drives rs1/rs2 address — reg file returns data
    // --------------------------------------------------------
    input  logic [`XLEN-1:0]                rf2rob_rs1_data_i,
    input  logic [`XLEN-1:0]                rf2rob_rs2_data_i,

    // --------------------------------------------------------
    // Scalar forwarding outputs
    // --------------------------------------------------------
    output logic                            fwd_rs1_hit_o,
    output logic [`XLEN-1:0]                fwd_rs1_val_o,
    output logic                            fwd_rs2_hit_o,
    output logic [`XLEN-1:0]                fwd_rs2_val_o,
    output logic [`XLEN-1:0]                fwd_rs1_data_o,
    output logic [`XLEN-1:0]                fwd_rs2_data_o,

    // --------------------------------------------------------
    // Vector forwarding outputs
    // --------------------------------------------------------
    output logic                            fwd_vs1_hit_o,
    output logic [`VLEN-1:0]                fwd_vs1_val_o,
    output logic                            fwd_vs2_hit_o,
    output logic [`VLEN-1:0]                fwd_vs2_val_o,
    output logic [`VLEN-1:0]                fwd_vs1_data_o,
    output logic [`VLEN-1:0]                fwd_vs2_data_o,

    // --------------------------------------------------------
    // VIQ (Vector Issue Queue) interface
    // --------------------------------------------------------
    output logic                            viq_dispatch_valid_o,
    output logic [`XLEN-1:0]                viq_dispatch_instr_o,
    output logic [`Tag_Width-1:0]           viq_dispatch_seq_num_o,
    output logic [`VREG_ADDR_W-1:0]         viq_dispatch_vd_o,
    output logic [`VREG_ADDR_W-1:0]         viq_dispatch_vs1_o,      // vector src ADDRESS
    output logic [`VREG_ADDR_W-1:0]         viq_dispatch_vs2_o,      // vector src ADDRESS
    output logic [`XLEN-1:0]                viq_dispatch_rs1_data_o, // scalar src DATA
    output logic [`XLEN-1:0]                viq_dispatch_rs2_data_o, // scalar src DATA
    output logic                            viq_dispatch_is_load_o,
    output logic                            viq_dispatch_is_store_o,

    input  logic                            viq_full_i,
    output logic                            stall_viq_full_o,
    output logic                            stall_scalar_raw_o,

    // --------------------------------------------------------
    // Scalar execution writeback
    // --------------------------------------------------------
    input  logic                            scalar_done_i,
    input  logic [`Tag_Width-1:0]           scalar_seq_num_i,
    input  logic [`REG_ADDR_W-1:0]          scalar_rd_addr_i,
    input  logic [`XLEN-1:0]                scalar_result_i,
    input  logic [`XLEN-1:0]                scalar_mem_addr_i,
    input  logic [`XLEN-1:0]                scalar_mem_data_i,
    output logic [`XLEN-1:0]                scalar_mem_data_o,

    // --------------------------------------------------------
    // Vector execution writeback
    // --------------------------------------------------------
    input  logic                            vector_done_i,
    input  logic [`Tag_Width-1:0]           vector_seq_num_i,
    input  logic [`VREG_ADDR_W-1:0]         vector_vd_addr_i,
    input  logic [`MAX_VLEN-1:0]                vector_result_i,
    input  logic [`XLEN-1:0]                vector_mem_addr_i,
    input  logic [`VLEN-1:0]                vector_mem_data_i,
    output logic [`VLEN-1:0]                vector_mem_data_o,
    output logic                            stall_vec_raw_o,

    // --------------------------------------------------------
    // Memory ordering stalls
    // --------------------------------------------------------
    output logic                            stall_fetch_o,
    output logic                            stall_scalar_mem_o,
    output logic                            stall_vector_mem_o,

    // --------------------------------------------------------
    // Commit interface
    // --------------------------------------------------------
    output logic                            commit_valid_o,
    output logic [`Tag_Width-1:0]           commit_vector_seq_num_o,
    output logic [`Tag_Width-1:0]           commit_scalar_seq_num_o,
    output logic                            commit_is_vector_o,
    output logic                            commit_scalar_store_o,
    output logic                            commit_vector_store_o,
    output logic [`REG_ADDR_W-1:0]          commit_rd_o,
    output logic [`VREG_ADDR_W-1:0]         commit_vd_o,
    output logic [`XLEN-1:0]                commit_scalar_result_o,
    output logic [`MAX_VLEN-1:0]                commit_vector_result_o,
    output logic [`XLEN-1:0]                commit_mem_addr_o,
    output logic [`VLEN-1:0]                commit_mem_data_o,
    output logic [`XLEN-1:0]                commit_scalar_mem_data_o,

    // --------------------------------------------------------
    // Flush interface
    // --------------------------------------------------------
    input  logic                            flush_valid_i,
    input  logic [`Tag_Width-1:0]           flush_seq_i
);

    localparam int PTR_W = $clog2(`ROB_DEPTH);

    typedef struct packed {
        logic                    valid;
        logic                    filled;
        logic                    done;
        logic                    is_vector;
        logic                    is_scalar_store;
        logic                    is_vector_store;
        logic                    is_mem;
        logic                    viq_dispatched;
        logic [`XLEN-1:0]        instr;
        logic [`REG_ADDR_W-1:0]  rd;
        logic [`VREG_ADDR_W-1:0] vd;
        logic [`VREG_ADDR_W-1:0] vs1;
        logic [`VREG_ADDR_W-1:0] vs2;
        logic [`MAX_VLEN-1:0]        result;
        logic [`XLEN-1:0]        mem_addr;
        logic [`VLEN-1:0]        mem_data;
    } rob_entry_t;

    rob_entry_t          rob [`ROB_DEPTH];
    logic [PTR_W-1:0]    head;
    logic [PTR_W-1:0]    tail;
    logic [PTR_W:0]      count;

    logic [PTR_W-1:0]    entry_dist_comb [`ROB_DEPTH];
    logic [PTR_W-1:0]    flush_dist_comb;
    logic [PTR_W:0]      flush_count;

    logic do_fetch;
    logic do_commit;

    // --------------------------------------------------------
    // ROB Full
    // --------------------------------------------------------
    assign rob_full_o = (count == (PTR_W+1)'(`ROB_DEPTH));

    // --------------------------------------------------------
    // ROB → Decode pipeline reg
    // --------------------------------------------------------
    logic             rob_de_valid_r;
    logic [31:0]      rob_de_instr_r;
    logic [PTR_W-1:0] rob_de_seq_num_r;

    assign rob_de_valid_o   = rob_de_valid_r;
    assign rob_de_instr_o   = rob_de_instr_r;
    assign rob_de_seq_num_o = rob_de_seq_num_r;

    // --------------------------------------------------------
    // Scalar Forwarding
    // ROB mein koi done entry hai jo rs1/rs2 match kare?
    // Agar haan — ROB value use karo (reg file se newer)
    // Agar nahi — reg file se aaya data use karo
    // --------------------------------------------------------
    always_comb begin
        fwd_rs1_hit_o = 1'b0;
        fwd_rs1_val_o = '0;
        fwd_rs2_hit_o = 1'b0;
        fwd_rs2_val_o = '0;
        for (int i = 0; i < `ROB_DEPTH; i++) begin
            if (rob[i].valid && rob[i].done && !rob[i].is_vector) begin
                if ((rob[i].rd == de_rs1_addr_i) && (de_rs1_addr_i != '0)) begin
                    fwd_rs1_hit_o = 1'b1;
                    fwd_rs1_val_o = rob[i].result[`XLEN-1:0];
                end
                if ((rob[i].rd == de_rs2_addr_i) && (de_rs2_addr_i != '0)) begin
                    fwd_rs2_hit_o = 1'b1;
                    fwd_rs2_val_o = rob[i].result[`XLEN-1:0];
                end
            end
        end
    end

    // Final resolved data:
    // ROB forward > scalar reg file
    assign fwd_rs1_data_o = fwd_rs1_hit_o ? fwd_rs1_val_o : rf2rob_rs1_data_i;
    assign fwd_rs2_data_o = fwd_rs2_hit_o ? fwd_rs2_val_o : rf2rob_rs2_data_i;

    // --------------------------------------------------------
    // Scalar Operand In-Flight Check
    // Agar rs1 ya rs2 ROB mein hai lekin done=0
    // to data abhi ready nahi — dispatch rok do (stall)
    // --------------------------------------------------------
    logic rs1_in_flight;
    logic rs2_in_flight;

    always_comb begin
        rs1_in_flight = 1'b0;
        rs2_in_flight = 1'b0;
        for (int i = 0; i < `ROB_DEPTH; i++) begin
            if (rob[i].valid && !rob[i].done && !rob[i].is_vector) begin
                if ((rob[i].rd == de_rs1_addr_i) && (de_rs1_addr_i != '0))
                    rs1_in_flight = 1'b1;
                if ((rob[i].rd == de_rs2_addr_i) && (de_rs2_addr_i != '0))
                    rs2_in_flight = 1'b1;
            end
        end
    end

    // Scalar RAW stall output — pipeline ko batao stall karo
    assign stall_scalar_raw_o = de_valid_i & de_is_vector_i &
                                 (rs1_in_flight | rs2_in_flight);

    // --------------------------------------------------------
    // VIQ Dispatch Condition
    //
    //  Sab conditions true honi chahiye:
    //  1. de_valid_i        — decode ne is cycle fill kiya
    //  2. de_is_vector_i    — vector instruction hai
    //  3. ~viq_full_i       — VIQ mein jagah hai
    //  4. ~flush_valid_i    — flush nahi chal raha
    //  5. ~rs1_in_flight    — rs1 data ready hai
    //  6. ~rs2_in_flight    — rs2 data ready hai
    //  7. ~viq_dispatched   — double dispatch guard
    // --------------------------------------------------------
    logic do_viq_dispatch;

    assign do_viq_dispatch = de_valid_i
                           & de_is_vector_i
                           & ~viq_full_i
                           & ~flush_valid_i
                           & ~rs1_in_flight
                           & ~rs2_in_flight
                           & ~rob[de_seq_num_i].viq_dispatched;

    // VIQ dispatch ports (combinational — same cycle dispatch)
    assign viq_dispatch_valid_o    = do_viq_dispatch;
    assign viq_dispatch_instr_o    = rob[de_seq_num_i].instr;
    assign viq_dispatch_seq_num_o  = de_seq_num_i;
    assign viq_dispatch_vd_o       = de_vector_vd_addr_i;

    // Vector sources — sirf ADDRESS (VIQ vector reg file se data lega)
    assign viq_dispatch_vs1_o      = de_vs1_addr_i;
    assign viq_dispatch_vs2_o      = de_vs2_addr_i;

    // Scalar sources — RESOLVED DATA
    // vadd.vx, vle32 jaise instructions ke liye
    // ROB forward > scalar reg file
    assign viq_dispatch_rs1_data_o = fwd_rs1_hit_o ? fwd_rs1_val_o
                                                    : rf2rob_rs1_data_i;
    assign viq_dispatch_rs2_data_o = fwd_rs2_hit_o ? fwd_rs2_val_o
                                                    : rf2rob_rs2_data_i;

    assign viq_dispatch_is_load_o  = de_vector_load_i;
    assign viq_dispatch_is_store_o = de_vector_store_i;

    // VIQ full stall
    assign stall_viq_full_o = de_valid_i & de_is_vector_i & viq_full_i;

    // --------------------------------------------------------
    // Vector Forwarding
    // --------------------------------------------------------
    always_comb begin
        fwd_vs1_hit_o = 1'b0;
        fwd_vs1_val_o = '0;
        fwd_vs2_hit_o = 1'b0;
        fwd_vs2_val_o = '0;
        for (int i = 0; i < `ROB_DEPTH; i++) begin
            if (rob[i].valid && rob[i].done) begin
                if (rob[i].is_vector) begin
                    if (rob[i].vd == de_vs1_addr_i) begin
                        fwd_vs1_hit_o = 1'b1;
                        fwd_vs1_val_o = rob[i].result;
                    end
                    if (rob[i].vd == de_vs2_addr_i) begin
                        fwd_vs2_hit_o = 1'b1;
                        fwd_vs2_val_o = rob[i].result;
                    end
                end
                if (!rob[i].is_vector && (rob[i].rd != '0)) begin
                    if (`VREG_ADDR_W'(rob[i].rd) == de_vs1_addr_i) begin
                        fwd_vs1_hit_o = 1'b1;
                        fwd_vs1_val_o = {(`VLEN-`XLEN)'(0), rob[i].result[`XLEN-1:0]};
                    end
                    if (`VREG_ADDR_W'(rob[i].rd) == de_vs2_addr_i) begin
                        fwd_vs2_hit_o = 1'b1;
                        fwd_vs2_val_o = {(`VLEN-`XLEN)'(0), rob[i].result[`XLEN-1:0]};
                    end
                end
            end
        end
    end

    assign fwd_vs1_data_o = fwd_vs1_hit_o ? fwd_vs1_val_o : '0;
    assign fwd_vs2_data_o = fwd_vs2_hit_o ? fwd_vs2_val_o : '0;

    // --------------------------------------------------------
    // Vector RAW Stall
    // --------------------------------------------------------
    always_comb begin
        stall_vec_raw_o = 1'b0;
        for (int i = 0; i < `ROB_DEPTH; i++) begin
            if (rob[i].valid && !rob[i].done) begin
                if (rob[i].is_vector) begin
                    if ((rob[i].vd == de_rs1_addr_i) ||
                        (rob[i].vd == de_rs2_addr_i))
                        stall_vec_raw_o = 1'b1;
                end
                if (!rob[i].is_vector && (rob[i].rd != '0)) begin
                    if ((`VREG_ADDR_W'(rob[i].rd) == de_rs1_addr_i) ||
                        (`VREG_ADDR_W'(rob[i].rd) == de_rs2_addr_i))
                        stall_vec_raw_o = 1'b1;
                end
            end
        end
    end

    // --------------------------------------------------------
    // Memory Ordering
    // --------------------------------------------------------
    logic any_unretired_vec_mem;
    logic any_unretired_scalar_mem;

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

    assign stall_fetch_o      = any_unretired_vec_mem | any_unretired_scalar_mem;
    assign stall_scalar_mem_o = any_unretired_vec_mem;
    assign stall_vector_mem_o = any_unretired_scalar_mem;

    // --------------------------------------------------------
    // Commit Outputs
    // --------------------------------------------------------
    rob_entry_t head_entry;
    assign head_entry = rob[head];

    assign commit_valid_o           = head_entry.valid &&
                                      head_entry.filled &&
                                      head_entry.done;
    assign commit_scalar_seq_num_o  = (`Tag_Width)'(head);
    assign commit_vector_seq_num_o  = (`Tag_Width)'(head);
    assign commit_is_vector_o       = head_entry.is_vector;
    assign commit_scalar_store_o    = head_entry.is_scalar_store;
    assign commit_vector_store_o    = head_entry.is_vector_store;
    assign commit_rd_o              = (!head_entry.is_vector && commit_valid_o)
                                      ? head_entry.rd  : '0;
    assign commit_vd_o              = ( head_entry.is_vector && commit_valid_o)
                                      ? head_entry.vd  : '0;
    assign commit_scalar_result_o   = (!head_entry.is_vector && commit_valid_o)
                                      ? head_entry.result[`XLEN-1:0] : '0;
    assign commit_vector_result_o   = ( head_entry.is_vector && commit_valid_o)
                                      ? head_entry.result : '0;
    assign commit_mem_addr_o        = head_entry.mem_addr;
    assign commit_mem_data_o        = head_entry.is_vector
                                      ? head_entry.mem_data : '0;
    assign commit_scalar_mem_data_o = !head_entry.is_vector
                                      ? head_entry.mem_data[`XLEN-1:0] : '0;
    assign scalar_mem_data_o        = head_entry.mem_data[`XLEN-1:0];
    assign vector_mem_data_o        = head_entry.mem_data;

    // --------------------------------------------------------
    // Flush Count (combinational)
    // --------------------------------------------------------
    always_comb begin
        flush_dist_comb = flush_seq_i[PTR_W-1:0] - head;
        flush_count     = '0;
        for (int i = 0; i < `ROB_DEPTH; i++) begin
            entry_dist_comb[i] = PTR_W'(i) - head;
            if (rob[i].valid && (entry_dist_comb[i] < flush_dist_comb))
                flush_count = flush_count + 1'b1;
        end
    end

    // --------------------------------------------------------
    // Sequential Logic
    // --------------------------------------------------------
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            head             <= '0;
            tail             <= '0;
            count            <= '0;
            rob_de_valid_r   <= 1'b0;
            rob_de_instr_r   <= '0;
            rob_de_seq_num_r <= '0;
            for (int i = 0; i < `ROB_DEPTH; i++)
                rob[i] <= '0;

        end else begin

            // PRIORITY 1: FLUSH
            if (flush_valid_i) begin
                for (int i = 0; i < `ROB_DEPTH; i++) begin
                    if (rob[i].valid &&
                        (PTR_W'(i) - head >= flush_seq_i[PTR_W-1:0] - head))
                        rob[i].valid <= 1'b0;
                end
                tail           <= flush_seq_i[PTR_W-1:0];
                count          <= flush_count;
                rob_de_valid_r <= 1'b0;

            end else begin

                do_fetch  = fetch_valid_i && !rob_full_o;
                do_commit = commit_valid_o;

                // STEP 2: FETCH
                if (do_fetch) begin
                    rob[tail].valid           <= 1'b1;
                    rob[tail].filled          <= 1'b0;
                    rob[tail].done            <= 1'b0;
                    rob[tail].is_vector       <= 1'b0;
                    rob[tail].is_scalar_store <= 1'b0;
                    rob[tail].is_vector_store <= 1'b0;
                    rob[tail].is_mem          <= 1'b0;
                    rob[tail].viq_dispatched  <= 1'b0;
                    rob[tail].instr           <= fetch_instr_i;
                    rob[tail].rd              <= '0;
                    rob[tail].vd              <= '0;
                    rob[tail].vs1             <= '0;
                    rob[tail].vs2             <= '0;
                    rob[tail].result          <= '0;
                    rob[tail].mem_addr        <= '0;
                    rob[tail].mem_data        <= '0;
                    tail             <= tail + PTR_W'(1);
                    rob_de_valid_r   <= 1'b1;
                    rob_de_instr_r   <= fetch_instr_i;
                    rob_de_seq_num_r <= tail;
                end else begin
                    rob_de_valid_r <= 1'b0;
                end

                // STEP 3: DECODE FILL + VIQ DISPATCH
                if (de_valid_i) begin
                    rob[de_seq_num_i].filled          <= 1'b1;
                    rob[de_seq_num_i].is_vector       <= de_is_vector_i;
                    rob[de_seq_num_i].is_scalar_store <= de_scalar_store_i;
                    rob[de_seq_num_i].is_vector_store <= de_vector_store_i;
                    rob[de_seq_num_i].is_mem          <= de_scalar_store_i
                                                       | de_vector_store_i
                                                       | de_scalar_load_i
                                                       | de_vector_load_i;
                    rob[de_seq_num_i].rd              <= de_scalar_rd_addr_i;
                    rob[de_seq_num_i].vd              <= de_vector_vd_addr_i;
                    rob[de_seq_num_i].vs1             <= de_vs1_addr_i;
                    rob[de_seq_num_i].vs2             <= de_vs2_addr_i;

                    // Vector instruction dispatch to VIQ
                    // Tabhi dispatch hoga jab:
                    //   scalar operands ready hain (not in-flight)
                    //   VIQ full nahi
                    //   pehle dispatch nahi hua
                    if (de_is_vector_i && !viq_full_i &&
                        !rs1_in_flight && !rs2_in_flight) begin
                        rob[de_seq_num_i].viq_dispatched <= 1'b1;
                        // viq_dispatch_*_o outputs combinationally
                        // driven hain — VIQ is cycle latch karega
                    end
                    // Agar stall tha: viq_dispatched=0 rahega,
                    // pipeline stalled rahegi, retry next cycle
                end

                // STEP 4: SCALAR WRITEBACK
                if (scalar_done_i) begin
                    rob[scalar_seq_num_i].done      <= 1'b1;
                    rob[scalar_seq_num_i].rd        <= scalar_rd_addr_i;
                    rob[scalar_seq_num_i].result    <= {(`VLEN-`XLEN)'(0),
                                                        scalar_result_i};
                    rob[scalar_seq_num_i].mem_addr  <= scalar_mem_addr_i;
                    rob[scalar_seq_num_i].mem_data  <= {(`VLEN-`XLEN)'(0),
                                                        scalar_mem_data_i};
                end

                // STEP 5: VECTOR WRITEBACK
                if (vector_done_i) begin
                    rob[vector_seq_num_i].done      <= 1'b1;
                    rob[vector_seq_num_i].vd        <= vector_vd_addr_i;
                    rob[vector_seq_num_i].result    <= vector_result_i;
                    //rob[vector_seq_num_i].result <= vector_result_i[`VLEN-1:0];
                    rob[vector_seq_num_i].mem_addr  <= vector_mem_addr_i;
                    rob[vector_seq_num_i].mem_data  <= vector_mem_data_i;
                end

                // STEP 6: COMMIT
                if (do_commit) begin
                    rob[head].valid  <= 1'b0;
                    rob[head].filled <= 1'b0;
                    rob[head].done   <= 1'b0;
                    head  <= head + PTR_W'(1);
                end

                // COUNT — fetch + commit same cycle safe
                case ({do_fetch, do_commit})
                    2'b10:   count <= count + (PTR_W+1)'(1);
                    2'b01:   count <= count - (PTR_W+1)'(1);
                    2'b11:   count <= count;
                    default: count <= count;
                endcase

            end // !flush
        end // rst
    end // always_ff

endmodule