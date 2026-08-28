#!/bin/bash
set -e
cd "$(dirname "$0")"
echo "=== Boot ROM AXI Build ==="
verilator --binary -j 0 \
    --top-module boot_rom_axi_tb \
    --timing \
    --Mdir obj_dir_boot_rom_axi \
    -Wno-UNUSEDSIGNAL \
    -Wno-WIDTHEXPAND \
    -Wno-WIDTHTRUNC \
    tb/axi_lite_assertions.sv \
    tb/sky130_sram_1kbyte_1rw1r_32x256_8_sim.v \
    rtl/ram_axi.sv \
    tb/boot_rom_axi_tb.sv
echo ""
echo "=== Boot ROM AXI Run ==="
./obj_dir_boot_rom_axi/Vboot_rom_axi_tb
