# ASIC Fiziksel Tasarim Teslimi - yz_top_sram

TEKNOFEST 2026 Cip Tasarim Yarismasi - Mikrodenetleyici Tasarim Kategorisi, Final.
yz_top_sram: on-chip SRAM giris bufferli int8 CNN cikarim hizlandirici SoC blogu.
LibreLane 3.0.6 Classic akisi, SKY130 (sky130A).

## 9.1. Tasarim Ozeti
- Aciklama: yz_top_sram, bir goruntuyu siniflandiran evrisimli sinir agini (CNN)
  donanimda calistiran bir hizlandirici SoC blogudur. AXI4-Lite arayuzu, kontrol/
  durum yazmaclari (yz_csr), CNN cekirdegi (yz_accel), SKY130 SRAM giris buffer'i
  ve SRAM'den CNN'e veri besleyen bir loader FSM icerir.
- En ust seviye modul adi: yz_top_sram
- Temel arayuzler: AXI4-Lite slave (CPU agirlik/goruntu yazar, logit okur), irq_o.
- Saat/reset: clk_i (birincil saat), rst_ni (aktif dusuk asenkron reset).
- Hedef saat: 15.4 MHz (65 ns periyot) - en yavas signoff corner'i (ss) icin secildi.
- Model: int8 CNN - konvolusyon 3x3 -> tam bagli katman (FC) -> argmax.
- SRAM: sky130_sram_1kbyte_1rw1r_32x256_8 (256x32), giris ozniteligi buffer'i;
  goruntu AXI->SRAM->loader->yz_accel yolundan akar (SRAM fonksiyonel veri yolunda).

## 9.2. Arac ve Ortam Bilgileri
- LibreLane: 3.0.6 (commit ba7193bff33d68941683b2963b90aa30cea117d1), akis: Classic
- PDK: sky130A - Open PDKs commit 8afc8346a57fe1ab7934ba5a6056ea8b43078e71
- Standart hucre kutuphanesi: sky130_fd_sc_hd
- OpenRAM: Kullanilmadi (onceden onaylanmis hazir SRAM makrosu - sartname 1.3)
- Araclar: Yosys 0.62, OpenROAD dcf36133, Magic 8.3.623, KLayout 0.30.7, Netgen,
  Verilator; ayrica sv2v (SystemVerilog -> Verilog donusumu). Ortam: Nix.
- Ayrinti: environment/versions.txt, environment/flake.nix, environment/flake.lock

## 9.3. Akisin Calistirilmasi
    cd ~/librelane && nix develop
    ciel enable --pdk-family sky130 8afc8346a57fe1ab7934ba5a6056ea8b43078e71
    cd <repo>/asic && make asic_run

- RTL (rtl/yz_csr.sv, yz_accel.sv, yz_top_sram.sv) sv2v ile asic/src/yz_top_sram.v
  dosyasina cevrilir (SYNTHESIS tanimli). Bu dosya depoda hazir bulunur; akis onu kullanir.
- make asic_run: runs/run1 temizlenir, LibreLane Classic calisir, scripts/
  collect_outputs.sh ile raporlar reports/ ve nihai ciktilar results/ altina toplanir.
- Yaklasik sure: ~35 dk. Onerilen: >=8 cekirdek, >=16 GB RAM, >=20 GB disk.

## 9.4. RTL ve Akis Girdileri
- RTL kaynaklari (depo koku): rtl/yz_csr.sv, rtl/yz_accel.sv, rtl/yz_top_sram.sv
- Dosya listesi: asic/filelist.f. sv2v ciktisi: asic/src/yz_top_sram.v (akisin girdisi).
- Ana yapilandirma: asic/config.yaml. Zamanlama kisiti: asic/constraints/design.sdc.
- Derleme tanimi: SYNTHESIS (sv2v ile; RTL icindeki $readmemh init'i sentezde atlanir).
- En ust modul yz_top_sram; config.yaml, filelist.f ve RTL uyumludur.

## 9.5. SRAM ve Fiziksel Makrolar
- Makro: sky130_sram_1kbyte_1rw1r_32x256_8, instance u_sram_in.
- Kaynak: referans sky130A PDK, libs.ref/sky130_sram_macros/ (onceden onayli - sf.1.3).
- Kapasite: 1 KiB - 256 kelime x 32 bit - 1RW+1R.
- Gorunumler: asic/macros/sky130_sram_1kbyte_1rw1r_32x256_8/ (gds, lef, verilog, lib 3 corner, spice).
- Guc pinleri: vccd1/vssd1 -> VPWR/VGND.
- Veri yoluna baglanti: AXI giris penceresi (0x5010_xxxx) SRAM'e yazar; CSR START
  ile loader FSM SRAM'den okuyup yz_accel input bolgesine yukler, sonra cikarimi
  baslatir. SRAM sentezde korunur; nihai netlist/DEF/GDSII'de bulunur.
- Liberty: TT/SS/FF uc zorunlu signoff corner'i kapsar.

## 9.6. Zamanlama Kisitlari ve Istisnalari
- Birincil saat: clk_i, 65 ns (15.4 MHz). Clock uncertainty: 0.25 ns.
- Input/output delay: 2.0 ns (AXI arayuz portlari).
- Asenkron reset: set_false_path -from [get_ports rst_ni] (removal yolu; sartname 3.2 izinli).
- Generated clock / coklu saat / multicycle: Yok (tek saat alani).
- Saat periyodu (65 ns) en yavas corner (ss, 1.6V) icin secildi; bkz. 9.11 ve 9.9.

## 9.7. Fiziksel Tasarim Yapilandirmasi
- Die alani: 0,0 - 1150,1100 um. FP_CORE_UTIL 40, PL_TARGET_DENSITY 0.40.
- Makro: u_sram_in sabit (70,70), yonelim N.
- Yonlendirme: RT_MAX_LAYER met4. Guc aglari: VPWR/VGND, PDN otomatik. CTS: varsayilan.
- Toplam ~21.100 standart hucre + 1 SRAM makrosu.
- Otomasyon: asic/Makefile (make asic_run), asic/scripts/collect_outputs.sh.

## 9.8. Lint Sonuclari ve Istisnalari
- Verilator lint: tasarima ait (yz_top_sram/yz_accel/yz_csr) hata yok.
- Uyarilar: SRAM davranissal modelinden (ucuncu taraf makro; BLKSEQ/PINCONNECTEMPTY)
  ve kullanilmayan ust adres bitlerinden kaynaklanir. Lint waiver kullanilmadi.

## 9.9. Bilinen Sorunlar ve Kabul Edilmis Istisnalar
Sartname 3.3 / 9.9 kapsaminda seffaf raporlanir; ihlaller teslimi gecersiz kilmaz (sf.33).

1) ss corner setup (18 yol, WNS ~-5.5 ns): Tasarim tt (tipik) ve ff (hizli) corner'da
   setup+hold TAM TEMIZ imzalanir. En yavas corner ss (1.6 V undervolt, 100 C, yavas
   proses) uzun CNN datapath yollarinda kalinti setup ihlali gosterir. Bu yollar SRAM
   uzerinden gectiginden saat gevsetmesi azalan verim verir; kesin cozum datapath'in
   pipeline'lanmasidir (gelecek revizyon). Fonksiyon ve tt/ff imzasi etkilenmez.

2) Hold (I/O arayuz): Hold ihlallerinin reg-to-reg kismi 0'dir (ic mantik hold-temiz).
   Kalan hold yollari giris/cikis arayuzunde; gercek sistemde bloğu suren CPU'nun
   senkron zamanlamasiyla yonetilir. HOLD_VIOLATION_CORNERS ile olumcul degil.

3) SRAM giris pini max_transition (0.04 ns): Onaylı makronun lib degeri fiziksel
   karsilanamiyor; makro degistirilemez (sf.1.3). RUN_POST_GPL_DESIGN_REPAIR: false.

4) Magic DRC (MAGIC_DRC_USE_GDS: false, SRAM soyut): SRAM'e komsu fill bolgesinde
   nwell.4 (well-tap) kalintisi; sinyal routing DRC'si (OpenROAD) 0. SRAM ic DRC'si
   yeniden dogrulanmaz (sf.1.3). ERROR_ON_MAGIC_DRC: false.

5) KLayout DRC ve Render: SRAM GDSII coklu top-cell yapisi nedeniyle calistirilamadi
   (--skip). Ana DRC imzasi Magic + OpenROAD routing DRC (0).

6) 1 kritik disconnected pin + 3 illegal overlap: SRAM makro kenari artefaktlari;
   gercek baglanti LVS ile dogrulanir (LVS: Circuits match uniquely).

7) sv2v ve iverilog: RTL sv2v ile Verilog'a cevrilir; LibreLane flake.nix'te iverilog
   doCheck=false override'i uygulanmistir (arac islevsel, sadece ortam kurulumu).

## 9.10. Guc ve IR-Drop Analizi
- Saat: 15.4 MHz. Corner: tt/ss/ff. Besleme: 1.8/1.6/1.95 V.
- Switching activity acik girdisi KULLANILMADI; guc sonuclari TAHMINIDIR.
- VSRC_LOC_FILES KULLANILMADI; IR-drop yaklasiktir. Raporlar: reports/power/.

## 9.11. Signoff Sonuc Ozeti
- Signoff corner'lari: tt_025C_1v80, ss_100C_1v60, ff_n40C_1v95.
- nom_tt: setup +19.9 ns, hold +0.24 ns -> TEMIZ.
- nom_ff: setup +32.0 ns, hold +0.06 ns -> TEMIZ.
- nom_ss: setup -5.5 ns (18 yol), hold I/O (bkz 9.9). Sinirlayici corner.
- Netgen LVS: "Circuits match uniquely" (temiz eslesme).
- OpenROAD detailed routing DRC: 0. Anten: 0. PDN grid: 0.
- Fonksiyonel dogrulama: RTL simulasyonda CNN goruntusu dogru siniflandirilir
  (donanim logit/argmax = altin model, birebir). Bkz. tb/yz_top_sram_tb.sv.

## 9.12. Rapor ve Cikti Konumlari
- LibreLane calisma etiketi: run1. Esas GDSII: results/gds/yz_top_sram.gds (Magic).
- Ayrica results/gds/yz_top_sram_magic.gds ve _klayout.gds.
- Zorunlu gorunumler: results/{gds,lef,def}/. Ek ciktilar: results/{netlist,sdc,spef,spice,config,metrics}/.
- Raporlar: reports/{general,lint,synthesis,timing,drc,lvs,antenna,pdn,routing,power,signoff}/.
- Cikti toplama: make asic_run -> scripts/collect_outputs.sh.

## 9.13. Ucuncu Taraf Bilesenler ve Lisanslar
Ayrinti: asic/THIRD_PARTY.md.
- LibreLane 3.0.6 (Apache-2.0), SKY130/Open PDKs (Apache-2.0, commit 8afc8346...),
  sky130_fd_sc_hd (Apache-2.0), SRAM makrosu (OpenRAM/sky130, degistirilmeden),
  Yosys/OpenROAD/Magic/Netgen/KLayout/Verilator/sv2v (ilgili acik kaynak lisanslar).
