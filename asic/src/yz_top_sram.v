module yz_csr (
	clk_i,
	rst_ni,
	axi_awvalid_i,
	axi_awready_o,
	axi_awaddr_i,
	axi_awprot_i,
	axi_wvalid_i,
	axi_wready_o,
	axi_wdata_i,
	axi_wstrb_i,
	axi_bvalid_o,
	axi_bready_i,
	axi_bresp_o,
	axi_arvalid_i,
	axi_arready_o,
	axi_araddr_i,
	axi_arprot_i,
	axi_rvalid_o,
	axi_rready_i,
	axi_rdata_o,
	axi_rresp_o,
	start_o,
	sw_reset_o,
	busy_i,
	done_i,
	error_i,
	input_addr_o,
	output_addr_o,
	weight_addr_o,
	kernel_size_o,
	stride_o,
	len_o
);
	input wire clk_i;
	input wire rst_ni;
	input wire axi_awvalid_i;
	output wire axi_awready_o;
	input wire [31:0] axi_awaddr_i;
	input wire [2:0] axi_awprot_i;
	input wire axi_wvalid_i;
	output wire axi_wready_o;
	input wire [31:0] axi_wdata_i;
	input wire [3:0] axi_wstrb_i;
	output wire axi_bvalid_o;
	input wire axi_bready_i;
	output wire [1:0] axi_bresp_o;
	input wire axi_arvalid_i;
	output wire axi_arready_o;
	input wire [31:0] axi_araddr_i;
	input wire [2:0] axi_arprot_i;
	output wire axi_rvalid_o;
	input wire axi_rready_i;
	output wire [31:0] axi_rdata_o;
	output wire [1:0] axi_rresp_o;
	output wire start_o;
	output wire sw_reset_o;
	input wire busy_i;
	input wire done_i;
	input wire error_i;
	output wire [31:0] input_addr_o;
	output wire [31:0] output_addr_o;
	output wire [31:0] weight_addr_o;
	output wire [3:0] kernel_size_o;
	output wire [3:0] stride_o;
	output wire [31:0] len_o;
	reg [31:0] ctrl_q;
	wire [31:0] status_q;
	reg [31:0] input_addr_q;
	reg [31:0] output_addr_q;
	reg [31:0] weight_addr_q;
	reg [31:0] cfg_q;
	reg [31:0] len_q;
	reg [31:0] cycle_cnt_q;
	wire [4:0] w_off;
	wire [4:0] r_off;
	assign w_off = axi_awaddr_i[4:0];
	assign r_off = axi_araddr_i[4:0];
	assign start_o = ctrl_q[0];
	assign sw_reset_o = ctrl_q[1];
	assign input_addr_o = input_addr_q;
	assign output_addr_o = output_addr_q;
	assign weight_addr_o = weight_addr_q;
	assign kernel_size_o = cfg_q[3:0];
	assign stride_o = cfg_q[7:4];
	assign len_o = len_q;
	assign status_q = {29'h00000000, error_i, done_i, busy_i};
	reg [1:0] axi_state_q;
	reg [31:0] read_data_q;
	assign axi_bresp_o = 2'b00;
	assign axi_rresp_o = 2'b00;
	assign axi_awready_o = ((axi_state_q == 2'd0) && axi_awvalid_i) && axi_wvalid_i;
	assign axi_wready_o = ((axi_state_q == 2'd0) && axi_awvalid_i) && axi_wvalid_i;
	assign axi_arready_o = (axi_state_q == 2'd0) && axi_arvalid_i;
	assign axi_bvalid_o = axi_state_q == 2'd1;
	assign axi_rvalid_o = axi_state_q == 2'd2;
	assign axi_rdata_o = read_data_q;
	always @(posedge clk_i or negedge rst_ni)
		if (!rst_ni) begin
			ctrl_q <= 32'h00000000;
			input_addr_q <= 32'h00000000;
			output_addr_q <= 32'h00000000;
			weight_addr_q <= 32'h00000000;
			cfg_q <= 32'h00000000;
			len_q <= 32'h00000000;
			cycle_cnt_q <= 32'h00000000;
			axi_state_q <= 2'd0;
			read_data_q <= 32'h00000000;
		end
		else begin
			if (busy_i)
				cycle_cnt_q <= cycle_cnt_q + 1;
			else if (start_o)
				cycle_cnt_q <= 32'h00000000;
			if (ctrl_q[0])
				ctrl_q[0] <= 1'b0;
			case (axi_state_q)
				2'd0:
					if (axi_awvalid_i && axi_wvalid_i) begin
						case (w_off)
							5'h00: ctrl_q <= axi_wdata_i;
							5'h08: input_addr_q <= axi_wdata_i;
							5'h0c: output_addr_q <= axi_wdata_i;
							5'h10: weight_addr_q <= axi_wdata_i;
							5'h14: cfg_q <= axi_wdata_i;
							5'h18: len_q <= axi_wdata_i;
							default:
								;
						endcase
						axi_state_q <= 2'd1;
					end
					else if (axi_arvalid_i) begin
						case (r_off)
							5'h00: read_data_q <= ctrl_q;
							5'h04: read_data_q <= status_q;
							5'h08: read_data_q <= input_addr_q;
							5'h0c: read_data_q <= output_addr_q;
							5'h10: read_data_q <= weight_addr_q;
							5'h14: read_data_q <= cfg_q;
							5'h18: read_data_q <= len_q;
							5'h1c: read_data_q <= cycle_cnt_q;
							default: read_data_q <= 32'h00000000;
						endcase
						axi_state_q <= 2'd2;
					end
				2'd1:
					if (axi_bready_i)
						axi_state_q <= 2'd0;
				2'd2:
					if (axi_rready_i)
						axi_state_q <= 2'd0;
				default: axi_state_q <= 2'd0;
			endcase
		end
endmodule
module yz_accel (
	clk_i,
	rst_ni,
	start_i,
	sw_reset_i,
	busy_o,
	done_o,
	error_o,
	irq_o,
	cycle_cnt_o,
	argmax_o,
	logit_addr_i,
	logit_rdata_o,
	mem_we_i,
	mem_region_i,
	mem_addr_i,
	mem_wdata_i
);
	parameter signed [31:0] IN_H = 8;
	parameter signed [31:0] IN_W = 8;
	parameter signed [31:0] K_H = 3;
	parameter signed [31:0] K_W = 3;
	parameter signed [31:0] STRIDE = 1;
	parameter signed [31:0] N_FILT = 2;
	parameter signed [31:0] OUT_H = 8;
	parameter signed [31:0] OUT_W = 8;
	parameter signed [31:0] FEAT = 128;
	parameter signed [31:0] FC_OUT = 4;
	parameter signed [31:0] SHIFT = 6;
	parameter signed [31:0] PAD_H = 1;
	parameter signed [31:0] PAD_W = 1;
	input wire clk_i;
	input wire rst_ni;
	input wire start_i;
	input wire sw_reset_i;
	output reg busy_o;
	output reg done_o;
	output reg error_o;
	output wire irq_o;
	output reg [31:0] cycle_cnt_o;
	output reg [7:0] argmax_o;
	input wire [15:0] logit_addr_i;
	output wire [31:0] logit_rdata_o;
	input wire mem_we_i;
	input wire [2:0] mem_region_i;
	input wire [15:0] mem_addr_i;
	input wire [31:0] mem_wdata_i;
	reg signed [7:0] imem [0:(IN_H * IN_W) - 1];
	reg signed [7:0] wconv [0:((N_FILT * K_H) * K_W) - 1];
	reg signed [31:0] bconv [0:N_FILT - 1];
	reg signed [7:0] actm [0:FEAT - 1];
	reg signed [7:0] wfc [0:(FC_OUT * FEAT) - 1];
	reg signed [31:0] bfc [0:FC_OUT - 1];
	reg signed [31:0] logitm [0:FC_OUT - 1];
	localparam signed [31:0] IN_AW = ((IN_H * IN_W) > 1 ? $clog2(IN_H * IN_W) : 1);
	localparam signed [31:0] WC_AW = (((N_FILT * K_H) * K_W) > 1 ? $clog2((N_FILT * K_H) * K_W) : 1);
	localparam signed [31:0] ACT_AW = (FEAT > 1 ? $clog2(FEAT) : 1);
	localparam signed [31:0] WF_AW = ((FC_OUT * FEAT) > 1 ? $clog2(FC_OUT * FEAT) : 1);
	localparam signed [31:0] BC_AW = (N_FILT > 1 ? $clog2(N_FILT) : 1);
	localparam signed [31:0] BF_AW = (FC_OUT > 1 ? $clog2(FC_OUT) : 1);
	always @(posedge clk_i)
		if (mem_we_i)
			case (mem_region_i)
				3'd0: imem[mem_addr_i[IN_AW - 1:0]] <= mem_wdata_i[7:0];
				3'd1: wconv[mem_addr_i[WC_AW - 1:0]] <= mem_wdata_i[7:0];
				3'd2: bconv[mem_addr_i[BC_AW - 1:0]] <= mem_wdata_i;
				3'd3: wfc[mem_addr_i[WF_AW - 1:0]] <= mem_wdata_i[7:0];
				3'd4: bfc[mem_addr_i[BF_AW - 1:0]] <= mem_wdata_i;
				default:
					;
			endcase
	assign logit_rdata_o = logitm[logit_addr_i[BF_AW - 1:0]];
	reg [3:0] st;
	reg [31:0] c;
	reg [31:0] oy;
	reg [31:0] ox;
	reg [31:0] ky;
	reg [31:0] kx;
	reg [31:0] f;
	reg [31:0] ii;
	reg [31:0] am_f;
	reg signed [31:0] acc;
	reg signed [31:0] am_best;
	reg [31:0] am_idx;
	wire signed [31:0] iy;
	wire signed [31:0] ix;
	assign iy = (($signed(oy) * STRIDE) - PAD_H) + $signed(ky);
	assign ix = (($signed(ox) * STRIDE) - PAD_W) + $signed(kx);
	wire in_bounds;
	assign in_bounds = (((iy >= 0) && (iy < IN_H)) && (ix >= 0)) && (ix < IN_W);
	wire [31:0] in_idx;
	wire [31:0] wc_idx;
	wire [31:0] act_idx;
	wire [31:0] wf_idx;
	assign in_idx = $unsigned((iy * IN_W) + ix);
	assign wc_idx = (((c * K_H) + ky) * K_W) + kx;
	assign act_idx = (((c * OUT_H) + oy) * OUT_W) + ox;
	assign wf_idx = (f * FEAT) + ii;
	wire signed [7:0] op_in;
	wire signed [31:0] product_conv;
	assign op_in = (in_bounds ? imem[in_idx[IN_AW - 1:0]] : 8'sd0);
	function automatic signed [31:0] sv2v_cast_32_signed;
		input reg signed [31:0] inp;
		sv2v_cast_32_signed = inp;
	endfunction
	assign product_conv = sv2v_cast_32_signed($signed(op_in) * $signed(wconv[wc_idx[WC_AW - 1:0]]));
	wire signed [31:0] product_fc;
	assign product_fc = sv2v_cast_32_signed($signed(actm[ii[ACT_AW - 1:0]]) * $signed(wfc[wf_idx[WF_AW - 1:0]]));
	function automatic signed [7:0] requant;
		input reg signed [31:0] a;
		reg signed [31:0] t;
		begin
			t = (a < 0 ? 32'sd0 : a);
			t = t >>> SHIFT;
			if (t > 127)
				t = 127;
			requant = t[7:0];
		end
	endfunction
	reg done_pulse;
	always @(posedge clk_i or negedge rst_ni)
		if (!rst_ni) begin
			st <= 4'd0;
			busy_o <= 1'b0;
			done_o <= 1'b0;
			error_o <= 1'b0;
			done_pulse <= 1'b0;
			cycle_cnt_o <= 32'd0;
			argmax_o <= 8'd0;
			c <= 0;
			oy <= 0;
			ox <= 0;
			ky <= 0;
			kx <= 0;
			f <= 0;
			ii <= 0;
			am_f <= 0;
			acc <= 0;
			am_best <= 0;
			am_idx <= 0;
		end
		else begin
			done_pulse <= 1'b0;
			if (sw_reset_i) begin
				st <= 4'd0;
				busy_o <= 1'b0;
				done_o <= 1'b0;
				error_o <= 1'b0;
			end
			else begin
				if (busy_o)
					cycle_cnt_o <= cycle_cnt_o + 1;
				case (st)
					4'd0:
						if (start_i) begin
							busy_o <= 1'b1;
							done_o <= 1'b0;
							error_o <= 1'b0;
							cycle_cnt_o <= 32'd0;
							c <= 0;
							oy <= 0;
							ox <= 0;
							st <= 4'd1;
						end
					4'd1: begin
						acc <= bconv[c[BC_AW - 1:0]];
						ky <= 0;
						kx <= 0;
						st <= 4'd2;
					end
					4'd2: begin
						acc <= acc + product_conv;
						if (kx < (K_W - 1))
							kx <= kx + 1;
						else begin
							kx <= 0;
							if (ky < (K_H - 1))
								ky <= ky + 1;
							else
								st <= 4'd3;
						end
					end
					4'd3: begin
						actm[act_idx[ACT_AW - 1:0]] <= requant(acc);
						if (ox < (OUT_W - 1)) begin
							ox <= ox + 1;
							st <= 4'd1;
						end
						else begin
							ox <= 0;
							if (oy < (OUT_H - 1)) begin
								oy <= oy + 1;
								st <= 4'd1;
							end
							else begin
								oy <= 0;
								if (c < (N_FILT - 1)) begin
									c <= c + 1;
									st <= 4'd1;
								end
								else begin
									f <= 0;
									st <= 4'd4;
								end
							end
						end
					end
					4'd4: begin
						acc <= bfc[f[BF_AW - 1:0]];
						ii <= 0;
						st <= 4'd5;
					end
					4'd5: begin
						acc <= acc + product_fc;
						if (ii < (FEAT - 1))
							ii <= ii + 1;
						else
							st <= 4'd6;
					end
					4'd6: begin
						logitm[f[BF_AW - 1:0]] <= acc;
						if (f < (FC_OUT - 1)) begin
							f <= f + 1;
							st <= 4'd4;
						end
						else begin
							am_f <= 0;
							am_best <= 32'sh80000000;
							am_idx <= 0;
							st <= 4'd7;
						end
					end
					4'd7: begin
						if (logitm[am_f[BF_AW - 1:0]] > am_best) begin
							am_best <= logitm[am_f[BF_AW - 1:0]];
							am_idx <= am_f;
						end
						if (am_f < (FC_OUT - 1))
							am_f <= am_f + 1;
						else begin
							argmax_o <= (logitm[am_f[BF_AW - 1:0]] > am_best ? am_f[7:0] : am_idx[7:0]);
							st <= 4'd8;
						end
					end
					4'd8: begin
						busy_o <= 1'b0;
						done_o <= 1'b1;
						done_pulse <= 1'b1;
						st <= 4'd0;
					end
					default: st <= 4'd0;
				endcase
			end
		end
	assign irq_o = done_pulse;
endmodule
module yz_top_sram (
	clk_i,
	rst_ni,
	axi_awvalid_i,
	axi_awready_o,
	axi_awaddr_i,
	axi_awprot_i,
	axi_wvalid_i,
	axi_wready_o,
	axi_wdata_i,
	axi_wstrb_i,
	axi_bvalid_o,
	axi_bready_i,
	axi_bresp_o,
	axi_arvalid_i,
	axi_arready_o,
	axi_araddr_i,
	axi_arprot_i,
	axi_rvalid_o,
	axi_rready_i,
	axi_rdata_o,
	axi_rresp_o,
	irq_o
);
	reg _sv2v_0;
	parameter signed [31:0] IN_H = 8;
	parameter signed [31:0] IN_W = 8;
	parameter signed [31:0] K_H = 3;
	parameter signed [31:0] K_W = 3;
	parameter signed [31:0] STRIDE = 1;
	parameter signed [31:0] N_FILT = 2;
	parameter signed [31:0] OUT_H = 8;
	parameter signed [31:0] OUT_W = 8;
	parameter signed [31:0] FEAT = 128;
	parameter signed [31:0] FC_OUT = 4;
	parameter signed [31:0] SHIFT = 6;
	parameter signed [31:0] PAD_H = 1;
	parameter signed [31:0] PAD_W = 1;
	input wire clk_i;
	input wire rst_ni;
	input wire axi_awvalid_i;
	output wire axi_awready_o;
	input wire [31:0] axi_awaddr_i;
	input wire [2:0] axi_awprot_i;
	input wire axi_wvalid_i;
	output wire axi_wready_o;
	input wire [31:0] axi_wdata_i;
	input wire [3:0] axi_wstrb_i;
	output wire axi_bvalid_o;
	input wire axi_bready_i;
	output wire [1:0] axi_bresp_o;
	input wire axi_arvalid_i;
	output wire axi_arready_o;
	input wire [31:0] axi_araddr_i;
	input wire [2:0] axi_arprot_i;
	output wire axi_rvalid_o;
	input wire axi_rready_i;
	output wire [31:0] axi_rdata_o;
	output wire [1:0] axi_rresp_o;
	output wire irq_o;
	localparam signed [31:0] N_IN = IN_H * IN_W;
	localparam [15:0] N_IN_M1 = N_IN[15:0] - 16'd1;
	wire csr_wr_sel;
	wire csr_rd_sel;
	wire in_wr_sel;
	wire wt_wr_sel;
	wire log_rd_sel;
	assign csr_wr_sel = axi_awaddr_i[23:20] == 4'h0;
	assign csr_rd_sel = axi_araddr_i[23:20] == 4'h0;
	assign in_wr_sel = axi_awaddr_i[23:20] == 4'h1;
	assign wt_wr_sel = (axi_awaddr_i[23:20] >= 4'h2) && (axi_awaddr_i[23:20] <= 4'h5);
	assign log_rd_sel = axi_araddr_i[23:20] == 4'h6;
	wire c_awready;
	wire c_wready;
	wire c_bvalid;
	wire c_arready;
	wire c_rvalid;
	wire [1:0] c_bresp;
	wire [1:0] c_rresp;
	wire [31:0] c_rdata;
	wire yz_start;
	wire yz_swrst;
	wire yz_busy;
	wire yz_done;
	wire yz_error;
	wire [31:0] yz_in_addr;
	wire [31:0] yz_out_addr;
	wire [31:0] yz_wt_addr;
	wire [31:0] yz_len;
	wire [3:0] yz_ksize;
	wire [3:0] yz_stride;
	yz_csr u_csr(
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.axi_awvalid_i(axi_awvalid_i & csr_wr_sel),
		.axi_awready_o(c_awready),
		.axi_awaddr_i(axi_awaddr_i),
		.axi_awprot_i(axi_awprot_i),
		.axi_wvalid_i(axi_wvalid_i & csr_wr_sel),
		.axi_wready_o(c_wready),
		.axi_wdata_i(axi_wdata_i),
		.axi_wstrb_i(axi_wstrb_i),
		.axi_bvalid_o(c_bvalid),
		.axi_bready_i(axi_bready_i & csr_wr_sel),
		.axi_bresp_o(c_bresp),
		.axi_arvalid_i(axi_arvalid_i & csr_rd_sel),
		.axi_arready_o(c_arready),
		.axi_araddr_i(axi_araddr_i),
		.axi_arprot_i(axi_arprot_i),
		.axi_rvalid_o(c_rvalid),
		.axi_rready_i(axi_rready_i & csr_rd_sel),
		.axi_rdata_o(c_rdata),
		.axi_rresp_o(c_rresp),
		.start_o(yz_start),
		.sw_reset_o(yz_swrst),
		.busy_i(yz_busy),
		.done_i(yz_done),
		.error_i(yz_error),
		.input_addr_o(yz_in_addr),
		.output_addr_o(yz_out_addr),
		.weight_addr_o(yz_wt_addr),
		.kernel_size_o(yz_ksize),
		.stride_o(yz_stride),
		.len_o(yz_len)
	);
	reg sram_csb;
	reg sram_web;
	reg [7:0] sram_addr;
	reg [31:0] sram_din;
	wire [31:0] sram_dout;
	reg [3:0] sram_wmask;
	sky130_sram_1kbyte_1rw1r_32x256_8 u_sram_in(
		.clk0(clk_i),
		.csb0(sram_csb),
		.web0(sram_web),
		.wmask0(sram_wmask),
		.addr0(sram_addr),
		.din0(sram_din),
		.dout0(sram_dout),
		.clk1(clk_i),
		.csb1(1'b1),
		.addr1(8'd0),
		.dout1()
	);
	wire [15:0] logit_addr;
	wire [31:0] logit_rdata;
	reg acc_mem_we;
	reg [2:0] acc_mem_region;
	reg [15:0] acc_mem_addr;
	reg [31:0] acc_mem_wdata;
	reg acc_start;
	wire [31:0] yz_cyc;
	wire [7:0] yz_argmax;
	yz_accel #(
		.IN_H(IN_H),
		.IN_W(IN_W),
		.K_H(K_H),
		.K_W(K_W),
		.STRIDE(STRIDE),
		.N_FILT(N_FILT),
		.OUT_H(OUT_H),
		.OUT_W(OUT_W),
		.FEAT(FEAT),
		.FC_OUT(FC_OUT),
		.SHIFT(SHIFT),
		.PAD_H(PAD_H),
		.PAD_W(PAD_W)
	) u_accel(
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.start_i(acc_start),
		.sw_reset_i(yz_swrst),
		.busy_o(yz_busy),
		.done_o(yz_done),
		.error_o(yz_error),
		.irq_o(irq_o),
		.cycle_cnt_o(yz_cyc),
		.argmax_o(yz_argmax),
		.logit_addr_i(logit_addr),
		.logit_rdata_o(logit_rdata),
		.mem_we_i(acc_mem_we),
		.mem_region_i(acc_mem_region),
		.mem_addr_i(acc_mem_addr),
		.mem_wdata_i(acc_mem_wdata)
	);
	reg [1:0] d_st;
	reg [31:0] d_rdata;
	wire d_awready;
	wire d_wready;
	wire d_bvalid;
	wire d_arready;
	wire d_rvalid;
	assign d_awready = (((d_st == 2'd0) && axi_awvalid_i) && axi_wvalid_i) && (in_wr_sel || wt_wr_sel);
	assign d_wready = d_awready;
	assign d_arready = ((d_st == 2'd0) && axi_arvalid_i) && log_rd_sel;
	assign d_bvalid = d_st == 2'd1;
	assign d_rvalid = d_st == 2'd2;
	assign logit_addr = axi_araddr_i[17:2];
	reg axi_acc_we;
	reg [2:0] axi_acc_region;
	reg [15:0] axi_acc_addr;
	reg [31:0] axi_acc_wdata;
	reg axi_sram_we;
	reg [7:0] axi_sram_addr;
	reg [31:0] axi_sram_wdata;
	always @(posedge clk_i or negedge rst_ni)
		if (!rst_ni) begin
			d_st <= 2'd0;
			d_rdata <= 32'h00000000;
			axi_acc_we <= 1'b0;
			axi_acc_region <= 3'd0;
			axi_acc_addr <= 16'd0;
			axi_acc_wdata <= 32'd0;
			axi_sram_we <= 1'b0;
			axi_sram_addr <= 8'd0;
			axi_sram_wdata <= 32'd0;
		end
		else begin
			axi_acc_we <= 1'b0;
			axi_sram_we <= 1'b0;
			case (d_st)
				2'd0:
					if ((axi_awvalid_i && axi_wvalid_i) && in_wr_sel) begin
						axi_sram_addr <= axi_awaddr_i[9:2];
						axi_sram_wdata <= axi_wdata_i;
						axi_sram_we <= 1'b1;
						d_st <= 2'd1;
					end
					else if ((axi_awvalid_i && axi_wvalid_i) && wt_wr_sel) begin
						axi_acc_region <= axi_awaddr_i[22:20] - 3'd1;
						axi_acc_addr <= axi_awaddr_i[17:2];
						axi_acc_wdata <= axi_wdata_i;
						axi_acc_we <= 1'b1;
						d_st <= 2'd1;
					end
					else if (axi_arvalid_i && log_rd_sel) begin
						d_rdata <= logit_rdata;
						d_st <= 2'd2;
					end
				2'd1:
					if (axi_bready_i)
						d_st <= 2'd0;
				2'd2:
					if (axi_rready_i)
						d_st <= 2'd0;
				default: d_st <= 2'd0;
			endcase
		end
	reg [1:0] l_st;
	reg [15:0] l_idx;
	reg ld_acc_we;
	reg [15:0] ld_acc_addr;
	reg [31:0] ld_acc_wdata;
	wire ld_active;
	assign ld_active = l_st != 2'd0;
	always @(posedge clk_i or negedge rst_ni)
		if (!rst_ni) begin
			l_st <= 2'd0;
			l_idx <= 16'd0;
			ld_acc_we <= 1'b0;
			ld_acc_addr <= 16'd0;
			ld_acc_wdata <= 32'd0;
			acc_start <= 1'b0;
		end
		else begin
			ld_acc_we <= 1'b0;
			acc_start <= 1'b0;
			case (l_st)
				2'd0:
					if (yz_start) begin
						l_idx <= 16'd0;
						l_st <= 2'd1;
					end
				2'd1: l_st <= 2'd2;
				2'd2: begin
					ld_acc_we <= 1'b1;
					ld_acc_addr <= l_idx;
					ld_acc_wdata <= {24'h000000, sram_dout[7:0]};
					if (l_idx == N_IN_M1)
						l_st <= 2'd3;
					else begin
						l_idx <= l_idx + 16'd1;
						l_st <= 2'd1;
					end
				end
				2'd3: begin
					acc_start <= 1'b1;
					l_st <= 2'd0;
				end
				default: l_st <= 2'd0;
			endcase
		end
	always @(*) begin
		if (_sv2v_0)
			;
		if (ld_active) begin
			sram_csb = 1'b0;
			sram_web = 1'b1;
			sram_wmask = 4'b0000;
			sram_addr = l_idx[7:0];
			sram_din = 32'd0;
		end
		else if (axi_sram_we) begin
			sram_csb = 1'b0;
			sram_web = 1'b0;
			sram_wmask = 4'b1111;
			sram_addr = axi_sram_addr;
			sram_din = axi_sram_wdata;
		end
		else begin
			sram_csb = 1'b1;
			sram_web = 1'b1;
			sram_wmask = 4'b0000;
			sram_addr = 8'd0;
			sram_din = 32'd0;
		end
	end
	always @(*) begin
		if (_sv2v_0)
			;
		if (ld_active) begin
			acc_mem_we = ld_acc_we;
			acc_mem_region = 3'd0;
			acc_mem_addr = ld_acc_addr;
			acc_mem_wdata = ld_acc_wdata;
		end
		else begin
			acc_mem_we = axi_acc_we;
			acc_mem_region = axi_acc_region;
			acc_mem_addr = axi_acc_addr;
			acc_mem_wdata = axi_acc_wdata;
		end
	end
	assign axi_awready_o = (csr_wr_sel ? c_awready : d_awready);
	assign axi_wready_o = (csr_wr_sel ? c_wready : d_wready);
	assign axi_bvalid_o = (csr_wr_sel ? c_bvalid : d_bvalid);
	assign axi_bresp_o = (csr_wr_sel ? c_bresp : 2'b00);
	assign axi_arready_o = (csr_rd_sel ? c_arready : d_arready);
	assign axi_rvalid_o = (csr_rd_sel ? c_rvalid : d_rvalid);
	assign axi_rdata_o = (csr_rd_sel ? c_rdata : d_rdata);
	assign axi_rresp_o = (csr_rd_sel ? c_rresp : 2'b00);
	initial _sv2v_0 = 0;
endmodule
