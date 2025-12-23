`include "vector_processor_defs.svh"

module adder8 (
    input  logic signed [7:0] A,
    input  logic signed [7:0] B,
    input  logic              Cin,
    output logic signed [7:0] Sum,
    output logic              Cout
);
    assign {Cout, Sum} = A + B + Cin;
endmodule

// MUX for Sew_32 control
module mux_sew_32 (
    input  logic carry_out,
    input  logic carry_ctrl,
    input  logic sew_32,
    output logic carry_in
);
    assign carry_in = (sew_32 == 1'b0) ? carry_ctrl : carry_out;
endmodule

// MUX for Sew_16_32 control
module mux_sew_16_32 (
    input  logic carry_out,
    input  logic carry_ctrl,
    input  logic sew_16_32,
    output logic carry_in
);
    assign carry_in = (sew_16_32 == 1'b0) ? carry_ctrl : carry_out;
endmodule

// MUX for Ctrl (initial carry select)
module mux_ctr (
    input  logic in0,
    input  logic in1,
    input  logic ctr,
    output logic out
);
    assign out = (ctr == 1'b0) ? in0 : in1;
endmodule

module adder_subtractor_32bit (
    input  logic        Ctrl,          // 0 = Add, 1 = Sub
    input  logic        sew_16_32,     // 1 = 16-bit op, 0 = 8-bit
    input  logic        sew_32,        // 1 = 32-bit op
    input  logic signed [31:0] A,
    input  logic signed [31:0] B,
    output logic signed [31:0] Sum
);

    // Segment input and output
    logic [7:0] A_seg[0:3], B_seg[0:3], B_xor[0:3], Sum_seg[0:3];
    logic [3:0] carry_out;
    logic [3:0] carry_ctrl;     // mux_ctr output
    logic [3:0] selected_carry; // final carry_in to each adder

    genvar i;
    generate
        for (i = 0; i < 4; i++) begin : segment_process

            // Split operands
            assign A_seg[i] = A[i*8 +: 8];
            assign B_seg[i] = B[i*8 +: 8];

            // XOR B with Ctrl for 2's complement (B ^ 0 = B for add, B ^ 1 = ~B for subtract)
            assign B_xor[i] = B_seg[i] ^ {8{Ctrl}};

            // MUX: Select 0 or 1 for carry_ctrl
            mux_ctr ctr_mux (
                .in0(1'b0),
                .in1(1'b1),
                .ctr(Ctrl),
                .out(carry_ctrl[i])
            );

            // MUX: Choose between carry_ctrl or previous carry_out
            if (i == 0) begin
                // First adder gets carry_ctrl directly
                assign selected_carry[i] = carry_ctrl[i];
            end else if (i == 1) begin
                mux_sew_16_32 mux16 (
                    .carry_out(carry_out[i-1]),
                    .carry_ctrl(carry_ctrl[i]),
                    .sew_16_32(sew_16_32),
                    .carry_in(selected_carry[i])
                );
            end else begin
                mux_sew_32 mux32 (
                    .carry_out(carry_out[i-1]),
                    .carry_ctrl(carry_ctrl[i]),
                    .sew_32(sew_32),
                    .carry_in(selected_carry[i])
                );
            end

            // 8-bit adder
            adder8 adder_inst (
                .A    (A_seg[i]),
                .B    (B_xor[i]),
                .Cin  (selected_carry[i]),
                .Sum  (Sum_seg[i]),
                .Cout (carry_out[i])
            );
        end
    endgenerate

    // Final sum packing
    always_comb begin
        case ({sew_32, sew_16_32})
            2'b00: Sum = {Sum_seg[3],Sum_seg[2], Sum_seg[1], Sum_seg[0]};      // 8-bit
            2'b01: Sum = {Sum_seg[3], Sum_seg[2],Sum_seg[1], Sum_seg[0]};      // 16-bit
            2'b11: Sum = {Sum_seg[3], Sum_seg[2], Sum_seg[1], Sum_seg[0]};     // 32-bit
            default: Sum = 32'd0;
        endcase
    end


endmodule

module vector_adder_subtractor (
    input  logic                          Ctrl,          // 0=Add, 1=Sub
    input  logic                          sew_16_32,     // 1 = 16-bit, 0 = 8-bit
    input  logic                          sew_32,        // 1 = 32-bit
    input  logic signed [`VLEN-1:0]   A,
    input  logic signed [`VLEN-1:0]   B,
    output logic signed [`VLEN-1:0]   Sum
);

    localparam NUM_SLICES = (`VLEN / 32);

    genvar i;
    generate
        for (i = 0; i < NUM_SLICES; i++) begin : units
            adder_subtractor_32bit units (
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
