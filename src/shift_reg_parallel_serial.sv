`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 15.12.2018 09:38:55
// Design Name: 
// Module Name: shift_reg_parallel_serial
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


module shift_reg_parallel_serial(
    input [39:0] cmd,
    input clk,
    input rst,
    input load,
    input enable,
    output logic out,
    input serial_in,
    input serial,
    output [31:0] resp_out,
    output [6:0] crc
    );

   parameter piso_shift = 40;

   reg [piso_shift-2:0] shift;
 
   
   assign crc = shift[6:0];
   assign resp_out = shift[38:7];

   always @(posedge clk)
      if (rst) begin
         shift <= 0;
         out <= 0;
      end
      else if (load) begin
         shift <= cmd[piso_shift-2:0];
         out    <= cmd[39];
      end
      else if (enable)  begin
         if (serial)
            shift <= {shift[piso_shift-3:0],serial_in};
         else begin
            shift <= {shift[piso_shift-3:0], 1'b0};
            out   <= shift[38];
         end
      end
endmodule
