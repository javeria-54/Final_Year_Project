# ================================================================
# Conv1D Stride=1  —  Multi-Channel
# Target: RISC-V RVV  |  VLEN=128, SEW=32, LMUL=1  →  VLMAX=4
#
# Computes:
#   Z[b, c_out, i] = bias[c_out]
#                  + Σ_{c_in=0}^{C_in-1}  Σ_{k=0}^{K-1}
#                    W[c_out, c_in, k] · A[b, c_in, i+k]
#
# Memory layout (int32 / .word, row-major C order):
#   input   [batch_size][in_channels][input_size]
#   kernel  [out_channels][in_channels][kernel_size]
#   bias    [out_channels]
#   output  [batch_size][out_channels][output_size]
#
#   output_size = input_size - kernel_size + 1
#
# Configuration for this file:
#   batch_size = 1, in_channels = 2, out_channels = 2,
#   kernel_size = 3, input_size = 6  →  output_size = 4
#
# ── Register allocation ─────────────────────────────────────────
#
#  Saved regs — set once in prologue, read-only after:
#   s0  batch_size
#   s1  in_channels
#   s2  out_channels
#   s3  kernel_size
#   s4  input_size
#   s5  output_size
#   s6  in_ch_stride_B        = input_size  × 4
#   s7  ker_inch_stride_B     = kernel_size × 4
#   s8  ker_outch_stride_B    = in_channels × kernel_size × 4
#   s9  out_ch_stride_B       = output_size × 4
#   s10 batch_inp_stride_B    = in_channels × input_size  × 4
#   s11 batch_out_stride_B    = out_channels× output_size × 4
#
#  Base pointers — set once, never modified:
#   a0  &input[0]
#   a1  &kernel[0]
#   a2  &bias[0]
#   a3  &output[0]
#
#  Batch loop:
#   a4  &input[b,0,0]         += s10 per batch
#   a5  &output[b,0,0]        += s11 per batch
#   t6  batch counter (↓)     only decremented in next_batch
#
#  Out-channel loop:
#   a6  &kernel[c_out,0,0]    += s8 per c_out
#   a7  &output[b,c_out,0]    += s9 per c_out
#   t5  out_ch counter (↓)    only decremented in next_out_ch
#   t4  bias[c_out]            loaded once per c_out, read-only inside
#
#  Output-position (vector chunk) loop — three live values:
#   t1  input  pos-ptr         += vl×4 per chunk
#   t2  output pos-ptr         += vl×4 per chunk
#   t3  remaining positions    -= vl   per chunk
#
#  Inside the in-channel loop t1/t2/t3 must be preserved.
#  We save vl on the stack so t0 is free as scratch:
#   0(sp) = vl                 spilled before in_ch_loop
#   4(sp) = (unused slot)
#
#  In-channel loop:
#   ra   &kernel[c_out,c_in,0] += s7 per c_in   (leaf fn; ra safe to use)
#   gp   &input[b,c_in,pos]    += s6 per c_in
#   tp   c_in counter (↓)
#   t0   scratch: address offsets and scalar weights  (vl already spilled)
#
#  Vector registers:
#   v0,v1,v2  input tap slices
#   v8        accumulator
#
# Stack frame: 8 bytes (16-byte alignment maintained)
# ================================================================

.section .data

.align 2
input:
    .word 10, 20, 30, 40, 50, 60   # batch=0, ch=0
    .word  5, 15, 25, 35, 45, 55   # batch=0, ch=1

.align 2
kernel:
    .word  1,  0, -1   # c_out=0, c_in=0
    .word  2,  1,  0   # c_out=0, c_in=1
    .word  0,  1,  2   # c_out=1, c_in=0
    .word  1,  1,  1   # c_out=1, c_in=1

.align 2
bias:
    .word 1, 0

.align 2
batch_size:    .word 1
in_channels:   .word 2
out_channels:  .word 2
kernel_size:   .word 3
input_size:    .word 6

.align 2
output:
    .space 32   # [1][2][4] × 4 B

# ── Expected output ──────────────────────────────────────────────
# Z[0,0,:] = [  6,  36,  66,  96 ]
# Z[0,1,:] = [125, 185, 245, 305 ]
#
# Manual check (i=0):
#   c_out=0: (10×1+20×0+30×-1) + (5×2+15×1+25×0) + 1 = -20+25+1 =   6  ✓
#   c_out=1: (10×0+20×1+30×2) + (5×1+15×1+25×1) + 0 =  80+45+0  = 125  ✓
# ================================================================

.section .text
.global _start

_start:
    # ══ 1. MSTATUS — VECTOR ENABLE ══
    li   t0, 0x600           # VS=1 (bits 9:8 = 01) to enable vector extension
    csrrs x0, mstatus, t0

    # ══ 2. VLENB READ (optional, for debug) ══
    csrrs t0, vlenb, x0

    addi sp, sp, -8        # 8-byte stack frame (vl spill slot at 0(sp))

    # ── Load dimensions ──────────────────────────────────────────
    la   t0, batch_size;    lw s0, 0(t0)
    la   t0, in_channels;   lw s1, 0(t0)
    la   t0, out_channels;  lw s2, 0(t0)
    la   t0, kernel_size;   lw s3, 0(t0)
    la   t0, input_size;    lw s4, 0(t0)
    sub  s5, s4, s3
    addi s5, s5, 1             # s5 = output_size

    # ── Byte strides ─────────────────────────────────────────────
    slli s6,  s4, 2            # in_ch_stride_B
    slli s7,  s3, 2            # ker_inch_stride_B
    mul  t0,  s1, s3
    slli s8,  t0, 2            # ker_outch_stride_B
    slli s9,  s5, 2            # out_ch_stride_B
    mul  t0,  s1, s4
    slli s10, t0, 2            # batch_inp_stride_B
    mul  t0,  s2, s5
    slli s11, t0, 2            # batch_out_stride_B

    # ── Base pointers ─────────────────────────────────────────────
    la   a0, input
    la   a1, kernel
    la   a2, bias
    la   a3, output

    # ════════════════════════════════════════════════════════════
    # BATCH LOOP
    # ════════════════════════════════════════════════════════════
    mv   a4, a0               # a4 = &input[b=0, ...]
    mv   a5, a3               # a5 = &output[b=0, ...]
    mv   t6, s0               # batch counter

batch_loop:
    beqz t6, epilogue

    # ──────────────────────────────────────────────────────────
    # OUT-CHANNEL LOOP
    # ──────────────────────────────────────────────────────────
    mv   a6, a1               # a6 = &kernel[c_out=0, ...]
    mv   a7, a5               # a7 = &output[b, c_out=0, ...]
    mv   t5, s2               # out_ch counter

out_ch_loop:
    beqz t5, next_batch

    # bias[c_out] = bias[ s2 - t5 ]
    sub  t0, s2, t5
    slli t0, t0, 2
    add  t0, a2, t0
    lw   t4, 0(t0)            # t4 = bias[c_out]  (stable in inner loops)

    # ──────────────────────────────────────────────────────────
    # OUTPUT-POSITION (VECTOR CHUNK) LOOP
    # ──────────────────────────────────────────────────────────
    mv   t1, a4               # t1 = &A[b, 0, pos=0]
    mv   t2, a7               # t2 = &Z[b, c_out, pos=0]
    mv   t3, s5               # t3 = remaining output positions

output_pos_loop:
    beqz t3, next_out_ch

    # vl = min(t3, VLMAX=4);  SEW=32 LMUL=1 VLEN=128
    vsetvli t0, t3, e32, m1   # t0 = vl

    vmv.v.i v8, 0              # clear accumulator for this chunk

    # Spill vl → 0(sp) so t0 is scratch inside in_ch_loop.
    # t1, t2, t3 are live; they are NOT used inside in_ch_loop body.
    sw   t0, 0(sp)

    # ─────────────────────────────────────────────────────────
    # IN-CHANNEL LOOP
    #
    # ra = &W[c_out, c_in, 0]   advances by s7
    # gp = &A[b, c_in, pos]     advances by s6
    # tp = c_in counter
    # t0 = scratch (vl was spilled)
    # t1, t2, t3 untouched
    # ─────────────────────────────────────────────────────────
    mv   ra, a6               # ra = &W[c_out, 0, 0]
    mv   gp, t1               # gp = &A[b, 0, pos]
    mv   tp, s1               # tp = in_channels

in_ch_loop:
    beqz tp, chunk_done

    # Tap k=0:  load A[b,c_in,pos..pos+vl-1], multiply by W[k=0]
    vle32.v  v0, (gp)          # v0 = A[..., pos+0]
    lw       t0, 0(ra)         # t0 = W[k=0]
    vmul.vx  v0, v0, t0
    vadd.vv  v8, v8, v0

    # Tap k=1:  base gp+4
    addi     t0, gp, 4         # t0 = &A[..., pos+1]
    vle32.v  v1, (t0)
    lw       t0, 4(ra)         # t0 = W[k=1]
    vmul.vx  v1, v1, t0
    vadd.vv  v8, v8, v1

    # Tap k=2:  base gp+8
    addi     t0, gp, 8         # t0 = &A[..., pos+2]
    vle32.v  v2, (t0)
    lw       t0, 8(ra)         # t0 = W[k=2]
    vmul.vx  v2, v2, t0
    vadd.vv  v8, v8, v2

    add      ra, ra, s7        # kernel → next c_in row
    add      gp, gp, s6        # input  → next c_in row
    addi     tp, tp, -1
    j        in_ch_loop

chunk_done:
    # Restore vl
    lw   t0, 0(sp)

    # Broadcast-add bias
    vadd.vx  v8, v8, t4

    # Store vl results to output
    vse32.v  v8, (t2)

    # Advance position pointers by vl elements
    slli t0, t0, 2             # t0 = vl × 4  (byte offset)
    add  t1, t1, t0            # input  ptr += vl×4
    add  t2, t2, t0            # output ptr += vl×4
    lw   t0, 0(sp)             # reload vl (we just overwrote t0)
    sub  t3, t3, t0            # remaining -= vl
    j    output_pos_loop

    # ──────────────────────────────────────────────────────────
next_out_ch:
    add  a6, a6, s8            # kernel → next c_out
    add  a7, a7, s9            # output → next c_out
    addi t5, t5, -1
    j    out_ch_loop

    # ──────────────────────────────────────────────────────────
next_batch:
    add  a4, a4, s10           # input  → next batch
    add  a5, a5, s11           # output → next batch
    addi t6, t6, -1
    j    batch_loop

    # ──────────────────────────────────────────────────────────
epilogue:
    addi sp, sp, 8

    # ══ SPIKE EXIT SEQUENCE ══
    li   t0, 1
    lui  t1, %hi(tohost)
    addi t1, t1, %lo(tohost)
    sw   t0, 0(t1)

1:  jal  x0, 1b

.section .tohost
.align 3
tohost:   .dword 0
fromhost: .dword 0
