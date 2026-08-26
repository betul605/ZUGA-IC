// qspi_master_axi.sv -- AXI4-Lite QSPI/SPI Master (temel x1, SPI Mode0)
// Yazmac: 0x00 CTRL(W:[0]START) 0x04 STATUS(RO:[0]BUSY,[1]DONE)
//         0x08 TDR(RW) 0x0C RDR(RO) 0x10 CFG(RW: saat boleni)
module qspi_master_axi (
    input  logic        clk_i,
    input  logic        rst_ni,
    input  logic        axi_awvalid_i,
    output logic        axi_awready_o,
    /* verilator lint_off UNUSEDSIGNAL */
    input  logic [31:0] axi_awaddr_i,
    input  logic [2:0]  axi_awprot_i,
    /* verilator lint_on UNUSEDSIGNAL */
    input  logic        axi_wvalid_i,
    output logic        axi_wready_o,
    /* verilator lint_off UNUSEDSIGNAL */
    input  logic [31:0] axi_wdata_i,
    input  logic [3:0]  axi_wstrb_i,
    /* verilator lint_on UNUSEDSIGNAL */
    output logic        axi_bvalid_o,
    input  logic        axi_bready_i,
    output logic [1:0]  axi_bresp_o,
    input  logic        axi_arvalid_i,
    output logic        axi_arready_o,
    /* verilator lint_off UNUSEDSIGNAL */
    input  logic [31:0] axi_araddr_i,
    input  logic [2:0]  axi_arprot_i,
    /* verilator lint_on UNUSEDSIGNAL */
    output logic        axi_rvalid_o,
    input  logic        axi_rready_i,
    output logic [31:0] axi_rdata_o,
    output logic [1:0]  axi_rresp_o,
    output logic        spi_sclk_o,
    output logic        spi_cs_no,
    output logic        spi_mosi_o,
    input  logic        spi_miso_i
);
    logic [7:0] tdr_q, rdr_q, cfg_q;
    logic is_ctrl_w, is_tdr_w, is_cfg_w;
    assign is_ctrl_w = (axi_awaddr_i[4:2] == 3'b000);
    assign is_tdr_w  = (axi_awaddr_i[4:2] == 3'b010);
    assign is_cfg_w  = (axi_awaddr_i[4:2] == 3'b100);
    typedef enum logic [1:0] { S_IDLE=2'd0, S_WRITE_RESP=2'd1, S_READ_RESP=2'd2 } state_e;
    state_e state_q;
    logic [31:0] read_data_q;
    assign axi_bresp_o   = 2'b00;
    assign axi_rresp_o   = 2'b00;
    assign axi_awready_o = (state_q==S_IDLE) && axi_awvalid_i && axi_wvalid_i;
    assign axi_wready_o  = (state_q==S_IDLE) && axi_awvalid_i && axi_wvalid_i;
    assign axi_arready_o = (state_q==S_IDLE) && axi_arvalid_i;
    assign axi_bvalid_o  = (state_q==S_WRITE_RESP);
    assign axi_rvalid_o  = (state_q==S_READ_RESP);
    assign axi_rdata_o   = read_data_q;
    logic spi_busy, spi_done;
    logic start_wr;
    assign start_wr = (state_q==S_IDLE) && axi_awvalid_i && axi_wvalid_i && is_ctrl_w && axi_wdata_i[0];
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            state_q<=S_IDLE; read_data_q<=32'h0; tdr_q<=8'h0; cfg_q<=8'h03;
        end else begin
            case (state_q)
                S_IDLE: begin
                    if (axi_awvalid_i && axi_wvalid_i) begin
                        if (is_tdr_w) tdr_q<=axi_wdata_i[7:0];
                        if (is_cfg_w) cfg_q<=axi_wdata_i[7:0];
                        state_q<=S_WRITE_RESP;
                    end else if (axi_arvalid_i) begin
                        case (axi_araddr_i[4:2])
                            3'b000: read_data_q<=32'h0;
                            3'b001: read_data_q<={30'h0, spi_done, spi_busy};
                            3'b010: read_data_q<={24'h0, tdr_q};
                            3'b011: read_data_q<={24'h0, rdr_q};
                            3'b100: read_data_q<={24'h0, cfg_q};
                            default: read_data_q<=32'h0;
                        endcase
                        state_q<=S_READ_RESP;
                    end
                end
                S_WRITE_RESP: if (axi_bready_i) state_q<=S_IDLE;
                S_READ_RESP:  if (axi_rready_i) state_q<=S_IDLE;
                default: state_q<=S_IDLE;
            endcase
        end
    end
    logic running_q, sclk_q, cs_n_q, done_q;
    logic [7:0] divcnt_q, txsh_q, rxsh_q;
    logic [3:0] bitcnt_q;
    assign spi_busy=running_q; assign spi_done=done_q;
    assign spi_sclk_o=sclk_q; assign spi_cs_no=cs_n_q; assign spi_mosi_o=txsh_q[7];
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            running_q<=1'b0; divcnt_q<=8'h0; bitcnt_q<=4'h0; txsh_q<=8'h0;
            rxsh_q<=8'h0; sclk_q<=1'b0; cs_n_q<=1'b1; done_q<=1'b0; rdr_q<=8'h0;
        end else begin
            if (!running_q) begin
                if (start_wr) begin
                    running_q<=1'b1; txsh_q<=tdr_q; rxsh_q<=8'h0; bitcnt_q<=4'h0;
                    divcnt_q<=8'h0; sclk_q<=1'b0; cs_n_q<=1'b0; done_q<=1'b0;
                end
            end else begin
                if (divcnt_q==cfg_q) begin
                    divcnt_q<=8'h0;
                    if (sclk_q==1'b0) begin
                        sclk_q<=1'b1; rxsh_q<={rxsh_q[6:0], spi_miso_i}; bitcnt_q<=bitcnt_q+4'd1;
                    end else begin
                        sclk_q<=1'b0;
                        if (bitcnt_q==4'd8) begin
                            running_q<=1'b0; cs_n_q<=1'b1; done_q<=1'b1; rdr_q<=rxsh_q;
                        end else txsh_q<={txsh_q[6:0],1'b0};
                    end
                end else divcnt_q<=divcnt_q+8'd1;
            end
        end
    end
endmodule
