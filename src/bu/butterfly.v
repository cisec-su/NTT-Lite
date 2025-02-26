`include "ntt_lite.vh"
module butterfly
   #(
        parameter LOGQ   = 32,
        parameter MUL_OP = 16,
        parameter L      = 12
    )
    (
        input                clk ,

        input  [        1:0] mode,
        input                dual,
        input  [LOGQ   -1:0] A   ,
        input  [LOGQ   -1:0] B   ,
        input  [LOGQ   -1:0] PSI ,
        input  [LOGQ   -1:0] Q   ,
        input  [LOGQ   +1:0] MU  ,
        input  [LOGLOGQ-1:0] logq,

        output [LOGQ   -1:0] E   ,
        output [LOGQ   -1:0] O   ,
        output [LOGQ   -1:0] M
    );


localparam LOGLOGQ = $rtoi($ceil($clog2(LOGQ + 1)));


wire [LOGQ -1:0] A_shift;
wire [LOGQ -1:0] MM;

wire [LOGQ -1:0] MM_in_A;
wire [LOGQ -1:0] MM_in_B;
wire [LOGQ -1:0] MM_out_C;
wire [LOGQ -1:0] add_in_A;
wire [LOGQ -1:0] add_in_B;
wire [LOGQ -1:0] add_out_C;
wire [LOGQ -1:0] sub_in_A;
wire [LOGQ -1:0] sub_in_B;
wire [LOGQ -1:0] sub_out_C;
wire [LOGQ -1:0] shift_in;
wire [LOGQ -1:0] shift_out;


assign MM_in_A     = (mode == `MODE_INTT) ? sub_out_C : B;
assign MM_in_B     = PSI;
assign add_in_A    = (mode == `MODE_INTT) ? A : shift_out;
assign add_in_B    = (mode == `MODE_INTT) ? B : MM_out_C;
assign sub_in_A    = (mode == `MODE_INTT) ? A : shift_out;
assign sub_in_B    = (mode == `MODE_INTT) ? B : MM_out_C;
assign E           = (mode == `MODE_INTT) ? shift_out : add_out_C;
assign O           = (mode == `MODE_INTT) ? MM_out_C : sub_out_C;
assign shift_in    = (mode == `MODE_INTT) ? add_out_C : A;
assign M           = MM_out_C;


shiftreg #(
    .SHIFT(L   ),
    .DATA (LOGQ)
) sre10(
    .clk     (clk      ),
    .rst     (1'b0     ),
    .data_in (shift_in ),
    .data_out(shift_out)
);


modmul #(
    .LOGQ   (LOGQ  ),
    .MUL_OP (MUL_OP)
) mm0 (
    .clk (clk      ),
    .dual(dual     ),
    .Q   (Q        ),
    .MU  (MU       ),
    .logq(logq     ),
    .A   (MM_in_A  ),
    .B   (MM_in_B  ),
    .C   (MM_out_C )
);


modadd  #(
    .LOGQ   (LOGQ),
    .LOGQH  (LOGQ),
    .LOGQH_DUAL (LOGQ >> 1),
    .EN_DUAL(1   ),
    .FF_IN  (0   ),
    .FF_ADD (0   ),
    .FF_OUT (0   )
) ma (
    .A   (add_in_A ),
    .B   (add_in_B ),
    .dual(dual     ),
    .qH  (Q        ),
    .C   (add_out_C) 
);


modsub #(
    .LOGQ   (LOGQ),
    .LOGQH  (LOGQ),
    .LOGQH_DUAL (LOGQ >> 1),
    .EN_DUAL(1   ),
    .FF_IN  (0   ),
    .FF_SUB (0   ),
    .FF_OUT (0   )
) ms (
    .A   (sub_in_A ),
    .B   (sub_in_B ),
    .dual(dual     ),
    .qH  (Q        ),
    .C   (sub_out_C)
);


endmodule




