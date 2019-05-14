`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01.03.2019 10:15:33
// Design Name: 
// Module Name: tb_sd_dpsm
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

`define RXACT 13 //receive in act -> set to 1
`define TXACT 12 //transmit in act -> set to 1
`define DBCKEND 10 //Data block sent/received -> 1 (CRC check passed)
`define STBITERR 9 //Start Bit not detected on data signals -> 1
`define DATAEND 8 //No more data to send, counter is zero
`define DTIMEOUT 3 //Data timeout error
`define DCRCFAIL 1 //Data block sent/received (CRC fail) 


module tb_sd_dpsm();

    parameter SD_TCLK = 20; // 50 MHz -> timescale 1ns
    parameter DATA_IDLE = 8'hff;
    parameter DATA_START = 8'h00;
    parameter DATA_END = 8'hff;

reg sd_clk, rst;

reg [31:0] sd_clkcr;
reg [31:0] sd_dlen;
reg [31:0] sd_dctrl;
reg [31:0] sd_dtimer;
wire [31:0] sd_status, sd_dcount, sd_fifocnt;
wire dat_oe;
wire [7:0] dat_out;
reg [7:0] dat_in;
wire [31:0] fifo_dat_o;
wire fifo_rd;
reg [31:0] fifo_dat_i;
wire fifo_wr;
reg [31:0] counter;
wire [7:0]dat_tri;
reg fifo_empty;


reg [1:0] fifo_idx = 0;
integer fifo_send_data[0:3] = {32'h12345678, 32'haabbccdd, 32'h9abcdef0, 32'h55aacc33};
integer fifo_send_data_reverse[0:3] = {32'h78563412, 32'hddccbbaa, 32'hf0debc9a, 32'h33ccaa55};
integer fifo_receive_data[0:3] = {32'h00010203, 32'ha0a1a2a3, 32'hdeadbeef, 32'hbad00dad};
integer fifo_receive_data_reverse[0:3] = {32'h03020100, 32'ha3a2a1a0, 32'hefbeadde, 32'had0dd0ba};

assign dat_tri = dat_oe ? dat_out : dat_in;

function [7:0] get_width_bits;
    input [7:0] data;
    input integer bits;
    begin
        if (bits == 1)
            get_width_bits = {7'b1111111, data[0]};
        else if (bits == 4)
            get_width_bits = {4'b1111,data[3:0]};
        else
            get_width_bits = data[7:0];
    end
endfunction

function integer crc16;
    input integer crc_in;
    input bit inb;
    begin
        inb = inb ^ crc_in[0];
        crc16 = crc_in >> 1;
        crc16 = crc16 ^ (16'h8408 & {16{inb}});
    end
endfunction

task sd_card_send;
    input integer bytes;
    input integer blocks;
    input integer width;
    input bit crc_failure;
    integer cycles;
    integer i, j;
    integer data_idx;
    integer shift;
    integer crc[7:0];
    reg [7:0] crc_out;
    begin
        assert(width == 1 || width == 4 || width == 8) else $stop;
        while (blocks) begin
            cycles = bytes*8/width;
            crc = {0, 0, 0, 0, 0, 0, 0, 0};
            //start bits
            dat_in <= get_width_bits(DATA_START, width);
            #SD_TCLK;
            //data bits
            for (i=0; i<cycles; i++) begin
                data_idx = (i*width/32)%$size(fifo_receive_data);
                shift = (32-width)-((i*width)%32);
                dat_in <= get_width_bits(fifo_receive_data[data_idx] >> shift, width);
                #SD_TCLK;
                for (j=0; j<8; j++)
                    crc[j] = crc16(crc[j], dat_in[j]);
            end
            //crc bits
            for (i=0; i<16; i++) begin
                for (j=0; j<7; j++)
                    crc_out[j] = crc[j] >> i;
                dat_in <= get_width_bits(crc_failure ? 0 : crc_out, width);
                #SD_TCLK;
            end
            //stop bits
            dat_in <= get_width_bits(DATA_END, width);
            #SD_TCLK;
            dat_in <= get_width_bits(DATA_IDLE, width);
            #(2*SD_TCLK);
            assert(sd_status[`DBCKEND] == 1);
            #(SD_TCLK);
            assert(sd_status[`DCRCFAIL] == crc_failure);
            if (blocks == 1)
            	assert(en_rx == 0);
            else 
            	assert(en_rx == 1);
            blocks--;
        end
    end
endtask

task sd_card_receive;
    input integer bytes;
    input integer blocks;
    input integer width;
    input [2:0] crc_status;
    integer cycles;
    integer i, j;
    integer received_data;
    integer data_idx;
    integer shift;
    integer crc[7:0];
    integer crc_in[7:0];
    //reg [3:0] crc_out;
    begin
        assert(width == 1 || width == 4 || width == 8) else $stop;
        cycles = bytes*8/width;
        
        while(blocks) begin
            received_data = 0;
            crc = {0, 0, 0, 0, 0, 0, 0, 0};
            crc_in = {0, 0, 0, 0, 0, 0, 0, 0};
            //wait for start bits
            wait (dat_out == get_width_bits(DATA_START, width));
            assert(dat_oe == 1);
			#SD_TCLK;
            //data bits
            for (i=0; i<cycles; i++) begin
                #SD_TCLK;
                shift = (32-width)-((i*width)%32);
                for (j=0; j<width; j++)
                    received_data[shift+j] = dat_out[j];
                assert(dat_oe == 1);
                if ((i*width)%32 == (32-width)) begin
                    data_idx = (i*width/32)%$size(fifo_send_data);
                    assert(fifo_send_data_reverse[data_idx] == received_data);
                end
                for (j=0; j<width; j++)
                    crc[j] = crc16(crc[j], dat_out[j]);
            end
            //crc bits
            for (i=0; i<16; i++) begin
                #SD_TCLK;
                assert(dat_oe == 1);
                for (j=0; j<width; j++)
                    crc_in[j][i] = dat_out[j];
            end
            for (i=0; i<width; i++)
                assert(crc_in[i] == crc[i]);
            //stop bits
            #SD_TCLK;
            assert(dat_oe == 1);
            assert(dat_out == DATA_END);
            #SD_TCLK;
            assert(dat_oe == 0);
            #(2*SD_TCLK);
            //crc status
            //start bit
            dat_in <= get_width_bits(DATA_START, 1);
            #SD_TCLK;
            //crc status bits
            for (i=0; i<$size(crc_status); i++) begin
                dat_in <= {7'b1111111, crc_status[i]};
                #SD_TCLK;
            end
            //stop bit
            dat_in <= get_width_bits(DATA_END, 1);
            #SD_TCLK;
            assert(en_tx == 1);
            //busy bit
            dat_in <= {7'b1111111, 1'b0};
            #(2*SD_TCLK);
            if (blocks)
                assert(en_tx == 1);
            if (crc_status == 3'b010)
                assert(sd_status[`DCRCFAIL] == 0);
            else
                assert(sd_status[`DCRCFAIL] == 1);
            #(10*SD_TCLK);
            dat_in <= DATA_IDLE;
            blocks--;
        end
        #SD_TCLK;
    end
endtask

task check_fifo_write;
    input integer bytes;
    input integer blocks;
    input integer width;
    integer cycles, i, j;
    begin
        assert(width == 1 || width == 4 || width == 8) else $stop;
        cycles = bytes/4;
        while (blocks) begin
            wait (fifo_wr == 1);
            #(SD_TCLK/2);
            assert(fifo_dat_o == fifo_receive_data_reverse[0]);
            for (i=1; i<cycles; i++) begin
                for (j=0; j<32/width-1; j++) begin
                    #SD_TCLK;
                    assert(fifo_wr == 0);
                end
                #SD_TCLK;
                assert(fifo_wr == 1);
                assert(fifo_dat_o == fifo_receive_data_reverse[i%$size(fifo_receive_data)]);
            end
            blocks--;
            #SD_TCLK;
        end
    end
endtask

task check_fifo_read;
    input integer bytes;
    input integer blocks;
    input integer width;
    integer cycles, i, j;
    begin
        assert(width == 1 || width == 4 || width == 8) else $stop;
        cycles = bytes/4;
        while (blocks) begin
            wait (fifo_rd == 1);
            assert(fifo_rd == 1);
            //read delay !!!
            #(SD_TCLK);
            fifo_dat_i <= fifo_send_data[1];
            for (i=2; i<cycles+1; i++) begin
                for (j=0; j<32/width-1; j++) begin
					#(SD_TCLK);
					assert(fifo_rd == 0);
                end
                #(SD_TCLK);
                assert(fifo_rd == 1);
                fifo_dat_i <= fifo_send_data[i%$size(fifo_send_data)];
            end
            #SD_TCLK;
            assert(fifo_rd == 0);
            fifo_dat_i <= fifo_send_data[0];
            blocks--;
        end
    end
endtask

task read_test;
    input integer block_length;
    input integer block_count;
    input integer width;
    input bit crc_failure;
    begin
        sd_clkcr <= { 19'b0,width>>2,11'b0};
        sd_dlen <= block_length*block_count;
        sd_dctrl <= {$clog2(block_length),4'b0011}; //read
        sd_dtimer <= {32'd64};
        fifo_empty = 1;
        
        #(21*SD_TCLK);
        
        fork
            sd_card_send(block_length, block_count, width, crc_failure);
            check_fifo_write(block_length, block_count, width);
        join
        
		sd_dctrl <= {$clog2(block_length),4'b0010}; //read
        #SD_TCLK;
        assert(en_rx == 0);
    end
endtask

task write_test;
    input integer block_length;
    input integer block_count;
    input integer width;
    input bit crc_failure;
    begin
		fifo_empty = 0;
        sd_clkcr <= { 19'b0,width>>2,11'b0};
        sd_dlen <= block_length*block_count;
        sd_dtimer <= {32'd64};
		sd_dctrl <= {$clog2(block_length),4'b0001}; //write
		#SD_TCLK;
        
        fork
            check_fifo_read(block_length, block_count, width);
            sd_card_receive(block_length, block_count, width, crc_failure ? 3'b101 : 3'b010);
        join
        
        sd_dctrl <= {$clog2(block_length),4'b0000}; //write
        #(2*SD_TCLK);
        assert(en_tx == 0);
    end
endtask
    sd_dpsm sd_dpsm_dut(
     .sd_clk(sd_clk),
     .rst(rst),
     .sd_clkcr(sd_clkcr),
     .sd_dlen(sd_dlen), 
     .sd_dctrl(sd_dctrl), 
     .sd_dtimer(sd_dtimer),
     .sd_status(sd_status),
     .sd_dcount(sd_dcount), 
     .sd_fifocnt(sd_fifocnt), 
     .dat_oe(dat_oe), 
     .dat_out(dat_out),
     .dat_in(dat_in),
     .fifo_dat_o(fifo_dat_o),
     .fifo_rd(fifo_rd),
     .fifo_dat_i(fifo_dat_i),
     .fifo_wr(fifo_wr),
     
     .en_rx(en_rx),
     .en_tx(en_tx),
     .fifo_full(1'b0),
     .fifo_empty(fifo_empty)
    );

    // sd_fifo_filler sd_fifo_filler_dut(
    //     .wb_clk    (wb_clk),
    //     .rst       (rst),
    //     .wb_adr_s2m (wbm_adr_o),
    //     .wb_we_s2m  (wbm_we_o),
    //     .wb_dat_s2m (wbm_dat_o),
    //     .wb_dat_m2s (wbm_dat_i),
    //     .wb_cyc_s2m (wbm_cyc_o),
    //     .wb_stb_s2m (wbm_stb_o),
    //     .wb_ack_m2s (wbm_ack_i),
    //     .en_rx   (en_rx_i),
    //     .en_tx   (en_tx_i),
    //     .adr_i     (adr_i),
    //     .sd_clk    (sd_clk),
    //     .dat_i     (dat_i),
    //     .dat_o     (dat_o),
    //     .wr_i      (wr_i),
    //     .rd_i      (rd_i),
    //     .sd_empty_o   (sd_empty_o),
    //     .sd_full_o   (sd_full_o),
    //     .wb_empty_o   (wb_empty_o),
    //     .wb_full_o    (wb_full_o)
    // );

    always
    begin
        sd_clk<=1'b1;
        forever #(SD_TCLK/2) sd_clk = ~sd_clk;
    end
    

 initial
begin
    rst = 1;
    dat_in = DATA_IDLE;
    fifo_dat_i = fifo_send_data[0];
    sd_clkcr = 0;
    sd_dlen = 0;
    sd_dctrl = 0;
    sd_dtimer = 64;

    $display("sd_data_serial_host_tb start ...");
    
    #(3*SD_TCLK);
    rst = 0;

    assert(fifo_rd == 0);
    assert(fifo_wr == 0);
    assert(dat_oe == 0);
    
    #(3*SD_TCLK);
    
    //tests with 1-bit mode and 4-bit mode
    //single block read and single block write
    //multiple block read and multiple block write
    //test with bad crc (wrong crc during read, wrong rcr in response)
    
    ///////////////////////////////////////////////////////////////
    //1-bit single block read
    read_test(16, 1, 1, 0);
    
    ///////////////////////////////////////////////////////////////
    //1-bit single block write
    #(6*SD_TCLK);
    write_test(16, 1, 1, 0);
    
    ///////////////////////////////////////////////////////////////
    //1-bit multiple block read  
    #(6*SD_TCLK);
    read_test(32, 3, 1, 0);
    
    ///////////////////////////////////////////////////////////////
    //1-bit multiple block write
    #(6*SD_TCLK);
    write_test(16, 8, 1, 0);
    
    ///////////////////////////////////////////////////////////////
    //              4 - bit
    ///////////////////////////////////////////////////////////////
    //4-bit single block read
    #(6*SD_TCLK);
    read_test(256, 1, 4, 0);
    
    ///////////////////////////////////////////////////////////////
    //4-bit single block write
    #(6*SD_TCLK);
    write_test(512, 1, 4, 0);   
    
    ///////////////////////////////////////////////////////////////
    //4-bit multiple block read
    #(6*SD_TCLK);
    read_test(8, 17, 4, 0);
    
    ///////////////////////////////////////////////////////////////
    //4-bit multiple block write
    #(6*SD_TCLK);
    write_test(4, 32, 4, 0);
    
 
        #(6*SD_TCLK);
        write_test(4, 32, 8, 0);
          
    //////////////////////////////////////////////////////////////
    //      TODO: xfer stopped in the middle
    
    #(100*SD_TCLK) $display("sd_data_serial_host_tb finish ...");
    $finish;
    
end

endmodule
