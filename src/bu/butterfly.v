`include "ntt_lite.vh"

module butterfly
   #(
        parameter LOGQ   = 32,
        parameter L      = 12
    )
    (
        input                clk      ,

        input  [        3:0] op       ,
        input  [        1:0] mode     ,
        input                floor    ,
        input                mode_p2d ,
        input                en_z     ,
        input  [LOGQ   -1:0] A        ,
        input  [LOGQ   -1:0] B        ,
        input  [LOGQ   -1:0] PSI      ,
        input  [LOGQ   -1:0] Q        ,
        input  [LOGQ*2 -1:0] MU       ,
        input  [LOGQ   -1:0] inv2     ,
        input  [LOGQ   -1:0] bound    ,
        input  [LOGLOGQ-1:0] k        ,
        input  [LOGLOGQ-1:0] d        ,
        output [LOGQ   -1:0] E        ,
        output               chknorm  ,
        output [LOGQ   -1:0] O        ,
        output [LOGQ   -1:0] M
    );


localparam LOGLOGQ = $rtoi($ceil($clog2(LOGQ + 1)));
localparam LOGQ0   = LOGQ >> 1;
localparam LOGT    = LOGQ << 1;


wire [LOGQ -1:0] mm_in_A;
wire [LOGQ -1:0] mm_in_Q;
wire [LOGQ -1:0] mm_in_B;
wire [LOGQ0-1:0] mm_in_Z;
wire [LOGQ -1:0] mm_in_E;
wire [LOGQ -1:0] mm_out_C;
wire [LOGT -1:0] mm_out_T;
wire [LOGT -1:0] mm_out_D;
wire [LOGQ -1:0] add_in_A;
wire [LOGQ -1:0] add_in_B;
wire [LOGQ -1:0] add_out_C;
wire [LOGQ -1:0] sub_in_A;
wire [LOGQ -1:0] sub_in_B;
wire [LOGQ -1:0] sub_in_Q;
wire [LOGQ -1:0] sub_out_C;
wire [LOGQ -1:0] shift_in_0;
wire [LOGQ -1:0] shift_out_0;
wire [LOGQ -1:0] shift_in_1;
wire [LOGQ -1:0] shift_out_1;
wire [LOGT -1:0] asr_in;
wire [LOGT -1:0] asr_out;
wire [LOGQ -1:0] asr_out_dual;
wire [LOGQ -1:0] asr_out_dual_masked;
wire [LOGQ -1:0] mm_inv2_in;
wire [LOGQ -1:0] mm_inv2_out;
wire [      1:0] mode_mul;
wire             dual;
wire [LOGQ -1:0] Q_dual;
wire [LOGQ*2-1:0] MU_dual;
wire [LOGQ -1:0] Q_half_dual;
wire [LOGQ -1:0] bound_half;
wire [LOGQ -1:0] psi_dual;
wire [LOGQ -1:0] pow_2_d;
wire [LOGQ -1:0] pow_2_d_dual;
wire [LOGQ -1:0] pow_2_d_shift_dual;
wire [LOGQ -1:0] mask_d;
wire [LOGQ -1:0] mask_d_dual;
wire [LOGQ -1:0] mask_k;
wire [LOGQ -1:0] mask_k_dual;
wire [LOGQ -1:0] D_dual;
wire [LOGQ -1:0] D_dual_masked;
wire [LOGQ -1:0] one_dual;
wire             sub_out_corr;

wire [LOGQ -1:0] decompose_pp_in_A0;
wire [LOGQ -1:0] decompose_pp_in_A1;
wire [LOGQ -1:0] decompose_pp_in_T;
wire [LOGQ -1:0] decompose_pp_out_B0;
wire [LOGQ -1:0] decompose_pp_out_B1;

wire makehint_specialcase;
wire hint;

wire [LOGQ-1:0] E_int;
wire [LOGQ-1:0] O_int;
wire [LOGQ-1:0] M_int;

reg [LOGQ-1:0] E_q;
reg [LOGQ-1:0] O_q;
reg [LOGQ-1:0] M_q;


assign mode_mul    = (mode == `MODE_POLY && op != `OP_PWM) ? `MODE_DUAL :
                     (mode_p2d                           ) ? `MODE_DUAL :
                                                              mode      ;
assign dual        =  mode == `MODE_DUAL || mode == `MODE_POLY;
assign Q_dual      = (dual) ? {Q[LOGQ0-1:0], Q[LOGQ0-1:0]} : 
                               Q                           ;
assign Q_half_dual = (dual) ? {Q[LOGQ0-1:0] >> 1, Q[LOGQ0-1:0] >> 1} : 
                               Q >> 1                                ;
assign bound_half  = (bound >> 1) - 1'b1;
assign MU_dual     = (dual) ? {MU[LOGQ-1:0], MU[LOGQ-1:0]} :
                               MU                          ;
assign psi_dual    = ((op == `OP_NTT || op == `OP_INTT) && dual) ? {PSI[LOGQ0-1:0], PSI[LOGQ0-1:0]} : 
                                                                    PSI                             ;

assign one_dual     = (dual) ? {{(LOGQ0-1){1'b0}}, 1'b1, {(LOGQ0-1){1'b0}}} : 
                               {1'b1}                                       ;

assign asr_out_dual = (dual) ? {asr_out[LOGQ+LOGQ0-1:LOGQ], asr_out[LOGQ0-1:0]} : 
                                asr_out                                         ;

assign pow_2_d     = ({{(LOGQ-1){1'b0}}, 1'b1} << d);

assign pow_2_d_dual = (dual) ? {pow_2_d[LOGQ0-1:0], pow_2_d[LOGQ0-1:0]} : 
                                pow_2_d                                 ;

assign pow_2_d_shift_dual = (dual) ? {pow_2_d[LOGQ0-1:0] >> 1, pow_2_d[LOGQ0-1:0] >> 1} : 
                                      pow_2_d >> 1;

assign mask_d = pow_2_d - 1'b1;
assign mask_d_dual = (dual) ? {mask_d[LOGQ0-1:0], mask_d[LOGQ0-1:0]} : 
                               mask_d                                ;

assign mask_k      = (k == 0) ?  {LOGQ{1'b1}}                          : 
                                 ({{(LOGQ-1){1'b0}}, 1'b1} << k) - 1'b1;
assign mask_k_dual = (dual) ?    {mask_k[LOGQ0-1:0], mask_k[LOGQ0-1:0]} : 
                                  mask_k                                ;


assign D_dual      = (dual) ? {mm_out_D[LOGQ+LOGQ0-1:LOGQ], mm_out_D[LOGQ0-1:0]} : 
                               mm_out_D                                          ;
assign D_dual_masked = D_dual & mask_d_dual;

assign mm_in_A     = (op == `OP_INTT                          ) ? sub_out_C          : 
                                                                  B                  ;
assign mm_in_B     = (op == `OP_DECOMPOSE                     ) ? one_dual           :
                     (op == `OP_COMPRESS                      ) ? pow_2_d_dual       :
                     (op == `OP_DECOMPRESS                    ) ? Q_dual             : 
                                                                  psi_dual           ;
assign mm_in_E     = (floor                                   ) ? {LOGQ{1'b0}}       :
                     (op == `OP_DECOMPOSE                     ) ? bound_half         :
                     (op == `OP_COMPRESS                      ) ? Q_half_dual        :
                     (op == `OP_DECOMPRESS                    ) ? pow_2_d_shift_dual :
                                                                  {LOGQ{1'b0}}       ;
assign mm_in_Z     = A[LOGQ-1:LOGQ0];
assign mm_in_Q     = (op == `OP_DECOMPOSE                     ) ? bound              : 
                                                                  Q_dual             ;
assign add_in_A    = (op == `OP_INTT || op == `OP_ADD) ? A              :
                     (op == `OP_SUM                  ) ? A              :
                     (op == `OP_CHKNORM              ) ? A              :
                     (op == `OP_MAKEHINT             ) ? A              :
                                                         shift_out_1    ;
assign add_in_B    = (op == `OP_INTT                 ) ? B              :
                     (op == `OP_SUM                  ) ? B              : 
                     (op == `OP_ADD                  ) ? PSI            :
                     (op == `OP_CHKNORM              ) ? bound          :
                     (op == `OP_MAKEHINT             ) ? bound          :
                                                         mm_out_C       ;
assign sub_in_A    = (op == `OP_INTT || op == `OP_SUB) ? A              :
                     (op == `OP_DECOMPOSE            ) ? mm_out_C       :
                     (op == `OP_CHKNORM              ) ? bound << 1     :
                     (op == `OP_MAKEHINT             ) ? bound << 1     :
                                                         shift_out_1    ;
assign sub_in_B    = (op == `OP_INTT                 ) ? B              : 
                     (op == `OP_DECOMPOSE            ) ? bound_half     : 
                     (op == `OP_CHKNORM              ) ? add_out_C      :
                     (op == `OP_MAKEHINT             ) ? add_out_C      :
                     (op == `OP_SUB                  ) ? PSI            : 
                                                         mm_out_C       ;
assign sub_in_Q    = (op == `OP_DECOMPOSE            ) ? bound          : 
                                                         Q_dual         ;                                                         
assign shift_in_0  = (op == `OP_INTT                 ) ? add_out_C      : 
                                                         A              ;
assign shift_in_1  = (op == `OP_INTT                 ) ? mm_inv2_out    : 
                                                         shift_out_0    ;

assign decompose_pp_in_A0 = sub_out_C;
assign decompose_pp_in_A1 = mm_out_D;
assign decompose_pp_in_T  = bound;

assign chknorm = sub_out_corr;
assign makehint_specialcase = (A == inv2 && PSI != 0);
assign hint = chknorm | makehint_specialcase;

assign mm_inv2_in  = shift_out_0;

assign asr_in      = mm_out_T;

assign asr_out_dual_masked = asr_out_dual & mask_k_dual;

assign E_int       = (op == `OP_INTT      ) ? shift_out_1          :
                     (op == `OP_DECOMPOSE ) ? decompose_pp_out_B1  :                     
                                              add_out_C            ;
assign O_int       = (op == `OP_INTT) ? mm_out_C    :
                                        sub_out_C   ;
assign M_int       = (op == `OP_ADD       ) ? add_out_C            :
                     (op == `OP_SUM       ) ? add_out_C            :
                     (op == `OP_SUB       ) ? sub_out_C            :
                     (op == `OP_COMPRESS  ) ? D_dual_masked        :
                     (op == `OP_DECOMPRESS) ? asr_out_dual_masked  :
                     (op == `OP_DECOMPOSE ) ? decompose_pp_out_B0  :
                     (op == `OP_MAKEHINT  ) ? hint                 :
                     /*                  */   mm_out_C             ;

assign E = E_q;
assign O = O_q;
assign M = M_q;


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
    .en_z(en_z    ),
    .Q   (mm_in_Q ),
    .MU  (MU_dual ),
    .A   (mm_in_A ),
    .B   (mm_in_B ),
    .E   (mm_in_E ),
    .Z   (mm_in_Z ),
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
    .Q   (Q_dual   ),
    .C   (add_out_C) 
);


modsub #(
    .LOGQ(LOGQ)
) ms (
    .A   (sub_in_A ),
    .B   (sub_in_B ),
    .dual(dual     ),
    .Q   (sub_in_Q ),
    .corr(sub_out_corr),
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
    .Q   (Q_dual     ),
    .dual(dual       ),
    .C   (mm_inv2_out)
);


decompose_pp #(
    .LOGQ(LOGQ)
) decompose_pp_0 (
    .A0  (decompose_pp_in_A0 ),
    .A1  (decompose_pp_in_A1 ),
    .T   (decompose_pp_in_T  ),
    .sc  (inv2               ),
    .q   (Q_dual             ),
    .B0  (decompose_pp_out_B0),
    .B1  (decompose_pp_out_B1)
);


always @(posedge clk) begin
    E_q <= E_int;
    O_q <= O_int;
    M_q <= M_int;
end


endmodule




