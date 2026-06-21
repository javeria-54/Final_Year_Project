riscv32-unknown-elf-gcc -march=rv32gv -mabi=ilp32d -c lda.s -o lda.o

riscv32-unknown-elf-gcc \
  -march=rv32gcv \
  -mabi=ilp32d \
  -static \
  -nostartfiles \
  -T linker.ld \
   lda.o \
  -o lda

spike --isa=rv32gcv \
  -l \
  --log=spike.log \
  --instructions=100000 \

riscv32-unknown-elf-objdump -D lda > lda.dis
riscv32-unknown-elf-objcopy -O binary lda lda.bin
hexdump -v -e '1/4 "%08x\n"' lda.bin > lda.txt

spike --isa=rv32gcv -d lda
