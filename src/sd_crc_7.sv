`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 17.12.2018 16:14:04
// Design Name: 
// Module Name: sd_crc_7
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


module sd_crc_7(
    input        in,
    input        en,
    input        clk,                           // Current bit valid (Clock)
    input        rst,                             // Init crc value
    input        serial,
    output reg [6:0] crc,                               // Current output crc value
    output reg crc_serial

);

   wire         inv;
   
   assign inv = in ^ crc[6];                 
   
   
    always @(posedge clk) begin
		if (rst) begin
			crc <= 0; 
			crc_serial <= 0; 
        end
		else begin
			if (en==1) begin
				crc[6] <= crc[5];
				crc[5] <= crc[4];
				crc[4] <= crc[3];
				crc[3] <= crc[2] ^ inv;
				crc[2] <= crc[1];
				crc[1] <= crc[0];
				crc[0] <= inv;

                crc_serial <= in;
			end
            else if(serial)
            begin
                crc <= {crc[5:0],1'b0};
                crc_serial <= crc[6];
            end
		end

     end
   
endmodule

