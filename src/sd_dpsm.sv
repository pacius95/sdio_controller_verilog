  `timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer: 
// 
// Create Date: 12.02.2019 15:10:41
// Design Name: 
// Module Name: sd_dpsm
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


module sd_dpsm(
    input sd_clk,
    input rst,
    input [31:0] sd_clkcr, sd_dlen, sd_dctrl, sd_dtimer,

    output logic [31:0] sd_status,
    output logic [31:0] sd_dcount,  //internal register used as counter accessible from WB as rean only
    output logic [31:0] sd_fifocnt, //internal register used as coutner accessible from WB and from the FIFO, reado_only WB

	output logic dat_oe,
    output logic [7:0] dat_out,
    input [7:0] dat_in,


    input [31:0] fifo_dat_i,
    output logic fifo_wr,
    output logic [31:0] fifo_dat_o,
    output logic fifo_rd,

    output wire en_rx,
    output wire en_tx,

    input fifo_full,
    input fifo_empty
    );
//sd_status bit offset 

`define RXACT 13 //receive in act -> set to 1
`define TXACT 12 //transmit in act -> set to 1
`define DBCKEND 10 //Data block sent/received -> 1 (CRC check passed)
`define STBITERR 9 //Start Bit not detected on data signals -> 1
`define DATAEND 8 //No more data to send, counter is zero
`define DTIMEOUT 3 //Data timeout error
`define DCRCFAIL 1 //Data block sent/received (CRC fail) 

typedef enum logic [7:0] {IDLE = 8'b0000_0001,
                  WAIT_S = 8'b0000_0010,
                  SEND = 8'b0000_0100,
                  BUSY = 8'b0000_1000,
                  WAIT_R = 8'b0001_0000,
                  RECEIVE = 8'b0010_0000,
                  READ_WAIT = 8'b0100_0000} state;
state ss=IDLE, ss_next=IDLE;

wire [1:0] bus_mode ; //00 1 bit, 01 4 bit, 10 8 bit 
wire [3:0] dt_block_size; // 2^x size of the block max 2^14 16k
wire dt_mode; // 0 block, 1 stream
wire dt_dir; // 0 write, 1 read

reg start_crc_check;
reg [2:0] crc_status;


//crc registers
reg [7:0] crc_in;
wire [7:0] crc_out;
wire [15:0] crc_out_parallel [7:0];
reg crc_enable;
reg crc_serial_enable;
reg crc_reset;

//internal registers
reg crc_fail;
reg [31:0] timer;
reg [31:0] dt_blk_cnt;
reg [7:0] counter;
reg [7:0] dat_in_reg;

assign en_rx = sd_status[`RXACT] & !en_tx;
assign en_tx = sd_status[`TXACT] & !en_rx;

assign bus_mode = sd_clkcr[12:11];
assign dt_block_size = sd_dctrl[7:4];
assign dt_mode = sd_dctrl[2];
assign dt_dir = sd_dctrl[1];

always @(posedge sd_clk) begin
        dat_in_reg <= dat_in;
end

genvar i;
generate
    for(i=0; i<8; i=i+1) begin: CRC_16_gen
        sd_crc_16 sd_crc_16_i (.in(crc_in[i]),.en(crc_enable),.clk(sd_clk),.rst(crc_reset | rst),
                              .crc(crc_out_parallel[i]),.crc_serial(crc_out[i]),.serial(crc_serial_enable));
    end
endgenerate


always @(posedge sd_clk)
begin
    if (rst)
        ss <= IDLE;
    else
        ss <= ss_next;
end

always@ (*)
begin
    ss_next = ss;
            case (ss)   
            IDLE: begin
                if (counter >= 4 & sd_dctrl[0]) begin
                    if (dt_dir) 
                        ss_next = WAIT_R;
                    else 
                        ss_next = WAIT_S;
                end
                else 
                    ss_next = IDLE;      
            end
            WAIT_S: begin
                if (!sd_dcount)
                    ss_next = IDLE;
                //if FIFO empty (maybe fifo half empty with the dc gray on the fifo i may do it) wait in this state else go to SEND
                else if (fifo_empty)
                    ss_next = WAIT_S;
                else
                    ss_next = SEND;
            end
            
            SEND: begin
                if(!counter) 
                    ss_next = BUSY;
                else
                    ss_next = SEND;
            end

            BUSY: begin
                if (!timer)
                    ss_next = IDLE;
                else if (counter == 3 & dat_in[0]!= 1'b1)
                	ss_next = IDLE;
                else if (counter > 3 & crc_status != 3'b010)
                	ss_next = IDLE;
                else if (counter > 3 & dat_in[0]!= 1'b0)
                    ss_next = WAIT_S;
                else 
                    ss_next = BUSY;
            end

            WAIT_R: begin
            	if (crc_fail) 
            		ss_next = IDLE;
                else if (!timer)
                    ss_next = IDLE;
                else if (!sd_dcount) begin
                    if (fifo_empty)
                        ss_next = IDLE;
                    else
                        ss_next = WAIT_R;
                end
                else if (!dat_in_reg[0])
                    ss_next = RECEIVE;
                else
                    ss_next = WAIT_R;
            end

            RECEIVE:begin
                if (fifo_full)
                	ss_next = IDLE;
                if(!counter)
                    ss_next = WAIT_R;
                else
                    ss_next = RECEIVE;
            end
        endcase
end




always@ (posedge sd_clk or posedge rst)
begin
    if (rst) begin
                counter <= 4;
                timer <= 1'b0;
                sd_dcount <= 1'b0;
                sd_fifocnt <= 1'b0;
                
				crc_reset <= 0;
				fifo_dat_o <= 0;
				crc_in <= 0;
                crc_serial_enable <= 1'b0;
                crc_enable <= 1'b0;
                crc_fail <= 1'b0;     
                dt_blk_cnt <= 1'b0;


                dat_oe <= 0;
                dat_out <= 8'hff;


                fifo_wr <= 1'b0;
                fifo_rd <= 1'b0;
                
                sd_status[`RXACT] <= 0;
        		sd_status[`TXACT] <= 0;
        		sd_status[`DBCKEND] <= 0;
        		sd_status[`STBITERR] <= 0;
        		sd_status[`DATAEND] <= 0;
        		sd_status[`DTIMEOUT] <= 0;
        		sd_status[`DCRCFAIL] <= 0;
        		sd_status <= 0;              
    end
    else begin
            case (ss)
            IDLE: begin

        		 
                timer <= sd_dtimer;
                sd_dcount <= sd_dlen;
                sd_fifocnt <= (sd_dlen >> 2 + (sd_dlen[0] | sd_dlen[1])) ; //dt_lenght refers to byte, fifocount to words 

                crc_serial_enable <=1'b0;
                crc_enable <= 1'b0;
                crc_fail <= 1'b0;
                crc_in <= 0;
                start_crc_check <= 1'b0;
                crc_status <= 3'b000;
				crc_reset <=1;
                dat_oe <= 0;
                dat_out <= 8'hff;

                fifo_wr <= 1'b0;
                fifo_rd <= 1'b0;
                fifo_dat_o <= 1'b0;

                dt_blk_cnt <= 1'b0;

                if (counter < 4)
                    counter <= counter + 1;
                else if (counter == 4 & sd_dctrl[0]) begin
                	sd_status[`DBCKEND] <= 0;
        			sd_status[`STBITERR] <= 0;
        			sd_status[`DATAEND] <= 0;
        			sd_status[`DTIMEOUT] <= 0;
        			sd_status[`DCRCFAIL] <= 0;        
                    if (dt_dir)
                        sd_status[`RXACT] <= 1'b1;
                    else 
                        sd_status[`TXACT] <= 1'b1;                    
                    counter <= 0;
                end
            end

            WAIT_S: begin 
                timer <= sd_dtimer;
                dat_out <= 8'hff;
                dat_oe <= 0;
                

                start_crc_check <= 1'b0;
                crc_status <= 1'b0;
                crc_reset <= 1'b0;
                crc_in <= 1'b0;
                sd_status[`DBCKEND] <= 1'b0;
                if (!sd_dcount) begin
                	counter <= 0;
                    sd_status[`TXACT] <= 1'b0;
                    sd_status[`DATAEND] <= 1'b1; //rleggere documento stm32
                end
                else if (!fifo_empty) begin
                    counter <= 20;
                    crc_enable <= 1;
                    if (bus_mode == 2'b10)//8bit
                        dt_blk_cnt <= (1 << dt_block_size) - 1; // 2^dt_block_size bytes
                    else if (bus_mode == 2'b01)  //4bit
                        dt_blk_cnt <= (1 << dt_block_size + 1) - 1; // 2^(dt_block_size bytes + 1) 
                    else //1bit
                        dt_blk_cnt <= (1 << dt_block_size + 3) - 1; // 2^(dt_block_size bytes + 3
                end
            end
            
            SEND: begin                    
                if (dt_blk_cnt > 0)    begin
                    dat_oe <= 1'b1;
                    dt_blk_cnt <= dt_blk_cnt - 1; 
                    if (bus_mode == 2'b10) begin //8bit
                		crc_in[7] <= fifo_dat_i[7 + {(~dt_blk_cnt[1:0]),3'b000}];
                		crc_in[6] <= fifo_dat_i[6 + {(~dt_blk_cnt[1:0]),3'b000}];
                		crc_in[5] <= fifo_dat_i[5 + {(~dt_blk_cnt[1:0]),3'b000}];
                		crc_in[4] <= fifo_dat_i[4 + {(~dt_blk_cnt[1:0]),3'b000}];
                		crc_in[3] <= fifo_dat_i[3 + {(~dt_blk_cnt[1:0]),3'b000}];
                		crc_in[2] <= fifo_dat_i[2 + {(~dt_blk_cnt[1:0]),3'b000}];
                		crc_in[1] <= fifo_dat_i[1 + {(~dt_blk_cnt[1:0]),3'b000}];
                		crc_in[0] <= fifo_dat_i[0 + {(~dt_blk_cnt[1:0]),3'b000}];                                               
                        if (dt_blk_cnt[1:0] == 2'b01) begin
                            fifo_rd <= 1;
                            sd_fifocnt <= sd_fifocnt - 1;
                            sd_dcount <= sd_dcount - 4;
                            end
                        else                             
                            fifo_rd <= 0;
                    end
                    else if (bus_mode == 2'b01) begin //4bit
                        crc_in[3] <= fifo_dat_i[3 + {dt_blk_cnt[0],2'b00} + {(~dt_blk_cnt[2:1]),3'b000}];
                        crc_in[2] <= fifo_dat_i[2 + {dt_blk_cnt[0],2'b00} + {(~dt_blk_cnt[2:1]),3'b000}];
                        crc_in[1] <= fifo_dat_i[1 + {dt_blk_cnt[0],2'b00} + {(~dt_blk_cnt[2:1]),3'b000}];
                        crc_in[0] <= fifo_dat_i[0 + {dt_blk_cnt[0],2'b00} + {(~dt_blk_cnt[2:1]),3'b000}];                     
                        if (dt_blk_cnt[2:0] == 3'b001) begin
                            fifo_rd <= 1;
                            sd_fifocnt <= sd_fifocnt - 1;
                            sd_dcount <= sd_dcount - 4;
                            end
                        else 
                            fifo_rd <= 0;
                    end
                    else begin //1bit
                        crc_in[0] <= fifo_dat_i[(dt_blk_cnt[2:0]) + {(~dt_blk_cnt[4:3]),3'b000}];                       
                        if (dt_blk_cnt[4:0] == 5'b00001) begin
	                        sd_fifocnt <= sd_fifocnt - 1;
    	                    sd_dcount <= sd_dcount - 4;
                            fifo_rd <= 1;
                        	end
                     	else 
                            fifo_rd <= 0;
                    end
                 	if (bus_mode == 2'b10)
                    	dat_out <= crc_out;
                    else if (bus_mode == 2'b01)
                    	dat_out <= {4'b1111,crc_out[3:0]};
                    else
                    	dat_out <= {7'b1111111,crc_out[0]};                   
                end
                else begin  
                    fifo_rd <= 0;
                    if (counter == 20) begin
                        dat_oe <= 1'b1;
                    	counter <= counter - 1;
						if (bus_mode == 2'b10) begin
                            crc_in[7:0] <= fifo_dat_i[31:24];
                    		dat_out <= crc_out;
                    	end	
                    	
                    	else if (bus_mode == 2'b01) begin
                    		crc_in[3:0] <= fifo_dat_i[27:24];
                    		dat_out <= {4'b1111,crc_out[3:0]};
                    	end
                   	 	else begin
                   	 		crc_in[0] <= fifo_dat_i[24];
                    		dat_out <= {7'b1111111,crc_out[0]};
                    	end
                    end	
                    else if (counter > 1 & counter < 20) begin
                        dat_oe <= 1'b1;
                    	counter <= counter - 1;
                        crc_enable <= 0;
                    	crc_serial_enable <= 1;
                 		if (bus_mode == 2'b10)
                    		dat_out <= crc_out;
                    	else if (bus_mode == 2'b01)
                    		dat_out <= {4'b1111,crc_out[3:0]};
                    	else
                    		dat_out <= {7'b1111111,crc_out[0]};
                    end
                    else if (counter == 1) begin
                        dat_oe <= 1'b1;
                        counter <= counter - 1;
                        crc_serial_enable <= 0;
                        dat_out <= 8'hff;
                    end
                    else begin
                    	dat_oe <= 0;
                    	dat_out <= 8'hff;
                    end
                end

            end

            BUSY: begin                
            	if (timer == 0) begin
                    sd_dcount <= sd_dcount + (1 << dt_block_size);
            		sd_fifocnt <= sd_fifocnt + (1 << (dt_block_size-2));
                    sd_status[`TXACT] <= 0;
                    sd_status[`DTIMEOUT] <= 1;
                    counter <= 0;
                end
				if (start_crc_check) begin
                    if (counter < 3 ) begin
                        crc_status[counter] <= dat_in[0];
                        counter <= counter + 1; 
                    end
                    else if (counter == 3) begin
						if (dat_in[0] != 1'b1) begin
							counter <= 0;                            
							sd_dcount <= sd_dcount + (1 << dt_block_size);
							sd_fifocnt <= sd_fifocnt + (1 << (dt_block_size-2));
						    sd_status[`TXACT] <= 0;
							sd_status[`DCRCFAIL] <= 1;
						end
						else
							counter <= counter + 1;
					end
                    else begin
                        if (crc_status != 3'b010) begin
                            sd_dcount <= sd_dcount + (1 << dt_block_size);
                            sd_fifocnt <= sd_fifocnt + (1 << (dt_block_size-2));
                            sd_status[`TXACT] <= 0;
                            sd_status[`DCRCFAIL] <= 1;
                            counter <= 0;
                            end
                        else if (dat_in[0] != 1'b0) begin
                        	sd_status[`DBCKEND] <= 1;
                        	counter <= 0;
                     	end
                        else
                    		timer <= timer - 1;
                    end
                end
                else if (dat_in[0] == 1'b0 & !start_crc_check)
                    start_crc_check <= 1;
                else
                    timer <= timer - 1;
            end
            
            WAIT_R: begin
                timer <= timer - 1;
                
                dat_oe <= 0;
                crc_reset <= 0;
                crc_in <= dat_in;
                
                if (crc_fail) begin
                    sd_dcount <= sd_dcount + (1 << dt_block_size);
   	                sd_fifocnt <= sd_fifocnt + (1 << (dt_block_size-2));
   	                sd_status[`DBCKEND] <= 0;
                    sd_status[`RXACT] <= 0;
                    sd_status[`DCRCFAIL] <= 1;
                end
                else if (timer == 0) begin
                	sd_status[`DBCKEND] <= 0;
                    sd_status[`RXACT] <= 0;
                    sd_status[`DTIMEOUT] <= 1;
                end
                else if (!sd_dcount) begin
                    if (fifo_empty) begin
                        sd_status[`DBCKEND] <= 0;
                        sd_status[`RXACT] <= 0;
                        sd_status[`DATAEND] <= 1;
                    end 
             	end
                else if (dat_in[0] == 0) begin
             	    sd_status[`DBCKEND] <= 0;
                    crc_serial_enable <= 0;
                    crc_enable <= 1;
                    counter <= 17;
                    if (bus_mode == 2'b10) //8bit
                        dt_blk_cnt <= (1 << dt_block_size) - 1; // 2^dt_block_size bytes - 1
                    else if (bus_mode == 2'b01) //4bit
                        dt_blk_cnt <= (1 << dt_block_size + 1) - 1; // 2^(dt_block_size bytes + 1) - 1
                    else //1bit
                        dt_blk_cnt <= (1 << dt_block_size + 3) - 1; // 2^(dt_block_size bytes + 3) - 1
                end
            end

            RECEIVE:begin
                timer <= sd_dtimer;
                crc_in <= dat_in;
                if (fifo_full) begin
                    sd_status[`RXACT] <= 0;
                    //fifo_flag_errors
                end
                if (dt_blk_cnt > 0) begin               
                    dt_blk_cnt <= dt_blk_cnt - 1;

                    if (bus_mode == 2'b10) begin //8bit
                        fifo_dat_o [7 + {(~dt_blk_cnt[1:0]),3'b000}] <= dat_in_reg[7];
                        fifo_dat_o [6 + {(~dt_blk_cnt[1:0]),3'b000}] <= dat_in_reg[6];
                        fifo_dat_o [5 + {(~dt_blk_cnt[1:0]),3'b000}] <= dat_in_reg[5];
                        fifo_dat_o [4 + {(~dt_blk_cnt[1:0]),3'b000}] <= dat_in_reg[4];
                        fifo_dat_o [3 + {(~dt_blk_cnt[1:0]),3'b000}] <= dat_in_reg[3];
                        fifo_dat_o [2 + {(~dt_blk_cnt[1:0]),3'b000}] <= dat_in_reg[2];
                        fifo_dat_o [1 + {(~dt_blk_cnt[1:0]),3'b000}] <= dat_in_reg[1];
                        fifo_dat_o [0 + {(~dt_blk_cnt[1:0]),3'b000}] <= dat_in_reg[0];

                        if (dt_blk_cnt[1:0] == 2'b00) begin
                        	sd_fifocnt <= sd_fifocnt - 1;
                            sd_dcount <= sd_dcount - 4;
                            fifo_wr <= 1'b1;
                        end
                        else
                            fifo_wr <= 1'b0;
                    end
                    else if (bus_mode == 2'b01) begin //4bit
                            fifo_dat_o [3 + {dt_blk_cnt[0],2'b00} + {(~dt_blk_cnt[2:1]),3'b000}] <= dat_in_reg[3];
                            fifo_dat_o [2 + {dt_blk_cnt[0],2'b00} + {(~dt_blk_cnt[2:1]),3'b000}] <= dat_in_reg[2];
                            fifo_dat_o [1 + {dt_blk_cnt[0],2'b00} + {(~dt_blk_cnt[2:1]),3'b000}] <= dat_in_reg[1];
                            fifo_dat_o [0 + {dt_blk_cnt[0],2'b00} + {(~dt_blk_cnt[2:1]),3'b000}] <= dat_in_reg[0];

                        if (dt_blk_cnt[2:0] == 3'b000) begin
	                        sd_fifocnt <= sd_fifocnt - 1;
                            sd_dcount <= sd_dcount - 4;
                            fifo_wr <= 1'b1;
                        end
                        else 
                            fifo_wr <= 1'b0;
                    end
                    else begin //1bit
                        fifo_dat_o[(dt_blk_cnt[2:0]) + {(~dt_blk_cnt[4:3]),3'b000}] <= dat_in_reg[0];

                        if (dt_blk_cnt[4:0] == 5'b00000) begin
	                        sd_fifocnt <= sd_fifocnt - 1;
                            sd_dcount <= sd_dcount - 4;
                            fifo_wr <= 1'b1;
                        end
                        else 
                            fifo_wr <= 1'b0;
                    end
                end
                else begin //crc
                    crc_enable <= 0;
                    if (counter > 0 ) 
                        counter <= counter - 1;
                    if (counter == 17) begin
	                    sd_fifocnt <= sd_fifocnt - 1;
                        sd_dcount <= sd_dcount - 4;
                        fifo_wr <= 1;
                        
                        if (bus_mode == 2'b10) 
                            fifo_dat_o[31:24] <= dat_in_reg;
                        else if (bus_mode == 2'b01) 
                            fifo_dat_o[27:24] <= dat_in_reg[3:0];
                        else
                            fifo_dat_o[24] <= dat_in_reg[0];
                    end
                    else if (counter < 17 & counter > 0) begin
                        fifo_wr <= 0;

                        if (dat_in_reg[0] != crc_out_parallel[0][counter-1])
                                    crc_fail <= 1;
                        if (bus_mode != 2'b00 & (dat_in_reg[1] != crc_out_parallel[1][counter-1] | dat_in_reg[2] != crc_out_parallel[2][counter-1]
                            | dat_in_reg[3] != crc_out_parallel[3][counter-1]))
                                    crc_fail <= 1;
                        if (bus_mode == 2'b10 & (dat_in_reg[4] != crc_out_parallel[4][counter-1] | dat_in_reg[5] != crc_out_parallel[5][counter-1]
                            | dat_in_reg[6] != crc_out_parallel[6][counter-1] | dat_in_reg[7] != crc_out_parallel[7][counter-1]))
                                    crc_fail <= 1;
                    end
                    if (!counter)  begin
                        crc_reset <= 1;
                        crc_enable <= 0; 
                        sd_status[`DBCKEND] <= 1;
                    end
                end
            end 
        endcase
    end
end
endmodule