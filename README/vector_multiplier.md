# Vector Multiplier — README

## Overview

This file implements a **pipelined vectorized integer multiplier** supporting 8-bit, 16-bit, and 32-bit element widths (SEW). The top-level module `vector_multiplier` accepts two 512-bit input vectors and produces a 1024-bit product vector by instantiating 16 parallel processing elements (`top_8`), each handling a 32-bit slice.

Each processing element is a 4-stage pipeline:

```
Stage 1: multiplier_8     → Operand prep, absolute value, byte routing
Stage 2: dadda_8 (×8)    → Eight parallel 8×8 Dadda multipliers (combinational)
Stage 3: Delay registers  → 1-cycle stall to align Dadda outputs with FSM
Stage 4: carry_save_8     → FSM-based carry-save accumulator → 64-bit product
```

Sign restoration is applied after Stage 4 using the sign bits captured in Stage 1.

---

## Module Hierarchy

```
vector_multiplier          (Top — 512-bit, 16 PEs)
  └── top_8 × 16           (One PE per 32-bit slice)
        ├── multiplier_8   (Stage 1: operand prep)
        ├── dadda_8 × 8    (Stage 2: 8×8 partial products)
        ├── delay regs     (Stage 3: 1-cycle alignment)
        └── carry_save_8   (Stage 4: accumulator FSM)
              ├── HA        (Half adder cell)
              └── csa_dadda (Carry-save adder cell)
```

---

## Top Module: `vector_multiplier`

```
module vector_multiplier (
    input  logic                       clk,
    input  logic                       reset,
    input  logic                       start,
    input  logic [1:0]                 sew,
    input  logic signed [`VLEN-1:0]    data_in_A,
    input  logic signed [`VLEN-1:0]    data_in_B,
    input  logic                       signed_mode,
    output logic                       count_0,
    output logic                       mult_done,
    output logic signed [`VLEN*2-1:0]  product
);
```

### Signals

| Signal | Direction | Width | Description |
|---|---|---|---|
| `clk` | Input | 1-bit | Clock |
| `reset` | Input | 1-bit | Active-high reset |
| `start` | Input | 1-bit | Pulse to begin a new multiplication across all PEs |
| `sew` | Input | 2-bit | Element width: `00`=8-bit, `01`=16-bit, `10`=32-bit |
| `data_in_A` | Input | `VLEN`-bit | First vector operand (512 bits) |
| `data_in_B` | Input | `VLEN`-bit | Second vector operand (512 bits) |
| `signed_mode` | Input | 1-bit | `1` = treat elements as signed (two's complement) |
| `count_0` | Output | 1-bit | Cycle-phase flag for SEW=32 — AND of all 16 PE `count_0` signals |
| `mult_done` | Output | 1-bit | High for one cycle when all 16 PEs have completed — AND of all PE done signals |
| `product` | Output | `VLEN×2`-bit | Packed 1024-bit product (each PE contributes 64 bits) |

---

## Sub-Module Signals

### `multiplier_8` — Stage 1

| Signal | Direction | Description |
|---|---|---|
| `data_in_A/B` | Input | 32-bit operand slice |
| `sew` | Input | Element width selector |
| `signed_mode` | Input | Enables two's complement absolute value computation |
| `start` | Input | Triggers cycle counter for SEW=32 time-multiplexing |
| `count_0` | Output | High in the second cycle of SEW=32 — signals `carry_save_8` to process upper-byte partials |
| `mult1_A … mult8_A` | Output | 8-bit A operands routed to each of the 8 Dadda units |
| `mult1_B … mult8_B` | Output | 8-bit B operands routed to each of the 8 Dadda units |
| `sign_A0…A3`, `sign_B0…B3` | Output | MSB (sign) of each byte of A and B — used for sign restoration |

### `dadda_8` — Stage 2

| Signal | Direction | Description |
|---|---|---|
| `A`, `B` | Input | 8-bit unsigned operands (absolute values from Stage 1) |
| `y` | Output | 16-bit product — fully combinational via a 5-stage Dadda partial product tree |

### `carry_save_8` — Stage 4 FSM

| Signal | Direction | Description |
|---|---|---|
| `start` | Input | Resets accumulators and begins a new accumulation |
| `sew` | Input | Selects FSM path |
| `mult_out_1…8` | Input | 16-bit delayed Dadda outputs |
| `mult_done` | Output | High for one cycle when accumulation is complete |
| `product_1` | Output | Lower 32 bits of the 64-bit result |
| `product_2` | Output | Upper 32 bits of the 64-bit result |

---

## Basic Working

### SEW=8 (4 independent 8-bit elements per PE)
Each byte of A is multiplied by the corresponding byte of B. The four 16-bit Dadda outputs are stored directly into accumulators in a single FSM cycle (`PP_8`). No accumulation across bytes is needed.

### SEW=16 (2 independent 16-bit elements per PE)
Each 16-bit element is split into two bytes. The eight Dadda units compute four partial products per element. The FSM (`PP_16`) uses CSA trees to accumulate these into two 32-bit results in a single cycle.

### SEW=32 (1 full 32-bit element per PE, 2 cycles)
A 32×32 multiply is split across two cycles using the `count_0` flag from `multiplier_8`:

- **Cycle 1 (`PP1_32`):** Dadda units receive the lower bytes of B (`B0`, `B1`) alongside all bytes of A. Partial products are accumulated into `accum_0…3`.
- **Cycle 2 (`PP2_32`):** Dadda units receive the upper bytes of B (`B2`, `B3`). Results are combined with the stored accumulators to produce the final 64-bit product.

### Sign Restoration
All multiplications are performed on absolute values. After accumulation, the MSBs (`sign_A` XOR `sign_B`) determine if the result needs to be negated (two's complement) per element. This is applied in the `always_comb` block of `top_8` before the product is output.

### `mult_done` Timing
`mult_done` is the AND of all 16 PE done signals. It goes high only when every PE has completed its accumulation — for SEW=8 and SEW=16 this takes 2 cycles after `start`; for SEW=32 it takes 3 cycles.