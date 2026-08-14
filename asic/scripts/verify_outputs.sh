#!/usr/bin/env bash
# Zorunlu cikti ve raporlarin varligini kontrol eder (sartname 8)
ASIC="$(cd "$(dirname "$0")/.." && pwd)"; cd "$ASIC"
ok=0; miss=0
chk(){ if [ -e "$1" ]; then echo "  [VAR] $1"; ok=$((ok+1)); else echo "  [EKSIK] $1"; miss=$((miss+1)); fi; }
echo ">> Zorunlu fiziksel gorunumler:"
chk results/gds/ram_axi.gds
chk results/lef/ram_axi.lef
chk results/def/ram_axi.def
echo ">> Zorunlu ek ciktilar:"
chk results/netlist/ram_axi_synth.v
chk results/netlist/ram_axi_pnr.v
chk results/netlist/ram_axi_powered.v
chk results/sdc/signoff.sdc
chk results/metrics/metrics.csv
echo ">> Zorunlu raporlar:"
chk reports/general/flow.log
chk reports/synthesis
chk reports/timing
chk reports/drc
chk reports/lvs
chk reports/power
echo ">> Ortam:"
chk environment/versions.txt
chk environment/flake.nix
chk environment/flake.lock
chk README.md
echo ">> Sonuc: $ok var, $miss eksik"
[ $miss -eq 0 ] && echo ">> TUM ZORUNLU CIKTILAR MEVCUT" || echo ">> UYARI: eksik dosyalar var"
