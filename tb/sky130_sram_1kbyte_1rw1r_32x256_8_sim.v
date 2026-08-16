// Simulasyon-only davranissal SRAM modeli (PDK makrosuyla ayni arayuz).
// ASIC akisinda kullanilmaz; orada onaylanmis GDS/LEF makro kullanilir.
module sky130_sram_1kbyte_1rw1r_32x256_8 (
`ifdef USE_POWER_PINS
  inout vccd1, inout vssd1,
`endif
  input  clk0, input csb0, input web0, input [3:0] wmask0,
  input  [7:0] addr0, input [31:0] din0, output reg [31:0] dout0,
  input  clk1, input csb1, input [7:0] addr1, output reg [31:0] dout1
);
  reg [31:0] mem [0:255];
  always @(posedge clk0) begin
    if (!csb0) begin
      if (!web0) begin
        if (wmask0[0]) mem[addr0][7:0]   <= din0[7:0];
        if (wmask0[1]) mem[addr0][15:8]  <= din0[15:8];
        if (wmask0[2]) mem[addr0][23:16] <= din0[23:16];
        if (wmask0[3]) mem[addr0][31:24] <= din0[31:24];
      end
      dout0 <= mem[addr0];
    end
  end
  always @(posedge clk1) if (!csb1) dout1 <= mem[addr1];
endmodule
