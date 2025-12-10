module tb_carry_save_8;

  // DUT signals
  logic clk;
  logic reset;
  logic start;
  logic [1:0] sew;
  logic signed [15:0] mult_out_1, mult_out_2, mult_out_3, mult_out_4;
  logic signed [15:0] mult_out_5, mult_out_6, mult_out_7, mult_out_8;
  logic signed [31:0] product_1, product_2;

  // Extra variables for testbench
  logic [31:0] A, B;
  logic [7:0]  A_bytes [0:3], B_bytes [0:3];
  logic [15:0] partial_products [0:15];
  logic signed [63:0] expected_sum;

  int i, row, col;

  // Instantiate DUT
  carry_save_8 dut (
    .clk(clk),
    .reset(reset),
    .start(start),
    .sew(sew),
    .mult_out_1(mult_out_1),
    .mult_out_2(mult_out_2),
    .mult_out_3(mult_out_3),
    .mult_out_4(mult_out_4),
    .mult_out_5(mult_out_5),
    .mult_out_6(mult_out_6),
    .mult_out_7(mult_out_7),
    .mult_out_8(mult_out_8),
    .product_1(product_1),
    .product_2(product_2)
  );

  // Clock generator
  always #5 clk = ~clk;

  initial begin
    clk = 0;
    reset = 1;
    start = 0;
    sew = 2'b00;
    {mult_out_1, mult_out_2, mult_out_3, mult_out_4,
     mult_out_5, mult_out_6, mult_out_7, mult_out_8} = 0;
    expected_sum = 0;

    // Example operands
    A = 32'h00000000;
    B = 32'h00000000;

    // Break into 8-bit chunks
    for (i=0; i<4; i++) begin
      A_bytes[i] = A >> (i*8);
      B_bytes[i] = B >> (i*8);
    end

    // Compute all partial products
    partial_products[0]  = A_bytes[0] * B_bytes[0];
    partial_products[1]  = A_bytes[1] * B_bytes[0];
    partial_products[2]  = A_bytes[2] * B_bytes[0];
    partial_products[3]  = A_bytes[3] * B_bytes[0];
    partial_products[4]  = A_bytes[0] * B_bytes[1];
    partial_products[5]  = A_bytes[1] * B_bytes[1];
    partial_products[6]  = A_bytes[2] * B_bytes[1];
    partial_products[7]  = A_bytes[3] * B_bytes[1];
    partial_products[8]  = A_bytes[0] * B_bytes[2];
    partial_products[9]  = A_bytes[1] * B_bytes[2];
    partial_products[10] = A_bytes[2] * B_bytes[2];
    partial_products[11] = A_bytes[3] * B_bytes[2];
    partial_products[12] = A_bytes[0] * B_bytes[3];
    partial_products[13] = A_bytes[1] * B_bytes[3];
    partial_products[14] = A_bytes[2] * B_bytes[3];
    partial_products[15] = A_bytes[3] * B_bytes[3];

    // Release reset
    #12 reset = 0;
    @(posedge clk);
    start = 1;
    sew = 2'b10;

    // === 1st Cycle : Feed first 8 partial products ===
    @(posedge clk);
    mult_out_1 <= partial_products[0];
    mult_out_2 <= partial_products[1];
    mult_out_3 <= partial_products[2];
    mult_out_4 <= partial_products[3];
    mult_out_5 <= partial_products[4];
    mult_out_6 <= partial_products[5];
    mult_out_7 <= partial_products[6];
    mult_out_8 <= partial_products[7];

    for (i = 0; i < 8; i++) begin
      row = i / 4;
      col = i % 4;
      expected_sum += partial_products[i] << ((row + col) * 8);
    end
    $display("Cycle 1 | Feeding PPs[0..7] | Expected so far = %016h", expected_sum);

    // === 2nd Cycle : Feed next 8 partial products ===
    @(posedge clk);
    mult_out_1 <= partial_products[8];
    mult_out_2 <= partial_products[9];
    mult_out_3 <= partial_products[10];
    mult_out_4 <= partial_products[11];
    mult_out_5 <= partial_products[12];
    mult_out_6 <= partial_products[13];
    mult_out_7 <= partial_products[14];
    mult_out_8 <= partial_products[15];

    for (i = 8; i < 16; i++) begin
      row = i / 4;
      col = i % 4;
      expected_sum += partial_products[i] << ((row + col) * 8);
    end
    $display("Cycle 2 | Feeding PPs[8..15] | Expected so far = %016h", expected_sum);

    // Stop feeding
    @(posedge clk);
    start = 0;
    {mult_out_1, mult_out_2, mult_out_3, mult_out_4,
     mult_out_5, mult_out_6, mult_out_7, mult_out_8} = 0;

    // Allow FSM to finish
    repeat(5) @(posedge clk);

    $display("=====================================================");
    $display("FINAL RESULT: Expected = %016h | FSM = %08h_%08h",
              expected_sum, product_2, product_1);
    $display("=====================================================");

    if (expected_sum === {product_2, product_1})
      $display("TEST PASSED");
    else
      $display("TEST FAILED");

    $finish;
  end

endmodule