# =============================================================================
# RISC-V Vector Load + Store Tests
# Tests: Unit Stride | Constant Stride | Indexed Ordered | Indexed Unordered
# =============================================================================

.section .tohost,"aw",@progbits
.align 3
.global tohost
.global fromhost
tohost:   .dword 0
fromhost: .dword 0

.section .text
.global _start
_start:

# ── Enable V extension in mstatus (VS bits 10:9 = 01 → 0x200) ───────────────
    li      t0, 0x600
    csrrs   x0, mstatus, t0

# ── Read VLENB ───────────────────────────────────────────────────────────────
    csrr    t0, vlenb

# ── Setup ────────────────────────────────────────────────────────────────────
    la      s0, src_array        # s0 = actual address of src_array
    la      s3, dst_array        # s3 = actual address of dst_array  ← FIX
    li      a1, 4
    
    vsetvli t0, t0, e8, m1, ta, ma
# =============================================================================
# CASE 1 — UNIT STRIDE  (load + store)
# Load  : src[0], src[1], src[2], src[3]  → consecutive 4-byte elements
# Store : dst[0], dst[1], dst[2], dst[3]
# =============================================================================
unit_stride:
    vle32.v  v1, (s0)            # LOAD  unit-stride
    vse32.v  v1, (s3)            # STORE unit-stride

# =============================================================================
# CASE 2 — CONSTANT STRIDE  (load + store, stride = 8 bytes)
# Load  : src+0, src+8, src+16, src+24
# Store : dst+0, dst+8, dst+16, dst+24
# =============================================================================
constant_stride:
    li       s1, 8
    vlse32.v  v2, (s0), s1       # LOAD  strided
    vsse32.v  v2, (s3), s1       # STORE strided

# =============================================================================
# CASE 3 — INDEXED ORDERED  (load + store)
# Offsets: {0, 8, 4, 12}
# "ordered" → exceptions taken in element order
# =============================================================================
indexed_ordered:
    la          t1, idx_ordered
    vle32.v     v4, (t1)         # v4 = {0, 8, 4, 12}
    vloxei32.v  v5, (s0), v4     # LOAD  indexed ordered
    vsoxei32.v  v5, (s3), v4     # STORE indexed ordered

# =============================================================================
# CASE 4 — INDEXED UNORDERED  (load + store)
# Offsets: {12, 0, 8, 4}
# "unordered" → hardware may reorder accesses for performance
# =============================================================================
indexed_unordered:
    la          t1, idx_unordered
    vle32.v     v6, (t1)         # v6 = {12, 0, 8, 4}
    vluxei32.v  v7, (s0), v6     # LOAD  indexed unordered
    vsuxei32.v  v7, (s3), v6     # STORE indexed unordered

# ── Clean exit via HTIF tohost ────────────────────────────────────────────────
exit:
    li      t0, 1
    la      t1, tohost
    sw     t0, 0(t1)
1:  j       1b

# =============================================================================
# DATA SECTION
# =============================================================================
.section .data
.align 4

src_array:
    .word 0x00000010   # [0] offset  0
    .word 0x00000020   # [1] offset  4
    .word 0x00000030   # [2] offset  8
    .word 0x00000040   # [3] offset 12
    .word 0x00000050   # [4] offset 16
    .word 0x00000060   # [5] offset 20
    .word 0x00000070   # [6] offset 24
    .word 0x00000080   # [7] offset 28

.align 4
dst_array:
    .word 0,0,0,0,0,0,0,0

.align 4
idx_ordered:
    .word  0
    .word  8
    .word  4
    .word 12

.align 4
idx_unordered:
    .word 12
    .word  0
    .word  8
    .word  4
