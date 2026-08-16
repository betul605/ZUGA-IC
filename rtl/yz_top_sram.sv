// ============================================================================
// yz_top_sram.sv -- YZ CNN Hizlandirici SoC + on-chip SRAM giris buffer'i
//
// yz_top'un SRAM'li surumu: giris ozniteligi (input) penceresine yazilan veri
// dogrudan yz_accel'e degil, onceden onaylanmis SKY130 SRAM makrosuna
// (sky130_sram_1kbyte_1rw1r_32x256_8) yazilir. CSR START ile bir loader FSM
// SRAM'den giristi okuyup yz_accel'in input bolgesine (region 0) yukler, sonra
// cikarimi baslatir. Boylece SRAM gercekten fonksiyonel veri yolunda yer alir.
//
// Agirliklar (wconv/bconv/wfc/bfc) buyuk oldugundan dogrudan yz_accel'e yuklenir.
// yz_csr ve yz_accel DEGISTIRILMEMISTIR (dogrulanmis kalir).
// ============================================================================
module yz_top_sram #(
    parameter int IN_H   = 8,  parameter int IN_W  = 8,
    parameter int K_H    = 3,  parameter int K_W   = 3,
    parameter int STRIDE = 1,  parameter int N_FILT= 2,
    parameter int OUT_H  = 8,  parameter int OUT_W = 8,
    parameter int FEAT   = 128,parameter int FC_OUT= 4,
    parameter int SHIFT  = 6,  parameter int PAD_H = 1, parameter int PAD_W = 1
)(
    input  logic        clk_i,
    input  logic        rst_ni,
`ifdef USE_POWER_PINS
    inout               VPWR,
    inout               VGND,
`endif
    input  logic        axi_awvalid_i,
    output logic        axi_awready_o,
    input  logic [31:0] axi_awaddr_i,
    input  logic [2:0]  axi_awprot_i,
    input  logic        axi_wvalid_i,
    output logic        axi_wready_o,
    input  logic [31:0] axi_wdata_i,
    input  logic [3:0]  axi_wstrb_i,
    output logic        axi_bvalid_o,
    input  logic        axi_bready_i,
    output logic [1:0]  axi_bresp_o,
    input  logic        axi_arvalid_i,
    output logic        axi_arready_o,
    input  logic [31:0] axi_araddr_i,
    input  logic [2:0]  axi_arprot_i,
    output logic        axi_rvalid_o,
    input  logic        axi_rready_i,
    output logic [31:0] axi_rdata_o,
    output logic [1:0]  axi_rresp_o,
    output logic        irq_o
);
    localparam int N_IN = IN_H*IN_W;
    localparam logic [15:0] N_IN_M1 = N_IN[15:0] - 16'd1;

    // -------- Alt bolge secimi (addr[23:20]) --------
    logic csr_wr_sel, csr_rd_sel, in_wr_sel, wt_wr_sel, log_rd_sel;
    assign csr_wr_sel = (axi_awaddr_i[23:20] == 4'h0);
    assign csr_rd_sel = (axi_araddr_i[23:20] == 4'h0);
    assign in_wr_sel  = (axi_awaddr_i[23:20] == 4'h1);                        // input -> SRAM
    assign wt_wr_sel  = (axi_awaddr_i[23:20] >= 4'h2) && (axi_awaddr_i[23:20] <= 4'h5); // weights -> accel
    assign log_rd_sel = (axi_araddr_i[23:20] == 4'h6);

    // ============================ CSR (yz_csr) ============================
    logic        c_awready, c_wready, c_bvalid, c_arready, c_rvalid;
    logic [1:0]  c_bresp, c_rresp;
    logic [31:0] c_rdata;
    logic        yz_start, yz_swrst, yz_busy, yz_done, yz_error;
    /* verilator lint_off UNUSEDSIGNAL */
    logic [31:0] yz_in_addr, yz_out_addr, yz_wt_addr, yz_len;
    logic [3:0]  yz_ksize, yz_stride;
    /* verilator lint_on UNUSEDSIGNAL */
    yz_csr u_csr (
        .clk_i(clk_i), .rst_ni(rst_ni),
        .axi_awvalid_i(axi_awvalid_i & csr_wr_sel), .axi_awready_o(c_awready),
        .axi_awaddr_i(axi_awaddr_i), .axi_awprot_i(axi_awprot_i),
        .axi_wvalid_i(axi_wvalid_i & csr_wr_sel), .axi_wready_o(c_wready),
        .axi_wdata_i(axi_wdata_i), .axi_wstrb_i(axi_wstrb_i),
        .axi_bvalid_o(c_bvalid), .axi_bready_i(axi_bready_i & csr_wr_sel), .axi_bresp_o(c_bresp),
        .axi_arvalid_i(axi_arvalid_i & csr_rd_sel), .axi_arready_o(c_arready),
        .axi_araddr_i(axi_araddr_i), .axi_arprot_i(axi_arprot_i),
        .axi_rvalid_o(c_rvalid), .axi_rready_i(axi_rready_i & csr_rd_sel), .axi_rdata_o(c_rdata), .axi_rresp_o(c_rresp),
        .start_o(yz_start), .sw_reset_o(yz_swrst),
        .busy_i(yz_busy), .done_i(yz_done), .error_i(yz_error),
        .input_addr_o(yz_in_addr), .output_addr_o(yz_out_addr), .weight_addr_o(yz_wt_addr),
        .kernel_size_o(yz_ksize), .stride_o(yz_stride), .len_o(yz_len)
    );

    // ======================== SRAM giris buffer'i ========================
    logic        sram_csb, sram_web;
    logic [7:0]  sram_addr;
    logic [31:0] sram_din, sram_dout;
    logic [3:0]  sram_wmask;

    sky130_sram_1kbyte_1rw1r_32x256_8 u_sram_in (
`ifdef USE_POWER_PINS
        .vccd1 (VPWR), .vssd1 (VGND),
`endif
        .clk0(clk_i), .csb0(sram_csb), .web0(sram_web), .wmask0(sram_wmask),
        .addr0(sram_addr), .din0(sram_din), .dout0(sram_dout),
        .clk1(clk_i), .csb1(1'b1), .addr1(8'd0), .dout1()
    );

    // ======================== Datapath (yz_accel) ========================
    logic [15:0] logit_addr;
    logic [31:0] logit_rdata;
    logic        acc_mem_we;
    logic [2:0]  acc_mem_region;
    logic [15:0] acc_mem_addr;
    logic [31:0] acc_mem_wdata;
    logic        acc_start;
    /* verilator lint_off UNUSEDSIGNAL */
    logic [31:0] yz_cyc;
    logic [7:0]  yz_argmax;
    /* verilator lint_on UNUSEDSIGNAL */
    yz_accel #(
        .IN_H(IN_H), .IN_W(IN_W), .K_H(K_H), .K_W(K_W), .STRIDE(STRIDE),
        .N_FILT(N_FILT), .OUT_H(OUT_H), .OUT_W(OUT_W), .FEAT(FEAT),
        .FC_OUT(FC_OUT), .SHIFT(SHIFT), .PAD_H(PAD_H), .PAD_W(PAD_W)
    ) u_accel (
        .clk_i(clk_i), .rst_ni(rst_ni),
        .start_i(acc_start), .sw_reset_i(yz_swrst),
        .busy_o(yz_busy), .done_o(yz_done), .error_o(yz_error), .irq_o(irq_o),
        .cycle_cnt_o(yz_cyc), .argmax_o(yz_argmax),
        .logit_addr_i(logit_addr), .logit_rdata_o(logit_rdata),
        .mem_we_i(acc_mem_we), .mem_region_i(acc_mem_region),
        .mem_addr_i(acc_mem_addr), .mem_wdata_i(acc_mem_wdata)
    );

    // ============ AXI veri yazma + logit okuma FSM ============
    typedef enum logic [1:0] { D_IDLE, D_WRESP, D_RRESP } dstate_e;
    dstate_e d_st;
    logic [31:0] d_rdata;
    logic        d_awready, d_wready, d_bvalid, d_arready, d_rvalid;
    assign d_awready = (d_st == D_IDLE) && axi_awvalid_i && axi_wvalid_i && (in_wr_sel || wt_wr_sel);
    assign d_wready  = d_awready;
    assign d_arready = (d_st == D_IDLE) && axi_arvalid_i && log_rd_sel;
    assign d_bvalid  = (d_st == D_WRESP);
    assign d_rvalid  = (d_st == D_RRESP);
    assign logit_addr = axi_araddr_i[17:2];

    // AXI tarafi weight yazma sinyalleri (yz_accel'e)
    logic        axi_acc_we;
    logic [2:0]  axi_acc_region;
    logic [15:0] axi_acc_addr;
    logic [31:0] axi_acc_wdata;

    // AXI tarafi SRAM yazma sinyalleri (input)
    logic        axi_sram_we;
    logic [7:0]  axi_sram_addr;
    logic [31:0] axi_sram_wdata;

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            d_st <= D_IDLE; d_rdata <= 32'h0;
            axi_acc_we <= 1'b0; axi_acc_region <= 3'd0; axi_acc_addr <= 16'd0; axi_acc_wdata <= 32'd0;
            axi_sram_we <= 1'b0; axi_sram_addr <= 8'd0; axi_sram_wdata <= 32'd0;
        end else begin
            axi_acc_we  <= 1'b0;
            axi_sram_we <= 1'b0;
            case (d_st)
                D_IDLE: begin
                    if (axi_awvalid_i && axi_wvalid_i && in_wr_sel) begin
                        // input -> SRAM (bir int8/word)
                        axi_sram_addr  <= axi_awaddr_i[9:2];
                        axi_sram_wdata <= axi_wdata_i;
                        axi_sram_we    <= 1'b1;
                        d_st           <= D_WRESP;
                    end else if (axi_awvalid_i && axi_wvalid_i && wt_wr_sel) begin
                        // weights -> yz_accel (region 2..5 -> 1..4)
                        axi_acc_region <= (axi_awaddr_i[22:20] - 3'd1);
                        axi_acc_addr   <= axi_awaddr_i[17:2];
                        axi_acc_wdata  <= axi_wdata_i;
                        axi_acc_we     <= 1'b1;
                        d_st           <= D_WRESP;
                    end else if (axi_arvalid_i && log_rd_sel) begin
                        d_rdata <= logit_rdata;
                        d_st    <= D_RRESP;
                    end
                end
                D_WRESP: if (axi_bready_i) d_st <= D_IDLE;
                D_RRESP: if (axi_rready_i) d_st <= D_IDLE;
                default: d_st <= D_IDLE;
            endcase
        end
    end

    // ==================== Loader FSM (SRAM -> yz_accel input) ====================
    typedef enum logic [1:0] { L_IDLE, L_SET, L_CAP, L_FIRE } lstate_e;
    lstate_e l_st;
    logic [15:0] l_idx;
    logic        ld_acc_we;
    logic [15:0] ld_acc_addr;
    logic [31:0] ld_acc_wdata;
    logic        ld_active;

    assign ld_active = (l_st != L_IDLE);

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            l_st <= L_IDLE; l_idx <= 16'd0;
            ld_acc_we <= 1'b0; ld_acc_addr <= 16'd0; ld_acc_wdata <= 32'd0;
            acc_start <= 1'b0;
        end else begin
            ld_acc_we <= 1'b0;
            acc_start <= 1'b0;
            case (l_st)
                L_IDLE:  if (yz_start) begin l_idx <= 16'd0; l_st <= L_SET; end
                L_SET:   l_st <= L_CAP;                       // SRAM okuma latency
                L_CAP: begin
                    ld_acc_we    <= 1'b1;                     // yz_accel input yaz
                    ld_acc_addr  <= l_idx;
                    ld_acc_wdata <= {24'h0, sram_dout[7:0]};
                    if (l_idx == N_IN_M1) l_st <= L_FIRE;
                    else begin l_idx <= l_idx + 16'd1; l_st <= L_SET; end
                end
                L_FIRE:  begin acc_start <= 1'b1; l_st <= L_IDLE; end
                default: l_st <= L_IDLE;
            endcase
        end
    end

    // ==================== SRAM port A surus mux ====================
    // Loader aktifken SRAM okur; degilse AXI input yazar
    always_comb begin
        if (ld_active) begin
            sram_csb   = 1'b0;
            sram_web   = 1'b1;            // okuma
            sram_wmask = 4'b0000;
            sram_addr  = l_idx[7:0];
            sram_din   = 32'd0;
        end else if (axi_sram_we) begin
            sram_csb   = 1'b0;
            sram_web   = 1'b0;            // yazma
            sram_wmask = 4'b1111;
            sram_addr  = axi_sram_addr;
            sram_din   = axi_sram_wdata;
        end else begin
            sram_csb   = 1'b1;
            sram_web   = 1'b1;
            sram_wmask = 4'b0000;
            sram_addr  = 8'd0;
            sram_din   = 32'd0;
        end
    end

    // ==================== yz_accel mem_we mux (loader input vs AXI weights) ====================
    always_comb begin
        if (ld_active) begin
            acc_mem_we     = ld_acc_we;
            acc_mem_region = 3'd0;        // input
            acc_mem_addr   = ld_acc_addr;
            acc_mem_wdata  = ld_acc_wdata;
        end else begin
            acc_mem_we     = axi_acc_we;
            acc_mem_region = axi_acc_region;
            acc_mem_addr   = axi_acc_addr;
            acc_mem_wdata  = axi_acc_wdata;
        end
    end

    // ==================== AXI cevap mux ====================
    assign axi_awready_o = csr_wr_sel ? c_awready : d_awready;
    assign axi_wready_o  = csr_wr_sel ? c_wready  : d_wready;
    assign axi_bvalid_o  = csr_wr_sel ? c_bvalid  : d_bvalid;
    assign axi_bresp_o   = csr_wr_sel ? c_bresp   : 2'b00;
    assign axi_arready_o = csr_rd_sel ? c_arready : d_arready;
    assign axi_rvalid_o  = csr_rd_sel ? c_rvalid  : d_rvalid;
    assign axi_rdata_o   = csr_rd_sel ? c_rdata   : d_rdata;
    assign axi_rresp_o   = csr_rd_sel ? c_rresp   : 2'b00;
endmodule
