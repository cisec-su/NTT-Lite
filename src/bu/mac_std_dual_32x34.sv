`include "mac_std_dual_32x34.svh"

module mac_std_dual_32x34
   #(  
        parameter          LOGB    = 34    ,
        parameter mode_e_t MODE_E  = DIS_E ,
        parameter          FF_IN_A = 1     ,
        parameter          FF_IN_B = 1     ,
        parameter          FF_IN_E = 0     ,
        parameter          FF_MUL  = 1     ,
        parameter          FF_OUT  = 1
    )
    (
        input               clk     ,
        input   mode_mul_t  mode_mul,
        input   [LOGA-1:0]  A       ,
        input   [LOGB-1:0]  B       ,
        input   [LOGE-1:0]  E       ,
        output  [LOGC-1:0]  C
    );

///////////////////////////// input check ///////////////////////////////

generate
    if (LOGB > 34) begin
        LOGB_CANT_BE_GREATER_THAN_34();
    end
    else if (LOGB % 2) begin
        LOGB_MUST_BE_EVEN();
    end
endgenerate

/////////////////////////////////////////////////////////////////////////



///////////////////////////// parameters ////////////////////////////////

localparam mac_std_dual_32x34_params_t params = {LOGB, MODE_E, FF_IN_A, FF_IN_B, FF_IN_E, FF_MUL, FF_OUT};
localparam LOGA = mac_std_dual_32x34_loga(params);
localparam LOGE = mac_std_dual_32x34_loge(params);
localparam LOGA0 = mac_std_dual_32x34_loga0(params);
localparam LOGB0 = mac_std_dual_32x34_logb0(params);
localparam LOGE0 = mac_std_dual_32x34_loge0(params);
localparam LOGD  = mac_std_dual_32x34_logd(params);
localparam LOGD0 = mac_std_dual_32x34_logd0(params);
localparam LOGC = mac_std_dual_32x34_logc(params);
localparam LOGC0 = mac_std_dual_32x34_logc0(params);
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


wire [LOGE-1:0] E_mx_0;
reg  [LOGE-1:0] E_q_0;
wire [LOGE-1:0] E_mx_1;
reg  [LOGE-1:0] E_q_1;

(* use_dsp = "yes" *) wire [DSP_M_U-1:0] P [0:N_A-1][0:N_B-1];
reg  [DSP_M_U-1:0] P_q [0:N_A-1][0:N_B-1];
wire [DSP_M_U-1:0] P_mx[0:N_A-1][0:N_B-1];


wire  [LOGC-1:0] S;
(* use_dsp = "no" *) wire  [LOGC0:0] S0;
(* use_dsp = "no" *) wire  [LOGC0:0] S1;
reg  [LOGC-1:0] S_q;

wire [LOGD0+1:0] T;
reg  [LOGC-1:0] S_int;

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

for (genvar i = 0; i < N_A; i = i + 1) begin
    for (genvar j = 0; j < N_B; j = j + 1) begin
        assign P_mx[i][j] = (FF_MUL) ? P_q[i][j] : P[i][j];
    end
end

if (MODE_E != DIS_E) begin
    assign E_mx_1   = (FF_MUL) ? E_q_1 : E_mx_0;
end

assign C = (FF_OUT) ? S_q : S;

/////////////////////////////////////////////////////////////////////////




///////////////////////////// multiplication ////////////////////////////

for (genvar i = 0; i < N_A; i = i + 1) begin
    for (genvar j = 0; j < N_B; j = j + 1) begin
        assign P[i][j] = A_i_mx[i] * B_i_mx[j];
    end
end

/////////////////////////////////////////////////////////////////////////




///////////////////////////// summation /////////////////////////////////


assign T = P_mx[1][0] + ((mode_mul == MUL_SINGLE) ? (P_mx[0][1] << (DSP_B_U - DSP_A_U)) : P_mx[0][1]);

always @(*) begin
    S_int = 0;
    case (mode_mul)
        MUL_SINGLE:
        begin
            S_int = (T << (DSP_A_U)) + {P_mx[1][1],P_mx[0][0]};
        end
        MUL_DUAL:
        begin
            S_int[LOGC0-1:    0] = P_mx[0][0];
            S_int[LOGC -1:LOGC0] = P_mx[1][1];
        end
        MUL_POLY:
        begin
            S_int[LOGC0-1:    0] = P_mx[0][0] + P_mx[1][1];
            S_int[LOGC -1:LOGC0] = T;
        end
    endcase
end

if (MODE_E == DIS_E) begin
    assign S = S_int;
end
else if (MODE_E == SUB_E) begin
    assign S0 = S_int[LOGC0-1:    0] - ((mode_mul == MUL_SINGLE) ? E_mx_1[LOGC0-1:0]                 : E_mx_1[LOGE0-1:    0]); // S[LOGC0] is the borrow-bit
    assign S1 = S_int[LOGC -1:LOGC0] - ((mode_mul == MUL_SINGLE) ? E_mx_1[LOGE -1:LOGC0] + S0[LOGC0] : E_mx_1[LOGE -1:LOGE0]);
    assign S = {S1[LOGC0-1:0], S0[LOGC0-1:0]};
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

if (FF_MUL) begin
    for (genvar i = 0; i < N_A; i = i + 1) begin
        for (genvar j = 0; j < N_B; j = j + 1) begin
            always @(posedge clk) begin
                P_q[i][j] <= P[i][j];
            end
        end
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
end

/////////////////////////////////////////////////////////////////////////


endmodule
