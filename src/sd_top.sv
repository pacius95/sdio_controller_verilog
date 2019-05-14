`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02.05.2019 12:52:42
// Design Name: 
// Module Name: sd_top
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module sd_top(
	// WISHBONE common
	wb_clk_i, 
	wb_rst_i, 
	// WISHBONE slave
	wb_dat_i, 
	wb_dat_o,
	wb_adr_i, 
	wb_we_i, 
	wb_cyc_i, 
	wb_stb_i, 
	wb_cti_i,
	wb_bte_i,
	wb_ack_o,
	wb_err_o,
	wb_rty_o,
	//SD BUS
	sd_cmd,
	sd_dat, 
	sd_clk_i,
	sd_clk_o
    );
    
input wb_clk_i;
input wb_rst_i; 
input [31:0] wb_dat_i;  
output [31:0] wb_dat_o;
input [7:0] wb_adr_i;
input wb_we_i;
input wb_cyc_i;
input wb_stb_i;
input wb_cti_i;
input wb_bte_i;
output wb_ack_o;
input wb_err_o;
input wb_rty_o;
inout sd_cmd;
inout [7:0] sd_dat;
input sd_clk_i;
output sd_clk_o;

wire [31:0] wb_dat_o_fifo;
wire [31:0] wb_dat_o_if;
wire wb_ack_o_fifo;
wire wb_ack_o_if;

assign wb_dat_o = wb_adr_i[7] ? wb_dat_o_fifo : wb_dat_o_if;
assign wb_ack_o = wb_adr_i[7] ? wb_ack_o_fifo : wb_ack_o_if;


wire sd_clk;

wire sd_cmd_out;
wire sd_cmd_in;
wire sd_cmd_oe;

wire [7:0]sd_dat_out;
wire [7:0]sd_dat_in;
wire sd_dat_oe;

wire sd_rst;

//regs wire
wire [31:0] sd_clkcr_sd_clk;
wire [31:0] sd_arg_sd_clk;
wire [31:0] sd_cmd_sd_clk;
wire [31:0] sd_dlen_sd_clk;
wire [31:0] sd_dctrl_sd_clk;
wire [31:0] sd_dtimer_sd_clk;

wire [31:0] sd_status_sd_clk_cpsm;
wire [31:0] sd_status_sd_clk_dpsm;
wire [31:0] sd_dcount_sd_clk;
wire [31:0] sd_fifocnt_sd_clk;

//regs
wire [31:0] sd_pwr_wb_clk;
wire [31:0] sd_clkcr_wb_clk;
wire [31:0] sd_arg_wb_clk;
wire [31:0] sd_cmd_wb_clk;
wire [31:0] sd_dlen_wb_clk;
wire [31:0] sd_dctrl_wb_clk;
wire [31:0] sd_dtimer_wb_clk;

wire [31:0] sd_status_wb_clk;
wire [31:0] sd_dcount_wb_clk;
wire [31:0] sd_fifocnt_wb_clk;

wire [31:0] sd_clkcr_sd_clk_i;
wire [31:0] sd_pwr_sd_clk_i;

wire rd_wb_wb_clk;
wire [31:0] sd_reg_wb_clk;
wire ack_cpsm_wb_clk;
wire [6:0] adr_in_sd_clk;
wire [6:0] adr_in_wb_clk;
wire rd_wb_sd_clk;
wire [31:0] sd_reg_sd_clk;
wire ack_cpsm_sd_clk;


wire [31:0] fifo_dat_o;
wire fifo_rd;
wire [31:0] fifo_dat_i;
wire fifo_wr;
wire en_tx;
wire en_rx;
wire fifo_full_sd_clk;
wire fifo_empty_sd_clk;
wire fifo_empty_wb_clk;
wire fifo_full_wb_clk;


assign sd_cmd = sd_cmd_oe ? sd_cmd_out : sd_cmd_in;
assign sd_dat = sd_dat_oe ? sd_dat_out : sd_dat_in;

//genvar i;
//generate
//    for(i=0; i<8; i=i+1) begin: sd_dat_assign
//    	assign sd_dat[i] = sd_dat_oe ? sd_dat_out[i] : sd_dat_in[i];
//    end
//endgenerate

sd_clock_divider sd_clock_divider_0 (
			.sd_clk_i (sd_clk_i),
			.sd_clkcr (sd_clkcr_sd_clk_i),
			.sd_pwr (sd_pwr_sd_clk_i),
			.rst  (wb_rst_i),
			.sd_clk  (sd_clk),
			.sd_clk_o (sd_clk_o)
		);
                 
sd_cmd_adapter sd_cmd_adapter_0(
			.sd_clk(sd_clk),
			.rst(wb_rst_i),
			.sd_cmd(sd_cmd_sd_clk),
			.sd_arg(sd_arg_sd_clk),
					
			.adr_in(adr_in_sd_clk),
 			.rd_wb(rd_wb_sd_clk),
			.sd_reg(sd_reg_sd_clk),
			.ack_cpsm(ack_cpsm_sd_clk),
			.sd_status(sd_status_sd_clk_cpsm),
			.cmd_in(sd_cmd_in),
			.cmd_out(sd_cmd_out),
			.cmd_oe(sd_cmd_oe)
		);                 

sd_dpsm sd_dpsm_0(
     		.sd_clk(sd_clk),
	    	.rst(wb_rst_i),
    		.sd_clkcr(sd_clkcr_sd_clk),
	    	.sd_dlen(sd_dlen_sd_clk), 
    		.sd_dctrl(sd_dctrl_sd_clk), 
     		.sd_dtimer(sd_dtimer_sd_clk),
     		.sd_status(sd_status_sd_clk_dpsm),
     		.sd_dcount(sd_dcount_sd_clk), 
     		.sd_fifocnt(sd_fifocnt_sd_clk), 
     		.dat_oe(sd_dat_oe), 
     		.dat_out(sd_dat_out),
     		.dat_in(sd_dat_in),
     		.fifo_dat_o(fifo_dat_o),
     		.fifo_rd(fifo_rd),
     		.fifo_dat_i(fifo_dat_i),
     		.fifo_wr(fifo_wr),
     
     		.en_rx(en_rx),
     		.en_tx(en_tx),
     		.fifo_full(fifo_full_sd_clk),
     		.fifo_empty(fifo_empty_sd_clk)
    	);

sd_fifo_filler sd_fifo_filler_dut(
			.wb_clk    (wb_clk_i),
			.rst       (wb_rst_i),
    	    .wb_adr_m2s (wb_adr_i),
    	    .wb_we_m2s  (wb_we_i),
    	    .wb_dat_m2s (wb_dat_i),
    	    .wb_dat_s2m (wb_dat_o_fifo),
    	    .wb_cyc_m2s (wb_cyc_i),
    	    .wb_stb_m2s (wb_stb_i),
    	    .wb_ack_s2m (wb_ack_o_fifo),
    	    .en_rx   (en_rx),
    	    .en_tx   (en_tx),
    	    .sd_clk    (sd_clk),
    	    .dat_i     (fifo_dat_o),
    	    .dat_o     (fifo_dat_i),
    	    .wr_i      (fifo_wr),
    	    .rd_i      (fifo_rd),
    	    .sd_empty_o   (fifo_empty_sd_clk),
    	    .sd_full_o   (fifo_full_sd_clk),
    	    .wb_empty_o   (fifo_empty_wb_clk),
    	    .wb_full_o    (fifo_full_wb_clk)
    	 );
    	 
wb_interface_slave #(.ADDR_WIDTH(8), .DATA_WIDTH(32), .BASE_ADDRESS(0))
	wb_interface_slave0(
			.clk(wb_clk_i), 
			.rst(wb_rst_i), 
			.dat_m2s(wb_dat_i), 
			.dat_s2m(wb_dat_o_if),
			.cyc_m2s(wb_cyc_i), 
			.stb_m2s(wb_stb_i), 
			.adr_m2s(wb_adr_i), 
			.we_m2s(wb_we_i), 
			.cti_m2s(wb_cti_i), 
			.bte_m2s(wb_bte_i),
    	    .ack_s2m(wb_ack_o_if), 
    	    .err_s2m(wb_err_o), 
    	    .rty_s2m(wb_rty_o),
    	    
    	    .adr_in(adr_in_wb_clk),
    	    .rd_cpsm(rd_wb_wb_clk), 
    	    .ack_cpsm(ack_cpsm_wb_clk),
    	    .dat_cpsm(sd_reg_wb_clk),
    	    
    	    //input regs
    	    .sd_status(sd_status_wb_clk),
    	    .sd_dcount(sd_dcount_wb_clk),
    	    .sd_fifocnt(sd_fifocnt_wb_clk),
    	    
    	    //output regs
    	    .sd_pwr(sd_pwr_wb_clk),
    	    .sd_clkcr(sd_clkcr_wb_clk),
    	    .sd_arg(sd_arg_wb_clk),
    	    .sd_cmd(sd_cmd_wb_clk),
    	    .sd_dlen(sd_dlen_wb_clk),
    	    .sd_dctrl(sd_dctrl_wb_clk),
    	    .sd_dtimer(sd_dtimer_wb_clk)
);    	 
    	     	 
    	 
bistable_domain_cross #(32) sd_clkcr_cross(wb_rst_i, wb_clk_i, sd_clkcr_wb_clk, sd_clk, sd_clkcr_sd_clk);
bistable_domain_cross #(32) sd_arg_cross(wb_rst_i, wb_clk_i, sd_arg_wb_clk, sd_clk, sd_arg_sd_clk);
bistable_domain_cross #(32) sd_cmd_cross(wb_rst_i, wb_clk_i, sd_cmd_wb_clk, sd_clk, sd_cmd_sd_clk);
bistable_domain_cross #(32) sd_dlen_cross(wb_rst_i, wb_clk_i, sd_dlen_wb_clk, sd_clk, sd_dlen_sd_clk);
bistable_domain_cross #(32) sd_dctrl_cross(wb_rst_i, wb_clk_i, sd_dctrl_wb_clk, sd_clk, sd_dctrl_sd_clk);
bistable_domain_cross #(32) sd_dtimer_cross(wb_rst_i, wb_clk_i, sd_dtimer_wb_clk, sd_clk, sd_dtimer_sd_clk);

bistable_domain_cross #(32) sd_dcount_cross(wb_rst_i, sd_clk, sd_dcount_sd_clk, wb_clk_i, sd_dcount_wb_clk);
bistable_domain_cross #(32) sd_fifocnt_cross(wb_rst_i, sd_clk, sd_fifocnt_sd_clk, wb_clk_i, sd_fifocnt_wb_clk);
bistable_domain_cross #(32) sd_status_cross(wb_rst_i, sd_clk, sd_status_sd_clk_cpsm | sd_status_sd_clk_dpsm, wb_clk_i, sd_status_wb_clk);

bistable_domain_cross #(32) sd_clkcr_cross_i(wb_rst_i, wb_clk_i, sd_clkcr_wb_clk, sd_clk_i, sd_clkcr_sd_clk_i);
bistable_domain_cross #(32) sd_pwr_cross_i(wb_rst_i, wb_clk_i, sd_pwr_wb_clk, sd_clk_i, sd_pwr_sd_clk_i);

bistable_domain_cross #(7) adr_in_cross(wb_rst_i, sd_clk, adr_in_wb_clk, wb_clk_i, adr_in_sd_clk);
bistable_domain_cross #(1) rd_wb_cross(wb_rst_i, sd_clk, rd_wb_wb_clk, wb_clk_i, rd_wb_sd_clk);
bistable_domain_cross #(32) sd_reg_cross(wb_rst_i, sd_clk, sd_reg_sd_clk, wb_clk_i, sd_reg_wb_clk);
bistable_domain_cross #(1) ack_cpsm_cross(wb_rst_i, sd_clk, ack_cpsm_sd_clk, wb_clk_i, ack_cpsm_wb_clk);
    	 
endmodule