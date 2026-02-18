`include "mac_std_dual_32x34.svh"

module mac_std_dual_32x34
   #(  
        parameter          LOGB     = 34    ,
        parameter mode_e_t MODE_E   = DIS_E ,
        parameter          FF_IN_A  = 1     ,
        parameter          FF_IN_B  = 1     ,
        parameter          FF_IN_E  = 0     ,
        parameter          FF_IN_Z  = 0     ,
        parameter          FF_MUL   = 1     ,
        parameter          FF_OUT   = 1     ,
        parameter          OPT_HIGH = 0     ,
        localparam mac_std_dual_32x34_params_t params = {LOGB, MODE_E, FF_IN_A, FF_IN_B, FF_IN_E, FF_IN_Z, FF_MUL, FF_OUT},
        localparam LOGA  = mac_std_dual_32x34_loga(params),
        localparam LOGE  = mac_std_dual_32x34_loge(params),
        localparam LOGA0 = mac_std_dual_32x34_loga0(params),
        localparam LOGB0 = mac_std_dual_32x34_logb0(params),
        localparam LOGE0 = mac_std_dual_32x34_loge0(params),
        localparam LOGD  = mac_std_dual_32x34_logd(params),
        localparam LOGD0 = mac_std_dual_32x34_logd0(params),
        localparam LOGC  = mac_std_dual_32x34_logc(params),
        localparam LOGC0 = mac_std_dual_32x34_logc0(params),
        localparam LOGZ  = mac_std_dual_32x34_logz(params)
    )
    (
        input               clk     ,
        input   mode_mul_t  mode_mul,
        input               en_z    ,
        input  [ LOGA-1:0]  A       ,
        input  [ LOGB-1:0]  B       ,
        input  [ LOGE-1:0]  E       ,
        input  [ LOGZ-1:0]  Z       ,
        output [ LOGC-1:0]  C       ,
        output [LOGC0-1:0]  F
    );

///////////////////////////// input check ///////////////////////////////

if (LOGB != 34 && LOGB != 32) begin
    LOGB_MUST_BE_32_OR_34();
end

/////////////////////////////////////////////////////////////////////////



///////////////////////////// parameters ////////////////////////////////

localparam LAT  = mac_std_dual_32x34_lat(params);
localparam DSP_A_U = LOGA0;
localparam DSP_B_U = LOGB0;
localparam DSP_M_U = DSP_A_U + DSP_B_U;

localparam N_A = ((LOGA - 1) / DSP_A_U) + 1;
localparam N_B = ((LOGB - 1) / DSP_B_U) + 1;
localparam N_D = N_A + N_B - 1;

/////////////////////////////////////////////////////////////////////////




///////////////////////////// signals ///////////////////////////////////

wire [DSP_A_U-1:0] A_i   [0:N_A-1];
reg  [DSP_A_U-1:0] A_i_q [0:N_A-1];
wire [DSP_A_U-1:0] A_i_mx[0:N_A-1];

wire [DSP_B_U-1:0] B_i   [0:N_B-1];
reg  [DSP_B_U-1:0] B_i_q [0:N_B-1];
wire [DSP_B_U-1:0] B_i_mx[0:N_B-1];

wire [LOGZ-1:0] Z_i   ;
reg  [LOGZ-1:0] Z_i_q ;
wire [LOGZ-1:0] Z_i_mx;

wire [DSP_B_U-1:0] LHS;


wire [LOGE-1:0] E_mx_0;
reg  [LOGE-1:0] E_q_0;
wire [LOGE-1:0] E_mx_1;
wire [LOGE0-1:0] E_mx_1_H;
reg  [LOGE-1:0] E_q_1;

(* use_dsp = "yes" *) wire [DSP_M_U-1:0] P [0:N_A-1][0:N_B-1];
reg  [DSP_M_U-1:0] P_q [0:N_A-1][0:N_B-1];
wire [DSP_M_U-1:0] P_mx[0:N_A-1][0:N_B-1];


wire  [LOGC-1:0] S;
(* use_dsp = "no" *) wire  [LOGC0:0] S0;
(* use_dsp = "no" *) wire  [LOGC0:0] S1;
reg  [LOGC-1:0] S_q;

(* use_dsp = "no" *) wire [LOGD0+1:0] T0;
(* use_dsp = "no" *) wire [LOGD0+1:0] T1;
(* use_dsp = "no" *) wire [LOGD0+1:0] T;
(* use_dsp = "no" *) reg  [LOGC-1:0] S_int;
wire dual;

reg  [LOGC0:0] F_q;
wire [LOGC0:0] F_mx;


wire c;
reg  c_q;
wire c_mx;

/////////////////////////////////////////////////////////////////////////




///////////////////////////// partitioning //////////////////////////////

for (genvar i = 0; i < N_A; i = i + 1) begin
    if (i == (N_A - 1)) begin
        assign A_i[i] = A[LOGA - 1 : DSP_A_U*i];
    end
    else begin
        assign A_i[i] = A[DSP_A_U*i +: DSP_A_U];
    end
end

for (genvar i = 0; i < N_B; i = i + 1) begin
    if (i == (N_B - 1)) begin
        assign B_i[i] = B[LOGB - 1 : DSP_B_U*i];
    end
    else begin
        assign B_i[i] = B[DSP_B_U*i +: DSP_B_U];
    end
end

/////////////////////////////////////////////////////////////////////////




///////////////////////////// pipeline steps ////////////////////////////

for (genvar i = 0; i < N_A; i = i + 1) begin
    assign A_i_mx[i] = (FF_IN_A) ? A_i_q[i] : A_i[i];
end

for (genvar i = 0; i < N_B; i = i + 1) begin
    assign B_i_mx[i] = (FF_IN_B) ? B_i_q[i] : B_i[i];
end

if (MODE_E != DIS_E) begin
    assign E_mx_0 = (FF_IN_E) ? E_q_0 : E;
end

assign Z_i_mx = (FF_IN_Z) ? Z_i_q : Z;

for (genvar i = 0; i < N_A; i = i + 1) begin
    for (genvar j = 0; j < N_B; j = j + 1) begin
        if (!(OPT_HIGH && (i == N_A - 1) && j == (N_B - 1))) begin
            assign P_mx[i][j] = (FF_MUL) ? P_q[i][j] : P[i][j];
        end
    end
end

if (OPT_HIGH) begin
    assign c_mx = (FF_MUL) ? c_q : c;
end

if (MODE_E != DIS_E) begin
    assign E_mx_1   = (FF_MUL) ? E_q_1 : E_mx_0;
end

assign C = (FF_OUT) ? S_q : S;
assign F = (FF_OUT) ? F_q : P_mx[1][1];

/////////////////////////////////////////////////////////////////////////




///////////////////////////// multiplication ////////////////////////////

assign P[0][0] = A_i_mx[0] * B_i_mx[0];

// when OPT_HIGH is enabled, P[1][1] is not calculated. As P[1][1] is required for dual mode, we place its computation to P[0][1]
if (OPT_HIGH) begin
    assign P[0][1] = ((mode_mul == MUL_SINGLE) ? A_i_mx[0] : A_i_mx[1]) * B_i_mx[1];    
end
else begin
    assign P[0][1] = A_i_mx[0] * B_i_mx[1]; 
end

assign P[1][0] = A_i_mx[1] * B_i_mx[0];


if (!OPT_HIGH) begin
    assign LHS = (en_z) ? Z_i_mx : A_i_mx[1];
    assign P[1][1] = LHS * B_i_mx[1];
end

if (OPT_HIGH) begin
    assign c = A_i_mx[N_A - 1] & B_i_mx[N_B - 1];
end

/////////////////////////////////////////////////////////////////////////




///////////////////////////// summation /////////////////////////////////


assign T0 = P_mx[0][1] << (DSP_B_U - DSP_A_U);
assign T1 = (mode_mul == MUL_SINGLE) ? T0 : P_mx[0][1];
assign T = P_mx[1][0] + T1;

always @(*) begin
    S_int = 0;
    case (mode_mul)
        MUL_SINGLE:
        begin
            S_int = (T << (DSP_A_U)) + ((OPT_HIGH) ? {c_mx, P_mx[0][0]} : {P_mx[1][1], P_mx[0][0]});
        end
        MUL_DUAL:
        begin
            S_int[LOGC0-1:    0] = P_mx[0][0];
            S_int[LOGC -1:LOGC0] = (OPT_HIGH) ? P_mx[0][1] : P_mx[1][1];
        end
        MUL_POLY:
        begin
            if (OPT_HIGH == 0) begin
                S_int[LOGC0-1:    0] = P_mx[0][0];// + P_mx[1][1];
                S_int[LOGC -1:LOGC0] = T;                    
            end
        end
    endcase
end

if (MODE_E == DIS_E) begin
    assign S = S_int;
end
else begin
    localparam MODE = (MODE_E == ADD_E) ? 0 : 1;
    assign dual = mode_mul != MUL_SINGLE;
    addsub_dual #(
        .MODE (MODE ),
        .LOGA0(LOGC0),
        .LOGB0(LOGE0)
    ) addsub_inst (
        .A   (S_int ),
        .B   (E_mx_1),
        .dual(dual  ),
        .C   (S     )
    );
end

/////////////////////////////////////////////////////////////////////////




///////////////////////////// sequential logic //////////////////////////


if (FF_IN_A) begin
    for (genvar i = 0; i < N_A; i = i + 1) begin
        always @(posedge clk) begin
            A_i_q[i] <= A_i[i];
        end
    end
end
if (FF_IN_B) begin
    for (genvar i = 0; i < N_B; i = i + 1) begin
        always @(posedge clk) begin
            B_i_q[i] <= B_i[i];
        end
    end
end
if (FF_IN_E && MODE_E != DIS_E) begin
    always @(posedge clk) begin
        E_q_0 <= E;
    end
end
if (FF_IN_Z) begin
    always @(posedge clk) begin
        Z_i_q <= Z;
    end
end

if (FF_MUL) begin
    for (genvar i = 0; i < N_A; i = i + 1) begin
        for (genvar j = 0; j < N_B; j = j + 1) begin
            if (!(OPT_HIGH && (i == N_A - 1) && j == (N_B - 1))) begin
                always @(posedge clk) begin
                    P_q[i][j] <= P[i][j];
                end
            end
        end
    end
end

if (FF_MUL && OPT_HIGH) begin
    always @(posedge clk) begin
        c_q <= c;
    end
end

if (MODE_E != DIS_E && FF_MUL) begin
    always @(posedge clk) begin
        E_q_1 <= E_mx_0;
    end
end


if (FF_OUT) begin
    always @(posedge clk) begin
        S_q <= S;
    end
    always @(posedge clk) begin
        F_q <= P_mx[1][1];
    end
end

/////////////////////////////////////////////////////////////////////////


endmodule
