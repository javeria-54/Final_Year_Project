# Vector Decode Unit — README

## Overview

This module implements the **Vector Instruction Decode Unit** for a RISC-V Vector Processing Unit (VPU). It is a **fully combinational** module that takes a raw instruction word and scalar register data as inputs, and extracts all fields needed by the vector register file, CSR unit, and load/store units.

It handles three categories of vector instructions: **arithmetic/logic** (`V_ARITH`), **vector loads** (`V_LOAD`), and **vector stores** (`V_STORE`), as well as **vector configuration** instructions (`vsetvli`, `vsetvl`, `vsetivli`).

---

## Top Module: `vec_decode`

```
module vec_decode (
    input  logic [`XLEN-1:0]     vec_inst,
    input  logic [`XLEN-1:0]     rs1_data,
    input  logic [`XLEN-1:0]     rs2_data,
    input  logic                 is_vec,
    output logic [4:0]           vec_read_addr_1,
    output logic [4:0]           vec_read_addr_2,
    output logic [4:0]           vec_read_addr_3,
    output logic [4:0]           vec_write_addr,
    output logic [`MAX_VLEN-1:0] vec_imm,
    output logic                 vec_mask,
    output logic [2:0]           width,
    output logic                 mew,
    output logic [2:0]           nf,
    output logic [`XLEN-1:0]     scalar2,
    output logic [`XLEN-1:0]     scalar1,
    input  logic                 vl_sel,
    input  logic                 vtype_sel,
    input  logic                 lumop_sel
);
```

---

## Main Signals

### Inputs

| Signal | Width | Description |
|---|---|---|
| `vec_inst` | `XLEN`-bit | Raw instruction word — all fields are extracted from this |
| `rs1_data` | `XLEN`-bit | Value of scalar register rs1 — used for AVL in `vsetvli` and base address in load/store |
| `rs2_data` | `XLEN`-bit | Value of scalar register rs2 — used for stride in load/store and `vsetvl` |
| `is_vec` | 1-bit | Enables the decode logic — output is zero when `is_vec = 0` |
| `vl_sel` | 1-bit | Selects `scalar1`: `0` = `rs1_data` (from register), `1` = `uimm` (from instruction bits `[19:15]`) |
| `vtype_sel` | 1-bit | Selects `scalar2` source: `0` = `rs2_data`, `1` = `zimm` (zero-extended immediate from instruction) |
| `lumop_sel` | 1-bit | Overrides `scalar2` with `lumop` field when set — used for unit-stride memory operations |

### Outputs

| Signal | Width | Description |
|---|---|---|
| `vec_read_addr_1` | 5-bit | Source register address vs1 — fed to vector register file read port 1 |
| `vec_read_addr_2` | 5-bit | Source register address vs2 — fed to vector register file read port 2 |
| `vec_read_addr_3` | 5-bit | Source/destination register address vs3/vd — used for multiply-accumulate and store operations |
| `vec_write_addr` | 5-bit | Destination register address vd — fed to vector register file write port |
| `vec_imm` | `MAX_VLEN`-bit | Immediate value extracted from instruction — used for `OPIVI` (immediate arithmetic) |
| `vec_mask` | 1-bit | Mask bit `vm` from instruction bit `[25]` — controls which elements are active |
| `width` | 3-bit | Element width for memory operations — extracted from instruction bits `[14:12]` |
| `mew` | 1-bit | Memory element width extension bit — selects between integer and floating-point widths |
| `nf` | 3-bit | Number of fields — used for segmented load/store operations |
| `scalar1` | `XLEN`-bit | AVL or vstart value sent to CSR — either `rs1_data` or `uimm` based on `vl_sel` |
| `scalar2` | `XLEN`-bit | vtype or stride value sent to CSR — selected from `rs2_data`, `zimm`, or `lumop` |

---

## Instruction Fields Extracted from `vec_inst`

| Bits | Field | Description |
|---|---|---|
| `[6:0]`   | `vopcode`   | Opcode — selects arithmetic, load, store, or config |
| `[11:7]`  | `vd_addr`   | Destination vector register (also vs3 for store/accumulate) |
| `[14:12]` | `vfunc3`    | Function 3 — selects operand type (VV, VX, VI, MV, config) |
| `[19:15]` | `vs1_addr` / `uimm` | Source register vs1 or 5-bit unsigned immediate |
| `[24:20]` | `vs2_addr` / `lumop` | Source register vs2 or unit-stride memory operation code |
| `[25]`    | `vm`        | Vector mask bit |
| `[27:26]` | `mop`       | Memory addressing mode: `00`=unit, `10`=strided, `01/11`=indexed |
| `[28]`    | `mew`       | Memory element width extension |
| `[30:20]` | `zimm`      | 11-bit zero-extended immediate for `vsetvli` |
| `[31:26]` | `func_6`    | 6-bit function code — selects specific arithmetic operation |
| `[31:29]` | `nf`        | Number of fields for segmented memory operations |

---

## Basic Working

### Arithmetic Instructions (`V_ARITH`, opcode `0x57`)
Decoded based on `vfunc3` into five variants:

| `vfunc3` | Type | Operands Used |
|---|---|---|
| `OPIVV` | Vector-Vector integer | vs1, vs2 → vd |
| `OPIVI` | Vector-Immediate integer | imm, vs2 → vd |
| `OPIVX` | Vector-Scalar integer | rs1, vs2 → vd |
| `OPMVV` | Vector-Vector multiply | vs1, vs2, vs3 → vd |
| `OPMVX` | Vector-Scalar multiply | rs1, vs2, vs3 → vd |

For each variant, `func_6` is checked against a list of valid operation codes. If valid, `vec_op_valid` is set. If the instruction is not in the valid list, `vec_op_valid` is cleared.

### Configuration Instructions (`CONF`, inside `V_ARITH`)
Decoded using `inst_msb` (bits `[31:30]`):

| `inst[31:30]` | Instruction | `scalar1` source | `scalar2` source |
|---|---|---|---|
| `0x` | `vsetvli` | `rs1_data` | `zimm[30:20]` |
| `11` | `vsetivli` | `uimm` (immediate) | `zimm[29:20]` |
| `10` | `vsetvl` | `rs1_data` | `rs2_data` |

### Load / Store Instructions (`V_LOAD`, `V_STORE`)
Both use the same decode path. The `mop` field selects the addressing mode:

- `2'b00` — Unit stride (no extra register needed)
- `2'b10` — Strided: `rs2_data` is the stride value, passed via `scalar2`
- `2'b01` / `2'b11` — Indexed (gather/scatter): `vs2_addr` is read for index values

`width`, `mew`, and `nf` are extracted directly from the instruction and forwarded to the load/store unit.

### Scalar Mux Logic (`scalar1`, `scalar2`)
Three muxes at the output select the final values sent to the CSR:

- `scalar1 = vl_sel ? uimm : rs1_data` — AVL source
- `vtype_mux = vtype_sel ? zimm : rs2_data` — vtype source
- `scalar2 = lumop_sel ? lumop : vtype_mux` — final scalar2 (can be overridden with lumop for memory ops)