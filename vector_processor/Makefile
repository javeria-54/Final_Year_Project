# ==============================================
# Questa/ModelSim Makefile — WSL Version
# ==============================================

SRC_DIR  = /mnt/c/Users/User/Downloads/final_Year_Project/Final_Year_Project/vector_processor
LIB_DIR  = /mnt/c/Users/User/Downloads/final_Year_Project/Final_Year_Project/work

TOP_TB   = pipeline_tb
RUN_TIME = 10000ns
WAVE_DO  = wave_setup.do

# Tools — WSL mein aliases already .bashrc mein hain
VLOG = vlog
VSIM = vsim
VLIB = vlib
VMAP = vmap

# Sari SV files
RTL_FILES = $(wildcard $(SRC_DIR)/*.sv)

# TB aur RTL alag karo
TB_FILES  = $(filter %_tb.sv, $(RTL_FILES))
RTL_NO_TB = $(filter-out %_tb.sv, $(RTL_FILES))

# Include path
INC = +incdir+$(SRC_DIR)

# ==============================================
.PHONY: all compile sim gui wave clean help
# ==============================================

all: compile gui

# -----------------------------------------------
lib:
	@echo "=============================="
	@echo " Setting up library..."
	@echo "=============================="
	@if [ ! -d "$(LIB_DIR)" ]; then \
		echo "Creating library..."; \
		$(VLIB) $(LIB_DIR); \
	else \
		echo "Library exists, skipping."; \
	fi
	$(VMAP) work $(LIB_DIR)

# -----------------------------------------------
compile: lib
	@echo "=============================="
	@echo " Compiling RTL..."
	@echo "=============================="
	$(VLOG) -work $(LIB_DIR) -sv $(INC) $(RTL_NO_TB)
	@echo "=============================="
	@echo " Compiling Testbench..."
	@echo "=============================="
	$(VLOG) -work $(LIB_DIR) -sv $(INC) $(TB_FILES)
	@echo "=============================="
	@echo " Compilation Done!"
	@echo "=============================="

# -----------------------------------------------
sim: compile
	$(VSIM) -c \
	        -lib $(LIB_DIR) \
	        -voptargs="+acc" \
	        $(TOP_TB) \
	        -do "run $(RUN_TIME); quit -f"

# -----------------------------------------------
gui: compile wave
	$(VSIM) -gui \
	        -lib $(LIB_DIR) \
	        -voptargs="+acc" \
	        $(TOP_TB) \
	        -do "$(WAVE_DO); run $(RUN_TIME)"

# -----------------------------------------------
wave:
	@echo "# Auto-generated wave setup" > $(WAVE_DO)
	@echo "quietly WaveActivateNextPane {} 0" >> $(WAVE_DO)
	@echo "add wave -divider {Clock and Reset}" >> $(WAVE_DO)
	@echo "add wave -radix hex /$(TOP_TB)/clk" >> $(WAVE_DO)
	@echo "add wave -radix hex /$(TOP_TB)/rst_n" >> $(WAVE_DO)
	@echo "add wave -divider {FETCH}" >> $(WAVE_DO)
	@echo "add wave -radix hex /$(TOP_TB)/dut/if2mem" >> $(WAVE_DO)
	@echo "add wave -radix hex /$(TOP_TB)/dut/mem2if" >> $(WAVE_DO)
	@echo "add wave -radix hex /$(TOP_TB)/dut/if2id_data" >> $(WAVE_DO)
	@echo "add wave -radix hex /$(TOP_TB)/dut/if2id_ctrl" >> $(WAVE_DO)
	@echo "add wave -divider {ROB}" >> $(WAVE_DO)
	@echo "add wave -radix hex /$(TOP_TB)/dut/rob_de_valid" >> $(WAVE_DO)
	@echo "add wave -radix hex /$(TOP_TB)/dut/rob_de_instr" >> $(WAVE_DO)
	@echo "add wave -radix hex /$(TOP_TB)/dut/rob_de_seq_num" >> $(WAVE_DO)
	@echo "add wave -radix hex /$(TOP_TB)/dut/de_valid_d" >> $(WAVE_DO)
	@echo "add wave -radix hex /$(TOP_TB)/dut/rob_full_o" >> $(WAVE_DO)
	@echo "add wave -radix hex /$(TOP_TB)/dut/rob_commit_valid" >> $(WAVE_DO)
	@echo "add wave -radix hex /$(TOP_TB)/dut/rob_commit_rd" >> $(WAVE_DO)
	@echo "add wave -radix hex /$(TOP_TB)/dut/rob_commit_scalar_result" >> $(WAVE_DO)
	@echo "add wave -divider {DECODE}" >> $(WAVE_DO)
	@echo "add wave -radix hex /$(TOP_TB)/dut/id2exe_data" >> $(WAVE_DO)
	@echo "add wave -radix hex /$(TOP_TB)/dut/id2exe_ctrl" >> $(WAVE_DO)
	@echo "add wave -radix hex /$(TOP_TB)/dut/is_vector" >> $(WAVE_DO)
	@echo "add wave -radix hex /$(TOP_TB)/dut/is_scalar_load" >> $(WAVE_DO)
	@echo "add wave -radix hex /$(TOP_TB)/dut/is_scalar_store" >> $(WAVE_DO)
	@echo "add wave -divider {EXECUTE}" >> $(WAVE_DO)
	@echo "add wave -radix hex /$(TOP_TB)/dut/exe2lsu_data" >> $(WAVE_DO)
	@echo "add wave -radix hex /$(TOP_TB)/dut/exe2lsu_ctrl" >> $(WAVE_DO)
	@echo "add wave -radix hex /$(TOP_TB)/dut/exe_done" >> $(WAVE_DO)
	@echo "add wave -divider {LSU}" >> $(WAVE_DO)
	@echo "add wave -radix hex /$(TOP_TB)/dut/lsu2dbus" >> $(WAVE_DO)
	@echo "add wave -radix hex /$(TOP_TB)/dut/dbus2lsu" >> $(WAVE_DO)
	@echo "add wave -radix hex /$(TOP_TB)/dut/lsu2wrb_data" >> $(WAVE_DO)
	@echo "add wave -radix hex /$(TOP_TB)/dut/lsu_done" >> $(WAVE_DO)
	@echo "add wave -divider {CSR}" >> $(WAVE_DO)
	@echo "add wave -radix hex /$(TOP_TB)/dut/exe2csr_ctrl" >> $(WAVE_DO)
	@echo "add wave -radix hex /$(TOP_TB)/dut/csr2wrb_data" >> $(WAVE_DO)
	@echo "add wave -divider {WRITEBACK}" >> $(WAVE_DO)
	@echo "add wave -radix hex /$(TOP_TB)/dut/wrb2id_fb" >> $(WAVE_DO)
	@echo "add wave -radix hex /$(TOP_TB)/dut/wrb2exe_fb_rd_data" >> $(WAVE_DO)
	@echo "add wave -divider {FORWARD STALL}" >> $(WAVE_DO)
	@echo "add wave -radix hex /$(TOP_TB)/dut/fwd2ptop" >> $(WAVE_DO)
	@echo "add wave -radix hex /$(TOP_TB)/dut/fwd2if" >> $(WAVE_DO)
	@echo "add wave -radix hex /$(TOP_TB)/dut/fwd2lsu" >> $(WAVE_DO)
	@echo "add wave -divider {DBUS}" >> $(WAVE_DO)
	@echo "add wave -radix hex /$(TOP_TB)/dut/dbus2peri" >> $(WAVE_DO)
	@echo "add wave -radix hex /$(TOP_TB)/dut/mem2dbus" >> $(WAVE_DO)
	@echo "add wave -radix hex /$(TOP_TB)/dut/dmem_sel" >> $(WAVE_DO)
	@echo "add wave -divider {VIQ}" >> $(WAVE_DO)
	@echo "add wave -radix hex /$(TOP_TB)/dut/viq_dispatch_valid" >> $(WAVE_DO)
	@echo "add wave -radix hex /$(TOP_TB)/dut/viq_deq_instr_o" >> $(WAVE_DO)
	@echo "add wave -radix hex /$(TOP_TB)/dut/viq_deq_seq_o" >> $(WAVE_DO)
	@echo "add wave -radix hex /$(TOP_TB)/dut/viq_full" >> $(WAVE_DO)
	@echo "add wave -divider {VECTOR PROCESSOR}" >> $(WAVE_DO)
	@echo "add wave -radix hex /$(TOP_TB)/dut/execution_result" >> $(WAVE_DO)
	@echo "add wave -radix hex /$(TOP_TB)/dut/execution_done" >> $(WAVE_DO)
	@echo "add wave -radix hex /$(TOP_TB)/dut/scalar_done" >> $(WAVE_DO)
	@echo "add wave -radix hex /$(TOP_TB)/dut/vector_done" >> $(WAVE_DO)
	@echo "add wave -divider {MEMORY}" >> $(WAVE_DO)
	@echo "add wave -radix hex /$(TOP_TB)/dut/addr_a" >> $(WAVE_DO)
	@echo "add wave -radix hex /$(TOP_TB)/dut/rdata_a" >> $(WAVE_DO)
	@echo "add wave -radix hex /$(TOP_TB)/dut/mem_wen" >> $(WAVE_DO)
	@echo "add wave -radix hex /$(TOP_TB)/dut/mem_ren" >> $(WAVE_DO)
	@echo "configure wave -namecolwidth 250" >> $(WAVE_DO)
	@echo "configure wave -valuecolwidth 120" >> $(WAVE_DO)
	@echo "configure wave -signalnamewidth 1" >> $(WAVE_DO)
	@echo "update" >> $(WAVE_DO)
	@echo "WaveRestoreZoom {0 ns} {$(RUN_TIME)}" >> $(WAVE_DO)
	@echo " Wave file generated!"

# -----------------------------------------------
clean:
	@echo "Cleaning..."
	rm -rf $(LIB_DIR)
	rm -f $(WAVE_DO)
	rm -f transcript vsim.wlf *.vcd
	@echo "Done."

# -----------------------------------------------
help:
	@echo "make all     → compile + GUI + waves"
	@echo "make compile → sirf compile"
	@echo "make sim     → batch simulation"
	@echo "make gui     → GUI with waves"
	@echo "make clean   → sab delete"