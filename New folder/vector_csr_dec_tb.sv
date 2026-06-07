module tb_vec_csr_dec #(
     XLEN = 32,
    VLMAX = 16
)();

logic               clk;
logic               n_rst;

// testbench -> vector_extension
logic [XLEN-1:0]    vec_inst;
logic [XLEN-1:0]    rs1_data;
logic [XLEN-1:0]    rs2_data;

// vec-csr-dec -> vec-regfile
logic [4:0]      vec_read_addr_1;
logic [4:0]      vec_read_addr_2;
logic [4:0]      vec_write_addr;
logic [4:0]      vec_imm;
logic            vec_mask;

// vec-csr-dec -> vec-csr / vec-regfile
logic [XLEN-1:0] scalar1;
logic [XLEN-1:0] scalar2;

// vec-csr-dec -> scalar-processor
logic [XLEN-1:0] csr_out;

// vec_decode -> vector load
logic [2:0]      width;
logic            mew;
logic [2:0]      nf;

// vec-csr-dec -> vector-processor
logic [3:0]      vlmul;
logic [5:0]      sew;
logic            tail_agnostic;    // vector tail agnostic 
logic            mask_agnostic;    // vector mask agnostic
logic [XLEN-1:0] vec_length;
logic [XLEN-1:0] start_element;

// vector_extension -> testbench
logic               is_vec_inst;

vec_csr_dec DUT (
    .clk                (clk),
    .n_rst              (n_rst),

    .vec_inst           (vec_inst),
    .rs1_data           (rs1_data),
    .rs2_data           (rs2_data),

    .vec_read_addr_1    (vec_read_addr_1),
    .vec_read_addr_2    (vec_read_addr_2),
    .vec_write_addr     (vec_write_addr),
    .vec_imm            (vec_imm),
    .vec_mask           (vec_mask),

    .scalar1            (scalar1),
    .scalar2            (scalar2),

    .csr_out            (csr_out),

    .width              (width),
    .mew                (mew),
    .nf                 (nf),

    .vlmul              (vlmul),
    .sew                (sew),
    .tail_agnostic      (tail_agnostic),
    .mask_agnostic      (mask_agnostic),
    .vec_length         (vec_length),
    .start_element      (start_element),

    .is_vec_inst        (is_vec_inst)
);

initial begin
        clk = 1;
    forever begin
        clk = #20 ~clk;
    end
end

initial begin
    init_signals;
    reset_sequence;

    // vl=VLMAX , sew = 32, lmul = 1, conf=vsetvli 
    vec_inst <= 32'h01007057;
    rs1_data <= 32'h0000000f;
    rs2_data <= 32'h00001200;
    @(posedge clk);

    // vl=uimm; uimm =  , sew = 32, lmul = 1, conf=vsetivli
    vec_inst <= 32'hc1087157;
    @(posedge clk);

    // vl=rs1 , sew = 32, lmul = 1, conf=vetvl
    rs2_data <= 32'h00000010;
    vec_inst <= 32'h8030f157;
    @(posedge clk);

    // load-instruction
    rs1_data <= 32'hDEADBEAF;
    // nf = 000, mew = 0, mop = 00, vm = 1, lumop = 00000, rs1_addr = 2, width = 6, vd = 2
    vec_inst <= 32'h02016107;
    repeat(2) @(posedge clk);
    $stop;
end

task init_signals;
    rs1_data <= '0; rs2_data <= '0;
    vec_inst <= '0; n_rst    <=  1;
endtask

task reset_sequence;
    @(posedge clk);
    n_rst <= '0;
    @(posedge clk);
    n_rst <=  1;
endtask


endmodule