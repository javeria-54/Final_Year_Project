# =============================================================================
# compile_and_sim.do — Questa Transcript mein chalao:
#     do compile_and_sim.do
# =============================================================================

# ---------------------------------------------------------------------------
# Work library banao
# ---------------------------------------------------------------------------
if {[file exists work]} {
    vdel -lib work -all
}
vlib work
vmap work work

# ---------------------------------------------------------------------------
# Compile — pehle packages/defs, phir baaki sab
# ---------------------------------------------------------------------------
puts "\n=============================="
puts "  Compiling..."
puts "==============================\n"

# Pehle packages aur defs
vlog -sv -work work +incdir+. \
    pcore_types_pkg.sv \
    axi_4_defs.svh \
    scalar_a_ext_defs.svh \
    scalar_csr_defs.svh \
    scalar_gpio_defs.svh \
    scalar_m_ext_defs.svh \
    scalar_pcore_config_defs.svh \
    scalar_pcore_interface_defs.svh \
    scalar_plic_defs.svh \
    scalar_spi_defs.svh \
    scalar_uart_defs.svh \
    vector_csr_regfile_defs.svh \
    vector_de_csr_defs.svh \
    vector_decode_defs.svh \
    vector_execution_unit.svh \
    vector_mask_unit_defs.svh \
    vector_processor_defs.svh \
    vector_regfile_defs.svh

# Phir baaki saari .sv files
vlog -sv -work work +incdir+. \
    rob.sv \
    rob_tb.sv \
    scalar_amo.sv \
    scalar_csr.sv \
    scalar_dbus_interconnect.sv \
    scalar_decode.sv \
    scalar_divide.sv \
    scalar_divider.sv \
    scalar_execute.sv \
    scalar_fetch.sv \
    scalar_forward_stall.sv \
    scalar_lsu.sv \
    scalar_memory.sv \
    scalar_pipeline_tb.sv \
    scalar_pipeline_top.sv \
    scalar_reg_file.sv \
    scalar_val_ready_controller.sv \
    scalar_writeback.sv \
    vector_adder_subtractor_tb.sv \
    vector_adder_subtractor_unit.sv \
    vector_bitwise_unit.sv \
    vector_bitwise_unit_tb.sv \
    vector_compare_unit.sv \
    vector_csr_dec.sv \
    vector_csr_dec_tb.sv \
    vector_csr_regfile.sv \
    vector_csr_regfile_tb.sv \
    vector_decode.sv \
    vector_decode_tb.sv \
    vector_execution_unit.sv \
    vector_instruction_queue.sv \
    vector_lsu.sv \
    vector_lsu_tb.sv \
    vector_mask_add_sub.sv \
    vector_mask_unit.sv \
    vector_mask_unit_tb.sv \
    vector_multiplier.sv \
    vector_multiply_add_unit.sv \
    vector_processor.sv \
    vector_processor_controller.sv \
    vector_processor_controller_tb.sv \
    vector_processor_datapath.sv \
    vector_processor_tb.sv \
    vector_regfile.sv \
    vector_regfile_tb.sv \
    vector_shift_module.sv \
    vector_val_ready_controller.sv

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

delete wave *

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
run -all
wave zoom full

puts "\n>>> Simulation complete!\n"
