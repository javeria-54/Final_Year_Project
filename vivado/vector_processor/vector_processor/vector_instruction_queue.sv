

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

    input  logic                        deq_ready,     
    output logic                        deq_valid,      
    output logic [`Tag_Width-1:0]       instr_seq_o,
    output logic [`INSTR_W-1:0]         instruction_o,
    output logic [`OPERAND_W-1:0]       operand_rs1_o,
    output logic [`OPERAND_W-1:0]       operand_rs2_o,
    output logic                        instr_is_vec_o, do_deq,

   // output logic                        stall_vec,     
    output logic                        viq_full,
    output logic [$clog2(`VIQ_DEPTH):0]   num_instr
);

    localparam PTR_W = $clog2(`VIQ_DEPTH);
    logic [`ENTRY_W-1:0]  fifo [0:`VIQ_DEPTH-1];
    logic [PTR_W:0]  write_ptr;
    logic [PTR_W:0]  read_ptr;

    logic [PTR_W-1:0] write_idx;
    logic [PTR_W-1:0] read_idx;

    assign write_idx = write_ptr[PTR_W-1:0];
    assign read_idx  = read_ptr [PTR_W-1:0];
  
    logic full, empty;
    assign full  = (write_ptr[PTR_W]     != read_ptr[PTR_W]) &&
                   (write_ptr[PTR_W-1:0] == read_ptr[PTR_W-1:0]);
    assign empty = (write_ptr == read_ptr);

    logic [`Tag_Width-1:0] last_enqueued_seq;
    logic seq_is_new;

    assign seq_is_new = (instr_seq_i != last_enqueued_seq);
 
    logic do_enq;

    assign do_enq = vector_instr_valid && !full && seq_is_new;

    assign do_deq = deq_ready && !empty;

    assign deq_valid = !empty;
   // assign stall_vec = full;
    assign viq_full  = full;
    assign num_instr = write_ptr - read_ptr;   
    always_comb begin
        if (!empty && do_deq) begin
            {instr_seq_o,
             instruction_o,
             operand_rs2_o,
             operand_rs1_o,
             instr_is_vec_o} = fifo[read_idx];
        end 
        else begin
            instr_seq_o = 'b0;
            instruction_o = 'b0;
            operand_rs1_o = 'b0;
            operand_rs2_o = 'b0;
            instr_is_vec_o = 'b0;
        end
    end
    always_ff @(posedge clk) begin
        if (!reset) begin
            write_ptr         <= '0;
            read_ptr          <= '0;
            last_enqueued_seq <= '0;
            for (int i = 0; i < `VIQ_DEPTH; i++) begin
                fifo[i] = '0;
            end

        end else begin
            if (do_enq) begin
                fifo[write_idx] <= {instr_seq_i,
                                    instruction_i,
                                    operand_rs2_i,
                                    operand_rs1_i,
                                    instr_is_vec_i};
                write_ptr         <= write_ptr + 1'b1;
                last_enqueued_seq <= instr_seq_i;   
            end
            if (do_deq) begin
                read_ptr <= read_ptr + 1'b1;
            end

        end
    end

    

endmodule