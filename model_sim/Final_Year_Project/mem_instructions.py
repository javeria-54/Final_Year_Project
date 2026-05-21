import sys
import os
import random

# =====================================================
# CONFIGURE HERE ONLY
# =====================================================
MEM_BANK_WIDTH      = 32
NUM_BANKS           = 4
BYTES_PER_INSTR     = 4
NOP                 = "00000013"

FPGA_MODE           = False

if FPGA_MODE:
    IMEM_BASE_ADDR  = 0x00000
    IMEM_SIZE       = 0x40000
    DMEM_BASE_ADDR  = 0x40000
    DMEM_SIZE       = 0x40000
    PC_RESET        = 0x00000
else:
    IMEM_BASE_ADDR  = 0x000000
    IMEM_SIZE       = 0x200000   # 2MB
    DMEM_BASE_ADDR  = 0x200000   # IMEM ke baad shuru hota hai
    DMEM_SIZE       = 0x200000   # 2MB
    PC_RESET        = 0x000000

# Auto-calculated
BYTES_PER_BANK_ROW  = MEM_BANK_WIDTH // 8           # 32/8 = 4
INSTRS_PER_BANK_ROW = BYTES_PER_BANK_ROW // BYTES_PER_INSTR  # 4/4 = 1
INSTRS_PER_ROW      = INSTRS_PER_BANK_ROW * NUM_BANKS        # 1*4 = 4
BANK_ROW_BITS       = BYTES_PER_BANK_ROW.bit_length() - 1    # clog2(4) = 2
BANK_SEL_BITS       = NUM_BANKS.bit_length() - 1             # clog2(4) = 2
ROW_SHIFT           = BANK_ROW_BITS + BANK_SEL_BITS          # 2+2 = 4
# =====================================================


def parse_hex_file(input_file):
    """Hex file se instructions parse karo"""
    instructions = []
    with open(input_file, 'r') as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('@') or line.startswith('//'):
                continue
            if len(line) != 8:
                raise ValueError(f"Invalid instruction '{line}' - must be 8 hex chars")
            instructions.append(line.upper())
    return instructions


def generate_bank_files(input_file, output_dir=None):
    """Instructions ko bank files mein convert karo"""

    global PC_RESET, IMEM_BASE_ADDR, IMEM_SIZE, DMEM_BASE_ADDR
    global MEM_BANK_WIDTH, NUM_BANKS, BYTES_PER_BANK_ROW
    global INSTRS_PER_BANK_ROW, INSTRS_PER_ROW, ROW_SHIFT, BANK_ROW_BITS

    if output_dir is None:
        output_dir = os.path.dirname(os.path.abspath(input_file))

    instructions = parse_hex_file(input_file)
    total = len(instructions)

    # Row boundary tak pad karo NOPs se
    while len(instructions) % INSTRS_PER_ROW != 0:
        instructions.append(NOP)

    num_rows = len(instructions) // INSTRS_PER_ROW

    print("=" * 60)
    print("IMEM Generation")
    print("=" * 60)
    print(f"Configuration      : {NUM_BANKS} banks x {MEM_BANK_WIDTH}-bit")
    print(f"Instrs per bank row: {INSTRS_PER_BANK_ROW}")
    print(f"Instrs per full row: {INSTRS_PER_ROW}")
    print(f"IMEM_BASE_ADDR     : 0x{IMEM_BASE_ADDR:08X}")
    print(f"DMEM_BASE_ADDR     : 0x{DMEM_BASE_ADDR:08X}")
    print(f"PC_RESET           : 0x{PC_RESET:08X}")
    print(f"Total instructions : {total}")
    print(f"Padded to          : {len(instructions)}  (rows: {num_rows})")

    # Har bank ke liye rows prepare karo
    bank_rows = [[[] for _ in range(num_rows)] for _ in range(NUM_BANKS)]

    for row in range(num_rows):
        for bank in range(NUM_BANKS):
            for col in range(INSTRS_PER_BANK_ROW):
                idx = row * INSTRS_PER_ROW + bank * INSTRS_PER_BANK_ROW + col
                instr = instructions[idx]
                # Little-endian byte order
                b0 = instr[6:8]
                b1 = instr[4:6]
                b2 = instr[2:4]
                b3 = instr[0:2]
                bank_rows[bank][row].extend([b0, b1, b2, b3])

    # IMEM start row = 0 (IMEM_BASE_ADDR = 0x0)
    imem_start_row = IMEM_BASE_ADDR >> ROW_SHIFT

    # Bank files likho — IMEM section
    for bank in range(NUM_BANKS):
        fname = os.path.join(output_dir, f"MEM_BANK_{bank}.txt")
        with open(fname, 'w') as f:
            f.write(f"@{imem_start_row:X}\n")
            for row in range(num_rows):
                byte_list = bank_rows[bank][row]
                packed = "".join(reversed(byte_list))
                f.write(packed + "\n")
        print(f"Written IMEM: {fname}  ({num_rows} rows)")

    # Verification table
    print("\n--- Instruction Verification ---")
    print(f"{'Idx':>4}  {'AbsAddr':>10}  {'LocalAddr':>10}  {'Instr':>10}  {'Row':>4}  {'Bank':>4}  {'ByteOff':>7}")
    for i in range(total):
        abs_addr   = PC_RESET + i * BYTES_PER_INSTR
        local_addr = abs_addr - IMEM_BASE_ADDR
        row        = local_addr >> ROW_SHIFT
        bank_sel   = (local_addr >> BANK_ROW_BITS) & (NUM_BANKS - 1)
        byte_off   = local_addr & (BYTES_PER_BANK_ROW - 1)
        print(f"{i:>4}  0x{abs_addr:08X}  0x{local_addr:08X}  {instructions[i]:>10}  {row:>4}  {bank_sel:>4}  {byte_off:>7}")

    # Bank summary row 0
    print("\n--- Bank contents summary (row 0) ---")
    for b in range(NUM_BANKS):
        raw = bank_rows[b][0]
        print(f"Bank_{b}[0]: ", end="")
        for i in range(INSTRS_PER_BANK_ROW):
            word = raw[i*4+3] + raw[i*4+2] + raw[i*4+1] + raw[i*4+0]
            orig_idx = b * INSTRS_PER_BANK_ROW + i
            print(f"instr_{orig_idx}={word}", end="  ")
        print()


def generate_random_data(output_dir, num_data_words=10000, seed=None):
    """
    Random data DMEM section mein dump karo.
    DMEM_BASE_ADDR se shuru hota hai.
    num_data_words: kitne 32-bit words generate karni hain
    seed: reproducible results ke liye (None = truly random)
    """

    global DMEM_BASE_ADDR, DMEM_SIZE, NUM_BANKS, ROW_SHIFT, BANK_ROW_BITS, BANK_SEL_BITS

    if seed is not None:
        random.seed(seed)

    # DMEM mein kitne words fit ho sakte hain max
    max_words = DMEM_SIZE // (MEM_BANK_WIDTH // 8)
    if num_data_words > max_words:
        print(f"Warning: num_data_words {num_data_words} > max {max_words}, clamping.")
        num_data_words = max_words

    # Har row mein NUM_BANKS words hain (ek per bank)
    words_per_row = NUM_BANKS
    num_rows = (num_data_words + words_per_row - 1) // words_per_row

    # Har bank ke liye data generate karo
    bank_data = [[] for _ in range(NUM_BANKS)]
    for row in range(num_rows):
        for bank in range(NUM_BANKS):
            rand_word = random.randint(0, 0xFFFFFFFF)
            bank_data[bank].append(f"{rand_word:08X}")

    # DMEM start row calculate karo
    dmem_start_row = DMEM_BASE_ADDR >> ROW_SHIFT

    print("\n" + "=" * 60)
    print("DMEM Random Data Generation")
    print("=" * 60)
    print(f"DMEM_BASE_ADDR     : 0x{DMEM_BASE_ADDR:08X}")
    print(f"DMEM start row     : {dmem_start_row} (0x{dmem_start_row:X})")
    print(f"Words to generate  : {num_data_words}")
    print(f"Rows to write      : {num_rows}")
    print(f"Random seed        : {seed if seed is not None else 'random'}")

    # Bank files mein APPEND karo DMEM address se
    for bank in range(NUM_BANKS):
        fname = os.path.join(output_dir, f"MEM_BANK_{bank}.txt")
        with open(fname, 'a') as f:
            f.write(f"\n@{dmem_start_row:X}\n")
            for word in bank_data[bank]:
                f.write(word + "\n")
        print(f"Written DMEM data: {fname}  ({num_rows} rows @ row 0x{dmem_start_row:X})")

    # DMEM verification table
    print("\n--- DMEM Data Verification (first 16 words) ---")
    print(f"{'WordIdx':>8}  {'AbsAddr':>10}  {'LocalAddr':>10}  {'Row':>6}  {'Bank':>4}  {'Data':>10}")
    for i in range(min(16, num_data_words)):
        abs_addr   = DMEM_BASE_ADDR + i * (MEM_BANK_WIDTH // 8)
        local_addr = abs_addr - DMEM_BASE_ADDR
        row        = (local_addr >> ROW_SHIFT) + dmem_start_row
        bank_sel   = (local_addr >> BANK_ROW_BITS) & (NUM_BANKS - 1)
        data       = bank_data[bank_sel][row - dmem_start_row]
        print(f"{i:>8}  0x{abs_addr:08X}  0x{local_addr:08X}  {row:>6}  {bank_sel:>4}  {data:>10}")


# =====================================================
# MAIN
# =====================================================
if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python mem_instructions.py <imem.txt> [output_dir] [num_data_words] [seed]")
        print("  imem.txt       : instruction hex file")
        print("  output_dir     : output directory (default: same as input)")
        print("  num_data_words : random DMEM words to generate (default: 256)")
        print("  seed           : random seed for reproducibility (default: random)")
        sys.exit(1)

    inp          = sys.argv[1]
    out          = sys.argv[2] if len(sys.argv) > 2 else None
    num_words    = int(sys.argv[3]) if len(sys.argv) > 3 else 256
    rand_seed    = int(sys.argv[4]) if len(sys.argv) > 4 else None

    if not os.path.isfile(inp):
        print(f"Error: '{inp}' not found")
        sys.exit(1)

    if out is None:
        out = os.path.dirname(os.path.abspath(inp))

    # Step 1: Instructions IMEM mein
    generate_bank_files(inp, out)

    # Step 2: Random data DMEM mein
    generate_random_data(out, num_data_words=num_words, seed=rand_seed)

    print("\nDone.")