`timescale 1ns / 1ps
`include "define.vh"
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 29.11.2018 11:21:08
// Design Name: 
// Module Name: wb_interface_slave
// Project Name: SDIO_controller
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
    
module wb_interface_slave #(
 parameter ADDR_WIDTH=8,
 parameter BASE_ADDRESS=0) //24 bit high of address
 (
    //common WISHBONE
    clk, rst, dat_m2s, dat_s2m,
    
    

    //slave WISHBONE
    cyc_m2s, stb_m2s, adr_m2s, we_m2s, cti_m2s, bte_m2s,
    ack_s2m, err_s2m, rty_s2m,
    
    adr_in, rd_cpsm, ack_cpsm,
    dat_cpsm,
    
    //input regs
    sd_status,
    sd_dcount,
    sd_fifocnt,
    
    //output regs
    sd_pwr,
    sd_clkcr,
    sd_arg,
    sd_cmd,
    sd_dlen,
    sd_dctrl,
    sd_dtimer
);

 //COMMON WISHBONE PORT

input   clk;                    //WISHBONE clock  
input   rst;                    //WISHBONE reset
input   [31:0] dat_m2s;   //WISHBONE data_input
output  logic [31:0] dat_s2m;   //WISHBONE data_output

//SLAVE WISHBONE PORT

input   cyc_m2s;                    //WISHBONE cycle
input   stb_m2s;                    //WISHBONE strobe
input   [ADDR_WIDTH-1:0] adr_m2s;   //WISHBONE adress_input
input   we_m2s;                     //WISHBONE write_enable_input
input   cti_m2s;            //WISHBONE c
input   bte_m2s;            //WISHBONE 
output  logic err_s2m;      //WISHBONE error_output
output  logic rty_s2m;      //WISHBONE retry_output
output  logic ack_s2m;      //WISHBONE acknowledge_output

//regs
input [31:0] sd_status;
input [31:0] sd_dcount;
input [31:0] sd_fifocnt;

//regs
output logic [31:0] sd_pwr;
output logic [31:0] sd_clkcr;
output logic [31:0] sd_arg;
output logic [31:0] sd_cmd;
output logic [31:0] sd_dlen;
output logic [31:0] sd_dctrl;
output logic [31:0] sd_dtimer;

output logic [ADDR_WIDTH-1:0] adr_in ;
output logic rd_cpsm;
input ack_cpsm;
input [31:0] dat_cpsm;



wire data_tx;
wire data_rx;
wire cmd_act;

assign data_tx = sd_status[`TXACT];
assign data_rx = sd_status[`RXACT];
assign cmd_act = sd_status[`CMDACT];


typedef enum logic [4:0] {IDLE = 5'b00001,
                  READ = 5'b00010,
                  WRITE = 5'b00100,
                  READ_CPSM = 5'b01000,
                  READ_DPSM = 5'b10000} state;
state ss=IDLE, ss_next=IDLE;

//syncronizing status and output update logic

  always @(posedge clk)
  begin
    if (rst)
      ss  <= IDLE;
    else
      ss <= ss_next;
  end 

wire cpsm_end;
wire dpsm_end;

neg_edge_detector neg_edge_detector_cmdact(
	.sig(cmd_act),.clk(clk), .pe(cpsm_end) 
	);
neg_edge_detector neg_edge_detector_dpsmact(
	.sig(data_rx | data_tx),.clk(clk), .pe(dpsm_end)
	);

//stopping the cpsm adn dpsm when they end
always @(posedge clk)
  begin
    if (dpsm_end) //qui dovrei mettere un negedge trigger sul bit DATAACT e CMDACT
    	sd_dctrl[0] <= 0;
    else if (cpsm_end)
    	sd_cmd[10] <= 0;
  end
  
//combo logic for state and output 
  always@(*)
  begin
      ss_next=ss;
      case(ss)
        IDLE: 
        begin
          if (cyc_m2s & stb_m2s & !we_m2s & !ack_s2m & !adr_m2s[7])      
            ss_next = READ;
          else if (cyc_m2s & stb_m2s & we_m2s & !data_tx & !data_rx & !cmd_act & !ack_s2m & !adr_m2s[7])
            ss_next = WRITE;
          else
            ss_next = IDLE;
        end
        READ:
        begin
			if (adr_in[6:4] == 3'b001 | adr_in == 7'h20)
				ss_next = READ_CPSM;
			else
				ss_next = IDLE; 
        end
        READ_CPSM: begin
        	if (ack_cpsm)
        		ss_next = IDLE;
        	else
        		ss_next = READ_CPSM;
        end
        WRITE:
        begin
          if(ack_s2m)
            ss_next = IDLE;
          else
            ss_next = WRITE;
        end
      endcase
  end



  always@(posedge clk)
  begin
    if (rst) 
      begin      
      sd_pwr <= 0;
      sd_clkcr <= 0;
      sd_arg <= 0;
      sd_cmd <= 0;
      sd_dlen <= 0;
      sd_dctrl <= 0;
      sd_dtimer <= 0;
      
      adr_in <= 0;
      ack_s2m <= 0;
      dat_s2m <= 0;
      rd_cpsm <= 0;
      end
    else begin
      case(ss)
        IDLE: 
        begin
          adr_in <= adr_m2s;
          ack_s2m <= 0;
          rd_cpsm <= 0;
        end
        READ:
        begin
            case (adr_in) 
              `SDIO_POWER       : dat_s2m <= sd_pwr;
              `SDIO_CLKCR       : dat_s2m <= sd_clkcr;
              `SDIO_ARG         : dat_s2m <= sd_arg;  
              `SDIO_CMD         : dat_s2m <= sd_cmd;  
              `SDIO_DTIMER      : dat_s2m <= sd_dtimer;  
              `SDIO_DLEN        : dat_s2m <= sd_dlen;
              `SDIO_DCTRL       : dat_s2m <= sd_dctrl;
               
              `SDIO_STA         : dat_s2m <= sd_status; 
              `SDIO_DCOUNT      : dat_s2m <= sd_dcount; 
              `SDIO_FIFOCNT     : dat_s2m <= sd_fifocnt;             
                        
            endcase
            //da 7'h10 a 7'h20 richiesta reg al cpsm
            if (adr_in[6:4] == 3'b001 | adr_in == 7'h20) begin
            	ack_s2m <= 0;
            	rd_cpsm <= 1;
            end    
        	else
        		ack_s2m <= 1;           		
        end
        READ_CPSM: begin
        	if (ack_cpsm) begin
        		dat_s2m <= dat_cpsm;
        		ack_s2m <= 1;
        		rd_cpsm <= 0;
        	end
        end
        WRITE:
        begin
          case (adr_in) 
            `SDIO_POWER       : sd_pwr  <= dat_m2s;
            `SDIO_CLKCR       : sd_clkcr  <= dat_m2s;
            `SDIO_ARG         : sd_arg  <= dat_m2s;  
            `SDIO_CMD         : sd_cmd  <= dat_m2s; 
            `SDIO_DTIMER      : sd_dtimer  <= dat_m2s;  
            `SDIO_DLEN        : sd_dlen  <= dat_m2s;
            `SDIO_DCTRL       : sd_dctrl  <= dat_m2s;
          endcase
            ack_s2m <= 1;  
        end
      endcase
    end
  end


endmodule