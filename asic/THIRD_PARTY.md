# Ucuncu Taraf Bilesenler ve Lisanslar - ram_axi ASIC teslimi

| Bilesen | Kaynak | Surum / Commit | Lisans | Degisiklik |
|---|---|---|---|---|
| LibreLane | github.com/librelane/librelane | 3.0.6 (ba7193b) | Apache-2.0 | flake.nix icinde iverilog doCheck=false override |
| Open PDKs / SKY130 | github.com/fossi-foundation/open-pdks | 8afc8346a57fe1ab7934ba5a6056ea8b43078e71 | Apache-2.0 | Degistirilmedi |
| sky130_fd_sc_hd | SKY130 PDK icinde | PDK ile birlikte | Apache-2.0 | Degistirilmedi |
| SRAM makrosu sky130_sram_1kbyte_1rw1r_32x256_8 | SKY130 PDK sky130_sram_macros | PDK ile birlikte (OpenRAM uretimi) | Apache-2.0 | Degistirilmedi (onceden onayli hazir makro) |
| Yosys | LibreLane nix-eda 6.11.0 | 0.62 | ISC | Degistirilmedi |
| OpenROAD | LibreLane nix-eda 6.11.0 | dcf36133 | BSD-3-Clause | Degistirilmedi |
| Magic | LibreLane nix-eda 6.11.0 | 8.3.623 | MIT-benzeri | Degistirilmedi |
| Netgen | LibreLane nix-eda 6.11.0 | nix-eda ile | GPL-2.0 | Degistirilmedi |
| KLayout | LibreLane nix-eda 6.11.0 | 0.30.7 | GPL-3.0 | Degistirilmedi |
| Verilator | LibreLane nix-eda 6.11.0 | nix-eda ile | LGPL-3.0/Artistic-2.0 | Degistirilmedi |

Tasarima ait RTL (rtl/ram_axi.sv) takim tarafindan yazilmistir. SRAM makrosunun
GDSII/LEF/Verilog/Liberty/SPICE gorunumleri degistirilmeden kullanilmistir.
