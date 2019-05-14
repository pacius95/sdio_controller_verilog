`timescale 1ns / 1ps
`include "define.vh"
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02.05.2019 12:52:42
// Design Name: 
// Module Name: tb_sd_top
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


module tb_sd_top();

parameter WB_TCLK = 10; // 50 MHz -> timescale 1ns
parameter SD_TCLK = 20; // 50 MHz -> timescale 1ns

  
reg wb_clk_i;
reg wb_rst_i;
reg [31:0] wb_dat_i;
wire [31:0] wb_dat_o;
reg [7:0] wb_adr_i;    
reg wb_we_i;
reg wb_cyc_i;
reg wb_stb_i;
wire wb_ack_o;

wire sd_cmd;
wire [7:0] sd_dat;
wire sd_clk_o;
reg sd_clk_i;

always
    begin
        wb_clk_i<=1;
        forever #(WB_TCLK/2) wb_clk_i = ~wb_clk_i;
    end
always
      begin
         sd_clk_i<=1;
         forever #(SD_TCLK/2) sd_clk_i = ~sd_clk_i;
     end
    
sd_top sd_top_dut(
	.wb_clk_i(wb_clk_i), 
	.wb_rst_i(wb_rst_i), 
	.wb_dat_i(wb_dat_i), 
	.wb_dat_o(wb_dat_o),
	.wb_adr_i(wb_adr_i), 
	.wb_we_i(wb_we_i), 
	.wb_cyc_i(wb_cyc_i), 
	.wb_stb_i(wb_stb_i), 
	.wb_cti_i(0),
	.wb_bte_i(0),
	.wb_ack_o(wb_ack_o),
	.wb_err_o(0),
	.wb_rty_o(0),
	.sd_cmd(sd_cmd),
	.sd_dat(sd_dat), 
	.sd_clk_o(sd_clk_o),
	.sd_clk_i(sd_clk_i)
    );

integer test_mem[0:31] = {
        32'h01234567, 32'h12345678, 32'h23456789, 32'h3456789a, 32'h456789ab, 32'h56789abc, 32'h6789abcd, 32'h789abcde,
        32'h89abcdef, 32'h9abcdef0, 32'habcdef01, 32'hbcdef012, 32'hcdef0123, 32'hdef01234, 32'hef012345, 32'hf0123456,
        32'h00010203, 32'h04050607, 32'h08090a0b, 32'h0c0d0e0f, 32'h10111213, 32'h14151617, 32'h18191a1b, 32'h1c1d1e1f,
        32'h20212223, 32'h24252627, 32'h28292a2b, 32'h2c2d2e2f, 32'h30313233, 32'h34353637, 32'h38393a3b, 32'h3c3d3e3f
    };
integer wb_word_cnt;
integer write_fifo;
integer read_fifo;
integer read_word;
integer wb_idx;


//DMA        
always @(posedge wb_clk_i) begin
    if (write_fifo) begin
		wb_write(`SDIO_FIFO,test_mem[wb_idx]);
		if (wb_idx == 31)
			wb_idx = 0;
		else
			wb_idx++;
		#(WB_TCLK);     		
    end
    else if (read_fifo) begin
		if (wb_cyc_i & wb_stb_i & !wb_we_i) begin
    		if (wb_ack_o) begin
				read_word <= wb_dat_o;		
    			wb_cyc_i <= 0;
    			wb_stb_i <= 0;
    			wb_we_i <= 0;
    		end
    	end
   	 	else begin
    		wb_cyc_i <= 1;
    		wb_stb_i <= 1;
    		wb_we_i <= 0;
    		wb_adr_i <= `SDIO_FIFO;
    	end
    end
end
  
task wb_write;
	input [31:0] wb_adr;
	input [31:0] wb_dat;
		wb_adr_i <= wb_adr;
		wb_we_i <= 1;
		wb_cyc_i <= 1;
		wb_stb_i <= 1;
		wb_dat_i <= wb_dat;
		wait(wb_ack_o);
	    #(WB_TCLK);
		wb_stb_i <= 0;
		wait(!wb_ack_o);
	    #(WB_TCLK);	
endtask

task wb_read;
	input [31:0] wb_adr;
		wb_adr_i <= wb_adr;
		wb_we_i <= 0;
		wb_cyc_i <= 1;
		wb_stb_i <= 1;
		wait(wb_ack_o);
	    #(WB_TCLK);
		wb_stb_i <= 0;
		wait(!wb_ack_o);
	    #(WB_TCLK);	
endtask  

    initial
    begin
    	wb_idx=0;
        wb_rst_i <= 1;
        wb_dat_i <= 0;
        wb_adr_i <= 0;
        wb_we_i <= 0;
        wb_cyc_i <= 0;
        wb_stb_i <= 0;
		#(5*WB_TCLK);
        wb_rst_i <= 0;
        #(5*WB_TCLK);
        
        
        wb_write(`SDIO_POWER,32'h00000003); 
        #(5*SD_TCLK);     
        wb_write(`SDIO_CLKCR,{22'b0,1'b1,10'b0});
        #(5*SD_TCLK);       
        wb_write(`SDIO_ARG,32'hFDFDFDFD);     
        wb_write(`SDIO_CMD,{21'b0,1'b1,2'b0,1'b0,1'b0,6'b101100});



	

        #(100*WB_TCLK);        
        wb_read(`SDIO_STA);
        
     
        wb_read(`SDIO_RESP1);
        
        
        wb_write(`SDIO_CLKCR,{19'b0,2'b10,1'b1,10'b0});
        wb_write(`SDIO_DLEN,32'd128);
        wb_write(`SDIO_DTIMER,32'd64);
        wb_write(`SDIO_DCTRL,{$clog2(128),4'b0001});
         
        write_fifo=1;
        
        #(100*WB_TCLK);        

                   //data_send
        
        #(100*WB_TCLK) $display("sd_data_serial_host_tb finish ...");
        $finish;   
     
	end   
endmodule
