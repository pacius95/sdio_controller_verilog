//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 18.12.2018 13:01:12
// Design Name: 
// Module Name: tb_sd_cmd_adapter
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
`timescale 1ns / 1ps
`include "define.vh"


module tb_sd_cmd_adapter();

parameter SD_TCLK = 20; // 50 MHz -> timescale 1ns
parameter CMD_IDLE = 1'b1;
parameter CMD_START = 1'b0;
parameter CMD_END = 1'b1;


reg sd_clk, rst;
reg [31:0] sd_cmd;
reg [31:0] sd_arg;
wire [31:0] sd_status;

reg [6:0] adr_in;
reg rd_wb;
wire [31:0] sd_reg;
wire ack_cpsm;

reg cmd_in;
wire cmd_oe, cmd_out;
wire cmd_tri;



assign cmd_tri = cmd_oe ? cmd_out : cmd_in;


always begin
    sd_clk <= 1;
    forever #(SD_TCLK/2) sd_clk = ~sd_clk;
end


 sd_cmd_adapter
    sd_cmd_adapter_dut(
     .sd_clk(sd_clk),
     .rst(rst),
     .sd_cmd(sd_cmd),
     .sd_arg(sd_arg),

	 .adr_in(adr_in),
	 .rd_wb(rd_wb),
	 .sd_reg(sd_reg),
	 .ack_cpsm(ack_cpsm),
     .sd_status(sd_status),
     .cmd_in(cmd_in),
     .cmd_out(cmd_out),
     .cmd_oe(cmd_oe)
    );

wire [39:0] command = 40'h4f23456786;
wire [127:0] response = 128'h0f56789abcdef0123456789abcdef012;


function integer crc7;
    input integer crc_in;
    input bit inb;
    begin
        inb = inb ^ crc_in[0];
        crc7 = crc_in >> 1;
        crc7 = crc7 ^ (7'h48 & {7{inb}});
    end
endfunction

task sd_card_receive;
    integer crc, i;
    reg [39:0] cmd;
    reg [6:0] crc_in;
    begin
        crc = 0;
        //wait for transmission start
        wait (cmd_out == 0);
		#SD_TCLK;
        for (i=39; i>=0; i--) begin
            cmd[i] = cmd_out;
            crc = crc7(crc, cmd_out);
            assert(cmd_oe == 1);
            #SD_TCLK;
        end
        assert(cmd == command);
        for (i=0; i<7; i++) begin
            crc_in[i] = cmd_out;
            assert(cmd_oe == 1);
            #SD_TCLK;
        end
        assert(crc_in == crc);
        assert(cmd_out == CMD_END);
        assert(cmd_oe == 1);
        #SD_TCLK;
        assert(cmd_oe == 0);
    end
endtask

task sd_card_send;
    input long_resp;
    integer crc, i, loop_end;
    begin
        crc = 0;
        cmd_in <= 0;
        #SD_TCLK;
        cmd_in <= 0;
        #SD_TCLK;
        for (i=0; i<6; i++) begin
            cmd_in <= i; //index
            if (!long_resp)
            	crc = crc7(crc, i);
            assert(cmd_oe == 0);
            #SD_TCLK;
        end
        if (long_resp) loop_end = 127-119;
        else loop_end = 127-31;
        for (i=127; i>=loop_end; i--) begin
            cmd_in <= response[i];
			crc = crc7(crc, response[i]);        
            assert(cmd_oe == 0);
            #SD_TCLK;
        end
        for (i=0; i<7; i++) begin
            cmd_in <= crc[i];
            assert(cmd_oe == 0);
            #SD_TCLK;
        end
        cmd_in <= CMD_END;
        assert(cmd_oe == 0);
        #SD_TCLK;
        cmd_in <= CMD_IDLE;
    end
endtask
    

initial
begin
    rst = 1;
    sd_cmd <= 0;
    sd_arg <= 0;
    //ack_i = 0;
    cmd_in <= CMD_IDLE;
    
    $display("sd_cmd_serial_host_tb start ...");
    
    #(3*SD_TCLK);
    rst = 0;
    assert(sd_status[`CMDACT] == 0); 
    assert(cmd_oe == 0);
    #SD_TCLK;
    assert(sd_status[`CMDACT] == 0); 
    assert(cmd_oe == 0);
    #(4*SD_TCLK); //INIT_DELAY
    assert(sd_status[`CMDACT] == 0); 
    assert(cmd_oe == 0);
    
    //tests with normal response (check index, check crc)
    //tests with long response (check crc)
    
    //cmd without response
    sd_cmd <= {21'b0,1'b1,2'b0,1'b0,1'b0,command[37:32]};
    sd_arg <= command[31:0];
    #SD_TCLK;


    
    fork
        sd_card_receive;
        begin
            wait(sd_status[`CMDSENT] == 1);
            #(SD_TCLK/2);
            assert(sd_status[`CCRCFAIL] == 0);
            assert(sd_status[`CTIMEOUT] == 0);
            #(SD_TCLK/2);
        end
    join

    //cmd with short response

    rst = 1; 
    sd_cmd <= 0;
    sd_arg <= 0;   
    #SD_TCLK;
    rst = 0;
    #SD_TCLK;
    assert(sd_status[`CMDACT] == 0); 
    assert(cmd_oe == 0);

    #(4*SD_TCLK);
    sd_cmd <= {21'b0,1'b1,2'b0,1'b0,1'b1,command[37:32]};
    sd_arg <= command[31:0];
    #SD_TCLK;

    fork
        begin
            sd_card_receive;
            assert(sd_status[`CMDSENT] == 0);
            #(3*SD_TCLK);
            sd_card_send(0);
        end
        begin
            wait(sd_status[`CMDREND] == 1);
            #(SD_TCLK/2);
            assert(sd_status[`CCRCFAIL] == 0);
            assert(sd_status[`CMDACT] == 0);
            #(SD_TCLK/2);
            adr_in <= `SDIO_RESP1;
            rd_wb <= 1;
            #(SD_TCLK);
            wait(ack_cpsm);
            assert(response[127:96] == sd_reg);
            #(SD_TCLK);
            adr_in <= `SDIO_RESP1;
            rd_wb <= 0;
        end
    join
    

// long response todo either here and on the cpsm
    
    rst = 1;    
    #SD_TCLK;
    rst = 0;
    #SD_TCLK;
    assert(sd_status[`CMDACT] == 0); 
    assert(cmd_oe == 0);

    #(4*SD_TCLK);
    sd_cmd <= {21'b0,1'b1,2'b0,1'b1,1'b1,command[37:32]};
    sd_arg <= command[31:0];
    #SD_TCLK;


    fork
        begin
            sd_card_receive;
            assert(sd_status[`CMDSENT] == 0);
            #(3*SD_TCLK);
            sd_card_send(1);
        end
        begin
            wait(sd_status[`CMDREND] == 1);
        	#(SD_TCLK/2);
        	assert(sd_status[`CCRCFAIL] == 0);
        	assert(sd_status[`CMDACT] == 0);
        	#(SD_TCLK/2);
        	adr_in <= `SDIO_RESP1;
        	rd_wb <= 1;
        	#(SD_TCLK);
        	wait(ack_cpsm);
        	assert(response[127:96] == sd_reg);
        	#(SD_TCLK);
        	adr_in <= `SDIO_RESP1;
        	rd_wb <= 0;
            
        end
    join
    
    sd_cmd <= {21'b0,1'b0,2'b0,1'b1,1'b1,command[37:32]};
    
    #(100*SD_TCLK) $display("sd_data_serial_host_tb finish ...");
    $finish;
    
end
endmodule

