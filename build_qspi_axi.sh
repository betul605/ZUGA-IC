#!/bin/bash
set -e
cd "$(dirname "$0")"
echo "=== QSPI Master AXI Build ==="
verilator --binary -j 0 \
    --top-module qspi_master_axi_tb \
    --timing \
    --Mdir obj_dir_qspi_axi \
    -Wno-UNUSEDSIGNAL \
    -Wno-WIDTHEXPAND \
    -Wno-WIDTHTRUNC \
    -Wno-TIMESCALEMOD \
    -Wno-INITIALDLY \
    tb/axi_lite_assertions.sv \
    rtl/qspi_master_axi.sv \
    tb/qspi_master_axi_tb.sv
echo ""
echo "=== QSPI Master AXI Run ==="
./obj_dir_qspi_axi/Vqspi_master_axi_tb
