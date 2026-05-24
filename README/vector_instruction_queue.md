# Vector Instruction Queue (VIQ) — README

## Overview

This module implements the **Vector Instruction Queue (VIQ)** for a RISC-V VPU. It is a **FIFO-based instruction buffer** that sits between the scalar processor and the vector execution pipeline. It accepts incoming vector instructions and holds them until the downstream vector unit is ready to consume them.

The queue is implemented as a circular buffer of depth `VIQ_DEPTH`, with separate read and write pointers. It supports **simultaneous enqueue and dequeue** in the same cycle.

---

## Top Module: `viq`

```
module viq (
    input  logic                      clk,
    input  logic                      reset,
    input  logic                      vector_instr_valid,
    input  logic [`Tag_Width-1:0]     instr_seq_i,
    input  logic [`INSTR_W-1:0]       instruction_i,
    input  logic [`OPERAND_W-1:0]     operand_rs1_i,
    input  logic [`OPERAND_W-1:0]     operand_rs2_i,
    input  logic                      instr_is_vec_i,
    input  logic                      deq_ready,
    output logic                      deq_valid,
    output logic [`Tag_Width-1:0]     instr_seq_o,
    output logic [`INSTR_W-1:0]       instruction_o,
    output logic [`OPERAND_W-1:0]     operand_rs1_o,
    output logic [`OPERAND_W-1:0]     operand_rs2_o,
    output logic                      instr_is_vec_o,
    output logic                      do_deq,
    output logic                      stall_vec,
    output logic                      viq_full,
    output logic [`VIQ_tag_width-1:0] num_instr
);
```

---

## Main Signals

### Inputs

| Signal | Width | Description |
|---|---|---|
| `clk` | 1-bit | Clock signal |
| `reset` | 1-bit | Active-high reset — clears all pointers and FIFO contents when low |
| `vector_instr_valid` | 1-bit | Asserted by scalar processor when a new vector instruction is ready to enqueue |
| `instr_seq_i` | `Tag_Width`-bit | Sequence number (tag) of the incoming instruction — used for deduplication |
| `instruction_i` | `INSTR_W`-bit | Full instruction word to be stored in the queue |
| `operand_rs1_i` | `OPERAND_W`-bit | Value of scalar source register rs1 |
| `operand_rs2_i` | `OPERAND_W`-bit | Value of scalar source register rs2 |
| `instr_is_vec_i` | 1-bit | Flag indicating this is a vector instruction (passed through with the entry) |
| `deq_ready` | 1-bit | Asserted by the downstream vector unit when it is ready to accept the next instruction |

### Outputs

| Signal | Width | Description |
|---|---|---|
| `deq_valid` | 1-bit | Asserted when the queue is non-empty and an instruction is available for dequeue |
| `do_deq` | 1-bit | Pulses high when a dequeue actually happens (`deq_ready && !empty`) |
| `instr_seq_o` | `Tag_Width`-bit | Sequence number of the instruction at the head of the queue |
| `instruction_o` | `INSTR_W`-bit | Instruction word at the head of the queue |
| `operand_rs1_o` | `OPERAND_W`-bit | rs1 value of the head instruction |
| `operand_rs2_o` | `OPERAND_W`-bit | rs2 value of the head instruction |
| `instr_is_vec_o` | 1-bit | Vector flag of the head instruction |
| `stall_vec` | 1-bit | Asserted when the queue is full — tells the scalar processor to stop issuing vector instructions |
| `viq_full` | 1-bit | Same as `stall_vec` — direct full flag for external visibility |
| `num_instr` | `VIQ_tag_width`-bit | Current number of instructions in the queue (`write_ptr - read_ptr`) |

---

## Basic Working

### FIFO Structure
The queue is a circular buffer of `VIQ_DEPTH` entries. Each entry stores the full instruction bundle: `{instr_seq, instruction, operand_rs2, operand_rs1, instr_is_vec}` packed into a single `ENTRY_W`-bit word.

Read and write pointers are one bit wider than needed to index the buffer (`PTR_W+1` bits). This extra MSB is used to distinguish between full and empty when the index bits are equal:

- **Empty:** `write_ptr == read_ptr` (both MSBs and index bits match)
- **Full:** MSBs differ but index bits are equal (write has wrapped around to meet read)

### Enqueue (`do_enq`)
A new entry is written when all three conditions hold: `vector_instr_valid`, queue is not `full`, and `instr_seq_i` is different from `last_enqueued_seq`. The last condition prevents the same instruction from being enqueued twice if the upstream holds valid high for multiple cycles.

### Dequeue (`do_deq`)
The head entry is consumed when `deq_ready` is high and the queue is not empty. The output signals are driven combinationally from `fifo[read_idx]` — they are valid in the same cycle `do_deq` is asserted. If no dequeue is happening, all outputs are driven to zero.

### Stall / Backpressure
When the queue is full, `stall_vec` and `viq_full` are asserted. The scalar processor should stop issuing new vector instructions until the queue drains.

### Simultaneous Enqueue and Dequeue
Since `do_enq` and `do_deq` are independent, both can happen in the same clock cycle — one entry enters at the tail while another leaves at the head, keeping the queue depth stable.