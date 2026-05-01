`include "vector_processor_defs.svh"

module viq (
    input  logic                        clk,
    input  logic                        reset,

    input  logic                        vector_instr_valid,
    input  logic [`Tag_Width-1:0]       instr_seq_i,
    input  logic [`INSTR_W-1:0]         instruction_i,
    input  logic [`OPERAND_W-1:0]       operand_rs1_i,
    input  logic [`OPERAND_W-1:0]       operand_rs2_i,
    input  logic                        instr_is_vec_i,

    output logic                        stall_vec,
    output logic                        viq_full,

    input  logic                        deq_ready,
    output logic                        deq_valid,
    output logic [`Tag_Width-1:0]       instr_seq_o,
    output logic [`INSTR_W-1:0]         instruction_o,
    output logic [`OPERAND_W-1:0]       operand_rs1_o,
    output logic [`OPERAND_W-1:0]       operand_rs2_o,
    output logic                        instr_is_vec_o,//instr_is_vecmem_o,

    output logic [`VIQ_tag_width-1:0]   num_instr
);

    localparam PTR_W = $clog2(`VIQ_DEPTH);

    // --------------------------------------------------------
    // FIFO storage
    // --------------------------------------------------------
    logic [`ENTRY_W-1:0]  fifo [0:`VIQ_DEPTH-1];
    logic [PTR_W:0]       write_ptr;
    logic [PTR_W:0]       read_ptr;

    logic [PTR_W-1:0]     write_idx;
    logic [PTR_W-1:0]     read_idx;

    assign write_idx = write_ptr[PTR_W-1:0];
    assign read_idx  = read_ptr [PTR_W-1:0];

    // --------------------------------------------------------
    // Full / Empty flags
    // --------------------------------------------------------
    logic full, empty;

    assign full  = (write_ptr[PTR_W]     != read_ptr[PTR_W]) &&
                   (write_ptr[PTR_W-1:0] == read_ptr[PTR_W-1:0]);
    assign empty = (write_ptr == read_ptr);

    // --------------------------------------------------------
    // Enqueue / Dequeue control
    // --------------------------------------------------------
    logic do_enq, do_deq;

    assign do_enq    = vector_instr_valid && !full;
    assign do_deq    = deq_ready && !empty;
    assign deq_valid = !empty;
    assign stall_vec = full;
    assign viq_full  = full;
    assign num_instr = write_ptr - read_ptr;

    // --------------------------------------------------------
    // Combinational output: only drive when not empty
    // --------------------------------------------------------
    always_comb begin
        if (!empty) begin
            {instr_seq_o,
             instruction_o,
             operand_rs2_o,
             operand_rs1_o,
             instr_is_vec_o} = fifo[read_idx];
        end else begin
            instr_seq_o       = '0;
            instruction_o     = '0;
            operand_rs1_o     = '0;
            operand_rs2_o     = '0;
            instr_is_vec_o = 1'b0;
        end
    end

    // --------------------------------------------------------
    // Sequential logic — enqueue and dequeue
    // FIXED: removed initial block; reset now clears everything
    // here in always_ff, so each signal has exactly one driver.
    // --------------------------------------------------------
    always_ff @(posedge clk) begin
        if (!reset) begin
            write_ptr <= '0;
            read_ptr  <= '0;
            // Clear FIFO contents on reset to avoid X propagation
            for (int i = 0; i < `VIQ_DEPTH; i++)
                fifo[i] <= '0;
        end else begin
            if (do_enq) begin
                fifo[write_idx] <= { instr_seq_i,
                                     instruction_i,
                                     operand_rs2_i,
                                     operand_rs1_i,
                                     instr_is_vec_i };
                write_ptr <= write_ptr + 1'b1;
            end

            if (do_deq) begin
                read_ptr <= read_ptr + 1'b1;
            end
        end
    end

endmodule