//////////////////////////////////////////////////////////////////////
////                                                              ////
//// WISHBONE SD Card Controller IP Core                          ////
////                                                              ////
//// sd_fifo_filler.v                                             ////
////                                                              ////
//// This file is part of the WISHBONE SD Card                    ////
//// Controller IP Core project                                   ////
//// http://opencores.org/project,sd_card_controller              ////
////                                                              ////
//// Description                                                  ////
//// Fifo interface between sd card and wishbone clock domains    ////
//// and DMA engine eble to write/read to/from CPU memory         ////
////                                                              ////
//// Author(s):                                                   ////
////     - Marek Czerski, ma.czerski@gmail.com                    ////
////                                                              ////
//////////////////////////////////////////////////////////////////////
////                                                              ////
//// Copyright (C) 2013 Authors                                   ////
////                                                              ////
//// Based on original work by                                    ////
////     Adam Edvardsson (adam.edvardsson@orsoc.se)               ////
////                                                              ////
////     Copyright (C) 2009 Authors                               ////
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

module sd_fifo_filler(
           input wb_clk,
           input rst,
           //WB Signals
           input [31:0] wb_adr_m2s,
           input wb_we_m2s,
           input [31:0] wb_dat_m2s,
           output [31:0] wb_dat_s2m,
           input wb_cyc_m2s,
           input wb_stb_m2s,
           output reg wb_ack_s2m,
           //Data Master Control signals
           input en_rx,
           input en_tx,

           //Data Serial signals
           input sd_clk,
           input [31:0] dat_i,
           output [31:0] dat_o,
           input wr_i,
           input rd_i,
           output sd_full_o,
           output sd_empty_o,
           output wb_full_o,
           output wb_empty_o
       );

`define FIFO_MEM_ADR_SIZE 5 //32 words

wire reset_fifo;

neg_edge_detector neg_edge_detector_cmdact(
	.sig(en_tx | en_rx),.clk(wb_clk), .pe(reset_fifo) 
	);
	
//receive fifo
generic_fifo_dc_gray #(
    .dw(32), 
    .aw(`FIFO_MEM_ADR_SIZE)
    ) generic_fifo_dc_gray0 (
    .rd_clk(wb_clk),
    .wr_clk(sd_clk), 
    .rst(!(rst | reset_fifo)), 
    .clr(1'b0), 
    .din(dat_i), 
    .we(wr_i),
    .dout(wb_dat_s2m), 
    .re(en_rx & wb_cyc_m2s & wb_ack_s2m & !wb_we_m2s & !wb_empty_o), 
    .full(sd_full_o), 
    .empty(wb_empty_o), 
    .wr_level(), 
    .rd_level() 
    );
    
//transfer fifo
generic_fifo_dc_gray #(
    .dw(32), 
    .aw(`FIFO_MEM_ADR_SIZE)
    ) generic_fifo_dc_gray1 (
    .rd_clk(sd_clk),
    .wr_clk(wb_clk), 
    .rst(!(rst | reset_fifo)), 
    .clr(1'b0), 
    .din(wb_dat_m2s), 
    .we(en_tx & wb_cyc_m2s & wb_stb_m2s & wb_we_m2s & wb_ack_s2m & !wb_full_o),
    .dout(dat_o), 
    .re(rd_i), 
    .full(wb_full_o), 
    .empty(sd_empty_o), 
    .wr_level(), 
    .rd_level() 
    );
    

always @(posedge wb_clk or posedge rst)
begin

	if ((en_tx | en_rx) & wb_cyc_m2s & wb_stb_m2s & !wb_ack_s2m & ((!wb_full_o & wb_we_m2s) | (!wb_empty_o & !wb_we_m2s)))
		wb_ack_s2m <= 1;
	else 
		wb_ack_s2m <= 0;
		
end
endmodule


