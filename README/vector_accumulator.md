# Vector Multiply-Add Unit — README

## Overview

This module implements a **vector multiply-accumulate unit** for a RISC-V VPU. It combines a `vector_multiplier` and a `vector_adder_subtractor` to support eight fused multiply-add/subtract operations in a single module. It supports SEW = 8, 16, and 32-bit element widths.

The general compute pattern is:
- **Multiply** two operands element-wise
- **Add or subtract** the result with a third operand

The `accum_op` field selects which inputs are multiplied, which is the addend, and whether the product is negated.

---

## Top Module: `vector_multiply_add_unit`

```
module vector_multiply_add_unit (
    input  logic                 clk,
    input  logic                 reset,
    input  logic [`VLEN-1:0]     data_A,
    input  logic [`VLEN-1:0]     data_B,
    input  logic [`VLEN-1:0]     data_C,
    input  logic [2:0]           accum_op,
    input  logic [1:0]           sew,
    input  logic                 signed_mode,
    input  logic                 Ctrl,
    input  logic                 start,
    input  logic                 sew_16_32,
    input  logic                 sew_32,
    output logic                 count_0_mul_add,
    output logic [`VLEN-1:0]     sum_product_result,
    output logic                 product_sum_done
);
```

---

## Main Signals

| Signal | Direction | Width | Description |
|---|---|---|---|
| `clk` | Input | 1-bit | Clock |
| `reset` | Input | 1-bit | Active-high reset |
| `data_A` | Input | `VLEN`-bit | First operand — always the multiplier input |
| `data_B` | Input | `VLEN`-bit | Second operand — multiplicand for MACC/NMSAC; addend for MADD/NMSUB |
| `data_C` | Input | `VLEN`-bit | Third operand — addend for MACC/NMSAC; multiplicand for MADD/NMSUB |
| `accum_op` | Input | 3-bit | Selects one of 8 multiply-accumulate operations (see table below) |
| `sew` | Input | 2-bit | Element width: `00`=8-bit, `01`=16-bit, `10`=32-bit |
| `signed_mode` | Input | 1-bit | `1` = signed multiplication |
| `Ctrl` | Input | 1-bit | `0` = add product to addend; `1` = subtract product from addend |
| `start` | Input | 1-bit | Start pulse forwarded to `vector_multiplier` |
| `sew_16_32` | Input | 1-bit | Carry boundary control for the adder (see adder README) |
| `sew_32` | Input | 1-bit | Carry boundary control for the adder (see adder README) |
| `count_0_mul_add` | Output | 1-bit | Forwarded from `vector_multiplier` — SEW=32 cycle-phase flag |
| `sum_product_result` | Output | `VLEN`-bit | Final result after multiply then add/subtract |
| `product_sum_done` | Output | 1-bit | Goes high when `mult_done` is asserted — result is valid |

---

## Supported Operations (`accum_op`)

| `accum_op` | Name | Operation | Multiply | Addend |
|---|---|---|---|---|
| `3'b000` | `VMACC_VV`  | `vd = +(A × B) + C` | A × B | C |
| `3'b001` | `VMACC_VX`  | `vd = +(A × B) + C` | A × B | C |
| `3'b010` | `VNMSAC_VV` | `vd = -(A × B) + C` | A × B | C |
| `3'b011` | `VNMSAC_VX` | `vd = -(A × B) + C` | A × B | C |
| `3'b100` | `VMADD_VV`  | `vd = +(A × C) + B` | A × C | B |
| `3'b101` | `VMADD_VX`  | `vd = +(A × C) + B` | A × C | B |
| `3'b110` | `VNMSUB_VV` | `vd = -(A × C) + B` | A × C | B |
| `3'b111` | `VNMSUB_VX` | `vd = -(A × C) + B` | A × C | B |

> Negation (NMSAC, NMSUB) is handled by setting `Ctrl=1` which passes the operation to the adder as a subtraction.

---

## Basic Working

### Step 1 — Operand Routing
Based on `accum_op`, the module routes inputs to the multiplier and selects the addend:
- `MACC`/`NMSAC`: multiply `data_A × data_B`, add `data_C`
- `MADD`/`NMSUB`: multiply `data_A × data_C`, add `data_B`

The addend is held at zero until `mult_done` goes high, preventing the adder from computing with stale data.

### Step 2 — Multiplication
`vector_multiplier` performs element-wise multiplication across all elements in parallel. It is multi-cycle for SEW=32 (3 cycles) and completes in 2 cycles for SEW=8 and SEW=16.

### Step 3 — Product Selection
Once `mult_done` is high, the lower half of each element's double-width product is extracted and packed into `product_selected` (element width matches SEW):

| SEW | Product per element | Selected bits |
|---|---|---|
| 8-bit  | 16-bit | Lower 8 bits |
| 16-bit | 32-bit | Lower 16 bits |
| 32-bit | 64-bit | Lower 32 bits |

### Step 4 — Add/Subtract
The product and addend are routed to `vector_adder_subtractor`. The `Ctrl` signal and operand swap determine whether the result is `product + addend` or `addend - product`:
- `Ctrl=0`: `add_operand_1 = product`, `add_operand_2 = addend` → addition
- `Ctrl=1`: `add_operand_1 = addend`, `add_operand_2 = product` → subtraction (addend - product)

### `product_sum_done`
Asserted combinationally when `mult_done` is high. Since the adder is purely combinational, the full result `sum_product_result` is valid in the same cycle `mult_done` goes high.