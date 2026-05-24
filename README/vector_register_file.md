# Vector Register File — README

## Overview

This module implements the **Vector Register File** for a RISC-V VPU. It stores `MAX_VEC_REGISTERS` vector registers, each `VLEN` bits wide. It supports three read ports, one write port, and LMUL-aware grouped access — meaning multiple consecutive physical registers are concatenated and returned as a single wide read or written as a single wide write, depending on the current LMUL setting.

Register `v0` is the dedicated **mask register** and has special read and write behaviour.

Writes occur on the **negative clock edge** to allow combinational reads to settle before the write.

---

## Top Module: `vec_regfile`

```
module vec_regfile (
    input  logic                      clk, reset,
    input  logic [4:0]                raddr_1, raddr_2, vec_write_addr,
    input  logic [DATA_WIDTH-1:0]     wdata,
    input  logic [4:0]                waddr,
    input  logic                      wr_en,
    input  logic [3:0]                lmul,
    input  logic [3:0]                emul,
    input  logic                      offset_vec_en,
    input  logic                      mask_operation,
    input  logic                      mask_wr_en,
    output logic [DATA_WIDTH-1:0]     rdata_1, rdata_2, rdata_3,
    output logic [DATA_WIDTH-1:0]     dst_data,
    output logic [VECTOR_LENGTH-1:0]  vector_length,
    output logic                      wrong_addr,
    output logic [`VLEN-1:0]          v0_mask_data,
    output logic                      data_written
);
```

---

## Main Signals

### Inputs

| Signal | Width | Description |
|---|---|---|
| `clk` | 1-bit | Clock — writes occur on the negative edge |
| `reset` | 1-bit | Active-low asynchronous reset — clears all registers |
| `raddr_1` | 5-bit | Read address for source register vs1 |
| `raddr_2` | 5-bit | Read address for source register vs2 |
| `vec_write_addr` | 5-bit | Address used to read the current destination register value (`dst_data`) |
| `waddr` | 5-bit | Write address — register to update |
| `wdata` | `DATA_WIDTH`-bit | Data to write — may span multiple physical registers for LMUL > 1 |
| `wr_en` | 1-bit | Enables write to the register file |
| `lmul` | 4-bit | Register grouping for arithmetic: `1`/`2`/`4`/`8` consecutive registers |
| `emul` | 4-bit | Register grouping for indexed memory: same encoding as `lmul` |
| `offset_vec_en` | 1-bit | `1` = read `rdata_2` based on `emul` (for indexed load/store index vector); `0` = use `lmul` |
| `mask_operation` | 1-bit | When set, reads `rdata_1` and `rdata_2` as single-register reads regardless of LMUL (for mask logic ops) |
| `mask_wr_en` | 1-bit | Writes `wdata[VLEN-1:0]` directly to `v0` (mask register) |

### Outputs

| Signal | Width | Description |
|---|---|---|
| `rdata_1` | `DATA_WIDTH`-bit | Read data for vs1 — concatenated across LMUL registers |
| `rdata_2` | `DATA_WIDTH`-bit | Read data for vs2 — selected from LMUL or EMUL read based on `offset_vec_en` |
| `rdata_3` | `DATA_WIDTH`-bit | Same as `dst_data` — current value of the destination register (for MAC ops) |
| `dst_data` | `DATA_WIDTH`-bit | Current value at `vec_write_addr` — used for masking and accumulate |
| `vector_length` | `VECTOR_LENGTH`-bit | Total active vector width in bits = VLEN × LMUL |
| `wrong_addr` | 1-bit | Asserted when an invalid or misaligned address is detected during read or write |
| `v0_mask_data` | `VLEN`-bit | Always reflects the current value of register `v0` — used as the mask |
| `data_written` | 1-bit | Pulses `1` for one cycle after a successful register write completes |

---

## Basic Working

### LMUL-Grouped Reads
When LMUL > 1, multiple consecutive physical registers are concatenated into a single wide output. The base address must be naturally aligned (divisible by LMUL):

| LMUL | Registers accessed | Alignment requirement |
|---|---|---|
| 1 | `[raddr]` | Any valid address |
| 2 | `[raddr+1 : raddr]` | `raddr % 2 == 0` |
| 4 | `[raddr+3 : raddr]` | `raddr % 4 == 0` |
| 8 | `[raddr+7 : raddr]` | `raddr % 8 == 0` |

If the address is out of bounds or misaligned, `addr_error` is set and `rdata` is zero.

### `rdata_2` Selection
`rdata_2` is selected by a final mux after both LMUL-based and EMUL-based reads:
- `offset_vec_en = 0` → use `rdata_2_lmul` (standard arithmetic operand)
- `offset_vec_en = 1` → use `rdata_2_emul` (index vector for indexed load/store, read based on EMUL)

### Mask Operation Mode
When `mask_operation = 1`, LMUL grouping is bypassed entirely. Both `rdata_1` and `rdata_2` return single physical registers at `raddr_1` and `raddr_2`. This is used for mask register logic instructions (VMAND, VMOR, VMXOR, etc.).

### Writes
Writes occur on the **negative clock edge**. Priority order:

1. `mask_wr_en`: Writes `wdata[VLEN-1:0]` to `v0` only.
2. `wr_en`: Writes `wdata` across `lmul` consecutive registers starting at `waddr`. If `waddr == 0`, `v0` retains its current value (mask is preserved) and only upper registers are updated.
3. Neither: `wrong_addr` is updated from the combinational read error flags.

Invalid write addresses (out of bounds or misaligned for the current LMUL) set `wrong_addr = 1` and no write occurs.

### `v0_mask_data`
Directly wired to `vec_regfile[0]` — always reflects the current mask register value with zero latency.s