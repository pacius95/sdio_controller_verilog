`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12.05.2019 11:13:26
// Design Name: 
// Module Name: neg_edge_detector
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
module neg_edge_detector( input sig,            // Input signal for which negative edge has to be detected
                      input clk,			// Input signal for clock
                      output pe);           // Output signal that gives a pulse when a negative edge occurs
 
    reg   sig_dly;                          // Internal signal to store the delayed version of signal
 
    // This always block ensures that sig_dly is exactly 1 clock behind sig
  always @ (posedge clk) begin
    sig_dly <= sig;
  end
  assign pe = ~sig & sig_dly;    
endmodule

