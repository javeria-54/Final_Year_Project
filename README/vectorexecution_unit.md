# Vector Execution Unit — README

## Overview

This is the **top-level Vector Execution Unit** for a RISC-V VPU. It acts as a **dispatcher and result collector** — it receives decoded operation signals, routes operand data to the correct functional sub-unit, and muxes the result back to a single output.

It instantiates six sub-units internally:

| Sub-unit | Module | Operation |
|---|---|---|
| Adder/Subtractor | `vector_adder_subtractor` | Add, subtract, reverse subtract |
| Multiplier | `vector_multiplier` | Multiply (low/high half) |
| Multiply-Accumulate | `vector_multiply_add_unit` | MADD, NMSUB, MACC, NMSAC |
| Mask Add/Sub | `vector_mask_add_sub` | Masked add/subtract |
| Compare | `vector_compare_unit` | Element-wise comparisons → mask |
| Bitwise | `vector_bitwise_unit` | AND, OR, XOR, NOT, MIN, MAX |
| Shift | `vector_shift_unit` | Logical/arithmetic shifts |

---

## Top Module: `vector_execution_unit`

```
module vector_execution_unit (
    input  logic                     clk,
    input  logic                     reset,
    input  logic [`MAX_VLEN-1:0]     data_1, data_2, data_3,
    input  logic [`Tag_Width-1:0]    seq_num,
    output logic [`Tag_Width-1:0]    seq_num_exe,
    input  logic                     execution_inst,
    input  logic                     Ctrl, start,
    input  logic [6:0]               sew_eew_mux_out,
    input  logic [2:0]               execution_op,
    input  logic                     signed_mode,
    input  logic                     mul_low, mul_high,
    input  logic                     reverse_sub_inst, add_inst, sub_inst,
    input  logic [4:0]               bitwise_op,
    input  logic [2:0]               cmp_op, accum_op, shift_op,
    output logic [(`VLEN/8)-1:0]     carry_out,
    output logic [1:0]               sew,
    input  logic [`VLEN-1:0]         mask_reg_updated,
    output logic [`MAX_VLEN-1:0]     execution_result,
    output logic [(`VLEN/8)-1:0]     carry_out_mask,
    output logic                     mult_done,
    output logic [`MAX_VLEN-1:0]     execution_result_reg,
    output logic                     execution_done
);
```

---

## Main Signals

### Inputs

| Signal | Width | Description |
|---|---|---|
| `clk` | 1-bit | Clock — used by multiplier and accumulate units (combinational units ignore it) |
| `reset` | 1-bit | Active-high reset — all outputs go to zero when low |
| `data_1` | `MAX_VLEN`-bit | First vector operand — routed to the active sub-unit |
| `data_2` | `MAX_VLEN`-bit | Second vector operand |
| `data_3` | `MAX_VLEN`-bit | Third vector operand — used only for multiply-accumulate |
| `seq_num` | `Tag_Width`-bit | Sequence number of the current instruction — latched on `execution_inst` |
| `execution_inst` | 1-bit | Pulses high to indicate a new instruction is being dispatched |
| `Ctrl` | 1-bit | Add/subtract control: `0` = add, `1` = subtract — forwarded to adder and mask-add |
| `start` | 1-bit | Start signal for multi-cycle units (multiplier, multiply-accumulate) |
| `sew_eew_mux_out` | 7-bit | One-hot encoded element width: `0001000`=8b, `0010000`=16b, `0100000`=32b |
| `execution_op` | 3-bit | Selects which functional unit to activate (see table below) |
| `signed_mode` | 1-bit | Enables signed arithmetic for multiply and compare operations |
| `mul_low` | 1-bit | Select lower half of multiply result |
| `mul_high` | 1-bit | Select upper half of multiply result |
| `add_inst` | 1-bit | Asserted for addition instructions (used with `execution_op = 3'b000`) |
| `sub_inst` | 1-bit | Asserted for subtraction instructions |
| `reverse_sub_inst` | 1-bit | Asserted for reverse subtraction (B - A instead of A - B) |
| `bitwise_op` | 5-bit | Operation code for bitwise unit (AND, OR, XOR, NOT, MIN, MAX, etc.) |
| `cmp_op` | 3-bit | Operation code for compare unit (EQ, NE, LT, LE, GT, etc.) |
| `accum_op` | 3-bit | Operation code for multiply-accumulate unit |
| `shift_op` | 3-bit | Operation code for shift unit (SLL, SRL, SRA) |
| `mask_reg_updated` | `VLEN`-bit | Current mask register value — used by the masked add/subtract unit |

### Outputs

| Signal | Width | Description |
|---|---|---|
| `seq_num_exe` | `Tag_Width`-bit | Sequence number forwarded when `execution_done` is asserted |
| `sew` | 2-bit | Decoded element width: `00`=8b, `01`=16b, `10`=32b |
| `execution_result` | `MAX_VLEN`-bit | Combinational result from the active sub-unit — valid when any `*_done` is high |
| `execution_result_reg` | `MAX_VLEN`-bit | Registered (latched) version of `execution_result` — stable for one cycle after done |
| `execution_done` | 1-bit | Pulses `1` for one cycle when any sub-unit completes and result is valid |
| `mult_done` | 1-bit | Specifically indicates multiplier completion — also used upstream for multi-cycle tracking |
| `carry_out` | `VLEN/8`-bit | Carry-out from every 8-bit adder slice in the main adder unit |
| `carry_out_mask` | `VLEN/8`-bit | Carry-out from the masked adder unit |

---

## `execution_op` — Functional Unit Select

| `execution_op` | Unit Activated | Sub-condition |
|---|---|---|
| `3'b000` | Adder/Subtractor | `add_inst`/`sub_inst` → add; `reverse_sub_inst` → reverse subtract |
| `3'b001` | Shift Unit | — |
| `3'b010` | Mask Add/Sub | — |
| `3'b011` | Multiplier | — |
| `3'b100` | Bitwise Unit | — |
| `3'b101` | Compare Unit | — |
| `3'b110` | Move (passthrough) | `data_1` forwarded directly to output |
| `3'b111` | Multiply-Accumulate | — |

---

## Basic Working

### SEW Decoding
`sew_eew_mux_out` is a one-hot 7-bit value that gets decoded into a 2-bit `sew` used by all sub-units. The `sew_16_32` and `sew_32` carry control signals are derived from `sew` to configure the adder's carry boundaries.

### Operation Dispatch
Each cycle, the `execution_op` field activates exactly one enable signal (`add_en`, `mult_en`, `shift_en`, etc.). The corresponding operands from `data_1`/`data_2`/`data_3` are routed to that sub-unit. All other sub-unit inputs are driven to zero.

### Multi-Cycle Units (Multiplier, Multiply-Accumulate)
The multiplier and multiply-accumulate units take multiple cycles. When `mult_en` or `mult_add_en` is first asserted, operands are latched into holding registers (`mult_data_1_reg`, `mult_sum_data_X_reg`) and a `mult_active` / `mult_sum_active` flag is set. These latched values continue to feed the sub-unit on subsequent cycles until `mult_done_internal` signals completion.

### Result Muxing
`execution_result` is driven combinationally from whichever sub-unit is active. For the multiplier, the correct half (upper or lower) is selected per element based on `mul_high` / `mul_low` and packed into the output vector.

### `execution_done` and `execution_result_reg`
When any sub-unit raises its `*_done` signal, `execution_done` is registered high for one cycle and `execution_result` is captured into `execution_result_reg`, giving downstream logic a stable registered copy of the result.

### Sequence Number Tracking
`seq_num` is latched into `seq_num_held` on the cycle `execution_inst` is asserted. It is driven to `seq_num_exe` only when `execution_done` is high, so downstream logic can match the result to the correct in-flight instruction.