#!/bin/bash
# build_ram_axi.sh -- RAM AXI4-Lite Bagimsiz Build & Run
set -e
cd "$(dirname "$0")"
echo "=== RAM AXI Build ==="
verilator --binary -j 0 \
    --top-module ram_axi_tb \
    --timing \
    --Mdir obj_dir_ram_axi \
    -Wno-UNUSEDSIGNAL \
    -Wno-WIDTHEXPAND \
    -Wno-WIDTHTRUNC \
    tb/axi_lite_assertions.sv \
    tb/sky130_sram_1kbyte_1rw1r_32x256_8_sim.v \
    rtl/ram_axi.sv \
    tb/ram_axi_tb.sv
echo ""
echo "=== RAM AXI Run ==="
./obj_dir_ram_axi/Vram_axi_tb
