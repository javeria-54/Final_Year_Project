.section .data
vec1:    .word  1,  2,  3,  4
vec2:    .word 10, 20, 30, 40
res_vv:  .word  0,  0,  0,  0
res_vi:  .word  0,  0,  0,  0
res_vx:  .word  0,  0,  0,  0

.section .text
.globl _start

_start:
    # ══ 1. MSTATUS — VECTOR ENABLE ══
    addi t0, x0, 0x600
    csrrs x0, mstatus, t0

    # ══ VLENB READ ══
    csrrs t0, vlenb, x0
    li t0, 0x10


    # ══ 2. VECTOR SETUP ══
    addi a1, x0, 4
    vsetvli a1, a1, e32, m1, ta, ma
    li a1, 4

    # Scalar register values assign karo
    li s0, 5        # s0 = 5
    li s1, 10       # s1 = 10
    li s2, 3        # s2 = 3
    li s3, 7        # s3 = 7
    li s4, 15       # s4 = 15
    li s5, 2        # s5 = 2
    li s6, 12       # s6 = 12
    li t3, 2        # t3 = 2  (vsll shift amount)
    li t4, 1        # t4 = 1  (vsrl shift amount)

    # ══ VI FORM ══
    vadd.vi   v0, v1,  5
    vadd.vi   v1, v0,  3
    vrsub.vi  v2, v1, -1
    vor.vi    v3, v2,  1
    vxor.vi   v4, v3, -7
    vand.vi   v5, v4,  15
    vsll.vi   v5, v4,  3
    vsrl.vi   v6, v5,  1
    vsra.vi   v7, v6,  2
    vmseq.vi  v8, v7,  0
    vmsne.vi  v9, v7,  1
    vmsleu.vi v10, v7, 5
    vmsle.vi  v11, v7, 3
    vmsgtu.vi v12, v7, 2
    vmsgt.vi  v13, v7, 4
    vmv.v.i   v14, 7
       
    # ══ 4. VV FORM ══
    vadd.vv   v4,  v1, v2
    vsub.vv   v5,  v2, v1
    vand.vv   v7,  v1, v2
    vor.vv    v8,  v4, v5
    vxor.vv   v9,  v1, v2
    vsll.vv   v11, v1, v2
    vsrl.vv   v12, v1, v2
    vsra.vv   v13, v1, v2
    vmseq.vv  v14, v1, v2
    vmsne.vv  v15, v1, v2
    vmsltu.vv v16, v1, v2
    vmslt.vv  v17, v1, v2
    vmsleu.vv v18, v1, v2
    vmsle.vv  v19, v1, v2
    vmin.vv   v20, v1, v2
    vminu.vv  v21, v1, v2
    vmax.vv   v22, v1, v2
    vmaxu.vv  v23, v1, v2
    vmv.v.v   v24, v1
   
    # ══ 6. VX FORM ══
    vadd.vx   v17, v1, s0
    vsub.vx   v18, v2, s1
    vand.vx   v20, v2, s4
    vor.vx    v21, v4, s5
    vxor.vx   v22, v1, s6
    vsll.vx   v23, v1, t3
    vsrl.vx   v24, v2, t4
    vsrl.vx   v26, v1, s1
    vsra.vx   v27, v2, s2
    vmseq.vx  v28, v1, s0
    vmsne.vx  v29, v1, s1
    vmsltu.vx v30, v1, s2
    vmslt.vx  v31, v1, s3
    vmsleu.vx v28, v2, s4
    vmsle.vx  v29, v2, s5
    vmsgtu.vx v30, v2, s6
    vmsgt.vx  v31, v2, s0
    vmin.vx   v20, v1, s1
    vminu.vx  v21, v2, s2
    vmax.vx   v22, v1, s3
    vmaxu.vx  v23, v2, s4
    vmv.v.x   v24, s0

    # ══ MULTIPLICATION ══
    vmul.vv   v6,  v1, v2
    vmulhu.vv v6,  v5, v1
    vmulh.vv  v5,  v2, v3
    vmulhsu.vv v10, v2, v1

    vmulh.vx  v11, v2, s0
    vmul.vx   v19, v1, s3
    vmulhu.vx v12, v2, s0
    vmulhsu.vx v13, v2, s0

    vmacc.vv  v11, v1, v2
    vnmsac.vv v12, v1, v2
    vnmsub.vv v14, v1, v2
    vmadd.vv  v13, v1, v2

    vmacc.vx  v10, s0, v2
    vnmsac.vx v10, s0, v2
    vmadd.vx  v10, s0, v2
    vnmsub.vx v10, s0, v2

    # ══ MASK LOGICAL ══
    vmand.mm  v0, v1, v2
    vmnand.mm v0, v1, v2
    vmandn.mm v0, v1, v2
    vmxor.mm  v0, v1, v2
    vmor.mm   v0, v1, v2
    vmnor.mm  v0, v1, v2
    vmorn.mm  v0, v1, v2
    vmxnor.mm v0, v1, v2
   
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
