#!/usr/bin/env bash
set -e
ASIC="$(cd "$(dirname "$0")/.." && pwd)"
ROOT="$ASIC/.."
CV="$ROOT/cv32e40p/rtl"
mkdir -p "$ASIC/src"
sv2v -DSYNTHESIS -DYZ_IN_H=8 \
  -I"$CV/include" -I"$ROOT/cv32e40p/bhv" -I"$ROOT/cv32e40p/bhv/include" \
  "$CV/include/cv32e40p_apu_core_pkg.sv" \
  "$CV/include/cv32e40p_fpu_pkg.sv" \
  "$CV/include/cv32e40p_pkg.sv" \
  "$CV/cv32e40p_if_stage.sv" "$CV/cv32e40p_cs_registers.sv" \
  "$CV/cv32e40p_register_file_ff.sv" "$CV/cv32e40p_load_store_unit.sv" \
  "$CV/cv32e40p_id_stage.sv" "$CV/cv32e40p_aligner.sv" \
  "$CV/cv32e40p_decoder.sv" "$CV/cv32e40p_compressed_decoder.sv" \
  "$CV/cv32e40p_fifo.sv" "$CV/cv32e40p_prefetch_buffer.sv" \
  "$CV/cv32e40p_hwloop_regs.sv" "$CV/cv32e40p_mult.sv" \
  "$CV/cv32e40p_int_controller.sv" "$CV/cv32e40p_ex_stage.sv" \
  "$CV/cv32e40p_alu_div.sv" "$CV/cv32e40p_alu.sv" \
  "$CV/cv32e40p_ff_one.sv" "$CV/cv32e40p_popcnt.sv" \
  "$CV/cv32e40p_apu_disp.sv" "$CV/cv32e40p_controller.sv" \
  "$CV/cv32e40p_obi_interface.sv" "$CV/cv32e40p_prefetch_controller.sv" \
  "$CV/cv32e40p_sleep_unit.sv" "$CV/cv32e40p_core.sv" "$CV/cv32e40p_top.sv" \
  "$ROOT/cv32e40p/bhv/cv32e40p_sim_clock_gate.sv" \
  "$ROOT/rtl/obi_to_axi_lite.sv" "$ROOT/rtl/ram_axi.sv" \
  "$ROOT/rtl/gpio_axi.sv" "$ROOT/rtl/timer_axi.sv" \
  "$ROOT/rtl/uart_axi.sv" "$ROOT/rtl/i2c_master_axi.sv" \
  "$ROOT/rtl/yz_csr.sv" "$ROOT/rtl/yz_accel.sv" "$ROOT/rtl/yz_top.sv" \
  "$ROOT/rtl/soc_top_axi.sv" \
  > "$ASIC/src/soc_top_axi.v"
echo ">> src/soc_top_axi.v uretildi ($(wc -l < "$ASIC/src/soc_top_axi.v") satir)"
