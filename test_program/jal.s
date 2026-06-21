.section .text
.globl _start

_start:
    addi x1, x0, 10        # x1 = 10
    jal  x2, target         # x2 = PC+4, jump to target

    # JALR yahan wapas aayega
    addi x5, x0, 77        # x5 = 77

    # Seedha exit — koi loop nahi
    li   t0, 1
    la   t1, tohost
    sw   t0, 0(t1)

1:  j 1b                   # Spike exit hone tak wait

target:
    addi x3, x0, 20        # x3 = 20
    jalr x0, x2, 0         # x2 pe wapas jao

.section .tohost
.align 3
tohost:   .dword 0
fromhost: .dword 0
