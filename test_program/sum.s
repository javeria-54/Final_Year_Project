.section .text
.globl _start
_start:
    addi t0, x0, 0x600
    csrrs x0, mstatus, t0   # vector enable karo

    csrr t0, vlenb           # vlenb read karo (csrr use karo)

    li t1, 1
    li t2, 1
    add t3, t1, t2

    # Spike exit
    li t0, 1
    la t1, tohost
    sw t0, 0(t1)

1:  j 1b

.section .tohost
.align 3
tohost: .dword 0
fromhost: .dword 0
