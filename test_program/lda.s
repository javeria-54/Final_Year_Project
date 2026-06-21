# ==========================================================
# REAL LDA (Linear Discriminant Analysis) - RVV Assembly
# Computes actual Within-Class & Between-Class Scatter
# Uses ONLY: vle32.v, vse32.v, vadd.vv, vmul.vv, vmv.x.s/vmv.s.x
# (No vredsum, no vslide, no vector subtract/broadcast needed)
# ==========================================================
#
# Dataset (1D feature, 2 classes, 4 samples each):
#   Class 0: {10, 12, 11, 13}
#   Class 1: {30, 32, 31, 29}
#
# Key trick: Variance/Scatter computed WITHOUT vector subtract,
# using the computational formula:
#       S = sum(x^2) - n * mean^2
# This needs only SQUARE (vmul.vv) + SUM (vadd.vv tree), both
# of which are implemented in SIVC.
#
# IMPORTANT: vl MUST stay at 2 here. The reduction logic below
# splits each 4-sample class into two halves of 2 elements and
# combines them with vadd.vv. If vl is changed to 4, vle32.v
# loads 4 elements per call instead of 2 - this causes the
# second load to read past the array bounds (into the next
# class's data), and vse32.v to write past the 8-byte scratch
# buffer (corrupting adjacent .data variables).
#
# Steps:
#   1. mean0, mean1            <- vector tree-add (sum / n)
#   2. sumSq0, sumSq1          <- vmul.vv (square) + tree-add
#   3. S_W0 = sumSq0 - n*mean0^2   (within-class scatter, class0)
#   4. S_W1 = sumSq1 - n*mean1^2   (within-class scatter, class1)
#   5. S_W  = S_W0 + S_W1           (total within-class scatter)
#   6. S_B  = (mean1 - mean0)^2     (between-class scatter)
#   7. threshold = (mean0 + mean1) / 2   (LDA decision boundary,
#      valid under equal within-class variance assumption)
#   8. classify test_point vs threshold
# ==========================================================

.section .data
.align 4
class0_data:    .word 10, 12, 11, 13          # Class 0 samples
class1_data:    .word 30, 32, 31, 29          # Class 1 samples
test_point:     .word 25                       # Sample to classify

scratch:        .word 0, 0                     # intermediate vector store buffer (2 words = 8 bytes, must match vl=2)

mean0_out:      .word 0
mean1_out:      .word 0
sw0_out:        .word 0        # within-class scatter, class 0
sw1_out:        .word 0        # within-class scatter, class 1
sw_total_out:   .word 0        # total within-class scatter
sb_out:         .word 0        # between-class scatter
threshold_out:  .word 0
result:         .word 0        # output: 0 = class0, 1 = class1

.section .text
.global _start

_start:
    # ---- Enable Vector Extension (VS = 01 in mstatus) ----
    li      t0, 0x600
    csrrs   x0, mstatus, t0

    li      t6, 4                  # constant n = 4 (samples per class)

    # ---- Set Vector Length: 2 elements, 32-bit, LMUL=1 ----
    # MUST be 2 - see note above. Do not change to 4.
    li      t0, 4
    vsetvli t1, t0, e32, m1, ta, ma

    # ============================================================
    # CLASS 0: compute sum(x) and sum(x^2)
    # ============================================================
    la      a0, class0_data
    vle32.v v1, (a0)              # v1 = [10, 12]
    addi    a0, a0, 8
    vle32.v v2, (a0)              # v2 = [11, 13]

    # ---- sum(x) ----
    vadd.vv v3, v1, v2            # v3 = [10+11, 12+13] = [21, 25]
    la      a1, scratch
    vse32.v v3, (a1)
    lw      t2, 0(a1)
    lw      t3, 4(a1)
    add     t2, t2, t3            # t2 = sum(class0) = 46

    div     t4, t2, t6            # mean0 = 46 / 4 = 11
    la      a2, mean0_out
    sw      t4, 0(a2)
    mv      s0, t4                # s0 = mean0

    # ---- sum(x^2) ----
    vmul.vv v4, v1, v1            # v4 = [100, 144]
    vmul.vv v5, v2, v2            # v5 = [121, 169]
    vadd.vv v6, v4, v5            # v6 = [221, 313]
    vse32.v v6, (a1)
    lw      t2, 0(a1)
    lw      t3, 4(a1)
    add     t2, t2, t3            # t2 = sum(x^2) class0 = 534

    # ---- S_W0 = sumSq0 - n*mean0^2 ----
    mul     t4, s0, s0            # t4 = mean0^2 = 121
    mul     t4, t4, t6            # t4 = n*mean0^2 = 484
    sub     t4, t2, t4            # t4 = S_W0 = 534 - 484 = 50
    la      a2, sw0_out
    sw      t4, 0(a2)
    mv      s2, t4                # s2 = S_W0

    # ============================================================
    # CLASS 1: compute sum(x) and sum(x^2)
    # ============================================================
    la      a0, class1_data
    vle32.v v1, (a0)              # v1 = [30, 32]
    addi    a0, a0, 8
    vle32.v v2, (a0)              # v2 = [31, 29]

    # ---- sum(x) ----
    vadd.vv v3, v1, v2            # v3 = [61, 61]
    vse32.v v3, (a1)
    lw      t2, 0(a1)
    lw      t3, 4(a1)
    add     t2, t2, t3            # t2 = sum(class1) = 122

    div     t4, t2, t6            # mean1 = 122 / 4 = 30
    la      a2, mean1_out
    sw      t4, 0(a2)
    mv      s1, t4                # s1 = mean1

    # ---- sum(x^2) ----
    vmul.vv v4, v1, v1            # v4 = [900, 1024]
    vmul.vv v5, v2, v2            # v5 = [961, 841]
    vadd.vv v6, v4, v5            # v6 = [1861, 1865]
    vse32.v v6, (a1)
    lw      t2, 0(a1)
    lw      t3, 4(a1)
    add     t2, t2, t3            # t2 = sum(x^2) class1 = 3726

    # ---- S_W1 = sumSq1 - n*mean1^2 ----
    mul     t4, s1, s1            # t4 = mean1^2 = 900
    mul     t4, t4, t6            # t4 = n*mean1^2 = 3600
    sub     t4, t2, t4            # t4 = S_W1 = 3726 - 3600 = 126
    la      a2, sw1_out
    sw      t4, 0(a2)
    mv      s3, t4                # s3 = S_W1

    # ============================================================
    # TOTAL WITHIN-CLASS SCATTER  S_W = S_W0 + S_W1
    # ============================================================
    add     t5, s2, s3            # t5 = S_W = 50 + 126 = 176
    la      a2, sw_total_out
    sw      t5, 0(a2)

    # ============================================================
    # BETWEEN-CLASS SCATTER  S_B = (mean1 - mean0)^2
    # ============================================================
    sub     t4, s1, s0            # t4 = mean1 - mean0 = 30 - 11 = 19
    mul     t4, t4, t4            # t4 = S_B = 19^2 = 361
    la      a2, sb_out
    sw      t4, 0(a2)

    # ============================================================
    # THRESHOLD (decision boundary, equal-variance assumption)
    # threshold = (mean0 + mean1) / 2
    # ============================================================
    add     t4, s0, s1            # t4 = 11 + 30 = 41
    li      t6, 2
    div     t4, t4, t6            # threshold = 41 / 2 = 20
    la      a2, threshold_out
    sw      t4, 0(a2)
    mv      s4, t4                # s4 = threshold

    # ============================================================
    # CLASSIFY TEST POINT
    # ============================================================
    la      a0, test_point
    lw      a3, 0(a0)             # a3 = test_point = 25

    blt     a3, s4, class_0       # if test_point < threshold -> class 0
    li      t1, 1                 # else -> class 1
    j       store_result

class_0:
    li      t1, 0

store_result:
    la      a1, result
    sw      t1, 0(a1)

    # ================= END =================
done:
    j       done                  # Infinite loop (halt, Spike/RTL waits here)