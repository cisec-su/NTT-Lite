`ifndef POLY_ACC_VH
`define POLY_ACC_VH


`define CMD_IDLE              3'd0
`define CMD_START             3'd2
`define CMD_LOAD_TWIDDLE      3'd3
`define CMD_LOAD_POLY         3'd4
`define CMD_READ_TWIDDLE      3'd5
`define CMD_LOAD_ZETA         3'd6
`define CMD_READ_POLY         3'd7


`define OP_NOP                5'd0
`define OP_NTT                5'd1
`define OP_INTT               5'd2
`define OP_PWM                5'd3
`define OP_ADD                5'd4
`define OP_SUB                5'd5
`define OP_COMPRESS           5'd6
`define OP_SUM                5'd9
`define OP_MAC                5'd15
`define OP_SQADD              5'd18
`define OP_TOCENTER           5'd19
`define OP_FROMCENTER         5'd20
`define OP_FNDECOMPRESS       5'd21
// below OPs are only valid for MODE_SINGLE
`define OP_DECOMPOSE          5'd10
`define OP_CHKINFNORM         5'd11
`define OP_MAKEHINT           5'd12
`define OP_USEHINT            5'd16
`define OP_CHKL1NORM          5'd17

`define OP1_NOP               2'd0
`define OP1_ENCODE            2'd1
`define OP1_DECODE            2'd2

`define OP2_NOP               2'd0
`define OP2_CBD               2'd1
`define OP2_REJSAMP           2'd2


`define MODE_SINGLE           2'd0
`define MODE_DUAL             2'd2
`define MODE_POLY             2'd3

`define ROUND_FLOOR           2'd0
`define ROUND_CEIL            2'd1
`define ROUND_HALFDOWN        2'd2
`define ROUND_HALFUP          2'd3


`endif