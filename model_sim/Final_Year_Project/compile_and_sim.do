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

# ======= SCALAR PIPELINE =======
add wave -divider {=== FETCH ===}
add wave -position insertpoint sim:/pipeline_tb/dut/fetch_module/*

add wave -divider {=== DECODE ===}
add wave -position insertpoint sim:/pipeline_tb/dut/decode_module/*

add wave -divider {=== EXECUTE ===}
add wave -position insertpoint sim:/pipeline_tb/dut/execute_module/*

add wave -divider {=== LSU ===}
add wave -position insertpoint sim:/pipeline_tb/dut/lsu_module/*

add wave -divider {=== CSR ===}
add wave -position insertpoint sim:/pipeline_tb/dut/csr_module/*

add wave -divider {=== WRITEBACK ===}
add wave -position insertpoint sim:/pipeline_tb/dut/writeback_module/*

add wave -divider {=== FORWARD STALL ===}
add wave -position insertpoint sim:/pipeline_tb/dut/forward_stall_module/*

add wave -divider {=== DIVIDE ===}
add wave -position insertpoint sim:/pipeline_tb/dut/divide_module/*

add wave -divider {=== AMO ===}
add wave -position insertpoint sim:/pipeline_tb/dut/amo_module/*

add wave -divider {=== ROB ===}
add wave -position insertpoint sim:/pipeline_tb/dut/rob/*

# ======= VECTOR PROCESSOR =======
add wave -divider {=== VIQ ===}
add wave -position insertpoint sim:/pipeline_tb/dut/viq/*

add wave -divider {=== VECTOR PROCESSOR ===}
add wave -position insertpoint sim:/pipeline_tb/dut/vector/*

add wave -divider {=== VEC DECODER ===}
add wave -position insertpoint sim:/pipeline_tb/dut/vector/DATAPATH/DECODER/*

add wave -divider {=== VEC CSR REGFILE ===}
add wave -position insertpoint sim:/pipeline_tb/dut/vector/DATAPATH/CSR_REGFILE/*

add wave -divider {=== SEW/EEW MUX ===}
add wave -position insertpoint sim:/pipeline_tb/dut/vector/DATAPATH/SEW_EEW_MUX/*

add wave -divider {=== LMUL/EMUL MUX ===}
add wave -position insertpoint sim:/pipeline_tb/dut/vector/DATAPATH/LMUL_EMUL_MUX/*

add wave -divider {=== VLMAX/EVLMAX MUX ===}
add wave -position insertpoint sim:/pipeline_tb/dut/vector/DATAPATH/VLMAX_EVLMAX_MUX/*

add wave -divider {=== VEC REGFILE ===}
add wave -position insertpoint sim:/pipeline_tb/dut/vector/DATAPATH/VEC_REGFILE/*

add wave -divider {=== DATA1 MUX ===}
add wave -position insertpoint sim:/pipeline_tb/dut/vector/DATAPATH/DATA1_MUX/*

add wave -divider {=== DATA2 MUX ===}
add wave -position insertpoint sim:/pipeline_tb/dut/vector/DATAPATH/DATA2_MUX/*

add wave -divider {=== DATA3 MUX ===}
add wave -position insertpoint sim:/pipeline_tb/dut/vector/DATAPATH/DATA3_MUX/*

add wave -divider {=== VEC LSU ===}
add wave -position insertpoint sim:/pipeline_tb/dut/vector/DATAPATH/VLSU/*

add wave -divider {=== VLSU DATA MUX ===}
add wave -position insertpoint sim:/pipeline_tb/dut/vector/DATAPATH/VLSU_DATA_MUX/*

add wave -divider {=== VEC EXECUTION UNIT ===}
add wave -position insertpoint sim:/pipeline_tb/dut/vector/DATAPATH/EXECUTION_UNIT/*

add wave -divider {=== VEC EXECUTION UNIT TOP ===}
add wave -position insertpoint sim:/pipeline_tb/dut/vector/DATAPATH/EXECUTION_UNIT/clk
add wave -position insertpoint sim:/pipeline_tb/dut/vector/DATAPATH/EXECUTION_UNIT/reset
add wave -position insertpoint sim:/pipeline_tb/dut/vector/DATAPATH/EXECUTION_UNIT/execution_op
add wave -position insertpoint sim:/pipeline_tb/dut/vector/DATAPATH/EXECUTION_UNIT/sew
add wave -position insertpoint sim:/pipeline_tb/dut/vector/DATAPATH/EXECUTION_UNIT/execution_result
add wave -position insertpoint sim:/pipeline_tb/dut/vector/DATAPATH/EXECUTION_UNIT/execution_done

add wave -divider {=== ENABLE SIGNALS ===}
add wave -position insertpoint sim:/pipeline_tb/dut/vector/DATAPATH/EXECUTION_UNIT/add_en
add wave -position insertpoint sim:/pipeline_tb/dut/vector/DATAPATH/EXECUTION_UNIT/shift_en
add wave -position insertpoint sim:/pipeline_tb/dut/vector/DATAPATH/EXECUTION_UNIT/mult_en
add wave -position insertpoint sim:/pipeline_tb/dut/vector/DATAPATH/EXECUTION_UNIT/compare_en
add wave -position insertpoint sim:/pipeline_tb/dut/vector/DATAPATH/EXECUTION_UNIT/bitwise_en
add wave -position insertpoint sim:/pipeline_tb/dut/vector/DATAPATH/EXECUTION_UNIT/mult_add_en
add wave -position insertpoint sim:/pipeline_tb/dut/vector/DATAPATH/EXECUTION_UNIT/mask_add_en
add wave -position insertpoint sim:/pipeline_tb/dut/vector/DATAPATH/EXECUTION_UNIT/move_en

add wave -divider {=== DONE SIGNALS ===}
add wave -position insertpoint sim:/pipeline_tb/dut/vector/DATAPATH/EXECUTION_UNIT/sum_done
add wave -position insertpoint sim:/pipeline_tb/dut/vector/DATAPATH/EXECUTION_UNIT/shift_done
add wave -position insertpoint sim:/pipeline_tb/dut/vector/DATAPATH/EXECUTION_UNIT/mult_done
add wave -position insertpoint sim:/pipeline_tb/dut/vector/DATAPATH/EXECUTION_UNIT/compare_done
add wave -position insertpoint sim:/pipeline_tb/dut/vector/DATAPATH/EXECUTION_UNIT/bitwise_done
add wave -position insertpoint sim:/pipeline_tb/dut/vector/DATAPATH/EXECUTION_UNIT/product_sum_done
add wave -position insertpoint sim:/pipeline_tb/dut/vector/DATAPATH/EXECUTION_UNIT/sum_mask_done

add wave -divider {=== VEC ADDER UNIT ===}
add wave -position insertpoint sim:/pipeline_tb/dut/vector/DATAPATH/EXECUTION_UNIT/adder_inst/A
add wave -position insertpoint sim:/pipeline_tb/dut/vector/DATAPATH/EXECUTION_UNIT/adder_inst/B
add wave -position insertpoint sim:/pipeline_tb/dut/vector/DATAPATH/EXECUTION_UNIT/adder_inst/Ctrl
add wave -position insertpoint sim:/pipeline_tb/dut/vector/DATAPATH/EXECUTION_UNIT/adder_inst/sew_16_32
add wave -position insertpoint sim:/pipeline_tb/dut/vector/DATAPATH/EXECUTION_UNIT/adder_inst/sew_32
add wave -position insertpoint sim:/pipeline_tb/dut/vector/DATAPATH/EXECUTION_UNIT/adder_inst/Sum
add wave -position insertpoint sim:/pipeline_tb/dut/vector/DATAPATH/EXECUTION_UNIT/adder_inst/carry_out
add wave -position insertpoint sim:/pipeline_tb/dut/vector/DATAPATH/EXECUTION_UNIT/adder_inst/sum_done

add wave -divider {=== VEC MULTIPLIER UNIT ===}
add wave -position insertpoint sim:/pipeline_tb/dut/vector/DATAPATH/EXECUTION_UNIT/vect_mult/clk
add wave -position insertpoint sim:/pipeline_tb/dut/vector/DATAPATH/EXECUTION_UNIT/vect_mult/reset
add wave -position insertpoint sim:/pipeline_tb/dut/vector/DATAPATH/EXECUTION_UNIT/vect_mult/data_in_A
add wave -position insertpoint sim:/pipeline_tb/dut/vector/DATAPATH/EXECUTION_UNIT/vect_mult/data_in_B
add wave -position insertpoint sim:/pipeline_tb/dut/vector/DATAPATH/EXECUTION_UNIT/vect_mult/sew
add wave -position insertpoint sim:/pipeline_tb/dut/vector/DATAPATH/EXECUTION_UNIT/vect_mult/signed_mode
add wave -position insertpoint sim:/pipeline_tb/dut/vector/DATAPATH/EXECUTION_UNIT/vect_mult/start
add wave -position insertpoint sim:/pipeline_tb/dut/vector/DATAPATH/EXECUTION_UNIT/vect_mult/mult_done
add wave -position insertpoint sim:/pipeline_tb/dut/vector/DATAPATH/EXECUTION_UNIT/vect_mult/product

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

add wave -divider {=== VEC COMPARE UNIT ===}
add wave -position insertpoint sim:/pipeline_tb/dut/vector/DATAPATH/EXECUTION_UNIT/vect_comp/dataA
add wave -position insertpoint sim:/pipeline_tb/dut/vector/DATAPATH/EXECUTION_UNIT/vect_comp/dataB
add wave -position insertpoint sim:/pipeline_tb/dut/vector/DATAPATH/EXECUTION_UNIT/vect_comp/cmp_op
add wave -position insertpoint sim:/pipeline_tb/dut/vector/DATAPATH/EXECUTION_UNIT/vect_comp/sew
add wave -position insertpoint sim:/pipeline_tb/dut/vector/DATAPATH/EXECUTION_UNIT/vect_comp/compare_result
add wave -position insertpoint sim:/pipeline_tb/dut/vector/DATAPATH/EXECUTION_UNIT/vect_comp/compare_done

add wave -divider {=== VEC BITWISE UNIT ===}
add wave -position insertpoint sim:/pipeline_tb/dut/vector/DATAPATH/EXECUTION_UNIT/vect_bitwise/dataA
add wave -position insertpoint sim:/pipeline_tb/dut/vector/DATAPATH/EXECUTION_UNIT/vect_bitwise/dataB
add wave -position insertpoint sim:/pipeline_tb/dut/vector/DATAPATH/EXECUTION_UNIT/vect_bitwise/bitwise_op
add wave -position insertpoint sim:/pipeline_tb/dut/vector/DATAPATH/EXECUTION_UNIT/vect_bitwise/sew
add wave -position insertpoint sim:/pipeline_tb/dut/vector/DATAPATH/EXECUTION_UNIT/vect_bitwise/bitwise_result
add wave -position insertpoint sim:/pipeline_tb/dut/vector/DATAPATH/EXECUTION_UNIT/vect_bitwise/bitwise_done

add wave -divider {=== VEC SHIFT UNIT ===}
add wave -position insertpoint sim:/pipeline_tb/dut/vector/DATAPATH/EXECUTION_UNIT/vector_shift/dataA
add wave -position insertpoint sim:/pipeline_tb/dut/vector/DATAPATH/EXECUTION_UNIT/vector_shift/dataB
add wave -position insertpoint sim:/pipeline_tb/dut/vector/DATAPATH/EXECUTION_UNIT/vector_shift/shift_op
add wave -position insertpoint sim:/pipeline_tb/dut/vector/DATAPATH/EXECUTION_UNIT/vector_shift/sew
add wave -position insertpoint sim:/pipeline_tb/dut/vector/DATAPATH/EXECUTION_UNIT/vector_shift/shift_result
add wave -position insertpoint sim:/pipeline_tb/dut/vector/DATAPATH/EXECUTION_UNIT/vector_shift/shift_done

add wave -divider {=== VEC MULT_ADD UNIT ===}
add wave -position insertpoint sim:/pipeline_tb/dut/vector/DATAPATH/EXECUTION_UNIT/mult_add/clk
add wave -position insertpoint sim:/pipeline_tb/dut/vector/DATAPATH/EXECUTION_UNIT/mult_add/reset
add wave -position insertpoint sim:/pipeline_tb/dut/vector/DATAPATH/EXECUTION_UNIT/mult_add/data_A
add wave -position insertpoint sim:/pipeline_tb/dut/vector/DATAPATH/EXECUTION_UNIT/mult_add/data_B
add wave -position insertpoint sim:/pipeline_tb/dut/vector/DATAPATH/EXECUTION_UNIT/mult_add/data_C
add wave -position insertpoint sim:/pipeline_tb/dut/vector/DATAPATH/EXECUTION_UNIT/mult_add/accum_op
add wave -position insertpoint sim:/pipeline_tb/dut/vector/DATAPATH/EXECUTION_UNIT/mult_add/sew
add wave -position insertpoint sim:/pipeline_tb/dut/vector/DATAPATH/EXECUTION_UNIT/mult_add/signed_mode
add wave -position insertpoint sim:/pipeline_tb/dut/vector/DATAPATH/EXECUTION_UNIT/mult_add/start
add wave -position insertpoint sim:/pipeline_tb/dut/vector/DATAPATH/EXECUTION_UNIT/mult_add/sum_product_result
add wave -position insertpoint sim:/pipeline_tb/dut/vector/DATAPATH/EXECUTION_UNIT/mult_add/product_sum_done

add wave -divider {=== VEC MASK ADD UNIT ===}
add wave -position insertpoint sim:/pipeline_tb/dut/vector/DATAPATH/EXECUTION_UNIT/mask_add_sub/adder_data_1
add wave -position insertpoint sim:/pipeline_tb/dut/vector/DATAPATH/EXECUTION_UNIT/mask_add_sub/adder_data_2
add wave -position insertpoint sim:/pipeline_tb/dut/vector/DATAPATH/EXECUTION_UNIT/mask_add_sub/mask_reg
add wave -position insertpoint sim:/pipeline_tb/dut/vector/DATAPATH/EXECUTION_UNIT/mask_add_sub/sew
add wave -position insertpoint sim:/pipeline_tb/dut/vector/DATAPATH/EXECUTION_UNIT/mask_add_sub/sum_mask_result
add wave -position insertpoint sim:/pipeline_tb/dut/vector/DATAPATH/EXECUTION_UNIT/mask_add_sub/sum_mask_done

add wave -divider {=== SEQ NUM ===}
add wave -position insertpoint sim:/pipeline_tb/dut/vector/DATAPATH/EXECUTION_UNIT/seq_num
add wave -position insertpoint sim:/pipeline_tb/dut/vector/DATAPATH/EXECUTION_UNIT/seq_num_held
add wave -position insertpoint sim:/pipeline_tb/dut/vector/DATAPATH/EXECUTION_UNIT/seq_num_exe

add wave -divider {=== MASK UNIT ===}
add wave -position insertpoint sim:/pipeline_tb/dut/vector/DATAPATH/MASK_UNIT/*

add wave -divider {=== VEC CONTROLLER ===}
add wave -position insertpoint sim:/pipeline_tb/dut/vector/CONTROLLER/*

# ======= SYSTEM =======
add wave -divider {=== VAL READY ===}
add wave -position insertpoint sim:/pipeline_tb/dut/val_ready/*

add wave -divider {=== MEMORY ===}
add wave -position insertpoint sim:/pipeline_tb/dut/memory/*

add wave -divider {=== DBUS INTERCONNECT ===}
add wave -position insertpoint sim:/pipeline_tb/dut/dbus/*

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
