import sys
import os

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
    DMEM_BASE_ADDR  = 0x00000
    DMEM_SIZE       = 0x200000
    IMEM_BASE_ADDR  = 0x000000
    IMEM_SIZE       = 0x200000
    PC_RESET        = 0x000000

# Auto-calculated
BYTES_PER_BANK_ROW  = MEM_BANK_WIDTH // 8
INSTRS_PER_BANK_ROW = BYTES_PER_BANK_ROW // BYTES_PER_INSTR
INSTRS_PER_ROW      = INSTRS_PER_BANK_ROW * NUM_BANKS
BANK_ROW_BITS       = BYTES_PER_BANK_ROW.bit_length() - 1
BANK_SEL_BITS       = NUM_BANKS.bit_length() - 1
ROW_SHIFT           = BANK_ROW_BITS + BANK_SEL_BITS
# =====================================================


def parse_hex_file(input_file):
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
    # Global variables explicitly use karo
    global PC_RESET, IMEM_BASE_ADDR, IMEM_SIZE, DMEM_BASE_ADDR
    global MEM_BANK_WIDTH, NUM_BANKS, BYTES_PER_BANK_ROW
    global INSTRS_PER_BANK_ROW, INSTRS_PER_ROW, ROW_SHIFT, BANK_ROW_BITS

    if output_dir is None:
        output_dir = os.path.dirname(os.path.abspath(input_file))

    instructions = parse_hex_file(input_file)
    total = len(instructions)

    while len(instructions) % INSTRS_PER_ROW != 0:
        instructions.append(NOP)

    num_rows = len(instructions) // INSTRS_PER_ROW

    print(f"Configuration      : {NUM_BANKS} banks x {MEM_BANK_WIDTH}-bit")
    print(f"Instrs per bank row: {INSTRS_PER_BANK_ROW}")
    print(f"Instrs per full row: {INSTRS_PER_ROW}")
    print(f"IMEM_BASE_ADDR     : 0x{IMEM_BASE_ADDR:08X}")
    print(f"PC_RESET           : 0x{PC_RESET:08X}")
    print(f"Total instructions : {total}")
    print(f"Padded to          : {len(instructions)}  (rows: {num_rows})")

    bank_rows = [[[] for _ in range(num_rows)] for _ in range(NUM_BANKS)]

    for row in range(num_rows):
        for bank in range(NUM_BANKS):
            for col in range(INSTRS_PER_BANK_ROW):
                idx = row * INSTRS_PER_ROW + bank * INSTRS_PER_BANK_ROW + col
                instr = instructions[idx]
                b0 = instr[6:8]
                b1 = instr[4:6]
                b2 = instr[2:4]
                b3 = instr[0:2]
                bank_rows[bank][row].extend([b0, b1, b2, b3])

    for bank in range(NUM_BANKS):
        fname = os.path.join(output_dir, f"MEM_BANK_{bank}.txt")
        with open(fname, 'w') as f:
            f.write("@0\n")
            for row in range(num_rows):
                byte_list = bank_rows[bank][row]
                packed = "".join(reversed(byte_list))
                f.write(packed + "\n")
        print(f"Written: {fname}  ({num_rows} rows)")

    # Verification table
    print("\n--- Verification ---")
    print(f"{'Idx':>4}  {'AbsAddr':>10}  {'LocalAddr':>10}  {'Instr':>10}  {'Row':>4}  {'Bank':>4}  {'ByteOff':>7}")
    for i in range(min(total, total)):
        abs_addr   = PC_RESET + i * BYTES_PER_INSTR
        local_addr = abs_addr - IMEM_BASE_ADDR
        row        = local_addr >> ROW_SHIFT
        bank_sel   = (local_addr >> BANK_ROW_BITS) & (NUM_BANKS - 1)
        byte_off   = local_addr & (BYTES_PER_BANK_ROW - 1)
        print(f"{i:>4}  0x{abs_addr:08X}  0x{local_addr:08X}  {instructions[i]:>10}  {row:>4}  {bank_sel:>4}  {byte_off:>7}")

    # Bank summary
    print("\n--- Bank contents summary (row 0) ---")
    for b in range(NUM_BANKS):
        raw = bank_rows[b][0]
        print(f"Bank_{b}[0]: ", end="")
        for i in range(INSTRS_PER_BANK_ROW):
            word = raw[i*4+3] + raw[i*4+2] + raw[i*4+1] + raw[i*4+0]
            orig_idx = b * INSTRS_PER_BANK_ROW + i
            print(f"instr_{orig_idx}={word}", end="  ")
        print()


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python mem_instructions.py <imem.txt> [output_dir]")
        sys.exit(1)

    inp = sys.argv[1]
    out = sys.argv[2] if len(sys.argv) > 2 else None

    if not os.path.isfile(inp):
        print(f"Error: '{inp}' not found")
        sys.exit(1)

    generate_bank_files(inp, out)
    print("\nDone.")