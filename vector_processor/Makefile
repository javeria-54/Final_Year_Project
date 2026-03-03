# ==============================
# Questa / ModelSim Makefile
# ==============================

SRC_DIR = /home/javeria/Documents/Final_Year_Project/rtl/vector_processor
TOP_TB  = vector_processor_tb

RTL_FILES = $(wildcard $(SRC_DIR)/*.sv)

PKG_FILE = $(SRC_DIR)/axi_4_pkg.sv
RTL_NO_PKG = $(filter-out $(PKG_FILE), $(RTL_FILES))

# Your project library path
LIB = /home/javeria/Documents/Final_Year_Project/rtl/model_sim/Final_Year_Project

all: compile simulate

lib:
	vlib $(LIB)
	vmap work $(LIB)

compile: lib
	vlog -work $(LIB) -sv +incdir+$(SRC_DIR) $(PKG_FILE)
	vlog -work $(LIB) -sv +incdir+$(SRC_DIR) $(RTL_NO_PKG)

simulate:
	vsim -c -lib $(LIB) $(TOP_TB) -do "run -all; quit"

gui:
	vsim -lib $(LIB) $(TOP_TB)

clean:
	rm -rf PROCESSOR transcript vsim.wlf