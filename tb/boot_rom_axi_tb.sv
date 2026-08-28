// ============================================================================
// boot_rom_axi_tb.sv  -- Boot ROM AXI4-Lite Testbench
//
// OTR Tablo 1 uyumlu: Boot ROM 0x0000_0000 - 0x0000_01FF (512 B)
//
// ram_axi.sv parametreli yapisi sayesinde, yeni RTL yazimi olmadan
// Boot ROM olarak instance edildi:
//   - SIZE_WORDS = 128 (512 byte)
//   - WRITE_ENABLE = 0 (read-only)
//   - MEM_FILE = "sw/bootloader.hex"
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

module boot_rom_axi_tb;

    logic clk;
    logic rst_n;
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
    int reads_done = 0;

    ram_axi #(
        .SIZE_WORDS  (128),
        .WRITE_ENABLE(1'b0),
        .MEM_FILE    ("sw/bootloader.hex")
    ) u_boot_rom (
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

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        rst_n = 0;
        repeat (3) @(posedge clk);
        rst_n = 1;
    end

    task automatic axi_read(input [31:0] addr, output [31:0] data);
        @(posedge clk);
        axi_arvalid = 1;
        axi_araddr  = addr;
        axi_arprot  = 0;
        wait (axi_arready);
        @(posedge clk);
        axi_arvalid = 0;
        axi_rready  = 1;
        wait (axi_rvalid);
        data = axi_rdata;
        @(posedge clk);
        @(negedge clk);
        axi_rready  = 0;
        reads_done++;
    endtask

    logic [31:0] read_data;

    initial begin
        axi_awvalid = 0; axi_awaddr = 0; axi_awprot = 0;
        axi_wvalid  = 0; axi_wdata = 0; axi_wstrb = 0;
        axi_bready  = 0;
        axi_arvalid = 0; axi_araddr = 0; axi_arprot = 0;
        axi_rready  = 0;

        $display("[TB] boot_rom_axi testbench BASLADI");
        $display("[TB] ram_axi parametreli: SIZE_WORDS=128, WRITE_ENABLE=0");
        wait (rst_n);
        repeat (5) @(posedge clk);

        // Test 1: 0x0000 - ilk word (00010001)
        $display("[TB] Test 1: 0x0000 oku (2 NOP compressed)");
        axi_read(32'h00000000, read_data);
        $display("[TB]   read = %h (beklenen 00010001)", read_data);
        if (read_data !== 32'h00010001) errors++;
        else $display("[TB] PASS: 0x0000 = 00010001");

        // Test 2: 0x0008 - lui t0,0x10 (000162c1)
        $display("[TB] Test 2: 0x0008 oku (lui t0,0x10)");
        axi_read(32'h00000008, read_data);
        $display("[TB]   read = %h (beklenen 000162c1)", read_data);
        if (read_data !== 32'h000162c1) errors++;
        else $display("[TB] PASS: 0x0008 = 000162c1");

        // Test 3: 0x000C - jr t0 (82820001)
        $display("[TB] Test 3: 0x000C oku (jr t0)");
        axi_read(32'h0000000C, read_data);
        $display("[TB]   read = %h (beklenen 82820001)", read_data);
        if (read_data !== 32'h82820001) errors++;
        else $display("[TB] PASS: 0x000C = 82820001");

        // Test 4: 0x0010 - j hang (0000006f)
        $display("[TB] Test 4: 0x0010 oku (j hang)");
        axi_read(32'h00000010, read_data);
        $display("[TB]   read = %h (beklenen 0000006f)", read_data);
        if (read_data !== 32'h0000006f) errors++;
        else $display("[TB] PASS: 0x0010 = 0000006f");

        // Test 5: 0x0100 - bos bolge
        $display("[TB] Test 5: 0x0100 oku (bos bolge)");
        axi_read(32'h00000100, read_data);
        if (read_data !== 32'h00000000) errors++;
        else $display("[TB] PASS: 0x0100 = 0 (bos bolge)");

        // Test 6: Read-only kontrol
        $display("[TB] Test 6: Read-only kontrol (AWREADY hep 0 olmali)");
        @(posedge clk);
        axi_awvalid = 1;
        axi_awaddr  = 32'h00000000;
        axi_wvalid  = 1;
        axi_wdata   = 32'hDEADBEEF;
        axi_wstrb   = 4'b1111;
        repeat (10) @(posedge clk);
        if (axi_awready === 1'b1) begin
            $display("[TB] HATA: AWREADY 1 oldu, read-only olmali");
            errors++;
        end else $display("[TB] PASS: AWREADY 0 kaldi (read-only)");
        axi_awvalid = 0;
        axi_wvalid  = 0;

        // ROM degismedi mi
        axi_read(32'h00000000, read_data);
        if (read_data !== 32'h00010001) begin
            $display("[TB] HATA: ROM icerigi degisti");
            errors++;
        end else $display("[TB] PASS: ROM icerigi korundu");

        $display("[TB] ====== TEST SONUCU ======");
        $display("[TB] reads_done = %0d", reads_done);
        $display("[TB] errors     = %0d", errors);
        if (errors == 0)
            $display("[TB] ====== ALL TESTS PASSED ======");
        else
            $display("[TB] ====== SOME TESTS FAILED ======");
        $finish;
    end

    initial begin
        repeat (1000) @(posedge clk);
        $display("[TB] WATCHDOG");
        $finish;
    end

endmodule
