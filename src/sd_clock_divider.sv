`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07.02.2019 16:36:29
// Design Name: 
// Module Name: sd_clock_divider
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


module sd_clock_divider (
           input sd_clk_i,
           input [31:0] sd_pwr,
           input [31:0] sd_clkcr,
           input rst,
           output sd_clk,
           output sd_clk_o
       );

reg [7:0] ClockDiv;
reg sd_clk_reg;

assign sd_clk = rst ? sd_clk_i : (sd_clkcr[10] ? sd_clk_i : sd_clk_reg); //bypass bit ( if 1 sd_clk_o == sd_clk_i)
assign sd_clk_o = (sd_pwr[1] & sd_pwr[0]) ? sd_clk : 1'b0;

always @(posedge sd_clk_i or posedge rst)
begin
    if (rst) begin
        ClockDiv <= 8'b0000_0000;
        sd_clk_reg <= 0;
    end
    else if (ClockDiv == sd_clkcr[7:0]) begin //SD_clk_o = sd_clk_i / 2 
        	ClockDiv <= 0;
        	sd_clk_reg <= ~sd_clk_reg;
    end 
    else begin
       	ClockDiv <= ClockDiv + 8'h1;
       	sd_clk_reg <= sd_clk_reg;
    end
end

endmodule
