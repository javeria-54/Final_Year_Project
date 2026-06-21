.section .data

.align 2
a:  .byte 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16
b:  .byte 10,20,30,40,50,60,70,80,90,100,110,120,130,140,150,160

.align 2
result_scalar: .space 16
result_vector: .space 16

# ================================================================
.section .text
.global _start

_start:
    # ── Vector Enable ──
    li    t0, 0x600
    csrrs x0, mstatus, t0

    # ── Base pointers ──
    la    a0, a               # a0 = &a[0]
    la    a1, b               # a1 = &b[0]
    la    a2, result_scalar   # a2 = &result_scalar[0]
    la    a3, result_vector   # a3 = &result_vector[0]

# ================================================================
# SCALAR LOOP — ek baar ek element
# ================================================================
    li    t3, 16              # counter = 16
    mv    t0, a0              # t0 = &a[0]
    mv    t1, a1              # t1 = &b[0]
    mv    t2, a2              # t2 = &result_scalar[0]

scalar_loop:
    beqz  t3, scalar_done

    lb    t4, 0(t0)           # t4 = a[i]
    lb    t5, 0(t1)           # t5 = b[i]
    add   t4, t4, t5          # t4 = a[i] + b[i]
    sb    t4, 0(t2)           # result_scalar[i] = t4

    addi  t0, t0, 1           # a ptr++
    addi  t1, t1, 1           # b ptr++
    addi  t2, t2, 1           # result ptr++
    addi  t3, t3, -1          # counter--
    j     scalar_loop

scalar_done:

# ================================================================
# VECTOR — ek hi baar 16 elements
# VLEN=128, SEW=8, LMUL=1 → VLMAX = 128/8 = 16
# ================================================================
    li    t0, 16
    vsetvli t0, t0, e8, m1    # vl = 16, SEW=8

    vle8.v  v0, (a0)          # v0 = a[0..15]  — 16 load ek baar
    vle8.v  v1, (a1)          # v1 = b[0..15]  — 16 load ek baar

    vadd.vv v2, v0, v1        # v2 = v0 + v1   — 16 add ek baar

    vse8.v  v2, (a3)          # result_vector store — 16 baar ek baar

# ================================================================
# SPIKE EXIT
# ================================================================
    li    t0, 1
    lui   t1, %hi(tohost)
    addi  t1, t1, %lo(tohost)
    sw    t0, 0(t1)
1:  j     1b

.section .tohost
.align 3
tohost:   .dword 0
fromhost: .dword 0