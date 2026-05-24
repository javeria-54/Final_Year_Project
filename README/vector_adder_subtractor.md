# Vector Adder/Subtractor — README

## Overview

This module implements a **scalable vector adder/subtractor** for a RISC-V Vector Processing Unit (VPU). It operates on a full `MAX_VLEN`-bit wide vector and supports three element widths: **8-bit, 16-bit, and 32-bit (SEW)**.

Internally, the vector is split into 32-bit slices, each handled by a parallel `adder_subtractor_32bit` unit. Each unit further breaks its 32-bit input into four 8-bit adders, with carry propagation controlled by SEW signals.

---

## Top Module: `vector_adder_subtractor`

```
module vector_adder_subtractor (
    input  logic                        Ctrl,
    input  logic                        sew_16_32,
    input  logic                        sew_32,
    input  logic signed [`VLEN-1:0]     A,
    input  logic signed [`VLEN-1:0]     B,
    output logic signed [`VLEN-1:0]     Sum,
    output logic        [(`VLEN/8)-1:0] carry_out,
    output logic                        sum_done
);
```

---

## Main Signals

| Signal | Direction | Width | Description |
|---|---|---|---|
| `Ctrl` | Input | 1-bit | Operation select: `0` = Addition, `1` = Subtraction |
| `sew_16_32` | Input | 1-bit | Enables carry across the byte-0 → byte-1 boundary. Set to `1` for SEW=16 or SEW=32 |
| `sew_32` | Input | 1-bit | Enables carry across byte-1→2 and byte-2→3 boundaries. Set to `1` for SEW=32 only |
| `A` | Input | `VLEN`-bit | First vector operand (signed) |
| `B` | Input | `VLEN`-bit | Second vector operand (signed) |
| `Sum` | Output | `VLEN`-bit | Result vector — holds the add/subtract output for all elements |
| `carry_out` | Output | `VLEN/8`-bit | Carry-out from every 8-bit adder segment across the full vector |
| `sum_done` | Output | 1-bit | Goes HIGH only when **all** parallel slices have produced a valid result |

---

## SEW Control (How to Set `sew_32` and `sew_16_32`)

| Mode | `sew_32` | `sew_16_32` | Behaviour |
|---|---|---|---|
| SEW = 8  | `0` | `0` | 4 independent 8-bit operations per 32-bit slice |
| SEW = 16 | `0` | `1` | 2 independent 16-bit operations per 32-bit slice |
| SEW = 32 | `1` | `1` | 1 full 32-bit operation per slice |
| Invalid  | `1` | `0` | Not supported — `sum_done` will be `0`, `Sum` = 0 |

---

## Basic Working

### Addition (`Ctrl = 0`)
- `B` passes through unchanged.
- Carry-in starts at `0` for each element boundary.
- Result: `Sum = A + B`

### Subtraction (`Ctrl = 1`)
- Each byte of `B` is inverted (`~B`) using XOR with `0xFF`.
- Carry-in starts at `1` at each element boundary.
- This implements 2's complement: `A + (~B) + 1 = A - B`

### Carry Propagation
Carry between the four internal 8-bit adders is selectively allowed or blocked using the SEW signals, creating independent element boundaries:

```
Byte:       [3]      [2]      [1]      [0]
         adder8 ← adder8 ← adder8 ← adder8
                  ↑mux_sew_32↑   ↑mux_sew_16_32↑
```

- `mux_sew_16_32` sits between byte 0 and byte 1
- `mux_sew_32` sits between bytes 1→2 and bytes 2→3
- When a mux blocks carry, each element starts fresh — making them independent

### Scalability
The top module instantiates `NUM_ELEMENT_SEW32 = VLEN / 32` slices in parallel. All slices share the same `Ctrl`, `sew_16_32`, and `sew_32` control signals. The `sum_done` output is the AND of all individual slice `sum_done` signals — it only goes HIGH when every slice is valid.

---
