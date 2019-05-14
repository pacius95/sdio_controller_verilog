`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 17.02.2019 23:52:58
// Design Name: 
// Module Name: sd_crc_16
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


module sd_crc_16(
    input        in,
    input        en,
    input        clk,                           // Current bit valid (Clock)
    input        rst,                             // Init crc value
    input        serial,
    output reg [15:0] crc,                               // Current output crc value
    output reg crc_serial

);

   wire         inv;
   
   assign inv = in ^ crc[15];                  
   
   
    always @(posedge clk) begin
		if (rst) begin
			crc <= 0;
			crc_serial <= 1'b1;
		end
		else begin
			if (en==1) begin
                crc[15] <= crc[14];
				crc[14] <= crc[13];
				crc[13] <= crc[12];
				crc[12] <= crc[11] ^ inv;
				crc[11] <= crc[10];
				crc[10] <= crc[9];
                crc[9] <= crc[8];
				crc[8] <= crc[7];
				crc[7] <= crc[6];
				crc[6] <= crc[5] ;
				crc[5] <= crc[4] ^ inv;
				crc[4] <= crc[3];
				crc[3] <= crc[2];
				crc[2] <= crc[1];
				crc[1] <= crc[0];
				crc[0] <= inv;

                crc_serial <= in;
			end
            else if(serial) begin
                crc <= {crc[14:0],1'b0};
                crc_serial <= crc[15];
            end
            else 
            	crc_serial <= 1'b1;
		end

     end
   
endmodule

