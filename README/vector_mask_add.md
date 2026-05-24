# Vector Mask Add/Subtract — README

## Overview

This module implements a **masked vector add/subtract unit** for a RISC-V VPU. It performs a two-stage addition: first computes `vs2 ± vs1`, then adds the mask register (expanded to element width) to the intermediate result. This implements mask-accumulate style operations where the mask bit contributes `+1` or `+0` to each element's result.

It internally instantiates two `vector_adder_subtractor` units chained in series.

---

## Top Module: `vector_mask_add_sub`

```
module vector_mask_add_sub (
    input  logic [`VLEN-1:0]         adder_data_1,
    input  logic [`VLEN-1:0]         adder_data_2,
    input  logic [`VLEN-1:0]         mask_reg,
    input  logic                     Ctrl,
    input  logic                     sew_16_32,
    input  logic                     sew_32,
    input  logic [1:0]               sew,
    output logic [(`VLEN/8)-1:0]     carry_out,
    output logic [`VLEN-1:0]         sum_mask_result,
    output logic                     sum_mask_done
);
```

---

## Main Signals

| Signal | Direction | Width | Description |
|---|---|---|---|
| `adder_data_1` | Input | `VLEN`-bit | First vector operand (vs1) |
| `adder_data_2` | Input | `VLEN`-bit | Second vector operand (vs2) — primary operand |
| `mask_reg` | Input | `VLEN`-bit | Mask register — bit `[i]` is the mask for element `i` |
| `Ctrl` | Input | 1-bit | Operation select: `0` = add, `1` = subtract |
| `sew_16_32` | Input | 1-bit | Carry boundary control: `1` enables carry across byte-0→1 boundary (SEW=16/32) |
| `sew_32` | Input | 1-bit | Carry boundary control: `1` enables carry across upper byte boundaries (SEW=32 only) |
| `sew` | Input | 2-bit | Element width: `00`=8b, `01`=16b, `10`=32b — used for mask expansion |
| `carry_out` | Output | `VLEN/8`-bit | Carry-out from every 8-bit slice of the second (mask) adder |
| `sum_mask_result` | Output | `VLEN`-bit | Final result: `(adder_data_2 ± adder_data_1) + mask_extended` |
| `sum_mask_done` | Output | 1-bit | Always `1` — both adders are purely combinational |

---

## Basic Working

### Stage 1 — Vector Add/Subtract
The first `vector_adder_subtractor` computes `adder_data_2 ± adder_data_1` based on `Ctrl`. The carry-out from this stage is discarded (`carry_out_unused`).

### Stage 2 — Mask Addition
The mask register is expanded from a packed 1-bit-per-element format into a full-width vector where each element holds `0` or `1` at its LSB, zero-padded to the element width:

| SEW | Expansion |
|---|---|
| 8-bit  | `mask_reg[i]` → `8'b0000_000x` placed at element `i` position |
| 16-bit | `mask_reg[i]` → `16'b0...x` placed at element `i` position |
| 32-bit | `mask_reg[i]` → `32'b0...x` placed at element `i` position |

This expanded mask is then added to the Stage 1 result by the second `vector_adder_subtractor`. The carry-out from this stage is forwarded to `carry_out`.

### Overall Operation
```
sum_mask_result = (adder_data_2 ± adder_data_1) + mask_extended
```

Each element is processed independently according to the SEW and carry boundary settings, consistent with the rest of the VPU's element-wise execution model.