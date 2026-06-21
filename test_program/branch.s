.section .text
.globl _start

_start:
    # ── Test 1: BEQ (equal) ──────────────────────────
    addi x1, x0, 5
    addi x2, x0, 5
    beq  x1, x2, beq_pass    # x1==x2 → jump hona chahiye
    addi x10, x0, 1           # x10=1 → FAIL (nahi aana chahiye)
beq_pass:
    addi x10, x0, 0           # x10=0 → PASS

    # ── Test 2: BNE (not equal) ──────────────────────
    addi x1, x0, 3
    addi x2, x0, 7
    bne  x1, x2, bne_pass    # x1!=x2 → jump hona chahiye
    addi x11, x0, 1           # x11=1 → FAIL
bne_pass:
    addi x11, x0, 0           # x11=0 → PASS

    # ── Test 3: BLT (less than signed) ───────────────
    addi x1, x0, 3
    addi x2, x0, 7
    blt  x1, x2, blt_pass    # x1<x2 → jump hona chahiye
    addi x12, x0, 1           # x12=1 → FAIL
blt_pass:
    addi x12, x0, 0           # x12=0 → PASS

    # ── Test 4: BGE (greater or equal) ───────────────
    addi x1, x0, 7
    addi x2, x0, 3
    bge  x1, x2, bge_pass    # x1>=x2 → jump hona chahiye
    addi x13, x0, 1           # x13=1 → FAIL
bge_pass:
    addi x13, x0, 0           # x13=0 → PASS

    # ── Test 5: BLTU (less than unsigned) ────────────
    addi x1, x0, 2
    addi x2, x0, 9
    bltu x1, x2, bltu_pass   # x1<x2 unsigned → jump hona chahiye
    addi x14, x0, 1           # x14=1 → FAIL
bltu_pass:
    addi x14, x0, 0           # x14=0 → PASS

    # ── Test 6: BGEU (greater or equal unsigned) ─────
    addi x1, x0, 9
    addi x2, x0, 2
    bgeu x1, x2, bgeu_pass   # x1>=x2 unsigned → jump hona chahiye
    addi x15, x0, 1           # x15=1 → FAIL
bgeu_pass:
    addi x15, x0, 0           # x15=0 → PASS

    # ── Test 7: Branch NOT taken ──────────────────────
    addi x1, x0, 3
    addi x2, x0, 7
    beq  x1, x2, fail_branch  # x1!=x2 → jump NAHI hona chahiye
    addi x16, x0, 0            # x16=0 → PASS (yahan aana chahiye)
    j    exit
fail_branch:
    addi x16, x0, 1            # x16=1 → FAIL

exit:
    # Expected results:
    # x10=0, x11=0, x12=0, x13=0, x14=0, x15=0, x16=0

    li   t0, 1
    la   t1, tohost
    sw   t0, 0(t1)

1:  j 1b

.section .tohost
.align 3
tohost:   .dword 0
fromhost: .dword 0
