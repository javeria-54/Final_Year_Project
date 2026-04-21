// ============================================================
//  operand_fwd_hazard
//
//  Ye module D&E stage aur VIQ ke beech baithta hai.
//  Teen kaam karta hai:
//
//  1. RSB Forwarding
//     Agar kisi instruction ka result RSB mein hai lekin
//     abhi commit nahi hua — to woh value seedha yahan se
//     VIQ ko de do. Register file se read karne ki zaroorat
//     nahi.
//
//  2. RAW Stall (src_in_flight)
//     Agar producing instruction abhi bhi execute ho rahi hai
//     (ROB mein hai, RSB mein result nahi aaya yet) — to
//     stall_o high karo. VIQ mein push mat karo abhi.
//
//  3. Scalar Mem Pending (Stall 4)
//     Agar VIQ ke head pe vector LD/ST hai aur koi scalar
//     LD/ST ROB mein unretired hai — to scalar_mem_pending_o
//     high karo. VIQ dispatch gate isko use karega.
//
//  Connections:
//    ROB   → dest_reg[], done[], is_scalar_mem[], valid[]
//    RSB   → dest_reg[], result[], valid[]
//    RegFile → rs1_val_i, rs2_val_i  (already read by D&E)
//    D&E   → rs1_addr_i, rs2_addr_i, instr_is_vecmem_i
//    → VIQ : resolved_rs1_o, resolved_rs2_o
//            stall_o, scalar_mem_pending_o
// ============================================================

module operand_fwd_hazard #(
    parameter OPERAND_W   = 32,
    parameter REG_AW      = 5,       // register address width (e.g. 5 for 32 regs)
    parameter ROB_DEPTH   = 8,
    parameter RSB_DEPTH   = 8
)(
    // ── ROB snapshot (combinational, every cycle) ────────────
    // For each ROB entry:
    //   valid_i      — slot occupied
    //   done_i       — instruction finished executing
    //   is_scalar_mem_i — scalar LD or ST
    //   dest_reg_i   — destination register (0 = no dest)
    input  logic [ROB_DEPTH-1:0]               rob_valid_i,
    input  logic [ROB_DEPTH-1:0]               rob_done_i,
    input  logic [ROB_DEPTH-1:0]               rob_is_scalar_mem_i,
    input  logic [ROB_DEPTH-1:0][REG_AW-1:0]  rob_dest_reg_i,

    // ── RSB snapshot (combinational, every cycle) ────────────
    // Each RSB entry: valid = result is sitting here, not yet committed
    input  logic [RSB_DEPTH-1:0]               rsb_valid_i,
    input  logic [RSB_DEPTH-1:0][REG_AW-1:0]  rsb_dest_reg_i,
    input  logic [RSB_DEPTH-1:0][OPERAND_W-1:0] rsb_result_i,

    // ── Register file values (read by D&E before calling us) ─
    input  logic [OPERAND_W-1:0]               rs1_regfile_i,
    input  logic [OPERAND_W-1:0]               rs2_regfile_i,

    // ── Source register addresses from D&E ───────────────────
    input  logic [REG_AW-1:0]                  rs1_addr_i,
    input  logic [REG_AW-1:0]                  rs2_addr_i,

    // ── Is the incoming instruction a vector mem op? ─────────
    // Used for scalar_mem_pending decision
    input  logic                               instr_is_vecmem_i,

    // ── Resolved operand outputs → VIQ ───────────────────────
    output logic [OPERAND_W-1:0]               resolved_rs1_o,
    output logic [OPERAND_W-1:0]               resolved_rs2_o,

    // ── Stall to scalar pipeline (RAW — src still executing) ─
    output logic                               stall_o,

    // ── Hold signal to VIQ dispatch gate (Stall 4) ───────────
    output logic                               scalar_mem_pending_o
);

    // =========================================================
    //  PART 1 — RSB forwarding + RAW stall check
    //
    //  For each source register:
    //    Step A: Is there an RSB entry with matching dest_reg?
    //            → YES: forward that result (done, not committed)
    //    Step B: Is there a ROB entry with matching dest_reg
    //            that is NOT yet done (still executing)?
    //            → YES: src_in_flight → stall
    //    Step C: No match anywhere → use register file value
    // =========================================================

    logic rs1_in_rsb, rs2_in_rsb;
    logic rs1_in_flight, rs2_in_flight;
    logic [OPERAND_W-1:0] rs1_rsb_val, rs2_rsb_val;

    always_comb begin
        // --- defaults ---
        rs1_in_rsb    = 1'b0;
        rs2_in_rsb    = 1'b0;
        rs1_in_flight = 1'b0;
        rs2_in_flight = 1'b0;
        rs1_rsb_val   = '0;
        rs2_rsb_val   = '0;

        // --- RSB scan ---
        // If multiple entries match (pipeline flush edge case),
        // last match wins — latest result is most up to date.
        for (int i = 0; i < RSB_DEPTH; i++) begin
            if (rsb_valid_i[i]) begin
                // rs1 check
                if ((rs1_addr_i != '0) &&
                    (rsb_dest_reg_i[i] == rs1_addr_i)) begin
                    rs1_in_rsb  = 1'b1;
                    rs1_rsb_val = rsb_result_i[i];
                end
                // rs2 check
                if ((rs2_addr_i != '0) &&
                    (rsb_dest_reg_i[i] == rs2_addr_i)) begin
                    rs2_in_rsb  = 1'b1;
                    rs2_rsb_val = rsb_result_i[i];
                end
            end
        end

        // --- ROB in-flight scan ---
        // in-flight = ROB entry is valid, not done, has a dest reg
        // that matches our source.  Result not in RSB yet → must stall.
        for (int i = 0; i < ROB_DEPTH; i++) begin
            if (rob_valid_i[i] && !rob_done_i[i]) begin
                if ((rs1_addr_i != '0) &&
                    (rob_dest_reg_i[i] == rs1_addr_i))
                    rs1_in_flight = 1'b1;

                if ((rs2_addr_i != '0) &&
                    (rob_dest_reg_i[i] == rs2_addr_i))
                    rs2_in_flight = 1'b1;
            end
        end
    end

    // ── Operand MUX ─────────────────────────────────────────
    // Priority: RSB forward > register file
    // (If in-flight, stall_o will be high and result is don't-care
    //  but we still output something safe.)
    assign resolved_rs1_o = rs1_in_rsb ? rs1_rsb_val : rs1_regfile_i;
    assign resolved_rs2_o = rs2_in_rsb ? rs2_rsb_val : rs2_regfile_i;

    // ── RAW stall ────────────────────────────────────────────
    // Stall if either source is in-flight AND not yet in RSB.
    // If it's in RSB we can forward — no stall needed.
    assign stall_o = (rs1_in_flight && !rs1_in_rsb) ||
                     (rs2_in_flight && !rs2_in_rsb);

    // =========================================================
    //  PART 2 — Scalar mem pending check  (Stall 4)
    //
    //  If the incoming instruction is a vector LD/ST, check
    //  whether any scalar LD/ST is unretired (valid, not done)
    //  in the ROB. If yes, vector mem must not dispatch yet.
    //
    //  VIQ dispatch gate uses this signal every cycle to hold
    //  its head entry when needed.
    // =========================================================

    logic any_scalar_mem_unretired;

    always_comb begin
        any_scalar_mem_unretired = 1'b0;
        for (int i = 0; i < ROB_DEPTH; i++) begin
            if (rob_valid_i[i] &&
                !rob_done_i[i] &&
                rob_is_scalar_mem_i[i])
                any_scalar_mem_unretired = 1'b1;
        end
    end

    // Only assert this signal when the instruction trying to
    // dispatch is actually a vector mem op.
    assign scalar_mem_pending_o = instr_is_vecmem_i &&
                                  any_scalar_mem_unretired;

endmodule