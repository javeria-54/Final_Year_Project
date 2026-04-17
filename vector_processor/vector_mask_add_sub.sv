`include "vector_processor_defs.svh"
`include "vector_execution_unit.svh"

module vector_mask_add_sub (
    input  logic [`VLEN-1:0]  adder_data_1,
    input  logic [`VLEN-1:0]  adder_data_2,
    input  logic [511:0]      mask_reg,
    input  logic              Ctrl,       
    input  logic              sew_16_32,
    input  logic              sew_32,
    input  logic [1:0]        sew, 
    output logic [63:0]       carry_out,       
    output logic [`VLEN-1:0]  sum_mask_result,
    output logic              sum_mask_done
);

    logic [`VLEN-1:0] sum_result;
    logic             sum_done_internal;
    logic [`VLEN-1:0] mask_extended;
    logic [63:0]      carry_out_unused;  // ← mask adder ka carry, use nahi hoga

    always_comb begin
        mask_extended = '0;
        
        if (!sew_32 && !sew_16_32) begin        // SEW=8
            for (int i = 0; i < `NUM_ELEMENT_SEW8; i++)
                mask_extended[i*8 +: 8] = {{7{1'b0}}, mask_reg[i]};
        end
        else if (!sew_32 && sew_16_32) begin    // SEW=16
            for (int i = 0; i < `NUM_ELEMENT_SEW16; i++)
                mask_extended[i*16 +: 16] = {{15{1'b0}}, mask_reg[i]};
        end
        else begin                              // SEW=32
            for (int i = 0; i < `NUM_ELEMENT_SEW32; i++)
                mask_extended[i*32 +: 32] = {{31{1'b0}}, mask_reg[i]};
        end
    end

    // First adder: vs2 +/- vs1  →  carry_out yahan se aata hai
    vector_adder_subtractor adder_inst (
        .A        (adder_data_1),
        .B        (adder_data_2),
        .Ctrl     (Ctrl),
        .sew_16_32(sew_16_32),
        .sew_32   (sew_32),
        .Sum      (sum_result),
        .carry_out(carry_out_unused),          // ← module output yahan connect
        .sum_done (sum_done_internal)
    );

    // Second adder: (vs2 +/- vs1) + mask  →  carry yahan discard hoga
    vector_adder_subtractor adder_mask (
        .A        (sum_result),
        .B        (mask_extended),
        .Ctrl     (Ctrl),
        .sew_16_32(sew_16_32),
        .sew_32   (sew_32),
        .carry_out(carry_out),  // ← alag wire, conflict nahi
        .Sum      (sum_mask_result),
        .sum_done (sum_mask_done)
    );

endmodule