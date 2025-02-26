`include "barrett.svh"

module barrett
   #(
        parameter  LOGQ     = 32,
        parameter  LOGQH    = 15,
        parameter  PIPE_Q   = 1 ,
        parameter  CORRECT  = 1 ,
        parameter  FF_IN    = 1 ,
        parameter  FF_SHF   = 1 ,
        parameter  FF_MUL   = 1 ,
        parameter  FF_NEG   = 0 ,
        parameter  FF_CORR  = 0 ,
        parameter  FF_OUT   = 1
    )
    (
        input                clk ,
        input                dual,
        input  [LOGC   -1:0] C   ,
        output [LOGT   -1:0] T   ,
        input  [LOGLOGQ-1:0] B   ,   // 2^{B-1} < q < 2^B
        input  [LOGQ   +1:0] MU  ,
        input  [LOGQH  -1:0] qH
    );

///////////////////////////// input check ///////////////////////////////

generate
    if (LOGQ > 32) begin
        LOGQ_CANT_BE_GREATER_THAN_32();
    end
endgenerate

/////////////////////////////////////////////////////////////////////////




///////////////////////////// parameters ////////////////////////////////

localparam barrett_params_t params = {LOGQ, LOGQH, CORRECT, FF_IN, FF_SHF, FF_MUL, FF_NEG, FF_CORR, FF_OUT};
localparam mac_std_dual_32x34_params_t mac_0_params = barrett_mac_0_params(params);
localparam mac_std_dual_32x34_params_t mac_1_params = barrett_mac_1_params(params);

localparam LOGT  = (CORRECT) ? LOGQ : LOGQ + 2;
localparam LOGC  = LOGQ << 1;//(LOGQ + 1) << 1;
localparam LOGC0 = LOGC >> 1;
localparam LOGCH_0 = LOGC0 - (LOGQ >> 1);
localparam LOGCH = LOGCH_0 << 1;
localparam LOGCL_0 = (LOGQ >> 1) + 2;
localparam LOGCL = LOGCL_0 << 1;
localparam LOGQ0 = LOGQ >> 1;
localparam LOGT0 = barrett_logt0(params);
localparam LOGT0_0 = LOGT0 >> 1;
localparam LOGT0H_0 = LOGT0_0 - (LOGQ >> 1);
localparam LOGT0H = LOGT0H_0 << 1;
localparam LOGLOGQ = $rtoi($ceil($clog2(LOGQ + 1)));
localparam LOGT1_MAC = barrett_logt1(params);
localparam LOGT1_MAC_0 = LOGT1_MAC >> 1;
localparam LOGT1   = (LOGQ0 + 2) << 1;
localparam LOGT1_0 = LOGT1 >> 1;
localparam W       = LOGQ - LOGQH;

localparam FF_NEG_ = barrett_ff_neg(params);
localparam LAT    = barrett_lat(params);
localparam LAT_0  = barrett_mac_0_lat(params);
localparam LAT_1  = barrett_mac_1_lat(params);

localparam CL_D   = LAT_0;
localparam Q_D    = (PIPE_Q) ? FF_NEG_ + LAT_1 + LAT_0 + FF_IN : 0;
localparam LOGQ_D = (PIPE_Q) ? LAT_0 + FF_IN : 0;

/////////////////////////////////////////////////////////////////////////




///////////////////////////// signals ///////////////////////////////////

generate
    if (FF_IN) begin : C_GEN
        reg  [LOGC-1:0] C_q;
    end
endgenerate

generate
    if (FF_IN && PIPE_Q) begin : MU_GEN
        reg  [LOGQ+1:0] mu_q;
    end
endgenerate

generate
    if (Q_D) begin : Q_GEN
        reg  [LOGQH-1:0] qH_q [0:Q_D-1];
    end
endgenerate

generate
    if (LOGQ_D) begin : LOGQ_GEN
        reg  [LOGLOGQ-1:0] B_q [0:LOGQ_D-1];
    end
endgenerate

wire [LOGC -1:0] C_mx;
wire [LOGQH-1:0] qH_mx   [0:1];
wire [LOGLOGQ:0] B_mx [0:1];
wire [LOGQ +1:0] mu_mx;
wire [LOGQ +1:0] mu_dual;

wire [LOGCH  -1:0] CH;
wire [LOGCH_0-1:0] CH_0;
wire [LOGCH_0-1:0] CH_1;

wire [LOGCL  -1:0] CL;
wire [LOGCL_0-1:0] CL_0;
wire [LOGCL_0-1:0] CL_1;
generate
    if (CL_D) begin : CL_GEN
        reg [LOGCL-1:0] CL_q [0:CL_D-1];
    end
endgenerate
wire [LOGCL-1:0] CL_mx;

wire [LOGT0 -1:0] T0;
wire [LOGT0H-1:0] T0H;
wire [LOGT0H_0-1:0] T0H_0;
wire [LOGT0H_0-1:0] T0H_1;

wire [LOGT1_MAC  -1:0] T1;
wire [LOGT1_MAC_0-1:0] T1_0;
wire [LOGT1_MAC_0-1:0] T1_1;
wire [LOGT1  -1:0] T1N;
wire [LOGT1_0-1:0] T1N_0;
wire [LOGT1_0-1:0] T1N_1;

generate
    if (FF_NEG_) begin : T1N_GEN
        reg [LOGT1-1:0] T1N_q;
    end
endgenerate
wire [LOGT1-1:0] T1N_mx;

wire [LOGQ-1:0] q;
wire [LOGQ-1:0] q_dual;

generate
    if (CORRECT) begin : CORR_GEN
        wire [LOGQ   -1:0] q;
        wire [LOGT1  -1:0] T1N_d1_mx;
        wire [LOGT1  -1:0] T2;
        wire [LOGT1_0  :0] T2_0;
        wire [LOGT1_0-1:0] T2_1;
        wire [LOGT1  -1:0] T2_mx;
        wire [LOGT1  -1:0] T3;
        wire [LOGT1_0  :0] T3_0;
        wire [LOGT1_0-1:0] T3_1;
        wire [LOGT1  -1:0] T3_mx;
        wire [LOGT1  -1:0] T4;
        wire [LOGT1_0  :0] T4_0;
        wire [LOGT1_0-1:0] T4_1;
        wire [LOGT1  -1:0] T4_mx;
        if (FF_CORR) begin : FF
            reg  [LOGT1-1:0] T1N_d1_q;
            reg  [LOGT1-1:0] T2_q;
            reg  [LOGT1-1:0] T3_q;
            reg  [LOGT1-1:0] T4_q;
        end
    end    
endgenerate

wire [LOGQ-1:0] T5;
wire [LOGQ0-1:0] T5_0;
wire [LOGQ0-1:0] T5_1;

if (FF_OUT) begin : OUT_GEN
    reg  [LOGQ-1:0] T5_q;
end

mode_mul_t mode_mul;

/////////////////////////////////////////////////////////////////////////




/////////////////////////// comb. assignments //////////////////////

assign q = (LOGQ > LOGQH) ? {qH_mx[0], {(W - 1){1'b0}}, 1'b1} : qH_mx[0];
assign mode_mul = (dual) ? MUL_DUAL : MUL_SINGLE;
assign mu_dual  = (dual) ? {mu_mx[LOGQ0:0], mu_mx[LOGQ0:0]} : mu_mx;
assign q_dual   = (dual) ? {q[LOGQ0-1:0], q[LOGQ0-1:0]} : q;

assign CH_0 = C_mx[LOGC0-1:    0] >> B_mx[0];
assign CH_1 = C_mx[LOGC -1:LOGC0] >> B_mx[1];
assign CH  = (dual) ? {CH_1, CH_0} : C_mx >> B_mx[0];

assign CL_0 = C_mx[LOGC0-1:    0] & ((1 << (LOGQ0 + 2)) - 1);
assign CL_1 = C_mx[LOGC -1:LOGC0] & ((1 << (LOGQ0 + 2)) - 1);   
assign CL  = (dual) ? {CL_1, CL_0} : C_mx & ((1 << (LOGQ + 2)) - 1);

assign T0H_0 = T0[LOGT0_0-1:      0] >> B_mx[0];
assign T0H_1 = T0[LOGT0  -1:LOGT0_0] >> B_mx[1];
assign T0H = (dual) ? {T0H_1,  T0H_0} : T0 >> B_mx[1];

assign T1_0 = T1[LOGT1_MAC_0-1:          0];
assign T1_1 = T1[LOGT1_MAC  -1:LOGT1_MAC_0];
assign T1N_0 = -T1_0;
assign T1N_1 = -T1_1;
assign T1N = (dual) ? {T1N_1, T1N_0} : -T1;

/////////////////////////////////////////////////////////////////////////




/////////////////////////// pipeline steps  /////////////////////////////

generate
    if (FF_IN) begin
        assign C_mx = C_GEN.C_q;
    end
    else begin
        assign C_mx = C;
    end
endgenerate

generate
    if (CL_D) begin
        assign CL_mx = CL_GEN.CL_q[CL_D - 1];
    end
    else begin
        assign CL_mx = CL;
    end
endgenerate

generate
    if (FF_IN && PIPE_Q) begin
        assign mu_mx = MU_GEN.mu_q;
    end
    else begin
        assign mu_mx = MU;
    end
endgenerate

generate
    if (Q_D) begin
        assign qH_mx[0] = Q_GEN.qH_q[FF_IN + LAT_0 - 1];
        assign qH_mx[1] = Q_GEN.qH_q[          Q_D - 1];
    end
    else begin
        assign qH_mx[0] = qH;
        assign qH_mx[1] = qH;
    end
endgenerate

generate
    if (LOGQ_D) begin
        assign B_mx[0] = LOGQ_GEN.B_q[ FF_IN - 1];
        assign B_mx[1] = LOGQ_GEN.B_q[LOGQ_D - 1];
    end
    else begin
        assign B_mx[0] = B;
        assign B_mx[1] = B;
    end
endgenerate

generate
    if (FF_NEG_) begin
        assign T1N_mx = T1N_GEN.T1N_q;
    end
    else begin
        assign T1N_mx = T1N;
    end
endgenerate

generate
    if (CORRECT) begin
        if (FF_CORR) begin
            assign CORR_GEN.T1N_d1_mx = CORR_GEN.FF.T1N_d1_q;
            assign CORR_GEN.T2_mx     = CORR_GEN.FF.T2_q;
            assign CORR_GEN.T3_mx     = CORR_GEN.FF.T3_q;
            assign CORR_GEN.T4_mx     = CORR_GEN.FF.T4_q;
        end
        else begin
            assign CORR_GEN.T1N_d1_mx = T1N_mx;
            assign CORR_GEN.T2_mx     = CORR_GEN.T2;
            assign CORR_GEN.T3_mx     = CORR_GEN.T3;
            assign CORR_GEN.T4_mx     = CORR_GEN.T4;
        end
    end
endgenerate

generate
    if (FF_OUT) begin
        assign T = OUT_GEN.T5_q;
    end
    else begin
        assign T = T5;
    end
endgenerate

/////////////////////////////////////////////////////////////////////////




/////////////////////////// mac 0 ///////////////////////////////////////

mac_std_dual_32x34 #(
    .LOGB    (mac_0_params.LOGB   ),
    .MODE_E  (mac_0_params.MODE_E ),
    .FF_IN_A (mac_0_params.FF_IN_A),
    .FF_IN_B (mac_0_params.FF_IN_B),
    .FF_IN_E (mac_0_params.FF_IN_E),
    .FF_MUL  (mac_0_params.FF_MUL ),
    .FF_OUT  (mac_0_params.FF_OUT )
) mac_std_inst_0 (
    .clk     (clk      ),
    .mode_mul(mode_mul ),
    .A       (CH       ),
    .B       (mu_dual  ),
    .C       (T0       )
);

/////////////////////////////////////////////////////////////////////////




/////////////////////////// mac 1 ///////////////////////////////////////

mac_std_dual_32x34 #(
    .LOGB    (mac_1_params.LOGB   ),
    .MODE_E  (mac_1_params.MODE_E ),
    .FF_IN_A (mac_1_params.FF_IN_A),
    .FF_IN_B (mac_1_params.FF_IN_B),
    .FF_IN_E (mac_1_params.FF_IN_E),
    .FF_MUL  (mac_1_params.FF_MUL ),
    .FF_OUT  (mac_1_params.FF_OUT )
) mac_std_inst_1 (
    .clk     (clk     ),
    .mode_mul(mode_mul),
    .A       (q_dual  ),
    .B       (T0H     ),
    .E       (CL_mx   ),
    .C       (T1      )
);

/////////////////////////////////////////////////////////////////////////




/////////////////////////// correction //////////////////////////////////

if (CORRECT) begin
    assign CORR_GEN.q = (LOGQ > LOGQH) ? {qH_mx[1], {(W - 1){1'b0}}, 1'b1} : qH_mx[1];

    assign CORR_GEN.T2_0 = T1N_mx[LOGT1_0-1:      0] - CORR_GEN.q[LOGT1_0-1:0];
    assign CORR_GEN.T2_1 = T1N_mx[LOGT1  -1:LOGT1_0] - ((dual) ? CORR_GEN.q[LOGT1_0-1:0] : (CORR_GEN.q >> LOGT1_0) + CORR_GEN.T2_0[LOGT1_0]);
    assign CORR_GEN.T2   = {CORR_GEN.T2_1, CORR_GEN.T2_0[LOGT1_0-1:0]};

    assign CORR_GEN.T3_0 = T1N_mx[LOGT1_0-1:      0] - {CORR_GEN.q[LOGT1_0-2:0], 1'b0};
    assign CORR_GEN.T3_1 = T1N_mx[LOGT1  -1:LOGT1_0] - ((dual) ? {CORR_GEN.q, 1'b0} : ({CORR_GEN.q, 1'b0} >> LOGT1_0) + CORR_GEN.T3_0[LOGT1_0]);
    assign CORR_GEN.T3   = {CORR_GEN.T3_1, CORR_GEN.T3_0[LOGT1_0-1:0]};

    assign CORR_GEN.T4_0 = CORR_GEN.T3[LOGT1_0-1:      0] - CORR_GEN.q[LOGT1_0-1:0];
    assign CORR_GEN.T4_1 = CORR_GEN.T3[LOGT1  -1:LOGT1_0] - ((dual) ? CORR_GEN.q : (CORR_GEN.q >> LOGT1_0) + CORR_GEN.T4_0[LOGT1_0]);
    assign CORR_GEN.T4   = {CORR_GEN.T4_1, CORR_GEN.T4_0[LOGT1_0-1:0]};


    assign T5_0 = ((dual && CORR_GEN.T2_mx[LOGQ0+1] == 1'b1) || (!dual && CORR_GEN.T2_mx[LOGQ+1] == 1'b1)) ? CORR_GEN.T1N_d1_mx[LOGQ0-1:0] :
                  ((dual && CORR_GEN.T3_mx[LOGQ0+1] == 1'b1) || (!dual && CORR_GEN.T3_mx[LOGQ+1] == 1'b1)) ? CORR_GEN.T2_mx    [LOGQ0-1:0] :
                  ((dual && CORR_GEN.T4_mx[LOGQ0+1] == 1'b1) || (!dual && CORR_GEN.T4_mx[LOGQ+1] == 1'b1)) ? CORR_GEN.T3_mx    [LOGQ0-1:0] : 
                                                                                                   CORR_GEN.T4_mx    [LOGQ0-1:0] ;

    assign T5_1 = (!dual && CORR_GEN.T2_mx[LOGQ         +1] == 1'b1) ? CORR_GEN.T1N_d1_mx[LOGQ0   +: LOGQ0] :
                  (!dual && CORR_GEN.T3_mx[LOGQ         +1] == 1'b1) ? CORR_GEN.T2_mx    [LOGQ0   +: LOGQ0] :
                  (!dual && CORR_GEN.T4_mx[LOGQ         +1] == 1'b1) ? CORR_GEN.T3_mx    [LOGQ0   +: LOGQ0] : 
                  (!dual                                           ) ? CORR_GEN.T4_mx    [LOGQ0   +: LOGQ0] :
                  ( dual && CORR_GEN.T2_mx[LOGT1_0+LOGQ0+1] == 1'b1) ? CORR_GEN.T1N_d1_mx[LOGT1_0 +: LOGQ0] :
                  ( dual && CORR_GEN.T3_mx[LOGT1_0+LOGQ0+1] == 1'b1) ? CORR_GEN.T2_mx    [LOGT1_0 +: LOGQ0] :
                  ( dual && CORR_GEN.T4_mx[LOGT1_0+LOGQ0+1] == 1'b1) ? CORR_GEN.T3_mx    [LOGT1_0 +: LOGQ0] : 
                                                                       CORR_GEN.T4_mx    [LOGT1_0 +: LOGQ0] ;

                //   (CORR_GEN.T3_mx[LOGQ+1] == 1'b1) ? ((dual) ? CORR_GEN.T2_mx    [LOGT1_0 +: LOGQ0] : CORR_GEN.T2_mx    [LOGQ0 +: LOGQ0]) :
                //   (CORR_GEN.T4_mx[LOGQ+1] == 1'b1) ? ((dual) ? CORR_GEN.T3_mx    [LOGT1_0 +: LOGQ0] : CORR_GEN.T3_mx    [LOGQ0 +: LOGQ0]) : 
                //                                       ((dual) ? CORR_GEN.T4_mx    [LOGT1_0 +: LOGQ0] : CORR_GEN.T4_mx    [LOGQ0 +: LOGQ0]) ;



    // assign T5_1 = (CORR_GEN.T2_mx[LOGQ+1] == 1'b1) ? ((dual) ? CORR_GEN.T1N_d1_mx[LOGT1_0 +: LOGQ0] : CORR_GEN.T1N_d1_mx[LOGQ0 +: LOGQ0]) :
    //               (CORR_GEN.T3_mx[LOGQ+1] == 1'b1) ? ((dual) ? CORR_GEN.T2_mx    [LOGT1_0 +: LOGQ0] : CORR_GEN.T2_mx    [LOGQ0 +: LOGQ0]) :
    //               (CORR_GEN.T4_mx[LOGQ+1] == 1'b1) ? ((dual) ? CORR_GEN.T3_mx    [LOGT1_0 +: LOGQ0] : CORR_GEN.T3_mx    [LOGQ0 +: LOGQ0]) : 
    //                                                   ((dual) ? CORR_GEN.T4_mx    [LOGT1_0 +: LOGQ0] : CORR_GEN.T4_mx    [LOGQ0 +: LOGQ0]) ;

    assign T5 = {T5_1, T5_0};


    // assign T5/*[LOGQ-1:LOGQ]*/ = (CORR_GEN.T2_mx[LOGQ+1] == 1'b1) ? CORR_GEN.T1N_d1_mx :
    //                              (CORR_GEN.T3_mx[LOGQ+1] == 1'b1) ? CORR_GEN.T2_mx     :
    //                              (CORR_GEN.T4_mx[LOGQ+1] == 1'b1) ? CORR_GEN.T3_mx     : CORR_GEN.T4_mx;
end
else begin
    assign T5 = T1N_mx;
end

/////////////////////////////////////////////////////////////////////////




/////////////////////////// sequential logic  ///////////////////////////

generate
    if (FF_IN) begin
        always @(posedge clk) begin           
            C_GEN.C_q <= C;
        end
    end
endgenerate

generate
    if (CL_D) begin
        for (genvar i = 0; i < CL_D; i = i + 1) begin
            always @(posedge clk) begin
                CL_GEN.CL_q[i] <= (i == 0) ? CL : CL_GEN.CL_q[i - 1];
            end
        end
    end
endgenerate


generate
    if (FF_IN && PIPE_Q) begin
        always @(posedge clk) begin           
            MU_GEN.mu_q <= mu_dual;
        end
    end
endgenerate


generate
    if (Q_D) begin
        for (genvar i = 0; i < Q_D; i = i + 1) begin
            always @(posedge clk) begin
                Q_GEN.qH_q[i] <= (i == 0) ? qH : Q_GEN.qH_q[i - 1];
            end
        end
    end
endgenerate

generate
    if (LOGQ_D) begin
        for (genvar i = 0; i < LOGQ_D; i = i + 1) begin
            always @(posedge clk) begin
                LOGQ_GEN.B_q[i] <= (i == 0) ? B : LOGQ_GEN.B_q[i - 1];
            end
        end
    end
endgenerate

generate
    if (FF_NEG_) begin
        always @(posedge clk) begin
            T1N_GEN.T1N_q <= T1N;
        end
    end
endgenerate

generate
    if (CORRECT && FF_CORR) begin
        always @(posedge clk) begin
            CORR_GEN.FF.T1N_d1_q <= T1N_mx;
            CORR_GEN.FF.T2_q <= CORR_GEN.T2;
            CORR_GEN.FF.T3_q <= CORR_GEN.T3;
            CORR_GEN.FF.T4_q <= CORR_GEN.T4;
        end
    end
endgenerate

if (FF_OUT) begin
    always @(posedge clk) begin
        OUT_GEN.T5_q <= T5;
    end
end

/////////////////////////////////////////////////////////////////////////


endmodule