# ================================================================
#  RISC-V Vector Assembly — Fixed Version
#  VLEN=128, SEW=e16, LMUL=m1 → 8 elements per register
#  vec1 = [1,2,3,4,5,6,7,8]
#  vec2 = [10,20,30,40,50,60,70,80]
# ================================================================

.section .data
vec1:    .half  1,  2,  3,  4,  5,  6,  7,  8
vec2:    .half 10, 20, 30, 40, 50, 60, 70, 80
res_vv:  .half  0,  0,  0,  0,  0,  0,  0,  0
res_vi:  .half  0,  0,  0,  0,  0,  0,  0,  0
res_vx:  .half  0,  0,  0,  0,  0,  0,  0,  0

.section .text
.globl _start

_start:
    # ══ 1. MSTATUS — VECTOR ENABLE ══
    addi t0, x0, 0x600
    csrrs x0, mstatus, t0

    # ══ 2. VECTOR SETUP ══
    # VLEN=128, e16 → 128/16 = 8 elements
    addi a1, x0, 8
    vsetvli a1, a1, e16, m1, ta, ma
    # NOTE: li a1,4 hataya — vl overwrite hoti thi

    # ══ 3. LOAD vec1 → v1, vec2 → v2 ══
    la    a0, vec1
    vle16.v v1, (a0)        # v1 = [1,2,3,4,5,6,7,8]

    la    a2, vec2
    vle16.v v2, (a2)        # v2 = [10,20,30,40,50,60,70,80]

    # ══ 4. SCALAR REGISTER VALUES ══
    li s0, 5        # s0 = 5
    li s1, 10       # s1 = 10
    li s2, 3        # s2 = 3
    li s3, 7        # s3 = 7
    li s4, 15       # s4 = 15
    li s5, 2        # s5 = 2
    li s6, 12       # s6 = 12
    li t3, 2        # t3 = 2  (vsll shift amount)
    li t4, 1        # t4 = 1  (vsrl shift amount)

    # ════════════════════════════════
    # ══ VI FORM (vector-immediate) ══
    # ════════════════════════════════
    vadd.vi   v0,  v1,  5       # v0  = v1 + 5       = [6,7,8,9,10,11,12,13]
    vadd.vi   v1,  v0,  3       # v1  = v0 + 3       = [9,10,11,12,13,14,15,16]
    vrsub.vi  v2,  v1, -1       # v2  = -1 - v1      = [-10,-11,-12,-13,-14,-15,-16,-17]
    vor.vi    v3,  v2,  1       # v3  = v2 | 1
    vxor.vi   v4,  v3, -7       # v4  = v3 ^ (-7)
    vand.vi   v5,  v4,  15      # v5  = v4 & 15
    vsll.vi   v5,  v4,  3       # v5  = v4 << 3
    vsrl.vi   v6,  v5,  1       # v6  = v5 >> 1  (logical)
    vsra.vi   v7,  v6,  2       # v7  = v6 >> 2  (arithmetic)
    vmseq.vi  v8,  v7,  0       # v8  = (v7 == 0)   mask
    vmsne.vi  v9,  v7,  1       # v9  = (v7 != 1)   mask
    vmsleu.vi v10, v7,  5       # v10 = (v7 <=u 5)  mask
    vmsle.vi  v11, v7,  3       # v11 = (v7 <= 3)   mask
    vmsgtu.vi v12, v7,  2       # v12 = (v7 >u 2)   mask
    vmsgt.vi  v13, v7,  4       # v13 = (v7 > 4)    mask
    vmv.v.i   v14, 7            # v14 = [7,7,7,7,7,7,7,7]

    # ════════════════════════════════
    # ══ VV FORM (vector-vector) ══
    # ════════════════════════════════
    vadd.vv   v4,  v1, v2       # v4  = v1 + v2
    vsub.vv   v5,  v2, v1       # v5  = v2 - v1
    vand.vv   v7,  v1, v2       # v7  = v1 & v2
    vor.vv    v8,  v4, v5       # v8  = v4 | v5
    vxor.vv   v9,  v1, v2       # v9  = v1 ^ v2
    vsll.vv   v11, v1, v2       # v11 = v1 << v2
    vsrl.vv   v12, v1, v2       # v12 = v1 >> v2  (logical)
    vsra.vv   v13, v1, v2       # v13 = v1 >> v2  (arithmetic)
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
    vsub.vx   v18, v2, s1       # v18 = v2 - 10
    vand.vx   v20, v2, s4       # v20 = v2 & 15
    vor.vx    v21, v4, s5       # v21 = v4 | 2
    vxor.vx   v22, v1, s6       # v22 = v1 ^ 12
    vsll.vx   v23, v1, t3       # v23 = v1 << 2
    vsrl.vx   v24, v2, t4       # v24 = v2 >> 1  (logical)
    vsrl.vx   v26, v1, s1       # v26 = v1 >> 10 (logical)
    vsra.vx   v27, v2, s2       # v27 = v2 >> 3  (arithmetic)
    vmseq.vx  v28, v1, s0       # v28 = (v1 == 5)  mask
    vmsne.vx  v29, v1, s1       # v29 = (v1 != 10) mask
    vmsltu.vx v30, v1, s2       # v30 = (v1 <u 3)  mask
    vmslt.vx  v31, v1, s3       # v31 = (v1 <  7)  mask
    vmsleu.vx v28, v2, s4       # v28 = (v2 <=u 15) mask
    vmsle.vx  v29, v2, s5       # v29 = (v2 <= 2)  mask
    vmsgtu.vx v30, v2, s6       # v30 = (v2 >u 12) mask
    vmsgt.vx  v31, v2, s0       # v31 = (v2 >  5)  mask
    vmin.vx   v20, v1, s1       # v20 = min(v1, 10) signed
    vminu.vx  v21, v2, s2       # v21 = min(v2, 3)  unsigned
    vmax.vx   v22, v1, s3       # v22 = max(v1, 7)  signed
    vmaxu.vx  v23, v2, s4       # v23 = max(v2, 15) unsigned
    vmv.v.x   v24, s0           # v24 = [5,5,5,5,5,5,5,5]

    # ════════════════════════════════
    # ══ MULTIPLICATION ══
    # ════════════════════════════════
    vmul.vv    v6,  v1, v2      # v6  = v1 * v2         (low half)
    vmulhu.vv  v6,  v5, v1      # v6  = (v5 *u v1) >> SEW (high, unsigned)
    vmulh.vv   v5,  v2, v3      # v5  = (v2 *  v3) >> SEW (high, signed)
    vmulhsu.vv v10, v2, v1      # v10 = (v2 signed * v1 unsigned) >> SEW

    vmulh.vx   v11, v2, s0      # v11 = (v2 * 5)  >> SEW signed high
    vmul.vx    v19, v1, s3      # v19 = v1 * 7    low half
    vmulhu.vx  v12, v2, s0      # v12 = (v2 *u 5) >> SEW unsigned high
    vmulhsu.vx v13, v2, s0      # v13 = (v2 su* 5) >> SEW

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
    vmand.mm   v0, v8,  v9      # v0 = v8 AND v9   (mask AND mask)
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
    vse16.v v4, (a3)            # vadd.vv result store karo

    la   a4, res_vi
    vse16.v v6, (a4)            # vmul result store karo

    la   a5, res_vx
    vse16.v v17, (a5)           # vadd.vx result store karo

    # ══ 7. EXIT ══
    addi t0, x0, 1
    lui  t1, %hi(tohost)
    addi t1, t1, %lo(tohost)
    sw   t0, 0(t1)

1:  jal  x0, 1b

.section .tohost
.align 3
tohost:   .dword 0
fromhost: .dword 0