module adder_subtractor #(
    parameter WIDTH = 512  // Must be multiple of 32
)(
    input  logic              Ctrl,          // 0=Add, 1=Sub
    input  logic              sew_16_32,     // 1 = 16-bit, 0 = 8-bit
    input  logic              sew_32,        // 1 = 32-bit
    input  logic signed [WIDTH-1:0]  A,
    input  logic signed [WIDTH-1:0]  B,
    output logic signed [WIDTH-1:0]  Sum
);

    localparam NUM_SLICES = WIDTH / 32;

    genvar i;
    generate
        for (i = 0; i < NUM_SLICES; i++) begin : slice
            adder_subtractor_32bit u_slice (
                .Ctrl      (Ctrl),
                .sew_16_32 (sew_16_32),
                .sew_32    (sew_32),
                .A         (A[i*32 +: 32]),
                .B         (B[i*32 +: 32]),
                .Sum       (Sum[i*32 +: 32])
            );
        end
    endgenerate

endmodule

