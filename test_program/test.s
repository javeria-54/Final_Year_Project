.section .data
vec1:    .word  1,  2,  3,  4
vec2:    .word 10, 20, 30, 40
res_vv:  .word  0,  0,  0,  0
res_vi:  .word  0,  0,  0,  0
res_vx:  .word  0,  0,  0,  0

.section .text
.globl _start

_start:
    # csrrs zero, mstatus, t0  — t0 abhi set nahi, pehle set karo
    addi t0, x0, 0x600
    csrrs x0, mstatus, t0

    # csrr t0, vlenb
    csrrs t0, vlenb, x0

# ══ 1. SCALAR REGISTER FILL ══

    addi t0, x0, 10
    addi t1, x0, 20
    addi t2, x0, 5
    addi t3, x0, 3
    addi t4, x0, 7

    add  s0, t0, t1
    sub  s1, s0, t2
    mul  s2, t1, t3
    div  s3, s2, t3

    and  s4, t0, t1
    or   s5, s0, s1
    xor  s6, t0, t2

    slli s7, t1, 2
    srli s8, s2, 1
    srai s9, s2, 1

    sub  a0, t0, t1
    bge  a0, x0, scalar_done
    sub  a0, x0, a0

scalar_done:

# ══ 2. VECTOR SETUP ══

    addi a1, x0, 4
    vsetvli a1, a1, e32, m1, ta, ma

# ══ 3. VECTOR LOAD/STORE ══

    lui  a2, %hi(vec1)
    addi a2, a2, %lo(vec1)
    vle32.v v1, (a2)

    lui  a3, %hi(vec2)
    addi a3, a3, %lo(vec2)
    vle32.v v2, (a3)

    lui  a4, %hi(res_vv)
    addi a4, a4, %lo(res_vv)
    vse32.v v1, (a4)

# ══ 4. VV FORM ══

    vadd.vv v4, v1, v2
    vsub.vv v5, v2, v1
    vmul.vv v6, v1, v2
    vand.vv v7, v1, v2
    vor.vv  v8, v4, v5
    vxor.vv v9, v1, v2

    lui  a4, %hi(res_vv)
    addi a4, a4, %lo(res_vv)
    vse32.v v4, (a4)

# ══ 5. VI FORM ══

    vadd.vi  v10, v1,  5
    vand.vi  v12, v4, 15
    vor.vi   v13, v1,  1
    vxor.vi  v14, v2,  7
    vsll.vi  v15, v1,  3
    vsrl.vi  v16, v2,  1

    lui  a5, %hi(res_vi)
    addi a5, a5, %lo(res_vi)
    vse32.v v10, (a5)

# ══ 6. VX FORM ══

    vadd.vx  v17, v1, s0
    vsub.vx  v18, v2, s1
    vmul.vx  v19, v1, s3
    vand.vx  v20, v2, s4
    vor.vx   v21, v4, s5
    vxor.vx  v22, v1, s6
    vsll.vx  v23, v1, t3
    vsrl.vx  v24, v2, t4

    lui  a6, %hi(res_vx)
    addi a6, a6, %lo(res_vx)
    vse32.v v17, (a6)

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