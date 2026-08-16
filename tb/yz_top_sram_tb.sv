// ============================================================================
// yz_top_sram_tb.sv -- YZ Hizlandirici SoC-entegrasyon testi (CPU AXI yolu)
//
// yz_top_sram'u bir AXI4-Lite MASTER gibi surer (CPU'nun yapacagini taklit eder):
//   1) giris+agirlik+bias'i veri pencerelerine AXI ile yazar
//   2) CSR.CTRL[0]=START ile cikarimi baslatir
//   3) STATUS.DONE'u yoklar (polling)
//   4) logit'leri 0x5000_6000'den okur ve altin model ile karsilastirir
//
// Kosum (small konfig):
//   python3 sw/yz/gen_golden.py small
//   iverilog -g2012 -I sw/yz -s yz_top_sram_tb -o /tmp/t.vvp \
//            rtl/yz_csr.sv rtl/yz_accel.sv rtl/yz_top_sram.sv tb/yz_top_sram_tb.sv && vvp /tmp/t.vvp
// ============================================================================
`timescale 1ns/1ps
`include "yz_params.svh"

module yz_top_sram_tb;
    localparam int FC_OUT = `YZ_FC_OUT;
    localparam [31:0] BASE = 32'h5000_0000;

    logic clk=0, rst_ni=0;
    always #5 clk = ~clk;

    // AXI master sinyalleri
    logic        awvalid, awready; logic [31:0] awaddr; logic [2:0] awprot;
    logic        wvalid,  wready;  logic [31:0] wdata;  logic [3:0] wstrb;
    logic        bvalid,  bready;  logic [1:0]  bresp;
    logic        arvalid, arready; logic [31:0] araddr; logic [2:0] arprot;
    logic        rvalid,  rready;  logic [31:0] rdata;  logic [1:0] rresp;
    logic        irq;

    yz_top_sram #(
        .IN_H(`YZ_IN_H), .IN_W(`YZ_IN_W), .K_H(`YZ_K_H), .K_W(`YZ_K_W),
        .STRIDE(`YZ_STRIDE), .N_FILT(`YZ_N_FILT), .OUT_H(`YZ_OUT_H),
        .OUT_W(`YZ_OUT_W), .FEAT(`YZ_FEAT), .FC_OUT(`YZ_FC_OUT),
        .SHIFT(`YZ_SHIFT), .PAD_H(`YZ_PAD_H), .PAD_W(`YZ_PAD_W)
    ) dut (
        .clk_i(clk), .rst_ni(rst_ni),
        .axi_awvalid_i(awvalid), .axi_awready_o(awready), .axi_awaddr_i(awaddr), .axi_awprot_i(awprot),
        .axi_wvalid_i(wvalid), .axi_wready_o(wready), .axi_wdata_i(wdata), .axi_wstrb_i(wstrb),
        .axi_bvalid_o(bvalid), .axi_bready_i(bready), .axi_bresp_o(bresp),
        .axi_arvalid_i(arvalid), .axi_arready_o(arready), .axi_araddr_i(araddr), .axi_arprot_i(arprot),
        .axi_rvalid_o(rvalid), .axi_rready_i(rready), .axi_rdata_o(rdata), .axi_rresp_o(rresp),
        .irq_o(irq)
    );

    // Yaris-guvenli AXI4-Lite master (nonblocking surus + kenarda ornekleme)
    task automatic axi_write(input [31:0] addr, input [31:0] data);
        logic hs;
        @(posedge clk);
        awvalid<=1; awaddr<=addr; awprot<=0; wvalid<=1; wdata<=data; wstrb<=4'hF;
        hs=0; while(!hs) begin @(posedge clk); if (awready && wready) hs=1; end
        awvalid<=0; wvalid<=0; bready<=1;
        hs=0; while(!hs) begin @(posedge clk); if (bvalid) hs=1; end
        bready<=0;
    endtask

    task automatic axi_read(input [31:0] addr, output [31:0] data);
        logic hs;
        @(posedge clk);
        arvalid<=1; araddr<=addr; arprot<=0;
        hs=0; while(!hs) begin @(posedge clk); if (arready) hs=1; end
        arvalid<=0; rready<=1;
        hs=0; while(!hs) begin @(posedge clk); if (rvalid) begin data=rdata; hs=1; end end
        rready<=0;
    endtask

    // Altin model verileri
    logic [7:0]  inp   [0:`YZ_IN_H*`YZ_IN_W-1];
    logic [7:0]  wconv [0:`YZ_N_FILT*`YZ_K_H*`YZ_K_W-1];
    logic [31:0] bconv [0:`YZ_N_FILT-1];
    logic [7:0]  wfc   [0:`YZ_FC_OUT*`YZ_FEAT-1];
    logic [31:0] bfc   [0:`YZ_FC_OUT-1];
    logic signed [31:0] exp [0:FC_OUT];   // FC_OUT logit + argmax

    integer i, errors, tout;
    logic [31:0] rd;

    initial begin
        $readmemh("sw/yz/yz_input.hex",    inp);
        $readmemh("sw/yz/yz_wconv.hex",    wconv);
        $readmemh("sw/yz/yz_bconv.hex",    bconv);
        $readmemh("sw/yz/yz_wfc.hex",      wfc);
        $readmemh("sw/yz/yz_bfc.hex",      bfc);
        $readmemh("sw/yz/yz_expected.hex", exp);
        errors=0;
        awvalid=0; wvalid=0; bready=0; arvalid=0; rready=0; awaddr=0; wdata=0; wstrb=0; araddr=0;
        repeat (4) @(posedge clk); rst_ni=1; repeat (2) @(posedge clk);

        $display("=========================================================");
        $display(" ZUGA-IC YZ SoC-Entegrasyon Testi (CPU AXI yolu)");
        $display(" yz_top_sram = yz_csr(0x5000_0000) + yz_accel + veri pencereleri");
        $display("=========================================================");

        // 1) Bellekleri AXI ile yukle (CPU'nun yapacagi) - bolge araligi 1 MB
        $display("[TB] Giris+agirlik+bias AXI uzerinden yukleniyor...");
        for (i=0;i<`YZ_IN_H*`YZ_IN_W;i=i+1)          axi_write(BASE+32'h0010_0000+i*4, {24'h0, inp[i]});
        for (i=0;i<`YZ_N_FILT*`YZ_K_H*`YZ_K_W;i=i+1) axi_write(BASE+32'h0020_0000+i*4, {24'h0, wconv[i]});
        for (i=0;i<`YZ_N_FILT;i=i+1)                 axi_write(BASE+32'h0030_0000+i*4, bconv[i]);
        for (i=0;i<`YZ_FC_OUT*`YZ_FEAT;i=i+1)        axi_write(BASE+32'h0040_0000+i*4, {24'h0, wfc[i]});
        for (i=0;i<`YZ_FC_OUT;i=i+1)                 axi_write(BASE+32'h0050_0000+i*4, bfc[i]);

        // 2) START (CSR CTRL[0]=1)
        $display("[TB] CSR CTRL[0]=START yaziliyor...");
        axi_write(BASE+32'h0000, 32'h1);

        // 3) STATUS.DONE (bit1) yokla
        tout=0; rd=0;
        while (!rd[1] && tout<200000) begin axi_read(BASE+32'h0004, rd); tout=tout+1; end
        if (!rd[1]) begin
            $display("[TB] HATA: DONE gelmedi (timeout). STATUS=0x%08h", rd);
            $display("===== YZ SOC ENTEGRASYON TESTI FAILED ====="); $finish;
        end
        $display("[TB] STATUS.DONE=1 (0x%08h), irq gozlendi=%0b", rd, irq);

        // 4) Logit'leri oku ve karsilastir
        for (i=0;i<FC_OUT;i=i+1) begin
            axi_read(BASE+32'h0060_0000+i*4, rd);
            if (rd !== exp[i]) begin
                $display("[TB] FAIL logit%0d: HW=%0d golden=%0d", i, $signed(rd), exp[i]);
                errors=errors+1;
            end else
                $display("[TB] PASS logit%0d = %0d", i, $signed(rd));
        end

        $display("---------------------------------------------------------");
        if (errors==0)
            $display("===== YZ SOC ENTEGRASYON TESTI PASSED ===== (CPU AXI yolu, HW==golden)");
        else
            $display("===== YZ SOC ENTEGRASYON TESTI FAILED ===== (%0d hata)", errors);
        $display("=========================================================");
        $finish;
    end

    initial begin #5_000_000; $display("[TB] WATCHDOG"); $finish; end
endmodule
