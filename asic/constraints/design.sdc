# ============================================================
# ram_axi zamanlama kisitlari
# Birincil saat: clk_i, 20 ns periyot (50 MHz)
# ============================================================
create_clock -name clk_i -period 20.0 [get_ports clk_i]
set_clock_uncertainty 0.25 [get_clocks clk_i]

# Giris gecikmeleri (saat portu haric tum girisler)
set_input_delay  2.0 -clock clk_i [get_ports rst_ni]
set_input_delay  2.0 -clock clk_i [get_ports axi_awvalid_i]
set_input_delay  2.0 -clock clk_i [get_ports {axi_awaddr_i[*]}]
set_input_delay  2.0 -clock clk_i [get_ports {axi_awprot_i[*]}]
set_input_delay  2.0 -clock clk_i [get_ports axi_wvalid_i]
set_input_delay  2.0 -clock clk_i [get_ports {axi_wdata_i[*]}]
set_input_delay  2.0 -clock clk_i [get_ports {axi_wstrb_i[*]}]
set_input_delay  2.0 -clock clk_i [get_ports axi_bready_i]
set_input_delay  2.0 -clock clk_i [get_ports axi_arvalid_i]
set_input_delay  2.0 -clock clk_i [get_ports {axi_araddr_i[*]}]
set_input_delay  2.0 -clock clk_i [get_ports {axi_arprot_i[*]}]
set_input_delay  2.0 -clock clk_i [get_ports axi_rready_i]

# Cikis gecikmeleri (tum cikislar)
set_output_delay 2.0 -clock clk_i [all_outputs]
