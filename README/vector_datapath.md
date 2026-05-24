# Vector Processor Datapath — README

## Overview

This module is the **top-level datapath** of the RISC-V Vector Processor. It connects all major functional units together: decode, CSR, register file, execution unit, LSU, and mask unit. The controller drives all control signals into this module; the datapath handles all data movement between units.

It also instantiates three parameterized multiplexers (`data_mux_2x1`, `data_mux_3x1`) used throughout to route operands.

---

## Module Hierarchy

```
vector_processor_datapath
  ├── vec_decode          (DECODER)
  ├── vec_csr_regfile     (CSR_REGFILE)
  ├── data_mux_2x1        (SEW_EEW_MUX)
  ├── data_mux_2x1        (LMUL_EMUL_MUX)
  ├── data_mux_2x1        (VLMAX_EVLMAX_MUX)
  ├── vec_regfile         (VEC_REGFILE)
  ├── data_mux_3x1        (DATA1_MUX)
  ├── data_mux_2x1        (DATA2_MUX)
  ├── data_mux_2x1        (DATA3_MUX)
  ├── vec_lsu             (VLSU)
  ├── data_mux_2x1        (VLSU_DATA_MUX)
  ├── vector_execution_unit (EXECUTION_UNIT)
  └── vector_mask_unit    (MASK_UNIT)
```

---

## Top Module: `vector_processor_datapth`

### Key Inputs

| Signal | Width | Description |
|---|---|---|
| `clk`, `reset` | 1-bit | Clock and active-high reset |
| `instruction` | `XLEN`-bit | Raw instruction word from scalar processor |
| `rs1_data` | `XLEN`-bit | Scalar register rs1 value from scalar processor |
| `rs2_data` | `XLEN`-bit | Scalar register rs2 value from scalar processor |
| `is_vec` | 1-bit | Asserted by scalar processor when instruction is a legal vector instruction |
| `mem_rdata` | `VLEN`-bit | Data returned from memory on a load |
| `seq_num_i` | `Tag_Width`-bit | Sequence number of the incoming instruction |
| `rob_commit_valid_i` | 1-bit | ROB commit signal — drives `inst_done` |
| `rob_commit_is_vec_o` | 1-bit | Write enable to register file from ROB commit |
| `vec_commit_vd_i` | 5-bit | Destination register address from ROB commit |
| `vec_commit_vector_result_i` | `MAX_VLEN`-bit | Result to write from ROB commit |
| `mask_reg_en` | 1-bit | Enables mask register read for carry/borrow and mask logic ops |
| All controller outputs | — | All control signals from `vector_processor_controller` |

### Key Outputs

| Signal | Width | Description |
|---|---|---|
| `inst_done` | 1-bit | Tied to `rob_commit_valid_i` — tells scalar processor the instruction completed |
| `error` | 1-bit | OR of `error_flag` (LSU) and `wrong_addr` (register file) |
| `csr_out` | `XLEN`-bit | CSR read data returned to scalar processor |
| `csr_done` | 1-bit | Pulses when CSR write completes |
| `execution_done` | 1-bit | Pulses when execution unit result is valid |
| `execution_result` | `MAX_VLEN`-bit | Registered result from the execution unit |
| `is_loaded` | 1-bit | Asserted when load data is ready in `vd_data` |
| `is_stored` | 1-bit | Asserted when store completes |
| `vd_data` | `MAX_VLEN`-bit | Load result assembled by the LSU |
| `mask_unit_output` | `MAX_VLEN`-bit | Final masked result from the mask unit |
| `mask_done` | 1-bit | Asserted when mask unit completes |
| `mask_reg_updated` | `VLEN`-bit | Updated v0 mask register value |
| `seq_num_o` | `Tag_Width`-bit | Sequence number of the completing instruction |
| `data_written` | 1-bit | Asserted when register file write completes |
| `vec_wr_data` | `MAX_VLEN`-bit | Data to be written to the register file |
| All memory interface signals | — | `mem_addr`, `mem_wdata`, `mem_wen`, `mem_ren`, `mem_byte_en`, etc. |

---

## Data Flow

### Operand Path

```
instruction → DECODER → vec_read_addr_1/2 → VEC_REGFILE → vec_data_1/2/3
                                                               │
                      scalar1/scalar2 ──────────────────────── ┤
                      vec_imm_extended ─────────────────────── ┤
                                                               ▼
                                                       DATA1_MUX (3-to-1)  → data_mux1_out
                                                       DATA2_MUX (2-to-1)  → data_mux2_out
                                                       DATA3_MUX (2-to-1)  → data_mux3_out
```

### Execution Path

```
data_mux1_out / data_mux2_out / vec_data_3
        ↓
EXECUTION_UNIT → lanes_data (combinational) → MASK_UNIT → mask_unit_output
              → execution_result (registered, 1 cycle later)
```

### Load Path

```
data_mux1_out[XLEN-1:0] (base addr) ──┐
data_mux2_out[XLEN-1:0] (stride/idx) ─┤→ VLSU → vd_data → vec_wr_data
dst_vec_data (store source) ───────────┘
```

### Write-Back

Register file writes happen at ROB commit — `vec_commit_vector_result_i` is written to `vec_commit_vd_i` when `rob_commit_is_vec_o` is asserted. This separates execution from commit.

### Sequence Number Routing

`seq_num_o` is selected combinationally from whichever unit completes first:

```
execution_done  → seq_num_exe
is_loaded/stored → seq_num_lsu
csr_done        → seq_num_csr
mask_done       → seq_num_mask
default         → seq_num_i (pass-through)
```

---

## Internal Muxes

### SEW/EEW, LMUL/EMUL, VLMAX/EVLMAX Muxes
Three `data_mux_2x1` instances select between the CSR-resident values and the instruction-derived effective values for memory operations:

| Mux | `sel=0` | `sel=1` | Control |
|---|---|---|---|
| `SEW_EEW_MUX` | `sew` (from CSR) | `eew` (from instruction) | `sew_eew_sel` |
| `LMUL_EMUL_MUX` | `vlmul` (from CSR) | `emul` (computed) | `emul_vlmul_sel` |
| `VLMAX_EVLMAX_MUX` | `vlmax` | `e_vlmax` | `vlmax_evlmax_sel` |

### DATA1 Mux (3-to-1)
Selects the first execution operand:

| `data_mux1_sel` | Source |
|---|---|
| `2'b00` | `vec_data_1` (vs1 from register file) |
| `2'b01` | `scaler1_extended` (scalar rs1, sign-extended to MAX_VLEN) |
| `2'b10` | `vec_imm_extended` (immediate, sign-extended per SEW) |

### DATA2 Mux (2-to-1)
Selects the second operand: `vec_data_2` (vs2) or `scaler2_extended` (scalar rs2).

### DATA3 Mux (2-to-1)
Selects the third operand: `0` (unused) or `vec_data_3` (vd for multiply-accumulate).

### Immediate Extension
The 5-bit `vec_imm` is sign-extended to `MAX_VLEN` based on `sew_execution`:
- SEW=8: replicated as 8-bit sign-extended values across the full vector
- SEW=16: replicated as 16-bit sign-extended values
- SEW=32: replicated as 32-bit sign-extended values

### Scalar Extension
`scalar1` and `scalar2` are replicated across `MAX_VLEN` for execution instructions, or zero-padded for non-execution (CSR/load/store) instructions.