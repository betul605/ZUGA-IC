bind qspi_master_axi axi_lite_protocol_checker u_axi_check (
    .clk_i(clk_i), .rst_ni(rst_ni),
    .axi_awvalid_i(axi_awvalid_i), .axi_awready_o(axi_awready_o),
    .axi_wvalid_i(axi_wvalid_i), .axi_wready_o(axi_wready_o),
    .axi_bvalid_o(axi_bvalid_o), .axi_bready_i(axi_bready_i), .axi_bresp_o(axi_bresp_o),
    .axi_arvalid_i(axi_arvalid_i), .axi_arready_o(axi_arready_o),
    .axi_rvalid_o(axi_rvalid_o), .axi_rready_i(axi_rready_i),
    .axi_rdata_o(axi_rdata_o), .axi_rresp_o(axi_rresp_o)
);
module qspi_master_axi_tb;
    logic clk, rst_n;
    logic        axi_awvalid, axi_awready;
    logic [31:0] axi_awaddr;
    logic [2:0]  axi_awprot;
    logic        axi_wvalid, axi_wready;
    logic [31:0] axi_wdata;
    logic [3:0]  axi_wstrb;
    logic        axi_bvalid, axi_bready;
    logic [1:0]  axi_bresp;
    logic        axi_arvalid, axi_arready;
    logic [31:0] axi_araddr;
    logic [2:0]  axi_arprot;
    logic        axi_rvalid, axi_rready;
    logic [31:0] axi_rdata;
    logic [1:0]  axi_rresp;
    logic spi_sclk, spi_cs_n, spi_mosi, spi_miso;
    assign spi_miso = spi_mosi;
    int errors = 0;
    logic busy_seen = 0;
    localparam logic [31:0] CTRL=32'h00, STATUS=32'h04, TDR=32'h08, RDR=32'h0C, CFG=32'h10;
    qspi_master_axi dut (
        .clk_i(clk), .rst_ni(rst_n),
        .axi_awvalid_i(axi_awvalid), .axi_awready_o(axi_awready),
        .axi_awaddr_i(axi_awaddr), .axi_awprot_i(axi_awprot),
        .axi_wvalid_i(axi_wvalid), .axi_wready_o(axi_wready),
        .axi_wdata_i(axi_wdata), .axi_wstrb_i(axi_wstrb),
        .axi_bvalid_o(axi_bvalid), .axi_bready_i(axi_bready), .axi_bresp_o(axi_bresp),
        .axi_arvalid_i(axi_arvalid), .axi_arready_o(axi_arready),
        .axi_araddr_i(axi_araddr), .axi_arprot_i(axi_arprot),
        .axi_rvalid_o(axi_rvalid), .axi_rready_i(axi_rready),
        .axi_rdata_o(axi_rdata), .axi_rresp_o(axi_rresp),
        .spi_sclk_o(spi_sclk), .spi_cs_no(spi_cs_n),
        .spi_mosi_o(spi_mosi), .spi_miso_i(spi_miso)
    );
    initial clk = 0;
    always #5 clk = ~clk;
    always @(posedge clk) if (spi_cs_n==1'b0) busy_seen <= 1'b1;
    task automatic axi_write(input [31:0] addr, input [31:0] data);
        @(posedge clk);
        axi_awvalid=1; axi_awaddr=addr; axi_awprot=0;
        axi_wvalid=1; axi_wdata=data; axi_wstrb=4'b1111;
        wait (axi_awready && axi_wready);
        @(posedge clk);
        axi_awvalid=0; axi_wvalid=0;
        axi_bready=1;
        wait (axi_bvalid);
        @(posedge clk);
        axi_bready=0;
    endtask
    task automatic axi_read(input [31:0] addr, output [31:0] data);
        @(posedge clk);
        axi_arvalid=1; axi_araddr=addr; axi_arprot=0;
        wait (axi_arready);
        @(posedge clk);
        axi_arvalid=0;
        axi_rready=1;
        wait (axi_rvalid);
        data = axi_rdata;
        @(posedge clk);
        axi_rready=0;
    endtask
    task automatic spi_xfer_check(input [7:0] tx, input [7:0] exp);
        logic [31:0] st, rd;
        int guard;
        begin
            axi_write(TDR, {24'h0, tx});
            axi_write(CTRL, 32'h1);
            guard=0;
            do begin axi_read(STATUS, st); guard++; end while ((st[1]==1'b0) && (guard<2000));
            if (st[1]!==1'b1) begin $display("[TB] FAIL: DONE gelmedi tx=0x%02h", tx); errors++; end
            axi_read(RDR, rd);
            if (rd[7:0]===exp) $display("[TB] PASS: gonderilen 0x%02h -> alinan 0x%02h", tx, rd[7:0]);
            else begin $display("[TB] FAIL: beklenen 0x%02h, alinan 0x%02h", exp, rd[7:0]); errors++; end
        end
    endtask
    initial begin
        axi_awvalid=0; axi_wvalid=0; axi_bready=0; axi_arvalid=0; axi_rready=0;
        axi_awaddr=0; axi_wdata=0; axi_wstrb=0; axi_awprot=0; axi_araddr=0; axi_arprot=0;
        rst_n=0; repeat (5) @(posedge clk); rst_n=1; repeat (2) @(posedge clk);
        $display("=== QSPI/SPI Master AXI Testbench ===");
        axi_write(CFG, 32'h1);
        spi_xfer_check(8'hA5, 8'hA5);
        spi_xfer_check(8'h3C, 8'h3C);
        if (busy_seen) $display("[TB] PASS: transfer sirasinda BUSY/CS gozlendi");
        else begin $display("[TB] FAIL: BUSY gozlenmedi"); errors++; end
        if (spi_cs_n===1'b1) $display("[TB] PASS: transfer sonrasi CS_N=1");
        else begin $display("[TB] FAIL: CS_N dusuk kaldi"); errors++; end
        $display("====== TEST SONUCU ======");
        if (errors==0) $display("====== ALL TESTS PASSED ======");
        else $display("====== %0d HATA ======", errors);
        $finish;
    end
    initial begin repeat (30000) @(posedge clk); $display("[TB] WATCHDOG TIMEOUT"); $finish; end
endmodule
