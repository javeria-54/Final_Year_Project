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

