#!/usr/bin/env bash
# ============================================================
# collect_outputs.sh -- LibreLane run ciktilarini sartname
# Tablo 8 yapisina (asic/reports, asic/results) toplar.
# Kullanim: asic/ dizininden  ->  bash scripts/collect_outputs.sh [run_tag]
# ============================================================
set -u
TAG="${1:-run1}"
ASIC="$(cd "$(dirname "$0")/.." && pwd)"
RUN="$ASIC/runs/$TAG"
DES="ram_axi"

[ -d "$RUN" ] || { echo "HATA: $RUN yok. Once akisi calistir."; exit 1; }

echo ">> Ciktilar toplaniyor: $RUN"

# --- dizinleri hazirla ---
mkdir -p "$ASIC"/reports/{general,lint,synthesis,timing,drc,lvs,antenna,pdn,routing,power,signoff}
mkdir -p "$ASIC"/results/{def,gds,lef,netlist,odb,sdc,sdf,spef,spice,lib,mag,images,config,metrics}

c(){ cp -f $1 "$2" 2>/dev/null && echo "  ok: $(basename $1)" || true; }

F="$RUN/final"

# ================= RESULTS =================
c "$F/def/$DES.def"            "$ASIC/results/def/"
c "$F/gds/$DES.gds"            "$ASIC/results/gds/$DES.gds"
c "$F/mag_gds/$DES.magic.gds"  "$ASIC/results/gds/${DES}_magic.gds"
c "$F/klayout_gds/$DES.klayout.gds" "$ASIC/results/gds/${DES}_klayout.gds"
c "$F/lef/$DES.lef"            "$ASIC/results/lef/"
c "$F/nl/$DES.nl.v"            "$ASIC/results/netlist/${DES}_pnr.v"
c "$F/pnl/$DES.pnl.v"          "$ASIC/results/netlist/${DES}_powered.v"
c "$RUN/06-yosys-synthesis/$DES.nl.v" "$ASIC/results/netlist/${DES}_synth.v"
c "$F/odb/$DES.odb"            "$ASIC/results/odb/"
c "$F/sdc/$DES.sdc"            "$ASIC/results/sdc/signoff.sdc"
c "$F/mag/$DES.mag"            "$ASIC/results/mag/"
cp -rf "$F/sdf/"* "$ASIC/results/sdf/" 2>/dev/null || true
cp -rf "$F/spef/"* "$ASIC/results/spef/" 2>/dev/null || true
cp -rf "$F/lib/"* "$ASIC/results/lib/" 2>/dev/null || true
# LVS spice (nihai netlist)
find "$RUN" -name "$DES.spice" -exec cp -f {} "$ASIC/results/spice/" \; 2>/dev/null || true
c "$F/metrics.csv"            "$ASIC/results/metrics/"
c "$F/metrics.json"           "$ASIC/results/metrics/"
c "$RUN/resolved.json"        "$ASIC/results/config/resolved.json"

# ================= REPORTS =================
# genel
c "$RUN/flow.log"      "$ASIC/reports/general/"
c "$RUN/warning.log"   "$ASIC/reports/general/"
c "$RUN/error.log"     "$ASIC/reports/general/"
c "$RUN/resolved.json" "$ASIC/reports/general/"
# lint
cp -rf "$RUN"/01-verilator-lint/* "$ASIC/reports/lint/" 2>/dev/null || true
# sentez
cp -rf "$RUN"/06-yosys-synthesis/reports/* "$ASIC/reports/synthesis/" 2>/dev/null || true
cp -f  "$RUN"/06-yosys-synthesis/*.log "$ASIC/reports/synthesis/" 2>/dev/null || true
# timing (post-PnR STA, tum corner'lar)
cp -rf "$RUN"/54-openroad-stapostpnr/* "$ASIC/reports/timing/" 2>/dev/null || true
# drc
cp -rf "$RUN"/62-magic-drc/reports/* "$ASIC/reports/drc/" 2>/dev/null || true
# lvs
cp -rf "$RUN"/67-netgen-lvs/reports/* "$ASIC/reports/lvs/" 2>/dev/null || true
cp -f  "$RUN"/67-netgen-lvs/*.log "$ASIC/reports/lvs/" 2>/dev/null || true
# antenna
cp -rf "$RUN"/45-openroad-checkantennas-1/reports/* "$ASIC/reports/antenna/" 2>/dev/null || true
cp -f  "$RUN"/45-openroad-checkantennas-1/*.rpt "$ASIC/reports/antenna/" 2>/dev/null || true
# pdn
cp -f  "$RUN"/21-openroad-generatepdn/*.rpt "$ASIC/reports/pdn/" 2>/dev/null || true
# routing (wirelength + tr drc)
cp -f  "$RUN"/49-odb-reportwirelength/*.csv "$ASIC/reports/routing/" 2>/dev/null || true
cp -rf "$RUN"/46-checker-trdrc/reports/* "$ASIC/reports/routing/" 2>/dev/null || true
# power / ir-drop
cp -f  "$RUN"/55-openroad-irdropreport/*.rpt "$ASIC/reports/power/" 2>/dev/null || true
cp -rf "$RUN"/55-openroad-irdropreport/* "$ASIC/reports/power/" 2>/dev/null || true
# signoff (manufacturability)
cp -rf "$RUN"/73-misc-reportmanufacturability/* "$ASIC/reports/signoff/" 2>/dev/null || true
# metrikler her iki bicimde signoff'a da
c "$F/metrics.csv"  "$ASIC/reports/signoff/"
c "$F/metrics.json" "$ASIC/reports/signoff/"

echo ">> Tamamlandi. Ozet:"
find "$ASIC/results" -type f | wc -l | xargs echo "   results dosya sayisi:"
find "$ASIC/reports" -type f | wc -l | xargs echo "   reports dosya sayisi:"
