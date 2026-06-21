# ================================================================
#  RISC-V Vector Assembly — 8-bit Version
#  VLEN=128, SEW=e8, LMUL=m1 → 128/8 = 16 elements per register
#  vec1 = [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16]
#  vec2 = [2,4,6,8,10,12,14,16,18,20,22,24,26,28,30,32]
# ================================================================

.section .data
vec1:    .byte  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14, 15, 16
vec2:    .byte  2,  4,  6,  8, 10, 12, 14, 16, 18, 20, 22, 24, 26, 28, 30, 32
res_vv:  .byte  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0
res_vi:  .byte  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0
res_vx:  .byte  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0

.section .text
.globl _start

_start:
    # ══ 1. MSTATUS — VECTOR ENABLE ══
    addi t0, x0, 0x600
    csrrs x0, mstatus, t0

    # ══ 2. VECTOR SETUP ══
    # VLEN=128, e8 → 128/8 = 16 elements
    addi a1, x0, 16
    vsetvli a1, a1, e8, m1, ta, ma

    # ══ 3. LOAD vec1 → v1, vec2 → v2 ══
    la    a0, vec1
    vle8.v v1, (a0)         # v1 = [1,2,3,...,16]

    la    a2, vec2
    vle8.v v2, (a2)         # v2 = [2,4,6,...,32]

    # ══ 4. SCALAR REGISTER VALUES ══
    # NOTE: e8 mein shift amount sirf 3 bits valid hai (0-7)
    li s0, 5        # s0 = 5
    li s1, 3        # s1 = 3   (e8 mein 10 shift nahi — max 7)
    li s2, 2        # s2 = 2
    li s3, 6        # s3 = 6
    li s4, 7        # s4 = 7   (e8 ke liye 15 overflow — max 127 signed)
    li s5, 1        # s5 = 1
    li s6, 4        # s6 = 4   (e8 ke liye 12 fit — 0..127)
    li t3, 2        # t3 = 2   (vsll shift amount)
    li t4, 1        # t4 = 1   (vsrl shift amount)

    # ════════════════════════════════
    # ══ VI FORM (vector-immediate) ══
    # ════════════════════════════════
    vadd.vi   v0,  v1,  5       # v0  = v1 + 5       = [6,7,8,...,21]
    vadd.vi   v1,  v0,  3       # v1  = v0 + 3       = [9,10,11,...,24]
    vrsub.vi  v2,  v1, -1       # v2  = -1 - v1      = [-10,-11,...,-25]
    vor.vi    v3,  v2,  1       # v3  = v2 | 1
    vxor.vi   v4,  v3, -7       # v4  = v3 ^ (-7)
    vand.vi   v5,  v4,  15      # v5  = v4 & 15
    vsll.vi   v5,  v4,  2       # v5  = v4 << 2      (e8: max shift=7)
    vsrl.vi   v6,  v5,  1       # v6  = v5 >> 1  (logical)
    vsra.vi   v7,  v6,  1       # v7  = v6 >> 1  (arithmetic, e8: max=7)
    vmseq.vi  v8,  v7,  0       # v8  = (v7 == 0)   mask
    vmsne.vi  v9,  v7,  1       # v9  = (v7 != 1)   mask
    vmsleu.vi v10, v7,  5       # v10 = (v7 <=u 5)  mask
    vmsle.vi  v11, v7,  3       # v11 = (v7 <= 3)   mask
    vmsgtu.vi v12, v7,  2       # v12 = (v7 >u 2)   mask
    vmsgt.vi  v13, v7,  4       # v13 = (v7 > 4)    mask
    vmv.v.i   v14, 7            # v14 = [7,7,...,7]  (16 elements)

    # ════════════════════════════════
    # ══ VV FORM (vector-vector) ══
    # ════════════════════════════════
    vadd.vv   v4,  v1, v2       # v4  = v1 + v2
    vsub.vv   v5,  v2, v1       # v5  = v2 - v1
    vand.vv   v7,  v1, v2       # v7  = v1 & v2
    vor.vv    v8,  v4, v5       # v8  = v4 | v5
    vxor.vv   v9,  v1, v2       # v9  = v1 ^ v2
    vsll.vv   v11, v1, v2       # v11 = v1 << v2  (only lower 3 bits of v2 used)
    vsrl.vv   v12, v1, v2       # v12 = v1 >> v2  logical
    vsra.vv   v13, v1, v2       # v13 = v1 >> v2  arithmetic
    vmseq.vv  v14, v1, v2       # v14 = (v1 == v2) mask
    vmsne.vv  v15, v1, v2       # v15 = (v1 != v2) mask
    vmsltu.vv v16, v1, v2       # v16 = (v1 <u v2) mask
    vmslt.vv  v17, v1, v2       # v17 = (v1 <  v2) mask
    vmsleu.vv v18, v1, v2       # v18 = (v1 <=u v2) mask
    vmsle.vv  v19, v1, v2       # v19 = (v1 <= v2) mask
    vmin.vv   v20, v1, v2       # v20 = min(v1,v2)  signed
    vminu.vv  v21, v1, v2       # v21 = min(v1,v2)  unsigned
    vmax.vv   v22, v1, v2       # v22 = max(v1,v2)  signed
    vmaxu.vv  v23, v1, v2       # v23 = max(v1,v2)  unsigned
    vmv.v.v   v24, v1           # v24 = v1 (copy)

    # ════════════════════════════════
    # ══ VX FORM (vector-scalar) ══
    # ════════════════════════════════
    vadd.vx   v17, v1, s0       # v17 = v1 + 5
    vsub.vx   v18, v2, s1       # v18 = v2 - 3
    vand.vx   v20, v2, s4       # v20 = v2 & 7
    vor.vx    v21, v4, s5       # v21 = v4 | 1
    vxor.vx   v22, v1, s6       # v22 = v1 ^ 4
    vsll.vx   v23, v1, t3       # v23 = v1 << 2
    vsrl.vx   v24, v2, t4       # v24 = v2 >> 1  logical
    vsrl.vx   v26, v1, s1       # v26 = v1 >> 3  logical
    vsra.vx   v27, v2, s2       # v27 = v2 >> 2  arithmetic
    vmseq.vx  v28, v1, s0       # v28 = (v1 == 5)  mask
    vmsne.vx  v29, v1, s1       # v29 = (v1 != 3)  mask
    vmsltu.vx v30, v1, s2       # v30 = (v1 <u 2)  mask
    vmslt.vx  v31, v1, s3       # v31 = (v1 <  6)  mask
    vmsleu.vx v28, v2, s4       # v28 = (v2 <=u 7) mask
    vmsle.vx  v29, v2, s5       # v29 = (v2 <= 1)  mask
    vmsgtu.vx v30, v2, s6       # v30 = (v2 >u 4)  mask
    vmsgt.vx  v31, v2, s0       # v31 = (v2 >  5)  mask
    vmin.vx   v20, v1, s1       # v20 = min(v1, 3)  signed
    vminu.vx  v21, v2, s2       # v21 = min(v2, 2)  unsigned
    vmax.vx   v22, v1, s3       # v22 = max(v1, 6)  signed
    vmaxu.vx  v23, v2, s4       # v23 = max(v2, 7)  unsigned
    vmv.v.x   v24, s0           # v24 = [5,5,...,5]  (16 elements)

    # ════════════════════════════════
    # ══ MULTIPLICATION ══
    # NOTE: e8 mein results 8-bit mein fit nahi ho sakte
    #       vmulh high bits deta hai — overflow normal hai
    # ════════════════════════════════
    vmul.vv    v6,  v1, v2      # v6  = v1 * v2         (low 8 bits)
    vmulhu.vv  v6,  v5, v1      # v6  = (v5 *u v1) >> 8 (high, unsigned)
    vmulh.vv   v5,  v2, v3      # v5  = (v2 *  v3) >> 8 (high, signed)
    vmulhsu.vv v10, v2, v1      # v10 = (v2 signed * v1 unsigned) >> 8

    vmulh.vx   v11, v2, s0      # v11 = (v2 * 5)  >> 8  signed high
    vmul.vx    v19, v1, s3      # v19 = v1 * 6    low 8 bits
    vmulhu.vx  v12, v2, s0      # v12 = (v2 *u 5) >> 8  unsigned high
    vmulhsu.vx v13, v2, s0      # v13 = (v2 su* 5) >> 8

    # ══ MULTIPLY-ADD ══
    vmacc.vv   v11, v1, v2      # v11 = v11 + v1*v2
    vnmsac.vv  v12, v1, v2      # v12 = v12 - v1*v2
    vnmsub.vv  v14, v1, v2      # v14 = -(v1*v14) + v2
    vmadd.vv   v13, v1, v2      # v13 = v1*v13 + v2

    vmacc.vx   v10, s0, v2      # v10 = v10 + s0*v2
    vnmsac.vx  v10, s0, v2      # v10 = v10 - s0*v2
    vmadd.vx   v10, s0, v2      # v10 = s0*v10 + v2
    vnmsub.vx  v10, s0, v2      # v10 = -(s0*v10) + v2

    # ════════════════════════════════
    # ══ MASK LOGICAL ══
    # ════════════════════════════════
    vmand.mm   v0, v8,  v9      # v0 = v8 AND v9
    vmnand.mm  v0, v8,  v9      # v0 = NOT(v8 AND v9)
    vmandn.mm  v0, v8,  v9      # v0 = v8 AND NOT(v9)
    vmxor.mm   v0, v8,  v9      # v0 = v8 XOR v9
    vmor.mm    v0, v8,  v9      # v0 = v8 OR  v9
    vmnor.mm   v0, v8,  v9      # v0 = NOT(v8 OR v9)
    vmorn.mm   v0, v8,  v9      # v0 = v8 OR NOT(v9)
    vmxnor.mm  v0, v8,  v9      # v0 = NOT(v8 XOR v9)

    # ════════════════════════════════
    # ══ RESULT STORE ══
    # ════════════════════════════════
    la   a3, res_vv
    vse8.v v4, (a3)             # vadd.vv result store

    la   a4, res_vi
    vse8.v v6, (a4)             # vmul result store

    la   a5, res_vx
    vse8.v v17, (a5)            # vadd.vx result store

    # ══ EXIT ══
    addi t0, x0, 1
    lui  t1, %hi(tohost)
    addi t1, t1, %lo(tohost)
    sw   t0, 0(t1)

1:  jal  x0, 1b

.section .tohost
.align 3
tohost:   .dword 0
fromhost: .dword 0