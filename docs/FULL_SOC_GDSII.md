# Full SoC Fiziksel Tasarim (soc_top_axi -> GDSII)

Tum mikrodenetleyiciyi (CV32E40P + tum cevre birimleri + YZ hizlandirici)
RTL->GDSII fiziksel akistan geciren calisma ve sonuclari.

## Sonuc (LibreLane Classic, SKY130 / sky130A)
- Akis: RTL -> sv2v -> Yosys sentez -> floorplan -> P&R -> CTS -> routing -> signoff -> GDSII. "Flow complete".
- LVS: **Circuits match uniquely** (Netgen).
- Zamanlama: setup ve hold **uc signoff kosesinde de karsilandi** (tt/ss/ff).
  Setup WS: +35.2 ns (tt), +21.9 ns (ss), +40.5 ns (ff) @ 100 ns saat. Hold WS: pozitif.
- Die alani: ~1.82 mm2 (stdcell ~1.22 mm2), ~49.000 hucre.
- Antenna: 1 net / 1 pin (357 diode eklendi).
- Kalan signoff cilasi: max-slew (~40k) / max-cap (~400) ihlalleri -> 2. gecis buffer'lama.

## Kapsam / durustluk notu
Bu fiziksel build, alan/makro fizibilitesi (tek 1 KB referans SRAM makrosu,
resmi PDK/makro duyurusu oncesi) icin **temsili/indirgenmis bellek konfigu**
kullanir; mimari ve datapath kanonik tasarimla aynidir, yalnizca olcek kucuktur:
- YZ: kucuk konfig (IN 8x8, N_FILT 2, FEAT 128) — kanonik RTL 49x40/FEAT 4000.
- instr_mem: 1024 word (kanonik 2176).
Tam 8 KB I + 8 KB D + 30 KB YZ fiziksel bellek, resmi SRAM makrolari gelince
2. fazda SRAM makrolarina tasinacaktir (YZ datapath'i registered-read icin pipeline'lanarak).

## Yeniden uretim (ozet)
1. Fiziksel-build: rtl/soc_top_axi.sv'de yz_top ornegini kucuk konfige al, instr_mem [0:1023] yap.
2. Verilog uret: gen_src_soc.sh (sv2v + sentez-disi $readmemh/$f* init temizligi).
3. Akis: librelane asic/config_soc.yaml (LibreLane Classic, sky130A).
4. Cikti: runs/<tag>/final/gds/soc_top_axi.gds + metrics.csv (LVS/DRC/timing).
Not: 168 MB GDS depoya konmaz (GitHub limiti); akisla yeniden uretilir.
