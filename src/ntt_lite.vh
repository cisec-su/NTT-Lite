`ifndef NTT_LITE_VH
`define NTT_LITE_VH

`define CMD_IDLE         3'd0
`define CMD_RST          3'd1
`define CMD_RFU          3'd5
`define CMD_LOAD_TWIDDLE 3'd3
`define CMD_LOAD_POLY    3'd4
`define CMD_RFU0         3'd5
`define CMD_RFU1         3'd6
`define CMD_RFU2         3'd7


`define MODE_NTT         2'd0
`define MODE_INTT        2'd2
`define MODE_PWM         2'd3
`define MODE_RFU1        2'd4


`endif