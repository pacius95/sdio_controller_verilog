`timescale 1ns / 1ps
`include "define.vh"
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10.12.2018 19:31:26
// Design Name: 
// Module Name: sd_cmd_adapter
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


module sd_cmd_adapter(
    input sd_clk,
    input rst,
    input [31:0] sd_cmd,
    input [31:0] sd_arg,
    output logic [31:0] sd_status,
    
    
    input [6:0] adr_in,
    input rd_wb,
    output logic [31:0] sd_reg,
    output logic ack_cpsm,
    
    
    input cmd_in,
    output logic cmd_oe,
    output logic cmd_out
    // output status_flag,

    );

typedef enum logic [7:0] {SETUP_RECEIVE = 8'b0000_0001,
                  IDLE = 8'b0000_0010,
                  PEND = 8'b0000_0100,
                  SETUP_SEND = 8'b0000_1000,
                  SEND = 8'b0001_0000,
                  WAIT = 8'b0010_0000,
                  RECEIVE = 8'b0100_0000,
                  WAITCPL = 8'b1000_0000} state;

state ss=IDLE, ss_next=IDLE;

reg [31:0] sd_respcmd; 
reg [31:0] sd_resp1;
reg [31:0] sd_resp2;
reg [31:0] sd_resp3;
reg [31:0] sd_resp4;

reg cmd_in_reg;
 
/*
reg ata_cmd;
reg nien;
reg en_cmd_cpl;
reg sdio_suspend;
reg wait_int;
*/
reg [39:0] cmd;  


reg shift_crc_rst;
reg shift_load;
reg shift_enable;
reg shift_out;
wire serial_in;
reg shift_serial;
wire [31:0]shift_rsp;
wire [6:0]shift_rsp_crc;


wire crc_in;
reg crc_enable;
wire [6:0] crc_out_parallel;
wire crc_serial_out;
reg crc_serial_enable;


assign crc_in = cmd_oe ?  shift_out :cmd_in_reg;

assign serial_in = cmd_oe ?  1'b0 : cmd_in_reg;


reg [7:0] counter; // 64 clk max

always @(posedge sd_clk or posedge rst)
begin
if (rst)
    begin
    
        sd_status[`CCRCFAIL] <= 0;
		sd_status[`CTIMEOUT] <= 0;
		sd_status[`CMDREND] <= 0;
		sd_status[`CMDSENT] <= 0;
		sd_status[`CMDACT] <= 0;
		sd_status <= 0;
        sd_resp1 <= 0;
        sd_resp2 <= 0;
        sd_resp3 <= 0;
        sd_resp4 <= 0;
        sd_respcmd <= 0;

       
		/*
		ata_cmd <= 0;
        nien <= 0;
        en_cmd_cpl <= 0;
        sdio_suspend <= 0;
        wait_int <= 0;
     	*/
        
        cmd <= 0;
        
        cmd_oe <= 0;
        cmd_out <= 1;
	

    end
else
    begin
		/* modalita' da implementare

		ata_cmd <= sd_cmd[14];   // if set send command 61
        nien <= sd_cmd[13];      //idk
        en_cmd_cpl <= sd_cmd[12];    //idk command completion
        sdio_suspend <= sd_cmd[11];  //send suspend command, onlyu to SDIO(?)
        wait_int <= sd_cmd[8];       //no timeout wait interrupt 
        */

        cmd <= {1'b0,1'b1,sd_cmd[5:0],sd_arg};   //cmdindex MSB transmitted first LSB last. 
    end                              //CRC calculated ann all 40 of this bits
end




always @(posedge sd_clk) begin
	if (rd_wb) begin
		case (adr_in) 
		  `SDIO_RESPCMD    : sd_reg <= sd_respcmd;
		  `SDIO_RESP1      : sd_reg <= sd_resp1;
		  `SDIO_RESP2      : sd_reg <= sd_resp2;  
		  `SDIO_RESP3      : sd_reg <= sd_resp3;  
		  `SDIO_RESP4      : sd_reg <= sd_resp4;  
		endcase
		ack_cpsm <= 1;
	end
	else
		ack_cpsm <= 0;
end


shift_reg_parallel_serial
    shift_reg_parallel_serial_0 (.cmd(cmd),
    .clk(sd_clk),
    .rst(shift_crc_rst | rst),
    .load(shift_load),
    .enable(shift_enable),
    .out(shift_out),
    .serial(shift_serial),
    .serial_in(serial_in),
    .resp_out(shift_rsp),
    .crc(shift_rsp_crc)
    );


sd_crc_7
    sd_crc_7_0 (.in(crc_in),
    .en(crc_enable),
    .clk(sd_clk),
    .rst(shift_crc_rst | rst),
    .crc(crc_out_parallel),
    .crc_serial(crc_serial_out),
    .serial(crc_serial_enable)
    );

always @(posedge sd_clk)
begin
    if (rst)
        ss <= IDLE;
    else
        ss <= ss_next;
end

always @(posedge sd_clk)
begin
	cmd_in_reg <= cmd_in;
end


//updates states and flags
always@ (*)
begin
    ss_next = ss;
            case (ss)
                IDLE: begin
                    if (counter < `IDLE_TIMER)
                            ss_next = IDLE;
                    else if (sd_cmd[10]) begin
                            if (sd_cmd[9])
                                ss_next = PEND;
                            else 
                                ss_next = SETUP_SEND;
                        end 
                   	else
                   		ss_next = IDLE;
                end

                PEND: begin
                    //wait for data send to be handled
                end

                SETUP_SEND: begin
                    ss_next = SEND;
                end

                SEND: begin
                    if (counter > `BIT_TO_SEND) begin
                        if (sd_cmd[6])
                            ss_next = WAIT;
                        else
                            ss_next = IDLE;
                    end
                    else 
                        ss_next = SEND;
                end

                WAIT: begin
                    if (counter == `WAIT_RESP) 
                        ss_next = IDLE;
                    else if (!cmd_in) 
                        ss_next = RECEIVE;
                    else 
                        ss_next = WAIT;
                end

                RECEIVE:
                begin
                    //if resp_length = 1 receive 136 bit, else if 0 48.
                    if (sd_cmd[7]) begin
                        if (counter == 135)
                            ss_next = IDLE;
                        else
                            ss_next = RECEIVE;
                    end
                    else begin
                        if (counter == 47)
                            ss_next = IDLE;
                        else
                            ss_next = RECEIVE;
                    end

                end

                WAITCPL:
                begin
                end
            endcase
end


always@ (posedge sd_clk or posedge rst)
begin
    if (rst) begin
        shift_crc_rst <= 0;
        shift_load <= 0;
        shift_enable <= 0;
        shift_serial <= 0;

        crc_serial_enable <=0;
        crc_enable <= 0;
        counter <= 0;        
    end
    else begin
            case (ss)
                IDLE:
                begin
                    if (counter < `IDLE_TIMER)
                        counter <= counter + 1;
                                 
                    shift_crc_rst <= 1;
                    shift_load <= 0;
                    shift_enable <= 0;
                    shift_serial <= 0;
                    
                    crc_serial_enable <=0;
                    crc_enable <= 0;
                    
                    cmd_oe <= 1'b0;
                    cmd_out <= 1'b1;

                    if (counter >= `IDLE_TIMER & !sd_cmd[9] & sd_cmd[10])  
                    	begin
                        	sd_status[`CMDACT] <= 1;
                        	sd_status[`CCRCFAIL] <= 0;
                    		sd_status[`CTIMEOUT] <= 0;
                    		sd_status[`CMDSENT] <= 0;
                    		sd_status[`CMDREND] <= 0;
                    	end
                end

                PEND:
                begin
                    //wait for data send to be handled
                end

                SETUP_SEND:
                begin
                    cmd_oe <= 1'b1;
                    cmd_out <= 1'b1; // o 1'bz ???
                    counter <= 0;
                    shift_crc_rst <= 0;

                    shift_load <= 1;    // inizia a lavorare dal prossimo clock
                end

                SEND://SENDING 1 bit at a time 48 bit.
                begin
                    shift_load <= 1'b0;
                    if ( counter <= 1) 
                        cmd_out <= 1'b1; // o 1'bz?
                    else 
                        cmd_out <= crc_serial_out;                    

                    if (counter <= `BIT_TO_SEND )
                        counter <= counter + 1'b1;
                    
                    if (counter < `CMD_SIZE)  begin
                        shift_enable <= 1'b1;
                        crc_enable <= 1'b1;
                    end
                    else if (counter >= `CMD_SIZE & counter < `BIT_TO_SEND) begin
                        shift_enable <= 1'b0;
                        crc_enable <= 1'b0;
                        crc_serial_enable <= 1'b1;
                    end
                    else if (counter == `BIT_TO_SEND) begin
                        crc_serial_enable <= 1'b0;
                        shift_crc_rst <= 1'b1;
                    end
                    else begin
                        shift_crc_rst <= 1'b0;
                        cmd_out <= 1'b1;
                        counter <= 1'b0;
                        if (!sd_cmd[6]) begin
                            sd_status[`CMDSENT] <= 1'b1;
                            sd_status[`CMDACT] <= 1'b0; 
                        end
                    end
                end

                WAIT:
                begin
                    cmd_oe <= 1'b0;
                    cmd_out <= 1'b1;
                    
                    if (counter == `WAIT_RESP) begin
                        sd_status[`CMDACT] <= 1'b0;
                        sd_status[`CTIMEOUT] <= 1'b1; 
                    end
                    
                    if (!cmd_in) begin
                        shift_serial <= 1'b1;
                        shift_enable <= 1'b1;
                        crc_serial_enable <= 1'b0;
                        if (sd_cmd[7] == 0)
                            crc_enable <= 1'b1;
                        else 
                            crc_enable <= 1'b0;
                        counter <= 0;
                    end 
                    else
                        counter <= counter + 1'b1;
                end

                RECEIVE:
                begin
                    counter <= counter + 1'b1;
                    if (!sd_cmd[7])   begin
                        if (counter == 8) 
                            sd_respcmd <= shift_rsp_crc[5:0];
                        else if ( counter >= 39 & counter <46)
                            crc_enable <= 0;
                        else if (counter == 46) begin
                            shift_enable <= 0;
                            shift_serial <= 0; 
                        end
                        else if (counter == 47) begin 
                            sd_resp1 <= shift_rsp;
                            if (crc_out_parallel == shift_rsp_crc)
                            	sd_status[`CMDREND] <= 1;
                            else  
                                sd_status[`CCRCFAIL] <= 1; 
                            sd_status[`CMDACT] <= 0; 
                            counter <=0; 
                        end
                    end
                    else begin
                        if (counter == 7) 
                            crc_enable <= 1;
                        else if (counter == 47)
                            sd_resp1 <= shift_rsp;
                        else if (counter == 79)
                            sd_resp2 <= shift_rsp;
                        else if (counter == 111)
                            sd_resp3 <= shift_rsp;
                        else if ( counter >= 127 & counter <134 )
                            crc_enable <= 0;
                        else if (counter == 134) begin
                            shift_enable <= 0;
                            shift_serial <= 0;
                        end
                        else if (counter == 135)    begin 
                            sd_resp4 <= {shift_rsp[23:0],shift_rsp_crc,1'b1};
                            if (crc_out_parallel == shift_rsp_crc) //da rivedere questa parte qui
                                sd_status[`CMDREND] <= 1;  
                            else 
                                sd_status[`CCRCFAIL] <= 1; 
                            sd_status[`CMDACT] <= 0;  
                            counter <= 0;
                        end
                    end
                end

                WAITCPL:
                begin
                end
            endcase
    end
end
endmodule
