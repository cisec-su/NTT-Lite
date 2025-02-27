`ifndef NTT_LITE_VH
`define NTT_LITE_VH

`define CMD_IDLE              3'd0
`define CMD_RST               3'd1
`define CMD_RFU               3'd5
`define CMD_LOAD_TWIDDLE      3'd3
`define CMD_LOAD_POLY         3'd4
`define CMD_RFU0              3'd5
`define CMD_RFU1              3'd6
`define CMD_RFU2              3'd7


`define OP_NTT                4'd0
`define OP_INTT               4'd1
`define OP_PWM                4'd2
`define OP_ADD                4'd3
`define OP_SUB                4'd4


`define MODE_SINGLE           2'd0
`define MODE_DUAL             2'd2
`define MODE_POLY             2'd3

`endif