`include "poly_acc.vh"

module butterfly
   #(
        parameter  int unsigned LOGQ            = 32,
        parameter  int unsigned L_MUL           = 6 ,
        parameter  int unsigned L_RED           = 6 ,
        parameter  int unsigned FF_MODADD_IN    = 1 ,
        parameter  int unsigned FF_MODADD_OUT   = 1 ,
        parameter  int unsigned FF_INTMUL_MUL   = 1 ,
        parameter  int unsigned FF_MODRED_MUL   = 1 ,
        parameter  int unsigned FF_BARRETT_KR_SUM0 = 0 ,
        parameter  int unsigned FF_BARRETT_KR_SUB0 = 0 ,
        parameter  int unsigned FF_BARRETT_KR_MUL  = 1 ,
        parameter  int unsigned FF_BARRETT_KR_SUM1 = 0 ,
        parameter  int unsigned FF_BARRETT_KR_SUM2 = 1 ,
        parameter  int unsigned FF_BARRETT_KR_SUB1 = 0 ,
        parameter  int unsigned FF_BARRETT_NEG     = 0 ,
        parameter  int unsigned FF_HINT            = 0 ,
        parameter  int unsigned FF_SC              = 0 ,
        parameter  bit          KYBER_EN           = 1 ,
        parameter  bit          DILITHIUM_EN       = 1 ,
        parameter  bit          FALCON_EN          = 1 ,
        localparam LOGLOGQ = $clog2(LOGQ + 1)
    )
    (
        input                clk      ,

        input                i_valid  ,
        input  [        4:0] op       ,
        input  [        1:0] mode     ,
        input  [        1:0] round    ,
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
        output reg           o_valid  ,
        output wire          busy     ,
        output [LOGQ   -1:0] E        ,
        output [LOGQ   -1:0] O        ,
        output               chknorm
    );

localparam int unsigned LAT_MUL    = L_MUL + FF_INTMUL_MUL;
localparam int unsigned LAT_RED    = L_RED + FF_MODRED_MUL + FF_BARRETT_KR_SUM0 + FF_BARRETT_KR_SUB0 + 
                                     FF_BARRETT_KR_MUL + FF_BARRETT_KR_SUM1 + FF_BARRETT_KR_SUM2 + FF_BARRETT_KR_SUB1 + 
                                     FF_BARRETT_NEG;
localparam int unsigned LAT_MODADD = FF_MODADD_IN + FF_MODADD_OUT;


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
wire [LOGQ -1:0] mm_out_F;
wire [LOGT-1:0]  MU_int;
wire [LOGQ -1:0] add_in_A;
wire [LOGQ -1:0] add_in_B;
wire [LOGQ -1:0] add_out_C;
wire             add_rd_en;
wire [LOGQ -1:0] sub_in_A;
wire [LOGQ -1:0] sub_in_B;
wire [LOGQ -1:0] sub_out_C;
wire             sub_rd_en;
wire [LOGQ -1:0] shift_in_0;
wire [LOGQ -1:0] shift_out_0;
wire [LOGQ -1:0] shift_in_1;
wire [LOGQ -1:0] shift_out_1;
wire [LOGQ -1:0] shift_in_3;
wire [LOGQ -1:0] shift_out_3;
wire [LOGQ -1:0] shift_in_2;
wire [LOGQ -1:0] shift_out_2;
wire [LOGQ -1:0] mm_inv2_in;
wire [LOGQ -1:0] mm_inv2_out;
wire [      1:0] mode_mul;
wire             dual;
wire [LOGQ -1:0] Q_half;
wire [LOGQ -1:0] Q1_half;
wire             sub_out_corr;

wire [LOGQ -1:0] specialcase_checker_in_A0;
wire [LOGQ -1:0] specialcase_checker_in_A1;
wire [LOGQ -1:0] specialcase_checker_in_S;
wire [LOGQ -1:0] specialcase_checker_out_B0;
wire [LOGQ -1:0] specialcase_checker_out_B1;
wire specialcase_checker_out_sc;

wire makehint_specialcase;
wire makehint_specialcase_d;
wire hint;

wire [LOGQ -1:0] use_hint_B;

wire [LOGQ-1:0] PSI_d;

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
// reg [LOGQ-1:0] bound_q;
reg [LOGQ-1:0] inv2_q;

reg [4:0] op_q;
reg [1:0] mode_q;
reg [1:0] round_q;
reg en_z_q;

wire [LOGQ-1:0] PSI2;

wire chknorm_int;
reg  chknorm_q;
reg  hint_q;

wire o_valid_mul, o_valid_add, o_valid_addsub, o_valid_ntt, i_valid_ntt;
wire o_valid_makehint, o_valid_usehint;

reg is_ntt_q;
reg is_intt_q;
reg is_add_q;
reg is_sub_q;
reg is_pwm_q;
reg is_mac_q;
reg is_sum_q;
reg is_make_hint_q;
reg is_use_hint_q;
reg is_tocenter_q;
reg is_fromcenter_q;
reg is_decompose_q;
reg is_chk_l1norm_q;
reg is_chk_infnorm_q;
reg is_compress_q;
reg is_sqadd_q;



assign mode_mul    = (mode_q == `MODE_POLY && (!is_pwm_q && !is_sqadd_q && !is_mac_q)) ? `MODE_DUAL   :
                     (en_z_q                                                         ) ? `MODE_SINGLE :
                                                                                          mode_q      ;

assign dual        =  mode_q == `MODE_DUAL || mode_q == `MODE_POLY;

assign Q_half      = (dual) ? {Q_q[LOGQ0-1:0] >> 1, Q_q[LOGQ0-1:0] >> 1} : 
                               Q_q >> 1                                  ;
assign Q1_half     = (dual) ? {(Q_q[LOGQ0-1:0] - 1'b1) >> 1, (Q_q[LOGQ0-1:0] - 1'b1) >> 1} : 
                               (Q_q - 1'b1) >> 1                                  ;

assign PSI2        = (dual) ? {(PSI_d[LOGQ-1:LOGQ0] << 1) + 1, (PSI_d[LOGQ0-1:0] << 1) + 1} : 
                               (PSI_d << 1) + 1'b1                                          ;

assign MU_int      = (dual && !en_z_q) ? {MU_q[LOGT-1:LOGQ], MU_q[LOGT-1:LOGQ]} : MU_q;

assign mm_in_A     = (is_intt_q                          ) ? sub_out_C          : 
                                                             B_q                ;
assign mm_in_B     = (is_sqadd_q        && !en_z_q       ) ? B_q                :
                     (is_intt_q                          ) ? PSI_d              :
                                                             PSI_q              ;
assign mm_in_E     = (is_mac_q && !en_z_q                       ) ?   A_q           :
                     (round_q == `ROUND_HALFDOWN                ) ?   Q1_half       :
                     (round_q == `ROUND_HALFUP                  ) ?   Q_half        :
                   /*(round_q == `ROUND_FLOOR                   ) ?*/ {LOGQ{1'b0}}  ;

assign mm_in_Z     = A_q[LOGQ-1:LOGQ0];
assign mm_in_Q     = (en_z_q                                    ) ? Q_q[LOGQ0-1:0]       : //TODO: check this
                                                                    Q_q                  ;
assign add_in_A    = (is_intt_q                ) ? A_q            :
                     (is_add_q                 ) ? PSI_q          :
                     (is_tocenter_q            ) ? PSI_q          :
                     (is_fromcenter_q          ) ? PSI_q          :
                     (is_decompose_q           ) ? mm_out_D       :
                     (is_use_hint_q            ) ? mm_out_D       :
                     (is_compress_q            ) ? mm_out_D       :
                     (is_chk_infnorm_q         ) ? PSI_q          :
                     (is_make_hint_q           ) ? PSI_q          :
                     (is_sum_q                 ) ? A_q            :
                     (is_chk_l1norm_q          ) ? A_q            :
                                                   shift_out_3    ;
assign add_in_B    = (is_intt_q                 ) ? B_q          :
                     (is_add_q                  ) ? B_q          :
                     (is_tocenter_q             ) ? B_q          :
                     (is_fromcenter_q           ) ? B_q          :
                     (is_decompose_q            ) ? {LOGQ{1'b0}} :
                     (is_use_hint_q             ) ? {LOGQ{1'b0}} :
                     (is_compress_q             ) ? {LOGQ{1'b0}} :
                     (is_chk_infnorm_q          ) ? B_q          :
                     (is_make_hint_q            ) ? B_q          :
                     (is_sum_q                  ) ? B_q          :
                     (is_chk_l1norm_q           ) ? B_q          :
                                                    mm_out_C     ;
assign add_rd_en   = (is_decompose_q || is_use_hint_q || is_compress_q || 
                                      is_fromcenter_q || is_chk_l1norm_q) ? 1'b0 : 1'b1;
assign sub_in_A    = (is_intt_q                   ) ? A_q            :
                     (is_sub_q                    ) ? B_q            :
                     (is_decompose_q              ) ? mm_out_C       :
                     (is_use_hint_q               ) ? mm_out_C       :
                     (is_tocenter_q               ) ? add_out_C      :
                     (is_fromcenter_q             ) ? add_out_C      :
                     (is_chk_infnorm_q            ) ? add_out_C      :
                     (is_chk_l1norm_q             ) ? add_out_C      :
                     (is_make_hint_q              ) ? add_out_C      :
                                                      shift_out_3    ;
assign sub_in_B    = (is_intt_q                 ) ? B_q            : 
                     (is_decompose_q            ) ? mm_in_E        : 
                     (is_use_hint_q             ) ? mm_in_E        :
                     (is_sub_q                  ) ? PSI_q          :
                     (is_chk_l1norm_q           ) ? PSI_d          : // todo: we can fix RHS (bound) by definition and use PSI_q instead.
                     (is_tocenter_q             ) ? PSI2           :
                     (is_fromcenter_q           ) ? PSI2           :
                     (is_chk_infnorm_q          ) ? PSI2           :
                     (is_make_hint_q            ) ? PSI2           :
                                                    mm_out_C       ;
assign sub_rd_en   = (is_tocenter_q) ? 1'b0 : 1'b1;
assign shift_in_0  = (is_intt_q                 ) ? add_out_C      :
                     (is_sqadd_q     && !en_z_q ) ? PSI_q          :
                     (is_compress_q             ) ? PSI_q          :
                     (is_chk_l1norm_q           ) ? add_out_C      :
                                                    A_q            ;
assign shift_in_1  = (is_intt_q                 ) ? mm_inv2_out    :
                                                    shift_out_0    ;

assign shift_in_2  = shift_out_1;

assign shift_in_3  = ((is_pwm_q || is_mac_q) && !en_z_q) ? mm_out_F       : //TODO: fix for sqadd
                                                           shift_out_2    ;

assign specialcase_checker_in_A0 = (is_make_hint_q) ? A_q : sub_out_C;
assign specialcase_checker_in_A1 = (is_make_hint_q) ? B_q : add_out_C;
assign specialcase_checker_in_S  = (is_decompose_q || is_use_hint_q || is_make_hint_q) ? inv2_q : shift_out_3; // TODO: will be removed by muxing inv2

assign chknorm_int = ~sub_out_corr;
assign makehint_specialcase = specialcase_checker_out_sc;
assign hint = chknorm_int | makehint_specialcase_d;


assign mm_inv2_in  = shift_out_0;


assign E_int       = (is_intt_q      ) ? shift_out_3          :
                     (is_add_q       ) ? add_out_C            :
                     (is_sum_q       ) ? add_out_C            :
                     (is_chk_l1norm_q) ? shift_out_1          :
                     (is_sub_q       ) ? sub_out_C            :
                     (is_tocenter_q  ) ? sub_out_C            :
                     (is_fromcenter_q) ? sub_out_C            :
                     (is_compress_q  ) ? specialcase_checker_out_B1  :
                     (is_decompose_q ) ? specialcase_checker_out_B0  :
                     (is_make_hint_q ) ? hint_q               :
                     (is_use_hint_q  ) ? use_hint_B           :
                     (is_pwm_q       ) ? ((en_z_q) ? add_out_C : mm_out_C ) :
                     (is_mac_q       ) ? ((en_z_q) ? add_out_C : mm_out_C ) : // todo: early output of 'O' part to increase precisio and save some MUXes by introducing some FFs
                     (is_sqadd_q     ) ? ((en_z_q) ? add_out_C : add_out_C) :
                    /*is_ntt_q        */ add_out_C            ;
assign O_int       = (is_intt_q      ) ? mm_out_C             :
                     (is_decompose_q ) ? specialcase_checker_out_B1  :
                     (is_pwm_q       ) ? shift_out_3          :
                     (is_mac_q       ) ? shift_out_3          :
                     (is_sqadd_q     ) ? shift_out_3          :
                     /*is_ntt_q        */ sub_out_C           ;

assign E = E_q;
assign O = O_q;

assign chknorm = chknorm_q;


modmul #(
    .LOGQ           (LOGQ           ),
    .FF_INTMUL_MUL  (FF_INTMUL_MUL  ),
    .FF_MODRED_MUL  (FF_MODRED_MUL  ),
    .FF_BARRETT_KR_SUM0(FF_BARRETT_KR_SUM0),
    .FF_BARRETT_KR_SUB0(FF_BARRETT_KR_SUB0),
    .FF_BARRETT_KR_MUL (FF_BARRETT_KR_MUL ),
    .FF_BARRETT_KR_SUM1(FF_BARRETT_KR_SUM1),
    .FF_BARRETT_KR_SUM2(FF_BARRETT_KR_SUM2),
    .FF_BARRETT_KR_SUB1(FF_BARRETT_KR_SUB1),
    .FF_BARRETT_NEG    (FF_BARRETT_NEG    )
) mm (
    .clk (clk     ),
    .mode(mode_mul),
    .en_z(en_z_q  ),
    .Q   (mm_in_Q ),
    .MU  (MU_int  ),
    .A   (mm_in_A ),
    .B   (mm_in_B ),
    .E   (mm_in_E ),
    .Z   (mm_in_Z ),
    .C   (mm_out_C),
    .T   (mm_out_T),
    .D   (mm_out_D),
    .F   (mm_out_F)
);

modadd  #(
    .LOGQ  (LOGQ         ),
    .FF_IN (FF_MODADD_IN ),
    .FF_OUT(FF_MODADD_OUT)
) ma (
    .clk (clk      ),
    .A   (add_in_A ),
    .B   (add_in_B ),
    .dual(dual     ),
    .rd_en(add_rd_en),
    .Q   (Q_q      ),
    .C   (add_out_C) 
);

modsub #(
    .LOGQ  (LOGQ         ),
    .FF_IN (FF_MODADD_IN ),
    .FF_OUT(FF_MODADD_OUT)
) ms (
    .clk (clk      ),
    .A   (sub_in_A ),
    .B   (sub_in_B ),
    .dual(dual     ),
    .rd_en(sub_rd_en),
    .Q   (Q_q      ),
    .corr(sub_out_corr),
    .C   (sub_out_C)
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

specialcase_checker #(
    .LOGQ(LOGQ),
    .FF_OUT(FF_SC)
) specialcase_checker_0 (
    .clk (clk),
    .A0  (specialcase_checker_in_A0 ),
    .A1  (specialcase_checker_in_A1 ),
    .S   (specialcase_checker_in_S  ),
    .dual(dual),
    .Q   (Q_q ),
    .B0  (specialcase_checker_out_B0),
    .B1  (specialcase_checker_out_B1),
    .sc  (specialcase_checker_out_sc)
);


use_hint #(
    .LOGQ(LOGQ),
    .HINT_DELAY(LAT_MODADD + LAT_MUL + LAT_RED + FF_SC),
    .FF_OUT(FF_HINT)
) use_hint_inst (
    .clk (clk),
    .A0  (specialcase_checker_out_B0),
    .A1  (specialcase_checker_out_B1),
    .Q   (Q_q     ),
    .M   (inv2_q  ),
    .hint(A_q[0]  ),
    .B   (use_hint_B)
);


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
    .SHIFT(LAT_MODADD - 1),
    .DATA (LOGQ )
) sre_1 (
    .clk     (clk        ),
    .rst     (1'b0       ),
    .data_in (shift_in_1 ),
    .data_out(shift_out_1)
);

//TODO: what if lat_MUL is smaller than lat_modadd?
shiftreg #(
    .SHIFT(LAT_MUL - LAT_MODADD),
    .DATA (LOGQ )
) sre_2 (
    .clk     (clk        ),
    .rst     (1'b0       ),
    .data_in (shift_in_2 ),
    .data_out(shift_out_2)
);

shiftreg #(
    .SHIFT(LAT_RED),
    .DATA (LOGQ )
) sre_3 (
    .clk     (clk        ),
    .rst     (1'b0       ),
    .data_in (shift_in_3 ),
    .data_out(shift_out_3)
);

shiftreg #(
    .SHIFT(LAT_MODADD),
    .DATA (LOGQ )
) sre_psi (
    .clk     (clk  ),
    .rst     (1'b0 ),
    .data_in (PSI_q),
    .data_out(PSI_d) // TODO: will be eliminated by late-reading PSI when INTT
);

shiftreg #(
    .SHIFT(LAT_MODADD * 2 - FF_SC),
    .DATA (1)
) sre_makehint (
    .clk     (clk ),
    .rst     (1'b0),
    .data_in (makehint_specialcase),
    .data_out(makehint_specialcase_d)
);

shiftreg #(
    .SHIFT(FF_HINT),
    .DATA (1)
) sre_makehint1 (
    .clk     (clk ),
    .rst     (1'b0),
    .data_in (hint),
    .data_out(hint_q)
);


always @(posedge clk) begin
    A_q   <= A;
    B_q   <= B;
    PSI_q <= PSI;
end

always @(posedge clk) begin
    op_q       <= op;
    mode_q     <= mode;
    round_q    <= round;
    en_z_q     <= en_z;
end

always @(posedge clk) begin
    Q_q     <= Q;
    MU_q    <= MU;
    // bound_q <= bound;
    inv2_q  <= inv2;
end

always @(posedge clk) begin
    E_q <= E_int;
    O_q <= O_int;
end

always @(posedge clk) begin
    chknorm_q <= chknorm_int;
end


///////////////////////////////////////// o_valid generation /////////////////////////////

wire s0, s1, s2, s3, s4, s5, s6;

shiftreg #(
    .SHIFT(LAT_MODADD + 2),
    .DATA (1),
    .EN_OR (1)
) sr_o_valid_add (
    .clk     (clk        ),
    .rst     (1'b0       ),
    .data_in (i_valid    ),
    .data_out(o_valid_add),
    .data_or (s0)
);

shiftreg #(
    .SHIFT(LAT_MODADD),
    .DATA (1),
    .EN_OR (1)
) sr_o_valid_addsub (
    .clk     (clk        ),
    .rst     (1'b0       ),
    .data_in (o_valid_add),
    .data_out(o_valid_addsub),
    .data_or (s1)
);

shiftreg #(
    .SHIFT(FF_HINT),
    .DATA (1),
    .EN_OR (1)
) sr_o_valid_makehint (
    .clk     (clk        ),
    .rst     (1'b0       ),
    .data_in (o_valid_addsub),
    .data_out(o_valid_makehint),
    .data_or (s2)
);

shiftreg #(
    .SHIFT(FF_HINT + FF_SC),
    .DATA (1),
    .EN_OR (1)
) sr_o_valid_usehint (
    .clk     (clk        ),
    .rst     (1'b0       ),
    .data_in (o_valid_ntt),
    .data_out(o_valid_usehint),
    .data_or (s3)
);


shiftreg #(
    .SHIFT(LAT_RED + LAT_MUL - LAT_MODADD),
    .DATA (1),
    .EN_OR (1)
) sr_o_valid_mul (
    .clk     (clk        ),
    .rst     (1'b0       ),
    .data_in (o_valid_add),
    .data_out(o_valid_mul),
    .data_or (s4)
);

assign i_valid_ntt = ((is_pwm_q || is_mac_q) && !en_z_q) ? 1'b0 : o_valid_mul;

shiftreg #(
    .SHIFT(LAT_MODADD),
    .DATA (1),
    .EN_OR (1)
) sr_o_valid_ntt (
    .clk     (clk        ),
    .rst     (1'b0       ),
    .data_in (i_valid_ntt),
    .data_out(o_valid_ntt),
    .data_or (s5)
);

shiftreg #(
    .SHIFT(FF_SC),
    .DATA (1),
    .EN_OR (1)
) sr_o_valid_sc (
    .clk     (clk        ),
    .rst     (1'b0       ),
    .data_in (o_valid_ntt),
    .data_out(o_valid_sc),
    .data_or (s6)
);

always @(*) begin
    case (op_q)
        `OP_NTT          : o_valid = o_valid_ntt;
        `OP_INTT         : o_valid = o_valid_ntt;
        `OP_PWM          : o_valid = (en_z_q) ? o_valid_ntt : o_valid_mul;
        `OP_MAC          : o_valid = (en_z_q) ? o_valid_ntt : o_valid_mul;
        `OP_COMPRESS     : o_valid = o_valid_sc;
        `OP_DECOMPOSE    : o_valid = o_valid_sc;
        `OP_SQADD        : o_valid = o_valid_ntt;
        `OP_ADD          : o_valid = o_valid_add;
        `OP_SUB          : o_valid = o_valid_add;
        `OP_SUM          : o_valid = o_valid_add;
        `OP_FROMCENTER   : o_valid = o_valid_addsub;
        `OP_TOCENTER     : o_valid = o_valid_addsub;
        `OP_CHKINFNORM   : o_valid = o_valid_addsub;
        `OP_CHKL1NORM    : o_valid = o_valid_addsub;
        `OP_MAKEHINT     : o_valid = o_valid_makehint;
        `OP_USEHINT      : o_valid = o_valid_usehint;
        default          : o_valid = 1'b0;
    endcase
end

assign busy = s0 | s1 | s2 | s3 | s4 | s5 | s6;

///////////////////////////////////////////////////////////////////////////////////////


always @(posedge clk) begin
    is_ntt_q           <= op == `OP_NTT;
    is_intt_q          <= op == `OP_INTT;
    is_add_q           <= op == `OP_ADD;
    is_sub_q           <= op == `OP_SUB;
    is_pwm_q           <= op == `OP_PWM;
    is_mac_q           <= op == `OP_MAC;
    is_sum_q           <= op == `OP_SUM;
    is_make_hint_q     <= (DILITHIUM_EN) ? op == `OP_MAKEHINT    : 1'b0;
    is_use_hint_q      <= (DILITHIUM_EN) ? op == `OP_USEHINT     : 1'b0;
    is_decompose_q     <= (DILITHIUM_EN) ? op == `OP_DECOMPOSE   : 1'b0;
    is_chk_infnorm_q   <= (DILITHIUM_EN) ? op == `OP_CHKINFNORM  : 1'b0;
    is_compress_q      <= (KYBER_EN    ) ? op == `OP_COMPRESS    : 1'b0;
    is_chk_l1norm_q    <= (FALCON_EN   ) ? op == `OP_CHKL1NORM   : 1'b0;
    is_sqadd_q         <= (FALCON_EN   ) ? op == `OP_SQADD       : 1'b0;
    is_tocenter_q      <= (FALCON_EN   ) ? op == `OP_TOCENTER    : 1'b0;
    is_fromcenter_q    <= (FALCON_EN   ) ? op == `OP_FROMCENTER  : 1'b0;
end

endmodule




