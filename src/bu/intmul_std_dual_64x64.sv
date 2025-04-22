`include "intmul_std_dual_64x64.svh"

module intmul_std_dual_64x64
   #(  
        parameter          DSP_A_U = 16    ,
        parameter          DSP_B_U = 16    ,
        parameter          FF_IN_A = 1     ,
        parameter          FF_IN_B = 1     ,
        parameter          FF_MUL  = 1     ,
        parameter          FF_OUT  = 1
    )
    (
        input               clk     ,
        input               dual    ,
        input   [LOGA-1:0]  A       ,
        input   [LOGB-1:0]  B       ,
        output  [LOGC-1:0]  C
    );


///////////////////////////// input check ///////////////////////////////

generate
    if (DSP_A_U > 32 || DSP_B_U > 32) begin
        DSP_U_MUST_BE_LESS_THAN_32();
    end
endgenerate
generate
    if ((DSP_A_U & (DSP_A_U-1)) != 0) begin
        DSP_A_U_MUST_BE_POWER_OF_2();
    end
endgenerate
generate
    if ((DSP_B_U & (DSP_B_U-1)) != 0) begin
        DSP_B_U_MUST_BE_POWER_OF_2();
    end
endgenerate


/////////////////////////////////////////////////////////////////////////



///////////////////////////// parameters ////////////////////////////////

localparam intmul_std_dual_64x64_params_t params = {FF_IN_A, FF_IN_B, FF_MUL, FF_OUT};
localparam LOGA0 = 32;
localparam LOGB0 = 32;
localparam LOGA = LOGA0 << 1;
localparam LOGB = LOGB0 << 1;
localparam LOGC0 = LOGA0 + LOGB0;
localparam LOGC = LOGC0 << 1;
localparam LAT  = intmul_std_dual_64x64_lat(params);
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


(* use_dsp = "yes" *) wire [DSP_M_U-1:0] P [0:N_A-1][0:N_B-1];
reg  [DSP_M_U-1:0] P_q [0:N_A-1][0:N_B-1];
wire [DSP_M_U-1:0] P_mx[0:N_A-1][0:N_B-1];

wire  [LOGC0-1:0] D[0:1][0:1];

(* use_dsp = "no" *) wire  [LOGC0:0] S0;
(* use_dsp = "no" *) wire  [LOGC0:0] S1;
reg  [LOGC-1:0] S;
reg  [LOGC-1:0] S_q;


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


for (genvar i = 0; i < N_A; i = i + 1) begin
    for (genvar j = 0; j < N_B; j = j + 1) begin
        assign P_mx[i][j] = (FF_MUL) ? P_q[i][j] : P[i][j];
    end
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

assign D[0][0] = {P_mx[1][1], P_mx[0][0]} + (P_mx[1][0] << DSP_A_U)  + (P_mx[0][1] << DSP_B_U);
assign D[0][1] = {P_mx[1][3], P_mx[0][2]} + (P_mx[1][2] << DSP_A_U)  + (P_mx[0][3] << DSP_B_U);
assign D[1][0] = {P_mx[3][1], P_mx[2][0]} + (P_mx[3][0] << DSP_A_U)  + (P_mx[2][1] << DSP_B_U);
assign D[1][1] = {P_mx[3][3], P_mx[2][2]} + (P_mx[3][2] << DSP_A_U)  + (P_mx[2][3] << DSP_B_U);

always @(*) begin
    S = 0;
    case (dual)
        1'b0:
        begin
            S = {D[1][1],D[0][0]} + (D[0][1] << LOGB0) + (D[1][0] << LOGA0);
        end
        1'b1:
        begin
            S[LOGC0-1:    0] = D[0][0];
            S[LOGC -1:LOGC0] = D[1][1];
        end
    endcase
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

if (FF_MUL) begin
    for (genvar i = 0; i < N_A; i = i + 1) begin
        for (genvar j = 0; j < N_B; j = j + 1) begin
            always @(posedge clk) begin
                P_q[i][j] <= P[i][j];
            end
        end
    end
end


if (FF_OUT) begin
    always @(posedge clk) begin
        S_q <= S;
    end
end

/////////////////////////////////////////////////////////////////////////


endmodule
