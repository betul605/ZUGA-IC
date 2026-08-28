// ============================================================================
// ram_axi_tb.sv  -- AXI4-Lite RAM Slave Testbench
//
// DUT: ram_axi (WRITE_ENABLE=1, DRAM modu, 256 word = 1 KB)
//
// Senaryolar:
//   1. Tek WRITE
//   2. Tek READ (varsayilan 0 deger)
//   3. Write-then-Read (yazilan veri okundugunda ayni mi)
//   4. Byte enable (wstrb=4'b0001 sadece 1 byte yazma)
// ============================================================================

// ============================================================================
// AXI4-Lite Protocol Check Bind (Faz 8 - Sartname Min. Kriter #3)
// ============================================================================
bind ram_axi axi_lite_protocol_checker u_axi_check (
    .clk_i        (clk_i),
    .rst_ni       (rst_ni),
    .axi_awvalid_i(axi_awvalid_i),
    .axi_awready_o(axi_awready_o),
    .axi_wvalid_i (axi_wvalid_i),
    .axi_wready_o (axi_wready_o),
    .axi_bvalid_o (axi_bvalid_o),
    .axi_bready_i (axi_bready_i),
    .axi_bresp_o  (axi_bresp_o),
    .axi_arvalid_i(axi_arvalid_i),
    .axi_arready_o(axi_arready_o),
    .axi_rvalid_o (axi_rvalid_o),
    .axi_rready_i (axi_rready_i),
    .axi_rdata_o  (axi_rdata_o),
    .axi_rresp_o  (axi_rresp_o)
);

module ram_axi_tb;

    logic clk;
    logic rst_n;

    // AXI4-Lite master sinyalleri (testbench tarafi)
    logic        axi_awvalid;
    logic        axi_awready;
    logic [31:0] axi_awaddr;
    logic [2:0]  axi_awprot;
    logic        axi_wvalid;
    logic        axi_wready;
    logic [31:0] axi_wdata;
    logic [3:0]  axi_wstrb;
    logic        axi_bvalid;
    logic        axi_bready;
    logic [1:0]  axi_bresp;
    logic        axi_arvalid;
    logic        axi_arready;
    logic [31:0] axi_araddr;
    logic [2:0]  axi_arprot;
    logic        axi_rvalid;
    logic        axi_rready;
    logic [31:0] axi_rdata;
    logic [1:0]  axi_rresp;

    int errors = 0;
    int writes_done = 0;
    int reads_done = 0;

    // ------------------------------------------------------------------------
    // DUT
    // ------------------------------------------------------------------------
    ram_axi #(
        .SIZE_WORDS(256),
        .MEM_FILE(""),
        .WRITE_ENABLE(1'b1)
    ) dut (
        .clk_i        (clk),
        .rst_ni       (rst_n),
        .axi_awvalid_i(axi_awvalid),
        .axi_awready_o(axi_awready),
        .axi_awaddr_i (axi_awaddr),
        .axi_awprot_i (axi_awprot),
        .axi_wvalid_i (axi_wvalid),
        .axi_wready_o (axi_wready),
        .axi_wdata_i  (axi_wdata),
        .axi_wstrb_i  (axi_wstrb),
        .axi_bvalid_o (axi_bvalid),
        .axi_bready_i (axi_bready),
        .axi_bresp_o  (axi_bresp),
        .axi_arvalid_i(axi_arvalid),
        .axi_arready_o(axi_arready),
        .axi_araddr_i (axi_araddr),
        .axi_arprot_i (axi_arprot),
        .axi_rvalid_o (axi_rvalid),
        .axi_rready_i (axi_rready),
        .axi_rdata_o  (axi_rdata),
        .axi_rresp_o  (axi_rresp)
    );

    // ------------------------------------------------------------------------
    // Clock & Reset
    // ------------------------------------------------------------------------
    initial clk = 0;
    always #5 clk = ~clk;  // 100 MHz

    initial begin
        rst_n = 0;
        repeat (3) @(posedge clk);
        rst_n = 1;
    end

    // ------------------------------------------------------------------------
    // AXI4-Lite Master Gorevleri
    // ------------------------------------------------------------------------
    task automatic axi_write(input [31:0] addr, input [31:0] data, input [3:0] strb);
        @(posedge clk);
        axi_awvalid = 1;
        axi_awaddr  = addr;
        axi_awprot  = 3'b000;
        axi_wvalid  = 1;
        axi_wdata   = data;
        axi_wstrb   = strb;

        // AW + W handshake bekle
        wait (axi_awready && axi_wready);
        @(posedge clk);
        axi_awvalid = 0;
        axi_wvalid  = 0;

        // BVALID bekle
        axi_bready = 1;
        wait (axi_bvalid);
        @(posedge clk);
        @(negedge clk); axi_bready = 0;
        writes_done++;
    endtask

    task automatic axi_read(input [31:0] addr, output [31:0] data);
        @(posedge clk);
        axi_arvalid = 1;
        axi_araddr  = addr;
        axi_arprot  = 3'b000;

        // AR handshake bekle
        wait (axi_arready);
        @(posedge clk);
        axi_arvalid = 0;

        // RVALID bekle
        axi_rready = 1;
        wait (axi_rvalid);
        data = axi_rdata;
        @(posedge clk);
        @(negedge clk); axi_rready = 0;
        reads_done++;
    endtask

    // ------------------------------------------------------------------------
    // Test Senaryolari
    // ------------------------------------------------------------------------
    logic [31:0] read_data;

    initial begin
        // Init
        axi_awvalid = 0;
        axi_awaddr  = 0;
        axi_awprot  = 0;
        axi_wvalid  = 0;
        axi_wdata   = 0;
        axi_wstrb   = 0;
        axi_bready  = 0;
        axi_arvalid = 0;
        axi_araddr  = 0;
        axi_arprot  = 0;
        axi_rready  = 0;

        $display("[TB] ram_axi testbench BASLADI");
        wait (rst_n);
        repeat (5) @(posedge clk);

        // ----------------------------------------------------------
        $display("[TB] Test 1: Tek WRITE @0x10, data=0xCAFEBABE");
        axi_write(32'h00000010, 32'hCAFEBABE, 4'b1111);
        $display("[TB] PASS: WRITE tamamlandi");
        repeat (3) @(posedge clk);

        // ----------------------------------------------------------
        $display("[TB] Test 2: Tek READ @0x20 (varsayilan 0 olmali)");
        axi_read(32'h00000020, read_data);
        if (read_data !== 32'h00000000) begin
            $display("[TB] HATA: read=%h, beklenen 00000000", read_data);
            errors++;
        end else $display("[TB] PASS: READ varsayilan 0");
        repeat (3) @(posedge clk);

        // ----------------------------------------------------------
        $display("[TB] Test 3: Write-then-Read @0x40, data=0xDEADBEEF");
        axi_write(32'h00000040, 32'hDEADBEEF, 4'b1111);
repeat (2) @(posedge clk);
        axi_read(32'h00000040, read_data);
        if (read_data !== 32'hDEADBEEF) begin
            $display("[TB] HATA: read=%h, beklenen DEADBEEF", read_data);
            errors++;
        end else $display("[TB] PASS: Yazilan veri okundu (DEADBEEF)");
        repeat (3) @(posedge clk);

        // ----------------------------------------------------------
        $display("[TB] Test 4: Byte enable wstrb=4'b0001 (sadece bayt 0)");
        axi_write(32'h00000080, 32'hFFFFFFFF, 4'b1111);  // once tum dolu
repeat (2) @(posedge clk);
        axi_read(32'h00000080, read_data);
        $display("[TB] Once dolu: read=%h", read_data);

        axi_write(32'h00000080, 32'h0000_00AA, 4'b0001);  // sadece bayt 0
repeat (2) @(posedge clk);
        axi_read(32'h00000080, read_data);
        if (read_data !== 32'hFFFF_FFAA) begin
            $display("[TB] HATA: read=%h, beklenen FFFFFFAA", read_data);
            errors++;
        end else $display("[TB] PASS: Byte enable dogru calisti (FFFFFFAA)");
        repeat (3) @(posedge clk);

        // ----------------------------------------------------------
        $display("[TB] ====== TEST SONUCU ======");
        $display("[TB] writes_done = %0d (beklenen: 4)", writes_done);
        $display("[TB] reads_done  = %0d (beklenen: 4)", reads_done);
        $display("[TB] errors      = %0d", errors);
        if (writes_done == 4 && reads_done == 4 && errors == 0)
            $display("[TB] ====== ALL TESTS PASSED ======");
        else
            $display("[TB] ====== SOME TESTS FAILED ======");
        $finish;
    end

    // Watchdog
    initial begin
        repeat (5000) @(posedge clk);
        $display("[TB] WATCHDOG: 5000 cycle gecti, sim takildi");
        $finish;
    end

endmodule
