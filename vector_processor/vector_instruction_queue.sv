module viq #(
    parameter DEPTH        = 8,
    parameter SEQ_W        = 8,
    parameter INSTR_W      = 32,
    parameter OPERAND_W    = 32,
    parameter ENTRY_W      = SEQ_W + INSTR_W + OPERAND_W + OPERAND_W + 1
)(
    input  logic                clk,
    input  logic                reset,          

    input  logic                vector_instr_valid,
    input  logic [SEQ_W-1:0]    instr_seq_i,
    input  logic [INSTR_W-1:0]  instruction_i,
    input  logic [OPERAND_W-1:0]operand_rs1_i,
    input  logic [OPERAND_W-1:0]operand_rs2_i,
    input  logic                instr_is_vecmem_i,

    output logic                stall_vec,      

    input  logic                deq_ready,      
    output logic                deq_valid,      
    output logic [SEQ_W-1:0]    instr_seq_o,
    output logic [INSTR_W-1:0]  instruction_o,
    output logic [OPERAND_W-1:0]operand_rs1_o,
    output logic [OPERAND_W-1:0]operand_rs2_o,
    output logic                instr_is_vecmem_o,

    output logic [$clog2(DEPTH):0] num_instr
);

    localparam PTR_W = $clog2(DEPTH);

    logic [ENTRY_W-1:0] fifo [0:DEPTH-1];
    logic [PTR_W:0] write_ptr;
    logic [PTR_W:0] read_ptr;

    logic [PTR_W-1:0] write_idx;
    logic [PTR_W-1:0] read_idx;

    assign write_idx = write_ptr[PTR_W-1:0];
    assign read_idx = read_ptr[PTR_W-1:0];

    logic full, empty;

    assign full  = (write_ptr[PTR_W] != read_ptr[PTR_W]) &&
                   (write_ptr[PTR_W-1:0] == read_ptr[PTR_W-1:0]);
    assign empty = (write_ptr == read_ptr);

    logic do_enq, do_deq;

    assign do_enq = vector_instr_valid && !full;
    assign do_deq = deq_ready && !empty;
    assign deq_valid = !empty;

    assign stall_vec = full;

    always_ff @(posedge clk) begin
        if (reset) begin
            read_ptr <= '0;
            write_ptr <= '0;
            instr_seq_o <= '0;
            instruction_o <= '0;
            operand_rs2_o <= '0;
            operand_rs1_o <= '0;
            instr_is_vecmem_o <='0;
        end 
        if (do_enq) begin
            fifo[read_idx] <= { instr_seq_i,
                                instruction_i,
                                operand_rs2_i,
                                operand_rs1_i,
                                instr_is_vecmem_i };
            read_ptr <= read_ptr + 1'b1;
        end
        if (do_deq) begin
            {   instr_seq_o,
                instruction_o,
                operand_rs2_o,
                operand_rs1_o,
                instr_is_vecmem_o } <= fifo[write_idx]  ;
            write_ptr <= write_ptr + 1'b1;
        end
    end

    assign num_instr = read_ptr - write_ptr;

endmodule