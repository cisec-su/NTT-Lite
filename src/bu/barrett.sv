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
        parameter  FF_OUT   = 1
    )
    (
        input                clk ,
        input                dual,
        input  [LOGC   -1:0] C   ,
        output [LOGQ   -1:0] T   ,
        input  [LOGLOGQ-1:0] B   ,   // 2^{B-1} < q < 2^B
        input  [LOGQ   +1:0] MU  ,
        input  [LOGD   -1:0] D   ,
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

localparam barrett_params_t params = {LOGQ, LOGQH, FF_IN, FF_SHF, FF_MUL, FF_OUT};
localparam mac_std_dual_32x34_params_t mac_0_params = barrett_mac_0_params(params);
localparam mac_std_dual_32x34_params_t mac_1_params = barrett_mac_1_params(params);

localparam LOGC  = LOGQ << 1;
localparam LOGD  = LOGQ << 1;
localparam LOGD0 = LOGD >> 1;
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

localparam LAT    = barrett_lat(params);
localparam LAT_0  = barrett_mac_0_lat(params);
localparam LAT_1  = barrett_mac_1_lat(params);

localparam CL_D   = LAT_0;
localparam Q_D    = (PIPE_Q) ? LAT_1 + LAT_0 + FF_IN : 0;
localparam LOGQ_D = (PIPE_Q) ? LAT_0 + FF_IN : 0;

/////////////////////////////////////////////////////////////////////////




///////////////////////////// signals ///////////////////////////////////

reg  [LOGC   -1:0] C_q;
reg  [LOGQ   +1:0] mu_q;
reg  [LOGQH  -1:0] qH_q [0:   Q_D-1];
reg  [LOGLOGQ-1:0] B_q  [0:LOGQ_D-1];

wire [LOGC -1:0] C_mx;
wire [LOGQH-1:0] qH_mx   [0:1];
wire [LOGLOGQ:0] B_mx [0:1];
wire [LOGQ +1:0] mu_mx;
wire [LOGQ +1:0] mu_dual;

wire [LOGC   -1:0] asr_0_C;
wire [LOGCH  -1:0] CH;

wire [LOGCL  -1:0] CL;
wire [LOGCL_0-1:0] CL_0;
wire [LOGCL_0-1:0] CL_1;

reg  [LOGCL-1:0] CL_q [0:CL_D-1];
wire [LOGCL-1:0] CL_mx;

wire [LOGT0 -1:0] T0;
wire [LOGT0H-1:0] T0H;
wire [LOGT0 -1:0] D_apx;
reg  [LOGT0 -1:0] D_apx_q [0:LAT_1-1];
wire [LOGT0 -1:0] D_apx_mx;

wire [LOGT1_MAC  -1:0] T1;
wire [LOGT1_MAC_0-1:0] T1_0;
wire [LOGT1_MAC_0-1:0] T1_1;
wire [LOGT1  -1:0] T1N;
wire [LOGT1_0-1:0] T1N_0;
wire [LOGT1_0-1:0] T1N_1;

wire [LOGQ-1:0] q;
wire [LOGQ-1:0] q_dual;

wire [LOGQ-1:0] T5;
reg  [LOGQ-1:0] T5_q;

wire [    3:0] K;
wire [LOGT0_0:0] D0;
wire [LOGT0_0:0] D1;
wire [LOGD-1:0] D_int;
reg  [LOGD-1:0] D_int_q;

mode_mul_t mode_mul;

/////////////////////////////////////////////////////////////////////////




/////////////////////////// comb. assignments //////////////////////

assign q = (LOGQ > LOGQH) ? {qH_mx[0], {(W - 1){1'b0}}, 1'b1} : qH_mx[0];
assign mode_mul = (dual) ? MUL_DUAL : MUL_SINGLE;
assign mu_dual  = (dual) ? {mu_mx[LOGQ0:0], mu_mx[LOGQ0:0]} : mu_mx;
assign q_dual   = (dual) ? {q[LOGQ0-1:0], q[LOGQ0-1:0]} : q;

assign CL_0 = C_mx[LOGC0-1:    0] & ((1 << (LOGQ0 + 2)) - 1);
assign CL_1 = C_mx[LOGC -1:LOGC0] & ((1 << (LOGQ0 + 2)) - 1);   
assign CL  = (dual) ? {CL_1, CL_0} : C_mx & ((1 << (LOGQ + 2)) - 1);

assign T1_0 = T1[LOGT1_MAC_0-1:          0];
assign T1_1 = T1[LOGT1_MAC  -1:LOGT1_MAC_0];
assign T1N_0 = -T1_0;
assign T1N_1 = -T1_1;
assign T1N = (dual) ? {T1N_1, T1N_0} : -T1;

assign D0 = D_apx_mx[LOGT0_0-1:0      ] + K[1:0];
assign D1 = D_apx_mx[LOGT0  -1:LOGT0_0] + ((dual) ? K[3:2] : D0[LOGT0_0]);
assign D_int = {D1[LOGT0_0-1:0] >> dual, D0[LOGT0_0-1:0] ^ (D1[0] << LOGT0_0-1)};

/////////////////////////////////////////////////////////////////////////




/////////////////////////// pipeline steps  /////////////////////////////

if (FF_IN) begin
    assign C_mx = C_q;
end
else begin
    assign C_mx = C;
end

if (CL_D) begin
    assign CL_mx = CL_q[CL_D - 1];
end
else begin
    assign CL_mx = CL;
end

if (FF_IN && PIPE_Q) begin
    assign mu_mx = mu_q;
end
else begin
    assign mu_mx = MU;
end

if (Q_D) begin
    assign qH_mx[0] = qH_q[FF_IN + LAT_0 - 1];
    assign qH_mx[1] = qH_q[          Q_D - 1];
end
else begin
    assign qH_mx[0] = qH;
    assign qH_mx[1] = qH;
end

if (LOGQ_D) begin
    assign B_mx[0] = B_q[ FF_IN - 1];
    assign B_mx[1] = B_q[LOGQ_D - 1];
end
else begin
    assign B_mx[0] = B;
    assign B_mx[1] = B;
end

if (LAT_1) begin
    assign D_apx_mx = D_apx_q[LAT_1 - 1];
end
else begin
    assign D_apx_mx = D_apx;
end

if (FF_OUT) begin
    assign T = T5_q;
    assign D = D_int_q;
end
else begin
    assign T = T5;
    assign D = D_int;
end

/////////////////////////////////////////////////////////////////////////




/////////////////////////// shift right  ////////////////////////////////

asr #(
    .LOGQ(LOGC)
) asr_inst_0 (
    .A   (C_mx   ),
    .d   (B_mx[0]),
    .dual(dual   ),
    .C   (asr_0_C)
);

assign CH[LOGCH_0-1:      0] = asr_0_C[LOGCH_0-1:0];
assign CH[LOGCH  -1:LOGCH_0] = (dual) ? asr_0_C[LOGC0+:LOGCH] : asr_0_C[LOGCH-1:LOGCH_0];


asr #(
    .LOGQ(LOGT0)
) asr_inst_1 (
    .A   (T0     ),
    .d   (B_mx[1]),
    .dual(dual   ),
    .C   (D_apx  )
);

assign T0H[LOGT0H_0-1:0       ] = D_apx[LOGT0H_0-1:0];
assign T0H[LOGT0H  -1:LOGT0H_0] = (dual) ? D_apx[LOGT0_0+:LOGT0H_0] : D_apx[LOGT0H-1:LOGT0H_0];

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

barrett_correction #(
    .LOGQ(LOGQ)
) barrett_correction_inst (
    .dual(dual    ),
    .A   (T1N     ),
    .C   (T5      ),
    .K   (K       ),
    .Q   (qH_mx[1])
);

/////////////////////////////////////////////////////////////////////////




/////////////////////////// sequential logic  ///////////////////////////

if (FF_IN) begin
    always @(posedge clk) begin           
        C_q <= C;
    end
end

if (CL_D) begin
    for (genvar i = 0; i < CL_D; i = i + 1) begin
        always @(posedge clk) begin
            CL_q[i] <= (i == 0) ? CL : CL_q[i - 1];
        end
    end
end

if (FF_IN && PIPE_Q) begin
    always @(posedge clk) begin           
        mu_q <= mu_dual;
    end
end

if (Q_D) begin
    for (genvar i = 0; i < Q_D; i = i + 1) begin
        always @(posedge clk) begin
            qH_q[i] <= (i == 0) ? qH : qH_q[i - 1];
        end
    end
end

if (LOGQ_D) begin
    for (genvar i = 0; i < LOGQ_D; i = i + 1) begin
        always @(posedge clk) begin
            B_q[i] <= (i == 0) ? B : B_q[i - 1];
        end
    end
end

if (LAT_1) begin
    for (genvar i = 0; i < LAT_1; i = i + 1) begin
        always @(posedge clk) begin
            D_apx_q[i] <= (i == 0) ? D_apx : D_apx_q[i - 1];
        end
    end
end

if (FF_OUT) begin
    always @(posedge clk) begin
        T5_q <= T5;
        D_int_q <= D_int;
    end
end

/////////////////////////////////////////////////////////////////////////


endmodule