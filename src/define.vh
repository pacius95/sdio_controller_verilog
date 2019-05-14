`define ADDR_WIDTH 8
`define DATA_WIDTH 32
`define BASE_ADDRESS 0

//sd_status parameter cpsm
`define CMDACT 23
`define CMDSENT 7
`define CMDREND 6
`define CTIMEOUT 2
`define CCRCFAIL 0

//sd_status parameter dpsm
`define RXACT 13 //receive in act -> set to 1
`define TXACT 12 //transmit in act -> set to 1
`define DBCKEND 10 //Data block sent/received -> 1 (CRC check passed)
`define STBITERR 9 //Start Bit not detected on data signals -> 1
`define DATAEND 8 //No more data to send, counter is zero
`define DTIMEOUT 3 //Data timeout error
`define DCRCFAIL 1 //Data block sent/received (CRC fail) 

//CPSM parameter
`define IDLE_TIMER 8
`define BIT_TO_SEND 48
`define CMD_SIZE 40
`define RESP_SIZE 128
`define WAIT_RESP 63

//Register Address

`define SDIO_POWER 8'h00
`define SDIO_CLKCR 8'h04
`define SDIO_ARG 8'h08
`define SDIO_CMD 8'h0C
`define SDIO_RESPCMD 8'h10
`define SDIO_RESP1 8'h014
`define SDIO_RESP2 8'h18
`define SDIO_RESP3 8'h1C
`define SDIO_RESP4 8'h20
`define SDIO_DTIMER 8'h24
`define SDIO_DLEN 8'h28
`define SDIO_DCTRL 8'h2C

`define SDIO_DCOUNT 8'h30
`define SDIO_STA 8'h34
`define SDIO_FIFOCNT 8'h48

`define SDIO_FIFO 8'h80
