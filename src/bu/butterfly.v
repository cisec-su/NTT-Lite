`include "ntt_lite.vh"

module butterfly
   #(
        parameter LOGQ   = 32,
        parameter L      = 12
    )
    (
        input                clk ,

        input  [        3:0] op  ,
        input  [        1:0] mode,
        input  [LOGQ   -1:0] A   ,
        input  [LOGQ   -1:0] B   ,
        input  [LOGQ   -1:0] PSI ,
        input  [LOGQ   -1:0] Q   ,
        input  [LOGQ   +1:0] MU  ,
        input  [LOGQ   -1:0] inv2,
        input  [LOGLOGQ-1:0] logq,
        input  [LOGLOGQ-1:0] d   ,
        output [LOGQ   -1:0] E   ,
        output [LOGQ   -1:0] O   ,
        output [LOGQ   -1:0] M
    );


localparam LOGLOGQ = $rtoi($ceil($clog2(LOGQ + 1)));
localparam LOGQ0   = LOGQ >> 1;
localparam LOGT    = LOGQ << 1;


wire [LOGQ -1:0] mm_in_A;
wire [LOGQ -1:0] mm_in_B;
wire [LOGQ -1:0] mm_in_E;
wire [LOGQ -1:0] mm_out_C;
wire [LOGT -1:0] mm_out_T;
wire [LOGT -1:0] mm_out_D;
wire [LOGQ -1:0] add_in_A;
wire [LOGQ -1:0] add_in_B;
wire [LOGQ -1:0] add_out_C;
wire [LOGQ -1:0] sub_in_A;
wire [LOGQ -1:0] sub_in_B;
wire [LOGQ -1:0] sub_out_C;
wire [LOGQ -1:0] shift_in_0;
wire [LOGQ -1:0] shift_out_0;
wire [LOGQ -1:0] shift_in_1;
wire [LOGQ -1:0] shift_out_1;
wire [LOGT -1:0] asr_in;
wire [LOGT -1:0] asr_out;
wire [LOGQ -1:0] asr_out_dual;
wire [LOGQ -1:0] mm_inv2_in;
wire [LOGQ -1:0] mm_inv2_out;
wire [      1:0] mode_mul;
wire             dual;
wire [LOGQ -1:0] q_dual;
wire [LOGQ -1:0] q_half_dual;
wire [LOGQ -1:0] psi_dual;
wire [LOGQ -1:0] pow_2_d;
wire [LOGQ -1:0] pow_2_d_dual;
wire [LOGQ -1:0] pow_2_d_shift_dual;
wire [LOGQ -1:0] D_dual;


assign mode_mul    = (mode == `MODE_POLY && op != `OP_PWM) ? `MODE_DUAL : 
                                                              mode      ;
assign dual        =  mode == `MODE_DUAL || mode == `MODE_POLY;
assign q_dual      = (dual) ? {Q[LOGQ0-1:0], Q[LOGQ0-1:0]} : 
                               Q                           ;
assign q_half_dual = (dual) ? {Q[LOGQ0-1:0] >> 1, Q[LOGQ0-1:0] >> 1} : 
                               Q >> 1                                ;
assign psi_dual    = ((op == `OP_NTT || op == `OP_INTT) && dual) ? {PSI[LOGQ0-1:0], PSI[LOGQ0-1:0]} : 
                                                                    PSI                             ;
assign asr_out_dual = (dual) ? {asr_out[LOGQ+LOGQ0-1:LOGQ], asr_out[LOGQ0-1:0]} : 
                                asr_out                                         ;

assign pow_2_d     = ({{(LOGQ-1){1'b0}}, 1'b1} << d);

assign pow_2_d_dual = (dual) ? {pow_2_d[LOGQ0-1:0], pow_2_d[LOGQ0-1:0]} : 
                                pow_2_d                                 ;

assign pow_2_d_shift_dual = (dual) ? {pow_2_d[LOGQ0-1:0] >> 1, pow_2_d[LOGQ0-1:0] >> 1} : 
                                      pow_2_d >> 1;

assign D_dual      = (dual) ? {mm_out_D[LOGQ+LOGQ0-1:LOGQ], mm_out_D[LOGQ0-1:0]} : 
                               mm_out_D                                          ;


assign mm_in_A     = (op == `OP_INTT                          ) ? sub_out_C          : 
                                                                  B                  ;
assign mm_in_B     = (op == `OP_COMPRESS                      ) ? pow_2_d_dual       :
                     (op == `OP_DECOMPRESS                    ) ? q_dual             : 
                                                                  psi_dual           ;
assign mm_in_E     = (op == `OP_COMPRESS                      ) ? q_half_dual        :
                     (op == `OP_DECOMPRESS                    ) ? pow_2_d_shift_dual :
                                                                  {LOGQ{1'b0}}       ;

assign add_in_A    = (op == `OP_INTT || op == `OP_ADD) ? A              :
                                                         shift_out_1    ;
assign add_in_B    = (op == `OP_INTT                 ) ? B              : 
                     (op == `OP_ADD                  ) ? PSI            :
                                                         mm_out_C       ;
assign sub_in_A    = (op == `OP_INTT || op == `OP_SUB) ? A              : 
                                                         shift_out_1    ;
assign sub_in_B    = (op == `OP_INTT                 ) ? B              : 
                     (op == `OP_SUB                  ) ? PSI            : 
                                                         mm_out_C       ;
assign shift_in_0  = (op == `OP_INTT                 ) ? add_out_C      : 
                                                         A              ;
assign shift_in_1  = (op == `OP_INTT                 ) ? mm_inv2_out    : 
                                                         shift_out_0    ;

assign mm_inv2_in  = shift_out_0;

assign asr_in      = mm_out_T;

assign E           = (op == `OP_INTT) ? shift_out_1 :
                                        add_out_C   ;
assign O           = (op == `OP_INTT) ? mm_out_C    :
                                        sub_out_C   ;
assign M           = (op == `OP_ADD       ) ? add_out_C    :
                     (op == `OP_SUB       ) ? sub_out_C    :
                     (op == `OP_COMPRESS  ) ? D_dual       :
                     (op == `OP_DECOMPRESS) ? asr_out_dual :
                     /*                  */   mm_out_C     ;


shiftreg #(
    .SHIFT(1   ),
    .DATA (LOGQ)
) sre_0 (
    .clk     (clk        ),
    .rst     (1'b0       ),
    .data_in (shift_in_0 ),
    .data_out(shift_out_0)
);


shiftreg #(
    .SHIFT(L - 1),
    .DATA (LOGQ )
) sre_1 (
    .clk     (clk        ),
    .rst     (1'b0       ),
    .data_in (shift_in_1 ),
    .data_out(shift_out_1)
);


modmul #(
    .LOGQ(LOGQ)
) mm (
    .clk (clk     ),
    .mode(mode_mul),
    .Q   (Q       ),
    .MU  (MU      ),
    .logq(logq    ),
    .A   (mm_in_A ),
    .B   (mm_in_B ),
    .E   (mm_in_E ),
    .C   (mm_out_C),
    .T   (mm_out_T),
    .D   (mm_out_D)
);


modadd  #(
    .LOGQ(LOGQ)
) ma (
    .A   (add_in_A ),
    .B   (add_in_B ),
    .dual(dual     ),
    .q   (q_dual   ),
    .C   (add_out_C) 
);


modsub #(
    .LOGQ(LOGQ)
) ms (
    .A   (sub_in_A ),
    .B   (sub_in_B ),
    .dual(dual     ),
    .q   (q_dual   ),
    .C   (sub_out_C)
);


asr #(
    .LOGQ(LOGT)
) asr (
    .A   (asr_in  ),
    .d   ({1'b0,d}),
    .dual(dual    ),
    .C   (asr_out )
);


modmul_inv2 #(
    .LOGQ(LOGQ)
) mm_inv2 (
    .A   (mm_inv2_in ),
    .inv2(inv2       ),
    .q   (q_dual     ),
    .dual(dual       ),
    .C   (mm_inv2_out)
);


endmodule




