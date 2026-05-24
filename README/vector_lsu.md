# Vector Load/Store Unit (LSU) — README

## Overview

This module implements the **Vector Load/Store Unit (LSU)** for a RISC-V VPU. It handles all vector memory accesses — loads and stores — across four addressing modes: **unit-stride, constant-stride, ordered indexed, and unordered indexed**.

It is a **sequential FSM-based module** that iterates through vector elements one at a time (or all at once for unit-stride), generating a memory address and data per cycle, and assembling the full result vector after all elements are processed.

---

## Top Module: `vec_lsu`

```
module vec_lsu (
    input  logic                  clk,
    input  logic                  n_rst,
    input  logic                  stride_sel,
    input  logic                  ld_inst,
    input  logic                  st_inst,
    input  logic                  index_str,
    input  logic                  index_unordered,
    input  logic [9:0]            vlmax,
    input  logic [6:0]            sew,
    input  logic [`XLEN-1:0]      rs1_data,
    input  logic [`XLEN-1:0]      rs2_data,
    input  logic [`MAX_VLEN-1:0]  vs2_data,
    input  logic [`MAX_VLEN-1:0]  vs3_data,
    input  logic                  mew,
    input  logic [2:0]            width,
    input  logic                  inst_done,
    output logic [`XLEN-1:0]      mem_addr,
    output logic [`VLEN-1:0]      mem_wdata,
    output logic [`VLEN-1:0]      mem_wdata_unit,
    output logic [63:0]           mem_byte_en,
    output logic                  mem_wen,
    output logic                  mem_ren,
    output logic                  mem_elem_mode,
    output logic [1:0]            mem_sew_enc,
    input  logic [`VLEN-1:0]      mem_rdata,
    input  logic [`Tag_Width-1:0] seq_num,
    output logic [`Tag_Width-1:0] seq_num_lsu,
    output logic [`MAX_VLEN-1:0]  vd_data,
    output logic                  is_loaded,
    output logic                  is_stored,
    output logic                  error_flag
);
```

---

## Main Signals

### Inputs

| Signal | Width | Description |
|---|---|---|
| `clk` | 1-bit | Clock signal |
| `n_rst` | 1-bit | Active-low asynchronous reset |
| `ld_inst` | 1-bit | Asserted when a vector load instruction is to be executed |
| `st_inst` | 1-bit | Asserted when a vector store instruction is to be executed |
| `stride_sel` | 1-bit | `1` = unit-stride mode; `0` = use `rs2_data` as stride |
| `index_str` | 1-bit | Asserted for indexed (gather/scatter) addressing mode |
| `index_unordered` | 1-bit | Asserted for unordered indexed mode — elements visited in LFSR-generated order |
| `vlmax` | 10-bit | Maximum number of elements to process |
| `sew` | 7-bit | Element width in bits (8, 16, 32) — controls byte enable and packing |
| `rs1_data` | `XLEN`-bit | Base address for the memory operation |
| `rs2_data` | `XLEN`-bit | Stride value for constant-stride mode |
| `vs2_data` | `MAX_VLEN`-bit | Index vector — each element is an offset from `rs1_data` (indexed mode) |
| `vs3_data` | `MAX_VLEN`-bit | Source data vector for store operations |
| `mew` | 1-bit | Memory element width extension — selects integer vs floating-point element type |
| `width` | 3-bit | EEW encoding for indexed mode: `000`=8b, `101`=16b, `110`=32b |
| `inst_done` | 1-bit | Asserted by upstream when the load/store result has been consumed — resets state |
| `mem_rdata` | `VLEN`-bit | Data returned from memory on a read |
| `seq_num` | `Tag_Width`-bit | Sequence number of the current instruction |

### Outputs

| Signal | Width | Description |
|---|---|---|
| `mem_addr` | `XLEN`-bit | Address driven to memory interface each cycle |
| `mem_wdata` | `VLEN`-bit | Per-element write data (non-unit-stride stores) |
| `mem_wdata_unit` | `VLEN`-bit | Full packed write data for unit-stride stores |
| `mem_byte_en` | 64-bit | Byte enable mask — indicates which bytes in the memory word are valid |
| `mem_wen` | 1-bit | Memory write enable — asserted when performing a store |
| `mem_ren` | 1-bit | Memory read enable — asserted when performing a load |
| `mem_elem_mode` | 1-bit | `1` = element-by-element mode; `0` = full-vector unit-stride mode |
| `mem_sew_enc` | 2-bit | Encoded SEW: `00`=8b, `01`=16b, `10`=32b |
| `seq_num_lsu` | `Tag_Width`-bit | Sequence number forwarded when `is_loaded` or `is_stored` is asserted |
| `vd_data` | `MAX_VLEN`-bit | Assembled result vector — valid when `is_loaded` goes high |
| `is_loaded` | 1-bit | Registered signal — goes high one cycle after the last element is loaded and `vd_data` is stable |
| `is_stored` | 1-bit | Asserted in the same cycle the last store completes |
| `error_flag` | 1-bit | Asserted when an invalid `width` encoding is used with indexed mode |

---

## FSM States

| State | Name | Description |
|---|---|---|
| `2'd0` | `ST_IDLE` | Waiting for a new load or store instruction |
| `2'd1` | `ST_RD_ISSUE` | Issuing memory reads one element per cycle (or all at once for unit-stride) |
| `2'd2` | `ST_WR_ISSUE` | Issuing memory writes one element per cycle (or all at once for unit-stride) |
| `2'd3` | `ST_UNORD_SETUP` | Pre-computing random visit order using LFSR before starting indexed access |

---

## Addressing Modes

| Mode | Condition | Address Formula |
|---|---|---|
| Unit-stride | `stride_sel=1` or `rs2_data=0` | `rs1_data` (single transaction for full vector) |
| Constant-stride | `stride_sel=0`, `rs2_data≠0`, `index_str=0` | `rs1_data + count_el × rs2_data` |
| Ordered indexed | `index_str=1`, `index_unordered=0` | `rs1_data + vs2_data[count_el]` |
| Unordered indexed | `index_str=1`, `index_unordered=1` | `random_addr_array[count_el]` (LFSR pre-computed) |

---

## Basic Working

### Load Flow
1. FSM moves from `ST_IDLE` → `ST_RD_ISSUE` (or `ST_UNORD_SETUP` first for unordered indexed).
2. Each cycle in `ST_RD_ISSUE`: `mem_addr` is driven, `mem_ren=1` is asserted, and `mem_rdata` is captured into `loaded_data[]` at the correct element slot.
3. For **unit-stride**, the entire vector is read in one transaction and all elements are unpacked simultaneously.
4. For **all other modes**, one element is read per cycle. `count_el` advances each cycle until `last_element`.
5. On the final element, `is_loaded_comb` is set internally. `is_loaded` is then **registered** — it goes high one cycle later, exactly when `vd_data` (packed from `loaded_data[]`) is stable and correct.

### Store Flow
1. FSM moves from `ST_IDLE` → `ST_WR_ISSUE` (or `ST_UNORD_SETUP` first for unordered indexed).
2. For **unit-stride**: `mem_wdata_unit` (full packed vector) and `unit_byte_en` are driven in one transaction. `is_stored` goes high immediately.
3. For **all other modes**: one element from `vs3_data` is extracted per cycle based on `wr_logical_idx`, packed into `el_wdata`, and written with the appropriate `el_byte_en`. `is_stored` goes high on the last element.

### Unordered Indexed Mode
Before accessing memory, the FSM enters `ST_UNORD_SETUP`. An LFSR generates a pseudo-random visit order across all `vlmax` elements, storing the pre-computed addresses in `random_addr_array[]` and the corresponding logical indices in `visit_to_logical[]`. Once all entries are filled (`all_assigned`), the FSM proceeds to read or write in that random order, placing each result in the correct logical position in `loaded_data[]`.

### `is_loaded` Timing
`is_loaded` is **registered by one cycle** after `is_loaded_comb` to ensure `vd_data` is fully valid before the upstream logic reads it. `is_stored` is combinational since no data assembly is needed after a write.

### Error Detection
If `index_str=1` and `width` is not one of the three valid EEW encodings (`000`, `101`, `110`), `error_flag` is asserted and the FSM stays in `ST_IDLE`.