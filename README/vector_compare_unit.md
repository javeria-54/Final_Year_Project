# Vector Compare Unit — README

## Overview

This module implements a **fully combinational vector comparison unit** for a RISC-V Vector Processing Unit (VPU). It compares two input vectors element-by-element and produces a **packed mask** as output — one bit per element — instead of a full-width result per element.

It supports **8 comparison operations** across **3 element widths (SEW = 8, 16, 32 bits)**.

---

## Top Module: `vector_compare_unit`

```
module vector_compare_unit (
    input  logic [`VLEN-1:0] dataA,
    input  logic [`VLEN-1:0] dataB,
    input  logic [2:0]       cmp_op,
    input  logic [1:0]       sew,
    output logic [`VLEN-1:0] compare_result,
    output logic             compare_done
);
```

---

## Main Signals

| Signal | Direction | Width | Description |
|---|---|---|---|
| `dataA` | Input | `VLEN`-bit | First vector operand |
| `dataB` | Input | `VLEN`-bit | Second vector operand — primary operand in comparisons |
| `cmp_op` | Input | 3-bit | Comparison operation select — chooses one of 8 supported comparisons |
| `sew` | Input | 2-bit | Element width selector — determines how the vector is divided into elements |
| `compare_result` | Output | `VLEN`-bit | **Packed mask** — bit `[i]` = `1` if comparison is TRUE for element `i`, else `0` |
| `compare_done` | Output | 1-bit | Always `1` — module is purely combinational, result is always valid |

---

## Operation Select (`cmp_op`)

| `cmp_op` | Name | Operation |
|---|---|---|
| `3'b000` | `CMP_EQ`  | `B == A` — Equal |
| `3'b001` | `CMP_NE`  | `B != A` — Not equal |
| `3'b010` | `CMP_LTU` | `B < A` — Less than, unsigned |
| `3'b011` | `CMP_LEU` | `B <= A` — Less than or equal, unsigned |
| `3'b100` | `CMP_LT`  | `B < A` — Less than, signed |
| `3'b101` | `CMP_LE`  | `B <= A` — Less than or equal, signed |
| `3'b110` | `CMP_GT`  | `B > A` — Greater than, signed *(pseudo-op)* |
| `3'b111` | `CMP_GTU` | `B > A` — Greater than, unsigned *(pseudo-op)* |

> **Pseudo-ops (GT, GTU):** These are implemented by **swapping A and B** before comparison, reusing the existing LT/LTU logic. No extra hardware is needed: `B > A` is equivalent to `A < B`.

---

## SEW Encoding (`sew`)

| `sew` | Element Width | Elements (VLEN=512) | Output bits used |
|---|---|---|---|
| `2'b00` | 8-bit  | 64 | bits `[63:0]` |
| `2'b01` | 16-bit | 32 | bits `[31:0]` |
| `2'b10` | 32-bit | 16 | bits `[15:0]` |
| `2'b11` | 64-bit | — | Not implemented, output = `0` |

---

## Basic Working

### Element Extraction
Based on `sew`, both input vectors are sliced into elements of the appropriate width. Each element pair `(dataB[i], dataA[i])` is compared independently.

### Packed Mask Output
Unlike typical ALU results, the output here is **not** a full-width value per element. Instead, each comparison produces a **single bit**, stored at position `i` in `compare_result`. All remaining upper bits are zero.

```
Element 0:  dataB[7:0]   vs dataA[7:0]   → result bit [0]
Element 1:  dataB[15:8]  vs dataA[15:8]  → result bit [1]
...
Element N:  dataB[...]   vs dataA[...]   → result bit [N]
```

This format is compliant with the **RISC-V V specification** for mask registers.

### Signed vs Unsigned
For `CMP_LT`, `CMP_LE`, `CMP_GT`: elements are compared as **signed** values using `$signed()`.
For `CMP_LTU`, `CMP_LEU`, `CMP_GTU`: comparison is **unsigned** (default in SystemVerilog).

### `compare_done`
Always driven to `1`. The module is purely combinational — output is valid as soon as inputs are stable.

---
