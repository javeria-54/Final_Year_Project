
import sys
import os

INSTRS_PER_BANK_ROW = 4          # 4 instructions * 4 bytes = 16 bytes per bank per row
INSTRS_PER_ROW      = 16         # 4 banks * 4 instrs = 16 instrs per full row
BYTES_PER_INSTR     = 4
NOP                 = "00000013" # ADDI x0, x0, 0


def parse_hex_file(input_file):
    """Read hex file, return list of 32-bit instruction strings (8 hex chars each)."""
    instructions = []
    with open(input_file, 'r') as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('@') or line.startswith('//'):
                continue
            if len(line) != 8:
                raise ValueError(f"Invalid instruction '{line}' - must be 8 hex chars (32-bit)")
            instructions.append(line.upper())
    return instructions


def generate_bank_files(input_file, output_dir=None):
    if output_dir is None:
        output_dir = os.path.dirname(os.path.abspath(input_file))

    instructions = parse_hex_file(input_file)
    total = len(instructions)

    # Pad to multiple of INSTRS_PER_ROW with NOPs
    while len(instructions) % INSTRS_PER_ROW != 0:
        instructions.append(NOP)

    num_rows = len(instructions) // INSTRS_PER_ROW

    print(f"Total instructions : {total}")
    print(f"Padded to          : {len(instructions)}  (rows: {num_rows})")

    # bank_rows[bank][row] = flat list of 16 bytes (little-endian per instruction)
    bank_rows = [[[] for _ in range(num_rows)] for _ in range(4)]

    for row in range(num_rows):
        for bank in range(4):
            for col in range(INSTRS_PER_BANK_ROW):   # 4 instrs per bank per row
                idx = row * INSTRS_PER_ROW + bank * INSTRS_PER_BANK_ROW + col
                instr = instructions[idx]             # e.g. "93020000"

                # Little-endian bytes
                # instr string "AABBCCDD" -> byte0=DD (LSB), byte3=AA (MSB)
                b0 = instr[6:8]   # bits [7:0]
                b1 = instr[4:6]   # bits [15:8]
                b2 = instr[2:4]   # bits [23:16]
                b3 = instr[0:2]   # bits [31:24]

                bank_rows[bank][row].extend([b0, b1, b2, b3])
                # After 4 instrs: 16 bytes in bank_rows[bank][row]

    # Write output files
    # Each line = one 128-bit row = 16 bytes
    # $readmemh reads left as MSB, so reverse byte list (byte15 first)
    for bank in range(4):
        fname = os.path.join(output_dir, f"MEM_BANK_{bank}.txt")
        with open(fname, 'w') as f:
            f.write("@0\n")
            for row in range(num_rows):
                byte_list = bank_rows[bank][row]      # 16 bytes, index 0=LSB
                packed = "".join(reversed(byte_list)) # MSB first for $readmemh
                f.write(packed + "\n")
        print(f"Written: {fname}  ({num_rows} rows)")

    # Verification table
    print("\n--- Verification (first 16 instructions) ---")
    print(f"{'Idx':>4}  {'Addr':>8}  {'Instr':>10}  {'Row':>4}  {'Bank':>4}  {'ByteOff':>7}")
    for i in range(min(16, total)):
        addr     = i * 4
        row      = addr >> 6
        bank_sel = (addr >> 4) & 0x3
        byte_off = addr & 0xF
        print(f"{i:>4}  0x{addr:06X}  {instructions[i]:>10}  {row:>4}  {bank_sel:>4}  {byte_off:>7}")

    print("\n--- Bank contents summary (row 0) ---")
    for b in range(4):
        raw = bank_rows[b][0]
        print(f"Bank_{b}[0]: ", end="")
        for i in range(4):
            word = raw[i*4+3] + raw[i*4+2] + raw[i*4+1] + raw[i*4+0]
            orig_idx = b * 4 + i
            print(f"instr_{orig_idx}={word}", end="  ")
        print()


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python gen_mem_banks.py <imem.txt> [output_dir]")
        sys.exit(1)

    inp = sys.argv[1]
    out = sys.argv[2] if len(sys.argv) > 2 else None

    if not os.path.isfile(inp):
        print(f"Error: '{inp}' not found")
        sys.exit(1)

    generate_bank_files(inp, out)
    print("\nDone.")