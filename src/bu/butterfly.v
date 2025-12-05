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
        output [LOGQ   -1:0] O
    );


localparam LOGLOGQ = $clog2(LOGQ + 1);
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
wire [LOGQ -1:0] Q_half;
wire [LOGQ -1:0] bound_half;
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
reg  makehint_specialcase_q;
wire hint;

wire [LOGQ-1:0] E_int;
wire [LOGQ-1:0] O_int;


reg [LOGQ-1:0] E_q;
reg [LOGQ-1:0] O_q;
reg [LOGQ-1:0] M_q;


reg [LOGQ-1:0] A_q;
reg [LOGQ-1:0] B_q;
reg [LOGQ-1:0] PSI_q;

reg [LOGQ-1:0] Q_q;
reg [LOGQ*2-1:0] MU_q;
reg [LOGQ-1:0] bound_q;
reg [LOGQ-1:0] inv2_q;

reg [LOGLOGQ-1:0] k_q;
reg [LOGLOGQ-1:0] d_q;

reg [LOGT-1:0] mm_out_D_q;

reg [3:0] op_q;
reg [1:0] mode_q;
reg floor_q;



assign mode_mul    = (mode_q == `MODE_POLY && op_q != `OP_PWM) ? `MODE_DUAL :
                     (mode_p2d                               ) ? `MODE_DUAL :
                                                                mode_q      ;
assign dual        =  mode_q == `MODE_DUAL || mode_q == `MODE_POLY;

assign Q_half      = (dual) ? {Q_q[LOGQ0-1:0] >> 1, Q_q[LOGQ0-1:0] >> 1} : 
                               Q_q >> 1                                  ;
assign bound_half  = (bound_q - 1'b1) >> 1;

assign one_dual     = (dual) ? {{(LOGQ0-1){1'b0}}, 1'b1, {(LOGQ0-1){1'b0}}} : 
                               {1'b1}                                       ;

assign asr_out_dual = (dual) ? {asr_out[LOGQ+LOGQ0-1:LOGQ], asr_out[LOGQ0-1:0]} : 
                                asr_out                                         ;

assign pow_2_d     = ({{(LOGQ-1){1'b0}}, 1'b1} << d_q);

assign pow_2_d_dual = (dual) ? {pow_2_d[LOGQ0-1:0], pow_2_d[LOGQ0-1:0]} : 
                                pow_2_d                                 ;

assign pow_2_d_shift_dual = (dual) ? {pow_2_d[LOGQ0-1:0] >> 1, pow_2_d[LOGQ0-1:0] >> 1} : 
                                      pow_2_d >> 1;

assign mask_d = pow_2_d - 1'b1;
assign mask_d_dual = (dual) ? {mask_d[LOGQ0-1:0], mask_d[LOGQ0-1:0]} : 
                               mask_d                                ;

assign mask_k      = (k_q == 0) ?  {LOGQ{1'b1}}                          : 
                                 ({{(LOGQ-1){1'b0}}, 1'b1} << k_q) - 1'b1;
assign mask_k_dual = (dual) ?    {mask_k[LOGQ0-1:0], mask_k[LOGQ0-1:0]} : 
                                  mask_k                                ;


assign D_dual      = (dual) ? {mm_out_D[LOGQ+LOGQ0-1:LOGQ], mm_out_D[LOGQ0-1:0]} : 
                               mm_out_D                                          ;
assign D_dual_masked = D_dual & mask_d_dual;

assign mm_in_A     = (op_q == `OP_INTT                          ) ? sub_out_C          : 
                                                                    B_q                ;
assign mm_in_B     = (op_q == `OP_DECOMPOSE                     ) ? one_dual           :
                     (op_q == `OP_COMPRESS                      ) ? pow_2_d_dual       :
                     (op_q == `OP_DECOMPRESS                    ) ? Q_q                : 
                                                                    PSI_q              ;
assign mm_in_E     = (floor_q                                   ) ? {LOGQ{1'b0}}       :
                     (op_q == `OP_DECOMPOSE                     ) ? bound_half         :
                     (op_q == `OP_COMPRESS                      ) ? Q_half             :
                     (op_q == `OP_DECOMPRESS                    ) ? pow_2_d_shift_dual :
                                                                  {LOGQ{1'b0}}       ;
assign mm_in_Z     = A_q[LOGQ-1:LOGQ0];
assign mm_in_Q     = (op_q == `OP_DECOMPOSE                     ) ? bound_q              : 
                                                                    Q_q                  ;
assign add_in_A    = (op_q == `OP_INTT || op_q == `OP_ADD) ? A_q            :
                     (op_q == `OP_SUM                    ) ? A_q            :
                     (op_q == `OP_CHKNORM                ) ? A_q            :
                     (op_q == `OP_MAKEHINT               ) ? A_q            :
                                                             shift_out_1    ;
assign add_in_B    = (op_q == `OP_INTT                 ) ? B_q            :
                     (op_q == `OP_SUM                  ) ? B_q            : 
                     (op_q == `OP_ADD                  ) ? PSI_q          :
                     (op_q == `OP_CHKNORM              ) ? bound_q        :
                     (op_q == `OP_MAKEHINT             ) ? bound_q        :
                                                           mm_out_C       ;
assign sub_in_A    = (op_q == `OP_INTT || op_q == `OP_SUB) ? A_q            :
                     (op_q == `OP_DECOMPOSE              ) ? mm_out_C       :
                     (op_q == `OP_CHKNORM                ) ? bound_q << 1   :
                     (op_q == `OP_MAKEHINT               ) ? bound_q << 1   :
                                                             shift_out_1    ;
assign sub_in_B    = (op_q == `OP_INTT                 ) ? B_q            : 
                     (op_q == `OP_DECOMPOSE            ) ? bound_half     : 
                     (op_q == `OP_CHKNORM              ) ? shift_out_0    :
                     (op_q == `OP_MAKEHINT             ) ? shift_out_0    :
                     (op_q == `OP_SUB                  ) ? PSI_q          : 
                                                           mm_out_C       ;
assign sub_in_Q    = Q_q;

assign shift_in_0  = (op_q == `OP_INTT                 ) ? add_out_C      :
                     (op_q == `OP_CHKNORM              ) ? add_out_C      :
                     (op_q == `OP_MAKEHINT             ) ? add_out_C      :
                     (op_q == `OP_DECOMPOSE            ) ? sub_out_C      :
                                                           A_q            ;
assign shift_in_1  = (op_q == `OP_INTT                 ) ? mm_inv2_out    : 
                                                           shift_out_0    ;

assign decompose_pp_in_A0 = shift_out_0;
assign decompose_pp_in_A1 = mm_out_D_q;
assign decompose_pp_in_T  = bound_q;

assign chknorm = sub_out_corr;
assign makehint_specialcase = (A_q == inv2_q && PSI_q != 0);
assign hint = chknorm | makehint_specialcase_q;

assign mm_inv2_in  = shift_out_0;

assign asr_in      = mm_out_T;

assign asr_out_dual_masked = asr_out_dual & mask_k_dual;

assign E_int       = (op_q == `OP_INTT      ) ? shift_out_1          :
                     (op_q == `OP_ADD       ) ? add_out_C            :
                     (op_q == `OP_SUM       ) ? add_out_C            :
                     (op_q == `OP_SUB       ) ? sub_out_C            :
                     (op_q == `OP_COMPRESS  ) ? D_dual_masked        :
                     (op_q == `OP_DECOMPRESS) ? asr_out_dual_masked  :
                     (op_q == `OP_DECOMPOSE ) ? decompose_pp_out_B0  :
                     (op_q == `OP_MAKEHINT  ) ? hint                 :
                     (op_q == `OP_CHKNORM   ) ? chknorm              :
                     (op_q == `OP_PWM       ) ? mm_out_C             :
                    /*op_q == `OP_NTT        */ add_out_C            ;
assign O_int       = (op_q == `OP_INTT      ) ? mm_out_C             :
                     (op_q == `OP_DECOMPOSE ) ? decompose_pp_out_B1  :
                    /*op_q == `OP_NTT        */ sub_out_C            ;

assign E = E_q;
assign O = O_q;


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
    .MU  (MU_q    ),
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
    .Q   (Q_q      ),
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
    .A   (asr_in    ),
    .d   ({1'b0,d_q}),
    .dual(dual      ),
    .C   (asr_out   )
);


modmul_inv2 #(
    .LOGQ(LOGQ)
) mm_inv2 (
    .A   (mm_inv2_in ),
    .inv2(inv2_q     ),
    .Q   (Q_q        ),
    .dual(dual       ),
    .C   (mm_inv2_out)
);


decompose_pp #(
    .LOGQ(LOGQ)
) decompose_pp_0 (
    .A0  (decompose_pp_in_A0 ),
    .A1  (decompose_pp_in_A1 ),
    .T   (decompose_pp_in_T  ),
    .sc  (inv2_q             ),
    .q   (Q_q                ),
    .B0  (decompose_pp_out_B0),
    .B1  (decompose_pp_out_B1)
);

always @(posedge clk) begin
    A_q   <= A;
    B_q   <= B;
    PSI_q <= PSI;
end


always @(posedge clk) begin
    op_q    <= op;
    mode_q  <= mode;
    floor_q <= floor;
end


always @(posedge clk) begin
    Q_q     <= Q;
    MU_q    <= MU;
    bound_q <= bound;
    inv2_q  <= inv2;
    k_q     <= k;
    d_q     <= d;
end



always @(posedge clk) begin
    E_q <= E_int;
    O_q <= O_int;
end


always @(posedge clk) begin
    mm_out_D_q <= mm_out_D;
end


always @(posedge clk) begin
    makehint_specialcase_q <= makehint_specialcase;
end


endmodule




