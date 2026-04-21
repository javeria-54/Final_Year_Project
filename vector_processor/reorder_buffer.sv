// =============================================================================
// rob.sv — Reorder Buffer (ROB)
// Scalar 3-Stage Pipeline + Multi-Cycle Vector Co-Processor
// =============================================================================
//
// OVERVIEW
// --------
// This module is the central ordering and hazard control unit of a processor
// that runs a 3-stage scalar pipeline (Fetch → Decode&Execute → Writeback)
// alongside a multi-cycle, non-pipelined vector co-processor.
//
// The scalar pipeline executes instructions in order. The vector co-processor
// runs concurrently with the scalar side and takes multiple cycles per
// instruction. This creates out-of-order completion — a vector instruction
// issued early may finish after several scalar instructions that were issued
// later. The ROB exists to restore in-order commit despite this.
//
// SCALAR AND VECTOR REGISTER FILES ARE SEPARATE.
// Data moves between the two domains only through shared memory (LD/ST).
// This means the only cross-domain hazard is a memory hazard.
//
// RESULTS DO NOT LIVE IN THE ROB.
// The ROB is purely a state-tracking and ordering structure. Actual result
// values are held in two separate Result Store Buffers (RSBs):
//   Scalar RSB — 32-bit results, indexed by seq#, also holds dest_reg
//   Vector RSB — 512-bit results, indexed by seq#, also holds dest_reg
// At commit time, the external register file reads the appropriate RSB
// using the commit_seq_num_o output as a lookup key.
//
// -----------------------------------------------------------------------------
// WHAT THE ROB DOES — PHASE BY PHASE
// -----------------------------------------------------------------------------
//
// PHASE 1 — PLACEHOLDER ALLOCATION (Fetch stage)
//   Every fetched instruction immediately gets a slot in the ROB and is
//   assigned a sequence number (seq#) equal to its tail index. At this point
//   only valid is set — the instruction has not been decoded yet so all
//   semantic fields (is_vector, is_mem, is_store) are left blank.
//   If the ROB is full, rob_full_o is asserted and Fetch must stall.
//
// PHASE 2 — ENTRY FILL (Decode & Execute stage)
//   One cycle later the instruction reaches D&E and is fully decoded.
//   The seq# assigned at Fetch travels in the Fetch→D&E pipeline register
//   and is used to locate the correct placeholder. D&E fills in is_vector,
//   is_mem, and is_store. All stall decisions run at this stage because
//   this is the first cycle where the instruction type is known.
//
// PHASE 3A — SCALAR COMPLETION
//   Scalar instructions complete in the D&E stage. On completion the scalar
//   unit writes its result and dest_reg to the Scalar RSB (outside this
//   module). It also sends scalar_done_i and scalar_seq_num_i to the ROB
//   so the ROB can mark that entry done. The ROB does not see the result.
//
// PHASE 3B — VECTOR COMPLETION
//   The vector unit finishes after multiple cycles and asserts vec_done_i
//   along with vec_seq_num_i. The result goes to the Vector RSB. The ROB
//   marks that entry done. This is the explicit feedback path from the
//   vector unit back to the ROB — without it the ROB would never know
//   the vector instruction has finished.
//
// PHASE 4 — IN-ORDER COMMIT (ROB head monitor, runs every cycle)
//   The ROB head pointer always points to the oldest uncommitted instruction.
//   Every cycle:
//     - If the head entry is valid, filled, and done → commit_valid_o is
//       asserted. External logic reads the result from the correct RSB using
//       commit_seq_num_o. The head entry is cleared and head advances.
//     - If the head entry is not done → commit stalls. Nothing behind the
//       head commits even if those results are already in the RSB. This
//       is the in-order commit guarantee.
//
// -----------------------------------------------------------------------------
// HAZARD HANDLING — ALL CASES
// -----------------------------------------------------------------------------
//
// STALL 1 — ROB FULL
//   rob_full_o asserted → Fetch stalls.
//
// STALL 2 — VIQ FULL (handled outside this module)
//   If the VIQ is full and a vector instruction reaches D&E, the scalar
//   pipeline stalls. This is signaled by the VIQ module, not the ROB.
//
// STALL 3 — MEMORY HAZARD: scalar LD/ST blocked by vector LD/ST (Rule M1)
//   If a scalar LD/ST is at D&E and any unretired vector LD/ST exists in
//   the ROB, stall_scalar_mem_o is asserted. D&E qualifies this with its
//   own de_is_mem_i flag before stalling the scalar pipeline.
//
// STALL 4 — MEMORY HAZARD: vector LD/ST blocked by scalar LD/ST (Rule M2)
//   If a vector LD/ST is at the VIQ head and any unretired scalar LD/ST
//   exists in the ROB, stall_vec_mem_dispatch_o is asserted. The VIQ
//   qualifies this with the vector instruction's is_mem flag before holding.
//
// STALL 5 — VECTOR RAW HAZARD: vector instr blocked by unretired vector result
//   If any valid Vector RSB entry's dest_reg matches either source register
//   of the vector instruction at the VIQ head, stall_vec_raw_o is asserted.
//   The vector instruction waits until the producing instruction commits and
//   the vector register file is updated. No forwarding on the vector side.
//
// FORWARDING — SCALAR RAW HAZARD (forwarding, not stall)
//   If a scalar instruction at D&E needs a source register whose up-to-date
//   value is sitting in the Scalar RSB (produced but not yet committed),
//   the ROB scans the Scalar RSB and forwards the value directly to D&E.
//   D&E muxes the forwarded value instead of the register file value.
//   If multiple RSB entries match the same register, the most recently
//   written one wins (last-match-wins scan from index 0 to ROB_DEPTH-1,
//   since higher indices toward tail are more recent).
//
// -----------------------------------------------------------------------------
// PARAMETERS
//   ROB_DEPTH   — number of ROB entries (power of 2 recommended)
//   REG_ADDR_W  — width of scalar register address
//   VREG_ADDR_W — width of vector register address
// -----------------------------------------------------------------------------

module rob #(
    parameter int ROB_DEPTH   = 8,
    parameter int REG_ADDR_W  = 5,
    parameter int VREG_ADDR_W = 5
)(
    input  logic clk,
    input  logic rst_n,                                      // active-low synchronous reset

    // -------------------------------------------------------------------------
    // FETCH INTERFACE
    // -------------------------------------------------------------------------
    input  logic        fetch_valid_i,                       // fetch is presenting a new instruction
    output logic        rob_full_o,                          // ROB full — stall Fetch
    output logic [$clog2(ROB_DEPTH)-1:0] seq_num_o,         // seq# assigned to fetched instruction

    // -------------------------------------------------------------------------
    // DECODE & EXECUTE INTERFACE
    // The seq# from Fetch travels in the Fetch→D&E pipeline register.
    // D&E uses it to fill the corresponding ROB placeholder.
    // -------------------------------------------------------------------------
    input  logic        de_valid_i,                          // D&E has a decoded instruction
    input  logic [$clog2(ROB_DEPTH)-1:0] de_seq_num_i,      // which ROB entry to fill
    input  logic        de_is_vector_i,                      // instruction targets vector co-processor
    input  logic        de_is_mem_i,                         // instruction is LD or ST
    input  logic        de_is_store_i,                       // instruction is specifically a store

    // -------------------------------------------------------------------------
    // SCALAR RAW FORWARDING INTERFACE
    // D&E presents source register indices of the current scalar instruction.
    // ROB scans the Scalar RSB and returns forwarded values if available.
    // -------------------------------------------------------------------------
    input  logic [REG_ADDR_W-1:0]  de_src1_reg_i,           // source register 1 of instr at D&E
    input  logic [REG_ADDR_W-1:0]  de_src2_reg_i,           // source register 2 of instr at D&E

    output logic        fwd_src1_hit_o,                      // src1 matched an RSB entry — use forwarded value
    output logic [31:0] fwd_src1_val_o,                      // forwarded value for src1
    output logic        fwd_src2_hit_o,                      // src2 matched an RSB entry — use forwarded value
    output logic [31:0] fwd_src2_val_o,                      // forwarded value for src2

    // -------------------------------------------------------------------------
    // SCALAR RSB READ PORTS (for forwarding scan)
    // The Scalar RSB exposes all its entries so the ROB can scan them
    // combinationally every cycle for forwarding matches.
    // -------------------------------------------------------------------------
    input  logic                         srsb_valid_i    [ROB_DEPTH], // entry occupied
    input  logic [$clog2(ROB_DEPTH)-1:0] srsb_seq_i      [ROB_DEPTH], // seq# of entry
    input  logic [REG_ADDR_W-1:0]        srsb_dest_reg_i [ROB_DEPTH], // destination register
    input  logic [31:0]                  srsb_result_i   [ROB_DEPTH], // result value

    // -------------------------------------------------------------------------
    // VECTOR RSB READ PORTS (for vector RAW stall check)
    // The Vector RSB exposes dest_reg of all entries so the ROB can check
    // for RAW conflicts with the instruction at the VIQ head.
    // -------------------------------------------------------------------------
    input  logic                         vrsb_valid_i    [ROB_DEPTH], // entry occupied
    input  logic [VREG_ADDR_W-1:0]       vrsb_dest_reg_i [ROB_DEPTH], // destination vector register

    // -------------------------------------------------------------------------
    // VECTOR RAW STALL INTERFACE
    // VIQ presents source vector registers of the instruction at its head.
    // ROB checks the Vector RSB for unretired producers.
    // -------------------------------------------------------------------------
    input  logic [VREG_ADDR_W-1:0] viq_src1_reg_i,          // source vreg 1 of instr at VIQ head
    input  logic [VREG_ADDR_W-1:0] viq_src2_reg_i,          // source vreg 2 of instr at VIQ head
    output logic        stall_vec_raw_o,                     // hold VIQ — vector RAW hazard

    // -------------------------------------------------------------------------
    // SCALAR COMPLETION INTERFACE
    // Scalar unit signals done after execution. Result goes to Scalar RSB.
    // ROB only receives done + seq# to mark the entry.
    // -------------------------------------------------------------------------
    input  logic        scalar_done_i,
    input  logic [$clog2(ROB_DEPTH)-1:0] scalar_seq_num_i,

    // -------------------------------------------------------------------------
    // VECTOR COMPLETION INTERFACE
    // Vector unit signals done after multi-cycle execution. Result goes to
    // Vector RSB. ROB only receives done + seq# to mark the entry.
    // -------------------------------------------------------------------------
    input  logic        vec_done_i,
    input  logic [$clog2(ROB_DEPTH)-1:0] vec_seq_num_i,

    // -------------------------------------------------------------------------
    // MEMORY HAZARD STALL OUTPUTS
    // -------------------------------------------------------------------------
    output logic        stall_scalar_mem_o,                  // stall scalar LD/ST at D&E
    output logic        stall_vec_mem_dispatch_o,            // hold vector LD/ST at VIQ head

    // -------------------------------------------------------------------------
    // COMMIT INTERFACE
    // On commit the ROB outputs the seq# and instruction type.
    // External logic (register file, RSB) uses seq# to find the result.
    // -------------------------------------------------------------------------
    output logic        commit_valid_o,                      // a commit is happening this cycle
    output logic [$clog2(ROB_DEPTH)-1:0] commit_seq_num_o,  // seq# being committed
    output logic        commit_is_vector_o,                  // committed instruction is from vector side
    output logic        commit_is_store_o                    // committed instruction is a store
);

    // =========================================================================
    // LOCAL PARAMETERS AND TYPES
    // =========================================================================

    localparam int PTR_W = $clog2(ROB_DEPTH);

    // ROB entry — minimal by design.
    // No result field  : results live in Scalar RSB / Vector RSB.
    // No dest_reg field: dest_reg lives in the RSBs alongside the result.
    typedef struct packed {
        logic valid;      // slot is occupied by a fetched instruction
        logic filled;     // D&E has written decoded details into this entry
        logic done;       // execution complete — result is in the RSB
        logic is_vector;  // instruction belongs to the vector co-processor
        logic is_mem;     // instruction is a load or store
        logic is_store;   // instruction is specifically a store
    } rob_entry_t;

    // =========================================================================
    // ROB STORAGE AND POINTERS
    // =========================================================================

    rob_entry_t rob [ROB_DEPTH];

    logic [PTR_W-1:0] head;    // oldest uncommitted instruction
    logic [PTR_W-1:0] tail;    // next free slot
    logic [PTR_W:0]   count;   // number of occupied entries (extra bit avoids full/empty ambiguity)

    // =========================================================================
    // ROB FULL / SEQ# OUTPUT
    // =========================================================================

    assign rob_full_o = (count == (PTR_W+1)'(ROB_DEPTH));
    assign seq_num_o  = tail;   // seq# is the tail index, output combinationally

    // =========================================================================
    // MEMORY HAZARD DETECTION — combinational scan of all ROB entries
    // =========================================================================

    logic any_unretired_vec_mem;     // unretired vector LD/ST exists in ROB
    logic any_unretired_scalar_mem;  // unretired scalar LD/ST exists in ROB

    always_comb begin
        any_unretired_vec_mem    = 1'b0;
        any_unretired_scalar_mem = 1'b0;

        for (int i = 0; i < ROB_DEPTH; i++) begin
            // Only examine entries whose type is known (filled = 1).
            // Placeholder entries (filled = 0) have unknown type and must
            // not influence hazard decisions — they could be anything.
            if (rob[i].valid && rob[i].filled) begin

                if ( rob[i].is_vector && rob[i].is_mem)
                    any_unretired_vec_mem    = 1'b1;

                if (!rob[i].is_vector && rob[i].is_mem)
                    any_unretired_scalar_mem = 1'b1;

            end
        end
    end

    // Rule M1: asserted when scalar LD/ST at D&E would race a vector LD/ST.
    // D&E must qualify this with de_is_mem_i before stalling.
    assign stall_scalar_mem_o = any_unretired_vec_mem;

    // Rule M2: asserted when vector LD/ST at VIQ head would race a scalar LD/ST.
    // VIQ dispatch must qualify this with the vector instruction's is_mem flag.
    assign stall_vec_mem_dispatch_o = any_unretired_scalar_mem;

    // =========================================================================
    // SCALAR RAW FORWARDING — combinational scan of Scalar RSB
    // =========================================================================
    // Scan every Scalar RSB entry. If its dest_reg matches src1 or src2 of
    // the instruction currently at D&E, forward that result.
    //
    // Last-match-wins: we iterate from index 0 to ROB_DEPTH-1 and overwrite
    // on each hit. Since entries closer to the tail (higher index in a
    // non-wrapped buffer, or more recently allocated in general) are more
    // recently issued, the last overwrite gives the most recent producer.
    // This correctly resolves WAW situations where the same register was
    // written by two unretired instructions.

    always_comb begin
        fwd_src1_hit_o = 1'b0;
        fwd_src1_val_o = '0;
        fwd_src2_hit_o = 1'b0;
        fwd_src2_val_o = '0;

        for (int i = 0; i < ROB_DEPTH; i++) begin
            if (srsb_valid_i[i]) begin

                // Forward to source register 1 if dest_reg matches
                if (srsb_dest_reg_i[i] == de_src1_reg_i) begin
                    fwd_src1_hit_o = 1'b1;
                    fwd_src1_val_o = srsb_result_i[i];
                end

                // Forward to source register 2 if dest_reg matches
                if (srsb_dest_reg_i[i] == de_src2_reg_i) begin
                    fwd_src2_hit_o = 1'b1;
                    fwd_src2_val_o = srsb_result_i[i];
                end

            end
        end
    end

    // =========================================================================
    // VECTOR RAW STALL — combinational scan of Vector RSB
    // =========================================================================
    // No forwarding on the vector side. If any unretired Vector RSB entry
    // is writing to a register that the VIQ head instruction needs to read,
    // hold the VIQ head until that entry commits and the vector register
    // file is updated.

    always_comb begin
        stall_vec_raw_o = 1'b0;

        for (int i = 0; i < ROB_DEPTH; i++) begin
            if (vrsb_valid_i[i]) begin
                if ((vrsb_dest_reg_i[i] == viq_src1_reg_i) ||
                    (vrsb_dest_reg_i[i] == viq_src2_reg_i)) begin
                    stall_vec_raw_o = 1'b1;
                end
            end
        end
    end

    // =========================================================================
    // COMMIT LOGIC — combinational, driven by ROB head entry
    // =========================================================================
    // Head commits if and only if it is valid, filled, and done.
    // External logic reads the result from the appropriate RSB this same cycle.

    rob_entry_t head_entry;
    assign head_entry = rob[head];

    assign commit_valid_o     = head_entry.valid && head_entry.filled && head_entry.done;
    assign commit_seq_num_o   = head;
    assign commit_is_vector_o = head_entry.is_vector;
    assign commit_is_store_o  = head_entry.is_store;

    // =========================================================================
    // CLOCKED LOGIC
    // =========================================================================

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            // -----------------------------------------------------------------
            // RESET
            // -----------------------------------------------------------------
            head  <= '0;
            tail  <= '0;
            count <= '0;
            for (int i = 0; i < ROB_DEPTH; i++)
                rob[i] <= '0;

        end else begin

            // -----------------------------------------------------------------
            // PHASE 1 — FETCH ALLOCATION
            // Allocate a placeholder at the tail. Only valid is set — all
            // semantic fields are unknown until D&E decodes the instruction.
            // Tail advances and wraps naturally due to PTR_W-bit arithmetic.
            // -----------------------------------------------------------------
            if (fetch_valid_i && !rob_full_o) begin
                rob[tail].valid     <= 1'b1;
                rob[tail].filled    <= 1'b0;   // awaiting D&E decode
                rob[tail].done      <= 1'b0;   // awaiting execution
                rob[tail].is_vector <= 1'b0;   // unknown until D&E
                rob[tail].is_mem    <= 1'b0;   // unknown until D&E
                rob[tail].is_store  <= 1'b0;   // unknown until D&E

                tail  <= tail + PTR_W'(1);
                count <= count + 1'b1;
            end

            // -----------------------------------------------------------------
            // PHASE 2 — D&E FILL
            // Instruction fully decoded. Write semantic fields into the
            // placeholder using de_seq_num_i (carried from Fetch in the
            // Fetch→D&E pipeline register). done remains 0.
            // -----------------------------------------------------------------
            if (de_valid_i) begin
                rob[de_seq_num_i].filled    <= 1'b1;
                rob[de_seq_num_i].is_vector <= de_is_vector_i;
                rob[de_seq_num_i].is_mem    <= de_is_mem_i;
                rob[de_seq_num_i].is_store  <= de_is_store_i;
            end

            // -----------------------------------------------------------------
            // PHASE 3A — SCALAR COMPLETION
            // Scalar unit has finished. Result is already in the Scalar RSB.
            // Mark the ROB entry done so the commit monitor can see it.
            // -----------------------------------------------------------------
            if (scalar_done_i) begin
                rob[scalar_seq_num_i].done <= 1'b1;
            end

            // -----------------------------------------------------------------
            // PHASE 3B — VECTOR COMPLETION
            // Vector unit has finished its multi-cycle execution. Result is
            // in the Vector RSB. Mark the ROB entry done.
            // This is the explicit writeback path: vector unit → ROB.
            // -----------------------------------------------------------------
            if (vec_done_i) begin
                rob[vec_seq_num_i].done <= 1'b1;
            end

            // -----------------------------------------------------------------
            // PHASE 4 — IN-ORDER COMMIT
            // commit_valid_o is combinational — external register file latches
            // the RSB result this same cycle. Here we clear the head entry
            // and advance the head pointer to the next oldest instruction.
            //
            // If the head entry is not done, nothing happens this cycle.
            // Instructions behind the head that are already done continue
            // to wait. In-order commit is strictly enforced.
            // -----------------------------------------------------------------
            if (commit_valid_o) begin
                rob[head].valid  <= 1'b0;   // free the slot for future allocation
                rob[head].filled <= 1'b0;
                rob[head].done   <= 1'b0;

                head  <= head + PTR_W'(1);  // advance to next oldest instruction
                count <= count - 1'b1;
            end

        end
    end

endmodule