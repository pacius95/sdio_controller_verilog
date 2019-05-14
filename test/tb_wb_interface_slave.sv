`timescale 1ns / 10ps
`include "define.vh"
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03.12.2018 10:53:29
// Design Name: 
// Module Name: tb_wb_interface_slave
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

module tb_wb_interface_slave();

    reg clk, rst, stb_m2s, cyc_m2s, we_m2s,  cti_m2s, bte_m2s;

    reg [`DATA_WIDTH-1:0] dat_m2s;
    reg [`ADDR_WIDTH-1:0] adr_m2s;
    wire ack_s2m, err_s2m, rty_s2m;
    wire [`DATA_WIDTH-1:0] dat_s2m;

    reg [`DATA_WIDTH-1:0] cnt;


            
    always #5 clk =~clk;
    
    
    initial
        begin
            clk <=1;
            rst <=1;
            stb_m2s <=0;
            cyc_m2s <=0;
            cnt <=0;
            @(posedge clk) rst <= 0;

            repeat (20) @(posedge clk)
            begin
            if (ack_s2m == 1)
                begin
                stb_m2s <= 0;
                we_m2s <= 0;
                dat_m2s <= '{default:0};
                cnt <= cnt + 1;
                end
            else 
                begin if (cnt == 0)
                adr_m2s <= {`SDIO_FIFO};
                else
                adr_m2s <= {`SDIO_FIFO};
                stb_m2s <= 1;
                cyc_m2s <= 1;
                we_m2s <= 1;
                dat_m2s <= {32'hFFFF_FFFF};

                end
            end


        #10 $finish;
        end

wb_interface_slave #(.ADDR_WIDTH(`ADDR_WIDTH), .DATA_WIDTH(`DATA_WIDTH), .BASE_ADDRESS(`BASE_ADDRESS))
      wb_interface_slave0(.clk(clk), .rst(rst), .dat_m2s(dat_m2s), .dat_s2m(dat_s2m),
        .cyc_m2s(cyc_m2s), .stb_m2s(stb_m2s), .adr_m2s(adr_m2s), .we_m2s(we_m2s), .cti_m2s(cti_m2s), .bte_m2s(bte_m2s),
        .ack_s2m(ack_s2m), .err_s2m(err_s2m), .rty_s2m(rty_s2m));
endmodule
