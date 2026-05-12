## Complete Design Summary

### Pipeline Overview

```
Scalar:  Fetch → Decode & Execute → Writeback
Vector:  VIQ → Vector Unit (multi-cycle, not pipelined)
Shared:  ROB + RSB (in-order commit mechanism)
```

---

### Register Files

- Scalar and vector register files are **completely separate**
- Data transfer between scalar and vector domains happens **exclusively through shared memory**
- This is why memory hazards are the **only hazards** that matter between the two sides

---

### ROB — Reorder Buffer

**At Fetch:**
- Assign seq# to instruction
- Check if ROB has a free slot — if not, **stall Fetch**
- Allocate a placeholder ROB entry: `[seq#, all other fields blank]`

**At Decode & Execute:**
- Fill in ROB entry with: `[seq#, type, is_vector, is_mem, dest_reg, done=N]`
- All stall checks and dispatch decisions happen here

**Commit (every cycle, ROB head monitor):**
- If ROB head entry is marked `done` → commit → write result to register file or memory → free ROB entry → advance head
- If ROB head entry is `not done` → stall commit — nothing behind it can commit regardless of their done status

---

### RSB — Result Store Buffer

- When any instruction completes (scalar or vector), its result is written to RSB tagged with seq#
- RSB holds results that are **done but waiting for in-order commit**
- On commit, result is moved from RSB to the actual register file or memory

---

### VIQ — Vector Instruction Queue

- FIFO buffer between scalar pipeline and vector unit
- Each entry carries: `[seq#, instruction, operands, is_mem]`
- Instructions enter VIQ at D&E stage when decoded as vector
- Vector unit pulls from VIQ head when it is free
- If VIQ is **full** when a vector instruction reaches D&E → **stall scalar pipeline**

---

### Stall Conditions — Complete List

#### Stall 1 — ROB Full
```
At Fetch:
  if ROB has no free slot → stall Fetch
```

#### Stall 2 — VIQ Full
```
At D&E:
  if instruction is vector AND VIQ is full → stall scalar pipeline
```

#### Stall 3 — Scalar LD/ST blocked by Vector LD/ST
```
At D&E:
  if instruction is scalar LD/ST
  AND any ROB entry is [vector, is_mem, not committed]
  → stall scalar pipeline
  → release when that vector LD/ST commits
```

#### Stall 4 — Vector LD/ST blocked by Scalar LD/ST
```
At VIQ head (dispatch check every cycle):
  if instruction is vector LD/ST
  AND any ROB entry is [scalar, is_mem, not committed]
  → hold in VIQ, do not dispatch to vector unit
  → release when that scalar LD/ST commits
```

#### No Stall Cases
```
- Scalar LD/ST in pipeline, vector ALU instruction in ROB → NO stall
- Vector ALU in VIQ, scalar LD/ST in pipeline → dispatch freely
- Scalar ALU instructions → never cause or trigger any stall
- Vector ALU instructions → never cause or trigger any stall
```

---

### Key Invariant
> At no point do a scalar memory instruction and a vector memory instruction overlap in execution. All memory accesses are serialized between the two sides.

---

### Dispatch & Completion Flow

```
Scalar instruction at D&E:
  → fill ROB entry
  → run stall checks
  → if no stall: execute → write result to RSB → mark ROB entry done
  → Writeback stage handles commit signaling

Vector instruction at D&E:
  → fill ROB entry
  → push to VIQ (stall if VIQ full)
  → when vector unit free AND dispatch check passes:
       → vector unit executes (multi-cycle)
       → on completion: write result to RSB → mark ROB entry done
       → completion signal sent back to ROB
```

---

### Out of Order Execution, In Order Commit

- Scalar instructions execute in order within the scalar pipeline
- Vector instructions execute concurrently with scalar (when no memory hazard)
- Results land in RSB out of order
- ROB enforces strictly in-order commit from its head pointer
- RSB result can sit waiting arbitrarily long until its seq# reaches ROB head

---

## Instruction Sequence for Trace

| Seq# | Instruction | Type | Notes |
|---|---|---|---|
| I1 | ADD R1, R2, R3 | Scalar ALU | |
| I2 | VADD V1, V2, V3 | Vector ALU | 4 cycles, no mem |
| I3 | ST R1, 100(R8) | Scalar ST | mem |
| I4 | VLD V2, 100(R8) | Vector LD | mem — hazard with I3 |
| I5 | MUL R4, R1, R5 | Scalar ALU | |
| I6 | VST V1, 200(R9) | Vector ST | mem |
| I7 | LD R6, 200(R9) | Scalar LD | mem — hazard with I6 |
| I8 | ADD R7, R4, R6 | Scalar ALU | |

---

## Assumptions

- Scalar D&E: 1 cycle
- Scalar Writeback: 1 cycle  
- Vector ALU (VADD): 4 cycles
- Vector LD/ST: 3 cycles
- VIQ depth: 2
- ROB has sufficient entries

---

## Cycle by Cycle Trace

---

### Cycle 1

| Stage | Instruction | Action |
|---|---|---|
| Fetch | I1 | ROB placeholder seq#1 allocated |

---

### Cycle 2

| Stage | Instruction | Action |
|---|---|---|
| Fetch | I2 | ROB placeholder seq#2 allocated |
| D&E | I1 | Decoded: scalar ALU. ROB#1 filled. Executes → result to RSB seq#1, ROB#1 done=Y |

---

### Cycle 3

| Stage | Instruction | Action |
|---|---|---|
| Fetch | I3 | ROB placeholder seq#3 allocated |
| D&E | I2 | Decoded: vector ALU, no mem. ROB#2 filled. No stall. Pushed to VIQ |
| Commit | I1 | ROB head seq#1 done → commits → result to reg file |
| Vector Unit | I2 VADD | Picked up from VIQ. Starts. Done end of cycle 6 |

---

### Cycle 4

| Stage | Instruction | Action |
|---|---|---|
| Fetch | I4 | ROB placeholder seq#4 allocated |
| D&E | I3 | Decoded: scalar ST, is_mem. ROB#3 filled. **Stall check:** any vector LD/ST unretired in ROB? → I2 is vector but ALU, not mem → **NO stall**. Executes → result to RSB seq#3, ROB#3 done=Y |
| Vector Unit | I2 VADD (1/4) | |
| ROB head | I2 | not done → commit stalls |

---

### Cycle 5

| Stage | Instruction | Action |
|---|---|---|
| Fetch | I5 | ROB placeholder seq#5 allocated |
| D&E | I4 | Decoded: vector LD, is_mem. ROB#4 filled. Pushed to VIQ. **VIQ dispatch check:** any scalar LD/ST unretired in ROB? → I3 is scalar ST, not yet committed → **I4 held in VIQ** |
| Vector Unit | I2 VADD (2/4) | |
| ROB head | I2 | not done → commit stalls. I3 done but stuck behind I2 |

---

### Cycle 6

| Stage | Instruction | Action |
|---|---|---|
| Fetch | I6 | ROB placeholder seq#6 allocated |
| D&E | I5 | Decoded: scalar ALU. ROB#5 filled. No stall. Executes → result to RSB seq#5, ROB#5 done=Y |
| Vector Unit | I2 VADD (3/4) | |
| VIQ | I4 VLD waiting | I3 still not committed → still held |
| ROB head | I2 | not done → commit stalls |

---

### Cycle 7

| Stage | Instruction | Action |
|---|---|---|
| Fetch | I7 | ROB placeholder seq#7 allocated |
| D&E | I6 | Decoded: vector ST, is_mem. ROB#6 filled. **Stall check at D&E:** any vector LD/ST unretired in ROB? → I4 is vector LD in ROB, not committed → **scalar pipeline stalls — I7 stalls at Fetch, I6 stalls at D&E** |
| Vector Unit | I2 VADD (4/4) ✓ DONE | Result to RSB seq#2, ROB#2 done=Y |
| VIQ | I4 VLD waiting | I3 still not committed |
| ROB head | I2 | just marked done → **commits** end of this cycle |

---

### Cycle 8

| Stage | Instruction | Action |
|---|---|---|
| Fetch | I7 (stalled) | I6 still at D&E blocking |
| D&E | I6 (stalled) | Still waiting — I4 unretired vector LD in ROB |
| Commit | I3 | ROB head now I3, done=Y → **commits** — scalar ST architecturally complete |
| VIQ dispatch check | I4 VLD | Any scalar LD/ST unretired in ROB? → I3 just committed → **NO** → **I4 dispatches to vector unit** → starts, done end of cycle 10 |
| Vector Unit | I4 VLD (1/3) | |

---

### Cycle 9

| Stage | Instruction | Action |
|---|---|---|
| Fetch | I7 (stalled) | I6 still stalled at D&E |
| D&E | I6 (stalled) | I4 is vector LD, not yet committed → stall holds |
| Commit | I4? | ROB head is I4, not done → stalls |
| Vector Unit | I4 VLD (2/3) | |

---

### Cycle 10

| Stage | Instruction | Action |
|---|---|---|
| Fetch | I7 (stalled) | |
| D&E | I6 (stalled) | I4 still not committed |
| Vector Unit | I4 VLD (3/3) ✓ DONE | Result to RSB seq#4, ROB#4 done=Y |
| Commit | I4 | ROB head I4 just done → **commits** |

---

### Cycle 11

| Stage | Instruction | Action |
|---|---|---|
| Fetch | I8 | ROB placeholder seq#8 allocated |
| D&E | I6 | Stall released. Decoded: vector ST, is_mem. ROB#6 filled. **Stall check:** any vector LD/ST unretired? → I4 just committed → **NO stall**. Pushed to VIQ |
| Commit | I5 | ROB head I5, done=Y → **commits** |
| VIQ dispatch check | I6 VST | Any scalar LD/ST unretired? → none → **I6 dispatches to vector unit** → starts, done end of cycle 13 |
| Vector Unit | I6 VST (1/3) | |

---

### Cycle 12

| Stage | Instruction | Action |
|---|---|---|
| Fetch | — | Nothing left |
| D&E | I7 | Decoded: scalar LD, is_mem. ROB#7 filled. **Stall check:** any vector LD/ST unretired in ROB? → I6 is vector ST, not committed → **stall scalar pipeline** — I7 held at D&E |
| D&E | I8 | Stalled behind I7 |
| Vector Unit | I6 VST (2/3) | |
| ROB head | I6 | not done → commit stalls |

---

### Cycle 13

| Stage | Instruction | Action |
|---|---|---|
| D&E | I7 (stalled) | I6 still not committed |
| Vector Unit | I6 VST (3/3) ✓ DONE | Result to RSB seq#6, ROB#6 done=Y |
| Commit | I6 | ROB head I6 just done → **commits** — vector ST architecturally complete |

---

### Cycle 14

| Stage | Instruction | Action |
|---|---|---|
| D&E | I7 | Stall released. **Stall check:** any vector LD/ST unretired? → none → **executes** → result to RSB seq#7, ROB#7 done=Y |
| D&E | I8 | Stalled one cycle behind I7 |
| Commit | I7? | Not yet — I7 needs writeback first |

---

### Cycle 15

| Stage | Instruction | Action |
|---|---|---|
| Writeback | I7 | |
| D&E | I8 | Decoded: scalar ALU. No stall. Executes → result to RSB seq#8, ROB#8 done=Y |
| Commit | I7 | ROB head I7, done=Y → **commits** |

---

### Cycle 16

| Stage | Instruction | Action |
|---|---|---|
| Writeback | I8 | |
| Commit | I8 | ROB head I8, done=Y → **commits** |

---

## Summary of Key Events

| Event | Cycles Stalled | Reason |
|---|---|---|
| I4 VLD held in VIQ | Cycles 5–8 | Scalar ST I3 not yet committed |
| I6 VST stalled at D&E | Cycles 7–11 | Vector LD I4 unretired in ROB |
| I7 LD stalled at D&E | Cycles 12–14 | Vector ST I6 not yet committed |
| I3 result waited in RSB | Cycles 4–8 | Blocked behind I2 at ROB head |
| I5 result waited in RSB | Cycles 6–11 | Blocked behind I2, I3, I4 at ROB head |

---

## What This Trace Exercises

- **Vector ALU never causes stalls** — I2 VADD ran freely and neither caused nor triggered any memory stall
- **Both directions of memory hazard** — scalar ST → vector LD (I3→I4) and vector ST → scalar LD (I6→I7) both correctly stalled
- **Stall check at D&E** — I6 was stalled mid-pipeline at D&E, not at Fetch, confirming stall logic fires at D&E when full decode info is available
- **ROB head blocking commit** — results sat in RSB for many cycles waiting for long-running vector ops to commit first
- **Clean serialization invariant held** — at no point did two memory instructions from opposite sides overlap in execution