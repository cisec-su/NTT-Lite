`ifndef NTT_LITE_VH
`define NTT_LITE_VH


`define CMD_IDLE              3'd0
`define CMD_SET_CLR           3'd1
`define CMD_START             3'd2
`define CMD_LOAD_TWIDDLE      3'd3
`define CMD_LOAD_POLY         3'd4
`define CMD_READ_TWIDDLE      3'd5
`define CMD_LOAD_ZETA         3'd6
`define CMD_READ_POLY         3'd7


`define OP_NTT                5'd0
`define OP_INTT               5'd1
`define OP_PWM                5'd2
`define OP_ADD                5'd3
`define OP_SUB                5'd4
`define OP_COMPRESS           5'd5
`define OP_DECOMPRESS         5'd6
`define OP_ENCODE             5'd7
`define OP_DECODE             5'd8
`define OP_SUM                5'd9
`define OP_MAC                5'd15
`define OP_CBD                5'd13
`define OP_REJ_SAMP           5'd14
`define OP_SQ                 5'd18
`define OP_SQADD              5'd19
// below OPs are only valid for MODE_SINGLE
`define OP_DECOMPOSE          5'd10
`define OP_CHKINFNORM         5'd11
`define OP_MAKEHINT           5'd12
`define OP_USEHINT            5'd16
`define OP_CHKL1NORM          5'd17

`define MODE_SINGLE           2'd0
`define MODE_DUAL             2'd2
`define MODE_POLY             2'd3


`endif