create_clock -name clk_i -period 65.0 [get_ports clk_i]
set_clock_uncertainty 0.25 [get_clocks clk_i]
set_input_delay  2.0 -clock clk_i [get_ports {axi_awvalid_i axi_wvalid_i axi_bready_i axi_arvalid_i axi_rready_i}]
set_input_delay  2.0 -clock clk_i [get_ports {axi_awaddr_i[*]}]
set_input_delay  2.0 -clock clk_i [get_ports {axi_awprot_i[*]}]
set_input_delay  2.0 -clock clk_i [get_ports {axi_wdata_i[*]}]
set_input_delay  2.0 -clock clk_i [get_ports {axi_wstrb_i[*]}]
set_input_delay  2.0 -clock clk_i [get_ports {axi_araddr_i[*]}]
set_input_delay  2.0 -clock clk_i [get_ports {axi_arprot_i[*]}]
set_output_delay 2.0 -clock clk_i [all_outputs]

# Asenkron reset istisnasi (sartname 3.2 izinli)
set_false_path -from [get_ports rst_ni]
