
# ZUGA-IC

**TEKNOFEST 2026 Çip Tasarımı Yarışması — Mikrodenetleyici Tasarım Kategorisi**

CV32E40P (RV32IMC) RISC-V çekirdeği üzerine kurulu, AXI4-Lite veri yolu tabanlı
bir System-on-Chip. Bellek, çevre birimleri ve bir yapay zekâ hızlandırıcısı
tek bir mimaride birleştirildi; tasarım RTL'den doğrulamaya, FPGA prototipinden
SKY130 üzerinde fiziksel çip çizimine (GDSII) kadar götürüldü.

## Takım

| Rol | İsim |
|-----|------|
| Takım | ZUGA-IC (ID: 989786, Başvuru: 5215977) |
| Kaptan | Umur Buğra Dikmen |
| Üye | Betül Bedir |
| Danışman | Dr. Fatih Gül |
| Üniversite | Recep Tayyip Erdoğan Üniversitesi — Elektrik-Elektronik Mühendisliği |

## Öne çıkanlar

- CV32E40P (RV32IMC) çekirdek, kendi yazdığımız OBI→AXI4-Lite köprüsü üzerinden
  tüm alt sisteme bağlı.
- Çevre birimleri: GPIO, Timer, iki UART (TX+RX), I2C Master; hepsi AXI4-Lite
  slave ve şartname EK-2 yazmaç haritasına uyumlu.
- Yapay zekâ hızlandırıcısı: TFLite Micro Speech "Tiny Conv" modelinin donanım
  gerçeklemesi; çıkışı Python altın modeliyle bit-bit doğrulandı.
- Doğrulama: 10/10 modül regresyon (0 hata), 5 SVA ile AXI protokol denetimi,
  DDK resmî demo testbench'inde TEST SUCCESS.
- FPGA: Digilent Nexys Video (Artix-7 XC7A200T) üzerinde 50 MHz, sıfır zamanlama
  ihlali.
- ASIC: YZ hızlandırıcı, gerçek bir SKY130 SRAM makrosuyla birlikte LibreLane
  akışında RTL→GDSII; Netgen LVS eşleşti.

## Sistem mimarisi

Mimari, tek bir AXI4-Lite veri yolu ve merkezî bir adres çözücü etrafında
kurulu. CV32E40P komut (IF) ve veri (LSU) için iki OBI portu üretir; bu portlar
`obi_to_axi_lite` köprüsü (altı durumlu FSM) ile tek bir AXI4-Lite master'a
dönüştürülür. Adres çözücü her erişimi ilgili belleğe veya çevre birimine
yönlendirir. Tüm tasarım tek saat alanında çalışır; bu, saat geçişi (CDC)
risklerini ortadan kaldırarak doğrulanabilirliği artırır.

### Adres haritası

| Blok | Başlangıç | Bitiş | Boyut | Erişim |
|------|-----------|-------|-------|--------|
| Boot ROM | 0x0000_0000 | 0x0000_01FF | 512 B | Komut (R) |
| IRAM | 0x0001_0000 | 0x0001_1FFF | 8 KB | Komut (R/W) |
| DRAM | 0x0002_0000 | 0x0002_1FFF | 8 KB | Veri (R/W) |
| GPIO | 0x4000_0000 | 0x4000_0007 | 8 B | AXI4-Lite |
| Timer | 0x4000_1000 | 0x4000_101F | 32 B | AXI4-Lite |
| UART-0 | 0x4000_2000 | 0x4000_2013 | 20 B | AXI4-Lite |
| UART-1 | 0x4000_3000 | 0x4000_3013 | 20 B | AXI4-Lite |
| I2C Master | 0x4000_4000 | 0x4000_4013 | 20 B | AXI4-Lite |
| YZ CSR | 0x5000_0000 | 0x5000_001F | 32 B | AXI4-Lite |

## Çevre birimleri

| Blok | Açıklama |
|------|----------|
| GPIO | 16-bit yazılım çıkışı + 16-bit donanım girişi, read-after-write korumalı |
| Timer | 8 adet 32-bit yazmaç; prescaler, auto-reload, kesme üretimi |
| UART-0 / UART-1 | 8N1 çerçeve, programlanabilir baud, bit-ortası örnekleme, metastabilite korumalı RX; TX ve RX ayrı FSM |
| I2C Master | 7-bit adresleme, 100 kHz standart mod, START/STOP/ACK/NACK |

Yazmaç haritaları şartname EK-2 ile birebir uyumludur; her blok için C sürücü
başlık dosyaları `sw/include` altında sağlanır.

## Yapay zekâ hızlandırıcı

Hızlandırıcı, TFLite Micro Speech "Tiny Conv" (anahtar-kelime tanıma) modelini
donanımda gerçekler:

`DepthwiseConv2D + ReLU` (8 filtre, 10×8 çekirdek, stride 2) → `FullyConnected`
(4000 → 4) → argmax. Reshape ve Softmax yazılım (CPU) tarafında kalır.

DepthwiseConv2D ve FullyConnected katmanları sıralı çalıştığından **tek bir
paylaşımlı MAC** birimi kullanılmıştır; bu, ASIC'te alanı küçük tutan bilinçli
bir karardır. Doğrulama, bağımsız bir Python altın modeline karşı self-checking
testbench (`tb_yz_accel`) ile yapılır; donanım ve altın model aynı sabit-nokta
parametrelerini kullandığından sonuçlar bit düzeyinde özdeştir.

Ölçülen sonuç: logit vektörü `[-55348, 78093, -91114, -59150]`, argmax = sınıf 1.
Donanım çıkarım süresi 336.001 çevrim; muhafazakâr bir yazılım maliyet modeline
göre (~1.810.560 çevrim) yaklaşık **5,4× hızlanma**; 50 MHz'de çıkarım gecikmesi
≈ 6,72 ms.

## Doğrulama ve test

Doğrulama üç katmanda yürütülür: tekil IP testleri, sistem entegrasyonu ve SVA
protokol denetimi. Tüm testbench'ler self-checking'tir.

| Metrik | Sonuç |
|--------|-------|
| Regresyon | 10/10 modül PASS, 62 transaction, 113 AXI el sıkışması, 0 hata |
| SVA protokol denetimi | 5 assertion (AW/W/B/AR/R kararlılık), 0 ihlal |
| Kapsama | satır %74,5 (310/416), dal %66,8 (286/428) |
| DDK demo testbench | TEST SUCCESS (Vivado 2021.2) |
| YZ hızlandırıcı | altın modelle bit-bit eşleşme, PASS |

Elemeye esas resmî DDK demo testbench'i, çekirdek ve UART entegrasyonunu doğrular:
çekirdek üzerinde koşan C programı UART'tan "R" gönderir, "A" alır ve
"Hello World!" dizisini iletir; testbench TEST SUCCESS üretir.

## FPGA prototipleme

Tasarım Digilent **Nexys Video** (Xilinx Artix-7 **XC7A200T**) üzerinde
sentezlenmiş, yerleştirilmiş, yönlendirilmiş ve bitstream olarak yüklenmiştir.

| Parametre | Değer |
|-----------|-------|
| Sistem saati | 50 MHz (20 ns) |
| WNS / WHS | +2,432 ns / +0,071 ns |
| Zamanlama ihlali | 0 (6376 endpoint) |
| Kaynak | ~%4 LUT, ~%1 FF |

Kartta DONE LED yanar, GPIO LED'leri çekirdek tarafından sürülür ve OLED ekrana
çekirdek üzerinden dizi yazdırılır — işlemci ve çevre birimlerinin gerçek
donanımda birlikte çalıştığının kanıtı.

## ASIC fiziksel tasarım

Yapay zekâ hızlandırıcı alt sistemi (`yz_top_sram` = `yz_accel` + `yz_csr` +
SKY130 SRAM makrosu + yükleyici FSM), LibreLane Classic akışıyla RTL'den
GDSII'ye götürülmüştür.

| Öğe | Değer |
|-----|-------|
| Akış | LibreLane 3.0.6 (Nix, Classic) |
| PDK | SKY130 / sky130A, `sky130_fd_sc_hd` |
| SRAM makrosu | `sky130_sram_1kbyte_1rw1r_32x256_8` (1 KiB, 256×32, 1RW+1R) |
| Saat | 65 ns (~15,4 MHz) |
| Signoff köşeleri | tt_025C_1v80, ff_n40C_1v95, ss_100C_1v60 |
| LVS | Netgen — circuits match |
| Zamanlama | tt ve ff köşeleri temiz; ss sınırlayıcı köşe (belgelendi) |
| Çıktı | GDSII / LEF / DEF üretildi |

Ayrıntılı akış, yeniden çalıştırma komutları, raporlar ve bilinen istisnalar
`asic/README.md` içinde açıklanmıştır.

## Depo yapısı

```
rtl/          Sentezlenebilir RTL (çekirdek entegrasyonu, çevre birimleri, YZ)
tb/           Self-checking testbench'ler ve regresyon betiği
sw/           Boot yazılımı (crt0, helloworld), linker script, C header'lar
fpga/         Nexys Video üst modülü ve XDC kısıtları
asic/         LibreLane RTL->GDSII akışı (config, constraints, macros, sonuçlar)
dtr_demo/     DDK demo testbench entegrasyonu (Vivado)
docs/         DTR, mühendislik notları, milestone raporları, ekran görüntüleri
cv32e40p/     CV32E40P çekirdek kaynakları (üçüncü taraf)
```

## Kurulum ve çalıştırma

Bağımlılıklar: Verilator 5.020+, RISC-V GCC (rv32imc), Icarus Verilog, Python 3,
make, git. FPGA için Vivado 2021.2; ASIC için Nix + LibreLane 3.0.6.

Regresyon (tüm bloklar, self-checking):

```
./run_regression.sh
```

FPGA: `fpga/` altındaki akışla Nexys Video (XC7A200T) hedeflenerek bitstream
üretilir.

ASIC (ayrıntı `asic/README.md`):

```
cd asic
make asic_run
```

## Tasarım kararları

- **AXI4-Lite:** OBI ile başlanıp AXI4-Lite'a geçildi — endüstri standardı,
  EDA/IP uyumu ve SVA ile protokol doğrulanabilirliği için.
- **Tek adres çözücü:** Tek master ve tekil transfer ihtiyacı için crossbar
  yerine merkezî adres çözücü; daha küçük alan, daha kolay doğrulama.
- **Paylaşımlı MAC:** YZ katmanları sıralı çalıştığından tek MAC — alan tasarrufu.
- **Softmax yazılımda:** Argmax için gereksiz ve pahalı olduğundan CPU'ya bırakıldı.
- **BRAM çıkarımı:** `ram_axi` içinde `ram_style="block"` ve reset'in bellekten
  ayrılması ile sentez süresi belirgin biçimde kısaldı.

## Bilinen sınırlamalar ve yol haritası

- ASIC ss köşesinde artık setup payı mevcut (kaynak: pipelinesız MAC yolu);
  çözüm datapath pipeline derinleştirme.
- Kapsama ilk faz seviyesinde; hedef satır ≥%95 / dal ≥%90 (yönlendirilmiş +
  kısıtlı-rastgele + UVM).
- İkinci faza planlı: QSPI Master ve Flash boot, JTAG debug, UVM doğrulama ortamı.

Alınan kararlar ve karşılaşılan sorunların ayrıntısı için: `docs/NOTES.md`.

## Kaynaklar

- CV32E40P — OpenHW Group: https://github.com/openhwgroup/cv32e40p
- AMBA AXI4-Lite — ARM IHI 0022
- RISC-V ISA: https://riscv.org
- TFLite Micro (Tiny Conv): https://github.com/tensorflow/tflite-micro
- SkyWater SKY130 PDK / Open PDKs, LibreLane, OpenROAD, Yosys, Magic, KLayout, Netgen
- Verilator: https://www.veripool.org/verilator/
- Digilent Nexys Video referansları

## Lisans ve üçüncü taraf bileşenler

Üçüncü taraf RTL, IP, SRAM makrosu ve araç bilgileri (kaynak, sürüm, lisans)
`asic/THIRD_PARTY.md` içinde listelenmiştir. Kopyalanan bileşenlerin lisans ve
telif bildirimleri korunmuştur.
