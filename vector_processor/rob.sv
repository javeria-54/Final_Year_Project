`include "vector_processor_defs.svh"
`include "scalar_pcore_interface_defs.svh"

// ============================================================
//  ROB — Reorder Buffer
//  Fixes in this version:
//   1. do_fetch / do_commit → always_comb (blocking assign
//      always_ff se bahar nikala)
//   2. Flush mein filled + done bhi clear hote hain
//   3. Scalar writeback mein rd overwrite hataya
//   4. rs1_in_flight / rs2_in_flight mein filled guard add
//   5. flush_count increment cast fix
//   6. commit_scalar_seq_num_o / commit_vector_seq_num_o
//      is_vector se gate kiye — galat seq num nahi jayega
//   7. viq_dispatch_valid_o mein double guard — scalar VIQ
//      pe nahi jayegi
// ============================================================

module rob (
    input  logic clk,
    input  logic rst_n,

    // --------------------------------------------------------
    // Fetch interface
    // --------------------------------------------------------
    input  logic                            fetch_valid_i,
    input  logic [`XLEN-1:0]               fetch_instr_i,
    output logic                            rob_full_o,

    // --------------------------------------------------------
    // ROB → Decode interface
    // --------------------------------------------------------
    output logic                            rob_de_valid_o,
    output logic [`XLEN-1:0]               rob_de_instr_o,
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
    // --------------------------------------------------------
    input  logic [`XLEN-1:0]               rf2rob_rs1_data_i,
    input  logic [`XLEN-1:0]               rf2rob_rs2_data_i,

    // --------------------------------------------------------
    // Scalar forwarding outputs
    // --------------------------------------------------------
    output logic                            fwd_rs1_hit_o,
    output logic [`XLEN-1:0]               fwd_rs1_val_o,
    output logic                            fwd_rs2_hit_o,
    output logic [`XLEN-1:0]               fwd_rs2_val_o,
    output logic [`XLEN-1:0]               fwd_rs1_data_o,
    output logic [`XLEN-1:0]               fwd_rs2_data_o,

    // --------------------------------------------------------
    // Vector forwarding outputs
    // --------------------------------------------------------
    output logic                            fwd_vs1_hit_o,
    output logic [`VLEN-1:0]               fwd_vs1_val_o,
    output logic                            fwd_vs2_hit_o,
    output logic [`VLEN-1:0]               fwd_vs2_val_o,
    output logic [`VLEN-1:0]               fwd_vs1_data_o,
    output logic [`VLEN-1:0]               fwd_vs2_data_o,

    // --------------------------------------------------------
    // VIQ interface
    // --------------------------------------------------------
    output logic                            viq_dispatch_valid_o,
    output logic [`XLEN-1:0]               viq_dispatch_instr_o,
    output logic [`Tag_Width-1:0]           viq_dispatch_seq_num_o,
    output logic [`VREG_ADDR_W-1:0]         viq_dispatch_vd_o,
    output logic [`VREG_ADDR_W-1:0]         viq_dispatch_vs1_o,
    output logic [`VREG_ADDR_W-1:0]         viq_dispatch_vs2_o,
    output logic [`XLEN-1:0]               viq_dispatch_rs1_data_o,
    output logic [`XLEN-1:0]               viq_dispatch_rs2_data_o,
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
    input  logic [`XLEN-1:0]               scalar_result_i,
    input  logic [`XLEN-1:0]               scalar_mem_addr_i,
    input  logic [`XLEN-1:0]               scalar_mem_data_i,
    output logic [`XLEN-1:0]               scalar_mem_data_o,

    // --------------------------------------------------------
    // Vector execution writeback
    // --------------------------------------------------------
    input  logic                            vector_done_i,
    input  logic [`Tag_Width-1:0]           vector_seq_num_i,
    input  logic [`VREG_ADDR_W-1:0]         vector_vd_addr_i,
    input  logic [`MAX_VLEN-1:0]            vector_result_i,
    input  logic [`XLEN-1:0]               vector_mem_addr_i,
    input  logic [`VLEN-1:0]               vector_mem_data_i,
    output logic [`VLEN-1:0]               vector_mem_data_o,
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
    output logic                            commit_scalar_load_o,
    output logic                            commit_vector_load_o,
    output logic [`REG_ADDR_W-1:0]          commit_rd_o,
    output logic [`VREG_ADDR_W-1:0]         commit_vd_o,
    output logic [`XLEN-1:0]               commit_scalar_result_o,
    output logic [`MAX_VLEN-1:0]            commit_vector_result_o,
    output logic [`XLEN-1:0]               commit_mem_addr_o,
    output logic [`VLEN-1:0]               commit_mem_data_o,
    output logic [`XLEN-1:0]               commit_scalar_mem_data_o,

    // --------------------------------------------------------
    // Flush interface
    // --------------------------------------------------------
    input  logic                            flush_valid_i,
    input  logic [`Tag_Width-1:0]           flush_seq_i
);

    localparam int PTR_W = $clog2(`ROB_DEPTH);

    // --------------------------------------------------------
    // ROB Entry Struct
    // --------------------------------------------------------
    typedef struct packed {
        logic                    valid;
        logic                    filled;
        logic                    done;
        logic                    is_vector;
        logic                    is_scalar_store;
        logic                    is_vector_store;
        logic                    is_scalar_load;
        logic                    is_vector_load;
        logic                    is_mem;
        logic                    viq_dispatched;
        logic [`XLEN-1:0]        instr;
        logic [`REG_ADDR_W-1:0]  rd;
        logic [`VREG_ADDR_W-1:0] vd;
        logic [`VREG_ADDR_W-1:0] vs1;
        logic [`VREG_ADDR_W-1:0] vs2;
        logic [`MAX_VLEN-1:0]    result;
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

    // --------------------------------------------------------
    // FIX 1: do_fetch / do_commit → always_comb
    // Pehle yeh always_ff ke andar blocking assign the —
    // synthesis mein unpredictable tha
    // --------------------------------------------------------
    logic do_fetch;
    logic do_commit;

    always_comb begin
        do_fetch  = fetch_valid_i && !rob_full_o;
        do_commit = commit_valid_o;
    end

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
    // --------------------------------------------------------
    always_comb begin
        fwd_rs1_hit_o = 1'b0;
        fwd_rs1_val_o = '0;
        fwd_rs2_hit_o = 1'b0;
        fwd_rs2_val_o = '0;
        for (int i = 0; i < `ROB_DEPTH; i++) begin
            if (rob[i].valid && rob[i].filled &&
                rob[i].done && !rob[i].is_vector) begin
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

    assign fwd_rs1_data_o = fwd_rs1_hit_o ? fwd_rs1_val_o : rf2rob_rs1_data_i;
    assign fwd_rs2_data_o = fwd_rs2_hit_o ? fwd_rs2_val_o : rf2rob_rs2_data_i;

    // --------------------------------------------------------
    // FIX 5: rs1_in_flight / rs2_in_flight — filled guard add
    // Pehle filled check nahi tha — fetch-only entry bhi
    // in-flight count hoti thi jo galat tha
    // --------------------------------------------------------
    logic rs1_in_flight;
    logic rs2_in_flight;

    always_comb begin
        rs1_in_flight = 1'b0;
        rs2_in_flight = 1'b0;
        for (int i = 0; i < `ROB_DEPTH; i++) begin
            // filled=1 zaroori — sirf decoded entries check karo
            if (rob[i].valid && rob[i].filled &&
                !rob[i].done && !rob[i].is_vector) begin
                if ((rob[i].rd == de_rs1_addr_i) && (de_rs1_addr_i != '0))
                    rs1_in_flight = 1'b1;
                if ((rob[i].rd == de_rs2_addr_i) && (de_rs2_addr_i != '0))
                    rs2_in_flight = 1'b1;
            end
        end
    end

    assign stall_scalar_raw_o = de_valid_i & de_is_vector_i &
                                 (rs1_in_flight | rs2_in_flight);

    // --------------------------------------------------------
    // FIX 7: VIQ Dispatch
    // do_viq_dispatch mein de_is_vector_i pehle se tha —
    // lekin viq_dispatch_valid_o pe bhi extra gate lagaya
    // taake koi edge case scalar ko VIQ pe na bheje
    // --------------------------------------------------------
    logic do_viq_dispatch;

    assign do_viq_dispatch = de_valid_i
                           & de_is_vector_i        // scalar yahan rok jati hai
                           & ~viq_full_i
                           & ~flush_valid_i
                           & ~rs1_in_flight
                           & ~rs2_in_flight
                           & ~rob[de_seq_num_i].viq_dispatched;

    // Extra guard — de_is_vector_i ka double check
    // is se scalar instruction kisi bhi haal mein VIQ nahi jayegi
    always_comb begin 
        if (do_viq_dispatch) begin
            viq_dispatch_valid_o    = do_viq_dispatch & de_is_vector_i;
            viq_dispatch_instr_o    = rob[de_seq_num_i].instr;
            viq_dispatch_seq_num_o  = de_seq_num_i;
            viq_dispatch_vd_o       = de_vector_vd_addr_i;
            viq_dispatch_vs1_o      = de_vs1_addr_i;
            viq_dispatch_vs2_o      = de_vs2_addr_i;
            viq_dispatch_rs1_data_o = fwd_rs1_hit_o ? fwd_rs1_val_o : rf2rob_rs1_data_i;
            viq_dispatch_rs2_data_o = fwd_rs2_hit_o ? fwd_rs2_val_o : rf2rob_rs2_data_i;
            viq_dispatch_is_load_o  = de_vector_load_i;
            viq_dispatch_is_store_o = de_vector_store_i;
            stall_viq_full_o = de_valid_i & de_is_vector_i & viq_full_i;
        end
        else begin
            viq_dispatch_valid_o    = 'b0;
            viq_dispatch_instr_o    = 'b0;
            viq_dispatch_seq_num_o  = 'b0;
            viq_dispatch_vd_o       = 'b0;
            viq_dispatch_vs1_o      = 'b0;
            viq_dispatch_vs2_o      = 'b0;
            viq_dispatch_rs1_data_o = 'b0;
            viq_dispatch_rs2_data_o = 'b0;
            viq_dispatch_is_load_o  = 'b0;
            viq_dispatch_is_store_o = 'b0;
            stall_viq_full_o = 'b0;
        end
    end

    // --------------------------------------------------------
    // Vector Forwarding
    // --------------------------------------------------------
    always_comb begin
        fwd_vs1_hit_o = 1'b0;
        fwd_vs1_val_o = '0;
        fwd_vs2_hit_o = 1'b0;
        fwd_vs2_val_o = '0;
        for (int i = 0; i < `ROB_DEPTH; i++) begin
            if (rob[i].valid && rob[i].filled && rob[i].done) begin
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
                        fwd_vs1_val_o = {(`VLEN-`XLEN)'(0),
                                          rob[i].result[`XLEN-1:0]};
                    end
                    if (`VREG_ADDR_W'(rob[i].rd) == de_vs2_addr_i) begin
                        fwd_vs2_hit_o = 1'b1;
                        fwd_vs2_val_o = {(`VLEN-`XLEN)'(0),
                                          rob[i].result[`XLEN-1:0]};
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
            if (rob[i].valid && rob[i].filled && !rob[i].done) begin
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

    assign commit_valid_o = head_entry.valid &&
                            head_entry.filled &&
                            head_entry.done;

    // --------------------------------------------------------
    // FIX 6: Seq num is_vector se gate kiye
    // Pehle dono same head value de rahe the — is se
    // scalar commit pe vector seq num bhi active hota tha
    // ab sirf sahi wala seq num non-zero hoga
    // --------------------------------------------------------
    assign commit_scalar_seq_num_o = (!head_entry.is_vector && commit_valid_o)
                                      ? (`Tag_Width)'(head) : '0;
    assign commit_vector_seq_num_o = ( head_entry.is_vector && commit_valid_o)
                                      ? (`Tag_Width)'(head) : '0;

    assign commit_is_vector_o    = head_entry.is_vector;
    assign commit_scalar_store_o = head_entry.is_scalar_store;
    assign commit_vector_store_o = head_entry.is_vector_store;
    assign commit_scalar_load_o  = head_entry.is_scalar_load && commit_valid_o;
    assign commit_vector_load_o  = head_entry.is_vector_load && commit_valid_o;

    assign commit_rd_o  = (!head_entry.is_vector && commit_valid_o)
                           ? head_entry.rd : '0;
    assign commit_vd_o  = ( head_entry.is_vector && commit_valid_o)
                           ? head_entry.vd : '0;

    // Scalar result — load + ALU dono yahan se jaate hain
    // scalar RF ko sirf yeh port dekhna chahiye
    assign commit_scalar_result_o = (!head_entry.is_vector && commit_valid_o)
                                     ? head_entry.result[`XLEN-1:0] : '0;

    // Vector result — load + execute dono yahan se jaate hain
    // vector RF ko sirf yeh port dekhna chahiye
    assign commit_vector_result_o = ( head_entry.is_vector && commit_valid_o)
                                     ? head_entry.result : '0;

    // Store ke liye memory address aur data
    assign commit_mem_addr_o        = head_entry.mem_addr;
    assign commit_mem_data_o        = head_entry.is_vector
                                       ? head_entry.mem_data : '0;
    assign commit_scalar_mem_data_o = !head_entry.is_vector
                                       ? head_entry.mem_data[`XLEN-1:0] : '0;

    assign scalar_mem_data_o = head_entry.mem_data[`XLEN-1:0];
    assign vector_mem_data_o = head_entry.mem_data;

    // --------------------------------------------------------
    // FIX 6: Flush Count
    // flush_count increment mein explicit cast add kiya
    // --------------------------------------------------------
    always_comb begin
        flush_dist_comb = flush_seq_i[PTR_W-1:0] - head;
        flush_count     = '0;
        for (int i = 0; i < `ROB_DEPTH; i++) begin
            entry_dist_comb[i] = PTR_W'(i) - head;
            if (rob[i].valid &&
                (entry_dist_comb[i] < flush_dist_comb))
                flush_count = flush_count + (PTR_W+1)'(1);
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
                        (PTR_W'(i) - head >=
                         flush_seq_i[PTR_W-1:0] - head)) begin
                        // FIX 3: valid ke saath filled + done bhi clear karo
                        // Pehle sirf valid clear hoti thi — reuse pe
                        // purani filled/done value residue karti thi
                        rob[i].valid  <= 1'b0;
                        rob[i].filled <= 1'b0;
                        rob[i].done   <= 1'b0;
                    end
                end
                tail           <= flush_seq_i[PTR_W-1:0];
                count          <= flush_count;
                rob_de_valid_r <= 1'b0;

            end else begin

                // STEP 2: FETCH
                if (do_fetch) begin
                    rob[tail].valid           <= 1'b1;
                    rob[tail].filled          <= 1'b0;
                    rob[tail].done            <= 1'b0;
                    rob[tail].is_vector       <= 1'b0;
                    rob[tail].is_scalar_store <= 1'b0;
                    rob[tail].is_vector_store <= 1'b0;
                    rob[tail].is_scalar_load  <= 1'b0;
                    rob[tail].is_vector_load  <= 1'b0;
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
                    rob[de_seq_num_i].is_scalar_load  <= de_scalar_load_i;
                    rob[de_seq_num_i].is_vector_load  <= de_vector_load_i;
                    rob[de_seq_num_i].is_mem          <= de_scalar_store_i
                                                       | de_vector_store_i
                                                       | de_scalar_load_i
                                                       | de_vector_load_i;
                    rob[de_seq_num_i].rd              <= de_scalar_rd_addr_i;
                    rob[de_seq_num_i].vd              <= de_vector_vd_addr_i;
                    rob[de_seq_num_i].vs1             <= de_vs1_addr_i;
                    rob[de_seq_num_i].vs2             <= de_vs2_addr_i;

                    // VIQ dispatch sirf vector ke liye
                    if (de_is_vector_i && !viq_full_i &&
                        !rs1_in_flight && !rs2_in_flight) begin
                        rob[de_seq_num_i].viq_dispatched <= 1'b1;
                    end
                end

                // STEP 4: SCALAR WRITEBACK
                // FIX 4: rd yahan overwrite nahi hoga
                // rd decode pe final ho chuka — result sirf writeback pe aata hai
                // Load case:  scalar_result_i = mem data (LSU ne diya)
                // ALU case:   scalar_result_i = execute result
                // Dono same path — result field mein store hota hai
                if (scalar_done_i) begin
                    rob[scalar_seq_num_i].done     <= 1'b1;
                    // rd yahan nahi likhte — decode pe already sahi hai
                    rob[scalar_seq_num_i].result   <= {(`VLEN-`XLEN)'(0),
                                                        scalar_result_i};
                    rob[scalar_seq_num_i].mem_addr <= scalar_mem_addr_i;
                    rob[scalar_seq_num_i].mem_data <= {(`VLEN-`XLEN)'(0),
                                                        scalar_mem_data_i};
                end

                // STEP 5: VECTOR WRITEBACK
                // Load case:    vector_result_i = mem data
                // Execute case: vector_result_i = ALU result
                if (vector_done_i) begin
                    rob[vector_seq_num_i].done     <= 1'b1;
                    rob[vector_seq_num_i].vd       <= vector_vd_addr_i;
                    rob[vector_seq_num_i].result   <= vector_result_i;
                    rob[vector_seq_num_i].mem_addr <= vector_mem_addr_i;
                    rob[vector_seq_num_i].mem_data <= vector_mem_data_i;
                end

                // STEP 6: COMMIT
                if (do_commit) begin
                    rob[head].valid  <= 1'b0;
                    rob[head].filled <= 1'b0;
                    rob[head].done   <= 1'b0;
                    head <= head + PTR_W'(1);
                end

                // COUNT update
                // fetch + commit same cycle → count same rehti hai
                case ({do_fetch, do_commit})
                    2'b10:   count <= count + (PTR_W+1)'(1);
                    2'b01:   count <= count - (PTR_W+1)'(1);
                    2'b11:   count <= count;
                    default: count <= count;
                endcase

            end // !flush
        end // rst_n
    end // always_ff

endmodule