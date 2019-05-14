`timescale 1ns / 1ps
// //////////////////////////////////////////////////////////////////////////////////
// // Company: 
// // Engineer: 
// // 
// // Create Date: 09.04.2019 18:20:03
// // Design Name: 
// // Module Name: tb_sd_fifo_filler
// // Project Name: 
// // Target Devices: 
// // Tool Versions: 
// // Description:  
// // 
// // Dependencies: 
// // 
// // Revision:
// // Revision 0.01 - File Created
// // Additional Comments:
// // 
// //////////////////////////////////////////////////////////////////////////////////




//////////////////////////////////////////////////////////////////////
////                                                              ////
//// WISHBONE SD Card Controller IP Core                          ////
////                                                              ////
//// sd_fifo_filler_tb.sv                                         ////
////                                                              ////
//// This file is part of the WISHBONE SD Card                    ////
//// Controller IP Core project                                   ////
//// http://opencores.org/project,sd_card_controller              ////
////                                                              ////
//// Description                                                  ////
//// testbench for sd_fifo_filler module                          ////
////                                                              ////
//// Author(s):                                                   ////
////     - Marek Czerski, ma.czerski@gmail.com                    ////
////                                                              ////
//////////////////////////////////////////////////////////////////////
////                                                              ////
//// Copyright (C) 2013 Authors                                   ////
////                                                              ////
//// This source file may be used and distributed without         ////
//// restriction provided that this copyright statement is not    ////
//// removed from the file and that any derivative work contains  ////
//// the original copyright notice and the associated disclaimer. ////
////                                                              ////
//// This source file is free software; you can redistribute it   ////
//// and/or modify it under the terms of the GNU Lesser General   ////
//// Public License as published by the Free Software Foundation; ////
//// either version 2.1 of the License, or (at your option) any   ////
//// later version.                                               ////
////                                                              ////
//// This source is distributed in the hope that it will be       ////
//// useful, but WITHOUT ANY WARRANTY; without even the implied   ////
//// warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR      ////
//// PURPOSE. See the GNU Lesser General Public License for more  ////
//// details.                                                     ////
////                                                              ////
//// You should have received a copy of the GNU Lesser General    ////
//// Public License along with this source; if not, download it   ////
//// from http://www.opencores.org/lgpl.shtml                     ////
////                                                              ////
//////////////////////////////////////////////////////////////////////

module tb_sd_fifo_filler();

parameter WB_TCLK = 20; // 50 MHz -> timescale 1ns
parameter SD_TCLK = WB_TCLK*2; // 25 MHz -> timescale 1ns

reg wb_clk;
reg rst;
reg [31:0] wb_adr_m2s;
reg wb_we_m2s;
reg [31:0] wb_dat_m2s;
wire [31:0] wb_dat_s2m;
reg wb_cyc_m2s;
reg wb_stb_m2s;
wire wb_ack_s2m;
reg en_rx_i;
reg en_tx_i;
reg sd_clk;
reg [31:0] dat_i;
wire [31:0] dat_o;
reg wr_i;
reg rd_i;
wire sd_full_o;
wire sd_empty_o;
wire wb_full_o;
wire wb_empty_o;


//fifo driver helpers
reg fifo_drv_ena;
integer fifo_drv_wait;
integer fifo_drv_wait_counter;
integer fifo_drv_idx;

integer wb_word_cnt;
integer write_fifo;
integer read_fifo;
integer read_word;
integer wb_idx;

//test memory vector
integer test_mem[0:31] = {
        32'h01234567, 32'h12345678, 32'h23456789, 32'h3456789a, 32'h456789ab, 32'h56789abc, 32'h6789abcd, 32'h789abcde,
        32'h89abcdef, 32'h9abcdef0, 32'habcdef01, 32'hbcdef012, 32'hcdef0123, 32'hdef01234, 32'hef012345, 32'hf0123456,
        32'h00010203, 32'h04050607, 32'h08090a0b, 32'h0c0d0e0f, 32'h10111213, 32'h14151617, 32'h18191a1b, 32'h1c1d1e1f,
        32'h20212223, 32'h24252627, 32'h28292a2b, 32'h2c2d2e2f, 32'h30313233, 32'h34353637, 32'h38393a3b, 32'h3c3d3e3f
    };

sd_fifo_filler sd_fifo_filler_dut(
                      .wb_clk    (wb_clk),
                      .rst       (rst),
                      .wb_adr_m2s (wb_adr_m2s),
                      .wb_we_m2s  (wb_we_m2s),
                      .wb_dat_m2s (wb_dat_m2s),
                      .wb_dat_s2m (wb_dat_s2m),
                      .wb_cyc_m2s (wb_cyc_m2s),
                      .wb_stb_m2s (wb_stb_m2s),
                      .wb_ack_s2m (wb_ack_s2m),
                      .en_rx   (en_rx_i),
                      .en_tx   (en_tx_i),
                      .sd_clk    (sd_clk),
                      .dat_i     (dat_i),
                      .dat_o     (dat_o),
                      .wr_i      (wr_i),
                      .rd_i      (rd_i),
                      .sd_empty_o   (sd_empty_o),
                      .sd_full_o   (sd_full_o),
                      .wb_empty_o   (wb_empty_o),
                      .wb_full_o    (wb_full_o)
                  );

// Generating sd_clk clock
always
begin
    sd_clk<=0;
    forever #(SD_TCLK/2) sd_clk = ~sd_clk;
end
// Generating wb_clk clock
always
begin
    wb_clk<=0;
    forever #(WB_TCLK/2) wb_clk = ~wb_clk;
end

//dma master
always @(posedge wb_clk) begin
    if (write_fifo) begin
		if (wb_cyc_m2s & wb_stb_m2s & wb_we_m2s) begin
			if (wb_ack_s2m) begin
				if (wb_idx == 31)
					wb_idx = 0;
				else
					wb_idx++;
			wb_cyc_m2s <= 0;
			wb_stb_m2s <= 0;
			wb_we_m2s <= 0;
			end
		end
		else
		begin
			wb_cyc_m2s <= 1;
			wb_stb_m2s <= 1;
			wb_we_m2s <= 1;
			wb_adr_m2s <= 32'h00000080;
			wb_dat_m2s <= test_mem[wb_idx];
		end
    end
    else if (read_fifo) begin
		if (wb_cyc_m2s & wb_stb_m2s & !wb_we_m2s) begin
    		if (wb_ack_s2m) begin
				read_word <= wb_dat_s2m;		
    			wb_cyc_m2s <= 0;
    			wb_stb_m2s <= 0;
    			wb_we_m2s <= 0;
    		end
    	end
   	 	else begin
    		wb_cyc_m2s <= 1;
    		wb_stb_m2s <= 1;
    		wb_we_m2s <= 0;
    		wb_adr_m2s <= 32'h00000080;
    	end
    end
    else begin
    	wb_cyc_m2s <= 0;
    	wb_stb_m2s <= 0;
    	wb_we_m2s <= 0;
    	wb_adr_m2s <= 0;
    	wb_dat_m2s <= 0;
    end
end
    
//fifo driver
always @(posedge sd_clk)
    if (en_rx_i) begin
        if (fifo_drv_wait == fifo_drv_wait_counter) begin
            wr_i <= 1;
            dat_i <= test_mem[fifo_drv_idx];
            fifo_drv_wait_counter <= 0;
            fifo_drv_idx++;
        end
        else begin
            wr_i <= 0;
            dat_i <= 0;
            fifo_drv_wait_counter++;
        end
    end
    else if (fifo_drv_ena) begin
        if (fifo_drv_wait_counter == 0) begin
            rd_i <= 1;
            assert(dat_o == test_mem[fifo_drv_idx]);
            fifo_drv_wait_counter++;
            fifo_drv_idx++;
        end
        else begin
            rd_i <= 0;
            if (fifo_drv_wait_counter == fifo_drv_wait)
                fifo_drv_wait_counter <= 0;
            else
                fifo_drv_wait_counter++;
        end
    end
    else begin
        wr_i <= 0;
        rd_i <= 0;
        fifo_drv_idx = 0;
        fifo_drv_wait_counter <= 0;
    end

initial
begin
    rst = 1;
    fifo_drv_wait = 0;
    fifo_drv_ena = 0;
    en_rx_i = 0;
    en_tx_i = 0;
    dat_i = 0;
    wr_i = 0;
    rd_i = 0;
    read_fifo = 0;
    write_fifo = 0;
    wb_idx = 0;
    $display("sd_fifo_filler_tb finish ...");
    
    #(3*WB_TCLK);
    rst = 0;
    assert(wb_full_o == 0);
    #(3*WB_TCLK);
    assert(wb_full_o == 0);
    assert(sd_empty_o == 1);
    
    //check normal operation
    en_rx_i = 1;
    read_fifo = 1;
    fifo_drv_wait = 7;
    
    #(100*WB_TCLK);
    en_rx_i = 0;
    #SD_TCLK;

    #(20*WB_TCLK);  
    read_fifo = 0;  
    assert(wb_full_o == 0);
    
    //fill almost fuul fifo then burst write
	rst = 1;
    #(3*WB_TCLK);
    rst = 0;
    assert(wb_full_o == 0);
    #(3*WB_TCLK);
    assert(wb_full_o == 0);
    assert(sd_empty_o == 1);
    
    //check normal operation but late dma activation
    en_rx_i = 1;
    fifo_drv_wait = 5;
    
    #(100*WB_TCLK);
    read_fifo = 1;
    #(100*WB_TCLK);
    en_rx_i = 0;
    read_fifo = 0;
    #(4*SD_TCLK);

//////////////////////////////////////////////////////////////
    //check fifo fill
    en_tx_i = 1;
    write_fifo = 1;
    wait(wb_full_o == 1);
    assert(sd_empty_o == 0);
    fifo_drv_wait = 7;
    fifo_drv_ena = 1;
    #(40*WB_TCLK);
    write_fifo = 0;
    
    wait(sd_empty_o == 1);
    en_tx_i = 0;
    fifo_drv_ena = 0;
    assert(wb_full_o == 0);

    #(10*WB_TCLK) $display("sd_fifo_filler_tb finish ...");
    $finish;
    
end

endmodule