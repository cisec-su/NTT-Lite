`ifndef NTT_LITE_VH
`define NTT_LITE_VH


`define CMD_IDLE              4'd0
`define CMD_RST               4'd1
`define CMD_START             4'd2
`define CMD_LOAD_TWIDDLE      4'd3
`define CMD_LOAD_POLY         4'd4
`define CMD_READ_TWIDDLE      4'd5
`define CMD_LOAD_ZETA         4'd6
`define CMD_READ_POLY         4'd7
`define CMD_SET_CLR           4'd15


`define OP_NTT                4'd0
`define OP_INTT               4'd1
`define OP_PWM                4'd2
`define OP_ADD                4'd3
`define OP_SUB                4'd4
`define OP_COMPRESS           4'd5
`define OP_DECOMPRESS         4'd6
`define OP_ENCODE             4'd7
`define OP_DECODE             4'd8
`define OP_SUM                4'd9
// below OPs are only valid for MODE_SINGLE
`define OP_DECOMPOSE          4'd10
`define OP_CHKNORM            4'd11
`define OP_MAKEHINT           4'd12
`define OP_CBD                4'd13
`define OP_REJ_SAMP           4'd14
`define OP_MAC                4'd15


`define MODE_SINGLE           2'd0
`define MODE_DUAL             2'd2
`define MODE_POLY             2'd3


`endif