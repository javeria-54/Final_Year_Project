# ============================================================
#  RISC-V Assembly - All Instruction Types Test (FIXED v2)
#  Fix: .align directives for half_arr and result
# ============================================================

.section .tohost
.align 3
tohost:   .dword 0
fromhost: .dword 0

.data
.align 2
array:      .word   0x5b970814, 0x1fce758d, 0x3642b24a, 40, 50   # 4-byte aligned (word)

byte_arr:   .byte   0xAA, 0xBB, 0xCC     # 3 bytes — next addr will be odd!

.align 1                                  # FIX: pad to 2-byte boundary
half_arr:   .half   0x1234, 0x5678       # 2-byte aligned (halfword) ✓

.align 2                                  # FIX: pad to 4-byte boundary
result:     .word   0                    # 4-byte aligned (word) ✓

.text
.globl _start
_start:

# ============================================================
# 1) R-TYPE
# ============================================================
    li      t0, 15
    li      t1, 7

    add     t2, t0, t1      # t2 = 22   (ADD)
    sub     t3, t0, t1      # t3 = 8    (SUB)
    mul     t4, t0, t1      # t4 = 105  (MUL)
    div     t5, t0, t1      # t5 = 2    (DIV)
    rem     t6, t0, t1      # t6 = 1    (REM)

    li      s0, 12
    li      s1, 10

    and     s2, s0, s1      # s2 = 8    (AND)
    or      s3, s0, s1      # s3 = 14   (OR)
    xor     s4, s0, s1      # s4 = 6    (XOR)

    li      a0, 1
    li      a1, 3

    sll     a2, a0, a1      # a2 = 8    (SLL)
    srl     a3, a2, a1      # a3 = 1    (SRL)
    sra     a4, a2, a1      # a4 = 1    (SRA)

    slt     a5, t1, t0      # a5 = 1    (SLT)
    sltu    a6, t1, t0      # a6 = 1    (SLTU)

# ============================================================
# 2) I-TYPE
# ============================================================
    li      s0, 100

    addi    s1, s0, 25      # s1 = 125
    addi    s2, s0, -10     # s2 = 90
    andi    s3, s0, 0xF0    # s3 = 96
    ori     s4, s0, 0x0F    # s4 = 111
    xori    s5, s0, 0xFF    # s5 = 155
    slti    s6, s0, 200     # s6 = 1
    sltiu   s7, s0, 50      # s7 = 0

    slli    t0, s0, 2       # t0 = 400
    srli    t1, t0, 1       # t1 = 200
    srai    t2, t0, 2       # t2 = 100

# ============================================================
# 3) LOAD  (I-Type encoding)
# ============================================================
    la      a0, array

    lw      t0, 0(a0)       # t0 = 10   (LW)
    lw      t1, 4(a0)       # t1 = 20   (LW)
    lw      t2, 8(a0)       # t2 = 30   (LW)

    la      a1, byte_arr
    lb      t3, 0(a1)       # t3 = 0xAA (LB  sign-ext)
    lbu     t4, 1(a1)       # t4 = 0xBB (LBU zero-ext)

    la      a2, half_arr    # a2 = 2-byte aligned address ✓
    lh      t5, 0(a2)       # t5 = 0x1234 (LH)
    lhu     t6, 2(a2)       # t6 = 0x5678 (LHU)

# ============================================================
# 4) S-TYPE (STORE)
# ============================================================
    la      a3, result      # 4-byte aligned ✓

    li      t0, 0x0000BEEF
    sw      t0, 0(a3)       # SW

    li      t1, 0x42
    sb      t1, 0(a3)       # SB

    li      t2, 0x1234
    sh      t2, 0(a3)       # SH  (result is 4-byte aligned so 2-byte ok)

# ============================================================
# 5) B-TYPE (Branches)
# ============================================================
    li      t0, 10
    li      t1, 20
    li      t2, 10

    beq     t0, t2, beq_taken
    j       beq_skip
beq_taken:
    addi    a0, x0, 1
beq_skip:

    bne     t0, t1, bne_taken
    j       bne_skip
bne_taken:
    addi    a0, x0, 2
bne_skip:

    blt     t0, t1, blt_taken
    j       blt_skip
blt_taken:
    addi    a0, x0, 3
blt_skip:

    bge     t1, t0, bge_taken
    j       bge_skip
bge_taken:
    addi    a0, x0, 4
bge_skip:

    bltu    t0, t1, bltu_taken
    j       bltu_skip
bltu_taken:
    addi    a0, x0, 5
bltu_skip:

    bgeu    t1, t0, bgeu_taken
    j       bgeu_skip
bgeu_taken:
    addi    a0, x0, 6
bgeu_skip:

# ============================================================
# 6) U-TYPE
# ============================================================
    lui     s0, 0x12345     # s0 = 0x12345000  (LUI)
    auipc   s1, 0x10        # s1 = PC+0x10000  (AUIPC)
    lui     s2, 0xABCDE
    addi    s2, s2, 0x7FF   # s2 = 0xABCDE7FF

# ============================================================
# 7) J-TYPE  (JAL / JALR)
# ============================================================
    jal     ra, func_demo       # JAL  (first call)

    la      t0, func_demo
    jalr    ra, t0, 0           # JALR (second call)

# ============================================================
# 8) Loop: sum array elements
# ============================================================
    la      a0, array
    li      a1, 5
    li      a2, 0               # i = 0
    li      a3, 0               # sum = 0

loop:
    bge     a2, a1, loop_end
    slli    t0, a2, 2           # byte offset = i*4
    add     t1, a0, t0
    lw      t2, 0(t1)
    add     a3, a3, t2
    addi    a2, a2, 1
    j       loop

loop_end:
    la      t0, result
    sw      a3, 0(t0)           # result = 150

# ============================================================
# EXIT via tohost
# ============================================================
exit:
    li      t0, 1
    la      t1, tohost
    sw      t0, 0(t1)
1:  j       1b

# ============================================================
# func_demo — only reachable via JAL/JALR
# ============================================================
func_demo:
    addi    sp, sp, -4
    sw      ra, 0(sp)

    li      t0, 0xFF
    li      t1, 0x0F
    and     t2, t0, t1

    lw      ra, 0(sp)
    addi    sp, sp, 4
    ret

# ============================================================
# END OF FILE
# ============================================================
