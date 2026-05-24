# Vector Bitwise Unit — README

## Overview

This module implements a **fully combinational vector bitwise and comparison unit** for a RISC-V Vector Processing Unit (VPU). It supports **8 operations** across **4 element widths (SEW = 8, 16, 32, 64 bits)**.

The entire `VLEN`-bit vector is divided into independent elements based on the selected SEW, and the chosen operation is applied to **all elements in parallel** using a for-loop inside `always_comb`. Since there is no clock or handshake involved, output is always immediately valid.

---

## Top Module: `vector_bitwise_unit`

```
module vector_bitwise_unit (
    input  logic [`VLEN-1:0] dataA,
    input  logic [`VLEN-1:0] dataB,
    input  logic [4:0]       bitwise_op,
    input  logic [1:0]       sew,
    output logic [`VLEN-1:0] bitwise_result,
    output logic             bitwise_done
);
```

---

## Main Signals

| Signal | Direction | Width | Description |
|---|---|---|---|
| `dataA` | Input | `VLEN`-bit | First vector operand — used as the second operand in most operations |
| `dataB` | Input | `VLEN`-bit | Second vector operand — primary operand (result is based on B for NOT) |
| `bitwise_op` | Input | 5-bit | Operation select code — selects one of 8 supported operations |
| `sew` | Input | 2-bit | Element width selector — determines how the vector is split into elements |
| `bitwise_result` | Output | `VLEN`-bit | Result vector — element-wise operation result |
| `bitwise_done` | Output | 1-bit | Always `1` — module is purely combinational, result is always valid |

---

## Operation Select (`bitwise_op`)

| `bitwise_op` | Name | Operation |
|---|---|---|
| `5'b00000` | `ALU_AND`  | `B & A` — Bitwise AND |
| `5'b00001` | `ALU_OR`   | `B \| A` — Bitwise OR |
| `5'b00010` | `ALU_XOR`  | `B ^ A` — Bitwise XOR |
| `5'b00011` | `ALU_NOT`  | `~B` — Bitwise NOT (A is ignored) |
| `5'b00100` | `ALU_MINU` | `min(B, A)` — Unsigned minimum |
| `5'b00101` | `ALU_MIN`  | `min(B, A)` — Signed minimum |
| `5'b00110` | `ALU_MAXU` | `max(B, A)` — Unsigned maximum |
| `5'b00111` | `ALU_MAX`  | `max(B, A)` — Signed maximum |

---

## SEW Encoding (`sew`)

| `sew` | Element Width | Number of Elements (VLEN=512) |
|---|---|---|
| `2'b00` | 8-bit  | 64 elements |
| `2'b01` | 16-bit | 32 elements |
| `2'b10` | 32-bit | 16 elements |
| `2'b11` | 64-bit | 8 elements  |

---

## Basic Working

### Element Extraction
Based on the `sew` input, the full `VLEN`-bit vectors (`dataA`, `dataB`) are sliced into elements of the appropriate width. For example, with SEW=16 and VLEN=512, the vector is divided into 32 independent 16-bit elements.

### Operation
The selected `bitwise_op` is applied to **each pair of elements** from `dataA` and `dataB` independently, in parallel. Results are packed back into the output vector at the same positions.

```
dataB [element i]  ──┐
                      ├──► operation ──► bitwise_result [element i]
dataA [element i]  ──┘
```

This repeats for every element across the full vector width simultaneously.

### Signed vs Unsigned (MIN/MAX)
For `ALU_MIN` and `ALU_MAX`, elements are compared as **signed** values using `$signed()`. For `ALU_MINU` and `ALU_MAXU`, comparison is **unsigned** (default in SystemVerilog).

### `bitwise_done`
Always driven to `1`. Since the module is purely combinational with no pipeline stages or clock, the output is valid as soon as inputs are stable. No handshake is needed.

---
