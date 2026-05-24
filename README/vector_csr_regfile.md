# Vector CSR Register File — README

## Overview

This module implements the **Vector Control and Status Register (CSR) file** for a RISC-V Vector Processing Unit (VPU). It is a **clocked, sequential module** that stores and manages the core vector configuration registers: `vtype`, `vl` (vector length), and `vstart`.

It decodes the `vsetvli` instruction to update vector configuration, computes `vlmax` and the actual `vl` based on the requested element width (SEW) and register grouping (LMUL), and provides configuration outputs to the rest of the VPU datapath.

---

## Top Module: `vec_csr_regfile`

```
module vec_csr_regfile (
    input  logic clk,
    input  logic n_rst,
    input  logic [`XLEN-1:0]      inst,
    output logic [`XLEN-1:0]      csr_out,
    input  logic [`Tag_Width-1:0] seq_num_i,
    output logic [`Tag_Width-1:0] seq_num_csr,
    input  logic                  rs1rd_de,
    input  logic [`XLEN-1:0]      scalar2,
    input  logic [`XLEN-1:0]      scalar1,
    input  logic [2:0]            width,
    input  logic                  csrwr_en,
    output logic [3:0]            vlmul, emul,
    output logic [6:0]            sew, eew,
    output logic [9:0]            vlmax, e_vlmax,
    output logic                  tail_agnostic,
    output logic                  mask_agnostic,
    output logic [`XLEN-1:0]      vec_length,
    output logic [`XLEN-1:0]      start_element,
    output logic                  csr_done
);
```

---

## Main Signals

### Inputs

| Signal | Width | Description |
|---|---|---|
| `clk` | 1-bit | Clock signal |
| `n_rst` | 1-bit | Active-low synchronous reset |
| `inst` | `XLEN`-bit | Full instruction word — decoded internally for opcode, funct3, rs1, rd, and CSR address |
| `seq_num_i` | `Tag_Width`-bit | Sequence number of the incoming instruction — captured when `csrwr_en` is asserted |
| `rs1rd_de` | 1-bit | Selects between VLMAX and AVL: `0` = use VLMAX (rs1 is x0), `1` = use requested `scalar1` |
| `scalar2` | `XLEN`-bit | New `vtype` value — bits `[7:0]` encode vma, vta, vsew, vlmul |
| `scalar1` | `XLEN`-bit | New `vl` / `vstart` value — the Application Vector Length (AVL) requested |
| `width` | 3-bit | Effective Element Width (EEW) for memory operations — used to compute `eew` and `emul` |
| `csrwr_en` | 1-bit | Write enable — when asserted, updates `vtype` and `vl` on the next clock edge |

### Outputs

| Signal | Width | Description |
|---|---|---|
| `csr_out` | `XLEN`-bit | Read data from a CSR instruction (returns old value of the accessed register) |
| `seq_num_csr` | `Tag_Width`-bit | Sequence number forwarded out when `csr_done` is asserted |
| `vlmul` | 4-bit | Decoded LMUL value as an integer (1, 2, 4, or 8) |
| `emul` | 4-bit | Effective LMUL = (EEW / SEW) × LMUL — computed for memory operations |
| `sew` | 7-bit | Decoded Standard Element Width in bits (8, 16, 32, or 64) |
| `eew` | 7-bit | Decoded Effective Element Width in bits for the current memory operation |
| `vlmax` | 10-bit | Maximum vector length = VLEN / SEW × LMUL |
| `e_vlmax` | 10-bit | Effective VLMAX = (VLEN / EEW) × EMUL — for memory operations |
| `tail_agnostic` | 1-bit | `vta` field from `vtype` — controls behaviour of tail elements |
| `mask_agnostic` | 1-bit | `vma` field from `vtype` — controls behaviour of masked-off elements |
| `vec_length` | `XLEN`-bit | Current value of `vl` — number of active elements to process |
| `start_element` | `XLEN`-bit | Current value of `vstart` — index of first element to process |
| `csr_done` | 1-bit | Pulses `1` for one cycle when the CSR write operation completes successfully |

---

## Internal CSR Registers

| Register | Description |
|---|---|
| `csr_vtype_q` | Stores `vtype`: holds `ill`, `vma`, `vta`, `vsew`, `vlmul` fields |
| `csr_vl_q` | Stores `vl` — the active vector length after `vsetvli` |
| `csr_vstart_q` | Stores `vstart` — starting element index, readable and writable via CSR instructions |

---

## Basic Working

### Vector Configuration (`vsetvli`)
When `csrwr_en` is asserted and it was not already high (edge detection via `csrwr_en_d`), the module performs a **4-step update** in a single clock cycle:

1. **Update `vtype`** from `scalar2` — sets vsew, vlmul, vta, vma fields.
2. **Compute `vlmax`** based on the new LMUL and SEW combination: `vlmax = (VLEN / SEW) × LMUL`.
3. **Compute actual `vl`** — if `rs1rd_de = 0` (rs1 is x0), `vl = vlmax`; otherwise `vl = min(scalar1, vlmax)`.
4. **Update `vl` register** — if both rs1 and rd are x0, `vl` is preserved; otherwise it is set to the computed value.

After this, `csr_done` is asserted for one cycle to signal completion.

### CSR Read/Write Instructions (opcode `7'h73`)
Standard CSR instructions (`csrrw`, `csrrs`, `csrrc`, and their immediate variants) are decoded via `funct3`:

- **`vstart`** — can be read and written. Supports set-bit (`csrrs`) and clear-bit (`csrrc`) operations.
- **`vtype`** — read-only. Only accessible when `rs1 = x0` (no side effect). Writes trigger `illegal_insn`.
- **`vl`** — read-only. Only accessible when `rs1 = x0`. Writes trigger `illegal_insn`.

`csr_out` always returns the **old value** of the accessed register (read-before-write semantics).

### EEW and EMUL (Memory Operations)
The `width` input selects the Effective Element Width for a memory instruction. `emul` is computed as `(EEW / SEW) × LMUL` using a lookup table across all EEW and SEW combinations. `e_vlmax` is then derived as `(VLEN / EEW) × EMUL`.

### Sequence Number Tracking
`seq_num_i` is latched into `seq_num_held` when `csrwr_en` is high. It is forwarded to `seq_num_csr` only when `csr_done` is asserted, so downstream logic knows which instruction completed.