# =============================================================================
# compile_and_sim.do — Questa Transcript mein chalao:
#     do compile_and_sim.do
# =============================================================================

# ---------------------------------------------------------------------------
# PATH — sirf yahan change karo
# ---------------------------------------------------------------------------
set SRC_DIR "C:/Users/User/Downloads/final_Year_Project/Final_Year_Project/vector_processor"

# ---------------------------------------------------------------------------
# Work library banao
# ---------------------------------------------------------------------------
if {[file exists work]} {
    vdel -lib work -all
}
vlib work
vmap work work

# ---------------------------------------------------------------------------
# Compile — SARI files EK vlog mein (include guards sahi kaam karein)
# ---------------------------------------------------------------------------
puts "\n=============================="
puts "  Compiling..."
puts "==============================\n"

vlog -sv -work work +incdir+$SRC_DIR \
    $SRC_DIR/pcore_types_pkg.sv \
    $SRC_DIR/axi_4_defs.svh \
    $SRC_DIR/scalar_a_ext_defs.svh \
    $SRC_DIR/scalar_csr_defs.svh \
    $SRC_DIR/scalar_gpio_defs.svh \
    $SRC_DIR/scalar_m_ext_defs.svh \
    $SRC_DIR/scalar_pcore_config_defs.svh \
    $SRC_DIR/scalar_pcore_interface_defs.svh \
    $SRC_DIR/scalar_plic_defs.svh \
    $SRC_DIR/scalar_spi_defs.svh \
    $SRC_DIR/scalar_uart_defs.svh \
    $SRC_DIR/vector_csr_regfile_defs.svh \
    $SRC_DIR/vector_de_csr_defs.svh \
    $SRC_DIR/vector_decode_defs.svh \
    $SRC_DIR/vector_execution_unit.svh \
    $SRC_DIR/vector_mask_unit_defs.svh \
    $SRC_DIR/vector_processor_defs.svh \
    $SRC_DIR/vector_regfile_defs.svh \
    $SRC_DIR/rob.sv \
    $SRC_DIR/scalar_amo.sv \
    $SRC_DIR/scalar_csr.sv \
    $SRC_DIR/scalar_dbus_interconnect.sv \
    $SRC_DIR/scalar_decode.sv \
    $SRC_DIR/scalar_divide.sv \
    $SRC_DIR/scalar_divider.sv \
    $SRC_DIR/scalar_execute.sv \
    $SRC_DIR/scalar_fetch.sv \
    $SRC_DIR/scalar_forward_stall.sv \
    $SRC_DIR/scalar_lsu.sv \
    $SRC_DIR/scalar_memory.sv \
    $SRC_DIR/scalar_pipeline_top.sv \
    $SRC_DIR/scalar_pipeline_tb.sv \
    $SRC_DIR/scalar_reg_file.sv \
    $SRC_DIR/scalar_val_ready_controller.sv \
    $SRC_DIR/scalar_writeback.sv \
    $SRC_DIR/vector_adder_subtractor_unit.sv \
    $SRC_DIR/vector_bitwise_unit.sv \
    $SRC_DIR/vector_compare_unit.sv \
    $SRC_DIR/vector_csr_dec.sv \
    $SRC_DIR/vector_csr_dec_tb.sv \
    $SRC_DIR/vector_csr_regfile.sv \
    $SRC_DIR/vector_decode.sv \
    $SRC_DIR/vector_execution_unit.sv \
    $SRC_DIR/vector_instruction_queue.sv \
    $SRC_DIR/vector_lsu.sv \
    $SRC_DIR/vector_mask_add_sub.sv \
    $SRC_DIR/vector_mask_unit.sv \
    $SRC_DIR/vector_multiplier.sv \
    $SRC_DIR/vector_multiply_add_unit.sv \
    $SRC_DIR/vector_processor.sv \
    $SRC_DIR/vector_processor_controller.sv \
    $SRC_DIR/vector_processor_datapath.sv \
    $SRC_DIR/vector_regfile.sv \
    $SRC_DIR/vector_shift_module.sv \
    $SRC_DIR/vector_val_ready_controller.sv

puts "\n>>> Compile complete.\n"

# ---------------------------------------------------------------------------
# Simulate
# ---------------------------------------------------------------------------
puts "\n=============================="
puts "  Starting Simulation..."
puts "==============================\n"

vsim -voptargs="+acc" -t 1ns work.pipeline_tb

# ---------------------------------------------------------------------------
# Waves — DUT ke andar saare signals
# ---------------------------------------------------------------------------
puts "\n=============================="
puts "  Adding Waves..."
puts "==============================\n"

add wave -divider {=== DECODE ===}
add wave -position insertpoint sim:/pipeline_tb/dut/decode_module/*

add wave -divider {=== ROB ===}
add wave -position insertpoint sim:/pipeline_tb/dut/rob/*

# ======= VECTOR PROCESSOR =======
add wave -divider {=== VIQ ===}
add wave -position insertpoint sim:/pipeline_tb/dut/viq/*

add wave -divider {=== VECTOR PROCESSOR ===}

add wave -divider {=== VEC DECODER ===}
add wave -position insertpoint sim:/pipeline_tb/dut/vector/DATAPATH/DECODER/*

add wave -divider {=== VEC EXECUTION UNIT ===}
add wave -position insertpoint sim:/pipeline_tb/dut/vector/DATAPATH/EXECUTION_UNIT/*

add wave -position insertpoint {sim:/pipeline_tb/dut/vector/DATAPATH/EXECUTION_UNIT/vect_mult/gen_processing_elements[3]/u_top8_pe/*}
add wave -position insertpoint {sim:/pipeline_tb/dut/vector/DATAPATH/EXECUTION_UNIT/vect_mult/gen_processing_elements[3]/u_top8_pe/mult/*}
add wave -position insertpoint {sim:/pipeline_tb/dut/vector/DATAPATH/EXECUTION_UNIT/vect_mult/gen_processing_elements[3]/u_top8_pe/cs/*}
add wave -position insertpoint {sim:/pipeline_tb/dut/vector/DATAPATH/EXECUTION_UNIT/vect_mult/gen_processing_elements[3]/u_top8_pe/dadda_1/*}
add wave -position insertpoint {sim:/pipeline_tb/dut/vector/DATAPATH/EXECUTION_UNIT/vect_mult/gen_processing_elements[3]/u_top8_pe/dadda_2/*}
add wave -position insertpoint {sim:/pipeline_tb/dut/vector/DATAPATH/EXECUTION_UNIT/vect_mult/gen_processing_elements[3]/u_top8_pe/dadda_3/*}
add wave -position insertpoint {sim:/pipeline_tb/dut/vector/DATAPATH/EXECUTION_UNIT/vect_mult/gen_processing_elements[3]/u_top8_pe/dadda_4/*}
add wave -position insertpoint {sim:/pipeline_tb/dut/vector/DATAPATH/EXECUTION_UNIT/vect_mult/gen_processing_elements[3]/u_top8_pe/dadda_5/*}
add wave -position insertpoint {sim:/pipeline_tb/dut/vector/DATAPATH/EXECUTION_UNIT/vect_mult/gen_processing_elements[3]/u_top8_pe/dadda_6/*}
add wave -position insertpoint {sim:/pipeline_tb/dut/vector/DATAPATH/EXECUTION_UNIT/vect_mult/gen_processing_elements[3]/u_top8_pe/dadda_7/*}
add wave -position insertpoint {sim:/pipeline_tb/dut/vector/DATAPATH/EXECUTION_UNIT/vect_mult/gen_processing_elements[3]/u_top8_pe/dadda_8/*}

add wave -divider {=== VEC CONTROLLER ===}
add wave -position insertpoint sim:/pipeline_tb/dut/vector/CONTROLLER/*

# ---------------------------------------------------------------------------
# Wave window settings
# ---------------------------------------------------------------------------
configure wave -namecolwidth 250
configure wave -valuecolwidth 120
configure wave -justifyvalue left
configure wave -signalnames full
configure wave -timelineunits ns

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------
run 100ns
wave zoom full

puts "\n>>> Simulation complete!\n"

