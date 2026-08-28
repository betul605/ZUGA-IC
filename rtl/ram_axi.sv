// ============================================================================
// ram_axi.sv  -- AXI4-Lite Slave RAM  (SKY130 SRAM makro tabanli)
//
// Bellek: sky130_sram_1kbyte_1rw1r_32x256_8  (256 word x 32-bit, 1RW+1R)
//   - Port A (1RW): AXI okuma + yazma icin kullanilir
//   - Port B (1R) : bu tasarimda kullanilmaz, girisleri guvenli sabitlenir
//
// SRAM senkron okuma yapar (adres -> +1 cevrim veri). State machine buna
// gore S_READ_WAIT durumu ile guncellenmistir.
//
// wmask0[i] = 1 -> ilgili byte yazilir  (AXI wstrb ile birebir)
// csb0 = 0 aktif (chip select),  web0 = 0 yazma / 1 okuma (aktif dusuk)
// ============================================================================
module ram_axi #(
    parameter SIZE_WORDS = 256,    // uyumluluk icin (SRAM sabit 256 word)
    parameter MEM_FILE = "",     // kullanilmiyor (SRAM init yok)
    parameter WRITE_ENABLE = 1'b1
) (
`ifdef USE_POWER_PINS
    inout VPWR,
    inout VGND,
`endif
    input  logic        clk_i,
    input  logic        rst_ni,
    // Write Address Channel
    input  logic        axi_awvalid_i,
    output logic        axi_awready_o,
    input  logic [31:0] axi_awaddr_i,
    /* verilator lint_off UNUSEDSIGNAL */
    input  logic [2:0]  axi_awprot_i,
    /* verilator lint_on UNUSEDSIGNAL */
    // Write Data Channel
    input  logic        axi_wvalid_i,
    output logic        axi_wready_o,
    input  logic [31:0] axi_wdata_i,
    input  logic [3:0]  axi_wstrb_i,
    // Write Response Channel
    output logic        axi_bvalid_o,
    input  logic        axi_bready_i,
    output logic [1:0]  axi_bresp_o,
    // Read Address Channel
    input  logic        axi_arvalid_i,
    output logic        axi_arready_o,
    input  logic [31:0] axi_araddr_i,
    /* verilator lint_off UNUSEDSIGNAL */
    input  logic [2:0]  axi_arprot_i,
    /* verilator lint_on UNUSEDSIGNAL */
    // Read Data Channel
    output logic        axi_rvalid_o,
    input  logic        axi_rready_i,
    output logic [31:0] axi_rdata_o,
    output logic [1:0]  axi_rresp_o
);
    localparam ADDR_WIDTH = 8;   // 256 word
    // MEM_FILE su an kullanilmiyor (SRAM makrosu init desteklemez)
    /* verilator lint_off UNUSEDPARAM */
    // (MEM_FILE parametresi ust modul uyumlulugu icin korunur)
    /* verilator lint_on UNUSEDPARAM */

    logic [ADDR_WIDTH-1:0] write_word_addr;
    logic [ADDR_WIDTH-1:0] read_word_addr;
    assign write_word_addr = axi_awaddr_i[ADDR_WIDTH+1:2];
    assign read_word_addr  = axi_araddr_i[ADDR_WIDTH+1:2];

    // ------------------------------------------------------------------------
    // State Machine
    // ------------------------------------------------------------------------
    typedef enum logic [1:0] {
        S_IDLE       = 2'd0,
        S_READ_WAIT  = 2'd1,   // SRAM okuma latency (1 cevrim)
        S_WRITE_RESP = 2'd2,
        S_READ_RESP  = 2'd3
    } state_e;
    state_e state_q;

    assign axi_bresp_o = 2'b00;
    assign axi_rresp_o = 2'b00;

    // ------------------------------------------------------------------------
    // SRAM Port A surucu sinyalleri (kombinasyonel)
    // ------------------------------------------------------------------------
    logic                  sram_csb0;   // aktif dusuk chip select
    logic                  sram_web0;   // aktif dusuk write enable
    logic [3:0]            sram_wmask0;
    logic [ADDR_WIDTH-1:0] sram_addr0;
    logic [31:0]           sram_din0;
    logic [31:0]           sram_dout0;

    logic do_write, do_read;
    assign do_write = WRITE_ENABLE && (state_q == S_IDLE) &&
                      axi_awvalid_i && axi_wvalid_i;
    assign do_read  = (state_q == S_IDLE) && axi_arvalid_i && !do_write;

    always_comb begin
        // varsayilan: SRAM secili degil
        sram_csb0   = 1'b1;
        sram_web0   = 1'b1;
        sram_wmask0 = 4'b0000;
        sram_addr0  = '0;
        sram_din0   = axi_wdata_i;
        if (do_write) begin
            sram_csb0   = 1'b0;
            sram_web0   = 1'b0;          // yazma
            sram_wmask0 = axi_wstrb_i;
            sram_addr0  = write_word_addr;
        end else if (do_read) begin
            sram_csb0   = 1'b0;
            sram_web0   = 1'b1;          // okuma
            sram_addr0  = read_word_addr;
        end
    end

    // ------------------------------------------------------------------------
    // AXI hazir / valid sinyalleri
    // ------------------------------------------------------------------------
    assign axi_awready_o = do_write;
    assign axi_wready_o  = do_write;
    assign axi_arready_o = do_read;
    assign axi_bvalid_o  = (state_q == S_WRITE_RESP);
    assign axi_rvalid_o  = (state_q == S_READ_RESP);
    assign axi_rdata_o   = sram_dout0;   // SRAM dout registered

    // ------------------------------------------------------------------------
    // State gecisleri
    // ------------------------------------------------------------------------
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            state_q <= S_IDLE;
        end else begin
            case (state_q)
                S_IDLE: begin
                    if (do_write)      state_q <= S_WRITE_RESP;
                    else if (do_read)  state_q <= S_READ_WAIT;
                end
                S_READ_WAIT:  state_q <= S_READ_RESP;   // SRAM dout hazir
                S_WRITE_RESP: if (axi_bready_i) state_q <= S_IDLE;
                S_READ_RESP:  if (axi_rready_i) state_q <= S_IDLE;
                default:      state_q <= S_IDLE;
            endcase
        end
    end

    // ------------------------------------------------------------------------
    // SRAM makro instance  (Port A = 1RW aktif, Port B = 1R sabitlenmis)
    // ------------------------------------------------------------------------
    sky130_sram_1kbyte_1rw1r_32x256_8 u_sram (
`ifdef USE_POWER_PINS
        .vccd1 (VPWR),
        .vssd1 (VGND),
`endif
        // Port A (1RW)
        .clk0   (clk_i),
        .csb0   (sram_csb0),
        .web0   (sram_web0),
        .wmask0 (sram_wmask0),
        .addr0  (sram_addr0),
        .din0   (sram_din0),
        .dout0  (sram_dout0),
        // Port B (1R) - kullanilmiyor
        .clk1   (clk_i),
        .csb1   (1'b1),        // devre disi
        .addr1  (8'b0),
        .dout1  ()             // bagli degil
    );

`ifndef SYNTHESIS
    // Simulasyon-only: MEM_FILE verilmisse (ROM modu) icerigi yukle.
    // ASIC sentezinde SYNTHESIS tanimli -> bu blok yok sayilir.
    initial if (MEM_FILE != "") $readmemh(MEM_FILE, u_sram.mem);
`endif
endmodule
