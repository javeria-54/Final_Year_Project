# Vector Processor Controller — README

## Overview

This module is the **main combinational controller** of the RISC-V VPU. It decodes a raw vector instruction word and drives all control signals across the entire vector pipeline — decode, CSR, register file, execution unit, and LSU. It has no state registers; every output is purely combinational from `vec_inst`.

It is the central hub that tells every other module what to do for each instruction.

---

## Top Module: `vector_processor_controller`

```
module vector_processor_controller (
    input  logic [`XLEN-1:0]  vec_inst,
    output logic               vl_sel,
    output logic               vtype_sel,
    output logic               lumop_sel,
    output logic               rs1rd_de,
    output logic               csrwr_en,
    output logic               sew_eew_sel,
    output logic               vlmax_evlmax_sel,
    output logic               emul_vlmul_sel,
    output logic               vec_reg_wr_en,
    output logic               mask_operation,
    output logic               mask_wr_en,
    output logic [1:0]         data_mux1_sel,
    output logic               data_mux2_sel,
    output logic               data_mux3_sel,
    output logic               offset_vec_en,
    output logic               stride_sel,
    output logic               ld_inst,
    output logic               st_inst,
    output logic               index_str,
    output logic               index_unordered,
    output logic [2:0]         execution_op,
    output logic               execution_inst,
    output logic               signed_mode,
    output logic               Ctrl, start,
    output logic               mul_low, mul_high,
    output logic [4:0]         bitwise_op,
    output logic [1:0]         op_type,
    output logic [2:0]         cmp_op,
    output logic [2:0]         accum_op,
    output logic [2:0]         shift_op,
    output logic [3:0]         mask_op,
    output logic               mask_reg_en,
    output logic               add_inst, sub_inst, reverse_sub_inst
);
```

---

## Main Signals

### Input

| Signal | Width | Description |
|---|---|---|
| `vec_inst` | `XLEN`-bit | Raw instruction word — all control signals are derived entirely from this |

### Outputs — Decode / CSR

| Signal | Width | Description |
|---|---|---|
| `csrwr_en` | 1-bit | Enables CSR write — asserted for `vsetvli`, `vsetvl`, `vsetivli` |
| `vl_sel` | 1-bit | `0` = use `rs1_data` as AVL; `1` = use `uimm` (for `vsetivli`) |
| `vtype_sel` | 1-bit | `0` = use `rs2_data` as vtype; `1` = use `zimm` immediate |
| `lumop_sel` | 1-bit | Overrides `scalar2` with `lumop` field for unit-stride memory ops |
| `rs1rd_de` | 1-bit | `0` = rs1 is x0 → use VLMAX; `1` = use requested AVL from rs1 |

### Outputs — Register File

| Signal | Width | Description |
|---|---|---|
| `vec_reg_wr_en` | 1-bit | Enables write to vector register file |
| `mask_operation` | 1-bit | Indicates this instruction updates the mask register |
| `mask_wr_en` | 1-bit | Enable signal specifically for mask register write |
| `mask_reg_en` | 1-bit | Asserted for carry/borrow and mask logic instructions — enables mask register read |
| `data_mux1_sel` | 2-bit | Selects first data operand: `00`=vs1 data, `01`=scalar rs1, `10`=immediate |
| `data_mux2_sel` | 1-bit | Selects second operand: `0`=vs2 data, `1`=scalar rs2 |
| `data_mux3_sel` | 1-bit | Selects third operand (for multiply-accumulate): `0`=vs2, `1`=vd (destination) |
| `offset_vec_en` | 1-bit | Asserted for indexed loads/stores — selects vs2 as the index offset vector |

### Outputs — SEW/VLMAX Mux Selects

| Signal | Width | Description |
|---|---|---|
| `sew_eew_sel` | 1-bit | `0` = use SEW from CSR; `1` = use EEW from instruction (for load/store) |
| `vlmax_evlmax_sel` | 1-bit | `0` = use VLMAX; `1` = use effective VLMAX (e_vlmax) for load/store |
| `emul_vlmul_sel` | 1-bit | `0` = use VLMUL from CSR; `1` = use EMUL computed from EEW |

### Outputs — LSU

| Signal | Width | Description |
|---|---|---|
| `ld_inst` | 1-bit | Asserted for vector load instructions |
| `st_inst` | 1-bit | Asserted for vector store instructions |
| `stride_sel` | 1-bit | `1` = unit-stride; `0` = use rs2 as stride value |
| `index_str` | 1-bit | Asserted for indexed (gather/scatter) addressing |
| `index_unordered` | 1-bit | Asserted for unordered indexed access (elements visited in LFSR order) |

### Outputs — Execution Unit

| Signal | Width | Description |
|---|---|---|
| `execution_inst` | 1-bit | Asserted for all arithmetic instructions — tells execution unit to process |
| `execution_op` | 3-bit | Selects functional unit: `000`=add/sub, `001`=shift, `010`=mask-add, `011`=mul, `100`=bitwise, `101`=compare, `110`=move, `111`=mul-add |
| `Ctrl` | 1-bit | `0` = addition/accumulate; `1` = subtraction/negate |
| `start` | 1-bit | Start pulse for multi-cycle multiplier — asserted for all mul/macc instructions |
| `signed_mode` | 1-bit | Enables signed arithmetic for multiply and compare |
| `mul_low` | 1-bit | Select lower half of multiply result (for `VMUL`) |
| `mul_high` | 1-bit | Select upper half of multiply result (for `VMULH`, `VMULHU`, `VMULHSU`) |
| `add_inst` | 1-bit | Specifically flags addition to the adder unit |
| `sub_inst` | 1-bit | Specifically flags subtraction |
| `reverse_sub_inst` | 1-bit | Flags reverse subtract: `B - A` instead of `A - B` (for `VRSUB`) |
| `bitwise_op` | 5-bit | Operation code for the bitwise unit (AND, OR, XOR, MIN, MAX, etc.) |
| `op_type` | 2-bit | Operand type: `00`=VV, `01`=VX, `10`=VI — passed to execution for context |
| `cmp_op` | 3-bit | Operation code for the compare unit |
| `shift_op` | 3-bit | Operation code for the shift unit: `000`=SLL, `001`=SRL, `010`=SRA |
| `accum_op` | 3-bit | Operation code for the multiply-accumulate unit |
| `mask_op` | 4-bit | Operation code for mask logic instructions (AND, OR, XOR, NAND, NOR, etc.) |

---

## Basic Working

The controller decodes `vec_inst` in one `always_comb` block structured as a nested case statement:

### Level 1 — Opcode (`vopcode`)
Three main instruction categories:

| Opcode | Category |
|---|---|
| `V_ARITH` | Arithmetic, comparison, shift, multiply, mask, config |
| `V_LOAD` | Vector load |
| `V_STORE` | Vector store |

### Level 2 — Function 3 (`vfunc3`) for Arithmetic
Inside `V_ARITH`, `vfunc3` selects the operand type:

| `vfunc3` | Type | `data_mux1_sel` |
|---|---|---|
| `OPIVV` | Vector-Vector | `2'b00` (vs1) |
| `OPIVX` | Vector-Scalar | `2'b01` (scalar rs1) |
| `OPIVI` | Vector-Immediate | `2'b10` (immediate) |
| `OPMVV` | Multiply VV | `2'b00` (vs1) |
| `OPMVX` | Multiply VX | `2'b01` (scalar rs1) |
| `CONF` | Configuration | CSR write path |

### Level 3 — Function 6 (`v_func6`) for Specific Operation
Inside each operand type, `v_func6` selects the specific instruction and drives the appropriate `execution_op`, `bitwise_op`, `cmp_op`, `shift_op`, `accum_op`, `Ctrl`, `start`, and `signed_mode` signals.

### Load/Store — `mop` Field
For `V_LOAD` and `V_STORE`, the `mop` field (bits `[27:26]`) selects the addressing mode and drives `stride_sel`, `index_str`, `index_unordered`, `offset_vec_en`, and the SEW/VLMAX mux selects accordingly:

| `mop` | Mode | `stride_sel` | `index_str` | `index_unordered` |
|---|---|---|---|---|
| `2'b00` | Unit-stride | `1` | `0` | `0` |
| `2'b10` | Constant-stride | `0` | `0` | `0` |
| `2'b11` | Ordered indexed | `0` | `1` | `0` |
| `2'b01` | Unordered indexed | `0` | `1` | `1` |

### Configuration Instructions (`CONF`)
Decoded using bits `[31:30]` of the instruction:

| `inst[31:30]` | Instruction | `vl_sel` | `vtype_sel` |
|---|---|---|---|
| `0x` | `vsetvli` | `0` (rs1) | `1` (zimm) |
| `11` | `vsetivli` | `1` (uimm) | `1` (zimm) |
| `10` | `vsetvl` | `0` (rs1) | `0` (rs2) |