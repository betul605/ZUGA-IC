# ASIC Fiziksel Tasarim Teslimi - ram_axi

TEKNOFEST 2026 Cip Tasarim Yarismasi - Mikrodenetleyici Tasarim Kategorisi, Final.
ram_axi tasariminin LibreLane Classic akisi ile SKY130 (sky130A) teknolojisinde
uretilmis ASIC fiziksel tasarim teslim paketi.

## 9.1. Tasarim Ozeti
- Aciklama: ram_axi, AXI4-Lite kole arayuzune sahip, fiziksel SKY130 SRAM makrosu
  tabanli bir RAM blogudur. Yeniden kullanilabilir fiziksel makro / ust seviye ASIC
  blogu olarak, bir SoC icinde CPU'nun AXI4-Lite veri yoluna baglanir.
- En ust seviye modul adi: ram_axi
- Temel arayuzler: AXI4-Lite (AW/W/B yazma, AR/R okuma), 32-bit veri, 32-bit adres,
  4-bit write-strobe (byte-enable).
- Saat/reset: clk_i (birincil saat), rst_ni (aktif dusuk asenkron reset).
- Hedef frekans: 50 MHz (20 ns periyot).
- Bellek: 1 KiB, 256 kelime x 32 bit; SRAM makrosu sky130_sram_1kbyte_1rw1r_32x256_8.

## 9.2. Arac ve Ortam Bilgileri
- LibreLane: 3.0.6 (commit ba7193bff33d68941683b2963b90aa30cea117d1), akis: Classic
- PDK: sky130A - Open PDKs commit 8afc8346a57fe1ab7934ba5a6056ea8b43078e71
- Standart hucre kutuphanesi: sky130_fd_sc_hd
- OpenRAM: Kullanilmadi (onceden onaylanmis hazir SRAM makrosu - sartname 1.3)
- Araclar: Yosys 0.62, OpenROAD dcf36133, Magic 8.3.623, KLayout 0.30.7,
  Netgen ve Verilator (LibreLane 3.0.6 nix-eda 6.11.0 ortami)
- Ortam: Nix (Determinate Nix 3.21.9). Ayrinti: environment/versions.txt,
  environment/flake.nix, environment/flake.lock

## 9.3. Akisin Calistirilmasi
    cd ~/librelane && nix develop
    ciel enable --pdk-family sky130 8afc8346a57fe1ab7934ba5a6056ea8b43078e71
    cd <repo>/asic && make asic_run

- make asic_run: runs/run1 calisma alanini temizler, LibreLane Classic akisini
  calistirir, sonra scripts/collect_outputs.sh ile raporlari reports/ ve nihai
  ciktilari results/ altina toplar.
- make asic_verify: zorunlu cikti/raporlarin varligini kontrol eder.
- make asic_clean: gecici calisma alanini temizler.
- Yaklasik sure: ~20-30 dk. Onerilen: >=8 cekirdek, >=16 GB RAM, >=20 GB disk.
- LibreLane calisma alani asic/runs/<tag>/ altinda otomatik olusur, .gitignore ile
  depoya dahil edilmez. asic/run/ yer tutucu bos calisma dizinidir.

## 9.4. RTL ve Akis Girdileri
- Dosya listesi: asic/filelist.f (RTL: rtl/ram_axi.sv, depo kokune gore).
- Ana yapilandirma: asic/config.yaml. Zamanlama kisiti: asic/constraints/design.sdc.
- Include/define/makro: Kullanilmadi. Guc pinleri USE_POWER_PINS ile kosullu baglanir.
- Ana RTL: rtl/ram_axi.sv. En ust modul ram_axi; config.yaml, filelist.f ve RTL
  modul adi uyumludur.

## 9.5. SRAM ve Fiziksel Makrolar
- Makro: sky130_sram_1kbyte_1rw1r_32x256_8, instance u_sram.
- Kaynak: referans sky130A PDK (Open PDKs 8afc8346...), libs.ref/sky130_sram_macros/.
  Onceden onaylanmis hazir makro (sartname 1.3).
- Kapasite: 1 KiB - 256 kelime x 32 bit - 1RW+1R - 8-bit yazma granularitesi.
- Gorunumler: asic/macros/sky130_sram_1kbyte_1rw1r_32x256_8/ altinda gds/, lef/,
  verilog/, lib/ (3 corner: TT/SS/FF), spice/.
- Guc pinleri: vccd1/vssd1 -> VPWR/VGND (VDD_NETS: [VPWR], GND_NETS: [VGND]).
- Veri yoluna baglanti: SRAM Port A (1RW) AXI4-Lite state machine ile okuma+yazma
  icin kullanilir. Port B (1R) kullanilmaz, guvenli sabitlenir. SRAM sentezde
  korunur; nihai netlist, DEF ve GDSII'de bulunur.
- Liberty: TT/SS/FF uc zorunlu signoff corner'i kapsar.

## 9.6. Zamanlama Kisitlari ve Istisnalari
- Birincil saat: clk_i, 20 ns (50 MHz). Clock uncertainty: 0.25 ns.
- Input delay: 2.0 ns (saat haric tum girisler). Output delay: 2.0 ns (tum cikislar).
- Generated clock: Yok. Coklu saat alani / asenkron grup: Yok (tek saat).
- False path / multicycle path: KULLANILMADI. Hicbir gercek yol istisna ile
  maskelenmemistir.
- Asenkron reset: rst_ni; ozel zamanlama istisnasi tanimlanmamistir.

## 9.7. Fiziksel Tasarim Yapilandirmasi
- Die alani: 0,0 - 640,540 um (mutlak). FP_CORE_UTIL 40; elde edilen ~%59.5.
- PL_TARGET_DENSITY: 0.45. Makro: u_sram sabit (70,70), yonelim N.
- IO: otomatik. Yonlendirme: RT_MAX_LAYER met4. Guc aglari: VPWR/VGND, PDN otomatik.
- CTS: LibreLane Classic varsayilan. MAX_TRANSITION_CONSTRAINT: 0.75 (bkz 9.9).
- Otomasyon: asic/Makefile, asic/scripts/collect_outputs.sh.

## 9.8. Lint Sonuclari ve Istisnalari
- Verilator lint: 0 hata, 5 uyari, 0 inferred latch, 0 timing construct.
- 5 uyarinin tamami onaylanmis SRAM makrosunun kendi davranissal Verilog
  modelinden (sky130_sram_1kbyte_1rw1r_32x256_8.v) kaynaklanir (BLKSEQ:
  ardisik blokta blocking atama; PINCONNECTEMPTY: kullanilmayan Port B dout1).
  Bunlar ucuncu taraf makro gorunumune aittir, degistirilemez (sartname 1.3).
- Tasarima ait (ram_axi.sv) lint hatasi/uyarisi yoktur. Lint waiver kullanilmadi.

## 9.9. Bilinen Sorunlar ve Kabul Edilmis Istisnalar
Asagidaki durumlar onaylanmis SKY130 SRAM makrosunun ozelliklerinden kaynaklanir;
makro fiziksel/mantiksal gorunumleri sartname 1.3 geregi degistirilemez.

1) SRAM giris pini max_transition (0.04 ns): Makronun Liberty modelinde giris
   pinleri icin tanimli max_transition (0.04 ns) fiziksel olarak karsilanamamaktadir
   (elde edilebilen en iyi ~0.043 ns). Bu nedenle post-global-placement design
   repair adimi (RUN_POST_GPL_DESIGN_REPAIR: false) devre disi birakilmistir. Sonuc:
   9 corner'da 12 max-slew ve 2-3 max-cap uyarisi (yalnizca SRAM giris netleri).
   Sinyal fonksiyonu ve zamanlama kapanisi etkilenmez (setup/hold ihlali 0).

2) Magic DRC nwell.4 (210 ihlal): MAGIC_DRC_USE_GDS: false ile SRAM soyut (LEF)
   olarak degerlendirilmistir (aksi halde SRAM ic geometrisi 2.8M+ ihlal uretir;
   makro onceden onaylidir, ic DRC'si sartname 1.3 geregi yeniden dogrulanmaz).
   Kalan 210 nwell.4 ihlali SRAM'e komsu fill/margin bolgesindeki well-tap
   kaynaklidir (x=5-60 um seridi). Sinyal yonlendirmesi DRC'si (OpenROAD detailed
   routing) 0 ihlaldir. Magic DRC bu nedenle olumcul olmayan (ERROR_ON_MAGIC_DRC:
   false) olarak isaretlenmis, tum ihlaller seffaf sekilde raporlanmistir
   (reports/drc/drc.magic.rpt).

3) KLayout DRC ve KLayout Render: Onaylanmis SRAM makrosunun GDSII hiyerarsisi
   coklu top-cell icerdiginden (Layout::top_cell), KLayout DRC ve on-izleme render
   adimlari calistirilamamistir (--skip KLayout.DRC, KLayout.Render). Birincil DRC
   imzasi Magic DRC + OpenROAD detailed routing DRC (0 ihlal) uzerinden yapilmistir.

4) iverilog doCheck override: LibreLane flake.nix icinde iverilog paketi icin
   doCheck=false uygulanmistir (iverilog kendi test paketinde bu ortamda 1 testte
   takiliyor; arac islevsel olarak calisir). Bu yalnizca ortam kurulumunu etkiler,
   tasarim sonuclarini etkilemez.

Bunlar disinda bilinen bir tasarim hatasi veya ihlali yoktur.

## 9.10. Guc ve IR-Drop Analizi
- Saat frekansi: 50 MHz. Corner: tt/ss/ff (uc zorunlu signoff corner'i).
- Besleme gerilimi: 1.8 V (tt), 1.6 V (ss), 1.95 V (ff).
- Switching activity: Acik switching activity girdisi KULLANILMADI; guc sonuclari
  TAHMINIDIR (LibreLane varsayilan aktivite varsayimlari).
- Ozel gerilim kaynagi konum dosyasi (VSRC_LOC_FILES): KULLANILMADI. IR-drop analizi
  varsayilan kaynak konumuyla calisir; degerler yaklasiktir.
- Raporlar: reports/power/ (corner bazli power.rpt ve irdrop.rpt).

## 9.11. Signoff Sonuc Ozeti
- Signoff PVT corner'lari: tt_025C_1v80, ss_100C_1v60, ff_n40C_1v95 (min/nom/max).
- Setup: 9 corner'da 0 ihlal (WNS >= +6.5 ns). Hold: 9 corner'da 0 ihlal (WNS > 0).
- Setup TNS = 0, Hold TNS = 0 (tum corner'lar).
- Magic DRC: 210 nwell.4 (SRAM komsu fill; bkz 9.9). KLayout DRC: calistirilamadi (9.9).
- OpenROAD detailed routing DRC: 0 ihlal.
- Netgen LVS: "Circuits match uniquely" (temiz eslesme).
- Anten: 0 ihlal. PDN grid: 0 ihlal (VPWR/VGND).
- Max fanout: 0. Max slew: 12, Max cap: 2-3 (yalnizca SRAM giris pinleri; bkz 9.9).

## 9.12. Rapor ve Cikti Konumlari
- LibreLane calisma etiketi: run1.
- Esas nihai GDSII: results/gds/ram_axi.gds (Magic streamout). Ayrica
  results/gds/ram_axi_magic.gds ve results/gds/ram_axi_klayout.gds saglanmistir.
- Zorunlu gorunumler: results/gds/, results/lef/, results/def/.
- Zorunlu ek ciktilar: results/netlist/ (synth, pnr, powered), results/sdc/,
  results/spef/, results/spice/, results/config/, results/metrics/.
- Zorunlu raporlar: reports/{general,lint,synthesis,timing,drc,lvs,antenna,pdn,
  routing,power,signoff}/.
- Cikti toplama: make asic_run icindeki scripts/collect_outputs.sh, akis sonunda
  runs/run1/ altindan reports/ ve results/ altina kopyalar.

## 9.13. Ucuncu Taraf Bilesenler ve Lisanslar
Ayrinti: asic/THIRD_PARTY.md.
- LibreLane 3.0.6 (Apache-2.0), fossi-foundation/librelane.
- SKY130 PDK / Open PDKs (Apache-2.0), commit 8afc8346...
- sky130_fd_sc_hd standart hucre kutuphanesi (Apache-2.0).
- SRAM makrosu sky130_sram_1kbyte_1rw1r_32x256_8 (OpenRAM/sky130, Apache-2.0);
  referans PDK ile saglanan onceden onaylanmis makro, degistirilmeden kullanildi.
- Yosys, OpenROAD, Magic, Netgen, KLayout, Verilator: LibreLane 3.0.6 nix-eda
  ortami ile saglanmistir (ilgili acik kaynak lisanslar).
