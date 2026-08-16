#!/usr/bin/env bash
# RTL -> Verilog donusumu (sv2v). asic/ dizininden calistirilir.
set -e
ASIC="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ASIC/src"
sv2v -DSYNTHESIS -DYZ_IN_H=8 \
  "$ASIC/../rtl/yz_csr.sv" "$ASIC/../rtl/yz_accel.sv" "$ASIC/../rtl/yz_top_sram.sv" \
  > "$ASIC/src/yz_top_sram.v"
echo ">> src/yz_top_sram.v uretildi"
