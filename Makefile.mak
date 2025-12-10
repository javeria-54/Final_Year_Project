# Variables
TOP_MODULE = top_8.sv
SRC_FILES = carry_save.sv dada.sv multiplier_8.sv top_8_tb.sv
WORK_DIR = work

# Default target
all: compile simulate

# Compile SystemVerilog files
compile:
	@echo "Creating work library..."
	vlib $(WORK_DIR)
	@echo "Compiling source files..."
	vlog -work $(WORK_DIR) $(SRC_FILES)

# Run the simulation in console mode
simulate: compile
	@echo "Running simulation..."
	vsim -c -do "run -all; quit" -L $(WORK_DIR) $(TOP_MODULE)

# Run the simulation in GUI mode
wave: compile
	@echo "Opening GUI simulation..."
	vsim -do "run -all; quit" -L $(WORK_DIR) $(TOP_MODULE)

# Clean up
.PHONY: clean
clean:
	@echo "Cleaning up..."
	rm -rf $(WORK_DIR) transcript vsim.wlf
